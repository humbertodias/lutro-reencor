function love.conf(t)
    t.window.title = "Reencor Remake - Love2D"
    t.window.width = 1280
    t.window.height = 800
    t.window.vsync = 1             -- Enable VSync (recommended)

    t.modules.audio = true
    t.modules.event = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.sound = true -- For decoding sound data
    t.modules.timer = true
    t.modules.window = true
    t.modules.filesystem = true

    -- For debugging (Love2D 11.0+)
    t.console = true
end
