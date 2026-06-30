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
(`ball`, the two team arrays `team1`/`team2`, the controlled-player pointers `control1`/`control2`, the
control schemes `scheme1`/`scheme2`, `timeLeft`, `isOvertime`, score via the `Goal` module) and dispatches
`update`/`draw`/`keypressed` by `state`. A team is simply an **array of on-pitch `Player`s — one per config
squad member** (see the team model below). Key transitions: a draw at 0:00 enters sudden-death `overtime`;
a scored goal enters a brief `goal` freeze, then either ends the match (overtime) or resets for kickoff.
Inputs are only honored in the states where they make sense (e.g. the pass key only in `playing`/`overtime`).

The other `src/` modules split into two coexisting conventions — be consistent with whichever a file
already uses:
- **Metatable OOP** (`:new`, `__index`): `src/ball.lua`, `src/player.lua` — instantiated per match (one
  `Player` per config squad member per team).
- **Plain-table singletons**: `src/field.lua`, `src/goal.lua`, `src/ui.lua`, `src/assets.lua`, `src/audio.lua`, `src/config.lua` — stateless-ish shared modules.

`src/field.lua` is the **shared coordinate authority**: pitch/goal geometry (`x`, `y`, `right`, `bottom`,
`cx`, `cy`, `goalTop`, `goalBottom`, `goalWidth`, …). `ball.lua`, `player.lua`, `goal.lua`,
and `ui.lua` all read these for boundaries, formation homes, scoring, and HUD placement. Gotcha: the
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

## Team model — config players ARE the team (who is on the pitch)

**Every player in a team's config squad is its own on-pitch `Player`** — there are no anonymous extras, no
goalkeeper role, and no hidden bench. With the default 3-player squads you get a literal **3-a-side** of the
named players (Mazhar/Swapon/Sadia vs Rei/Sahabub/Rifa). A `Player` (`src/player.lua`) is one footballer:
position/velocity, one config identity (`name`, `number`, `attrSpeed/Strength/Stamina`), the derived
`speedPx`/`kickPower`/`maxStamina`, its own `stamina`, a formation `homeX/homeY`, and `faceX/faceY`+`holdoff`
for passing. `game.lua` builds each team with `buildTeam(team, aiMods)` → one `Player.new(team, i, total,
aiMods)` per config entry; formation homes come from the `FORMATIONS`/`homeFraction` table in `player.lua`
(left-team fractions mirrored in `x` for the right team).

**Per-player attributes come from the config.** `src/config.lua` is the single source of truth: its `TEAMS`
table (validated on load) gives every player a `name` and `speed`/`strength`/`stamina` on a 1–10 scale, plus
a per-team `name` (`Config.teamName`, shown in the HUD / goal flash / game-over). A `DIFFICULTIES` table
(`Config.difficulties()`) drives the difficulty screen — the menu is two screens (`game.lua`'s `menuPage`:
`"main"` Play/2-Players → `"difficulty"` Easy/Medium/Hard); the chosen `aiSpeed`/`aiKick` flow through
`buildTeam` into every AI `Player` and scale only its run speed and kick power. The attribute→game mapping
(`*_BASE`/`*_PER`) lives at the top of `src/player.lua` — edit names/stats in `config.lua`, edit the mapping
in `player.lua`. **To add players to the pitch, add them to the `TEAMS` squad in `config.lua`** — squad size
drives how many run (the formation table covers 1–5, with a staggered fallback beyond).

### Stamina (rest-based, no bench)

Each player drains stamina while **running** and recovers it while **resting** (standing still), clamped to
`[0, maxStamina]`; kicking costs a flat amount. Low stamina scales movement speed and kick power down (with
floors), on the **fraction** of each player's own max so unequal players compare fairly. **Invariant:**
`Player:reset()` only repositions for kickoff — it must never touch `stamina`, so fatigue persists across
goals and into overtime. Tuning (`DRAIN_MOVE`/`REGEN_REST`/`KICK_COST`/floors) is `local` constants at the
top of `src/player.lua`; ball friction lives in `src/ball.lua`. *(There is no substitution any more — the
whole squad is on the pitch, so the old bench/sub system was removed.)*

### Control & passing (FIFA-style; modelled on `soccer.py`)

You drive **one** player per team at a time — the **controlled player** (`game.lua`'s `control1`/`control2`,
an entry of the team array). Mirrors Code-the-Classics `soccer.py`'s `active_control_player`:
- **Control follows the ball.** `updatePossession(t)` keeps control on the active player while it is within
  `POSSESS_RANGE` of the ball, otherwise hands control to whichever team-mate is now on the ball.
- **The kick key is a pass.** `humanKick(t)` (F = team 1, L = team 2) is honoured only when the active player
  is on the ball. `pickPassTarget` finds the best team-mate **ahead in your facing direction** (within
  `PASS_RANGE`, scored by forwardness+closeness); `passBallTo` kicks to them (led toward goal) **and sets
  them as the controlled player** — control follows the pass. With nobody open it `shootAtGoal`.
- A **chevron** (`drawControlMarker`) marks who you control; the `UI.drawTeams` corner panel lists the whole
  squad with stamina bars and marks the same player. `resetControl()` re-points control to the player nearest
  the ball at every kickoff and clears the pass lockouts (`holdoff` per player, `passTimer` per team — during
  which off-ball mates hold so they don't steal the pass). Tuning is the `PASS_*`/`POSSESS_*`/`SHOOT_*`
  constants at the top of `src/game.lua`.

**How a player moves is decided by `game.lua` and passed into `Player:update(dt, ball, opts)`:**
`humanMove = {x,y}` drives the controlled player from the keys; otherwise it runs AI — `chase = true` (the
team's lead, go for the ball; with `autoKick` it kicks toward goal when close) or, by default, hold a
ball-biased formation point. `autoKick=false` stops a human team's off-ball players from blasting the ball
(the human passes instead).

`game.lua` drives both teams each frame via `updateTeams(dt)`, branching per side:
- **`updateHumanTeam`** moves the controlled player by the keys and runs the rest as AI; while you hold the
  ball (or just passed) off-ball mates hold their formation shape, otherwise the nearest one chases to win it
  back. Then `separateTeam` + `updatePossession`.
- **`updateAITeam`** makes the player nearest the ball the lead (chase + auto-kick toward goal); the rest hold
  the ball-biased formation. `aiMods` scale the whole AI side.
- **`separateTeam(arr, immovable)`** de-overlaps same-team bodies; the controlled player is `immovable` so a
  human's dribble isn't nudged.
- Players freeze during the `goal` flash and are sent home by `resetTeams()` + `resetControl()` on every
  kickoff / overtime restart. Draw order: team1 → team2 → ball on top → control chevrons.

## Conventions

- Each `src/*.lua` module returns one table and is loaded with `require("src.x")` (dot path).
- Many UI coordinates are hardcoded against the fixed 800×600 window and a 50px top HUD strip; account for
  that when changing layout.
- **Keep docs in sync with code.** `README.md` (controls/features), `docs/plan.md` (design, phases,
  tuning, controls), and `AGENTS.md` (agent notes) are treated as living docs and are expected to be
  updated in the same change as the code — the git history has a dedicated "sync docs with code" commit
  and this norm is followed per feature.
