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

    game.emu_frame = 0
    game.hitstop = 0
    game.camera_focus_point = {0, 0, 400}
    game.superstop = 0
    game.camera_path = nil
    game.frame = {0, 0}
    game.pos = {10, 0, 0}
    game.draw_shake = {0, 0, 0, 0, 0, 0}

    game.show_boxes = false
    game.show_inputs = false

    game.player_number = 2
    game.selected_characters = {"SF3/Ryu", "SF3/Ken"}
    game.selected_stage = {"Reencor/Training"}

    game.input_device_list = {}
    init_input_devices()
    game.dummy_input_device = input_device.dummy_input

    game.screen_sequence = {"ModeSelectionScreen"}
    game.current_screen = nil
    game.screen_parameters = {}

    game.active_players = {}
    game.active_stages = nil

    next_screen({"ComboTrialScreen"}) -- Initial screen for testing
end

function love.update(dt)
    if game.current_screen and game.current_screen.update then
        game.current_screen:update(dt)
    elseif not game.current_screen then
        if #game.screen_sequence > 0 then
            local next_screen_name = table.remove(game.screen_sequence)
            if game_screens[next_screen_name] then
                game.current_screen = game_screens[next_screen_name]:new(game, unpack(game.screen_parameters))
                game.screen_parameters = {}
            else
                print("Error: screen not found: " .. tostring(next_screen_name))
            end
        else
            love.event.quit()
        end
    end

    if game.input_device_list then
        for _, dev in ipairs(game.input_device_list) do
            if dev and dev.update then
                dev:update(dt)
            end
        end
    end

    if game.dummy_input_device and game.dummy_input_device.update then
        game.dummy_input_device:update(dt)
    end

    if game.camera and game.camera.update then
        game.camera:update(game.camera_focus_point)
    end
end

function love.draw()
    love.graphics.clear(0.1, 0.1, 0.1, 1, 1, 0)

    game.camera:apply()

    if game.current_screen and game.current_screen.draw then
        game.current_screen:draw()
    end

    game.screen:display()
end

-- ... (the rest of the file)
