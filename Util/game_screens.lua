print("Loading Util/game_screens.lua")

local common_functions = require("Util.common_functions")
print("Loaded common_functions")
local active_objects = require("Util.active_objects")
print("Loaded active_objects")
local interface_objects = require("Util.interface_objects")
print("Loaded interface_objects")
local box_collisions = require("Util.box_collisions")
print("Loaded box_collisions")

local screens = {}
print("Created screens table")

local ModeSelectionScreen = {}
ModeSelectionScreen.__index = ModeSelectionScreen
function ModeSelectionScreen:new(game)
    local self = setmetatable({}, ModeSelectionScreen)
    self.game = game
    self.modes = {
        ["Single Player"] = {"VersusScreen", "SinglePlayerCharacterSelectionScreen"},
        ["Multi Player"] = {"VersusScreen", "MultiPlayerCharacterSelectionScreen"},
        ["Training"] = {"TrainingScreen", "SinglePlayerCharacterSelectionScreen"},
    }
    self.mode_menu = {}
    local i = 1
    for mode_name, _ in pairs(self.modes) do
        table.insert(self.mode_menu, interface_objects.MenuItemString:new({
            game = game, name = mode_name, string = mode_name, pos = {-550, 250 - i * 100, 0}
        }))
        i = i + 1
    end
    self.menu_selectors = {
        interface_objects.MenuSelector:new({
            game = game,
            inputdevice = game.input_device_list[1],
            menu = self.mode_menu,
            index = 1,
        })
    }
    self.selection_timer = 60
    return self
end
function ModeSelectionScreen:update(dt)
end
function ModeSelectionScreen:draw()
end

screens.ModeSelectionScreen = ModeSelectionScreen
print("Defined ModeSelectionScreen")

print("Returning screens table")
return screens
