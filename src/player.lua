-- src/player.lua: Player entity, movement, kick, stamina, substitutions and simple AI

local Field  = require("src.field")
local Assets = require("src.assets")
local Audio  = require("src.audio")

local Player = {}
Player.__index = Player

local SPEED        = 160   -- px per second (at full stamina)
local KICK_POWER   = 420   -- impulse magnitude (at full stamina)
local KICK_RANGE   = 40    -- px – how close the player must be to kick
local KICK_COOLDOWN = 0.3  -- min seconds between kicks (rate-limits the AI's
                           -- per-frame auto-kick so it spends stamina sanely)
local RADIUS       = 14    -- visual radius

-- AI reaction parameters
local AI_SPEED   = 130
local AI_RANGE   = 35

-- ─── Stamina / substitution tuning ───────────────────────────────────────────
local SQUAD_SIZE      = 3      -- players per team (1 on pitch + 2 on the bench)
local MAX_STAMINA     = 100
local DRAIN_MOVE      = 5.0    -- stamina/sec drained while the active player moves
local DRAIN_IDLE      = 1.5    -- stamina/sec drained while the active player stands
local KICK_COST       = 8      -- stamina spent per kick
local REGEN_BENCH     = 6.0    -- stamina/sec recovered while resting on the bench
local SUB_COOLDOWN    = 1.2    -- seconds enforced between substitutions
local MIN_SPEED_MUL   = 0.55   -- movement speed multiplier at 0 stamina
local MIN_KICK_MUL    = 0.60   -- kick power multiplier at 0 stamina

-- AI substitution behaviour
local AI_SUB_THRESHOLD = 35    -- AI subs when its active player drops below this
local AI_SUB_TARGET    = 70    -- ...and a bench player has at least this much

-- Jersey numbers per team, purely cosmetic flavour
local JERSEYS = {
    [1] = {9, 7, 11},
    [2] = {10, 8, 4},
}

function Player.new(team, controlScheme)
    -- team: 1 = left/red, 2 = right/blue
    -- controlScheme: "wasd", "arrows", or "ai"
    local self = setmetatable({}, Player)
    self.team    = team
    self.control = controlScheme
    self.radius  = RADIUS

    -- Build the squad: a roster of members, each with their own stamina.
    self.roster = {}
    for i = 1, SQUAD_SIZE do
        self.roster[i] = {
            stamina = MAX_STAMINA,
            number  = (JERSEYS[team] and JERSEYS[team][i]) or i,
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

-- Stamina of the on-pitch member as a 0..1 fraction
function Player:staminaFrac()
    return self:activeMember().stamina / MAX_STAMINA
end

-- Index of the freshest bench member (highest stamina), or nil if none
function Player:freshestBench()
    local bestIdx, bestStamina
    for i, m in ipairs(self.roster) do
        if i ~= self.active and (not bestStamina or m.stamina > bestStamina) then
            bestIdx, bestStamina = i, m.stamina
        end
    end
    return bestIdx, bestStamina
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

function Player:update(dt, ball)
    self.subCooldown  = math.max(0, self.subCooldown - dt)
    self.subFlash     = math.max(0, self.subFlash - dt)
    self.kickCooldown = math.max(0, self.kickCooldown - dt)

    local moveX, moveY = 0, 0

    if self.control == "wasd" then
        if love.keyboard.isDown("w") then moveY = -1 end
        if love.keyboard.isDown("s") then moveY =  1 end
        if love.keyboard.isDown("a") then moveX = -1 end
        if love.keyboard.isDown("d") then moveX =  1 end

    elseif self.control == "arrows" then
        if love.keyboard.isDown("up")    then moveY = -1 end
        if love.keyboard.isDown("down")  then moveY =  1 end
        if love.keyboard.isDown("left")  then moveX = -1 end
        if love.keyboard.isDown("right") then moveX =  1 end

    elseif self.control == "ai" then
        -- Simple AI: move toward the ball
        local dx = ball.x - self.x
        local dy = ball.y - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 5 then
            moveX = dx / dist
            moveY = dy / dist
        end
        -- AI auto-kick when close enough
        if dist <= AI_RANGE then
            self:kick(ball)
        end
        -- AI manages its own fitness: sub off a tired player for a fresh one
        if self:activeMember().stamina < AI_SUB_THRESHOLD then
            local _, benchStamina = self:freshestBench()
            if benchStamina and benchStamina >= AI_SUB_TARGET then
                self:substitute()
            end
        end
    end

    -- Fatigue scales movement speed
    local frac     = self:staminaFrac()
    local speedMul = MIN_SPEED_MUL + (1 - MIN_SPEED_MUL) * frac

    -- Normalise diagonal movement and apply
    local len = math.sqrt(moveX * moveX + moveY * moveY)
    local isMoving = len > 0
    if isMoving then
        local spd = ((self.control == "ai") and AI_SPEED or SPEED) * speedMul
        self.x = self.x + (moveX / len) * spd * dt
        self.y = self.y + (moveY / len) * spd * dt
    end

    -- Drain the active member; regenerate everyone on the bench
    local active = self:activeMember()
    active.stamina = math.max(0, active.stamina - (isMoving and DRAIN_MOVE or DRAIN_IDLE) * dt)
    for i, m in ipairs(self.roster) do
        if i ~= self.active then
            m.stamina = math.min(MAX_STAMINA, m.stamina + REGEN_BENCH * dt)
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
        local effSpeed = SPEED * speedMul
        local relVx = ball.vx - (moveX * effSpeed)
        local relVy = ball.vy - (moveY * effSpeed)
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
function Player:kick(ball)
    if self.kickCooldown > 0 then return end
    if ball:isNear(self.x, self.y, KICK_RANGE) then
        local nx, ny = dirToBall(self.x, self.y, ball.x, ball.y)
        if nx == 0 and ny == 0 then
            -- kick straight ahead toward opponent goal
            nx = (self.team == 1) and 1 or -1
        end
        local kickMul = MIN_KICK_MUL + (1 - MIN_KICK_MUL) * self:staminaFrac()
        ball:applyImpulse(nx * KICK_POWER * kickMul, ny * KICK_POWER * kickMul)

        -- Kicking costs stamina and arms the cooldown
        local active = self:activeMember()
        active.stamina = math.max(0, active.stamina - KICK_COST)
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
