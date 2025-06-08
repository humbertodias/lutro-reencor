-- utils/input_device.lua

local function RoundSign(n)
    if n > 0 then return 1
    elseif n < 0 then return -1
    else return 0 end
end

local default_keyboard_config_p1 = {
    dx_positive_key = "d", dx_negative_key = "a",
    dy_positive_key = "s", dy_negative_key = "w", -- Assuming w is up, s is down
    buttons = { "j", "k", "l", "u", "i", "o" }
}

local default_keyboard_config_p2 = {
    dx_positive_key = "right", dx_negative_key = "left",
    dy_positive_key = "down", dy_negative_key = "up",
    buttons = { "kp1", "kp2", "kp3", "kp4", "kp5", "kp6" }
}

local InputDevice = {}
InputDevice.__index = InputDevice

function InputDevice:new(game, team, love_joystick_or_nil, mode_name_str)
    local instance = setmetatable({}, InputDevice)
    instance.game = game
    instance.type = "input"
    instance.team = team or 1
    instance.mode_name = mode_name_str or "none"

    instance.key_config = {}
    if instance.mode_name == "keyboard" then
        if instance.team == 1 then instance.key_config = default_keyboard_config_p1
        elseif instance.team == 2 then instance.key_config = default_keyboard_config_p2
        end
    end

    instance.controller = love_joystick_or_nil
    if instance.mode_name == "joystick" then
        if not (instance.controller and instance.controller:isConnected()) then
            print("Warning: Joystick invalid/disconnected for team " .. instance.team .. ". Mode set to 'none'.")
            instance.mode_name = "none"
        elseif instance.controller:isGamepad() then
             print("Info: Joystick " .. instance.controller:getName() .. " is standard gamepad.")
        else
            print("Warning: Joystick " .. instance.controller:getName() .. " is not standard gamepad.")
        end
    end

    instance.mode_update_function = instance[instance.mode_name .. "_mode_update_raw_input_state"] or instance.none_mode_update_raw_input_state

    instance.press_list_showed = {}
    -- raw_input_state: {dx, dy, b1, b2, b3, b4, b5, b6}
    instance.raw_input_state = {0, 0, 0, 0, 0, 0, 0, 0}
    instance.current_input_processed = {"5"}
    instance.last_raw_input_state = {0, 0, 0, 0, 0, 0, 0, 0}
    instance.press_charge = {0,0,0,0,0,0} -- For 6 buttons
    instance.inter_press = 0
    instance.input_timer = 0
    instance.last_input_timer = 0
    instance.active_object = nil

    instance.sequence_commands = {
        {command = "QCF", sequence = {"2", "3", "6"}, press = true}, {command = "QCF", sequence = {"2", "6"}, press = true},
        {command = "QCB", sequence = {"2", "1", "4"}, press = true}, {command = "QCB", sequence = {"2", "4"}, press = true},
        {command = "DP", sequence = {"6", "2", "3"}, press = true}, {command = "DP", sequence = {"6", "3", "2", "3"}, press = true},
        {command = "DP", sequence = {"3", "2", "3"}, press = true}, {command = "DP", sequence = {"3", "2", "6"}, press = true},
        {command = "DP", sequence = {"6", "2", "6"}, press = true}, {command = "DP", sequence = {"3", "2", "1", "3"}, press = true},
        {command = "Doble_tap_forward", sequence = {"5", "6", "5", "6"}},
    }
    instance.sequence_index = {}
    for i = 1, #instance.sequence_commands do instance.sequence_index[i] = 1 end

    -- Temporary state for keyboard dx/dy to handle opposing presses
    instance._kb_dx_pos = 0; instance._kb_dx_neg = 0; instance._kb_dy_pos = 0; instance._kb_dy_neg = 0
    return instance
end

-- Called by Love2D callbacks in main.lua
function InputDevice:update_key_state(love_key, is_pressed_bool)
    if self.mode_name ~= "keyboard" then return end
    local state_val = is_pressed_bool and 1 or 0

    if love_key == self.key_config.dx_positive_key then self._kb_dx_pos = state_val
    elseif love_key == self.key_config.dx_negative_key then self._kb_dx_neg = state_val
    elseif love_key == self.key_config.dy_positive_key then self._kb_dy_pos = state_val -- Down
    elseif love_key == self.key_config.dy_negative_key then self._kb_dy_neg = state_val -- Up
    else
        for i, btn_key_cfg in ipairs(self.key_config.buttons) do
            if love_key == btn_key_cfg then
                self.raw_input_state[2+i] = state_val; break
            end
        end
    end
    -- Combine directional key states into raw_input_state[1] and raw_input_state[2]
    self.raw_input_state[1] = self._kb_dx_pos - self._kb_dx_neg
    self.raw_input_state[2] = self._kb_dy_pos - self._kb_dy_neg
end

