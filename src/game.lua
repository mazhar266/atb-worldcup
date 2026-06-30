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

-- ─── Passing / control-switch tuning ─────────────────────────────────────────
-- FIFA-style (modelled on Code-the-Classics soccer.py): you control one player;
-- the kick key PASSES to the best team-mate and hands control to them. Control
-- otherwise follows whichever of your players wins a loose ball.
local POSSESS_RANGE   = 30    -- px: how close a player must be to "have" the ball
local PASS_KICK_RANGE = 46    -- px: how close you must be to pass / shoot
local PASS_RANGE      = 340   -- px: longest auto-pass
local PASS_CONE       = 0.30  -- dot: how "ahead" (in your facing dir) a target must be
local PASS_LEAD       = 26    -- px: lead the pass ahead of the receiver toward goal
local PASS_SPEED_K    = 1.25  -- pass speed scales with distance (px/s per px)
local PASS_SPEED_MIN  = 200
local PASS_SPEED_MAX  = 640
local SHOOT_SPEED     = 560   -- straight shot at goal when no team-mate is open
local PASS_HOLDOFF    = 0.45  -- s: after a pass, passer can't reclaim & mates hold

-- ─── Module-level state ──────────────────────────────────────────────────────
local state
local ball
local team1, team2       -- arrays of on-field players (one per config squad member)
local scheme1, scheme2   -- per-team control: "wasd" / "arrows" / "ai"
local control1, control2 -- the player each team currently controls (a team-array entry)
local passTimer1         -- team 1: seconds in which mates hold after a pass
local passTimer2         -- team 2: same
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

-- ── Team accessors (a "team" is just an array of its on-field config players) ──
local function teamArr(t)        return (t == 1) and team1 or team2 end
local function teamScheme(t)     return (t == 1) and scheme1 or scheme2 end
local function teamIsHuman(t)    return teamScheme(t) ~= "ai" end
local function controlledUnit(t) return (t == 1) and control1 or control2 end
local function setControlled(t, u) if t == 1 then control1 = u else control2 = u end end
local function passTimerGet(t)   return (t == 1) and passTimer1 or passTimer2 end
local function passTimerSet(t, v) if t == 1 then passTimer1 = v else passTimer2 = v end end
local function oppGoalX(t)        return (t == 1) and Field.right or Field.x end

-- Squared distance between two bodies (avoids a sqrt for "who is nearest").
local function dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

-- Is player `u` within `range` px of the ball?
local function nearBall(u, range)
    local dx, dy = ball.x - u.x, ball.y - u.y
    return (dx * dx + dy * dy) <= range * range
end

-- Read a human team's movement keys into a {x, y} vector (the player normalises).
local function humanMoveVector(t)
    local scheme = teamScheme(t)
    local mx, my = 0, 0
    if scheme == "wasd" then
        if love.keyboard.isDown("w") then my = -1 end
        if love.keyboard.isDown("s") then my =  1 end
        if love.keyboard.isDown("a") then mx = -1 end
        if love.keyboard.isDown("d") then mx =  1 end
    elseif scheme == "arrows" then
        if love.keyboard.isDown("up")    then my = -1 end
        if love.keyboard.isDown("down")  then my =  1 end
        if love.keyboard.isDown("left")  then mx = -1 end
        if love.keyboard.isDown("right") then mx =  1 end
    end
    return { mx, my }
end

-- The player on team `t` nearest the ball (optionally skipping one).
local function nearestPlayerToBall(t, exclude)
    local best, bestD
    for _, p in ipairs(teamArr(t)) do
        if p ~= exclude then
            local d = dist2(p, ball)
            if not bestD or d < bestD then bestD, best = d, p end
        end
    end
    return best
end

-- At each kickoff, control the player nearest the ball and clear pass lockouts.
local function resetControl()
    passTimer1, passTimer2 = 0, 0
    for _, p in ipairs(team1) do p.holdoff = 0 end
    for _, p in ipairs(team2) do p.holdoff = 0 end
    setControlled(1, nearestPlayerToBall(1))
    setControlled(2, nearestPlayerToBall(2))
end

-- Build one team: one Player per config squad member, in a formation.
local function buildTeam(team, aiMods)
    local total = #Config.squad(team)
    local arr = {}
    for i = 1, total do
        arr[i] = Player.new(team, i, total, aiMods)
    end
    return arr
end

