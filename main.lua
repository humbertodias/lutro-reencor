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
    game.selected_characters = {"ryu SF3", "ryu SF3"}
    game.selected_stage = {"trining stage"}

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

function love.joystickadded(joystick)
    table.insert(game.input_device_list, input_device.InputDevice:new(game, #game.input_device_list + 1, joystick:getID(), "joystick"))
end

function load_assets(dir)
    local items = love.filesystem.getDirectoryItems(dir)
    for _, item in ipairs(items) do
        local full_path = dir .. "/" .. item
        if love.filesystem.getInfo(full_path).type == "directory" then
            load_assets(full_path)
        else
            local ext = item:match("^.+(%..+)$")
            if ext then ext = ext:sub(2):lower() end

            local key = full_path:gsub("Assets/", ""):gsub("%..+$", "")
            print("Loading asset:", key, ext)

            if ext == "png" or ext == "jpg" or ext == "jpeg" then
                local img, size = renderer.Renderer.load_image_path(full_path)
                if img then
                    game.image_dict[key] = {img, size}
                end
            elseif ext == "wav" or ext == "ogg" or ext == "mp3" then
                local sound = love.audio.newSource(full_path, "static")
                if sound then
                    game.sound_dict[key] = sound
                end
            elseif ext == "json" then
                local file_content = love.filesystem.read(full_path)
                local success, data = pcall(json.decode, file_content)
                if success then
                    game.object_dict[key] = data
                else
                    print("Failed to load JSON: " .. full_path)
                end
            end
        end
    end
end

function init_input_devices()
    for i = 1, love.joystick.getJoystickCount() do
        table.insert(game.input_device_list, input_device.InputDevice:new(game, i, i, "joystick"))
    end
    table.insert(game.input_device_list, input_device.InputDevice:new(game, #game.input_device_list + 1, nil, "keyboard"))
end

function next_screen(screen_sequence)
    for _, screen_name in ipairs(screen_sequence) do
        table.insert(game.screen_sequence, 1, screen_name)
    end
    if game.current_screen and game.current_screen.deinit then
        game.current_screen:deinit()
    end
    game.current_screen = nil
end

game.next_screen = next_screen