function InputDevice:update_joystick_axis_state(axis_name, value)
    if self.mode_name ~= "joystick" or not self.controller then return end
    -- For gamepads, axis_name is "leftx", "lefty", etc.
    if axis_name == "leftx" then self.raw_input_state[1] = RoundSign(value)
    elseif axis_name == "lefty" then self.raw_input_state[2] = RoundSign(value)
    -- Add other axes if needed, e.g., for triggers as buttons
    -- elseif axis_name == "triggerleft" then self.raw_input_state[BUTTON_L2_INDEX] = value > 0.5 and 1 or 0
    end
end

function InputDevice:update_joystick_button_state(button_name_or_idx, is_pressed_bool)
    if self.mode_name ~= "joystick" or not self.controller then return end
    local state_val = is_pressed_bool and 1 or 0

    if self.controller:isGamepad() then
        local gamepad_button_map = { -- Map to raw_input_state indices 3 through 8 (b1 to b6)
            a = 3, b = 4, x = 5, y = 6, leftshoulder = 7, rightshoulder = 8,
        }
        if gamepad_button_map[button_name_or_idx] then
            self.raw_input_state[gamepad_button_map[button_name_or_idx]] = state_val
        end
    else -- Non-standard gamepad, use raw button indices (1-based from Love2D)
        if type(button_name_or_idx) == "number" and button_name_or_idx >= 1 and button_name_or_idx <= 6 then
             self.raw_input_state[2 + button_name_or_idx] = state_val
        end
    end
end

-- These functions are called by self:update() if their mode is active.
-- They now primarily ensure raw_input_state is up-to-date (if polling is still needed for some modes)
-- and then call get_press.
function InputDevice:keyboard_mode_update_raw_input_state()
    -- Keyboard state is now primarily updated by update_key_state via callbacks.
    -- This function might only be needed if there's a desire to re-poll for some reason,
    -- or can be simplified if callbacks are fully relied upon.
    -- For now, ensure dx/dy are correctly combined from temporary states.
    self.raw_input_state[1] = (self._kb_dx_pos or 0) - (self._kb_dx_neg or 0)
    self.raw_input_state[2] = (self._kb_dy_pos or 0) - (self._kb_dy_neg or 0)
    -- Button states (raw_input_state[3] onwards) are directly set by update_key_state.
    self:get_press(self.raw_input_state)
end

function InputDevice:joystick_mode_update_raw_input_state()
    if not self.controller or not self.controller:isConnected() then
        self.raw_input_state = {0,0,0,0,0,0,0,0}; self:get_press(self.raw_input_state); return
    end
    -- Joystick axis/button states are now primarily updated by their respective callback handlers.
    -- This function can call get_press directly if callbacks are the sole source of truth for raw_input_state.
    -- If some joystick aspects still need polling (e.g. non-standard ones not covered by callbacks), do it here.
    -- For standard gamepads, callbacks should be sufficient for axes and buttons.
    self:get_press(self.raw_input_state)
end

function InputDevice:AI_mode_update_raw_input_state() self:get_press(self.raw_input_state) end
function InputDevice:record_mode_update_raw_input_state() self:get_press(self.raw_input_state) end
function InputDevice:none_mode_update_raw_input_state() self.raw_input_state = {0,0,0,0,0,0,0,0}; self:get_press(self.raw_input_state) end
function InputDevice:random_mode_update_raw_input_state()
    self.rand_timer = (self.rand_timer or 0) - 1
    if self.rand_timer <= 0 then
        self.rand_timer = math.random(10, 60)
        self.raw_input_state[1] = math.random(-1,1); self.raw_input_state[2] = math.random(-1,1)
        for i=3, #self.raw_input_state do self.raw_input_state[i] = math.random(0,1) end
    end
    self:get_press(self.raw_input_state)
end