local function createPlayers(mode, difficulty)
    scheme1 = "wasd"
    team1   = buildTeam(1, nil)            -- human side: no AI scaling
    if mode == 1 then
        local d = Config.difficulty(difficulty)
        scheme2 = "ai"
        team2   = buildTeam(2, { speed = d.aiSpeed, kick = d.aiKick })
    else
        scheme2 = "arrows"
        team2   = buildTeam(2, nil)
    end
    resetControl()
end

-- Keep same-team bodies from stacking. `immovable` (the controlled player) is
-- never moved, so a human's control is not nudged by the crowd.
local function separateTeam(arr, immovable)
    for i = 1, #arr do
        local a = arr[i]
        for j = i + 1, #arr do
            local b = arr[j]
            local dx, dy = a.x - b.x, a.y - b.y
            local d = math.sqrt(dx * dx + dy * dy)
            local minD = a.radius + b.radius
            if d > 0 and d < minD then
                local nx, ny = dx / d, dy / d
                local push = minD - d
                if a == immovable then
                    b.x, b.y = b.x - nx * push, b.y - ny * push
                elseif b == immovable then
                    a.x, a.y = a.x + nx * push, a.y + ny * push
                else
                    a.x, a.y = a.x + nx * push * 0.5, a.y + ny * push * 0.5
                    b.x, b.y = b.x - nx * push * 0.5, b.y - ny * push * 0.5
                end
            end
        end
    end
    for _, a in ipairs(arr) do
        a.x = math.max(Field.x + a.radius, math.min(Field.right  - a.radius, a.x))
        a.y = math.max(Field.y + a.radius, math.min(Field.bottom - a.radius, a.y))
    end
end

-- Control follows the ball: keep control while the active player still has it,
-- otherwise hand it to whichever team-mate is now on the ball.
local function updatePossession(t)
    local cur = controlledUnit(t)
    if cur and (cur.holdoff or 0) <= 0 and nearBall(cur, POSSESS_RANGE) then return end
    local best, bestD
    for _, u in ipairs(teamArr(t)) do
        if (u.holdoff or 0) <= 0 then
            local d = dist2(u, ball)
            if d <= POSSESS_RANGE * POSSESS_RANGE and (not bestD or d < bestD) then
                bestD, best = d, u
            end
        end
    end
    if best then setControlled(t, best) end
end

-- Pick the best team-mate to pass to: ahead in the passer's facing direction,
-- within range, scored by forwardness and closeness. Returns nil → shoot.
local function pickPassTarget(t, passer)
    local fx, fy = passer.faceX or 0, passer.faceY or 0
    if fx == 0 and fy == 0 then fx, fy = (t == 1) and 1 or -1, 0 end
    local best, bestScore
    for _, u in ipairs(teamArr(t)) do
        if u ~= passer then
            local dx, dy = u.x - passer.x, u.y - passer.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 0 and d <= PASS_RANGE then
                local dot = (dx / d) * fx + (dy / d) * fy
                if dot >= PASS_CONE then
                    local score = dot - (d / PASS_RANGE) * 0.5
                    if not bestScore or score > bestScore then bestScore, best = score, u end
                end
            end
        end
    end
    return best
end

-- Kick the ball to a team-mate (led slightly toward goal) and hand them control.
local function passBallTo(t, passer, target)
    local leadX = (oppGoalX(t) > target.x) and PASS_LEAD or -PASS_LEAD
    local aimX, aimY = target.x + leadX, target.y
    local dx, dy = aimX - ball.x, aimY - ball.y
    local d = math.sqrt(dx * dx + dy * dy)
    local nx = (d > 0) and dx / d or ((t == 1) and 1 or -1)
    local ny = (d > 0) and dy / d or 0
    local speed = math.max(PASS_SPEED_MIN, math.min(PASS_SPEED_MAX, d * PASS_SPEED_K))
    ball.vx, ball.vy = nx * speed, ny * speed
    passer.holdoff = PASS_HOLDOFF
    passTimerSet(t, PASS_HOLDOFF)
    setControlled(t, target)     -- control follows the pass
end

-- No open team-mate: blast it straight at the opponent goal.
local function shootAtGoal(t, shooter)
    local dx, dy = oppGoalX(t) - ball.x, Field.cy - ball.y
    local d = math.sqrt(dx * dx + dy * dy)
    local nx = (d > 0) and dx / d or ((t == 1) and 1 or -1)
    local ny = (d > 0) and dy / d or 0
    ball.vx, ball.vy = nx * SHOOT_SPEED, ny * SHOOT_SPEED
    shooter.holdoff = PASS_HOLDOFF * 0.5
