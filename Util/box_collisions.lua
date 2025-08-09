local common_functions = require("Util.common_functions")
local BaseActiveObject = require("Util.active_objects").BaseActiveObject

local BoxCollisions = {}

function BoxCollisions.box_collide(r1x, r1y, r1w, r1h, r2x, r2y, r2w, r2h)
    return r1x < r2x + r2w and r1x + r1w > r2x and r1y < r2y + r2h and r1y + r1h > r2y
end

function BoxCollisions.boundingbox_boundingbox_collide(self, other, game)
    -- Complex collision logic to be translated here
end

function BoxCollisions.pushbox_pushbox_collide(self, other)
    -- Complex collision logic to be translated here
end

function BoxCollisions.hitbox_hurtbox_collide(self, other)
    if not self.boxes.hitbox or not other.boxes.hurtbox then return end

    for _, bi in ipairs(self.boxes.hitbox.boxes or {}) do
        for _, bu in ipairs(other.boxes.hurtbox.boxes or {}) do
            if BoxCollisions.box_collide(
                self.pos[1] + bi[1] * self.face - bi[3] * (self.face < 0 and 1 or 0),
                self.pos[2] + bi[2],
                bi[3],
                bi[4],
                other.pos[1] + bu[1] * other.face - bu[3] * (other.face < 0 and 1 or 0),
                other.pos[2] + bu[2],
                bu[3],
                bu[4]
            ) and (self.boxes.hitbox.hitset or 0) > 0 and (self.hitstop == 0 or other.hitstop == 0) and other.juggle > (self.boxes.hitbox.juggle or 1) and self.team ~= other.team then
                table.insert(self.hit_coll_hurt, other)
                table.insert(other.hurt_coll_hit, self)
                self.box = {
                    self.pos[1] + bi[1] * self.face - bi[3] * (self.face < 0 and 1 or 0),
                    self.pos[2] + bi[2],
                    bi[3],
                    bi[4],
                }
                return
            end
        end
    end
end

function BoxCollisions.takebox_grabbox_collide(self, other)
    -- Logic to be translated
end

function BoxCollisions.trigger_hurtbox_collide(self, other)
    -- Logic to be translated
end

function BoxCollisions.calculate_boxes_collitions(game)
    local active_objects = {}
    for _, obj in ipairs(game.object_list) do
        if obj.class_name == "BaseActiveObject" and (obj.type == "projectile" or obj.type == "character") then
            table.insert(active_objects, obj)
        end
    end

    local main_stage = game.active_stages[1]

    -- In Lua, permutations and combinations are not standard.
    -- We need to implement them or use nested loops.
    for i = 1, #active_objects do
        for j = 1, #active_objects do
            if i ~= j then
                local self_obj = active_objects[i]
                local other_obj = active_objects[j]
                BoxCollisions.trigger_hurtbox_collide(self_obj, other_obj)
                BoxCollisions.takebox_grabbox_collide(self_obj, other_obj)
                BoxCollisions.hitbox_hurtbox_collide(self_obj, other_obj)
            end
        end
    end

    for i = 1, #active_objects do
        for j = i + 1, #active_objects do
            BoxCollisions.pushbox_pushbox_collide(active_objects[i], active_objects[j])
        end
    end

    for _, self_obj in ipairs(active_objects) do
        -- ... rest of the logic from calculate_boxes_collitions
    end
end

function BoxCollisions.draw_boxes(game, object)
    if object.class_name == "BaseActiveObject" and (object.type == "projectile" or object.type == "character" or object.type == "stage") then
        for box_type, box_data in pairs(object.boxes) do
            local color = common_functions.colors[box_type]
            if color then
                for _, box in ipairs(box_data.boxes or {}) do
                    game.screen:draw_rect(
                        {
                            object.pos[1] + box[1] * object.face - box[3] * (object.face < 0 and 1 or 0),
                            object.pos[2] + box[2],
                            box[3],
                            box[4]
                        },
                        color,
                        2
                    )
                end
            end
        end
        -- game.screen:draw_cross(object.pos, 80)
    end
end

return BoxCollisions
