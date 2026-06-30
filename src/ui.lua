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

-- Draw one team's fitness panel (active stamina + bench pips + sub hint) in a
-- top corner of the pitch. alignRight mirrors the layout for the right team.
local function drawSquadPanel(p, alignRight, subKey)
    local BARW, BARH = 120, 9
    local PIPW, PIPH = 34, 5
    local x0 = alignRight and (Field.right - 10 - BARW) or (Field.x + 10)
    local y0 = Field.y + 8
    local hasHint = (p.control ~= "ai")

    love.graphics.setFont(fontTiny)
    local lineH = fontTiny:getHeight()

    local m0      = p:activeMember()
    local name    = m0.name or ("#" .. tostring(m0.number or "?"))
    local attrStr = string.format("SPD %d  STR %d  STA %d",
        m0.attrSpeed or 0, m0.attrStrength or 0, m0.attrStamina or 0)
    local nameW   = fontTiny:getWidth(name)
    local attrW   = fontTiny:getWidth(attrStr)

    -- Vertical layout: stamina bar → attribute line → bench pips → sub hint
    local attrY = y0 + BARH + 3
    local pipY  = attrY + lineH + 4
    local hintY = pipY + PIPH + 4

    -- Opaque backing so moving sprites can't bleed through the panel.
    local pad = 5
    local bgL, bgR
    if alignRight then
        bgL = math.min(x0 - 6 - nameW, x0 + BARW - attrW)
        bgR = x0 + BARW
    else
        bgL = x0
        bgR = math.max(x0 + BARW + 6 + nameW, x0 + attrW)
    end
    local bgB = hasHint and (hintY + lineH) or (pipY + PIPH)
    love.graphics.setColor(COL_PANEL_BG)
    love.graphics.rectangle("fill", bgL - pad, y0 - pad, (bgR - bgL) + pad * 2, (bgB - y0) + pad * 2, 4, 4)

    -- Active player's stamina bar
    local frac = p:staminaFrac()
    drawBar(x0, y0, BARW, BARH, frac, staminaColor(frac), alignRight)

    -- Active player's name beside the bar
    love.graphics.setColor(1, 1, 1, 0.95)
    if alignRight then
        love.graphics.print(name, x0 - nameW - 6, y0 - 2)
    else
        love.graphics.print(name, x0 + BARW + 6, y0 - 2)
    end

    -- Attribute readout (speed / strength / stamina, 1–10 scale)
    love.graphics.setColor(0.72, 0.74, 0.8)
    if alignRight then
        love.graphics.print(attrStr, x0 + BARW - attrW, attrY)
    else
        love.graphics.print(attrStr, x0, attrY)
    end

    -- Bench pips, colour-coded by each member's stamina fraction so the freshest
    -- sub — the one substitute() will bring on — reads at a glance.
    local benchIdx = 0
    for i, m in ipairs(p.roster) do
        if i ~= p.active then
            local pf = (m.maxStamina and m.maxStamina > 0) and (m.stamina / m.maxStamina) or 0
            local px = alignRight
                and (x0 + BARW - PIPW - benchIdx * (PIPW + 6))
                or  (x0 + benchIdx * (PIPW + 6))
            drawBar(px, pipY, PIPW, PIPH, pf, staminaColor(pf), alignRight)
            benchIdx = benchIdx + 1
        end
    end

    -- Substitution key hint (only meaningful for human-controlled teams)
    if hasHint then
        local ready = p.subCooldown <= 0
        love.graphics.setColor(ready and {0.95, 0.95, 0.6} or {0.5, 0.5, 0.5})
        local hint = ready and ("SUB: " .. subKey) or "subbing..."
        if alignRight then
            love.graphics.print(hint, x0 + BARW - fontTiny:getWidth(hint), hintY)
        else
            love.graphics.print(hint, x0, hintY)
        end
    end
end

function UI.drawStamina(player1, player2)
    drawSquadPanel(player1, false, "Q")
    drawSquadPanel(player2, true,  "K")
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

function UI.drawMenu(menuOption)
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
        "P1: WASD move  ·  F kick  ·  Q substitute",
        "P2: Arrows move  ·  L kick  ·  K substitute",
        "",
        "Players tire as they run — sub on fresh legs!",
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
        resultMsg = Config.teamName(1) .. " wins! 🏆"
    elseif score[2] > score[1] then
        love.graphics.setColor(COL_BLUE)
        resultMsg = Config.teamName(2) .. " wins! 🏆"
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
