-- src/ui.lua: HUD, menu, pause overlay, and game-over screen

local UI = {}

-- Colours
local COL_HUD_BG   = {0.05, 0.05, 0.05, 0.85}
local COL_WHITE    = {1,    1,    1}
local COL_YELLOW   = {1,    0.85, 0.1}
local COL_OVERLAY  = {0,    0,    0,   0.55}
local COL_RED      = {0.9,  0.15, 0.15}
local COL_BLUE     = {0.15, 0.35, 0.9}

-- Fonts (created in UI.load)
local fontLarge
local fontMedium
local fontSmall

function UI.load()
    fontLarge  = love.graphics.newFont(42)
    fontMedium = love.graphics.newFont(24)
    fontSmall  = love.graphics.newFont(16)
end

-- ─── HUD ────────────────────────────────────────────────────────────────────

function UI.drawHUD(score, timeLeft)
    -- Background strip
    love.graphics.setColor(COL_HUD_BG)
    love.graphics.rectangle("fill", 0, 0, 800, 50)

    -- Score
    local scoreText = score[1] .. "  –  " .. score[2]
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(COL_WHITE)
    local tw = fontLarge:getWidth(scoreText)
    love.graphics.print(scoreText, (800 - tw) / 2, 2)

    -- Player labels
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(COL_RED)
    love.graphics.print("P1", 20, 16)
    love.graphics.setColor(COL_BLUE)
    love.graphics.print("P2", 760, 16)

    -- Timer
    local mins = math.floor(timeLeft / 60)
    local secs = math.floor(timeLeft % 60)
    local timeStr = string.format("%d:%02d", mins, secs)
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(timeLeft <= 10 and COL_YELLOW or COL_WHITE)
    local ttw = fontMedium:getWidth(timeStr)
    love.graphics.print(timeStr, 800 - ttw - 20, 14)
end

-- ─── Goal flash ─────────────────────────────────────────────────────────────

function UI.drawGoalFlash(team, alpha)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(fontLarge)
    local msg = "GOAL!"
    local tw  = fontLarge:getWidth(msg)
    love.graphics.print(msg, (800 - tw) / 2, 250)
    love.graphics.setFont(fontMedium)
    local sub = (team == 1) and "Team Red scores!" or "Team Blue scores!"
    local sw  = fontMedium:getWidth(sub)
    love.graphics.setColor(team == 1 and COL_RED or COL_BLUE)
    love.graphics.print(sub, (800 - sw) / 2, 300)
end

-- ─── Menu screen ────────────────────────────────────────────────────────────

function UI.drawMenu(menuOption)
    -- Dark full-screen overlay
    love.graphics.setColor(0.05, 0.15, 0.05)
    love.graphics.rectangle("fill", 0, 0, 800, 600)

    -- Title
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(COL_YELLOW)
    local title = "ATB WorldCup"
    local tw = fontLarge:getWidth(title)
    love.graphics.print(title, (800 - tw) / 2, 80)

    -- Subtitle
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(COL_WHITE)
    local sub = "An arcade football game"
    local sw  = fontSmall:getWidth(sub)
    love.graphics.print(sub, (800 - sw) / 2, 136)

    -- Mode selector
    love.graphics.setFont(fontMedium)
    local options = {"1 Player  (vs AI)", "2 Players  (local)"}
    for i, opt in ipairs(options) do
        if i == menuOption then
            love.graphics.setColor(COL_YELLOW)
            love.graphics.print("► " .. opt, 280, 220 + (i - 1) * 50)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("  " .. opt, 280, 220 + (i - 1) * 50)
        end
    end

    -- Instructions
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.6, 0.6, 0.6)
    local lines = {
        "↑ / ↓  Navigate    Enter  Select",
        "",
        "P1: WASD + F to kick",
        "P2: Arrow Keys + L to kick",
    }
    for i, line in ipairs(lines) do
        local lw = fontSmall:getWidth(line)
        love.graphics.print(line, (800 - lw) / 2, 360 + (i - 1) * 22)
    end
end

-- ─── Pause overlay ──────────────────────────────────────────────────────────

function UI.drawPause()
    love.graphics.setColor(COL_OVERLAY)
    love.graphics.rectangle("fill", 0, 0, 800, 600)

    love.graphics.setFont(fontLarge)
    love.graphics.setColor(COL_WHITE)
    local msg = "PAUSED"
    local tw  = fontLarge:getWidth(msg)
    love.graphics.print(msg, (800 - tw) / 2, 230)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.75, 0.75, 0.75)
    local hints = {"P – Resume", "R – Restart", "Escape – Menu"}
    for i, h in ipairs(hints) do
        local hw = fontSmall:getWidth(h)
        love.graphics.print(h, (800 - hw) / 2, 300 + (i - 1) * 28)
    end
end

-- ─── Game-over screen ───────────────────────────────────────────────────────

function UI.drawGameOver(score)
    love.graphics.setColor(COL_OVERLAY)
    love.graphics.rectangle("fill", 0, 0, 800, 600)

    love.graphics.setFont(fontLarge)
    love.graphics.setColor(COL_YELLOW)
    local msg = "FULL TIME"
    local tw  = fontLarge:getWidth(msg)
    love.graphics.print(msg, (800 - tw) / 2, 180)

    -- Final score
    love.graphics.setColor(COL_WHITE)
    local scoreStr = score[1] .. "  –  " .. score[2]
    local sw = fontLarge:getWidth(scoreStr)
    love.graphics.print(scoreStr, (800 - sw) / 2, 250)

    -- Winner announcement
    love.graphics.setFont(fontMedium)
    local resultMsg
    if score[1] > score[2] then
        love.graphics.setColor(COL_RED)
        resultMsg = "Team Red wins! 🏆"
    elseif score[2] > score[1] then
        love.graphics.setColor(COL_BLUE)
        resultMsg = "Team Blue wins! 🏆"
    else
        love.graphics.setColor(0.8, 0.8, 0.8)
        resultMsg = "It's a Draw!"
    end
    local rw = fontMedium:getWidth(resultMsg)
    love.graphics.print(resultMsg, (800 - rw) / 2, 320)

    -- Prompt
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.65, 0.65, 0.65)
    local hints = {"Enter – Play again", "Escape – Back to menu"}
    for i, h in ipairs(hints) do
        local hw = fontSmall:getWidth(h)
        love.graphics.print(h, (800 - hw) / 2, 390 + (i - 1) * 28)
    end
end

return UI
