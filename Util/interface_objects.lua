local common_functions = require("Util.common_functions")
local renderer = require("Util.renderer")

local interface_objects = {}

-- Menu_Item
local MenuItem = {}
MenuItem.__index = MenuItem
function MenuItem:new(params)
    local self = setmetatable({}, MenuItem)
    -- ...
    return self
end
-- ... (other classes: MenuItemString, MenuSelector, etc.)

return interface_objects
