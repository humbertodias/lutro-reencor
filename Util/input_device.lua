local common_functions = require("Util.common_functions")

local function contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
end

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
        {"right"}, {"left"}, {"up"}, {"down"}, {"backspace"}, {"w"}, {"q"}, {"d"}, {"s"}, {"a"}, {"r", "kp5"}, {"r"}, {"pagedown"}
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

    -- ... (rest of the InputDevice implementation)

    return self
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

-- ... (rest of the functions)

local dummy_input = InputDevice:new(nil, 0, 0, "none")

return {
    InputDevice = InputDevice,
    dummy_input = dummy_input
}
