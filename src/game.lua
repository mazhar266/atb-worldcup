-- src/game.lua: Game state machine and main orchestrator

local Field   = require("src.field")
local Ball    = require("src.ball")
local Player  = require("src.player")
local Goal    = require("src.goal")
local UI      = require("src.ui")
local Assets  = require("src.assets")
local Audio   = require("src.audio")

local Game = {}

-- ─── State constants ─────────────────────────────────────────────────────────
local STATE_MENU      = "menu"
local STATE_PLAYING   = "playing"
local STATE_OVERTIME  = "overtime"   -- sudden-death extra time
local STATE_PAUSED    = "paused"
local STATE_GOAL      = "goal"       -- brief freeze after a goal
local STATE_GAMEOVER  = "gameover"

-- ─── Configuration ───────────────────────────────────────────────────────────
local MATCH_TIME    = 90    -- seconds per match
local GOAL_FREEZE   = 1.8   -- seconds to show goal flash

-- ─── Module-level state ──────────────────────────────────────────────────────
local state
local ball
local player1
local player2
local timeLeft
local isOvertime
local goalFlashTimer
local lastScoringTeam
local menuOption    -- 1 = vs AI, 2 = 2 player

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function createPlayers(option)
    local p2control = (option == 1) and "ai" or "arrows"
    player1 = Player.new(1, "wasd")
    player2 = Player.new(2, p2control)
end

local function startMatch(option)
    Goal.reset()
    ball       = Ball.new()
    isOvertime = false
    createPlayers(option or menuOption)
    timeLeft = MATCH_TIME
    state    = STATE_PLAYING
    Audio.playWhistle()
end

local function resetAfterGoal()
    ball:reset()
    player1:reset()
    player2:reset()
    state = isOvertime and STATE_OVERTIME or STATE_PLAYING
end

-- ─── Love2D callbacks ────────────────────────────────────────────────────────

function Game.load()
    Assets.load()
    Audio.load()
    UI.load()
    menuOption = 1
    state = STATE_MENU
end

function Game.update(dt)
    if state == STATE_PLAYING then
        -- Update timer
        timeLeft = timeLeft - dt
        if timeLeft <= 0 then
            timeLeft = 0
            -- Tied → go to sudden-death overtime; otherwise end match
            if Goal.score[1] == Goal.score[2] then
                isOvertime = true
                state = STATE_OVERTIME
                ball:reset()
                player1:reset()
                player2:reset()
                Audio.playWhistle()
            else
                state = STATE_GAMEOVER
            end
            return
        end

        -- Update entities
        ball:update(dt)
        player1:update(dt, ball)
        player2:update(dt, ball)

        -- Check for goals
        local scorer = Goal.check(ball)
        if scorer then
            lastScoringTeam = scorer
            goalFlashTimer  = GOAL_FREEZE
            state = STATE_GOAL
            Audio.playGoal()
        end

    elseif state == STATE_OVERTIME then
        -- No countdown in overtime; first goal wins
        ball:update(dt)
        player1:update(dt, ball)
        player2:update(dt, ball)

        local scorer = Goal.check(ball)
        if scorer then
            lastScoringTeam = scorer
            goalFlashTimer  = GOAL_FREEZE
            state = STATE_GOAL
            Audio.playGoal()
        end

    elseif state == STATE_GOAL then
        goalFlashTimer = goalFlashTimer - dt
        -- Players are frozen during the goal flash, but let the sub-flash ring
        -- keep fading so it doesn't hang on screen for the whole freeze.
        player1:tickFlash(dt)
        player2:tickFlash(dt)
        if goalFlashTimer <= 0 then
            -- In overtime a goal ends the match; in normal time reset and play on
            if isOvertime then
                state = STATE_GAMEOVER
            else
                resetAfterGoal()
            end
        end
    end
end

function Game.draw()
    -- Clear background
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    love.graphics.clear()

    if state == STATE_MENU then
        UI.drawMenu(menuOption)
        return
    end

    -- Draw field
    Field.draw()

    -- Draw entities
    ball:draw()
    player1:draw()
    player2:draw()

    -- Draw HUD
    UI.drawHUD(Goal.score, timeLeft, isOvertime)
    UI.drawStamina(player1, player2)

    -- Overlays
    if state == STATE_GOAL then
        local alpha = math.min(1, goalFlashTimer / GOAL_FREEZE * 2)
        UI.drawGoalFlash(lastScoringTeam, alpha)

    elseif state == STATE_PAUSED then
        UI.drawPause()

    elseif state == STATE_GAMEOVER then
        UI.drawGameOver(Goal.score)
    end
end

function Game.keypressed(key)
    if state == STATE_MENU then
        if key == "up"    then menuOption = 1 end
        if key == "down"  then menuOption = 2 end
        if key == "w"     then menuOption = 1 end
        if key == "s"     then menuOption = 2 end
        if key == "return" or key == "kpenter" then
            startMatch(menuOption)
        end
        if key == "escape" then love.event.quit() end

    elseif state == STATE_PLAYING or state == STATE_OVERTIME then
        -- Kick keys
        if key == "f" then player1:kick(ball) end
        if key == "l" then player2:kick(ball) end

        -- Substitution keys (only for human-controlled teams)
        if key == "q" and player1.control ~= "ai" then player1:substitute() end
        if key == "k" and player2.control ~= "ai" then player2:substitute() end

        if key == "p"      then state = STATE_PAUSED end
        if key == "escape" then state = STATE_MENU end

    elseif state == STATE_PAUSED then
        if key == "p"      then
            state = isOvertime and STATE_OVERTIME or STATE_PLAYING
        end
        if key == "r"      then startMatch() end
        if key == "escape" then state = STATE_MENU end

    elseif state == STATE_GAMEOVER then
        if key == "return" or key == "kpenter" then
            startMatch()
        end
        if key == "escape" then state = STATE_MENU end
    end
end

return Game
