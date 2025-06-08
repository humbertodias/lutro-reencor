-- objects/base_active_object.lua
-- This file is based on the BaseActiveObject found in Util/Active_Objects.py,
-- as it appears to be the more complete version.

local InputDevice = require("utils.input_device") -- Assuming path
local CommonFunctions = require("utils.common_functions") -- Assuming path

-- Functions from CommonFunctions that are directly called or heavily implied
local RoundSign = CommonFunctions.RoundSign
local get_command_lua = CommonFunctions.get_command -- Renamed to avoid conflict with any 'command' variable
local get_state_lua = CommonFunctions.get_state
local next_frame_lua = CommonFunctions.next_frame
local get_object_per_team_lua = CommonFunctions.get_object_per_team
local object_kill_lua = CommonFunctions.object_kill


local BaseActiveObject = {}
BaseActiveObject.__index = BaseActiveObject

function BaseActiveObject:new(args)
    args = args or {}
    local instance = setmetatable({}, BaseActiveObject)

    instance.game = args.game -- Must be the global game table/object
    instance.dict = args.dict or {} -- Character/object definition data (from JSON)

    instance.type = string.lower(instance.dict.type or "character")
    instance.type_name = "BaseActiveObject" -- For type checking if needed

    instance.team = args.team or 1
    instance.inputdevice = args.inputdevice or InputDevice.get_dummy() -- Use global dummy if none provided
    instance.parent = args.parent or nil -- For projectiles, etc.

    if args.pos and #args.pos == 2 then
        instance.pos = {args.pos[1], args.pos[2], 0}
    elseif args.pos and #args.pos == 3 then
        instance.pos = {args.pos[1], args.pos[2], args.pos[3]}
    else
        instance.pos = args.pos or {0,0,0} -- x, y, z (z for layering if needed)
    end

    instance.face = args.face or 1
    instance.palette_index = args.palette or 0 -- Renamed to avoid conflict with a 'palette' table if used for colors

    instance.hurt_coll_hit = {}
    instance.hit_coll_hurt = {}
    instance.trigger_coll_hurt = {}
    instance.take_coll_grab = {}

    instance.image = "reencor/none" -- Path to image, or a loaded Love2D image object
    instance.image_offset = {0,0,0} -- x,y,z for drawing offset
    instance.image_size = {100,100,0} -- width,height,depth (depth might not be used in Love2D directly)
    instance.image_mirror = {false, false} -- {flip_x, flip_y}
    instance.image_tint = {1,1,1,1} -- Love2D color (R,G,B,A normalized 0-1) - original was 0-255
    instance.image_angle = {0,0,0} -- Euler angles; Love2D draw usually takes single radian value for 2D rotation
    instance.image_repeat = false -- Love2D wrap mode
    instance.image_glow = 0
    instance.draw_textures = {} -- List of additional textures to draw
    instance.draw_shake = {0,0,0,0,0,0} -- x,y current shake; x_mag, y_mag, current_dur, total_dur

    instance.current_command = {"5"} -- Numpad notation, '5' is neutral
    instance.command_index_timer = {}
    if instance.dict.states then
        for move_name, state_data in pairs(instance.dict.states) do
            if state_data.command and type(state_data.command) == "table" then
                instance.command_index_timer[move_name] = {}
                for _ = 1, #state_data.command do
                    table.insert(instance.command_index_timer[move_name], {0,0}) -- {progress, timer}
                end
            end
        end
    end

    instance.mass = instance.dict.mass or 1
    instance.scale = instance.dict.scale or {1,1} -- {scale_x, scale_y}
    instance.time_kill = instance.dict.timekill or false -- boolean or number (frames)

    instance.gauges = {}
    if instance.dict.gauges then
        for gauge_name, gauge_data in pairs(instance.dict.gauges) do
            instance.gauges[gauge_name] = gauge_data.inicial or 0
        end
    end

    instance.boxes = instance.dict.boxes or {} -- Collision boxes

    -- frame[1] = current substate index from end of framedata list (0 = last substate)
    -- frame[2] = duration left in current substate
    instance.frame = {0,0}
    instance.repeat_count = 0 -- Renamed from 'repeat' due to Lua keyword
    instance.ignore_stop = false
    instance.hold_on_stun = false
    instance.hitstun = 0
    instance.hitstop = 0

    instance.speed = {0,0} -- {vx, vy}
    instance.acceleration = {0,0} -- {ax, ay}
    instance.con_speed = {0,0} -- Constant speed from frame data
    instance.air_time = 0
    instance.air_max_height = 0 -- Not obviously used in update logic shown

    instance.fet = "grounded" -- "airborne"
    instance.grabed = nil -- Object instance is grabbing this one
    instance.cancel = {nil} -- List of cancel conditions (nil represents Python None)
    instance.kara = 0 -- Kara cancel timer/flag
    instance.current_state = "Stand"
    instance.buffer_state = {} -- {move_name = timer_left}
    instance.wallbounce = false

    instance.combo = 0
    instance.parry = {"6", 0} -- {direction_string, timer}
    instance.guard = "" -- "block", "parry" (set by logic in Box_Collisions)
    instance.juggle = 100
    instance.damage_scaling = {100, 100} -- {current_combo_scaling_%, min_scaling_%_floor}
    instance.last_damage = {0,0} -- {total_damage_this_combo, last_hit_damage}

    instance.move_raw_input = {}
    if instance.dict.states then
        for move_name, state_data in pairs(instance.dict.states) do
            if state_data.command then
                instance.move_raw_input[move_name] = {}
            end
        end
    end

    instance.self_main_object = nil
    instance.other_main_object = nil
    instance.influence_object = nil

    if instance.inputdevice and instance.inputdevice.set_active_object then
        instance.inputdevice:set_active_object(instance)
    elseif instance.inputdevice then
        instance.inputdevice.active_object = instance
    end

    instance.combo_list = {}

    local initial_state_name = args.inicial_state or "Stand"
    if instance.dict.states and instance.dict.states[initial_state_name] and instance.dict.states[initial_state_name].framedata and #instance.dict.states[initial_state_name].framedata > 0 then
        instance.current_state = initial_state_name -- Set current_state before calling get_state
        instance.frame = {#instance.dict.states[initial_state_name].framedata -1, 0} -- Init frame[1] correctly (0 means last frame)
        get_state_lua(instance, {[initial_state_name] = 2}, true)

        if instance.dict.states[instance.current_state] and #instance.dict.states[instance.current_state].framedata > 0 then
            next_frame_lua(instance, instance.dict.states[instance.current_state].framedata[1])
        else
            print("Warning: Initial state " .. instance.current_state .. " has no framedata after get_state.")
        end
    else
        print("Warning: Could not set initial state: " .. initial_state_name .. " or it has no framedata.")
        if instance.dict.states and instance.dict.states["Stand"] and #instance.dict.states["Stand"].framedata > 0 then
            instance.current_state = "Stand"
            instance.frame = {#instance.dict.states["Stand"].framedata -1, 0}
            next_frame_lua(instance, instance.dict.states["Stand"].framedata[1])
        else
             print("Critical Warning: Default 'Stand' state also missing or has no framedata.")
        end
    end

    return instance
end

function BaseActiveObject:update(dt)
    if not self.game then print("Warning: self.game is nil in BaseActiveObject:update for ".. (self.dict and self.dict.name or "Unknown object")) return end

    if not self.self_main_object then
        self.self_main_object = get_object_per_team_lua(self.game.object_list, self.team, false, self.type)
    end
    if not self.other_main_object then
        self.other_main_object = get_object_per_team_lua(self.game.object_list, self.team, true, self.type)
    end

    if self.inputdevice and self.inputdevice.current_input_processed and self.inputdevice.inter_press == 1 and self.parry[2] == 0 then
        local dir_input = self.inputdevice.current_input_processed[1]
        if dir_input == "3" or dir_input == "6" then
            self.parry = {dir_input, 24}
        end
    end
    if self.parry[2] > 0 then self.parry[2] = self.parry[2] - 1 end

    for gauge_name, value in pairs(self.gauges) do
        if value < 0 then self.gauges[gauge_name] = 0 end
        if self.dict.gauges and self.dict.gauges[gauge_name] and self.dict.gauges[gauge_name].max and value > self.dict.gauges[gauge_name].max then
            self.gauges[gauge_name] = self.dict.gauges[gauge_name].max
        end
    end

    for move_name, timers_list in pairs(self.command_index_timer) do
        for i = 1, #timers_list do
            local timer_entry = timers_list[i]
            if timer_entry[2] > 0 then
                timer_entry[2] = timer_entry[2] - 1
            else
                timer_entry[1] = 0
            end
        end
    end

    if self.hitstop == 0 and self.grabed == nil then
        if self.hitstun > 0 then
            self.hitstun = self.hitstun - 1
        end

        if self.other_main_object and self.other_main_object.pos and self.pos then
            local cancel_allows_turn = CommonFunctions.table_intersection_check(self.cancel, {"neutral", "turn", "kara"})
            local is_neutral_frame = (self.frame[1] == 0 and self.frame[2] == 0)

            if (cancel_allows_turn or is_neutral_frame) and self.fet == "grounded" and self.other_main_object.pos[1] ~= self.pos[1] then
                 if math.abs(self.other_main_object.pos[1] - self.pos[1]) > 32 then
                    local required_face = RoundSign(self.other_main_object.pos[1] - self.pos[1])
                    if self.face ~= required_face and required_face ~= 0 then -- Don't turn if aligned
                        self.face = required_face
                        self.current_command = self.current_command or {}
                        table.insert(self.current_command, 1, "turn")
                        if self.inputdevice then self.inputdevice.inter_press = 1 end
                    end
                end
            end
        end

        self.speed[1] = self.speed[1] + self.acceleration[1] * self.face
        self.speed[2] = self.speed[2] + self.acceleration[2]

        local dt_factor = dt * 60
        self.pos[1] = self.pos[1] + self.speed[1] * dt_factor
        self.pos[2] = self.pos[2] + self.speed[2] * dt_factor

        if self.fet == "airborne" and self.dict.gravity then
            self.speed[2] = self.speed[2] + self.dict.gravity * dt_factor
        end

        local new_buffer_state = {}
        for move, timer_val in pairs(self.buffer_state) do
            if timer_val > 1 then
                new_buffer_state[move] = timer_val - 1
            end
        end
        self.buffer_state = new_buffer_state
    end

    local is_frame_animation_ended = self.frame[2] <= 0

    if (self.inputdevice and self.inputdevice.inter_press == 1) or is_frame_animation_ended or
       (not CommonFunctions.table_intersection_check(self.cancel, {nil}) or self.kara > 0) then
        if self.inputdevice and self.inputdevice.current_input_processed then
             self.current_command = self.current_command or {}
             for _, inp_cmd in ipairs(self.inputdevice.current_input_processed) do
                table.insert(self.current_command, inp_cmd)
             end
        end
        get_command_lua(self, self.current_command)
    end

    local can_attempt_state_change = (self.inputdevice and self.inputdevice.inter_press == 1) or (self.buffer_state and next(self.buffer_state) ~= nil)
    local cancel_allows_change = (not CommonFunctions.table_intersection_check(self.cancel, {nil}) or self.kara > 0)
    local hitstop_allows_change = (self.hitstop == 0 or (self.hitstop > 0 and self.ignore_stop))

    if (can_attempt_state_change and cancel_allows_change and hitstop_allows_change) or is_frame_animation_ended then
        get_state_lua(self, self.buffer_state)
    end

    local can_advance_frame_logic = (self.hitstop > 0 and self.ignore_stop) or (self.hitstop == 0)
    local stun_condition_logic = (self.hold_on_stun and self.hitstun == 0) or (not self.hold_on_stun)

    if can_advance_frame_logic and stun_condition_logic then
        self.frame[2] = self.frame[2] - 1
    end

    if self.frame[2] <= 0 then
        if self.dict.states and self.dict.states[self.current_state] and self.dict.states[self.current_state].framedata then
            local framedata = self.dict.states[self.current_state].framedata
            local current_substate_idx_from_end = self.frame[1]

            if current_substate_idx_from_end >= 0 and #framedata > 0 then
                 -- Python: framedata[-self.frame[0]] which means index from end.
                 -- If self.frame[1] is 0 (last frame), we want framedata[#framedata]
                 -- If self.frame[1] is 1 (second to last), we want framedata[#framedata-1]
                 local direct_idx = #framedata - current_substate_idx_from_end
                 if framedata[direct_idx] then
                    next_frame_lua(self, framedata[direct_idx])
                 else
                    -- This case means animation sequence truly ended.
                    -- Or current_substate_idx_from_end was too large.
                    -- No more substates to process for this state via next_frame.
                    -- get_state will handle transitions if inputs/buffer allow.
                 end
            end
        end
    end

    if self.con_speed[1] ~= 0 or self.con_speed[2] ~= 0 then
        self.speed[1] = self.speed[1] + self.con_speed[1]
        self.speed[2] = self.speed[2] + self.con_speed[2]
    end

    if self.hitstop > 0 then self.hitstop = self.hitstop - 1 end
    if self.kara > 0 then self.kara = self.kara - 1 end

    self.current_command = {}

    if type(self.time_kill) == "number" then
        self.time_kill = self.time_kill - 1
        if self.time_kill <= 0 then
            object_kill_lua(self)
        end
    end
end

function BaseActiveObject:draw()
    local textures_to_draw = {}
    if self.image and self.image ~= "reencor/none" then
        table.insert(textures_to_draw, {
            image_path = self.image, -- Store path for lookup
            image_offset = self.image_offset,
            image_size = self.image_size, -- This is the intended draw size, not necessarily source image size
            image_mirror = self.image_mirror,
            image_tint_py = self.image_tint, -- Store as PyColor {255,255,255,255}
            image_angle_euler = self.image_angle,
            image_repeat = self.image_repeat,
            image_glow = self.image_glow,
            -- type field from python was: texture.get("type", self.type) == "character"
            -- This was used for an 'always_on_top' flag in the original draw_texture.
            -- Love2D handles draw order by sequence or Canvases.
        })
    end
    for _, tex_data in ipairs(self.draw_textures or {}) do
        -- Ensure tex_data from JSON also uses image_path and py_tint if applicable
        table.insert(textures_to_draw, tex_data)
    end

    for _, tex_info in ipairs(textures_to_draw) do
        local image_key_to_use = CommonFunctions.get_key_from_path(tex_info.image_path)
        print("BaseActiveObject:draw - Original image path: '" .. tex_info.image_path .. "', Generated key: '" .. image_key_to_use .. "' for object: " .. (self.dict.name or "Unknown"))
        local img_obj_and_dims = self.game.image_dict and self.game.image_dict[image_key_to_use]
        if not img_obj_and_dims then print("BaseActiveObject:draw - Image NOT found for key: '" .. image_key_to_use .. "' from path: '" .. tex_info.image_path .. "'") end

        if img_obj_and_dims and img_obj_and_dims[1] then
            local img_obj = img_obj_and_dims[1] -- The Love2D Image object
            local src_img_w, src_img_h = img_obj:getDimensions()

            local offset = tex_info.image_offset or {0,0,0}
            local draw_size = tex_info.image_size or {src_img_w, src_img_h} -- Default to source image size if not specified
            local mirror = tex_info.image_mirror or {false, false}
            local tint_py = tex_info.image_tint_py or {255,255,255,255}
            local angle_euler = tex_info.image_angle_euler or {0,0,0}
            -- repeat and glow need specific Love2D handling (shaders, Quad with wrap mode)

            local world_x = self.pos[1] + (self.draw_shake[1] or 0)
            local world_y = self.pos[2] + (self.draw_shake[2] or 0)
            -- world_z = self.pos[3] + (offset[3] or 0) -- For potential layer sorting

            -- Simplified positioning: Draw image centered at world_x, world_y, respecting offsets.
            -- Offsets are from the center.
            local center_x = world_x + offset[1] * self.face
            local center_y = world_y + offset[2] -- Assuming Y offset is not affected by face

            local scale_x_val = (draw_size[1] / src_img_w) * self.scale[1]
            local scale_y_val = (draw_size[2] / src_img_h) * self.scale[2]

            if self.face < 0 then scale_x_val = -scale_x_val end -- Flip based on character face
            if mirror[1] then scale_x_val = -scale_x_val end -- Additional explicit X mirror
            if mirror[2] then scale_y_val = -scale_y_val end -- Explicit Y mirror

            love.graphics.setColor(tint_py[1]/255, tint_py[2]/255, tint_py[3]/255, (tint_py[4] or 255)/255)
            love.graphics.draw(img_obj, center_x, center_y, math.rad(angle_euler[3]), scale_x_val, scale_y_val, src_img_w/2, src_img_h/2)
            love.graphics.setColor(1,1,1,1)
        end
    end
end

local function reset_CharacterActiveObject(obj, args)
    args = args or {}

    obj.game = args.game or obj.game
    obj.dict = args.dict or obj.dict

    obj.type = string.lower(obj.dict.type or "character")
    obj.team = args.team or obj.team or 1
    obj.inputdevice = args.inputdevice or obj.inputdevice or InputDevice.get_dummy()
    obj.parent = args.parent -- Can be nil

    if args.pos and #args.pos == 2 then
        obj.pos = {args.pos[1], args.pos[2], 0}
    elseif args.pos and #args.pos == 3 then
        obj.pos = {args.pos[1], args.pos[2], args.pos[3]}
    elseif args.pos == nil and obj.pos == nil then -- Ensure pos is initialized if not set by args or previously
        obj.pos = {0,0,0}
    end

    obj.face = args.face or obj.face or 1
    obj.palette_index = args.palette or obj.palette_index or 0

    obj.hurt_coll_hit = {}
    obj.hit_coll_hurt = {}
    obj.trigger_coll_hurt = {}
    obj.take_coll_grab = {}

    obj.image = "reencor/none"
    obj.image_offset = {0,0,0}
    obj.image_size = {100,100,0}
    obj.image_mirror = {false, false}
    obj.image_tint = {1,1,1,1}
    obj.image_angle = {0,0,0}
    obj.image_repeat = false
    obj.image_glow = 0
    obj.draw_textures = {}
    obj.draw_shake = {0,0,0,0,0,0}

    obj.current_command = {"5"}
    obj.command_index_timer = {}
    if obj.dict.states then
        for move_name, state_data in pairs(obj.dict.states) do
            if state_data.command and type(state_data.command) == "table" then
                obj.command_index_timer[move_name] = {}
                for _ = 1, #state_data.command do
                    table.insert(obj.command_index_timer[move_name], {0,0})
                end
            end
        end
    end

    obj.mass = obj.dict.mass or 1
    obj.scale = obj.dict.scale or {1,1}
    obj.time_kill = obj.dict.timekill or false

    obj.gauges = {}
    if obj.dict.gauges then
        for gauge_name, gauge_data in pairs(obj.dict.gauges) do
            obj.gauges[gauge_name] = gauge_data.inicial or 0
        end
    end
    obj.boxes = obj.dict.boxes or {}

    obj.frame = {0,0}
    obj.repeat_count = 0
    obj.ignore_stop = false
    obj.hold_on_stun = false
    obj.hitstun = 0
    obj.hitstop = 0

    obj.speed = {0,0}
    obj.acceleration = {0,0}
    obj.con_speed = {0,0}
    obj.air_time = 0
    obj.air_max_height = 0

    obj.fet = "grounded"
    obj.grabed = nil
    obj.cancel = {nil}
    obj.kara = 0
    obj.current_state = "Stand"
    obj.buffer_state = {}
    obj.wallbounce = false

    obj.combo = 0
    obj.parry = {"6", 0}
    obj.guard = ""
    obj.juggle = 100
    obj.damage_scaling = {100, 100}
    obj.last_damage = {0,0}

    obj.move_raw_input = {}

    obj.self_main_object = nil
    obj.other_main_object = nil
    obj.influence_object = nil

    if obj.inputdevice and obj.inputdevice.set_active_object then
        obj.inputdevice:set_active_object(obj)
    elseif obj.inputdevice then
        obj.inputdevice.active_object = obj
    end
    obj.combo_list = {}

    local initial_state_name = args.inicial_state or "Stand"
    if obj.dict.states and obj.dict.states[initial_state_name] and obj.dict.states[initial_state_name].framedata and #obj.dict.states[initial_state_name].framedata > 0 then
        obj.current_state = initial_state_name
        obj.frame = {#obj.dict.states[initial_state_name].framedata -1, 0}
        get_state_lua(obj, {[initial_state_name] = 2}, true)
        if obj.dict.states[obj.current_state] and #obj.dict.states[obj.current_state].framedata > 0 then
            next_frame_lua(obj, obj.dict.states[obj.current_state].framedata[1])
        else
             print("Warning (reset): Initial state " .. obj.current_state .. " has no framedata after get_state.")
        end
    else
        print("Warning (reset): Could not set initial state: " .. initial_state_name .. " or it has no framedata.")
        if obj.dict.states and obj.dict.states["Stand"] and #obj.dict.states["Stand"].framedata > 0 then
            obj.current_state = "Stand"
            obj.frame = {#obj.dict.states["Stand"].framedata-1, 0}
            next_frame_lua(obj, obj.dict.states["Stand"].framedata[1])
        else
            print("Critical Warning (reset): Default 'Stand' state also missing or has no framedata.")
        end
    end
end

local ActiveObjectsModule = {
    BaseActiveObject = BaseActiveObject,
    reset_CharacterActiveObject = reset_CharacterActiveObject
}

return ActiveObjectsModule
