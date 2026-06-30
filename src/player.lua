-- src/player.lua: Player entity, movement, kick, stamina, substitutions and simple AI

local Field  = require("src.field")
local Assets = require("src.assets")
local Audio  = require("src.audio")
local Config = require("src.config")

local Player = {}
Player.__index = Player

local KICK_RANGE    = 40    -- px – how close the player must be to kick
local KICK_COOLDOWN = 0.3   -- min seconds between kicks (rate-limits the AI's
                            -- per-frame auto-kick so it spends stamina sanely)
local RADIUS        = 14    -- visual radius
local AI_RANGE      = 35    -- AI auto-kick reach

-- ─── Per-player attribute → game mapping (attributes are a 1–10 scale) ────────
-- speed    → run speed in px/sec
-- strength → kick impulse (how far the ball travels)
-- stamina  → maximum stamina ("life")
local SPEED_BASE  = 100   -- px/s at speed 0      → attr 1..10 maps to 110..200
local SPEED_PER   = 10
local KICK_BASE   = 200   -- impulse at strength 0 → attr 1..10 maps to 230..500
local KICK_PER    = 30
local STAMINA_PER = 10    -- max stamina per stamina point → attr 1..10 = 10..100

local function speedToPx(attr)      return SPEED_BASE + attr * SPEED_PER end
local function strengthToKick(attr) return KICK_BASE  + attr * KICK_PER  end
local function staminaToMax(attr)   return attr * STAMINA_PER end

-- ─── Stamina / substitution tuning ───────────────────────────────────────────
local DRAIN_MOVE    = 5.0    -- stamina/sec drained while the active player moves
local DRAIN_IDLE    = 1.5    -- stamina/sec drained while the active player stands
local KICK_COST     = 8      -- stamina spent per kick
local REGEN_BENCH   = 6.0    -- stamina/sec recovered while resting on the bench
local SUB_COOLDOWN  = 1.2    -- seconds enforced between substitutions
local MIN_SPEED_MUL = 0.55   -- movement speed multiplier at 0 stamina
local MIN_KICK_MUL  = 0.60   -- kick power multiplier at 0 stamina

-- AI substitution behaviour, as a fraction of the player's own max stamina
local AI_SUB_THRESHOLD = 0.35  -- AI subs when active stamina drops below this frac
local AI_SUB_TARGET    = 0.70  -- ...and a bench player is at least this fresh

-- Jersey numbers per team for the on-pitch badge (cosmetic)
local JERSEYS = {
    [1] = {9, 7, 11},
    [2] = {10, 8, 4},
}

-- Stamina fraction (0..1) of a roster member, guarding against a zero max
local function memberFrac(m)
    if not m.maxStamina or m.maxStamina <= 0 then return 0 end
    return m.stamina / m.maxStamina
end

function Player.new(team, controlScheme, aiMods)
    -- team: 1 = left/red, 2 = right/blue
    -- controlScheme: "wasd", "arrows", or "ai"
    -- aiMods (AI only): { speed = mul, kick = mul } from the chosen difficulty
    local self = setmetatable({}, Player)
    self.team    = team
    self.control = controlScheme
    self.radius  = RADIUS

    -- Difficulty multipliers — 1.0 (no effect) for human players
    self.aiSpeedMul = (aiMods and aiMods.speed) or 1
    self.aiKickMul  = (aiMods and aiMods.kick)  or 1

    -- Build the squad from the config: each member carries its own attributes,
    -- the derived speed/kick/max-stamina, and current stamina (starting full).
    self.roster = {}
    for i, p in ipairs(Config.squad(team)) do
        local maxStamina = staminaToMax(p.stamina)
        self.roster[i] = {
            name         = p.name,
            attrSpeed    = p.speed,
            attrStrength = p.strength,
            attrStamina  = p.stamina,
            speedPx      = speedToPx(p.speed),       -- run speed (px/s)
            kickPower    = strengthToKick(p.strength), -- kick impulse
            maxStamina   = maxStamina,
            stamina      = maxStamina,
            number       = (JERSEYS[team] and JERSEYS[team][i]) or i,
        }
    end
    self.active       = 1     -- index of the member currently on the pitch
    self.subCooldown  = 0     -- seconds until another substitution is allowed
    self.subFlash     = 0     -- brief visual pulse after a substitution
    self.kickCooldown = 0     -- seconds until another kick is allowed

    self:reset()
    return self
end

