# ATB WorldCup – Project Plan

## Overview

ATB WorldCup is a simple arcade-style 2D football (soccer) game built with
[LÖVE2D](https://love2d.org/). The goal is to create a fun, quick-to-play
game that ATB colleagues can enjoy during breaks.

---

## Game Design

### Core Concept

- Top-down 2D football pitch
- Two teams, each with a **3-player squad**: one player on the pitch, two on the bench
- Kick the ball into the opponent's goal to score
- 90-second match; highest score wins
- If tied at full time, sudden-death overtime (first goal wins)

### Stamina & Substitutions

The on-pitch player is the only member controlled at any time. Fatigue turns
squad rotation into the core strategic layer:

- Each player has a **stamina** bar whose maximum is set by their stamina
  attribute (see below). It drains faster while moving and a flat amount per
  kick; it ticks down slowly even while standing.
- Low stamina **slows movement** (down to ~55% speed at empty) and **weakens
  kicks** (down to ~60% power at empty), as a fraction of that player's own max.
- Pressing the **substitute** key swaps the active player for the freshest
  player on the bench. The pitch position is kept, so control is seamless.
- Benched players **recover stamina** while resting. A short cooldown
  (~1.2 s) prevents spamming substitutions.
- The AI manages its own fitness: it automatically subs a tired player off when
  a sufficiently rested replacement is available.

**Tuning constants** (in `src/player.lua`): move-drain 5/s · idle-drain 1.5/s ·
kick cost 8 · kick cooldown 0.3 s · bench regen 6/s · sub cooldown 1.2 s ·
min speed 55% · min kick 60%.

### Player Attributes & Config

Each player is named and rated on a **1–10** scale for three attributes, defined
in the `TEAMS` table in [`src/config.lua`](../src/config.lua) — the single config
source of truth, validated on load (out-of-range values are clamped, missing
fields defaulted) so a hand-edit can't crash the game. Each team also has a
display `name` (`Config.teamName`), shown in the HUD, on goals, and on full time:

| Attribute  | Drives          | Mapping (in `src/player.lua`)                     |
|------------|-----------------|---------------------------------------------------|
| `speed`    | run speed       | `SPEED_BASE + attr·SPEED_PER` → 110–200 px/s       |
| `strength` | kick distance   | `KICK_BASE + attr·KICK_PER` → 230–500 impulse      |
| `stamina`  | max stamina/life| `attr·STAMINA_PER` → 10–100 capacity                |

Each squad member carries its own derived `speedPx`, `kickPower`, and
`maxStamina`. Because drain is in absolute points/sec but `maxStamina` scales
with the attribute, high-stamina players simply last longer; speed/kick fatigue
and the AI's auto-sub thresholds all work on the **fraction** of each player's
own max, so squads with different staminas compare fairly.

Default rosters *(speed/strength/stamina)* — team 1 **Business** (left/red):
Rei (7/7/8), Sahabub (8/8/9), Rifa (7/3/6); team 2 **Tech** (right/blue):
Mazhar (5/10/6), Swapon (7/8/8), Sadia (10/2/6).

### Visual Style

- Generated pixel-art sprites with shape-based fallback (sprites live in `assets/` and are optional)
- Green pitch with white lines and a subtle grass texture
- Red/blue player sprites = active players (shaded per squad member, jersey number drawn on top)
- Soccer ball sprite
- White rectangles = Goals
- Stamina bar + bench pips for each team in the top corners of the pitch

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
| `src/player.lua`  | Squad roster, attributes, movement, kick, stamina, subs, AI |
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

### Phase 4 – Squad & Substitutions ✅
- [x] 3-player squad per team with per-member stamina (`src/player.lua`)
- [x] Stamina drains while moving/kicking; fatigue scales speed and kick power
- [x] `Player:substitute()` swaps in the freshest bench player (with cooldown)
- [x] Bench players recover stamina while resting
- [x] AI auto-substitutes tired players for rested ones
- [x] Stamina bars, bench pips, and sub-key hints in the HUD (`src/ui.lua`)
- [x] `Q` / `K` substitution keys wired into the game loop (`src/game.lua`)

### Phase 5 – AI Opponent (Future)
- [ ] Smarter rule-based AI: positioning, defending, anticipating the ball
- [ ] Difficulty selector on menu (Easy / Medium / Hard)
- [ ] Optional sprint key (hold to move faster, drains stamina quicker)
- [ ] Limited substitution count per match (more sim-like)

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

---

## Controls Reference

| Action        | Player 1   | Player 2        |
|---------------|------------|-----------------|
| Move Up       | W          | ↑ Up Arrow      |
| Move Down     | S          | ↓ Down Arrow    |
| Move Left     | A          | ← Left Arrow    |
| Move Right    | D          | → Right Arrow   |
| Kick          | F          | L               |
| Substitute    | Q          | K               |

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
- **Kick mechanic**: When `F`/`L` is pressed and the ball is within 40 px of
  the player centre, apply an impulse in the direction from player to ball
- **Ball friction**: Ball velocity multiplied by `0.98` each frame (60 fps)
- **Wall bounce**: Ball reflects off field boundary walls; goals pass through
  the goal opening
- **Attributes**: Each member's `speed`/`strength`/`stamina` (1–10) map to a
  derived `speedPx` (run speed), `kickPower` (kick impulse / distance), and
  `maxStamina` (life capacity). See *Player Attributes & Config* above.
- **Stamina**: Per-member, capped at that member's own `maxStamina`. The active
  member drains `DRAIN_MOVE`/s while moving (`DRAIN_IDLE`/s otherwise) plus
  `KICK_COST` per kick; bench members regenerate `REGEN_BENCH`/s up to their max.
  Speed and kick power scale linearly with the active member's stamina
  **fraction** (floored at `MIN_SPEED_MUL` / `MIN_KICK_MUL`). Stamina
  **persists** across goal kickoffs and into overtime — only `Player:reset()`
  repositions, it never refills.
- **Substitution**: `Player:substitute()` selects the freshest bench member (by
  stamina fraction) and makes it active in the same pitch slot, gated by
  `SUB_COOLDOWN`.
- **Kick cooldown**: `Player:kick()` is gated by `KICK_COOLDOWN` so a kick is a
  discrete action. The AI auto-kicks every frame it is near the ball; without
  the cooldown the per-kick stamina cost would be paid every frame and drain a
  full bar in a fraction of a second.

---

## Milestones

| Milestone          | Target       | Status      |
|--------------------|--------------|-------------|
| Project skeleton   | Week 1       | ✅ Done     |
| Playable prototype | Week 2       | ✅ Done     |
| Polished v1.0      | Week 3       | ✅ Done     |
| Squad & subs       | Week 4       | ✅ Done     |
| AI opponent        | Week 5       | 🔲 Planned  |
| Audio integration  | Week 5       | ✅ Done     |
| Packaged release   | Week 6       | 🔲 Planned  |
