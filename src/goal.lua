-- src/goal.lua: Goal zone detection and score management

local Field = require("src.field")

local Goal = {}

-- Scores
Goal.score = {0, 0}

function Goal.reset()
    Goal.score = {0, 0}
end

-- Returns the team index (1 or 2) that just scored, or nil
function Goal.check(ball)
    -- Ball fully past the left edge → Team 2 scores
    if ball.x + ball.radius < Field.x - Field.goalWidth then
        if ball.y >= Field.goalTop and ball.y <= Field.goalBottom then
            Goal.score[2] = Goal.score[2] + 1
            return 2
        end
    end

    -- Ball fully past the right edge → Team 1 scores
    if ball.x - ball.radius > Field.right + Field.goalWidth then
        if ball.y >= Field.goalTop and ball.y <= Field.goalBottom then
            Goal.score[1] = Goal.score[1] + 1
            return 1
        end
    end

    return nil
end

return Goal
