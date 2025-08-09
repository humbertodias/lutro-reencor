local common_functions = require("Util.common_functions")
local active_objects = require("Util.active_objects")
local interface_objects = require("Util.interface_objects")
local box_collisions = require("Util.box_collisions")
local renderer = require("Util.renderer")
local input_device = require("Util.input_device")
local game_screens = require("Util.game_screens")
local json = require("Util.json")

local game = {}
local load_assets, init_input_devices, next_screen -- Forward declarations

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

    print("game_screens content:")
    for k,v in pairs(game_screens) do
        print(k, v)
    end

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

    next_screen({"ComboTrialScreen"})
end

-- ... (the rest of the file is the same as before)
