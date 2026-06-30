-- src/teammate.lua: AI-controlled outfield teammates and goalkeepers.
--
-- The named 3-member squad in `src/player.lua` is the human's controllable
-- "captain" — the one carrying the stamina / substitution system. To fill the
-- pitch like a real match (the FIFA-style "all players running" look, inspired
-- by the Code-the-Classics `soccer.py`), each side ALSO fields a small formation
-- of lightweight AI runners defined here: a goalkeeper that guards the net plus
-- a few outfielders that chase, support, and shoot.
--
-- Teammates deliberately have NO stamina / substitution depth (only the captain
-- does) — they run at a fixed speed, hold a ball-aware formation, and kick toward
-- the opponent goal. This keeps the squad/stamina model in `player.lua` and its
-- invariants completely untouched; teammates are purely additive.

local Field  = require("src.field")
local Assets = require("src.assets")
local Audio  = require("src.audio")

local Teammate = {}
Teammate.__index = Teammate

local RADIUS        = 13    -- visual radius (captain is 14, so it reads as the lead)
local OUT_SPEED     = 150   -- outfield run speed (px/s)
local GK_SPEED      = 140   -- goalkeeper speed (px/s)
local KICK_RANGE    = 34    -- how close to the ball a teammate must be to kick
local KICK_COOLDOWN = 0.4   -- min seconds between one teammate's kicks
local OUT_KICK      = 300   -- outfield kick impulse (toward the opponent goal)
local GK_KICK       = 360   -- goalkeeper clearance impulse (upfield)
local DEADZONE      = 4     -- px target tolerance (stops jitter at the anchor)
local FORM_BIAS_X   = 0.55  -- how strongly an outfielder shifts toward the ball's x
local FORM_BIAS_Y   = 0.45  -- ...and toward the ball's y
local GK_INSET      = 26    -- goalkeeper resting distance from its own goal line
local GK_OUT_MAX    = 80    -- furthest a keeper strays from its own line
local GK_REACH      = 72    -- ball distance at which the keeper rushes off its line

-- Formation anchors for the LEFT team, as fractions of the pitch (mirrored in x
-- for the right team). The captain (`player.lua`) holds central midfield, so
-- these surround it: a keeper, two split defenders, and an advanced forward.
local FORMATION = {
    { role = "gk",  fx = 0.045, fy = 0.50 },
    { role = "out", fx = 0.22,  fy = 0.26 },
    { role = "out", fx = 0.22,  fy = 0.74 },
    { role = "out", fx = 0.42,  fy = 0.50 },
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Unit vector + length of (dx, dy). Length is returned as the third value.
local function unit(dx, dy)
    local d = math.sqrt(dx * dx + dy * dy)
    if d == 0 then return 0, 0, 0 end
    return dx / d, dy / d, d
end

-- team: 1 = left/red, 2 = right/blue
-- slot: a FORMATION entry { role, fx, fy }
-- idx:  position in the formation (drives the sprite shade variant)
-- aiMods (AI side only): { speed = mul, kick = mul } from the chosen difficulty
function Teammate.new(team, slot, idx, aiMods)
    local self = setmetatable({}, Teammate)
    self.team   = team
    self.role   = slot.role
    self.radius = RADIUS
    self.isLeft = (team == 1)

    -- Mirror the left-team fraction across the halfway line for the right team.
    local fx = self.isLeft and slot.fx or (1 - slot.fx)
    self.homeX = Field.x + fx * Field.width
    self.homeY = Field.y + slot.fy * Field.height

    self.color = self.isLeft and {0.9, 0.15, 0.15} or {0.15, 0.35, 0.9}

    -- Difficulty multipliers — 1.0 (no effect) for the human side.
    self.aiSpeedMul = (aiMods and aiMods.speed) or 1
    self.aiKickMul  = (aiMods and aiMods.kick)  or 1

    -- Sprite shade variant for a little visual variety across the formation.
    self.spriteIdx = (self.role == "gk") and 1 or (((idx - 1) % 3) + 1)

    self.kickCooldown = 0
    self:reset()
    return self
end

-- Build one team's formation (array of Teammates). aiMods scales the AI side.
function Teammate.formation(team, aiMods)
    local mates = {}
    for i, slot in ipairs(FORMATION) do
        mates[i] = Teammate.new(team, slot, i, aiMods)
    end
    return mates
end

-- Reposition to the formation home (kickoff). Cheap, side-effect free.
function Teammate:reset()
    self.x = self.homeX
    self.y = self.homeY
    self.moving = false
    self.dirX, self.dirY = 0, 0
    -- Facing (for aiming passes when a human is driving this team-mate) and the
    -- brief post-pass lockout; default facing toward the opponent goal.
    self.faceX = self.isLeft and 1 or -1
    self.faceY = 0
    self.holdoff = 0
end

-- The opponent's goal-line x (where outfielders aim their shots).
function Teammate:foeGoalX()
    return self.isLeft and Field.right or Field.x
end

-- This frame's movement target (tx, ty).
--   gk:    sit on the goal line tracking the ball's y; rush out to smother a
--          close ball on the keeper's own side of the pitch.
--   chaser:go straight for the ball (the team's "lead" player).
--   other: hold a formation anchor that drifts toward the ball, so the line
--          advances and retreats with play instead of standing still.
function Teammate:target(ball, chase)
    if self.role == "gk" then
        local lineX = self.isLeft and (Field.x + GK_INSET) or (Field.right - GK_INSET)
        local ty = clamp(ball.y, Field.goalTop - 10, Field.goalBottom + 10)
        ty = clamp(ty, Field.y + self.radius, Field.bottom - self.radius)

        local _, _, d = unit(ball.x - self.x, ball.y - self.y)
        local onOwnSide
        if self.isLeft then
            onOwnSide = ball.x < Field.x + 160
        else
            onOwnSide = ball.x > Field.right - 160
        end
        if d < GK_REACH and onOwnSide then
            return ball.x, ball.y
        end
        return lineX, ty
    end

    if chase then
        return ball.x, ball.y
    end

    local tx = self.homeX + (ball.x - self.homeX) * FORM_BIAS_X
    local ty = self.homeY + (ball.y - self.homeY) * FORM_BIAS_Y
    return tx, ty
end

-- opts (all optional):
--   humanMove = {x, y}  → driven by a human (this team-mate is the active player)
--   chase     = bool    → AI: this outfielder is the team's lead, go for the ball
--   autoKick  = false   → AI: don't auto-kick (human team's off-ball outfielders)
-- Keepers always auto-clear regardless of autoKick, and are never human-driven.
function Teammate:update(dt, ball, opts)
    opts = opts or {}
    self.kickCooldown = math.max(0, self.kickCooldown - dt)
    self.holdoff      = math.max(0, (self.holdoff or 0) - dt)

    local spd = ((self.role == "gk") and GK_SPEED or OUT_SPEED) * self.aiSpeedMul
    local moving, ux, uy

    if opts.humanMove then
        local mx, my = opts.humanMove[1], opts.humanMove[2]
        local len = math.sqrt(mx * mx + my * my)
        moving = len > 0
        ux, uy = (moving and mx / len or 0), (moving and my / len or 0)
    else
        local tx, ty = self:target(ball, opts.chase)
        local dx, dy = tx - self.x, ty - self.y
        local d = math.sqrt(dx * dx + dy * dy)
        moving = d > DEADZONE
        ux, uy = (moving and dx / d or 0), (moving and dy / d or 0)
    end

    self.moving = moving
    self.dirX, self.dirY = ux, uy
    if moving then
        self.x = self.x + ux * spd * dt
        self.y = self.y + uy * spd * dt
        self.faceX, self.faceY = ux, uy
    end

    -- Keepers stay in a box near their line; outfielders use the whole pitch.
    if self.role == "gk" then
        if self.isLeft then
            self.x = clamp(self.x, Field.x + self.radius, Field.x + GK_OUT_MAX)
        else
            self.x = clamp(self.x, Field.right - GK_OUT_MAX, Field.right - self.radius)
        end
    else
        self.x = clamp(self.x, Field.x + self.radius, Field.right - self.radius)
    end
    self.y = clamp(self.y, Field.y + self.radius, Field.bottom - self.radius)

    -- A human-driven outfielder kicks via the team's pass key (handled in
    -- game.lua), so it never auto-kicks. Keepers always clear; AI outfielders
    -- auto-kick only when allowed.
    if not opts.humanMove then
        if self.role == "gk" or opts.autoKick ~= false then
            self:tryKick(ball)
        end
    end

    self:pushBall(ball)
