# ATB WorldCup

An arcade-style 2D football game built with [LÖVE2D](https://love2d.org/) (Love2D) for fun with ATB colleagues.

## Features

- Arcade-style 2D football (soccer) gameplay
- 2-player local versus mode or 1-player vs AI
- **Squad & substitutions** — each team has a 3-player squad (1 on the pitch, 2 on the bench)
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
│   └── audio.lua     # Music / sound effect loader and playback
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