-- Reset on-pitch position/velocity (kickoff). Stamina and roster are preserved
-- on purpose so fatigue carries across goals and overtime.
function Player:reset()
    if self.team == 1 then
        self.x = Field.x + 160
        self.baseColor = {0.9, 0.15, 0.15}
    else
        self.x = Field.right - 160
        self.baseColor = {0.15, 0.35, 0.9}
    end
    self.y  = Field.cy
    self.vx = 0
    self.vy = 0
    -- Formation home (used when this captain is an off-ball supporter) and the
    -- facing direction used to aim passes; default toward the opponent goal.
    self.homeX, self.homeY = self.x, self.y
    self.faceX = (self.team == 1) and 1 or -1
    self.faceY = 0
    self.holdoff = 0   -- brief lockout after passing (can't reclaim the ball)
end

-- Returns the unit vector from player to ball (or 0,0 if at same position)
local function dirToBall(px, py, bx, by)
    local dx = bx - px
    local dy = by - py
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return 0, 0 end
    return dx / len, dy / len
end

-- The member currently on the pitch
function Player:activeMember()
    return self.roster[self.active]
end

-- Stamina of the on-pitch member as a 0..1 fraction of its own max
function Player:staminaFrac()
    return memberFrac(self:activeMember())
end

-- Index and fraction of the freshest bench member (highest stamina fraction),
-- or nil if none. Fraction (not raw points) so squads with different max
-- staminas compare fairly.
function Player:freshestBench()
    local bestIdx, bestFrac
    for i, m in ipairs(self.roster) do
        if i ~= self.active then
            local f = memberFrac(m)
            if not bestFrac or f > bestFrac then
                bestIdx, bestFrac = i, f
            end
        end
    end
    return bestIdx, bestFrac
end

-- Swap the on-pitch member with the freshest bench member. The pitch slot
-- (position/velocity) is kept, so control is seamless. Honours the cooldown.
function Player:substitute()
    if self.subCooldown > 0 then return false end
    local benchIdx = self:freshestBench()
    if not benchIdx then return false end
    self.active      = benchIdx
    self.subCooldown = SUB_COOLDOWN
    self.subFlash    = 0.4
    Audio.playSubstitute()
    return true
end

-- Advance only the cosmetic substitution flash. Used during the post-goal
-- freeze when the full update loop (and its timers) is paused.
function Player:tickFlash(dt)
    self.subFlash = math.max(0, self.subFlash - dt)
end

-- opts (all optional) decide how the captain moves this frame:
--   humanMove = {x, y}  → driven by a human (this captain is the active player)
--   moveTo    = {x, y}  → AI: head for this support point instead of the ball
--   autoKick  = false   → AI: don't auto-kick (used on a human team's off-ball captain)
--   autoSub   = false   → AI: don't auto-substitute (humans sub manually)
-- With no humanMove/moveTo the captain runs the simple ball-chasing AI.
function Player:update(dt, ball, opts)
    opts = opts or {}
    self.subCooldown  = math.max(0, self.subCooldown - dt)
    self.subFlash     = math.max(0, self.subFlash - dt)
    self.kickCooldown = math.max(0, self.kickCooldown - dt)
    self.holdoff      = math.max(0, (self.holdoff or 0) - dt)

    local moveX, moveY = 0, 0

    if opts.humanMove then
        moveX, moveY = opts.humanMove[1], opts.humanMove[2]
    else
        -- AI: steer toward a support point if given, otherwise toward the ball.
        local tx = opts.moveTo and opts.moveTo[1] or ball.x
        local ty = opts.moveTo and opts.moveTo[2] or ball.y
        local dx, dy = tx - self.x, ty - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 5 then
            moveX, moveY = dx / dist, dy / dist
        end
        -- Auto-kick toward the opponent goal when close to the ball (AI teams).
        if opts.autoKick ~= false then
            local bdx, bdy = ball.x - self.x, ball.y - self.y
            if (bdx * bdx + bdy * bdy) <= AI_RANGE * AI_RANGE then
                local goalX = (self.team == 1) and Field.right or Field.x
                self:kick(ball, goalX, Field.cy)
            end
        end
        -- AI manages its own fitness: sub off a tired player for a fresh one
        if opts.autoSub ~= false then
            if self:staminaFrac() < AI_SUB_THRESHOLD then
                local _, benchFrac = self:freshestBench()
                if benchFrac and benchFrac >= AI_SUB_TARGET then
                    self:substitute()
                end
            end
        end
    end

    -- Fatigue scales movement speed; base speed comes from the player's attribute
    local member   = self:activeMember()
    local frac     = self:staminaFrac()
    local speedMul = MIN_SPEED_MUL + (1 - MIN_SPEED_MUL) * frac

    -- Normalise diagonal movement and apply
    local len = math.sqrt(moveX * moveX + moveY * moveY)
    local isMoving = len > 0
    self.moving = isMoving   -- read by the audio layer for the movement loop
    local dirX, dirY = 0, 0
    if isMoving then
        dirX, dirY = moveX / len, moveY / len
        local spd = member.speedPx * speedMul * self.aiSpeedMul
        self.x = self.x + dirX * spd * dt
        self.y = self.y + dirY * spd * dt
        self.faceX, self.faceY = dirX, dirY   -- remember facing for aiming passes
    end

    -- Drain the active member; regenerate everyone on the bench (to its own max)
    member.stamina = math.max(0, member.stamina - (isMoving and DRAIN_MOVE or DRAIN_IDLE) * dt)
    for i, m in ipairs(self.roster) do
        if i ~= self.active then
            m.stamina = math.min(m.maxStamina, m.stamina + REGEN_BENCH * dt)
        end
    end

    -- Clamp to field boundaries
    self.x = math.max(Field.x + self.radius,     math.min(Field.right  - self.radius, self.x))
    self.y = math.max(Field.y + self.radius,     math.min(Field.bottom - self.radius, self.y))

    -- Push ball on collision (player circle vs ball circle)
    local dx = ball.x - self.x
    local dy = ball.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local minDist = self.radius + ball.radius
    if dist < minDist and dist > 0 then
        -- Separate
        local overlap = minDist - dist
        local nx = dx / dist
        local ny = dy / dist
        ball.x = ball.x + nx * overlap
        ball.y = ball.y + ny * overlap
        -- Transfer some of the player's movement energy (also fatigue-scaled)
        local effSpeed = member.speedPx * speedMul * self.aiSpeedMul
        local relVx = ball.vx - (dirX * effSpeed)
        local relVy = ball.vy - (dirY * effSpeed)
        local dot = relVx * nx + relVy * ny
        if dot < 0 then
            ball.vx = ball.vx - dot * nx * 0.6
            ball.vy = ball.vy - dot * ny * 0.6
        end
    end
