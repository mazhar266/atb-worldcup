-- src/player.lua: one on-field footballer — a single player from src/config.lua.
--
-- Every player listed in a team's config squad is its OWN on-field entity: there
-- are no anonymous extras and no hidden bench, so a 3-player squad is literally a
-- 3-a-side match of the named players. You control one team-mate at a time;
-- control follows the ball and the pass key hands control to whoever you pass to
-- (that FIFA-style logic lives in src/game.lua). Each player carries its own
-- speed/strength/stamina from the config and tires as it runs.

local Field  = require("src.field")
local Assets = require("src.assets")
local Audio  = require("src.audio")
local Config = require("src.config")

local Player = {}
Player.__index = Player

local RADIUS        = 14    -- visual radius
local KICK_RANGE    = 40    -- px – how close to the ball an AI player can kick
local KICK_COOLDOWN = 0.3   -- min seconds between an AI player's kicks
local AI_RANGE      = 35    -- AI auto-kick reach

-- ─── Attribute → game mapping (attributes are a 1–10 scale) ───────────────────
-- speed → run speed (px/s) · strength → kick impulse · stamina → max "life"
local SPEED_BASE  = 100   -- attr 1..10 → 110..200 px/s
local SPEED_PER   = 10
local KICK_BASE   = 200   -- attr 1..10 → 230..500 impulse
local KICK_PER    = 30
local STAMINA_PER = 10    -- attr 1..10 → 10..100 capacity

local function speedToPx(attr)      return SPEED_BASE + attr * SPEED_PER end
local function strengthToKick(attr) return KICK_BASE  + attr * KICK_PER  end
local function staminaToMax(attr)   return attr * STAMINA_PER end

-- ─── Stamina tuning ───────────────────────────────────────────────────────────
-- There is no bench any more (the whole squad is on the pitch), so players
-- recover by *resting* — standing still regenerates stamina, running drains it.
local DRAIN_MOVE    = 8.0    -- stamina/sec while running
local KICK_COST     = 8      -- stamina per kick
local REGEN_REST    = 5.0    -- stamina/sec recovered while (nearly) still
local MIN_SPEED_MUL = 0.55   -- movement multiplier at 0 stamina
local MIN_KICK_MUL  = 0.60   -- kick power multiplier at 0 stamina

-- Off-ball AI: how strongly a player drifts from its home toward the ball, so the
-- shape pushes up and drops back with play instead of standing still.
local FORM_BIAS_X   = 0.55
local FORM_BIAS_Y   = 0.45

-- Jersey numbers per team, indexed by squad position (cosmetic)
local JERSEYS = {
    [1] = {9, 7, 11, 8, 4, 6, 10},
    [2] = {10, 8, 4, 7, 11, 6, 9},
}

