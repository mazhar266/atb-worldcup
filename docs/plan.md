# ATB WorldCup – Project Plan

## Overview

ATB WorldCup is a simple arcade-style 2D football (soccer) game built with
[LÖVE2D](https://love2d.org/). The goal is to create a fun, quick-to-play
game that ATB colleagues can enjoy during breaks.

---

## Game Design

### Core Concept

- Top-down 2D football pitch
- **Whole config squads on the pitch** (FIFA-style): every named player in a team's
  config squad plays at once (default **3-a-side**), so the full team moves with play.
  No anonymous extras — only the players in `src/config.lua` appear (see *Teams* below)
- Kick the ball into the opponent's goal to score
- 90-second match; highest score wins
- If tied at full time, sudden-death overtime (first goal wins)

### Teams & Control (FIFA-style passing, modelled on `soccer.py`)

A team is simply an **array of on-pitch `Player`s, one per config squad member** — there
are no anonymous runners and no goalkeeper role. `game.lua`'s `buildTeam` makes one
`Player.new(team, i, total, aiMods)` per config entry; each takes a **formation home**
from the `FORMATIONS`/`homeFraction` table in `src/player.lua` (left-team fractions
mirrored in `x` for the right team). Modelled on
[Code-the-Classics `soccer.py`](https://github.com/Wireframe-Magazine/Code-the-Classics/blob/master/soccer-master/soccer.py):

- You drive **one** player at a time — the **controlled player** (`control1`/`control2`).
  **Control follows the ball**: while your player is on the ball you keep control, otherwise
  it jumps to whichever team-mate wins a loose ball (`updatePossession`).
- **The kick key is a pass.** On the ball, `F`/`L` passes to the best team-mate *ahead in
  your facing direction* (`pickPassTarget`) and **hands you control of them** (`passBallTo`)
  — you run onto your own pass. With nobody open it shoots at goal. A short `holdoff`/`passTimer`
  stops the passer reclaiming it and keeps mates from stealing the pass.
- A **chevron** marks the player you control; the corner panel highlights the same player.
  `resetControl()` re-points control to the player nearest the ball at each kickoff.
- **Off-ball AI:** the player nearest the ball is the "lead" (chases; AI teams auto-kick toward
  goal); the rest hold a home anchor that drifts toward the ball, so the shape pushes up and
  drops back. How each player moves is chosen in `game.lua` and passed into
  `Player:update(dt, ball, opts)` (`humanMove` for the controlled player, else `chase`/hold).
- Difficulty (`aiSpeed`/`aiKick`) scales the whole AI side. Passing/control tuning (`PASS_*`,
  `POSSESS_*`, `SHOOT_*`) is at the top of `src/game.lua`.

### Stamina (rest-based)

The whole squad is on the pitch, so there is no bench and no substitution — players manage
their own fitness by **resting**:

- Each player has a **stamina** bar whose maximum is set by their stamina attribute. It
  **drains while running** and a flat amount per kick, and **recovers while standing still**.
- Low stamina **slows movement** (to ~55% at empty) and **weakens kicks** (to ~60% at empty),
  as a fraction of that player's own max.
- Because control follows the ball and you can pass, the running naturally spreads across the
  squad — leave a tired player and steer a fresh one. The corner panel shows every player's
  name and stamina, marking the one you control.

**Tuning constants** (in `src/player.lua`): run-drain 8/s · rest-regen 5/s · kick cost 8 ·
kick cooldown 0.3 s · min speed 55% · min kick 60%.

### Player Attributes & Config

Each player is named and rated on a **1–10** scale for three attributes, defined
in the `TEAMS` table in [`src/config.lua`](../src/config.lua) — the single config
source of truth, validated on load (out-of-range values are clamped, missing
fields defaulted) so a hand-edit can't crash the game. **The number of players you
list per team is the number that take the field.** Each team also has a display
`name` (`Config.teamName`), shown in the HUD, on goals, and on full time:

| Attribute  | Drives          | Mapping (in `src/player.lua`)                     |
|------------|-----------------|---------------------------------------------------|
| `speed`    | run speed       | `SPEED_BASE + attr·SPEED_PER` → 110–200 px/s       |
| `strength` | kick distance   | `KICK_BASE + attr·KICK_PER` → 230–500 impulse      |
| `stamina`  | max stamina/life| `attr·STAMINA_PER` → 10–100 capacity                |

Each player carries its own derived `speedPx`, `kickPower`, and `maxStamina`.
Because drain is in absolute points/sec but `maxStamina` scales with the
attribute, high-stamina players simply last longer; speed/kick fatigue works on
the **fraction** of each player's own max, so players with different staminas
compare fairly.

Default squads (per `src/config.lua`) — team 1 **Tech** (left/red): Mazhar,
Swapon, Sadia; team 2 **Business** (right/blue): Rei, Sahabub, Rifa. Each
player's `speed`/`strength`/`stamina` is set in that file.

### Difficulty modes

A `DIFFICULTIES` list in `src/config.lua` defines the difficulty modes: each has
a `name`, a `tagline` (both shown in the menu), and AI multipliers `aiSpeed` /
`aiKick`. The menu is **two screens** (`menuPage` in `game.lua` = `"main"` →
`"difficulty"`): the main screen offers *Play (1 Player vs AI)* and *2 Players*,
and choosing Play opens the difficulty screen built from `Config.difficulties()`
(Esc goes back). The chosen `{aiSpeed, aiKick}` are passed to the AI `Player`
(`Player.new`'s `aiMods`), scaling only the AI's run speed and kick power — human
players are unaffected. Defaults: Easy 0.70/0.85, Medium 1.0/1.0, Hard 1.25/1.15.

### Visual Style

- Generated pixel-art sprites with shape-based fallback (sprites live in `assets/` and are optional)
- Green pitch with white lines and a subtle grass texture
- Red/blue player sprites = the config players (one per squad member, jersey number drawn on top)
- A chevron marks the player you control; the rest of the team are AI
- Soccer ball sprite (drawn on top of the bodies so it is never hidden)
- White rectangles = Goals
- A corner panel per team lists every player's name + stamina bar (controlled player marked)

---

## Architecture

### Module Breakdown

| File              | Responsibility                                      |
|-------------------|-----------------------------------------------------|
| `conf.lua`        | Love2D window settings (800×600, title, vsync)      |
| `main.lua`        | Love2D callbacks: load, update, draw, keypressed    |
| `src/game.lua`    | Game state machine (menu → playing → paused → over) |
| `src/field.lua`   | Draw pitch, centre circle, halfway line, goal boxes |
| `src/ball.lua`    | Ball position, velocity, friction, wall bouncing    |
| `src/player.lua`  | One on-pitch config player: attributes, movement, kick, stamina, formation AI |
| `src/goal.lua`    | Goal zone rectangles, collision detection, scoring  |
| `src/ui.lua`      | HUD (score, timer, stamina, names/stats), menu, game-over |
| `src/config.lua`  | Single config source: team/player names + attributes (1–10) |
| `src/audio.lua`   | Music / SFX loader and playback (OGG, WAV fallback) |

### Game States

```
MENU  ──(Enter)──►  PLAYING  ──(P)──►  PAUSED
                      │                   │
                   (timer=0)           (P/R)
                      │                   │
                  (if draw)          PLAYING / MENU
                      │
                      ▼
                  OVERTIME  ──(goal)──►  GAME_OVER
                      │
                   (no draw)
                      │
                      ▼
                  GAME_OVER
```

---

## Implementation Phases

### Phase 1 – Project Skeleton ✅
- [x] Repository initialised
- [x] `README.md` updated
- [x] `docs/plan.md` created
- [x] `conf.lua` – window configuration
- [x] `main.lua` – Love2D entry point wired up

### Phase 2 – Core Gameplay ✅
- [x] `src/field.lua` – pitch and goal rendering
- [x] `src/ball.lua` – ball with velocity and friction
- [x] `src/player.lua` – player movement and kick
- [x] `src/goal.lua` – goal detection and score increment
- [x] `src/game.lua` – tie everything together in update/draw
- [x] Sudden-death overtime when match ends in a draw

### Phase 3 – UI & Polish ✅
- [x] `src/ui.lua` – score display, countdown timer
- [x] Menu screen (title + instructions)
- [x] Game-over screen (winner announcement, restart prompt)
- [x] Pause overlay

### Phase 4 – Stamina ✅
- [x] Per-player stamina (`src/player.lua`); stamina drains while running/kicking, fatigue scales speed and kick power
- [x] Players recover stamina by **resting** (standing still) — no bench
- [x] Per-team corner panel lists every player's name + stamina bar, marking the controlled player (`src/ui.lua`)
- *Note:* an earlier bench/substitution system (`Q`/`K`, `Player:substitute()`, AI auto-subs) was **removed** when the whole squad moved onto the pitch — there's no bench to sub from.

### Phase 5 – Full teams, control & AI
- [x] Whole config squad on the pitch — every config player is its own on-pitch `Player`; no anonymous extras and no goalkeeper role (`src/player.lua`, `buildTeam` in `src/game.lua`)
- [x] Pass & control-switch — control the player on the ball; the kick key passes to a team-mate and hands you control of them; control follows loose balls (modelled on `soccer.py`; `control1`/`control2`, `humanKick`, `updatePossession` in `src/game.lua`)
- [ ] Smarter rule-based AI: positioning, defending, anticipating the ball (off-ball AI is a simple chase/formation-hold)
- [x] Difficulty selector on menu (Easy / Medium / Hard) — config-driven names + taglines, scaling the AI's `aiSpeed` / `aiKick`
- [ ] Optional sprint key (hold to move faster, drains stamina quicker)
- [ ] Optional goalkeeper role (e.g. a config flag) so a config player can guard the net

### Phase 6 – Audio & Assets ✅
- [x] Generated pixel-art sprites for ball, players, field grass, and menu banner (see `assets/` and `tools/generate_assets.py`)
- [x] SFX with randomised variants: kick (`kick0-3`), goal (`goal0-1`), bounce, substitution, whistle
- [x] Looping background theme music (streamed `theme.ogg`) on the menu / results screens
- [x] Crowd ambience bed during live play; kickoff jingle (`start.ogg`); footstep loop (`move.ogg`)
- [x] OGG-first loader (`src/audio.lua`) with WAV fallbacks for cues that only exist as WAV

#### Audio scene model
The state machine drives the soundscape: theme music loops on `menu`/`gameover`,
and on kickoff it stops the theme, starts the crowd bed, plays the start jingle +
whistle. The crowd bed runs through `playing`/`overtime`/`goal`; pausing stops the
crowd and movement loop and unpausing resumes them. The movement loop follows
**human** players only (so the AI chasing the ball doesn't drone constantly).

### Phase 7 – Packaging (Future)
- [ ] Bundle into `.love` archive for easy distribution
- [ ] Build scripts for Windows / macOS / Linux executables

---

## Screen Layout (800 × 600)

```
┌─────────────────────────────────────────────────┐
│  [Score: 0 – 0]              [Time: 1:30]        │
│                                                  │
│  ┌──┐                                    ┌──┐    │
│  │G │     ·····················          │G │    │
│  │o │   ·                       ·        │o │    │
│  │a │  ·        ⊙ (centre)       ·       │a │    │
│  │l │   ·                       ·        │l │    │
│  │  │     ·····················          │  │    │
│  └──┘   ① (P1 red)  ② (P2 blue)         └──┘    │
│                   ○ (ball)                       │
└─────────────────────────────────────────────────┘
```

- **Field**: 700 × 480 px, centred on screen
- **Goals**: 20 × 120 px, centred vertically on each side
- **HUD strip**: 40 px at the top
- The sketch shows one player per side (①/②); in play each side fields its whole
  config squad (default three players) spread across its half (see *Teams & Control*)

---

## Controls Reference

| Action        | Player 1   | Player 2        |
|---------------|------------|-----------------|
| Move Up       | W          | ↑ Up Arrow      |
| Move Down     | S          | ↓ Down Arrow    |
| Move Left     | A          | ← Left Arrow    |
| Move Right    | D          | → Right Arrow   |
| Pass / Shoot  | F          | L               |

| Global        | Key         |
|---------------|-------------|
| Start / OK    | Enter       |
| Pause/Resume  | P           |
| Restart       | R           |
| Quit to Menu  | Escape      |

---

## Technical Notes

- **Language**: Lua 5.1 (bundled with LÖVE2D)
- **Framework**: LÖVE2D 11.x
- **Physics**: Custom simple AABB + velocity; no physics library needed
- **Pass / shoot mechanic**: When `F`/`L` is pressed and the controlled player is
  on the ball, pass to the best team-mate ahead and switch control to them
  (`humanKick`/`passBallTo` in `src/game.lua`); with none open, shoot at goal.
  Control otherwise follows whoever wins the ball (`updatePossession`). AI players
  still kick by impulse toward goal when near the ball (`Player:kick`)
- **Ball friction**: Ball velocity multiplied by `0.98` each frame (60 fps)
- **Wall bounce**: Ball reflects off field boundary walls; goals pass through
  the goal opening
- **Attributes**: Each member's `speed`/`strength`/`stamina` (1–10) map to a
  derived `speedPx` (run speed), `kickPower` (kick impulse / distance), and
  `maxStamina` (life capacity). See *Player Attributes & Config* above.
- **Stamina**: Per-player, capped at that player's own `maxStamina`. A player
  drains `DRAIN_MOVE`/s while running plus `KICK_COST` per kick, and regenerates
  `REGEN_REST`/s while standing still (no bench). Speed and kick power scale
  linearly with the player's stamina **fraction** (floored at `MIN_SPEED_MUL` /
  `MIN_KICK_MUL`). Stamina **persists** across goal kickoffs and into overtime —
  only `Player:reset()` repositions, it never refills.
- **Kick cooldown**: `Player:kick()` (the AI's kick toward goal) is gated by
  `KICK_COOLDOWN` so a kick is a discrete action. The AI auto-kicks every frame it
  is near the ball; without the cooldown the per-kick stamina cost would be paid
  every frame and drain a full bar in a fraction of a second. (Human kicks are
  passes/shots handled in `game.lua`, not here.)

---

## Milestones

| Milestone          | Target       | Status      |
|--------------------|--------------|-------------|
| Project skeleton   | Week 1       | ✅ Done     |
| Playable prototype | Week 2       | ✅ Done     |
| Polished v1.0      | Week 3       | ✅ Done     |
| Stamina            | Week 4       | ✅ Done     |
| Full teams + passing | Week 5     | ✅ Done     |
| Smarter AI         | Week 6       | 🔲 Planned  |
| Audio integration  | Week 5       | ✅ Done     |
| Packaged release   | Week 6       | 🔲 Planned  |
