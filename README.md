# ATB WorldCup

An arcade-style 2D football game built with [LÖVE2D](https://love2d.org/) (Love2D) for fun with ATB colleagues.

## Features

- Arcade-style 2D football (soccer) gameplay
- **Whole config squads on the pitch** — like FIFA, every named player from a team's config squad plays at
  once (the default 3-a-side: Mazhar/Swapon/Sadia vs Rei/Sahabub/Rifa), so the full team moves with play.
  There are no anonymous extras — **only the players you define in [`src/config.lua`](src/config.lua) appear**
- **Pass & switch control** — you always control the player on the ball; the kick key **passes to a
  team-mate and hands you control of them**, and control auto-switches to whoever wins a loose ball
  (modelled on the Code-the-Classics `soccer.py`). A chevron marks who you're controlling
- 2-player local versus mode or 1-player vs AI
- **Difficulty modes** — Easy / Medium / Hard (with custom taglines) scale the AI's speed and kicking; names, taglines, and tuning all editable in [`src/config.lua`](src/config.lua)
- **Named players with attributes** — every player has **speed**, **strength**, and **stamina** ratings (1–10), all editable in [`src/config.lua`](src/config.lua)
- **Speed** sets how fast a player runs · **Strength** sets how far they kick the ball · **Stamina** is their "life" (maximum energy)
- **Stamina system** — players tire while running and kicking (slower, weaker) and **recover by resting**; each player's name and stamina show in the corner panel
- Simple ball physics with velocity and friction
- Goal detection and score tracking
- 90-second match timer with sudden-death overtime
- Pixel-art sprites for the ball, players, field, and menu banner
- **Full audio** — looping theme music on the menu, crowd ambience during play, a
  kickoff jingle, footstep loop, and effects for kicks, goals, bounces, and the
  whistle (randomised kick/goal variants for variety)
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
| Pass / Shoot  | `F`              | `L`                   |

> **Passing & control (FIFA-style):** You drive one player at a time — whoever is
> on the ball (a chevron marks them, and the corner panel highlights them). Press
> **Pass** (`F` / `L`) to play the ball to the best team-mate ahead of you;
> **control switches to that team-mate** so you run onto your own pass. With no
> team-mate open, it's a shot at goal. When you don't have the ball, control jumps
> to whichever of your players wins it.
>
> **Tip:** Every player tires as they run and recovers while resting, so don't let
> one player do all the work — spread the running across the squad and watch the
> stamina bars in the corner panel.

### Menu / Global

| Key          | Action                  |
|--------------|-------------------------|
| `Enter`      | Start game / Confirm    |
| `P`          | Pause / Resume          |
| `R`          | Restart (from pause)    |
| `Escape`     | Quit to menu            |

## Squads & Attributes

Each team's whole config squad is on the pitch at once (the default is 3-a-side),
and **only** these players appear — there are no anonymous extras. You control one
at a time; passing and loose balls switch control between them (see above). Add or
remove players by editing the `TEAMS` squad in [`src/config.lua`](src/config.lua)
— the number you list is the number that take the field.

Every player has three attributes on a **1–10** scale, defined in
[`src/config.lua`](src/config.lua):

| Attribute  | Effect in game                                          |
|------------|---------------------------------------------------------|
| `speed`    | How fast the player runs                                |
| `strength` | How far they kick the ball                              |
| `stamina`  | Their "life" — maximum energy; drains as they play      |

The default squads (team 1 = left/red, team 2 = right/blue):

| Tech (Red)        | Speed | Strength | Stamina |    | Business (Blue)    | Speed | Strength | Stamina |
|-------------------|:-----:|:--------:|:-------:|----|--------------------|:-----:|:--------:|:-------:|
| Mazhar            |   5   |    10    |    6    |    | Rei                |    7  |     7    |    8    |
| Swapon            |   7   |     8    |    8    |    | Sahabub            |    8  |     8    |    9    |
| Sadia             |  10   |     2    |    6    |    | Rifa               |    7  |     3    |    6    |

Edit the team names, player names, and stats in the `TEAMS` table at the top of
`src/config.lua` — the loader validates them and clamps each attribute to 1–10.
Each player's name and stamina are shown in the corner panel, and the team names
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
