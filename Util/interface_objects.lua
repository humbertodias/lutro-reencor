print("Loading Util/interface_objects.lua")

local common_functions = require("Util.common_functions")
local renderer = require("Util.renderer")

local interface_objects = {}
print("Created interface_objects table")

-- Menu_Item
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
    -- ... draw logic
end
interface_objects.MenuItem = MenuItem
print("Defined MenuItem")

-- ... (full implementation of all other classes)

print("Returning interface_objects table")
return interface_objects
