-- src/field.lua: Football pitch rendering

local Assets = require("src.assets")

local Field = {}

-- Field geometry (centred on 800x600 window)
Field.x      = 50   -- left edge of the playing area
Field.y      = 60   -- top edge  (leaves 40px for HUD + padding)
Field.width  = 700
Field.height = 480

-- Goal dimensions
Field.goalWidth  = 20
Field.goalHeight = 120

-- Derived convenience values (set in Field.load so they update if sizes change)
Field.right  = Field.x + Field.width
Field.bottom = Field.y + Field.height
Field.cx     = Field.x + Field.width  / 2  -- horizontal centre
Field.cy     = Field.y + Field.height / 2  -- vertical centre

-- Goal openings (y range)
Field.goalTop    = Field.cy - Field.goalHeight / 2
Field.goalBottom = Field.cy + Field.goalHeight / 2

-- Colours
local COL_GRASS   = {0.13, 0.55, 0.13}
local COL_LINE    = {1,    1,    1,    0.85}
local COL_GOAL    = {0.95, 0.95, 0.95}

function Field.draw()
    -- Grass background
    if Assets.grass then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(Assets.grass, Field.x, Field.y)
    else
        love.graphics.setColor(COL_GRASS)
        love.graphics.rectangle("fill", Field.x, Field.y, Field.width, Field.height)
    end

    -- Border
    love.graphics.setColor(COL_LINE)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", Field.x, Field.y, Field.width, Field.height)

    -- Halfway line
    love.graphics.line(Field.cx, Field.y, Field.cx, Field.bottom)

    -- Centre circle
    love.graphics.circle("line", Field.cx, Field.cy, 60)

    -- Centre spot
    love.graphics.circle("fill", Field.cx, Field.cy, 4)

    -- Goal boxes (penalty areas)
    local boxW = 100
    local boxH = 200
    local boxTop = Field.cy - boxH / 2
    -- Left penalty area
    love.graphics.rectangle("line", Field.x, boxTop, boxW, boxH)
    -- Right penalty area
    love.graphics.rectangle("line", Field.right - boxW, boxTop, boxW, boxH)

    -- Goals (white rectangles outside the field boundary)
    love.graphics.setColor(COL_GOAL)
    -- Left goal
    love.graphics.rectangle(
        "fill",
        Field.x - Field.goalWidth, Field.goalTop,
        Field.goalWidth, Field.goalHeight
    )
    -- Right goal
    love.graphics.rectangle(
        "fill",
        Field.right, Field.goalTop,
        Field.goalWidth, Field.goalHeight
    )

    -- Goal outlines
    love.graphics.setColor(COL_LINE)
    love.graphics.rectangle(
        "line",
        Field.x - Field.goalWidth, Field.goalTop,
        Field.goalWidth, Field.goalHeight
    )
    love.graphics.rectangle(
        "line",
        Field.right, Field.goalTop,
        Field.goalWidth, Field.goalHeight
    )
end

return Field
