-- src/config.lua: the single source of truth for squad rosters and per-player
-- attributes. Edit the TEAMS table below to change names or stats — no other
-- files are involved. Values are validated on load, so a typo or out-of-range
-- number can't crash the game.
--
-- Attributes use a 1–10 scale:
--   speed    — how fast the player runs
--   strength — how hard / far the player kicks the ball
--   stamina  — the player's "life": their maximum stamina (energy) capacity
--
-- team 1 is the left/red side; team 2 is the right/blue side. In 1-player mode
-- the human controls team 1 and the AI controls team 2. The first player listed
-- starts on the pitch; the rest start on the bench.

local Config = {}

-- ─── EDIT ME: squads, names & attributes ─────────────────────────────────────
local TEAMS = {
    [2] = {
        name = "Business",
        players = {
            { name = "Rei",     speed = 70, strength = 70, stamina = 80 },
            { name = "Sahabub", speed = 80, strength = 80, stamina = 90 },
            { name = "Rifa",    speed = 70, strength = 30, stamina = 60 },
        },
    },
    [1] = {
        name = "Tech",
        players = {
            { name = "Mazhar", speed =  50, strength = 100, stamina = 60 },
            { name = "Swapon", speed =  70, strength =  80, stamina = 80 },
            { name = "Sadia",  speed = 100, strength =  20, stamina = 60 },
        },
    },
}
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── EDIT ME: difficulty modes (shown in the menu; scale the AI opponent) ─────
-- Each entry: a `name` + `tagline` shown in the menu, and AI multipliers —
-- `aiSpeed` scales how fast the AI runs and `aiKick` how hard it kicks
-- (1.0 = normal). The list can be any length; the menu adapts.
local DIFFICULTIES = {
    { name = "Easy",   tagline = "Chhoti bachchi ho keya!", aiSpeed = 0.70, aiKick = 0.85 },
    { name = "Medium", tagline = "We are Friends",          aiSpeed = 1.00, aiKick = 1.00 },
    { name = "Hard",   tagline = "Beak your legs",          aiSpeed = 1.25, aiKick = 1.15 },
}
-- ─────────────────────────────────────────────────────────────────────────────

local ATTR_MIN, ATTR_MAX = 1, 10

local function clampAttr(v, default)
    if type(v) ~= "number" then return default end
    if v < ATTR_MIN then return ATTR_MIN end
    if v > ATTR_MAX then return ATTR_MAX end
    return v
end

local function clampNum(v, default, lo, hi)
    if type(v) ~= "number" then return default end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Coerce one team into a clean { name, players = {...} } with valid attributes.
local function normalizeTeam(team, teamIndex)
    team = (type(team) == "table") and team or {}
    local players = (type(team.players) == "table") and team.players or {}

    local out = { name = (type(team.name) == "string" and team.name) or ("Team " .. teamIndex), players = {} }
    for i, p in ipairs(players) do
        p = (type(p) == "table") and p or {}
        out.players[i] = {
            name     = (type(p.name) == "string" and p.name) or (out.name .. " " .. i),
            speed    = clampAttr(p.speed,    5),
            strength = clampAttr(p.strength, 5),
            stamina  = clampAttr(p.stamina,  5),
        }
    end
    -- Guarantee at least one player so a squad is never empty.
    if #out.players == 0 then
        out.players[1] = { name = out.name .. " 1", speed = 5, strength = 5, stamina = 5 }
    end
    return out
end

-- Coerce the difficulty list into clean, validated entries.
local function normalizeDifficulties(list)
    if type(list) ~= "table" or #list == 0 then
        list = { { name = "Normal", tagline = "" } }
    end
    local out = {}
    for i, d in ipairs(list) do
        d = (type(d) == "table") and d or {}
        out[i] = {
            name    = (type(d.name) == "string" and d.name) or ("Level " .. i),
            tagline = (type(d.tagline) == "string" and d.tagline) or "",
            aiSpeed = clampNum(d.aiSpeed, 1.0, 0.3, 2.0),
            aiKick  = clampNum(d.aiKick,  1.0, 0.3, 2.0),
        }
    end
    return out
end

function Config.load()
    Config.teams = {
        [1] = normalizeTeam(TEAMS[1], 1),
        [2] = normalizeTeam(TEAMS[2], 2),
    }
    Config.diffs = normalizeDifficulties(DIFFICULTIES)
    return Config.teams
end

-- The display name of a team (e.g. "Business" / "Tech"), loading lazily.
function Config.teamName(team)
    if not Config.teams then Config.load() end
    local t = Config.teams[team]
    return t and t.name or ("Team " .. tostring(team))
end

-- The squad (array of {name, speed, strength, stamina}) for a team.
function Config.squad(team)
    if not Config.teams then Config.load() end
    return Config.teams[team].players
end

-- The list of difficulty modes ({name, tagline, aiSpeed, aiKick}).
function Config.difficulties()
    if not Config.diffs then Config.load() end
    return Config.diffs
end

-- One difficulty by index, clamped to the valid range (defaults to the first).
function Config.difficulty(i)
    local list = Config.difficulties()
    i = i or 1
    return list[math.max(1, math.min(#list, i))] or list[1]
end

return Config
