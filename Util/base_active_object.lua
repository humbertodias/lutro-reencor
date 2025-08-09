local common_functions = require("Util.common_functions")
local InputDevice = require("Util.input_device").InputDevice

local BaseActiveObject = {}
BaseActiveObject.__index = BaseActiveObject
BaseActiveObject.class_name = "BaseActiveObject"

function BaseActiveObject:new(params)
    local self = setmetatable({}, BaseActiveObject)

    self.game = params.game
    self.type = params.type or "character"
    self.dict = params.dict or {}
    self.team = params.team or 1
    self.inputdevice = params.inputdevice or InputDevice:new()
    self.pos = params.pos or {280, 200, 0}
    self.face = params.face or 1
    self.palette = params.palette or 0

    self.hurt_coll_hit = {}
    self.hit_coll_hurt = {}
    self.trigger_coll_hurt = {}
    self.take_coll_grab = {}

    self.image = "reencor/none"
    self.image_offset = {0, 0}
    self.image_size = {100, 100}
    self.image_mirror = {false, false}
    self.image_tint = {255, 255, 255, 255}
    self.image_angle = {0, 0, 0}
    self.image_repeat = false
    self.image_glow = 0
    self.draw_shake = {0, 0, 0, 0, 0, 0}

    self.current_command = {5}
    self.command_index_timer = {}
    if self.dict.states then
        for move, state_data in pairs(self.dict.states) do
            if state_data.command then
                self.command_index_timer[move] = {}
                for _ in ipairs(state_data.command) do
                    table.insert(self.command_index_timer[move], {0, 0})
                end
            end
        end
    end

    self.mass = self.dict.mass
    self.scale = self.dict.scale
    self.time_kill = self.dict.timekill
    self.gauges = {}
    if self.dict.gauges then
        for gauge, gauge_data in pairs(self.dict.gauges) do
            self.gauges[gauge] = gauge_data.inicial
        end
    end
    self.boxes = self.dict.boxes

    self.frame = {0, 0}
    self.repeat_count = 0
    self.ignore_stop = false
    self.hold_on_stun = false
    self.hitstun = 0
    self.hitstop = 0

    self.speed = {0, 0}
    self.acceleration = {0, 0}
    self.con_speed = {0, 0}
    self.air_time = 0
    self.air_max_height = 0

    self.fet = "grounded"
    self.grabed = nil
    self.cancel = {0}
    self.kara = 0
    self.current_state = "Stand"
    self.buffer_state = {}
    self.wallbounce = false

    self.combo = 0
    self.parry = {"6", 0}
    self.guard = ""
    self.juggle = 100
    self.damage_scaling = {100, 100}
    self.last_damage = {0, 0}

    self.move_raw_input = {}
    if self.dict.states then
        for move, state_data in pairs(self.dict.states) do
            if state_data.command then
                self.move_raw_input[move] = {}
            end
        end
    end

    self.self_main_object = nil
    self.other_main_object = nil
    self.influence_object = nil

    if params.inicial_state then
        common_functions.get_state(self, {[params.inicial_state] = 2}, true)
        common_functions.next_frame(self, self.dict.states[self.current_state].framedata[1])
    end

    return self
end

function BaseActiveObject:update(dt)
    -- ...
end

function BaseActiveObject:draw(screen)
    -- ...
end

return BaseActiveObject
