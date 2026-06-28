# ATB WorldCup – Project Plan

## Overview

ATB WorldCup is a simple arcade-style 2D football (soccer) game built with
[LÖVE2D](https://love2d.org/). The goal is to create a fun, quick-to-play
game that ATB colleagues can enjoy during breaks.

---

## Game Design

### Core Concept

- Top-down 2D football pitch
- Two teams of one player each (1v1)
- Kick the ball into the opponent's goal to score
- 90-second match; highest score wins
- If tied at full time, sudden-death overtime (first goal wins)

### Visual Style

- Simple solid-color geometric shapes (no sprites required to run)
- Green pitch with white lines
- Red circle = Player 1, Blue circle = Player 2
- White/yellow circle = Ball
- White rectangles = Goals

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
| `src/player.lua`  | Player movement, kick mechanic, simple AI logic     |
| `src/goal.lua`    | Goal zone rectangles, collision detection, scoring  |
| `src/ui.lua`      | HUD (score, timer), menu screen, game-over screen   |

### Game States

```
MENU  ──(Enter)──►  PLAYING  ──(P)──►  PAUSED
                      │                   │
                   (timer=0)           (P/R)
                      │                   │
                      ▼                   ▼
                  GAME_OVER          PLAYING / MENU
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

### Phase 3 – UI & Polish ✅
- [x] `src/ui.lua` – score display, countdown timer
- [x] Menu screen (title + instructions)
- [x] Game-over screen (winner announcement, restart prompt)
- [x] Pause overlay

### Phase 4 – AI Opponent (Future)
- [ ] Simple rule-based AI: move toward ball, kick when close
- [ ] Difficulty selector on menu (Easy / Medium / Hard)

### Phase 5 – Audio & Assets (Future)
- [ ] Kick sound effect
- [ ] Goal celebration sound
- [ ] Background music loop
- [ ] Optional sprite sheet for players and ball

### Phase 6 – Packaging (Future)
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

---

## Milestones

| Milestone          | Target       | Status      |
|--------------------|--------------|-------------|
| Project skeleton   | Week 1       | ✅ Done     |
| Playable prototype | Week 2       | ✅ Done     |
| Polished v1.0      | Week 3       | ✅ Done     |
| AI opponent        | Week 4       | 🔲 Planned  |
| Audio integration  | Week 5       | 🔲 Planned  |
| Packaged release   | Week 6       | 🔲 Planned  |
