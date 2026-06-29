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
(`ball`, `player1`, `player2`, `timeLeft`, `isOvertime`, score via the `Goal` module) and dispatches
`update`/`draw`/`keypressed` by `state`. Key transitions: a draw at 0:00 enters sudden-death `overtime`;
a scored goal enters a brief `goal` freeze, then either ends the match (overtime) or resets for kickoff.
Inputs are only honored in the states where they make sense (e.g. kick/substitute keys only in
`playing`/`overtime`).

The other `src/` modules split into two coexisting conventions — be consistent with whichever a file
already uses:
- **Metatable OOP** (`:new`, `__index`): `src/ball.lua`, `src/player.lua` — instantiated per match.
- **Plain-table singletons**: `src/field.lua`, `src/goal.lua`, `src/ui.lua`, `src/assets.lua`, `src/audio.lua` — stateless-ish shared modules.

`src/field.lua` is the **shared coordinate authority**: pitch/goal geometry (`x`, `y`, `right`, `bottom`,
`cx`, `cy`, `goalTop`, `goalBottom`, `goalWidth`, …). `ball.lua`, `player.lua`, `goal.lua`, and `ui.lua`
all read these for boundaries, scoring, and HUD placement. Gotcha: the derived values (`right`, `cx`, …)
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

## Squad / stamina / substitution model (the main gameplay system)

Each team is a **3-player squad**, not a single player. A `Player` object is a *pitch slot* that owns the
position/velocity (`x`, `y`, `vx`, `vy`); its `roster` is an array of members `{stamina, number}` and
`active` indexes the member currently on the pitch. Only the active member is controlled and drawn.

- Stamina drains for the active member (move/idle/kick) and **regenerates for benched members**, clamped to
  `[0, 100]`. Low stamina linearly scales down movement speed and kick power (with floors).
- `Player:substitute()` swaps the active member with the freshest bench member **in place** (position is
  kept, so control is seamless), gated by a cooldown. The AI auto-subs when its active player tires.
- **Invariant:** `Player:reset()` only repositions for kickoff — it must never touch `roster`/`active`/
  stamina, so fatigue persists across goals and into overtime. Preserve this if you refactor reset/kickoff.
- All gameplay tuning lives as `local` constants at the top of `src/player.lua` (drain/regen rates, kick
  cost, cooldown, speed/kick floors, squad size) and `src/ball.lua` (friction, kick power). Tweak feel there.
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
