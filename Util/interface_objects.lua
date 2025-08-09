print("Loading Util/interface_objects.lua")

local common_functions = require("Util.common_functions")
local renderer = require("Util.renderer")
local box_collisions = require("Util.box_collisions")

local interface_objects = {}
print("Created interface_objects table")

local color = {
    {255, 0, 0, 255}, {0, 0, 255, 255}, {0, 255, 0, 255}, {255, 255, 0, 255},
    {255, 0, 255, 255}, {0, 255, 255, 255}, {255, 128, 0, 255}, {128, 0, 255, 255},
    {0, 128, 255, 255}, {128, 255, 0, 255}, {255, 0, 128, 255}, {0, 128, 128, 255},
}

-- MenuItem
local MenuItem = {}
MenuItem.__index = MenuItem
function MenuItem:new(params)
    local self = setmetatable({}, MenuItem)
    self.game = params.game
    self.name = params.name or "dummy"
    self.image = params.image or "reencor/none"
    self.pos = params.pos or {0,0,0}
    self.size = params.size or {100,100}
    self.face = params.face or -1
    self.func = params.func or function() end
    self.param = params.param
    self.timer = 0
    self.image_offset = {0,0,0}
    self.image_mirror = {false, false}
    self.image_tint = {255,255,255,255}
    self.image_angle = {0,0,0}
    self.image_repeat = false
    self.image_glow = 1
    self.draw_textures = {}
    self.draw_shake = {0,0,0,0,0,0}
    self.type = "menu item"
    self.scale = 1
    self.frame = {0,0}
    self.current_state = "Stand"
    common_functions.object_image(self, self.image)
    return self
end
function MenuItem:selected() self.timer = 8 end
function MenuItem:update() if self.timer > 0 then self.timer = self.timer - 1 end end
function MenuItem:draw(screen, pos)
    for _, texture in ipairs({ {image = self.image} }) do
        screen:draw_texture(
            self.game.image_dict[texture.image][1],
            {self.pos[1], self.pos[2], self.pos[3]},
            self.size,
            self.image_mirror,
            self.image_tint,
            self.image_angle,
            self.image_repeat,
            self.image_glow,
            true
        )
    end
end
interface_objects.MenuItem = MenuItem

-- MenuItemString
local MenuItemString = {}
MenuItemString.__index = MenuItemString
function MenuItemString:new(params)
    local self = setmetatable({}, MenuItemString)
    self.game = params.game
    self.name = params.name or ""
    self.string = params.string or ""
    self.pos = params.pos or {0,0,0}
    self.scale = params.scale or {1,1}
    self.func = params.func or function() end
    self.param = params.param
    self.alignment = params.alignment or "right"
    self.color = params.color or {255,255,255,255}
    self.gradient_timer = params.gradient_timer or 0
    self.timer = 0
    self.size = renderer.get_string_size and renderer.get_string_size(self.game.image_dict, self.name, self.scale) or {0,0}
    self.draw_shake = {0,0,0,0,0,0}
    return self
end
function MenuItemString:selected() self.timer = 8 end
function MenuItemString:update() if self.timer > 0 then self.timer = self.timer - 1 end end
function MenuItemString:draw(screen, pos)
    renderer.draw_string(
        self.game.image_dict,
        screen,
        self.string,
        {self.draw_shake[1] + pos[1] + self.pos[1], self.draw_shake[2] + pos[2] + self.pos[2], self.pos[3] - self.timer},
        self.scale,
        self.color,
        self.alignment
    )
end
interface_objects.MenuItemString = MenuItemString

-- ... (This is still not the full implementation, but it's more complete)
-- I will assume the user wants me to continue with this iterative process.

return interface_objects
