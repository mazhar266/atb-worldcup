# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ATB WorldCup is an arcade-style top-down 2D football game built on **LÖVE2D (Love2D) 11.x / Lua 5.1**.
It has **no build system, no test suite, no linter, and no external dependencies** — Love2D is the only
requirement. Colors are 0–1 floats (Love2D 11.x convention).

## Commands

```bash
love .            # run the game from the project root (the only "build/run" step)
love2d .          # same, on distros that name the binary love2d
```

There is no test/lint tooling in the repo, and no Lua interpreter is assumed to be installed — code
cannot be unit-tested or syntax-checked from the shell. Validate changes by running the game in Love2D
and playing it. To distribute, zip the project contents into a `.love` archive (packaging is not yet
scripted; see `docs/plan.md` Phase 7).

## Architecture

`main.lua` is a thin shim: every Love2D callback (`load`/`update`/`draw`/`keypressed`) forwards directly
to the corresponding function in `src/game.lua`. `conf.lua` fixes the window at **800×600** and disables
the `joystick` and `physics` modules — do **not** use `love.physics`; all motion is hand-rolled.

`src/game.lua` is the orchestrator and the single source of truth for the **state machine**:
`menu → playing → overtime → paused → goal → gameover`. It owns all mutable match state at module level
(`ball`, `player1`, `player2`, the two AI formations `mates1`/`mates2`, `timeLeft`, `isOvertime`, score via
the `Goal` module) and dispatches `update`/`draw`/`keypressed` by `state`. The squad-vs-formation split
(one controllable captain + an AI supporting cast per side) is also wired here — see the formation model
below. Key transitions: a draw at 0:00 enters sudden-death `overtime`;
a scored goal enters a brief `goal` freeze, then either ends the match (overtime) or resets for kickoff.
Inputs are only honored in the states where they make sense (e.g. kick/substitute keys only in
`playing`/`overtime`).

The other `src/` modules split into two coexisting conventions — be consistent with whichever a file
already uses:
- **Metatable OOP** (`:new`, `__index`): `src/ball.lua`, `src/player.lua`, `src/teammate.lua` — instantiated per match.
- **Plain-table singletons**: `src/field.lua`, `src/goal.lua`, `src/ui.lua`, `src/assets.lua`, `src/audio.lua`, `src/config.lua` — stateless-ish shared modules.

