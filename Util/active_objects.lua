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

    self.hurt_coll_hit, self.hit_coll_hurt, self.trigger_coll_hurt, self.take_coll_grab = {}, {}, {}, {}

    self.image = "reencor/none"
    self.image_offset = {0, 0, 0}
    self.image_size = {100, 100, 0}
    self.image_mirror = {false, false}
    self.image_tint = {255, 255, 255, 255}
    self.image_angle = {0, 0, 0}
    self.image_repeat = false
    self.image_glow = 0
    self.draw_textures = {}
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
    self.repeat = 0
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
    self.combo_list = {}

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
    self.inputdevice.active_object = self

    common_functions.get_state(self, {[self.inicial_state] = 2}, true)
    common_functions.next_frame(self, self.dict.states[self.current_state].framedata[1])

    return self
end

function BaseActiveObject:update(dt)
    -- Complex update logic to be translated here
end

function BaseActiveObject:draw(screen, pos)
    local textures_to_draw = {{image = self.image}}
    for _, t in ipairs(self.draw_textures) do
        table.insert(textures_to_draw, t)
    end

    for _, texture_data in ipairs(textures_to_draw) do
        local image_info = self.game.image_dict[texture_data.image]
        if image_info then
            local image = image_info[1]
            local image_offset = texture_data.image_offset or self.image_offset
            local image_size = texture_data.image_size or self.image_size
            local image_mirror = texture_data.image_mirror or {false, false}
            local image_tint = texture_data.image_tint or self.image_tint
            local image_angle = texture_data.image_angle or self.image_angle
            local image_repeat = texture_data.image_repeat or self.image_repeat
            local image_glow = texture_data.image_glow or self.image_glow

            local x, y, z
            if type(image_offset[1]) == "number" then
                x = self.draw_shake[1] + self.pos[1] - (image_offset[1] * (self.face < 0 and 1 or -1)) - (self.face < 0 and 0 or image_size[1] * self.scale)
            else
                x = pos[1] + tonumber(image_offset[1])
            end
            if type(image_offset[2]) == "number" then
                y = self.draw_shake[2] + self.pos[2] + image_offset[2]
            else
                y = pos[2] + tonumber(image_offset[2])
            end
            if type(image_offset[3]) == "number" then
                z = self.pos[3] + image_offset[3]
            else
                z = pos[3] + tonumber(image_offset[3])
            end

            screen:draw_texture(
                image, {x, y, z}, image_size,
                {self.face > 0 and not image_mirror[1] or image_mirror[1], image_mirror[2]},
                image_tint, image_angle, image_repeat, image_glow
            )
        end
    end
end

local function reset_CharacterActiveObject(self, params)
    -- This function basically re-runs the constructor logic on an existing object.
    -- In Lua, we can just call the new method and replace the old object, or manually reset fields.
    -- For simplicity, we'll just show the structure.

    self.game = params.game
    self.dict = params.dict or {}
    self.type = self.dict.type or "character"
    -- ... and so on for all fields, similar to the :new() function
end

return {
    BaseActiveObject = BaseActiveObject,
    reset_CharacterActiveObject = reset_CharacterActiveObject
}
