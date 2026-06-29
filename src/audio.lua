-- src/audio.lua: Sound effect / music loader and playback helpers.
--
-- Assets live in assets/sfx/. The richer effects are OGG (theme, start, crowd,
-- move, and the kick0-3 / goal0-1 variants); a few simple cues only exist as the
-- generated WAVs (bounce, substitute, whistle) and are used as fallbacks.
-- If a file is missing or love.audio is unavailable, every play call is a no-op.

local Audio = {}

-- Mixing levels (0..1)
local SFX_VOLUME    = 0.7
local BOUNCE_VOLUME = 0.45   -- bounces are frequent; keep them quiet
local MUSIC_VOLUME  = 0.35   -- theme music bed
local CROWD_VOLUME  = 0.30   -- crowd ambience bed
local MOVE_VOLUME   = 0.35   -- footstep / movement loop

-- Load a single source, returning nil on any failure (missing file, no audio
-- device). `kind` is "static" (short SFX) or "stream" (long looping beds).
local function loadSource(path, kind, volume)
    if not (love and love.audio) then return nil end
    local ok, src = pcall(love.audio.newSource, path, kind or "static")
    if not ok or not src then return nil end
    src:setVolume(volume or SFX_VOLUME)
    return src
end

-- Load the first path that exists (used for ogg-preferred-then-wav fallback).
local function loadFirst(paths, kind, volume)
    for _, p in ipairs(paths) do
        local src = loadSource(p, kind, volume)
        if src then return src end
    end
    return nil
end

-- Load every path that exists into an array (used for randomised variants).
local function loadVariants(paths, volume)
    local list = {}
    for _, p in ipairs(paths) do
        local src = loadSource(p, "static", volume)
        if src then list[#list + 1] = src end
    end
    return list
end

local function loop(src)
    if src then src:setLooping(true) end
    return src
end

function Audio.load()
    -- One-shot SFX with randomised variants (fall back to the single WAV).
    Audio.kicks = loadVariants({
        "assets/sfx/kick0.ogg", "assets/sfx/kick1.ogg",
        "assets/sfx/kick2.ogg", "assets/sfx/kick3.ogg",
    }, SFX_VOLUME)
    if #Audio.kicks == 0 then
        Audio.kicks = loadVariants({ "assets/sfx/kick.wav" }, SFX_VOLUME)
    end

    Audio.goals = loadVariants({
        "assets/sfx/goal0.ogg", "assets/sfx/goal1.ogg",
    }, SFX_VOLUME)
    if #Audio.goals == 0 then
        Audio.goals = loadVariants({ "assets/sfx/goal.wav" }, SFX_VOLUME)
    end

    -- Single-shot cues (ogg preferred, wav fallback where only wav exists).
    Audio.bounce     = loadFirst({ "assets/sfx/bounce.ogg",     "assets/sfx/bounce.wav" },     "static", BOUNCE_VOLUME)
    Audio.substitute = loadFirst({ "assets/sfx/substitute.ogg", "assets/sfx/substitute.wav" }, "static", SFX_VOLUME)
    Audio.whistle    = loadFirst({ "assets/sfx/whistle.ogg",    "assets/sfx/whistle.wav" },    "static", SFX_VOLUME)
    Audio.start      = loadFirst({ "assets/sfx/start.ogg",      "assets/sfx/start.wav" },      "static", SFX_VOLUME)

    -- Looping beds (streamed so the large theme isn't decoded into memory).
    Audio.theme = loop(loadSource("assets/sfx/theme.ogg", "stream", MUSIC_VOLUME))
    Audio.crowd = loop(loadSource("assets/sfx/crowd.ogg", "stream", CROWD_VOLUME))
    Audio.move  = loop(loadSource("assets/sfx/move.ogg",  "static", MOVE_VOLUME))
end

-- ─── One-shot helpers ─────────────────────────────────────────────────────────

local function playOneShot(src)
    if src then
        src:stop()
        src:play()
    end
end

local function playRandom(list)
    if list and #list > 0 then
        local src = list[(love and love.math and love.math.random(#list)) or 1]
        src:stop()
        src:play()
    end
end

function Audio.playKick()       playRandom(Audio.kicks) end
function Audio.playGoal()       playRandom(Audio.goals) end
function Audio.playBounce()     playOneShot(Audio.bounce) end
function Audio.playSubstitute() playOneShot(Audio.substitute) end
function Audio.playWhistle()    playOneShot(Audio.whistle) end
function Audio.playStart()      playOneShot(Audio.start) end

-- ─── Looping beds ─────────────────────────────────────────────────────────────

local function startLoop(src)
    if src and not src:isPlaying() then src:play() end
end

local function stopLoop(src)
    if src and src:isPlaying() then src:stop() end
end

function Audio.startTheme() startLoop(Audio.theme) end
function Audio.stopTheme()  stopLoop(Audio.theme) end
function Audio.startCrowd() startLoop(Audio.crowd) end
function Audio.stopCrowd()  stopLoop(Audio.crowd) end

-- Toggle the movement loop each frame based on whether a human is running.
-- Uses pause/resume so the loop is seamless rather than restarting.
function Audio.setMoving(moving)
    local src = Audio.move
    if not src then return end
    if moving then
        if not src:isPlaying() then src:play() end
    elseif src:isPlaying() then
        src:pause()
    end
end

return Audio