end

-- The human kick key: pass to the best team-mate (handing them control) or, if
-- none is open, shoot. Only works when the active player is on the ball.
local function humanKick(t)
    if not teamIsHuman(t) then return end
    local u = controlledUnit(t)
    if not u or not nearBall(u, PASS_KICK_RANGE) then return end
    local target = pickPassTarget(t, u)
    if target then passBallTo(t, u, target) else shootAtGoal(t, u) end
    Audio.playKick()
end

-- Update a human-controlled team: the active player follows the keys; everyone
-- else runs AI. While we hold the ball (or just passed), off-ball players hold a
-- support shape so they don't fight us for it; otherwise the nearest goes to win
-- it back.
local function updateHumanTeam(t, dt)
    local arr = teamArr(t)
    local cur = controlledUnit(t)
    local mv  = humanMoveVector(t)
    local weHave   = cur and nearBall(cur, POSSESS_RANGE)
    local letChase = (not weHave) and (passTimerGet(t) <= 0)
    local chaser   = letChase and nearestPlayerToBall(t, cur) or nil

    for _, p in ipairs(arr) do
        if p == cur then
            p:update(dt, ball, { humanMove = mv })
        else
            p:update(dt, ball, { chase = (p == chaser), autoKick = false })
        end
    end

    separateTeam(arr, cur)
    updatePossession(t)
end

-- Update an AI-controlled team: the player nearest the ball is the lead (chases
-- and auto-kicks toward goal); the rest hold a ball-biased formation shape.
local function updateAITeam(t, dt)
    local arr    = teamArr(t)
    local chaser = nearestPlayerToBall(t, nil)
    for _, p in ipairs(arr) do
        p:update(dt, ball, { chase = (p == chaser), autoKick = true })
    end
    separateTeam(arr, nil)
end

-- Drive both teams for a frame. Used in play/overtime.
local function updateTeams(dt)
    passTimer1 = math.max(0, passTimer1 - dt)
    passTimer2 = math.max(0, passTimer2 - dt)
    if teamIsHuman(1) then updateHumanTeam(1, dt) else updateAITeam(1, dt) end
    if teamIsHuman(2) then updateHumanTeam(2, dt) else updateAITeam(2, dt) end
end

-- Send every player back to its formation home (kickoff / overtime restart).
local function resetTeams()
    for _, p in ipairs(team1) do p:reset() end
    for _, p in ipairs(team2) do p:reset() end
end

-- A small chevron over the player a human is currently controlling.
local function drawControlMarker(t)
    if not teamIsHuman(t) then return end
    local u = controlledUnit(t)
    if not u then return end
    local x, y = u.x, u.y - (u.radius or 14) - 8
    love.graphics.setColor(1, 1, 1, 0.92)
    love.graphics.polygon("fill", x - 6, y - 7, x + 6, y - 7, x, y + 2)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", x - 6, y - 7, x + 6, y - 7, x, y + 2)
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
    local moving = false
    for t = 1, 2 do
        local u = controlledUnit(t)
        if teamIsHuman(t) and u and u.moving then moving = true end
    end
    Audio.setMoving(moving)
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
    resetTeams()
    resetControl()
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
                resetTeams()
                resetControl()
                Audio.playWhistle()
            else
                state = STATE_GAMEOVER
                audioGameOver()
            end
            return
        end

        -- Update entities
        ball:update(dt)
        updateTeams(dt)
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
        updateTeams(dt)
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
        -- Players are frozen during the goal flash.
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

    -- Draw entities: both teams of config players, then the ball on top so it is
    -- never hidden under a body, then the control chevrons.
    for _, p in ipairs(team1) do p:draw() end
    for _, p in ipairs(team2) do p:draw() end
    ball:draw()
    drawControlMarker(1)
    drawControlMarker(2)

    -- Draw HUD
    UI.drawHUD(Goal.score, timeLeft, isOvertime)
    UI.drawTeams(team1, team2, control1, control2)

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
        -- Pass / shoot: hands control to the team-mate you pass to (FIFA-style)
        if key == "f" then humanKick(1) end
        if key == "l" then humanKick(2) end

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