function InputDevice:get_press(current_raw_input_table)
    self.inter_press = 0
    local new_processed_input = {}
    local face_multiplier = (self.active_object and self.active_object.face) or 1
    local dpad_dx = current_raw_input_table[1]; local dpad_dy = current_raw_input_table[2]
    local dpad_map = {[-1]={[-1]="7",[0]="4",[1]="1"},[0]={[-1]="8",[0]="5",[1]="2"},[1]={[-1]="9",[0]="6",[1]="3"}}
    local current_dpad_val = dpad_map[dpad_dx * face_multiplier] and dpad_map[dpad_dx * face_multiplier][dpad_dy] or "5"
    table.insert(new_processed_input, current_dpad_val)

    local last_dpad_dx = self.last_raw_input_state[1]; local last_dpad_dy = self.last_raw_input_state[2]
    local last_dpad_val = dpad_map[last_dpad_dx * face_multiplier] and dpad_map[last_dpad_dx * face_multiplier][last_dpad_dy] or "5"
    local dpad_transition = last_dpad_val .. current_dpad_val
    table.insert(new_processed_input, dpad_transition)

    local pressed_buttons, released_buttons, held_buttons = {}, {}, {}
    for i = 3, #current_raw_input_table do
        local btn_idx = i-2
        if current_raw_input_table[i]==1 and self.last_raw_input_state[i]==0 then table.insert(pressed_buttons,"p_b"..btn_idx)
        elseif current_raw_input_table[i]==0 and self.last_raw_input_state[i]==1 then table.insert(released_buttons,"r_b"..btn_idx)
        elseif current_raw_input_table[i]==1 and self.last_raw_input_state[i]==1 then table.insert(held_buttons,"h_b"..btn_idx) end
    end

    local recognized_commands = {}
    for i,move_def in ipairs(self.sequence_commands) do
        local current_seq_idx = self.sequence_index[i]
        local target_dir_in_seq = move_def.sequence[current_seq_idx]
        if current_dpad_val == target_dir_in_seq then
            if current_seq_idx > 1 then
                if dpad_transition:sub(1,1) == move_def.sequence[current_seq_idx-1] then self.sequence_index[i]=current_seq_idx+1
                else self.sequence_index[i] = (current_dpad_val==move_def.sequence[1]) and 2 or 1 end
            else self.sequence_index[i]=current_seq_idx+1 end
        elseif current_dpad_val ~= last_dpad_val then
             self.sequence_index[i] = (current_dpad_val==move_def.sequence[1]) and 2 or 1
        end
        if self.sequence_index[i] > #move_def.sequence then
            if not move_def.press or #pressed_buttons > 0 then table.insert(recognized_commands,move_def.command) end
            self.sequence_index[i]=1
        end
    end

    for i=1, (#self.raw_input_state - 2) do
        local is_held = false; for _,hb in ipairs(held_buttons) do if hb==("h_b"..i) then is_held=true; break end end
        if is_held then self.press_charge[i]=(self.press_charge[i] or 0)+1 else self.press_charge[i]=0 end
        if self.press_charge[i]>40 then table.insert(held_buttons,"charge_b"..i) end
    end

    for _,v in ipairs(pressed_buttons) do table.insert(new_processed_input,v) end
    for _,v in ipairs(released_buttons) do table.insert(new_processed_input,v) end
    for _,v in ipairs(held_buttons) do table.insert(new_processed_input,v) end
    for _,v in ipairs(recognized_commands) do table.insert(new_processed_input,v) end
    self.current_input_processed = new_processed_input

    local changed=false; for i=1,#current_raw_input_table do if current_raw_input_table[i]~=self.last_raw_input_state[i] then changed=true; break end end
    if changed then
        self.inter_press=1; if #self.press_list_showed>=20 then table.remove(self.press_list_showed,1) end
        local cpy={}; for _,v_ in ipairs(self.current_input_processed) do table.insert(cpy,v_) end; table.insert(self.press_list_showed,cpy)
        self.last_input_timer=self.input_timer; self.input_timer=0
    end
    for i=1,#current_raw_input_table do self.last_raw_input_state[i]=current_raw_input_table[i] end
    self.input_timer=self.input_timer+1
end

function InputDevice:update(dt)
    if self.mode_update_function then
        self:mode_update_function()
    end
end

function InputDevice:draw()
    if self.mode_name == "none" or not self.game or not self.game.image_dict or not Game.camera or not Game.internal_resolution then return end
    local view_x, view_y = Game.camera.x, Game.camera.y
    local view_w, view_h = Game.internal_resolution[1], Game.internal_resolution[2]
    local icon_base_size = 20; local y_spacing = icon_base_size + 5; local x_icon_spacing = icon_base_size + 2
    local start_x, start_y

    if self.team == 1 then
        start_x = 50 -- Fixed position from left of internal canvas
        start_y = view_h - 50 - (#self.press_list_showed * y_spacing)
    else
        start_x = view_w - 50 - (6 * x_icon_spacing) -- Fixed from right, estimate width for 6 icons
        start_y = view_h - 50 - (#self.press_list_showed * y_spacing)
    end

    for i, input_set in ipairs(self.press_list_showed) do
        local current_x_pos = start_x
        for _, input_str in ipairs(input_set) do
            local image_key = "reencor/" .. input_str
            if self.game.image_dict[image_key] then
                local img_data = self.game.image_dict[image_key]; local img = img_data[1]
                if img then
                    love.graphics.draw(img, current_x_pos, start_y + (i-1) * y_spacing, 0, icon_base_size/img:getWidth(), icon_base_size/img:getHeight())
                    current_x_pos = current_x_pos + x_icon_spacing
                end
            end
        end
    end
end

function InputDevice:set_active_object(obj) self.active_object = obj end
function InputDevice:isDummy() return self.mode_name == "none" or self.mode_name == "AI" end

local dummy_input_device_instance = nil
function InputDevice.initialize_dummy(game_ref)
    if not dummy_input_device_instance then dummy_input_device_instance = InputDevice:new(game_ref, 0, nil, "none") end
    return dummy_input_device_instance
end
function InputDevice.get_dummy() assert(dummy_input_device_instance, "Dummy input device not initialized."); return dummy_input_device_instance end

return InputDevice
