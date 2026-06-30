-- src/game.lua: Game state machine and main orchestrator

local Field   = require("src.field")
local Ball    = require("src.ball")
local Player  = require("src.player")
local Goal    = require("src.goal")
local UI      = require("src.ui")
local Assets  = require("src.assets")
local Audio   = require("src.audio")
local Config  = require("src.config")

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
local menuPage           -- "main" or "difficulty"
local menuOption         -- selected index into the current page's list
local mainItems          -- main-menu entries {label, action}
local difficultyItems    -- difficulty entries {label, difficulty}
local currentMode        -- 1 = vs AI, 2 = 2 players (of the running / last match)
local currentDifficulty  -- difficulty index used for the AI

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function createPlayers(mode, difficulty)
    player1 = Player.new(1, "wasd")
    if mode == 1 then
        local d = Config.difficulty(difficulty)
        player2 = Player.new(2, "ai", { speed = d.aiSpeed, kick = d.aiKick })
    else
        player2 = Player.new(2, "arrows")
    end
end

-- Build the two menu screens: the main screen (Play / 2 Players) leads to the
-- difficulty screen (one row per configured difficulty).
local function buildMenu()
    mainItems = {
        { label = "Play  (1 Player vs AI)", action = "difficulty" },
        { label = "2 Players  (local)",     action = "start2p" },
    }
    difficultyItems = {}
    for i, d in ipairs(Config.difficulties()) do
        local label = d.name
        if d.tagline ~= "" then label = label .. "  (" .. d.tagline .. ")" end
        difficultyItems[#difficultyItems + 1] = { label = label, difficulty = i }
    end
end

local function menuItemsForPage()
    return (menuPage == "difficulty") and difficultyItems or mainItems
end

-- ─── Audio scenes ──────────────────────────────────────────────────────────
-- Theme music plays on the menu / results screens; the crowd ambience bed plays
-- while a match is live. The movement loop only follows human players.

local function audioMenu()
    Audio.stopCrowd()
    Audio.setMoving(false)
    Audio.startTheme()
end

local function audioMatch()
    Audio.stopTheme()
    Audio.startCrowd()
end

local function audioGameOver()
    Audio.stopCrowd()
    Audio.setMoving(false)
    Audio.playWhistle()   -- final whistle
    Audio.startTheme()
end

local function updateMoveAudio()
    Audio.setMoving((player1.control ~= "ai" and player1.moving)
                 or (player2.control ~= "ai" and player2.moving))
end

-- Return to the (main) menu screen.
local function goToMenu()
    state      = STATE_MENU
    menuPage   = "main"
    menuOption = 1
    audioMenu()
end

local function startMatch(mode, difficulty)
    currentMode       = mode or currentMode
    currentDifficulty = difficulty or currentDifficulty
    Goal.reset()
    ball       = Ball.new()
    isOvertime = false
    createPlayers(currentMode, currentDifficulty)
    timeLeft = MATCH_TIME
    state    = STATE_PLAYING
    audioMatch()
    Audio.playStart()
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
    buildMenu()
    currentMode       = 1
    currentDifficulty = 1
    goToMenu()
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
                audioGameOver()
            end
            return
        end

        -- Update entities
        ball:update(dt)
        player1:update(dt, ball)
        player2:update(dt, ball)
        updateMoveAudio()

        -- Check for goals
        local scorer = Goal.check(ball)
        if scorer then
            lastScoringTeam = scorer
            goalFlashTimer  = GOAL_FREEZE
            state = STATE_GOAL
            Audio.playGoal()
            Audio.setMoving(false)
        end

    elseif state == STATE_OVERTIME then
        -- No countdown in overtime; first goal wins
        ball:update(dt)
        player1:update(dt, ball)
        player2:update(dt, ball)
        updateMoveAudio()

        local scorer = Goal.check(ball)
        if scorer then
            lastScoringTeam = scorer
            goalFlashTimer  = GOAL_FREEZE
            state = STATE_GOAL
            Audio.playGoal()
            Audio.setMoving(false)
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
                audioGameOver()
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
        if menuPage == "difficulty" then
            UI.drawMenu(difficultyItems, menuOption,
                "Select Difficulty  ·  it scales the AI opponent",
                "Enter: Start    Esc: Back")
        else
            UI.drawMenu(mainItems, menuOption,
                "An arcade football game",
                "W/S or Up/Down: Navigate    Enter: Select")
        end
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
        local items = menuItemsForPage()
        if key == "up"   or key == "w" then menuOption = math.max(1, menuOption - 1) end
        if key == "down" or key == "s" then menuOption = math.min(#items, menuOption + 1) end
        if key == "return" or key == "kpenter" then
            local item = items[menuOption]
            if menuPage == "difficulty" then
                startMatch(1, item.difficulty)
            elseif item.action == "difficulty" then
                menuPage   = "difficulty"
                menuOption = 1
            elseif item.action == "start2p" then
                startMatch(2)
            end
        end
        if key == "escape" then
            if menuPage == "difficulty" then
                menuPage   = "main"
                menuOption = 1
            else
                love.event.quit()
            end
        end

    elseif state == STATE_PLAYING or state == STATE_OVERTIME then
        -- Kick keys
        if key == "f" then player1:kick(ball) end
        if key == "l" then player2:kick(ball) end

        -- Substitution keys (only for human-controlled teams)
        if key == "q" and player1.control ~= "ai" then player1:substitute() end
        if key == "k" and player2.control ~= "ai" then player2:substitute() end

        if key == "p"      then
            state = STATE_PAUSED
            Audio.stopCrowd()
            Audio.setMoving(false)
        end
        if key == "escape" then
            goToMenu()
        end

    elseif state == STATE_PAUSED then
        if key == "p"      then
            state = isOvertime and STATE_OVERTIME or STATE_PLAYING
            Audio.startCrowd()
        end
        if key == "r"      then startMatch() end
        if key == "escape" then
            goToMenu()
        end

    elseif state == STATE_GAMEOVER then
        if key == "return" or key == "kpenter" then
            startMatch()
        end
        if key == "escape" then
            goToMenu()
        end
    end
end

return Game
