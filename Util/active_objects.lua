local common_functions = require("Util.common_functions")
local InputDevice = require("Util.input_device").InputDevice
local dummy_input = require("Util.input_device").dummy_input

local BaseActiveObject = {}
BaseActiveObject.__index = BaseActiveObject
BaseActiveObject.class_name = "BaseActiveObject"

function BaseActiveObject:new(params)
    local self = setmetatable({}, BaseActiveObject)

    self.game = params.game
    self.dict = params.dict or {}
    self.type = self.dict.type or "character"
    self.pos = params.pos or {0, 0, 0}
    self.face = params.face or 1
    self.inicial_state = params.inicial_state or "Stand"
    self.palette = params.palette or 0
    self.inputdevice = params.inputdevice or dummy_input
    self.team = params.team or 1
    self.parent = params.parent

    -- ... (the rest of the implementation, similar to base_active_object.lua but with the specific details from Active_Objects.py)

    return self
end

function BaseActiveObject:update(dt)
    -- ...
end

function BaseActiveObject:draw(screen, pos)
    -- ...
end

local function reset_CharacterActiveObject(self, params)
    -- ...
end

return {
    BaseActiveObject = BaseActiveObject,
    reset_CharacterActiveObject = reset_CharacterActiveObject
}
