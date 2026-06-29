-- src/assets.lua: Central asset loader with graceful fallbacks.
--
-- The game ships with generated PNG sprites in assets/. If any file is missing
-- the loader returns nil and callers fall back to the original shape-based
-- rendering.

local Assets = {}

local function tryLoad(path)
    local ok, img = pcall(love.graphics.newImage, path)
    if ok then
        img:setFilter("nearest", "nearest")
        return img
    end
    return nil
end

function Assets.load()
    Assets.ball = tryLoad("assets/ball.png")

    Assets.playerRed = {
        tryLoad("assets/player_red_1.png"),
        tryLoad("assets/player_red_2.png"),
        tryLoad("assets/player_red_3.png"),
    }
    Assets.playerBlue = {
        tryLoad("assets/player_blue_1.png"),
        tryLoad("assets/player_blue_2.png"),
        tryLoad("assets/player_blue_3.png"),
    }

    Assets.grass = tryLoad("assets/grass.png")
    Assets.title = tryLoad("assets/title.png")
end

function Assets.playerSprite(team, activeIndex)
    local list = (team == 1) and Assets.playerRed or Assets.playerBlue
    local img = list and list[activeIndex]
    return img or list and list[1]
end

return Assets
