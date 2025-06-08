-- main.lua
-- Main Love2D entry point, reviewed and refactored for Love2D best practices.

-- Global Game Table
Game = {}

-- Standard Love2D Path for requiring modules
-- Ensure your .lua files are in these directories or adjust paths accordingly.
package.path = package.path ..
    ";./utils/?.lua" ..
    ";./objects/?.lua" ..
    ";./screens/?.lua" ..
    ";./ui/?.lua" ..
    ";./?.lua" -- For dkjson if in root

-- Require translated modules
local CommonFunctions = require("utils.common_functions")
local Renderer = require("utils.renderer")
local InputDevice = require("utils.input_device")
local InterfaceObjects = require("ui.interface_objects")
local GameScreens = require("screens.game_screens")
local BoxCollisions = require("utils.box_collisions")
local BaseActiveObjectModule = require("objects.base_active_object") -- Module table
local BaseActiveObject = BaseActiveObjectModule.BaseActiveObject

-- For JSON parsing (ensure dkjson.lua is in your project, e.g., in 'utils' or root)
local dkjson_success, dkjson_lib = pcall(require, "dkjson")
if not dkjson_success then
    error("Failed to load dkjson library. Please ensure dkjson.lua is in your project path.\n" .. dkjson_lib)
end
local json = dkjson_lib

-- Screen Manager
ScreenManager = {
    currentScreen = nil,
    screenStack = {}
}

