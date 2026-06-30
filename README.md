# ATB WorldCup

An arcade-style 2D football game built with [LÖVE2D](https://love2d.org/) (Love2D) for fun with ATB colleagues.

## Features

- Arcade-style 2D football (soccer) gameplay
- 2-player local versus mode or 1-player vs AI
- **Difficulty modes** — Easy / Medium / Hard (with custom taglines) scale the AI's speed and kicking; names, taglines, and tuning all editable in [`src/config.lua`](src/config.lua)
- **Named squads with attributes** — each of the 3 players per team has **speed**, **strength**, and **stamina** ratings (1–10), all editable in [`src/config.lua`](src/config.lua)
- **Speed** sets how fast a player runs · **Strength** sets how far they kick the ball · **Stamina** is their "life" (maximum energy)
- **Squad & substitutions** — 1 player on the pitch, 2 on the bench; the active player's name and stats show in the HUD
- **Stamina system** — the active player tires while running and kicking; tired players move slower and kick weaker
- **Fresh legs** — substitute the active player for a rested one on the bench; benched players recover stamina (the AI manages its own subs too)
- Simple ball physics with velocity and friction
- Goal detection and score tracking
- 90-second match timer with sudden-death overtime
- Pixel-art sprites for the ball, players, field, and menu banner
- **Full audio** — looping theme music on the menu, crowd ambience during play, a
  kickoff jingle, footstep loop, and effects for kicks, goals, bounces, the
  whistle, and substitutions (randomised kick/goal variants for variety)
- Pause and restart support

## Requirements

- [LÖVE2D](https://love2d.org/) version **11.x** or higher

## Running the Game

1. [Download and install LÖVE2D](https://love2d.org/#download) for your platform.

2. Clone this repository:
   ```bash
   git clone https://github.com/mazhar266/atb-worldcup.git
   cd atb-worldcup
   ```

3. Run the game with LÖVE2D:
   ```bash
   love .
   ```

   Or on some systems:
   ```bash
   love2d .
   ```

## Controls

| Action        | Player 1 (Red)   | Player 2 (Blue)       |
|---------------|------------------|-----------------------|
| Move Up       | `W`              | `↑` (Up Arrow)        |
| Move Down     | `S`              | `↓` (Down Arrow)      |
| Move Left     | `A`              | `←` (Left Arrow)      |
| Move Right    | `D`              | `→` (Right Arrow)     |
| Kick Ball     | `F`              | `L`                   |
| Substitute    | `Q`              | `K`                   |

> **Tip:** Watch the stamina bar at the top of your half. Sub on a fresh player
> (`Q` / `K`) when you start to tire — the player you bring off recovers stamina
> while resting on the bench. There's a short cooldown between substitutions.

### Menu / Global

| Key          | Action                  |
|--------------|-------------------------|
| `Enter`      | Start game / Confirm    |
| `P`          | Pause / Resume          |
| `R`          | Restart (from pause)    |
| `Escape`     | Quit to menu            |

## Squads & Attributes

Each team is a 3-player squad. Every player has three attributes on a **1–10**
scale, defined in [`src/config.lua`](src/config.lua):

| Attribute  | Effect in game                                          |
|------------|---------------------------------------------------------|
| `speed`    | How fast the player runs                                |
| `strength` | How far they kick the ball                              |
| `stamina`  | Their "life" — maximum energy; drains as they play      |

The default rosters (team 1 = left/red, team 2 = right/blue):

| Business (Red)    | Speed | Strength | Stamina |    | Tech (Blue)        | Speed | Strength | Stamina |
|-------------------|:-----:|:--------:|:-------:|----|--------------------|:-----:|:--------:|:-------:|
| Rei               |   7   |     7    |    8    |    | Mazhar             |    5  |    10    |    6    |
| Sahabub           |   8   |     8    |    9    |    | Swapon             |    7  |     8    |    8    |
| Rifa              |   7   |     3    |    6    |    | Sadia              |   10  |     2    |    6    |

Edit the team names, player names, and stats in the `TEAMS` table at the top of
`src/config.lua` — the loader validates them and clamps each attribute to 1–10.
The active player's name and stats are shown in the HUD, and the team names
appear in the HUD, on goals, and on the final score.

## Difficulty

The menu is two screens. The main screen picks the mode:

```
> Play  (1 Player vs AI)
  2 Players  (local)
```

Choosing **Play** opens the difficulty screen (press `Esc` to go back):

```
> Easy  (Chhote bachche ho keya!)
  Medium  (We are Friends)
  Hard  (Beak your legs)
```

Each difficulty scales the AI opponent — `aiSpeed` (how fast it runs) and
`aiKick` (how hard it kicks). The names, taglines, and multipliers live in the
`DIFFICULTIES` table in [`src/config.lua`](src/config.lua); add or rename modes
freely and the difficulty screen adapts. Difficulty only affects the AI.

## Project Structure

```
atb-worldcup/
├── main.lua          # Love2D entry point
├── conf.lua          # Love2D window configuration
├── src/
│   ├── game.lua      # Game state manager
│   ├── field.lua     # Field rendering
│   ├── ball.lua      # Ball physics and rendering
│   ├── player.lua    # Player entity, controls, and AI
│   ├── goal.lua      # Goal zones and scoring
│   ├── ui.lua        # HUD, menus, and overlays
│   ├── assets.lua    # Central sprite loader
│   ├── audio.lua     # Music / sound effect loader and playback
│   └── config.lua    # Squad rosters, names & per-player attributes (edit here)
├── assets/           # PNG sprites and audio
│   └── sfx/          # OGG music + effects (WAV fallbacks for a few cues)
├── tools/
│   ├── generate_assets.py  # Sprite generator script
│   └── generate_sfx.py     # Sound effect generator script
├── docs/
│   └── plan.md       # Project plan and design document
├── LICENSE
└── README.md
```

## Assets

The game ships with pixel-art sprites in `assets/` and audio in `assets/sfx/`.
If the sprites are missing, the renderer falls back to the original geometric
shapes; missing sounds are simply skipped.

Audio loading prefers the richer **OGG** assets (`theme`, `start`, `crowd`,
`move`, and the `kick0-3` / `goal0-1` variants). The `tools/generate_sfx.py`
script only synthesises simple **WAV** placeholders (`bounce`, `substitute`,
`whistle`, plus single `kick`/`goal`), which are used as fallbacks when the
matching OGG is absent. The large `theme.ogg` is streamed (see `theme.ogg.options`).

### Regenerate image assets

Requires Python 3 and Pillow:

```bash
python3 -m venv .venv-assets
source .venv-assets/bin/activate  # On Windows: .venv-assets\Scripts\activate
pip install Pillow
python tools/generate_assets.py
```

### Regenerate sound effects

Requires Python 3 and ffmpeg:

```bash
python tools/generate_sfx.py
```

## Documentation

See [`docs/plan.md`](docs/plan.md) for the full project plan, game design, and implementation roadmap.

## License

See [LICENSE](LICENSE).
