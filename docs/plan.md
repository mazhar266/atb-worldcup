# ATB WorldCup – Project Plan

## Overview

ATB WorldCup is a simple arcade-style 2D football (soccer) game built with
[LÖVE2D](https://love2d.org/). The goal is to create a fun, quick-to-play
game that ATB colleagues can enjoy during breaks.

---

## Game Design

### Core Concept

- Top-down 2D football pitch
- **Full teams on the pitch** (FIFA-style): each side fields one controllable
  **captain** plus an AI **formation** — a goalkeeper and outfield runners — so the
  whole team moves with play (see *Teams & Formations* below)
- The captain is a **3-player squad**: one player on the pitch, two on the bench
- Kick the ball into the opponent's goal to score
- 90-second match; highest score wins
- If tied at full time, sudden-death overtime (first goal wins)

### Teams & Formations

Closely modelled on [Code-the-Classics `soccer.py`](https://github.com/Wireframe-Magazine/Code-the-Classics/blob/master/soccer-master/soccer.py),
each side puts a whole team on the pitch rather than a lone player:

- Each side has a named **captain** (`src/player.lua`, carrying the stamina/substitution
  depth below) plus a **formation** of AI runners in **`src/teammate.lua`**.
  `Teammate.formation()` builds one side's lineup from a `FORMATION` table — currently a
  **goalkeeper + 3 outfielders** (left-team anchors are mirrored in `x` for the right
  team). The runners are lightweight: fixed pace, no stamina or subs.
- **Formation behaviour:** the outfielder nearest the ball becomes the "lead" and chases
  it; the others hold a home anchor that drifts toward the ball, so the line pushes up and
  drops back with play. The **goalkeeper** tracks the ball along its goal line and rushes
  out to smother a close ball on its own side.

#### Control & passing (FIFA-style)

You drive **one** player at a time per team — the **controlled unit** (`game.lua`'s
`control1`/`control2`; the captain or any outfielder, never the keeper), mirroring
`soccer.py`'s `active_control_player`:

- **Control follows the ball.** While your active player is on the ball you keep control;
  otherwise control jumps to whichever of your players wins a loose ball (`updatePossession`).
- **The kick key is a pass.** When you're on the ball, `F`/`L` passes to the best team-mate
  *ahead in your facing direction* (`pickPassTarget`) and **hands you control of them**
  (`passBallTo` sets the new controlled unit) — you run onto your own pass. With no
  team-mate open it shoots at goal. A short `holdoff`/`passTimer` stops the passer reclaiming
  it and keeps mates from stealing the pass.
- A **chevron** marks the player you control; `resetControl()` re-points control to the unit
  nearest the ball at each kickoff.
- How each unit moves is chosen in `game.lua` and passed into `:update(dt, ball, opts)`
  (same `opts` for `Player` and `Teammate`): `humanMove` for the controlled unit, otherwise
  AI (`moveTo` support point, else chase). `autoKick=false`/`autoSub=false` keep a human
  team's off-ball players from blasting the ball or auto-subbing.
- Difficulty (`aiSpeed`/`aiKick`) scales the AI side's formation just like its captain.
- The formation is **additive** — it doesn't touch the squad/stamina invariants. Only the
  **captain carries stamina** (controlling a team-mate doesn't tire). Teammate tuning lives
  in `local` constants at the top of `src/teammate.lua`; passing/control tuning (`PASS_*`,
  `POSSESS_*`, `SHOOT_*`) is at the top of `src/game.lua`.

### Stamina & Substitutions

The captain's on-pitch member is the only player you control directly. Fatigue turns
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
- Red/blue player sprites = captains (shaded per squad member, jersey number drawn on top)
- Each side's AI formation drawn in the same team colours; goalkeepers wear a yellow ring
- Soccer ball sprite (drawn on top of the bodies so it is never hidden)
- White rectangles = Goals
- Stamina bar + bench pips for each team in the top corners of the pitch (captain only)

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
| `src/player.lua`  | Captain: squad roster, attributes, movement, kick, stamina, subs, AI |
| `src/teammate.lua`| AI formation: goalkeeper + outfield runners (chase, support, shoot) |
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
- [x] Full-team formations — goalkeeper + outfield runners per side that chase, support, and shoot, so all players run on the pitch FIFA-style (`src/teammate.lua`, wired in `src/game.lua`)
- [x] Pass & control-switch — control the player on the ball; the kick key passes to a team-mate and hands you control of them; control follows loose balls (modelled on `soccer.py`; `control1`/`control2`, `humanKick`, `updatePossession` in `src/game.lua`)
- [ ] Smarter rule-based AI: positioning, defending, anticipating the ball (captain AI is still a simple ball-chaser)
- [x] Difficulty selector on menu (Easy / Medium / Hard) — config-driven names + taglines, scaling the AI's `aiSpeed` / `aiKick`
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
- The sketch shows only the two captains (①/②); in play each side also fields a
  goalkeeper and three outfield runners spread across its half (see *Teams &
  Formations*)

---

## Controls Reference

| Action        | Player 1   | Player 2        |
|---------------|------------|-----------------|
| Move Up       | W          | ↑ Up Arrow      |
| Move Down     | S          | ↓ Down Arrow    |
| Move Left     | A          | ← Left Arrow    |
| Move Right    | D          | → Right Arrow   |
| Pass / Shoot  | F          | L               |
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