end

-- Kick the ball toward the opponent goal (outfield) or upfield (keeper clear).
function Teammate:tryKick(ball)
    if self.kickCooldown > 0 then return end
    if not ball:isNear(self.x, self.y, KICK_RANGE) then return end

    local aimX, aimY
    if self.role == "gk" then
        aimX, aimY = Field.cx, Field.cy        -- clear it upfield, away from goal
    else
        aimX, aimY = self:foeGoalX(), Field.cy
    end
    local nx, ny = unit(aimX - ball.x, aimY - ball.y)
    if nx == 0 and ny == 0 then nx = self.isLeft and 1 or -1 end

    local power = ((self.role == "gk") and GK_KICK or OUT_KICK) * self.aiKickMul
    ball:applyImpulse(nx * power, ny * power)
    self.kickCooldown = KICK_COOLDOWN
    Audio.playKick()
end

-- Push the ball on body contact (same circle-vs-circle as the captain).
function Teammate:pushBall(ball)
    local dx = ball.x - self.x
    local dy = ball.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local minDist = self.radius + ball.radius
    if dist < minDist and dist > 0 then
        local overlap = minDist - dist
        local nx, ny = dx / dist, dy / dist
        ball.x = ball.x + nx * overlap
        ball.y = ball.y + ny * overlap
        local spd = ((self.role == "gk") and GK_SPEED or OUT_SPEED) * self.aiSpeedMul
        local relVx = ball.vx - self.dirX * spd
        local relVy = ball.vy - self.dirY * spd
        local dot = relVx * nx + relVy * ny
        if dot < 0 then
            ball.vx = ball.vx - dot * nx * 0.6
            ball.vy = ball.vy - dot * ny * 0.6
        end
    end
end

function Teammate:draw()
    local sprite = Assets.playerSprite(self.team, self.spriteIdx)
    if sprite then
        local w, h = sprite:getDimensions()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, self.x - w / 2, self.y - h / 2)
    else
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.22)
        love.graphics.circle("fill", self.x + 3, self.y + 4, self.radius)
        -- Body (dimmed slightly so the captain's full-bright sprite stands out)
        local c = self.color
        love.graphics.setColor(c[1] * 0.85, c[2] * 0.85, c[3] * 0.85)
        love.graphics.circle("fill", self.x, self.y, self.radius)
        -- Outline
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.x, self.y, self.radius)
    end

    -- Keeper marker: a contrasting ring so the goalie reads at a glance.
    if self.role == "gk" then
        love.graphics.setColor(0.95, 0.85, 0.2, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.x, self.y, self.radius + 3)
    end
end

return Teammate
