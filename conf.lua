-- conf.lua: LÖVE2D window and module configuration

function love.conf(t)
    t.window.title   = "ATB WorldCup"
    t.window.width   = 800
    t.window.height  = 600
    t.window.vsync   = 1
    t.window.resizable = false

    -- Disable unused modules for a lighter footprint
    t.modules.joystick = false
    t.modules.physics  = false
end
