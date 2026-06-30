-- src/ball.lua: Ball entity with simple physics

local Field = require("src.field")
local Assets = require("src.assets")
local Audio  = require("src.audio")

local Ball = {}
Ball.__index = Ball

local RADIUS   = 10
local FRICTION = 0.98   -- velocity multiplier per frame
local MIN_SPEED = 5     -- below this the ball is considered stopped

-- Anti-stuck: free a ball that gets pinned against a wall/corner (e.g. by a
-- player holding it there) instead of letting it sit for the whole match.
local STUCK_TIME      = 1.2   -- seconds pinned near a wall before we auto-free it
local STUCK_MOVE      = 28    -- px of net travel under which it "isn't progressing"
local STUCK_MARGIN    = 30    -- px from a wall that counts as "in the corner / on the line"
local ESCAPE_SPEED    = 300   -- px/s velocity given to a freed ball
local ESCAPE_TELEPORT = 64    -- px the ball is relocated toward midfield to clear a pinning player

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
    -- Anti-stuck tracking
    self.stuckTimer = 0
    self.stuckX = self.x
    self.stuckY = self.y
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

    -- Anti-stuck: a ball pinned against a wall/corner (held there by a player)
    -- would otherwise sit for the whole match. If it lingers near any edge
    -- without making progress, relocate it back toward midfield.
    --
    -- The escape must move the ball's POSITION, not just its velocity: players
    -- are updated right after the ball each frame, so a velocity-only nudge is
    -- cancelled the same frame by the pinning player's push. Teleporting the
    -- ball clear of the player makes that push a no-op.
    --
    -- Exception: never touch a ball that is in the goal band and still rolling
    -- toward that end line — it may be a slow goal in progress. A pinned ball is
    -- not moving toward the line, so it is still freed.
    local inGoalBand  = self.y >= Field.goalTop and self.y <= Field.goalBottom
    local scoringRoll =
        (inGoalBand and self.x <= Field.x + 40    and self.vx < 0) or
        (inGoalBand and self.x >= Field.right - 40 and self.vx > 0)

    local nearWall =
        (self.y - self.radius <= Field.y + STUCK_MARGIN) or
        (self.y + self.radius >= Field.bottom - STUCK_MARGIN) or
        (self.x - self.radius <= Field.x + STUCK_MARGIN) or
        (self.x + self.radius >= Field.right - STUCK_MARGIN)

    local ddx = self.x - self.stuckX
    local ddy = self.y - self.stuckY
    if (not scoringRoll) and nearWall and (ddx * ddx + ddy * ddy) < STUCK_MOVE * STUCK_MOVE then
        self.stuckTimer = self.stuckTimer + dt
        if self.stuckTimer >= STUCK_TIME then
            local tx = Field.cx - self.x
            local ty = Field.cy - self.y
            local len = math.sqrt(tx * tx + ty * ty)
            if len > 0 then
                local ux, uy = tx / len, ty / len
                -- Relocate clear of the pinning player, then send it into play.
                self.x = self.x + ux * ESCAPE_TELEPORT
                self.y = self.y + uy * ESCAPE_TELEPORT
                self.vx = ux * ESCAPE_SPEED
                self.vy = uy * ESCAPE_SPEED
            end
            -- Keep the relocated ball safely inside the pitch.
            self.x = math.max(Field.x + self.radius, math.min(Field.right - self.radius, self.x))
            self.y = math.max(Field.y + self.radius, math.min(Field.bottom - self.radius, self.y))
            self.stuckTimer = 0
            self.stuckX, self.stuckY = self.x, self.y
        end
    else
        self.stuckTimer = 0
        self.stuckX, self.stuckY = self.x, self.y
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
