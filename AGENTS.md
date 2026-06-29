# ATB WorldCup — Agent Notes

> This file is written for AI coding agents. It assumes you know nothing about the project. All facts below are derived directly from the repository contents (`README.md`, `CLAUDE.md`, `docs/plan.md`, `conf.lua`, `main.lua`, and the files in `src/`).

## Project Overview

ATB WorldCup is a small arcade-style, top-down 2D football (soccer) game built with [LÖVE2D](https://love2d.org/) (Love2D) 11.x / Lua 5.1. It is designed for short local multiplayer matches and includes a single-player versus-AI mode.

Key gameplay systems:

- **2-player local versus** or **1-player vs AI**.
- **3-player squads** per team: one active player on the pitch and two on the bench.
- **Stamina system**: the active player tires while moving, idling, and kicking. Low stamina reduces movement speed and kick power.
- **Substitutions**: swap the active player for the freshest bench player (`Q` for Player 1, `K` for Player 2). Bench players recover stamina while resting.
- **Match timer**: 90-second regulation; if the score is tied, sudden-death overtime begins (first goal wins).
- Generated pixel-art sprites live in `assets/` and are loaded by `src/assets.lua`. Rendering falls back to simple geometric shapes if the sprites are missing.
- Audio lives in `assets/sfx/` and is loaded/played via `src/audio.lua`: looping theme music + crowd ambience beds, a kickoff jingle, a human-only footstep loop, and one-shot effects (randomised `kick0-3` / `goal0-1`, bounce, whistle, substitute). The loader prefers OGG and falls back to the generated WAVs; missing sounds are skipped silently. The state machine in `src/game.lua` drives which beds play per state (theme on menu/gameover, crowd during play).

License: MIT (`LICENSE`).

## Technology Stack & Requirements

- **Language**: Lua 5.1 (bundled with Love2D).
- **Framework**: LÖVE2D (Love2D) 11.x or newer.
- **Config file**: `conf.lua` is the project configuration file. There is no `pyproject.toml`, `package.json`, `Cargo.toml`, or equivalent.
- **Dependencies**: none beyond Love2D itself.
- **Tooling in the repo**: no build system, no test suite, no linter, and no CI scripts.
- **Physics**: custom, hand-rolled AABB and circle collision. `love.physics` is explicitly disabled in `conf.lua`.

## Project Structure

```text
atb-worldcup/
├── main.lua          # Thin Love2D entry point; forwards callbacks to src/game.lua
├── conf.lua          # Love2D window/module configuration
├── src/
│   ├── game.lua      # State machine and main orchestrator (menu, playing, overtime, paused, goal, gameover)
│   ├── field.lua     # Shared pitch/goal geometry and field rendering
│   ├── ball.lua      # Ball entity: position, velocity, friction, wall bouncing
│   ├── player.lua    # Player entity: squad roster, movement, kick, stamina, substitutions, simple AI
│   ├── goal.lua      # Goal zone detection and score state
│   ├── ui.lua        # HUD, menu, pause overlay, goal flash, game-over screen
│   ├── assets.lua    # Central sprite loader with fallback to shape rendering
│   └── audio.lua     # Music / sound effect loader and playback helpers
├── assets/           # PNG sprites and audio
│   ├── sfx/          # OGG music + effects (theme, start, crowd, move, kick0-3, goal0-1) + WAV fallbacks
│   ├── ball.png      # Soccer ball sprite
│   ├── grass.png     # Pitch grass texture
│   ├── title.png     # Menu title banner
│   └── player_{red,blue}_{1..3}.png  # Squad shade variants
├── tools/
│   ├── generate_assets.py  # Python/Pillow script that regenerates image assets
│   └── generate_sfx.py     # Python/ffmpeg script that regenerates sound effects
├── docs/
│   └── plan.md       # Full design document, controls reference, and implementation roadmap
├── README.md         # Human-facing quick start and controls
├── CLAUDE.md         # Claude Code guidance (architecture, conventions, squad model)
├── LICENSE           # MIT License
└── AGENTS.md         # This file
```

## Build and Run Commands

The project has no build step. Run it directly with Love2D from the project root:

```bash
love .
```

On some Linux distributions the binary is named differently:

```bash
love2d .
```

Distribution packaging is not yet implemented. A standard Love2D distribution would be created by zipping the project contents (without `.git`) into a `.love` archive. The roadmap mentions future build scripts for Windows/macOS/Linux executables in `docs/plan.md` Phase 7.

## Code Organization & Architecture

### Entry point (`main.lua`)

A thin shim. Every Love2D callback (`love.load`, `love.update`, `love.draw`, `love.keypressed`) forwards directly to the matching function in `src/game.lua`.

### State machine (`src/game.lua`)

`src/game.lua` is the single source of truth for game state. It owns all mutable match state at module level (`ball`, `player1`, `player2`, `timeLeft`, `isOvertime`, `menuOption`, etc.).

States:

| State      | Meaning                                            |
|------------|----------------------------------------------------|
| `menu`     | Mode selection (1P vs AI, 2P local)                |
| `playing`  | Active regulation time                             |
| `overtime` | Sudden-death extra time (no timer; first goal wins)|
| `paused`   | Pause overlay                                      |
| `goal`     | Brief freeze after a goal                          |
| `gameover` | Match over screen                                  |

Transitions:

- `menu` → `playing` via `Enter`.
- `playing` timer reaching 0 → `overtime` if tied, otherwise `gameover`.
- A goal during `playing` or `overtime` → `goal`; after the freeze it resets to `playing` or ends in `gameover` if it was overtime.
- `P` toggles pause; `Escape` returns to menu.

### Modules (`src/`)

There are two module conventions in use; be consistent with whichever a file already uses:

- **Metatable OOP**: `src/ball.lua` and `src/player.lua` expose `:new()` constructors and use `__index`. Instances are created per match.
- **Plain-table singletons**: `src/field.lua`, `src/goal.lua`, and `src/ui.lua` return a single shared table and are called directly.

Important module responsibilities:

- `src/field.lua` is the **shared coordinate authority**. It defines pitch geometry (`x`, `y`, `width`, `height`, `right`, `bottom`, `cx`, `cy`, `goalTop`, `goalBottom`, `goalWidth`, `goalHeight`). Other modules read these values for boundaries, scoring, and HUD placement. Derived values are computed once at require time, so changing `Field.width` or `Field.x` at runtime will not recompute them.
- `src/ball.lua` implements custom physics: velocity, per-frame friction (`0.98`), wall bounce, and pass-through at the goal openings. Tuning constants live at the top of the file.
- `src/player.lua` is the most complex module. It handles:
  - Input for `wasd`, arrow keys, and a simple AI.
  - 3-member squad roster with per-member stamina.
  - Fatigue scaling of movement speed and kick power.
  - Substitutions (`Player:substitute()`) with a cooldown.
  - AI auto-substitution logic and per-frame auto-kick.
- `src/goal.lua` owns the `score` table and `Goal.check(ball)` returns the scoring team index or `nil`.
- `src/ui.lua` is pure rendering. Fonts are created in `UI.load`. HUD coordinates are hardcoded for the fixed 800×600 window.

### Core gameplay invariant (stamina persistence)

`Player:reset()` only repositions the on-pitch player for kickoff. It intentionally **never** touches `roster`, `active`, or stamina. Fatigue therefore persists across goals and into overtime. Preserve this behavior if you refactor reset/kickoff logic.

## Controls

### In-Game

| Action         | Player 1 (Red) | Player 2 (Blue) |
|----------------|----------------|-----------------|
| Move Up        | `W`            | `↑` (Up Arrow)  |
| Move Down      | `S`            | `↓` (Down Arrow)|
| Move Left      | `A`            | `←` (Left Arrow)|
| Move Right     | `D`            | `→` (Right Arrow)|
| Kick           | `F`            | `L`             |
| Substitute     | `Q`            | `K`             |

### Menu / Global

| Key        | Action                    |
|------------|---------------------------|
| `Enter`    | Start game / Confirm      |
| `P`        | Pause / Resume            |
| `R`        | Restart (from pause)      |
| `Escape`   | Quit to menu              |

## Code Style Guidelines

- Each `src/*.lua` module returns one table and is loaded with `require("src.x")` (dot path).
- Colors use Love2D 11.x 0–1 float RGB(A) values.
- Many constants are declared as module-level `local` values at the top of files.
- UI coordinates are hardcoded against the fixed 800×600 window and the 50 px top HUD strip; account for that when changing layout.
- The codebase uses British English spelling in some comments and docs (e.g., "colour").
- Documentation is expected to stay in sync with code. `README.md` (controls/features) and `docs/plan.md` (design, phases, tuning) are treated as living docs and should be updated in the same change as the code.

## Testing Instructions

There is **no automated test suite, linter, or CI pipeline** in this repository.

Validate changes by:

1. Running the game with `love .`.
2. Playing through the affected flow (menu navigation, match timer, scoring, overtime, pause/restart, substitutions, AI behavior).
3. Checking the HUD renders correctly (score, timer, stamina bars, bench pips, goal flash, game-over screen).

If you add new behavior that can be unit-tested outside Love2D, prefer to keep such code in pure functions that do not depend on `love.*` globals, but no test harness currently exists.

## Deployment & Packaging

- There are no build scripts or release workflows.
- For manual distribution, create a `.love` archive by zipping the project contents (excluding `.git`) from the project root.
- The roadmap (`docs/plan.md` Phase 7) lists planned future work: bundling into `.love` archives and platform-specific executable build scripts.

## Security Considerations

- The game is a local, offline Love2D application. There is no network code, no web server, no file I/O beyond what Love2D performs internally, and no user-supplied data parsed by the game.
- No secrets, credentials, or environment files are present.
- `.gitignore` ignores compiled Lua output, object files, libraries, and executables.
- Because there is no package manager or third-party dependency tree, there is no dependency-update surface beyond the Love2D runtime itself.

## Where to Look for More Detail

- `docs/plan.md`: full game design, screen layout, controls reference, tuning constants, architecture diagram, implementation phases, and roadmap.
- `README.md`: human-facing quick start and feature list.
- `CLAUDE.md`: Claude Code-specific guidance that overlaps heavily with this file.
