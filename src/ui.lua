-- src/ui.lua: HUD, menu, pause overlay, and game-over screen

local Field = require("src.field")
local Assets = require("src.assets")
local Config = require("src.config")

local UI = {}

-- Colors
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
local fontTiny

function UI.load()
    fontLarge  = love.graphics.newFont(42)
    fontMedium = love.graphics.newFont(24)
    fontSmall  = love.graphics.newFont(16)
    fontTiny   = love.graphics.newFont(12)
end

-- ─── HUD ────────────────────────────────────────────────────────────────────

function UI.drawHUD(score, timeLeft, isOvertime)
    -- Background strip (flush with the field top at y=60)
    love.graphics.setColor(COL_HUD_BG)
    love.graphics.rectangle("fill", 0, 0, 800, 60)

    -- Score (centred, top)
    local scoreText = score[1] .. "  –  " .. score[2]
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(COL_WHITE)
    local tw = fontLarge:getWidth(scoreText)
    love.graphics.print(scoreText, (800 - tw) / 2, 2)

    -- Timer / overtime indicator (top-right)
    love.graphics.setFont(fontMedium)
    if isOvertime then
        love.graphics.setColor(COL_YELLOW)
        local otStr = "OVERTIME"
        love.graphics.print(otStr, 800 - fontMedium:getWidth(otStr) - 20, 8)
    else
        local mins = math.floor(timeLeft / 60)
        local secs = math.floor(timeLeft % 60)
        local timeStr = string.format("%d:%02d", mins, secs)
        love.graphics.setColor(timeLeft <= 10 and COL_YELLOW or COL_WHITE)
        love.graphics.print(timeStr, 800 - fontMedium:getWidth(timeStr) - 20, 8)
    end

    -- Team names (bottom corners, colour-coded by side)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(COL_RED)
    love.graphics.print(Config.teamName(1), 20, 40)
    local name2 = Config.teamName(2)
    love.graphics.setColor(COL_BLUE)
    love.graphics.print(name2, 800 - fontSmall:getWidth(name2) - 20, 40)
end

-- ─── Stamina / squad widget ───────────────────────────────────────────────────

local COL_STAM_HI  = {0.30, 0.85, 0.30}
local COL_STAM_MID = {0.95, 0.80, 0.20}
local COL_STAM_LO  = {0.90, 0.25, 0.20}
local COL_PANEL_BG = {0.05, 0.07, 0.05, 0.92}

local function staminaColor(frac)
    if frac > 0.5 then
        return COL_STAM_HI
    elseif frac > 0.25 then
        return COL_STAM_MID
    else
        return COL_STAM_LO
    end
end

-- Draw a horizontal bar that fills to `frac` (0..1). When alignRight is true the
-- fill empties toward the screen centre (used for the right-hand team).
local function drawBar(x, y, w, h, frac, col, alignRight)
    frac = math.max(0, math.min(1, frac))
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)

    local fw = w * frac
    love.graphics.setColor(col)
    if alignRight then
        love.graphics.rectangle("fill", x + w - fw, y, fw, h, 2, 2)
    else
        love.graphics.rectangle("fill", x, y, fw, h, 2, 2)
    end

    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 2, 2)
end

