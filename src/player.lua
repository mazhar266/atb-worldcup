-- src/player.lua: Player entity, movement, kick and simple AI

local Field = require("src.field")

local Player = {}
Player.__index = Player

local SPEED      = 160   -- px per second
local KICK_POWER = 420   -- impulse magnitude
local KICK_RANGE = 40    -- px – how close the player must be to kick
local RADIUS     = 14    -- visual radius

-- AI reaction parameters
local AI_SPEED   = 130
local AI_RANGE   = 35

function Player.new(team, controlScheme)
    -- team: 1 = left/red, 2 = right/blue
    -- controlScheme: "wasd", "arrows", or "ai"
    local self = setmetatable({}, Player)
    self.team    = team
    self.control = controlScheme
    self.radius  = RADIUS
    self:reset()
    return self
end

function Player:reset()
    if self.team == 1 then
        self.x = Field.x + 160
        self.color = {0.9, 0.15, 0.15}
    else
        self.x = Field.right - 160
        self.color = {0.15, 0.35, 0.9}
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

function Player:update(dt, ball)
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
    end

    -- Normalise diagonal movement
    local len = math.sqrt(moveX * moveX + moveY * moveY)
    if len > 0 then
        local spd = (self.control == "ai") and AI_SPEED or SPEED
        self.x = self.x + (moveX / len) * spd * dt
        self.y = self.y + (moveY / len) * spd * dt
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
        -- Transfer some of the player's movement energy
        local relVx = ball.vx - (moveX * SPEED)
        local relVy = ball.vy - (moveY * SPEED)
        local dot = relVx * nx + relVy * ny
        if dot < 0 then
            ball.vx = ball.vx - dot * nx * 0.6
            ball.vy = ball.vy - dot * ny * 0.6
        end
    end
end

-- Called on keypress for human kick
function Player:kick(ball)
    if ball:isNear(self.x, self.y, KICK_RANGE) then
        local nx, ny = dirToBall(self.x, self.y, ball.x, ball.y)
        if nx == 0 and ny == 0 then
            -- kick straight ahead toward opponent goal
            nx = (self.team == 1) and 1 or -1
        end
        ball:applyImpulse(nx * KICK_POWER, ny * KICK_POWER)
    end
end

function Player:draw()
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.circle("fill", self.x + 3, self.y + 4, self.radius)

    -- Body
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, self.radius)

    -- Outline
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, self.radius)

    -- Team number
    love.graphics.setColor(1, 1, 1)
    local label = tostring(self.team)
    local font  = love.graphics.getFont()
    local tw    = font:getWidth(label)
    local th    = font:getHeight()
    love.graphics.print(label, self.x - tw / 2, self.y - th / 2)
end

return Player
