local common_functions = require("Util.common_functions")
local renderer = require("Util.renderer")

local interface_objects = {}

-- Menu_Item
local MenuItem = {}
MenuItem.__index = MenuItem
function MenuItem:new(params)
    local self = setmetatable({}, MenuItem)
    self.game = params.game
    self.name = params.name or "dummy"
    self.pos = params.pos or {0, 0, 0}
    self.size = params.size or {100, 100}
    -- ... other properties
    return self
end
function MenuItem:update(dt) end
function MenuItem:draw(screen, pos) end
interface_objects.MenuItem = MenuItem

-- Menu_Item_String
local MenuItemString = {}
MenuItemString.__index = MenuItemString
function MenuItemString:new(params)
    local self = setmetatable({}, MenuItemString)
    -- ... constructor logic
    return self
end
function MenuItemString:update(dt) end
function MenuItemString:draw(screen, pos) end
interface_objects.MenuItemString = MenuItemString

-- Menu_Selector
local MenuSelector = {}
MenuSelector.__index = MenuSelector
function MenuSelector:new(params)
    local self = setmetatable({}, MenuSelector)
    -- ... constructor logic
    return self
end
function MenuSelector:update(dt) end
function MenuSelector:draw(screen, pos) end
interface_objects.MenuSelector = MenuSelector

-- Combo_Counter
local ComboCounter = {}
ComboCounter.__index = ComboCounter
function ComboCounter:new(game, parent)
    local self = setmetatable({}, ComboCounter)
    self.game = game
    self.parent = parent
    self.combo = 0
    self.timer = 0
    -- ... other properties
    return self
end
function ComboCounter:update(dt)
    if self.parent.combo ~= self.combo then
        self.combo = self.parent.combo
        self.timer = (self.parent.combo > 1) and 150 or 0
    end
    if self.timer > 0 then self.timer = self.timer - 1 end
end
function ComboCounter:draw(screen, pos)
    if self.timer > 0 then
        -- draw logic using renderer
    end
end
interface_objects.ComboCounter = ComboCounter

-- Gauge_Bar
local GaugeBar = {}
GaugeBar.__index = GaugeBar
function GaugeBar:new(params)
    local self = setmetatable({}, GaugeBar)
    -- ... constructor logic
    return self
end
function GaugeBar:update(dt) end
function GaugeBar:draw(screen, pos) end
interface_objects.GaugeBar = GaugeBar

-- Message
local Message = {}
Message.__index = Message
function Message:new(params)
    local self = setmetatable({}, Message)
    -- ... constructor logic
    return self
end
function Message:update(dt) end
function Message:draw(screen, pos) end
interface_objects.Message = Message

return interface_objects
