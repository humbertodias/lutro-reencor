local common_functions = require("Util.common_functions")

local InputDevice = {}
InputDevice.__index = InputDevice

function InputDevice:new(game, team, index, mode)
    local self = setmetatable({}, InputDevice)
    self.game = game
    self.type = "input"
    self.team = team or 1
    self.index = index or 0
    mode = mode or "none"

    self.key = {
        {79}, {80}, {82}, {81}, {8}, {26}, {20}, {7}, {22}, {4}, {21, 92}, {21}, {116}
    }

    self.joystick_name_mapping = {
        ["Nintendo Switch Pro Controller"] = {
            {{"analog", 0}, {"binary", 14}, {"binary", 13, 1}},
            {{"analog", 1}, {"binary", 11, 1}, {"binary", 12}},
            {{"analog", 5}},
            {{"binary", 0}},
            {{"binary", 1}},
            {{"binary", 10}},
            {{"binary", 2}},
            {{"binary", 3}},
            {{"binary", 9}, {"analog", 4}},
        },
        ["Xbox Controller"] = {
            {{"analog", 0}},
            {{"analog", 1}},
            {{"binary", 4}},
            {{"binary", 3}},
            {{"binary", 2}},
            {{"binary", 5}},
            {{"binary", 1}},
            {{"analog", 2}},
            {{"analog", 3}},
        },
    }

    self.mode_functions = {
        keyboard = self.keyboard_mode,
        joystick = self.joystick_mode,
        AI = self.AI_mode,
        record = self.record_mode,
        none = self.none_mode,
        random = self.random_mode,
    }
    self.mode = self.mode_functions[mode]

    if mode == "joystick" then
        self.controller = love.joystick.getJoysticks()[index]
        self.con = self.joystick_name_mapping[self.controller:getName()]
    end

    self.press_list_showed = {}
    self.raw_input = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    self.current_input = {"5"}
    self.last_input = {{0, 0}, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    self.press_charge = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    self.inter_press = 0
    self.input_timer = 0
    self.record_timer = 0
    self.recorded_inputs = {}
    self.last_input_timer = 0
    self.recorded_inputs_index = 1
    self.draw_shake = {0, 0, 0, 0, 0, 0}
    self.rand_timer = 0
    self.active_object = nil

    self.sequence_commands = {
        {command = "QCF", sequence = {"2", "3", "6"}, press = true},
        {command = "QCF", sequence = {"2", "6"}, press = true},
        {command = "QCB", sequence = {"2", "1", "4"}, press = true},
        {command = "QCB", sequence = {"2", "4"}, press = true},
        {command = "DP", sequence = {"6", "3", "2", "3"}, press = true},
        {command = "DP", sequence = {"3", "2", "3"}, press = true},
        {command = "DP", sequence = {"3", "2", "6"}, press = true},
        {command = "DP", sequence = {"6", "2", "6"}, press = true},
        {command = "DP", sequence = {"6", "2", "3"}, press = true},
        {command = "DP", sequence = {"3", "2", "1", "3"}, press = true},
        {command = "Doble_tap_forward", sequence = {"5", "6", "5", "6"}},
    }

    self.sequence_index = {}
    for _ in ipairs(self.sequence_commands) do
        table.insert(self.sequence_index, 1)
    end

    return self
end

function InputDevice:axis_button(input)
    if input[1] == "analog" then
        return common_functions.RoundSign(self.controller:getAxis(input[2]))
    else
        return (self.controller:isDown(input[2]) and (#input > 2 and -1 or 1) or 0)
    end
end

function InputDevice:keyboard_mode()
    local raw = {}
    for i = 1, #self.key do
        local sum = 0
        for _, k_code in ipairs(self.key[i]) do
            if love.keyboard.isDown(k_code) then
                sum = sum + 1
            end
        end
        raw[i] = sum
    end
    self.raw_input = raw

    self:get_press({
        {self.raw_input[1] + self.raw_input[2] * -1, self.raw_input[3] + self.raw_input[4] * -1},
        self.raw_input[5], self.raw_input[6], self.raw_input[7], self.raw_input[8],
        self.raw_input[9], self.raw_input[10], self.raw_input[11]
    })
end

function InputDevice:joystick_mode()
    local raw = {{0,0}}
    for i = 1, #self.con do
        local sum = 0
        for _, k in ipairs(self.con[i]) do
            sum = sum + self:axis_button(k)
        end
        if i == 1 then raw[1][1] = sum
        elseif i == 2 then raw[1][2] = -sum
        else raw[i-1] = sum
        end
    end
    self.raw_input = raw
    self:get_press(self.raw_input)
end

function InputDevice:AI_mode()
    -- TODO: Implement AI mode
    self:none_mode()
end

function InputDevice:record_mode()
    -- TODO: Implement record mode
    self:none_mode()
end

function InputDevice:none_mode()
    self.raw_input = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    self:get_press({{0, 0}, 0, 0, 0, 0, 0, 0, 0})
end

function InputDevice:random_mode()
    self.rand_timer = self.rand_timer - 1
    if self.rand_timer <= 0 then
        self.rand_timer = love.math.random(10, 60)
        self.raw_input = {}
        for _ = 1, 11 do
            table.insert(self.raw_input, love.math.random(0, 1))
        end
    end
    self:get_press({
        {self.raw_input[1] + self.raw_input[2] * -1, self.raw_input[3] + self.raw_input[4] * -1},
        self.raw_input[5], self.raw_input[6], self.raw_input[7], self.raw_input[8],
        self.raw_input[9], self.raw_input[10], self.raw_input[11]
    })
end

function InputDevice:get_press(raw_input)
    self.inter_press = 0
    self.current_input = {}

    local dpad_map = {{"8", "2", "5"}, {"9", "3", "6"}, {"7", "1", "4"}}
    local face_mult = (self.active_object and self.active_object.face or 1)
    local dpad = dpad_map[raw_input[1][1] * face_mult + 2][raw_input[1][2] + 2]
    local last_dpad = dpad_map[self.last_input[1][1] * face_mult + 2][self.last_input[1][2] + 2]
    local dpad_transition = last_dpad .. dpad

    local pressed_buttons = {}
    local released_buttons = {}
    local holded_buttons = {}

    for i = 2, #raw_input do
        if raw_input[i] == 1 and self.last_input[i] == 0 then
            table.insert(pressed_buttons, "p_b" .. (i-1))
        elseif raw_input[i] == 0 and self.last_input[i] == 1 then
            table.insert(released_buttons, "r_b" .. (i-1))
        elseif raw_input[i] == 1 and self.last_input[i] == 1 then
            table.insert(holded_buttons, "h_b" .. (i-1))
        end
    end

    local commands = {}
    for i, move in ipairs(self.sequence_commands) do
        if dpad == move.sequence[self.sequence_index[i]] and last_dpad == move.sequence[self.sequence_index[i]-1] then
            self.sequence_index[i] = self.sequence_index[i] + 1
            if self.sequence_index[i] > #move.sequence then
                self.sequence_index[i] = 1
                table.insert(commands, move.command)
            end
        end
    end

    for i = 1, 6 do
        if love.util.contains(holded_buttons, "h_b" .. i) then
            self.press_charge[i] = self.press_charge[i] + 1
        else
            self.press_charge[i] = 0
        end
        if self.press_charge[i] == 1 and love.util.contains(pressed_buttons, "p_b" .. i) then
            -- This logic seems a bit off, but translating as is.
        end
        if self.press_charge[i] > 40 then
            table.insert(holded_buttons, "charge_b" .. i)
        end
    end

    self.current_input = {dpad, dpad_transition}
    for _, b in ipairs(pressed_buttons) do table.insert(self.current_input, b) end
    for _, b in ipairs(released_buttons) do table.insert(self.current_input, b) end
    for _, b in ipairs(holded_buttons) do table.insert(self.current_input, b) end
    for _, c in ipairs(commands) do table.insert(self.current_input, c) end

    if not self:are_inputs_equal(raw_input, self.last_input) then
        self.inter_press = 1
        if #self.press_list_showed > 20 then
            table.remove(self.press_list_showed, 1)
        end
        table.insert(self.press_list_showed, self.current_input)
        self.last_input_timer = self.input_timer
        self.input_timer = 0
    end
    self.last_input = raw_input
    self.input_timer = self.input_timer + 1
end

function InputDevice:are_inputs_equal(t1, t2)
    for i = 1, #t1 do
        if type(t1[i]) == "table" then
            if not self:are_inputs_equal(t1[i], t2[i]) then return false end
        else
            if t1[i] ~= t2[i] then return false end
        end
    end
    return true
end

function InputDevice:update(dt)
    self.mode(self)
end

function InputDevice:draw(pos)
    if self.mode ~= self.mode_functions.none then
        for i, inputs in ipairs(self.press_list_showed) do
            local turn = 0
            for _, input_str in ipairs(inputs) do
                local image_key = "reencor/" .. input_str
                if self.game.image_dict[image_key] then
                    local image_data = self.game.image_dict[image_key]
                    local x_pos = pos[1] + (-600 + (self.team == 1 and 0 or 1175)) + 25 * turn * (self.team == 1 and 1 or -1)
                    local y_pos = pos[2] - 300 + 25 * i
                    love.graphics.draw(image_data[1], x_pos, y_pos, 0, 20/image_data[2][1], 20/image_data[2][2])
                    turn = turn + 1
                end
            end
        end
    end
end

local dummy_input = InputDevice:new(nil, 0, 0, "none")

return {
    InputDevice = InputDevice,
    dummy_input = dummy_input
}
