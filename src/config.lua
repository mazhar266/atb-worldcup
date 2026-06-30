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
            { name = "Rei",     speed = 7, strength = 7, stamina = 8 },
            { name = "Sahabub", speed = 8, strength = 8, stamina = 9 },
            { name = "Rifa",    speed = 7, strength = 3, stamina = 6 },
        },
    },
    [1] = {
        name = "Tech",
        players = {
            { name = "Mazhar", speed =  5, strength = 10, stamina = 6 },
            { name = "Swapon", speed =  7, strength =  8, stamina = 8 },
            { name = "Sadia",  speed = 10, strength =  2, stamina = 6 },
        },
    },
}
-- ─────────────────────────────────────────────────────────────────────────────

local ATTR_MIN, ATTR_MAX = 1, 10

local function clampAttr(v, default)
    if type(v) ~= "number" then return default end
    if v < ATTR_MIN then return ATTR_MIN end
    if v > ATTR_MAX then return ATTR_MAX end
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

function Config.load()
    Config.teams = {
        [1] = normalizeTeam(TEAMS[1], 1),
        [2] = normalizeTeam(TEAMS[2], 2),
    }
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

return Config
