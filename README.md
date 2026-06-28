# ATB WorldCup

An arcade-style 2D football game built with [LÖVE2D](https://love2d.org/) (Love2D) for fun with ATB colleagues.

## Features

- Arcade-style 2D football (soccer) gameplay
- 2-player local versus mode or 1-player vs AI
- Simple ball physics with velocity and friction
- Goal detection and score tracking
- 90-second match timer
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
│   └── ui.lua        # HUD, menus, and overlays
├── docs/
│   └── plan.md       # Project plan and design document
├── LICENSE
└── README.md
```

## Documentation

See [`docs/plan.md`](docs/plan.md) for the full project plan, game design, and implementation roadmap.

## License

See [LICENSE](LICENSE).
