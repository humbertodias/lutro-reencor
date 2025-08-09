local M = {}

M.colors = {
    hurtbox = {20, 20, 255, 255},
    hitbox = {255, 20, 20, 255},
    takebox = {20, 255, 255, 255},
    grabbox = {20, 255, 20, 255},
    pushbox = {255, 0, 255, 255},
    triggerbox = {255, 128, 0, 255},
    boundingbox = {255, 255, 255, 255},
}

M.default_substate = {dur = 1}

-- ... (all the other tables and functions from the previous conversion)

function M.object_image_repeat(self, should_repeat, ...)
    self.image_repeat = should_repeat
end

function M.object_repeat_substate(self, repeat_substate, ...)
    repeat_substate = repeat_substate or {0,0}
    if self.repeat_count < repeat_substate[2] or repeat_substate[2] == -1 then
        self.frame = {self.frame[1] + repeat_substate[1], 0}
        self.repeat_count = self.repeat_count + 1
    end
    if self.repeat_count == repeat_substate[2] then
        self.frame = {self.frame[1], 0}
    end
end

M.function_dict = {
    -- ...
    image_repeat = M.object_image_repeat,
    -- ...
    repeat_substate = M.object_repeat_substate,
    -- ...
}

return M