`src/field.lua` is the **shared coordinate authority**: pitch/goal geometry (`x`, `y`, `right`, `bottom`,
`cx`, `cy`, `goalTop`, `goalBottom`, `goalWidth`, …). `ball.lua`, `player.lua`, `teammate.lua`, `goal.lua`,
and `ui.lua` all read these for boundaries, formation anchors, scoring, and HUD placement. Gotcha: the
derived values (`right`, `cx`, …)
are computed **once at require-time** from the literal fields (despite a comment mentioning a `Field.load`
that doesn't exist) — changing `Field.width`/`x` at runtime won't recompute them.

`src/ball.lua` is custom physics: velocity + per-frame friction (`0.98`), wall bounce, and pass-through at
the goal openings. `src/goal.lua` holds the `score` table and `Goal.check(ball)` returns the scoring team.
`src/ui.lua` is pure rendering (HUD, menu, pause, goal flash, game-over, stamina panel); fonts are created
in `UI.load`.

`src/assets.lua` loads PNG sprites from `assets/` (ball, players, grass, title) with graceful fallback to
the geometric shapes when a sprite is missing. `src/audio.lua` loads/plays everything in `assets/sfx/`:
looping **theme** music + **crowd** ambience beds, a **start** jingle, a human-only **move** loop, and
one-shot effects (randomised `kick0-3`/`goal0-1`, bounce, whistle, substitute). It prefers **OGG** and
falls back to the generated **WAV** placeholders (`tools/generate_sfx.py` only makes WAVs); every play call
is a safe no-op if the file or audio device is missing. The **audio "scene" is driven by `game.lua`'s state
machine** (theme on `menu`/`gameover`, crowd during play, move follows human players) — wire new transitions
there, keep `audio.lua` as low-level play/stop primitives. `assets/sfx/theme.ogg.options` (`stream: true`)
is just a hint that the large theme is loaded as a streaming source.

## Full-team formation model (who is on the pitch)

To fill the pitch like a real match (the FIFA-style "all players running" look, modelled on
Code-the-Classics `soccer.py`), each side fields **one controllable captain + an AI formation of
team-mates**. The captain is the `Player` from `src/player.lua` (carrying the whole squad/stamina/sub
system below). The supporting cast lives in **`src/teammate.lua`**: a `Teammate` is a lightweight pitch
body with **no stamina/substitution depth** — it just runs at a fixed speed, holds a ball-aware formation
anchor, and kicks. `Teammate.formation(team, aiMods)` builds one side's lineup from the module-level
`FORMATION` table (currently a **goalkeeper + 3 outfielders**; left-team fractions are mirrored in `x` for
the right team). Teammates are **purely additive** — they leave `player.lua` and its invariants untouched.

### Control & passing (FIFA-style; modelled on `soccer.py`)

You drive **one** player per team at a time — the **controlled unit** (`game.lua`'s `control1`/`control2`,
which may point at the captain `Player` **or** any outfield `Teammate`; never the keeper). The model mirrors
Code-the-Classics `soccer.py`'s `active_control_player`:
- **Control follows the ball.** `updatePossession(t)` keeps control on the active unit while it is within
  `POSSESS_RANGE` of the ball, otherwise hands control to whichever team unit is now on the ball. So you
  always end up driving the player who has it.
- **The kick key is a pass.** `humanKick(t)` (F = team 1, L = team 2) is honoured only when the active unit
  is on the ball. It calls `pickPassTarget` (best team-mate that is **ahead in your facing direction**,
  within `PASS_RANGE`, scored by forwardness+closeness); `passBallTo` kicks to them (led toward goal) **and
  sets them as the controlled unit** — control follows the pass. With no team-mate open it `shootAtGoal`.
- A **chevron** (`drawControlMarker`) marks the player you currently control. `resetControl()` re-points
  control to the unit nearest the ball at every kickoff / overtime restart and clears pass lockouts
  (`holdoff` per unit, `passTimer` per team — during which off-ball mates hold so they don't steal the pass).
- Tuning for all of this is the `PASS_*` / `POSSESS_*` / `SHOOT_*` constants at the top of `src/game.lua`.

**How a unit moves is decided by `game.lua` and passed into `:update(dt, ball, opts)`** (both `Player` and
`Teammate` take the same `opts`): `humanMove = {x,y}` drives the controlled unit from the keys; otherwise the
unit runs AI (`moveTo` = a support point, else chase the ball). `autoKick=false` stops a human team's
off-ball players from blasting the ball (the human passes instead); `autoSub=false` leaves subs manual.
Keepers always auto-clear. Every unit stores `faceX/faceY` (facing, for aiming passes) and `holdoff`.

`game.lua` drives both teams each frame via `updateTeams(dt)`, branching per side:
- **`updateHumanTeam`** moves the controlled unit by the keys and runs everyone else as AI; while you hold
  the ball (or just passed) off-ball mates hold a support shape (captain → `captainSupportPoint`), otherwise
  the nearest outfielder chases to win it back. Then `separateTeam` + `updatePossession`.
- **`updateAITeam`** is the old behaviour: the captain chases + auto-kicks + auto-subs, and `updateTeam`
  runs the formation (lead chases, others hold a ball-biased anchor). The **goalkeeper** tracks the ball
  along its line and rushes out to smother a close ball on its own side.
- **`separateTeam`** de-overlaps same-team bodies (team-mates yield; the captain is immovable).
- `aiMods` (the difficulty `aiSpeed`/`aiKick`) scale the AI side's team-mates too, just like the AI captain.
- Teammates freeze during the `goal` flash (not updated) and are sent home by `resetMates()` + `resetControl()`
  on every kickoff / overtime restart, alongside `Player:reset()`. Draw order: formations → captains → ball
  → control chevrons.
- Teammate tuning (speeds, kick power/range/cooldown, formation anchors, keeper box/reach) is `local`
  constants at the top of `src/teammate.lua`. The squad/stamina UI panel still only reflects the captain;
  **only the captain carries stamina** (controlling a stamina-less team-mate does not tire).

## Squad / stamina / substitution model (the main gameplay system)

Each team's **captain** is a **3-player squad**, not a single player. A `Player` object is a *pitch slot*
that owns the position/velocity (`x`, `y`, `vx`, `vy`); its `roster` is an array of members and `active`
indexes the member currently on the pitch. Only the active member is controlled and drawn (the rest of the
on-pitch team are the `Teammate`s above; the squad's other two members are bench substitutes, not runners).

**Per-player attributes come from a config file.** `src/config.lua` is the single source of truth: its
`TEAMS` table (validated on load) gives every player a `name` and `speed`/`strength`/`stamina` on a 1–10
scale, plus a per-team `name` (`Config.teamName`, shown in the HUD / goal flash / game-over). A separate
`DIFFICULTIES` table (`Config.difficulties()`) drives the difficulty screen — the menu is two screens
(`game.lua`'s `menuPage`: `"main"` Play/2-Players → `"difficulty"` Easy/Medium/Hard). Each entry carries a
`name`, `tagline`, and AI multipliers `aiSpeed`/`aiKick` that `game.lua` passes to the AI `Player` via
`Player.new(..., aiMods)`, scaling only the AI's run speed and kick power. `Player.new`
derives, per member: `speedPx` (run speed), `kickPower` (kick distance), and `maxStamina` (life capacity)
via the `*_BASE`/`*_PER` mapping constants at the top of `src/player.lua` — edit names/stats in
`src/config.lua`, edit the attribute→game mapping in `player.lua`. Stamina is capped at each
member's own `maxStamina`; drain is absolute points/sec (so high-stamina players last longer) while the
fatigue speed/kick multipliers and the AI auto-sub thresholds work on the stamina **fraction** of each
member's own max, so unequal squads compare fairly.

- Stamina drains for the active member (move/idle/kick) and **regenerates for benched members**, clamped to
  `[0, 100]`. Low stamina linearly scales down movement speed and kick power (with floors).
- `Player:substitute()` swaps the active member with the freshest bench member **in place** (position is
  kept, so control is seamless), gated by a cooldown. The AI auto-subs when its active player tires.
- **Invariant:** `Player:reset()` only repositions for kickoff — it must never touch `roster`/`active`/
  stamina, so fatigue persists across goals and into overtime. Preserve this if you refactor reset/kickoff.
- All gameplay tuning lives as `local` constants at the top of `src/player.lua` (drain/regen rates, kick
  cost, cooldown, speed/kick floors, attribute→game mapping) and `src/ball.lua` (friction). Squad size,
  team/player names, and per-player stats come from the `TEAMS` table in `src/config.lua`, not constants.
- `src/ui.lua` reads `Player` internals (`roster`, `active`, `subCooldown`) directly to draw the fitness
  panel; if you change the roster shape, update the UI accordingly.

## Conventions

- Each `src/*.lua` module returns one table and is loaded with `require("src.x")` (dot path).
- Many UI coordinates are hardcoded against the fixed 800×600 window and a 50px top HUD strip; account for
  that when changing layout.
- **Keep docs in sync with code.** `README.md` (controls/features), `docs/plan.md` (design, phases,
  tuning, controls), and `AGENTS.md` (agent notes) are treated as living docs and are expected to be
  updated in the same change as the code — the git history has a dedicated "sync docs with code" commit
  and this norm is followed per feature.
