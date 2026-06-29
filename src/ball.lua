-- src/ball.lua: Ball entity with simple physics

local Field = require("src.field")
local Assets = require("src.assets")
local Audio  = require("src.audio")

local Ball = {}
Ball.__index = Ball

local RADIUS   = 10
local FRICTION = 0.98   -- velocity multiplier per frame
local MIN_SPEED = 5     -- below this the ball is considered stopped

function Ball.new()
    local self = setmetatable({}, Ball)
    self:reset()
    return self
end

function Ball:reset()
    self.x  = Field.cx
    self.y  = Field.cy
    self.vx = 0
    self.vy = 0
    self.radius = RADIUS
end

-- Apply an impulse vector to the ball (used by kick)
function Ball:applyImpulse(ix, iy)
    self.vx = self.vx + ix
    self.vy = self.vy + iy
end

function Ball:update(dt)
    -- Move
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Apply friction
    self.vx = self.vx * FRICTION
    self.vy = self.vy * FRICTION

    -- Clamp tiny speeds to zero
    if math.abs(self.vx) < MIN_SPEED then self.vx = 0 end
    if math.abs(self.vy) < MIN_SPEED then self.vy = 0 end

    -- Bounce off top/bottom field walls
    if self.y - self.radius < Field.y then
        self.y  = Field.y + self.radius
        self.vy = -self.vy
        Audio.playBounce()
    elseif self.y + self.radius > Field.bottom then
        self.y  = Field.bottom - self.radius
        self.vy = -self.vy
        Audio.playBounce()
    end

    -- Left wall bounce (only outside the goal opening)
    if self.x - self.radius < Field.x then
        local inGoal = self.y >= Field.goalTop and self.y <= Field.goalBottom
        if not inGoal then
            self.x  = Field.x + self.radius
            self.vx = -self.vx
            Audio.playBounce()
        end
    end

    -- Right wall bounce (only outside the goal opening)
    if self.x + self.radius > Field.right then
        local inGoal = self.y >= Field.goalTop and self.y <= Field.goalBottom
        if not inGoal then
            self.x  = Field.right - self.radius
            self.vx = -self.vx
            Audio.playBounce()
        end
    end
end

function Ball:draw()
    if Assets.ball then
        local w, h = Assets.ball:getDimensions()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(Assets.ball, self.x - w / 2, self.y - h / 2)
        return
    end

    -- Fallback shape rendering
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", self.x + 3, self.y + 3, self.radius)

    -- Ball body
    love.graphics.setColor(1, 1, 0.8)
    love.graphics.circle("fill", self.x, self.y, self.radius)

    -- Ball outline
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", self.x, self.y, self.radius)
end

-- Returns true if the point (px,py) is within kickRange of the ball
function Ball:isNear(px, py, kickRange)
    local dx = self.x - px
    local dy = self.y - py
    return (dx * dx + dy * dy) <= kickRange * kickRange
end

return Ball
