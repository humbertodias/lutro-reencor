-- utils/box_collisions.lua

local BaseActiveObject = require("objects.base_active_object").BaseActiveObject -- Assuming the module returns a table with BaseActiveObject key
local CommonFunctions = require("utils.common_functions")

-- From CommonFunctions
local function_dict = CommonFunctions.function_dict
local default_hitbox = CommonFunctions.default_hitbox
local attack_type_value = CommonFunctions.attack_type_value
local get_object_per_team_lua = CommonFunctions.get_object_per_team -- Renamed to avoid conflict
local get_command_lua = CommonFunctions.get_command
local get_state_lua = CommonFunctions.get_state
local next_frame_lua = CommonFunctions.next_frame
local merge_tables = CommonFunctions.merge_tables -- Assuming this helper exists in common_functions_lua
local table_intersection_check = CommonFunctions.table_intersection_check

local BoxCollisions = {}

--------------------------------------------------------------------------------
-- Core AABB Collision Check
--------------------------------------------------------------------------------
function BoxCollisions.box_collide(r1x, r1y, r1w, r1h, r2x, r2y, r2w, r2h)
    return r1x < r2x + r2w and r1x + r1w > r2x and
           r1y < r2y + r2h and r1y + r1h > r2y
end

--------------------------------------------------------------------------------
-- Specific Collision Type Functions
--------------------------------------------------------------------------------

