local common_functions = require("Util.common_functions")
local active_objects = require("Util.active_objects")
local interface_objects = require("Util.interface_objects")
local box_collisions = require("Util.box_collisions")
local renderer = require("Util.renderer")
local input_device = require("Util.input_device")
local game_screens = require("Util.game_screens")
local json = require("Util.json")

local game = {}

function love.load()
    love.graphics.setDepthMode("lequal", true)
    game.resolution = {love.graphics.getWidth(), love.graphics.getHeight()}
    game.internal_resolution = {1280, 800}

    game.camera = renderer.Camera:new(0.1)
    game.screen = renderer.Screen:new(game.internal_resolution)

    love.window.setTitle("REENCOR")

    game.image_dict = {}
    game.sound_dict = {}
    game.object_dict = {}

    load_assets("Assets")

    game.object_list = {}

    -- ... (the rest of the game state initialization)

    init_input_devices()

    game.screen_sequence = {"ModeSelectionScreen"}
    -- ...
end

function love.update(dt)
    -- ...
end

function love.draw()
    love.graphics.clear(0.1, 0.1, 0.1, 1, 1, 0)

    game.camera:apply()

    if game.current_screen then
        game.current_screen:draw()
    end

    game.screen:display()
end

function init_input_devices()
    for i = 1, love.joystick.getJoystickCount() do
        table.insert(game.input_device_list, input_device.InputDevice:new(game, i, i, "joystick"))
    end
    table.insert(game.input_device_list, input_device.InputDevice:new(game, #game.input_device_list + 1, nil, "keyboard"))
end

-- ... (the rest of the helper functions)