-- Draw one team's roster panel in a top corner of the pitch: every on-pitch
-- config player as a row of name + stamina bar, with the player you currently
-- control marked. alignRight anchors the panel to the right edge for team 2.
local function drawTeamPanel(players, controlled, alignRight)
    love.graphics.setFont(fontTiny)
    local lineH = fontTiny:getHeight()
    local ROWH  = lineH + 5
    local NAMEW, BARW, BARH = 66, 84, 7
    local padX, padY = 6, 5
    local panelW = NAMEW + 8 + BARW
    local x0 = alignRight and (Field.right - 10 - panelW) or (Field.x + 10)
    local y0 = Field.y + 8
    local panelH = #players * ROWH

    -- Opaque backing so moving sprites can't bleed through the panel.
    love.graphics.setColor(COL_PANEL_BG)
    love.graphics.rectangle("fill", x0 - padX, y0 - padY, panelW + padX * 2, panelH + padY * 2, 4, 4)

    for i, p in ipairs(players) do
        local y      = y0 + (i - 1) * ROWH
        local isCtrl = (p == controlled)

        -- Control marker (a small chevron) beside the player you steer.
        if isCtrl then
            love.graphics.setColor(1, 0.95, 0.5)
            love.graphics.polygon("fill", x0 - 2, y + 1, x0 - 2, y + lineH - 1, x0 + 4, y + lineH / 2)
        end

        -- Name (brighter for the controlled player)
        love.graphics.setColor(isCtrl and {1, 1, 1} or {0.7, 0.72, 0.78})
        local name = p.name or ("#" .. tostring(p.number or i))
        love.graphics.print(name, x0 + 8, y)

        -- Stamina bar
        local frac = p:staminaFrac()
        drawBar(x0 + NAMEW + 8, y + 1, BARW, BARH, frac, staminaColor(frac), false)
    end
end

function UI.drawTeams(team1, team2, control1, control2)
    drawTeamPanel(team1, control1, false)
    drawTeamPanel(team2, control2, true)
end

-- ─── Goal flash ─────────────────────────────────────────────────────────────

function UI.drawGoalFlash(team, alpha)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(fontLarge)
    local msg = "GOAL!"
    local tw  = fontLarge:getWidth(msg)
    love.graphics.print(msg, (800 - tw) / 2, 250)
    love.graphics.setFont(fontMedium)
    local sub = Config.teamName(team) .. " scores!"
    local sw  = fontMedium:getWidth(sub)
    love.graphics.setColor(team == 1 and COL_RED or COL_BLUE)
    love.graphics.print(sub, (800 - sw) / 2, 300)
end

-- ─── Menu screen ────────────────────────────────────────────────────────────

function UI.drawMenu(items, selected, subtitle, navLine)
    -- Dark full-screen overlay
    love.graphics.setColor(0.05, 0.15, 0.05)
    love.graphics.rectangle("fill", 0, 0, 800, 600)

    -- Title banner
    if Assets.title then
        local tw, th = Assets.title:getDimensions()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(Assets.title, (800 - tw) / 2, 60)
    end

    -- Title
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(COL_YELLOW)
    local title = "ATB WorldCup"
    local tw = fontLarge:getWidth(title)
    love.graphics.print(title, (800 - tw) / 2, 80)

    -- Subtitle
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(COL_WHITE)
    local sub = subtitle or "An arcade football game"
    local sw  = fontSmall:getWidth(sub)
    love.graphics.print(sub, (800 - sw) / 2, 136)

    -- Selectable options (difficulties + 2-player), driven by config
    love.graphics.setFont(fontMedium)
    local startY  = 196
    local spacing = 40
    for i, item in ipairs(items) do
        local y = startY + (i - 1) * spacing
        if i == selected then
            love.graphics.setColor(COL_YELLOW)
            love.graphics.print("> " .. item.label, 150, y)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("  " .. item.label, 150, y)
        end
    end

    -- Instructions (below the options list)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.6, 0.6, 0.6)
    local lines = {
        navLine or "W/S or Up/Down: Navigate    Enter: Select",
        "",
        "P1: WASD move  ·  F pass / shoot",
        "P2: Arrows move  ·  L pass / shoot",
        "",
        "Pass to a team-mate to take control of them — FIFA-style!",
        "Players tire as they run — rest them to recover!",
    }
    local instrY = startY + #items * spacing + 24
    for i, line in ipairs(lines) do
        local lw = fontSmall:getWidth(line)
        love.graphics.print(line, (800 - lw) / 2, instrY + (i - 1) * 22)
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
        resultMsg = Config.teamName(1) .. " WINS!"
    elseif score[2] > score[1] then
        love.graphics.setColor(COL_BLUE)
        resultMsg = Config.teamName(2) .. " WINS!"
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