-- Formation home positions as pitch fractions for the LEFT team (mirrored in x
-- for the right team), keyed by squad size; index = squad position. Any larger
-- squad falls back to a staggered spread.
local FORMATIONS = {
    [1] = {{0.30, 0.50}},
    [2] = {{0.24, 0.36}, {0.24, 0.64}},
    [3] = {{0.18, 0.50}, {0.40, 0.30}, {0.40, 0.70}},
    [4] = {{0.16, 0.50}, {0.34, 0.28}, {0.34, 0.72}, {0.48, 0.50}},
    [5] = {{0.12, 0.50}, {0.26, 0.30}, {0.26, 0.70}, {0.44, 0.36}, {0.44, 0.64}},
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Unit vector + length of (dx, dy); length is the third return value.
local function unit(dx, dy)
    local d = math.sqrt(dx * dx + dy * dy)
    if d == 0 then return 0, 0, 0 end
    return dx / d, dy / d, d
end

-- Home fraction for player `idx` of a squad of `total`.
local function homeFraction(idx, total)
    local f = FORMATIONS[total]
    if f and f[idx] then return f[idx][1], f[idx][2] end
    local fx = 0.16 + ((idx - 1) % 3) * 0.14
    local fy = (idx - 0.5) / total
    return fx, fy
end

-- team: 1 = left/red, 2 = right/blue
-- idx:  which config player (1..N)
-- total: squad size (drives the formation spread)
-- aiMods (AI side only): { speed = mul, kick = mul } from the chosen difficulty
function Player.new(team, idx, total, aiMods)
    local self = setmetatable({}, Player)
    local cfg  = Config.squad(team)[idx]

    self.team   = team
    self.index  = idx
    self.radius = RADIUS
    self.isLeft = (team == 1)

    self.name         = cfg.name
    self.attrSpeed    = cfg.speed
    self.attrStrength = cfg.strength
    self.attrStamina  = cfg.stamina
    self.speedPx      = speedToPx(cfg.speed)
    self.kickPower    = strengthToKick(cfg.strength)
    self.maxStamina   = staminaToMax(cfg.stamina)
    self.stamina      = self.maxStamina
    self.number       = (JERSEYS[team] and JERSEYS[team][idx]) or idx

    self.aiSpeedMul = (aiMods and aiMods.speed) or 1
    self.aiKickMul  = (aiMods and aiMods.kick)  or 1

    self.baseColor = self.isLeft and {0.9, 0.15, 0.15} or {0.15, 0.35, 0.9}

    local fx, fy = homeFraction(idx, total)
    if not self.isLeft then fx = 1 - fx end
    self.homeX = Field.x + fx * Field.width
    self.homeY = Field.y + fy * Field.height

    self.kickCooldown = 0
    self.holdoff      = 0
    self:reset()
    return self
end

-- Stamina as a 0..1 fraction of this player's own max.
function Player:staminaFrac()
    if not self.maxStamina or self.maxStamina <= 0 then return 0 end
    return self.stamina / self.maxStamina
end

-- Reposition to the formation home (kickoff). Stamina is preserved on purpose so
-- fatigue carries across goals and into overtime — only position is reset here.
function Player:reset()
    self.x = self.homeX
    self.y = self.homeY
    self.vx, self.vy = 0, 0
    self.moving = false
    self.dirX, self.dirY = 0, 0
    self.faceX = self.isLeft and 1 or -1
    self.faceY = 0
    self.holdoff = 0
end

-- opts (all optional):
--   humanMove = {x, y}  → driven by a human (this player is the active one)
--   chase     = bool    → AI: go for the ball (the team's lead). Otherwise the
--                         player holds a ball-biased formation point.
--   autoKick  = false   → AI: don't auto-kick (a human team's off-ball players;
--                         the human kicks via the pass key instead)
function Player:update(dt, ball, opts)
    opts = opts or {}
    self.kickCooldown = math.max(0, self.kickCooldown - dt)
    self.holdoff      = math.max(0, (self.holdoff or 0) - dt)

    local moveX, moveY = 0, 0
    if opts.humanMove then
        moveX, moveY = opts.humanMove[1], opts.humanMove[2]
    elseif opts.chase then
        local ux, uy, bd = unit(ball.x - self.x, ball.y - self.y)
        moveX, moveY = ux, uy
        if opts.autoKick ~= false and bd <= AI_RANGE then
            local goalX = self.isLeft and Field.right or Field.x
            self:kick(ball, goalX, Field.cy)
        end
    else
        -- Hold a formation point that drifts toward the ball.
        local tx = self.homeX + (ball.x - self.homeX) * FORM_BIAS_X
        local ty = self.homeY + (ball.y - self.homeY) * FORM_BIAS_Y
        local ux, uy, d = unit(tx - self.x, ty - self.y)
        if d > 4 then moveX, moveY = ux, uy end
    end

    -- Fatigue scales movement speed
    local frac     = self:staminaFrac()
    local speedMul = MIN_SPEED_MUL + (1 - MIN_SPEED_MUL) * frac

    local len = math.sqrt(moveX * moveX + moveY * moveY)
    local isMoving = len > 0
    self.moving = isMoving
    local dirX, dirY = 0, 0
    if isMoving then
        dirX, dirY = moveX / len, moveY / len
        local spd = self.speedPx * speedMul * self.aiSpeedMul
        self.x = self.x + dirX * spd * dt
        self.y = self.y + dirY * spd * dt
        self.faceX, self.faceY = dirX, dirY   -- remember facing for aiming passes
    end

    -- Drain while running; recover while resting (clamped to own max)
    if isMoving then
        self.stamina = math.max(0, self.stamina - DRAIN_MOVE * dt)
    else
        self.stamina = math.min(self.maxStamina, self.stamina + REGEN_REST * dt)
    end

    -- Clamp to the pitch
    self.x = clamp(self.x, Field.x + self.radius, Field.right  - self.radius)
    self.y = clamp(self.y, Field.y + self.radius, Field.bottom - self.radius)

    -- Push the ball on body contact (circle vs circle)
    local dx = ball.x - self.x
    local dy = ball.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local minDist = self.radius + ball.radius
    if dist < minDist and dist > 0 then
        local overlap = minDist - dist
        local nx, ny = dx / dist, dy / dist
        ball.x = ball.x + nx * overlap
        ball.y = ball.y + ny * overlap
        local effSpeed = self.speedPx * speedMul * self.aiSpeedMul
        local relVx = ball.vx - dirX * effSpeed
        local relVy = ball.vy - dirY * effSpeed
        local dot = relVx * nx + relVy * ny
        if dot < 0 then
            ball.vx = ball.vx - dot * nx * 0.6
            ball.vy = ball.vy - dot * ny * 0.6
        end
    end
end

-- AI kick toward (aimX, aimY). A cooldown makes a kick a discrete action so the
-- per-frame auto-kick doesn't drain stamina instantly. Human kicks are passes /
-- shots handled in src/game.lua, not here.
function Player:kick(ball, aimX, aimY)
    if self.kickCooldown > 0 then return end
    if not ball:isNear(self.x, self.y, KICK_RANGE) then return end
    local nx, ny = unit((aimX or self.x) - ball.x, (aimY or self.y) - ball.y)
    if nx == 0 and ny == 0 then nx = self.isLeft and 1 or -1 end
    local kickMul = MIN_KICK_MUL + (1 - MIN_KICK_MUL) * self:staminaFrac()
    local power   = self.kickPower * kickMul * self.aiKickMul
    ball:applyImpulse(nx * power, ny * power)
    self.stamina = math.max(0, self.stamina - KICK_COST)
    self.kickCooldown = KICK_COOLDOWN
    Audio.playKick()
end

function Player:draw()
    local sprite = Assets.playerSprite(self.team, self.index)
    if sprite then
        local w, h = sprite:getDimensions()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, self.x - w / 2, self.y - h / 2)
    else
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.circle("fill", self.x + 3, self.y + 4, self.radius)
        -- Body
        love.graphics.setColor(self.baseColor)
        love.graphics.circle("fill", self.x, self.y, self.radius)
        -- Outline
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.x, self.y, self.radius)
    end

    -- Jersey number
    love.graphics.setColor(1, 1, 1)
    local label = tostring(self.number)
    local font  = love.graphics.getFont()
    love.graphics.print(label, self.x - font:getWidth(label) / 2, self.y - font:getHeight() / 2)
end

return Player