end

-- Called on keypress for human kick (and every frame by the AI when close).
-- A cooldown makes a kick a discrete action: without it the AI's per-frame
-- auto-kick would pay KICK_COST every frame and empty its stamina in a flash.
-- Optional aimX/aimY: kick the ball toward that point (the AI aims at the
-- opponent goal). Without it, kick along the player→ball line so a human's kick
-- follows the direction they are pushing.
function Player:kick(ball, aimX, aimY)
    if self.kickCooldown > 0 then return end
    if ball:isNear(self.x, self.y, KICK_RANGE) then
        local nx, ny
        if aimX then
            nx, ny = dirToBall(ball.x, ball.y, aimX, aimY)
        else
            nx, ny = dirToBall(self.x, self.y, ball.x, ball.y)
        end
        if nx == 0 and ny == 0 then
            -- kick straight ahead toward opponent goal
            nx = (self.team == 1) and 1 or -1
        end
        local member  = self:activeMember()
        local kickMul = MIN_KICK_MUL + (1 - MIN_KICK_MUL) * self:staminaFrac()
        -- Strength sets how far the ball travels; fatigue and difficulty scale it
        local power = member.kickPower * kickMul * self.aiKickMul
        ball:applyImpulse(nx * power, ny * power)

        -- Kicking costs stamina and arms the cooldown
        member.stamina = math.max(0, member.stamina - KICK_COST)
        self.kickCooldown = KICK_COOLDOWN
        Audio.playKick()
    end
end

-- Per-member body colour: team colour, dimmed slightly per squad index so a
-- substitution is visible on the pitch.
function Player:bodyColor()
    local shade = 1.0 - (self.active - 1) * 0.12
    local c = self.baseColor
    return { c[1] * shade, c[2] * shade, c[3] * shade }
end

function Player:draw()
    local sprite = Assets.playerSprite(self.team, self.active)

    -- Substitution pulse ring
    if self.subFlash > 0 then
        love.graphics.setColor(1, 1, 1, self.subFlash)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", self.x, self.y, self.radius + 6 + (0.4 - self.subFlash) * 20)
    end

    if sprite then
        local w, h = sprite:getDimensions()
        -- Shade variants per active roster slot make substitutions visible.
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, self.x - w / 2, self.y - h / 2)
    else
        -- Fallback shape rendering
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.circle("fill", self.x + 3, self.y + 4, self.radius)

        -- Body
        love.graphics.setColor(self:bodyColor())
        love.graphics.circle("fill", self.x, self.y, self.radius)

        -- Outline
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.x, self.y, self.radius)
    end

    -- Jersey number of the active member
    love.graphics.setColor(1, 1, 1)
    local label = tostring(self:activeMember().number)
    local font  = love.graphics.getFont()
    local tw    = font:getWidth(label)
    local th    = font:getHeight()
    love.graphics.print(label, self.x - tw / 2, self.y - th / 2)
end

return Player
