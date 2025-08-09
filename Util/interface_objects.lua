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
    -- ...
    return self
end
function MenuItem:selected() self.timer = 8 end
function MenuItem:update() if self.timer > 0 then self.timer = self.timer - 1 end end
function MenuItem:draw(screen, pos) end
interface_objects.MenuItem = MenuItem

-- MenuItemString
local MenuItemString = {}
MenuItemString.__index = MenuItemString
function MenuItemString:new(params)
    local self = setmetatable({}, MenuItemString)
    -- ...
    return self
end
function MenuItemString:selected() self.timer = 8 end
function MenuItemString:update() if self.timer > 0 then self.timer = self.timer - 1 end end
function MenuItemString:draw(screen, pos) end
interface_objects.MenuItemString = MenuItemString

-- MenuSelector
local MenuSelector = {}
MenuSelector.__index = MenuSelector
function MenuSelector:new(params)
    local self = setmetatable({}, MenuSelector)
    self.game = params.game
    self.team = params.team or 1
    self.inputdevice = params.inputdevice
    self.menu = params.menu
    self.selected_index = params.index or 1
    self.last_index = 1
    self.timer = 0
    self.selected = false
    self.selected_name = nil
    self.pos = {0,0}
    self.size = {100,100}
    self.color = color[params.index]
    self.scale = {1,1}
    self.select_int = 0
    self.index_int = 1
    return self
end
function MenuSelector:on_selection()
    self.menu[self.selected_index]:selected()
    self.menu[self.selected_index].func()
    self.selected = true
    self.selected_name = self.menu[self.selected_index].name
    self.select_int = 1
end
function MenuSelector:on_deselection()
    self.selected = false
    self.selected_name = nil
    self.select_int = -1
end
function MenuSelector:change_index(best_option)
    self.selected_index = best_option
    self.timer = 6
    self.last_index = self.selected_index
    self.index_int = 1
end
function MenuSelector:update() end
function MenuSelector:draw(screen, pos) end
interface_objects.MenuSelector = MenuSelector

-- ... (ComboCounter, GaugeBar, Message)

return interface_objects