-- self_obj, other_obj, game_obj
function BoxCollisions.boundingbox_boundingbox_collide(self_obj, other_obj, game_obj)
    local grounded = false
    local self_bb_data = (self_obj.boxes and self.obj.boxes.boundingbox) or {}
    local other_bb_data = (other_obj.boxes and other_obj.boxes.boundingbox) or {}

    for _, bi in ipairs(self_bb_data.boxes or {}) do
        for _, bu in ipairs(other_bb_data.boxes or {}) do
            -- Box coordinates calculation:
            -- x = obj.pos[1] + box_offset_x * obj.face - (if obj.face < 0 then box_width else 0)
            -- y = obj.pos[2] + box_offset_y
            local s_box_x = self_obj.pos[1] + bi[1] * self_obj.face - (self_obj.face < 0 and bi[3] or 0)
            local s_box_y = self_obj.pos[2] + bi[2]
            local o_box_x = other_obj.pos[1] + bu[1] * other_obj.face - (other_obj.face < 0 and bu[3] or 0)
            local o_box_y = other_obj.pos[2] + bu[2]

            if BoxCollisions.box_collide(s_box_x, s_box_y, bi[3], bi[4], o_box_x, o_box_y, bu[3], bu[4]) then
                if self_obj.pos[2] < o_box_y + bu[4] then -- Check if self_obj is above or at the same level as other_obj's top surface
                    grounded = true
                    if self_obj.fet ~= "grounded" and self_obj.grabed == nil and self_obj.hitstop == 0 then
                        self_obj.fet = "grounded"
                        self_obj.frame = {0,0} -- Reset animation frame
                        self_obj.current_command = self_obj.current_command or {}
                        table.insert(self_obj.current_command, "landing")
                        self_obj.wallbounce = false
                        self_obj.hitstun = 0
                        self_obj.air_time = 0
                        self_obj.juggle = 100

                        local combined_input = {}
                        for _, c in ipairs(self_obj.current_command) do table.insert(combined_input, c) end
                        if self_obj.inputdevice and self_obj.inputdevice.current_input_processed then
                            for _, c in ipairs(self_obj.inputdevice.current_input_processed) do table.insert(combined_input, c) end
                        end
                        get_command_lua(self_obj, combined_input)

                        local got_state = get_state_lua(self_obj, self_obj.buffer_state)
                        if got_state and self_obj.dict.states[self_obj.current_state] then
                            -- Python: self.dict["states"][self.current_state]["framedata"][-self.frame[0]]
                            -- Lua: self_obj.frame[1] is index from end (0 = last).
                            local framedata = self_obj.dict.states[self_obj.current_state].framedata
                            local idx = #framedata - self_obj.frame[1]
                            if framedata[idx] then
                                next_frame_lua(self_obj, framedata[idx])
                            end
                        end
                    end
                    if self_obj.hitstop == 0 then
                        if self_obj.hitstun == 0 then
                            self_obj.speed[1] = self_obj.speed[1] * (self_bb_data.grounded_friction or 0.7)
                        else
                            self_obj.speed[1] = self_obj.speed[1] * 0.85
                        end
                    end
                    self_obj.pos[2] = o_box_y + bu[4] - bi[2] -1 -- Adjust self_obj Y pos to be on top of other_obj
                    if self_obj.speed[2] < 0 then self_obj.speed[2] = 0 end -- Stop downward movement
                end
            end
        end

        -- Wall collision (screen edges) - assuming game_obj.pos is camera world center, game_obj.internal_resolution is screen size
        local game_half_width = game_obj.internal_resolution[1] * 0.5
        local left_bound = game_obj.pos[1] - game_half_width
        local right_bound = game_obj.pos[1] + game_half_width

        -- Check right wall
        if self_obj.pos[1] + (bi[1]*self_obj.face - (self_obj.face < 0 and bi[3] or 0)) + bi[3] > right_bound then -- Simplified: self_obj.pos[1] + 160 > right_bound
            if self_obj.wallbounce and string.find(self_obj.current_state or "", "ummble") then
                self_obj.frame = {0,0}; self_obj.speed = {-14, 24}; self_obj.buffer_state = self_obj.buffer_state or {}; self_obj.buffer_state.Tummble = 1;
                self_obj.face = 1; self_obj.hitstop = 8; -- game_obj.osc not directly translatable
                self_obj.juggle = 80; self_obj.wallbounce = false;
            end
            -- Transfer momentum logic (complex, simplified)
            if self_obj.hurt_coll_hit and #self_obj.hurt_coll_hit > 0 and self_obj.speed[1] > 0 then
                -- Simplified: self_obj.hurt_coll_hit[#self_obj.hurt_coll_hit].speed[1] = self_obj.hurt_coll_hit[#self_obj.hurt_coll_hit].speed[1] - self_obj.speed[1]
                self_obj.hurt_coll_hit = {}
            end
            self_obj.pos[1] = right_bound - (bi[1]*self_obj.face - (self_obj.face < 0 and bi[3] or 0)) - bi[3] -- Adjust position
        end

        -- Check left wall
        if self_obj.pos[1] + (bi[1]*self_obj.face - (self_obj.face < 0 and bi[3] or 0)) < left_bound then -- Simplified: self_obj.pos[1] - 160 < left_bound
             if self_obj.wallbounce and string.find(self_obj.current_state or "", "ummble") then
                self_obj.frame = {0,0}; self_obj.speed = {14, 24}; self_obj.buffer_state = self_obj.buffer_state or {}; self_obj.buffer_state.Tummble = 1;
                self_obj.face = -1; self_obj.hitstop = 8;
                self_obj.juggle = 80; self_obj.wallbounce = false;
            end
            if self_obj.hurt_coll_hit and #self_obj.hurt_coll_hit > 0 and self_obj.speed[1] < 0 then
                self_obj.hurt_coll_hit = {}
            end
            self_obj.pos[1] = left_bound - (bi[1]*self_obj.face - (self_obj.face < 0 and bi[3] or 0)) -- Adjust position
        end
    end

    if not grounded then
        if self_obj.fet == "grounded" and self_obj.inputdevice then
            self_obj.inputdevice.inter_press = 1 -- Signal input change if falling off edge
        end
        self_obj.fet = "airborne"
        self_obj.air_time = (self_obj.air_time or 0) + 1
        local air_friction = (self_bb_data and self_bb_data.airborne_friction) or {1,1}
        self_obj.speed[1] = self_obj.speed[1] * air_friction[1]
        self_obj.speed[2] = self_obj.speed[2] * air_friction[2]
    end
end


function BoxCollisions.pushbox_pushbox_collide(self_obj, other_obj)
    if self_obj.team == other_obj.team then return end

    local self_pb_data = (self_obj.boxes and self_obj.boxes.pushbox) or {}
    local other_pb_data = (other_obj.boxes and other_obj.boxes.pushbox) or {}

    for _, bi in ipairs(self_pb_data.boxes or {}) do
        for _, bu in ipairs(other_pb_data.boxes or {}) do
            local s_box_x = self_obj.pos[1] + bi[1] * self_obj.face - (self_obj.face < 0 and bi[3] or 0)
            local s_box_y = self_obj.pos[2] + bi[2]
            local o_box_x = other_obj.pos[1] + bu[1] * other_obj.face - (other_obj.face < 0 and bu[3] or 0)
            local o_box_y = other_obj.pos[2] + bu[2]

            if BoxCollisions.box_collide(s_box_x, s_box_y, bi[3], bi[4], o_box_x, o_box_y, bu[3], bu[4]) then
                local overlap = (s_box_x + bi[3]) - o_box_x -- Assuming self is to the left of other
                if s_box_x > o_box_x then -- Self is to the right
                    overlap = (o_box_x + bu[3]) - s_box_x
                end

                local push_amount = overlap / 2
                if self_obj.pos[1] == other_obj.pos[1] then -- Directly on top, push based on face
                    self_obj.pos[1] = self_obj.pos[1] - self_obj.face * 1
                    other_obj.pos[1] = other_obj.pos[1] + other_obj.face * 1 -- was -other.face
                elseif self_obj.pos[1] < other_obj.pos[1] then -- self is to the left
                    self_obj.pos[1] = self_obj.pos[1] - push_amount
                    other_obj.pos[1] = other_obj.pos[1] + push_amount
                else -- self is to the right
                    self_obj.pos[1] = self_obj.pos[1] + push_amount
                    other_obj.pos[1] = other_obj.pos[1] - push_amount
                end
                return -- Process one collision pair for pushbox
            end
        end
    end
end


function BoxCollisions.hitbox_hurtbox_collide(self_obj, other_obj)
    local self_hitbox_data = (self_obj.boxes and self_obj.boxes.hitbox) or {}
    local other_hurtbox_data = (other_obj.boxes and other_obj.boxes.hurtbox) or {}

    for _, bi in ipairs(self_hitbox_data.boxes or {}) do
        for _, bu in ipairs(other_hurtbox_data.boxes or {}) do
            local s_box_x = self_obj.pos[1] + bi[1] * self_obj.face - (self_obj.face < 0 and bi[3] or 0)
            local s_box_y = self_obj.pos[2] + bi[2]
            local o_box_x = other_obj.pos[1] + bu[1] * other_obj.face - (other_obj.face < 0 and bu[3] or 0)
            local o_box_y = other_obj.pos[2] + bu[2]

            if BoxCollisions.box_collide(s_box_x, s_box_y, bi[3], bi[4], o_box_x, o_box_y, bu[3], bu[4]) and
               (self_hitbox_data.hitset or 0) > 0 and
               (self_obj.hitstop == 0 or other_obj.hitstop == 0) and
               (other_obj.juggle or 0) >= (self_hitbox_data.juggle or 1) and -- Python was > instead of >=
               self_obj.team ~= other_obj.team then

                self_obj.hit_coll_hurt = self_obj.hit_coll_hurt or {}
                other_obj.hurt_coll_hit = other_obj.hurt_coll_hit or {}
                table.insert(self_obj.hit_coll_hurt, other_obj)
                table.insert(other_obj.hurt_coll_hit, self_obj)

                self_obj.collision_box_cache = {s_box_x, s_box_y, bi[3], bi[4]} -- Store the specific hitbox that collided
                return
            end
        end
    end
end

-- Similar translations for takebox_grabbox_collide, trigger_hurtbox_collide

function BoxCollisions.takebox_grabbox_collide(self_obj, other_obj)
    -- ... translation similar to hitbox_hurtbox_collide ...
    local self_takebox_data = (self_obj.boxes and self_obj.boxes.takebox) or {}
    local other_grabbox_data = (other_obj.boxes and other_obj.boxes.grabbox) or {}

    for _, bi in ipairs(self_takebox_data.boxes or {}) do
        for _, bu in ipairs(other_grabbox_data.boxes or {}) do
             local s_box_x = self_obj.pos[1] + bi[1] * self_obj.face - (self_obj.face < 0 and bi[3] or 0)
             local s_box_y = self_obj.pos[2] + bi[2]
             local o_box_x = other_obj.pos[1] + bu[1] * other_obj.face - (other_obj.face < 0 and bu[3] or 0)
             local o_box_y = other_obj.pos[2] + bu[2]
            if BoxCollisions.box_collide(s_box_x, s_box_y, bi[3], bi[4], o_box_x, o_box_y, bu[3], bu[4]) and
               self_obj.team ~= other_obj.team then
                self_obj.take_coll_grab = self_obj.take_coll_grab or {}
                table.insert(self_obj.take_coll_grab, other_obj)
                return
            end
        end
    end
end

function BoxCollisions.trigger_hurtbox_collide(self_obj, other_obj)
    -- ... translation similar to hitbox_hurtbox_collide ...
    local self_triggerbox_data = (self_obj.boxes and self_obj.boxes.triggerbox) or {}
    local other_hurtbox_data = (other_obj.boxes and other_obj.boxes.hurtbox) or {}
    for _, bi in ipairs(self_triggerbox_data.boxes or {}) do
        for _, bu in ipairs(other_hurtbox_data.boxes or {}) do
             local s_box_x = self_obj.pos[1] + bi[1] * self_obj.face - (self_obj.face < 0 and bi[3] or 0)
             local s_box_y = self_obj.pos[2] + bi[2]
             local o_box_x = other_obj.pos[1] + bu[1] * other_obj.face - (other_obj.face < 0 and bu[3] or 0)
             local o_box_y = other_obj.pos[2] + bu[2]
            if BoxCollisions.box_collide(s_box_x, s_box_y, bi[3], bi[4], o_box_x, o_box_y, bu[3], bu[4]) and
               self_obj.team ~= other_obj.team then
                self_obj.trigger_coll_hurt = self_obj.trigger_coll_hurt or {}
                table.insert(self_obj.trigger_coll_hurt, other_obj)
                return
            end
        end
    end
end


--------------------------------------------------------------------------------
-- Main Collision Calculation Function
--------------------------------------------------------------------------------
-- Helper for permutations (basic version for 2 elements)
local function simple_permutations_2(list)
    local perms = {}
    for i = 1, #list do
        for j = 1, #list do
            if i ~= j then
                table.insert(perms, {list[i], list[j]})
            end
        end
    end
    return perms
end

-- Helper for combinations (basic version for 2 elements)
local function simple_combinations_2(list)
    local combs = {}
    for i = 1, #list do
        for j = i + 1, #list do
            table.insert(combs, {list[i], list[j]})
        end
    end
    return combs
end


function BoxCollisions.calculate_boxes_collitions(game_obj)
    local active_objects = {}
    for _, obj in ipairs(game_obj.object_list or {}) do
        -- Assuming BaseActiveObject instances have a 'type_name' field set to "BaseActiveObject"
        -- or check for essential components of an active object.
        if obj.type_name == "BaseActiveObject" and (obj.type == "projectile" or obj.type == "character") then
            table.insert(active_objects, obj)
        end
    end

    if #active_objects == 0 then return end
    local main_stage = (game_obj.active_stages and game_obj.active_stages[1]) or nil

    -- Collision checks
    for _, pair in ipairs(simple_permutations_2(active_objects)) do
        local self_obj, other_obj = pair[1], pair[2]
        BoxCollisions.trigger_hurtbox_collide(self_obj, other_obj)
        BoxCollisions.takebox_grabbox_collide(self_obj, other_obj)
        BoxCollisions.hitbox_hurtbox_collide(self_obj, other_obj)
    end
    for _, pair in ipairs(simple_combinations_2(active_objects)) do
        local self_obj, other_obj = pair[1], pair[2]
        BoxCollisions.pushbox_pushbox_collide(self_obj, other_obj)
    end

    -- Process grab collisions
    for _, self_obj in ipairs(active_objects) do
        if self_obj.take_coll_grab and #self_obj.take_coll_grab > 0 then
            for _, other_obj in ipairs(self_obj.take_coll_grab) do
                if self_obj.boxes and self_obj.boxes.takebox then
                    for func_name_key, val_param in pairs(self_obj.boxes.takebox) do
                        if function_dict[func_name_key] then
                            function_dict[func_name_key](self_obj, val_param, other_obj)
                        end
                    end
                end
            end
            self_obj.take_coll_grab = {}
        end
    end

    -- Process trigger collisions
    for _, self_obj in ipairs(active_objects) do
        if self_obj.trigger_coll_hurt and #self_obj.trigger_coll_hurt > 0 then
            for _, other_obj in ipairs(self_obj.trigger_coll_hurt) do
                 if self_obj.boxes and self_obj.boxes.triggerbox then
                    for func_name_key, val_param in pairs(self_obj.boxes.triggerbox) do
                        if function_dict[func_name_key] then
                            function_dict[func_name_key](self_obj, val_param, other_obj)
                        end
                    end
                end
            end
            self_obj.trigger_coll_hurt = {}
        end
    end

    -- Process hit collisions (most complex part)
    for _, self_obj in ipairs(active_objects) do
        if self_obj.hit_coll_hurt and #self_obj.hit_coll_hurt > 0 then
            for _, other_obj in ipairs(self_obj.hit_coll_hurt) do
                local current_hitbox_def = merge_tables(default_hitbox, (self_obj.boxes and self_obj.boxes.hitbox) or {})
                local interaction_result_type = {"hurt"} -- Default hit type
                -- Variables ri, ru from Python seem related to rewards/penalties, not directly used in hit logic below.

                -- Block/Parry detection logic (highly detailed)
                local other_cancel_options = other_obj.cancel or {nil}
                local hitbox_type_list = current_hitbox_def.hittype or {}

                local other_input_dir = (other_obj.inputdevice and other_obj.inputdevice.current_input_processed and other_obj.inputdevice.current_input_processed[1]) or "5"

                if table_intersection_check(other_cancel_options, {"neutral", "interruption", "blocking"}) and other_obj.fet == "grounded" then
                    if (other_input_dir == "4" or (other_obj.guard == "block" and table_intersection_check(hitbox_type_list, {"high", "middle"}))) then
                        if table_intersection_check(hitbox_type_list, {"high", "middle"}) then interaction_result_type = {"block", "stand"} end
                    elseif (other_input_dir == "1" or (other_obj.guard == "block" and table_intersection_check(hitbox_type_list, {"low", "middle"}))) then
                         if table_intersection_check(hitbox_type_list, {"low", "middle"}) then interaction_result_type = {"block", "crouch"} end
                    end
                end

                if table_intersection_check(other_cancel_options, {"neutral", "interruption", "parry", "blocking"}) then
                    if (other_obj.parry and other_obj.parry[1] == "6" or (other_obj.guard == "parry" and table_intersection_check(hitbox_type_list, {"high", "middle"}))) then
                        if table_intersection_check(hitbox_type_list, {"high", "middle"}) and ((other_obj.parry and other_obj.parry[2] >= 16) or other_obj.guard == "parry") then
                            if other_obj.parry then other_obj.parry[2] = 0 end; interaction_result_type = {"parry", "stand"}
                        end
                    elseif (other_obj.parry and other_obj.parry[1] == "3" or (other_obj.guard == "parry" and table_intersection_check(hitbox_type_list, {"low", "middle"}))) then
                         if table_intersection_check(hitbox_type_list, {"low", "middle"}) and ((other_obj.parry and other_obj.parry[2] >= 16) or other_obj.guard == "parry") then
                            if other_obj.parry then other_obj.parry[2] = 0 end; interaction_result_type = {"parry", "crouch"}
                        end
                    end
                end

                other_obj.current_command = interaction_result_type
                for _, ht_val in ipairs(hitbox_type_list) do table.insert(other_obj.current_command, ht_val) end

                self_obj.current_command = self_obj.current_command or {}
                local self_hit_status = "hited"
                if interaction_result_type[1] == "parry" then self_hit_status = "parried"
                elseif interaction_result_type[1] == "block" then self_hit_status = "blocked" end
                table.insert(self_obj.current_command, self_hit_status)

                if not other_obj.hitstun or other_obj.hitstun == 0 then
                    if self_obj.self_main_object then -- Ensure self_main_object exists
                        self_obj.self_main_object.damage_scaling = {100, 100}
                        self_obj.self_main_object.combo_list = {}
                        self_obj.self_main_object.combo = 0
                    end
                end

                if self_obj.self_main_object then -- Pass attacker's main object scaling
                    self_obj.damage_scaling = self_obj.self_main_object.damage_scaling
                end

                -- Create Sparks object
                if game_obj.object_dict and game_obj.object_dict["SF3/Sparks"] and BaseActiveObject then
                    local spark_pos_x = self_obj.collision_box_cache and (self_obj.collision_box_cache[1] + self_obj.collision_box_cache[3] / 2) or self_obj.pos[1]
                    local spark_pos_y = self_obj.collision_box_cache and (self_obj.collision_box_cache[2] + self_obj.collision_box_cache[4] / 2) or self_obj.pos[2]

                    local spark_initial_state = "medium" -- Default
                    for atk_type_key, _ in pairs(attack_type_value) do
                        if table_intersection_check(other_obj.current_command, {atk_type_key}) then
                            spark_initial_state = atk_type_key; break
                        end
                    end

                    local spark = BaseActiveObject:new({
                        game = game_obj,
                        dict = game_obj.object_dict["SF3/Sparks"],
                        pos = {spark_pos_x, spark_pos_y, 0},
                        face = self_obj.face,
                        inicial_state = spark_initial_state
                    })
                    table.insert(game_obj.object_list, spark)
                end

                -- Apply all hitbox effects via function_dict
                for func_key, param_val in pairs(current_hitbox_def) do
                    if function_dict[func_key] then
                        function_dict[func_key](self_obj, param_val, other_obj)
                    end
                end

                if other_obj.hitstun and other_obj.hitstun > 0 then
                    if self_obj.self_main_object then
                        self_obj.self_main_object.combo = (self_obj.self_main_object.combo or 0) + 1
                        self_obj.self_main_object.combo_list = self_obj.self_main_object.combo_list or {}
                        table.insert(self_obj.self_main_object.combo_list, (self_obj.dict.name or "obj") .. " " .. (self_obj.current_state or ""))
                    end
                end
            end
            self_obj.hit_coll_hurt = {}
        end
    end

    -- Bounding box collisions with stage
    if main_stage then
        for _, self_obj in ipairs(active_objects) do
            BoxCollisions.boundingbox_boundingbox_collide(self_obj, main_stage, game_obj)
        end
    end
end


--------------------------------------------------------------------------------
-- Debug Drawing Function
--------------------------------------------------------------------------------
function BoxCollisions.draw_boxes_debug(game_obj, current_obj)
    -- Check if it's a BaseActiveObject type, or has expected structure
    if not (current_obj.type_name == "BaseActiveObject" and current_obj.boxes) then return end
    if not (current_obj.type == "projectile" or current_obj.type == "character" or current_obj.type == "stage") then return end

    local original_r, original_g, original_b, original_a = love.graphics.getColor()

    for box_type, box_data in pairs(current_obj.boxes) do
        local color_py = CommonFunctions.colors[box_type]
        if color_py then
            love.graphics.setColor(color_py[1]/255, color_py[2]/255, color_py[3]/255, (color_py[4] or 255)/255)
            for _, box_coords in ipairs(box_data.boxes or {}) do
                local x = current_obj.pos[1] + box_coords[1] * current_obj.face - (current_obj.face < 0 and box_coords[3] or 0)
                local y = current_obj.pos[2] + box_coords[2]
                local w = box_coords[3]
                local h = box_coords[4]
                love.graphics.rectangle("line", x, y, w, h)
            end
        end
    end

    -- Draw cross at object origin
    love.graphics.setColor(1,1,1,1) -- White cross
    love.graphics.setLineWidth(1)
    love.graphics.line(current_obj.pos[1] - 20, current_obj.pos[2], current_obj.pos[1] + 20, current_obj.pos[2])
    love.graphics.line(current_obj.pos[1], current_obj.pos[2] - 20, current_obj.pos[1], current_obj.pos[2] + 20)

    love.graphics.setColor(original_r, original_g, original_b, original_a) -- Reset color
end


return BoxCollisions