function ScreenManager:switchTo(screen_module_name, params)
    print("Attempting to switch to screen: " .. tostring(screen_module_name))
    if self.currentScreen and self.currentScreen.on_exit then
        self.currentScreen:on_exit()
    end

    local screen_class = GameScreens[screen_module_name]
    if screen_class and screen_class.new then
        local screen_instance = screen_class:new(Game, params) -- Pass global Game table
        self.currentScreen = screen_instance
        print("Switched to screen:", screen_module_name)

        -- Reset global game states (from Python's screen_manager loop end)
        Game.hitstop = 0
        Game.camera_focus_point = Game.camera_focus_point or {0,0,400}
        Game.camera_focus_point[1], Game.camera_focus_point[2], Game.camera_focus_point[3] = 0, (Game.internal_resolution[2] or 800) * 0.3, 400
        Game.superstop = 0
        Game.camera_path = {}
        Game.frame_camera_path = {0,0}
        Game.pos_camera_focus = {10,0,0}
        Game.draw_shake_camera = {0,0,0,0,0,0}
        if Game.camera then Game.camera.draw_shake = Game.draw_shake_camera end
        Game.show_boxes = false
        Game.record_input = false
        Game.reproduce_input = false
    else
        love.graphics.print("Error: Screen module or class not found: " .. tostring(screen_module_name), 10, 50)
        error("Screen module or class not found or has no :new() method: " .. tostring(screen_module_name))
    end
end

local function clamp(value, min_val, max_val)
    return math.max(min_val, math.min(value, max_val))
end

function Game.loadAssets()
    Game.object_dict = {}
    Game.image_dict = {}
    Game.sound_dict = {}
    Game.font_dict = {} -- For Love2D Font objects

    Game.assets_path = "Assets" -- Changed "assets" to "Assets"

    --[[ Function get_key_from_path moved to CommonFunctions module ]]

    local function load_item(item_path_in_assets)
        print("Attempting to load item: " .. Game.assets_path .. "/" .. item_path_in_assets)
        local file_info = love.filesystem.getInfo(Game.assets_path .. "/" .. item_path_in_assets)
        if file_info then print("Found item: " .. item_path_in_assets .. ", type: " .. file_info.type) else print("Failed to get info for: " .. Game.assets_path .. "/" .. item_path_in_assets) end
        if not file_info or file_info.type ~= "file" then return end

        local ext = string.match(item_path_in_assets, "%.([^.]+)$")
        if not ext then return end
        ext = string.lower(ext)

        local full_fs_path = Game.assets_path .. "/" .. item_path_in_assets -- Used for love.filesystem calls
        local key = CommonFunctions.get_key_from_path(item_path_in_assets) -- Use CommonFunctions

        if ext == "png" or ext == "jpg" or ext == "jpeg" then
            local img = Renderer.loadImage(full_fs_path) -- Renderer.loadImage uses love.graphics.newImage
            if img then
                Game.image_dict[key] = {img, {img:getWidth(), img:getHeight()}}
                print("Loaded image with key: '" .. key .. "' from path: '" .. full_fs_path .. "'")
            end
        elseif ext == "wav" or ext == "ogg" or ext == "mp3" then
            local success, snd = pcall(love.audio.newSource, full_fs_path, "static")
            if success then
                Game.sound_dict[key] = snd
                print("Loaded sound with key: '" .. key .. "' from path: '" .. full_fs_path .. "'")
            else
                print("Error loading sound:", full_fs_path, snd)
            end
        elseif ext == "json" then
            local content = love.filesystem.read(full_fs_path)
            if content then
                -- local success, data = json.decode(content) -- Use the loaded dkjson library
                -- if success then
                --     local base_dummy = CommonFunctions.dummy_json
                --     local merged_data = CommonFunctions.merge_tables(base_dummy, data)
                --     merged_data.boxes = CommonFunctions.merge_tables(base_dummy.boxes, data.boxes or {})
                --     for box_type, default_box_content in pairs(base_dummy.boxes) do
                --         merged_data.boxes[box_type] = CommonFunctions.merge_tables(default_box_content, merged_data.boxes[box_type] or {})
                --     end
                --     Game.object_dict[key] = merged_data
                -- else
                --     print("Error decoding JSON:", full_fs_path, data)
                -- end
                -- TODO: MINE

                local data, pos, err = json.decode(content)
                if data then
                    local base_dummy = CommonFunctions.dummy_json
                    local merged_data = CommonFunctions.merge_tables(base_dummy, data)
                    merged_data.boxes = CommonFunctions.merge_tables(base_dummy.boxes, data.boxes or {})
                    for box_type, default_box_content in pairs(base_dummy.boxes) do
                        merged_data.boxes[box_type] = CommonFunctions.merge_tables(default_box_content, merged_data.boxes[box_type] or {})
                    end
                    Game.object_dict[key] = merged_data
                    print("Loaded JSON object with key: '" .. key .. "' from path: '" .. full_fs_path .. "'")
                    print("---- Merged JSON data for key: " .. key .. " ----")
                    if merged_data.type then print("Type: " .. merged_data.type) end
                    if merged_data.name then print("Name: " .. merged_data.name) end
                    if merged_data.portrait then print("Portrait path: " .. merged_data.portrait) end
                    if merged_data.states and merged_data.states.Stand then print("Has Stand state: true") else print("Has Stand state: false or states missing") end
                    if merged_data.animations and merged_data.animations.Stand_anim then print("Has Stand_anim: true") else print("Has Stand_anim: false or animations missing") end
                    if merged_data.boxes and merged_data.boxes.collision_box then print("Has collision_box: true") else print("Has collision_box: false or boxes missing") end
                    print("---- End Merged JSON for key: " .. key .. " ----")
                else
                    print("Error decoding JSON:", full_fs_path, err)
                end

            else
                print("Error reading JSON file:", full_fs_path)
            end
        elseif ext == "ttf" or ext == "otf" then -- Load fonts directly
            -- The original code loaded one specific font for pre-rendering chars.
            -- Here we can make it more general if other fonts are found.
            -- For now, only "Util/unispace bd.ttf" is explicitly handled later.
            print("Detected font file: " .. full_fs_path .. " with key: " .. key .. ". Will be loaded if used by Renderer.loadFont.")
        end
    end

    local function walk_dir(folder_in_assets)
        print("Walking directory: " .. Game.assets_path .. "/" .. folder_in_assets)
        local items_in_dir = love.filesystem.getDirectoryItems(Game.assets_path .. "/" .. folder_in_assets)
        for _, item_name in ipairs(items_in_dir) do
            local current_path_in_assets = folder_in_assets .. (folder_in_assets == "" and "" or "/") .. item_name
            print("Checking item in dir: " .. item_name .. " at path: " .. Game.assets_path .. "/" .. current_path_in_assets)
            local item_info = love.filesystem.getInfo(Game.assets_path .. "/" .. current_path_in_assets)
            if item_info then
                print("Item info: type=" .. item_info.type .. ", size=" .. (item_info.size or "N/A"))
                if item_info.type == "directory" then
                    walk_dir(current_path_in_assets)
                elseif item_info.type == "file" then
                    load_item(current_path_in_assets)
                end
            else
                print("Could not get item_info for: " .. current_path_in_assets)
                print("Warning: Could not get info for asset item: " .. current_path_in_assets) -- Kept original warning too
            end
        end
    end

    walk_dir("")

    -- Load font characters (as in original Python's get_dictionaries)
    local font_path_key = "Util/unispace bd" -- Key derived from "Util/unispace bd.ttf"
    local font_asset_path = Game.assets_path .. "/Util/unispace bd.ttf" -- Actual path
    if not love.filesystem.getInfo(font_asset_path) then
        -- Fallback if it was not moved under assets/Util but e.g. assets/fonts/
        local alternative_font_path = Game.assets_path .. "/fonts/unispace bd.ttf"
        if love.filesystem.getInfo(alternative_font_path) then
            font_asset_path = alternative_font_path
            font_path_key = "fonts/unispace bd" -- Update key if path changes
        else
            print("Warning: Main font 'unispace bd.ttf' not found at expected paths.")
            font_asset_path = nil
        end
    end

    if font_asset_path then
        local font_size = 60
        local main_font_obj = Renderer.loadFont(font_asset_path, font_size) -- Uses font_cache in Renderer
        if main_font_obj then
            Game.font_dict["main_unispace_60"] = main_font_obj -- Store the Love2D font object
            local chars_to_load = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+- :_/?!.,;()[]{}"
            for i = 1, #chars_to_load do
                local char = string.sub(chars_to_load, i, i)
                -- Renderer.loadFontCharacterAsImage uses a canvas, which is a Drawable (Image-like)
                local char_img_canvas = Renderer.loadFontCharacterAsImage(main_font_obj, char, 200,200,200)
                if char_img_canvas then
                    Game.image_dict["font " .. char] = {char_img_canvas, {char_img_canvas:getWidth(), char_img_canvas:getHeight()}}
                    print("Loaded font character with key: 'font " .. char .. "'")
                end
            end
        else
            print("Failed to load main font via Renderer: " .. font_asset_path)
        end
    end
end

function Game.initializeInputDevices()
    Game.input_device_list = {} -- Reset if re-initializing
    table.insert(Game.input_device_list, InputDevice:new(Game, 1, nil, "keyboard")) -- Keyboard is P1

    local joysticks = love.joystick.getJoysticks()
    for i, joy in ipairs(joysticks) do
        if joy:isConnected() then
            -- Pass the joystick object itself (Love2D index `i` is also its ID for callbacks)
            table.insert(Game.input_device_list, InputDevice:new(Game, #Game.input_device_list + 1, joy, "joystick"))
        end
    end
    Game.dummy_input_device = InputDevice.initialize_dummy(Game)
end

function Game.calculateCameraFocusPoint()
    if not Game.active_players or #Game.active_players == 0 then
        Game.camera_focus_point = { (Game.internal_resolution[1] or 640)/2, (Game.internal_resolution[2] or 400) * 0.3, 400}
        return
    end

    local sum_x, sum_y = 0,0
    for _, p_obj in ipairs(Game.active_players) do
        sum_x = sum_x + p_obj.pos[1]
        sum_y = sum_y + p_obj.pos[2]
    end
    local num_players = #Game.active_players

    Game.pos_camera_focus = {
        sum_x / num_players,
        (sum_y / num_players) + (Game.internal_resolution[2] or 800) * 0.1, -- Y focus slightly above midpoint of players
        400
    }

    if Game.active_stages and #Game.active_stages > 0 then
        local stage_dict = Game.active_stages[1].dict
        local camera_limits = stage_dict and stage_dict.camera_focus_point_limit

        if camera_limits and camera_limits[1] and camera_limits[2] then -- Ensure limits are defined
            local half_width_internal = Game.internal_resolution[1] * 0.5 / (Game.camera and Game.camera.zoom or 1)
            local half_height_internal = Game.internal_resolution[2] * 0.5 / (Game.camera and Game.camera.zoom or 1)

            Game.pos_camera_focus[1] = clamp(Game.pos_camera_focus[1], camera_limits[1][1] + half_width_internal, camera_limits[1][2] - half_width_internal)
            Game.pos_camera_focus[2] = clamp(Game.pos_camera_focus[2], camera_limits[2][2] + half_height_internal, camera_limits[2][1] - half_height_internal) -- Original Y min/max seemed swapped (max was index 1, min index 2)
        end
    end

    if Game.camera_path and Game.camera_path.path and #Game.camera_path.path > 0 then
        local current_path_idx = Game.frame_camera_path[2]
        if not Game.camera_path.path[current_path_idx] then -- Path ended or invalid index
            Game.camera_path = {}
            Game.frame_camera_path = {0,0}
            Game.camera_focus_point = Game.pos_camera_focus -- Default to player focus
            return
        end

        local path_frame_data = Game.camera_path.path[current_path_idx]
        local path_obj_ref_name = Game.camera_path.object
        local actual_path_obj
        if path_obj_ref_name == "self" then actual_path_obj = Game.active_players[1]
        elseif path_obj_ref_name == "other" then actual_path_obj = Game.active_players[2]
        end
        actual_path_obj = actual_path_obj or {pos={0,0,0}, face=1}

        local scale_cam = math.abs(400 / (path_frame_data.pos[3] or 400))
        local current_zoom = math.abs((Game.camera_focus_point and Game.camera_focus_point[3] or 400) / 400)

        local cx = path_frame_data.pos[1] * actual_path_obj.face + actual_path_obj.pos[1]
        local cy = path_frame_data.pos[2] + actual_path_obj.pos[2]
        local cz = math.floor(scale_cam + 0.5)

        local half_w_eff = Game.internal_resolution[1] * 0.5 * current_zoom
        local half_h_eff = Game.internal_resolution[2] * 0.5 * current_zoom

        local min_x_bound = Game.pos_camera_focus[1] - Game.internal_resolution[1] * 0.5 + half_w_eff
        local max_x_bound = Game.pos_camera_focus[1] + Game.internal_resolution[1] * 0.5 - half_w_eff
        local min_y_bound = Game.pos_camera_focus[2] - Game.internal_resolution[2] * 0.5 + half_h_eff
        local max_y_bound = Game.pos_camera_focus[2] + Game.internal_resolution[2] * 0.5 - half_h_eff

        Game.camera_focus_point = {
            clamp(cx, min_x_bound, max_x_bound),
            clamp(cy, min_y_bound, max_y_bound),
            cz
        }

        Game.frame_camera_path[1] = Game.frame_camera_path[1] + 1
        if Game.frame_camera_path[1] > path_frame_data.dur then
            Game.frame_camera_path[1] = 0
            Game.frame_camera_path[2] = Game.frame_camera_path[2] + 1
            if Game.frame_camera_path[2] > #Game.camera_path.path then
                Game.camera_path = {}
                Game.frame_camera_path = {0,0}
            end
        end
    else
        Game.camera_focus_point = Game.pos_camera_focus
    end
end

function Game:gameplay_update(dt)
    Game.emu_frame = (Game.emu_frame or 0) + 1

    for i = #Game.object_list, 1, -1 do
        local obj = Game.object_list[i]
        if obj and obj.update then
            obj:update(dt)
        end
    end

    if Game.hitstop and Game.hitstop > 0 then Game.hitstop = Game.hitstop - 1 end

    for _, obj in ipairs(Game.object_list) do
        if obj and obj.draw_shake and CommonFunctions.update_display_shake then
            CommonFunctions.update_display_shake(obj)
        end
    end

    if BoxCollisions.calculate_boxes_collitions then BoxCollisions.calculate_boxes_collitions(Game) end

    if Game.camera and Game.camera.draw_shake and CommonFunctions.update_display_shake then
        CommonFunctions.update_display_shake(Game.camera)
    end
    Game.calculateCameraFocusPoint()
end

function Game:gameplay_draw()
    if Game.camera then Game.camera:attach() end

    for _, obj in ipairs(Game.object_list) do
        if obj and obj.draw then
            obj:draw()
        end
        if Game.show_boxes and obj and BoxCollisions.draw_boxes_debug then
            BoxCollisions.draw_boxes_debug(Game, obj)
        end
    end

    if Game.show_inputs then
        for _, dev in ipairs(Game.input_device_list or {}) do
            if dev and dev.draw then dev:draw() end
        end
    end

    if Game.camera then Game.camera:detach() end
end

--------------------------------------------------------------------------------
-- Love2D Callbacks
--------------------------------------------------------------------------------

function love.load()
    if arg[#arg] == "-debug" then require("mobdebug").start() end

    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Reencor Remake - Love2D")
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)

    Game.resolution = {love.graphics.getWidth(), love.graphics.getHeight()}
    Game.internal_resolution = {1280, 800}
    Game.frame_rate = 60
    -- TODO: MINE
    --love.timer.setStep(1/Game.frame_rate) -- For fixed update if desired, or use dt freely

    Game.camera = Renderer.Camera:new(0.1)
    Game.internal_canvas = love.graphics.newCanvas(Game.internal_resolution[1], Game.internal_resolution[2])
    Game.internal_canvas:setFilter("nearest","nearest")


    Game.loadAssets()
    Game.object_list = {}

    Game.emu_frame = 0
    Game.hitstop = 0
    Game.camera_focus_point = {Game.internal_resolution[1]/2, Game.internal_resolution[2] * 0.3, 400}
    Game.superstop = 0
    Game.camera_path = {}
    Game.frame_camera_path = {0,0}
    Game.pos_camera_focus = {Game.internal_resolution[1]/2, Game.internal_resolution[2] * 0.3,0}
    Game.draw_shake_camera = {0,0,0,0,0,0}
    if Game.camera then Game.camera.draw_shake = Game.draw_shake_camera end

    Game.show_boxes = false
    Game.show_inputs = false
    Game.player_number = 2
    Game.selected_characters = {"SF3/Ryu", "SF3/Ken"}
    Game.selected_stage = {"Reencor/Training"}

    Game.initializeInputDevices()

    ScreenManager:switchTo("ModeSelectionScreen")

    Game.active_players = {}
    Game.active_stages = {}
end

function love.update(dt)
    for i, dev in ipairs(Game.input_device_list or {}) do
        if dev.update then dev:update(dt) end
    end

    if Game.camera and Game.camera.update and Game.camera_focus_point then
        Game.camera:update(dt, Game.camera_focus_point)
    end

    if ScreenManager.currentScreen and ScreenManager.currentScreen.update then
        ScreenManager.currentScreen:update(dt)
    end

    if Game.next_screen_key then
        local key = Game.next_screen_key
        local params = Game.next_screen_params
        Game.next_screen_key = nil
        Game.next_screen_params = nil
        ScreenManager:switchTo(key, params)
    end
end

function love.draw()
    love.graphics.setCanvas(Game.internal_canvas)
    love.graphics.clear() -- Clear the internal canvas

        -- Test draw red rectangle to internal canvas
        love.graphics.setColor(1, 0, 0, 1) -- Bright red
        love.graphics.rectangle("fill", 0, 0, Game.internal_resolution[1] / 4, Game.internal_resolution[2] / 4) -- Top-left quadrant of canvas
        love.graphics.setColor(1, 1, 1, 1) -- Reset color

        if ScreenManager.currentScreen and ScreenManager.currentScreen.draw then
            ScreenManager.currentScreen:draw()
        else
            love.graphics.print("No current screen to draw.", 100, 100)
        end

    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1,1)
    -- Scale internal canvas to window size
    local scale_x = love.graphics.getWidth() / Game.internal_resolution[1]
    local scale_y = love.graphics.getHeight() / Game.internal_resolution[2]
    love.graphics.draw(Game.internal_canvas, 0,0, 0, scale_x, scale_y)

    love.graphics.setColor(1, 1, 0, 1) -- Yellow color for camera stats
    love.graphics.print("Cam X: " .. string.format("%.2f", Game.camera.x), 10, 50)
    love.graphics.print("Cam Y: " .. string.format("%.2f", Game.camera.y), 10, 70)
    love.graphics.print("Cam Zoom: " .. string.format("%.2f", Game.camera.zoom), 10, 90)
    if Game.camera_focus_point then
        love.graphics.print("Focus X: " .. string.format("%.2f", Game.camera_focus_point[1]), 10, 110)
        love.graphics.print("Focus Y: " .. string.format("%.2f", Game.camera_focus_point[2]), 10, 130)
        love.graphics.print("Focus Z (Zoom): " .. string.format("%.2f", Game.camera_focus_point[3]), 10, 150)
    end
    love.graphics.print("Current Screen: " .. (ScreenManager.currentScreen and ScreenManager.currentScreen.screen_name or "None"), 10, 170)
    love.graphics.setColor(1, 1, 1, 1) -- Reset color

    love.graphics.setColor(0,1,0,1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    -- The original current screen print was at y=30, new one is at y=170, so it's fine.
    -- love.graphics.print("Current Screen: " .. (ScreenManager.currentScreen and ScreenManager.currentScreen.screen_name or "None"), 10, 30)
    love.graphics.setColor(1,1,1,1)
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        love.event.quit()
    end
    if key == "0" then
        love.event.quit()
    end
    if key == "9" then
        -- ScreenManager:switchTo("ModeSelectionScreen")
    end

    for _, dev in ipairs(Game.input_device_list or {}) do
        if dev.mode_name == "keyboard" and dev.update_raw_input_keyboard then
            dev:update_raw_input_keyboard(key, true)
        end
    end
end

function love.keyreleased(key, scancode)
    for _, dev in ipairs(Game.input_device_list or {}) do
        if dev.mode_name == "keyboard" and dev.update_raw_input_keyboard then
            dev:update_raw_input_keyboard(key, false)
        end
    end
end

function love.joystickadded(joystick)
    print("Joystick added: " .. joystick:getName() .. " ID: " .. joystick:getID())
    local new_team_id = #Game.input_device_list + 1 -- This might lead to P3, P4 etc.
    local new_device = InputDevice:new(Game, new_team_id, joystick, "joystick") -- Pass joystick object
    table.insert(Game.input_device_list, new_device)

    -- Try to assign to P2 if P2 is on dummy or not assigned
    if Game.active_players and Game.active_players[2] then
        if Game.active_players[2].inputdevice == Game.dummy_input_device or Game.active_players[2].inputdevice == nil then
            Game.active_players[2].inputdevice = new_device
            new_device.active_object = Game.active_players[2]
            print("Assigned new joystick to Player 2")
        end
    end

    if InterfaceObjects and InterfaceObjects.Message and Game.image_dict then
        local msg_args = {
            game = Game, string = "Joystick connected",
            texture_string = {{image = "reencor/+", size = {35,35}}, {image = "reencor/5", size = {35,35}}},
            pos = {Game.internal_resolution[1] * 0.85, Game.internal_resolution[2] * 0.8, 1000},
            background_pycolor = {0,0,0,126}, time = 120, kill_on_time = true,
            allign = "left", scale = {0.7,0.7}
        }
        -- This needs a proper UI layer or message manager to add messages to.
        -- For now, let's assume ScreenManager.currentScreen can handle temporary messages.
        if ScreenManager.currentScreen and ScreenManager.currentScreen.add_message then
            ScreenManager.currentScreen:add_message(InterfaceObjects.Message:new(msg_args))
        else
            -- Fallback: add to a global message list if no screen handler
            Game.global_messages = Game.global_messages or {}
            table.insert(Game.global_messages, InterfaceObjects.Message:new(msg_args))
        end
    end
end

function love.joystickremoved(joystick)
    print("Joystick removed: " .. joystick:getName())
    for i = #Game.input_device_list, 1, -1 do
        local dev = Game.input_device_list[i]
        if dev.controller == joystick then
            table.remove(Game.input_device_list, i)
            for _, player_obj in ipairs(Game.active_players or {}) do
                if player_obj.inputdevice == dev then
                    player_obj.inputdevice = Game.dummy_input_device
                    if Game.dummy_input_device then Game.dummy_input_device.active_object = player_obj end
                end
            end
            break
        end
    end
end

function love.joystickaxis(joystick, axis, value)
    for _, dev in ipairs(Game.input_device_list or {}) do
        if dev.controller == joystick and dev.update_raw_input_joystick_axis then
            dev:update_raw_input_joystick_axis(axis, value)
        end
    end
end

function love.joystickpressed(joystick, button)
    for _, dev in ipairs(Game.input_device_list or {}) do
        if dev.controller == joystick and dev.update_raw_input_joystick_button then
            dev:update_raw_input_joystick_button(button, true)
        end
    end
end

function love.joystickreleased(joystick, button)
     for _, dev in ipairs(Game.input_device_list or {}) do
        if dev.controller == joystick and dev.update_raw_input_joystick_button then
            dev:update_raw_input_joystick_button(button, false)
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if ScreenManager.currentScreen and ScreenManager.currentScreen.mousepressed then
        -- Convert to internal resolution coordinates if using canvas scaling
        local scale_x = Game.internal_resolution[1] / love.graphics.getWidth()
        local scale_y = Game.internal_resolution[2] / love.graphics.getHeight()
        ScreenManager.currentScreen:mousepressed(x * scale_x, y * scale_y, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
     if ScreenManager.currentScreen and ScreenManager.currentScreen.mousereleased then
        local scale_x = Game.internal_resolution[1] / love.graphics.getWidth()
        local scale_y = Game.internal_resolution[2] / love.graphics.getHeight()
        ScreenManager.currentScreen:mousereleased(x * scale_x, y * scale_y, button, istouch, presses)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if ScreenManager.currentScreen and ScreenManager.currentScreen.mousemoved then
        local scale_x = Game.internal_resolution[1] / love.graphics.getWidth()
        local scale_y = Game.internal_resolution[2] / love.graphics.getHeight()
        ScreenManager.currentScreen:mousemoved(x * scale_x, y * scale_y, dx * scale_x, dy * scale_y, istouch)
    end
end

function love.quit()
    print("Quitting Reencor Remake.")
end
