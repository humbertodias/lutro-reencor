local common_functions = require("Util.common_functions")
local active_objects = require("Util.active_objects")
local interface_objects = require("Util.interface_objects")
local box_collisions = require("Util.box_collisions")

local screens = {}

local function load_objects(game, screen)
    game.active_stages = {
        active_objects.BaseActiveObject:new({
            game = game,
            dict = game.object_dict[game.selected_stage[1]],
            inicial_state = "Stand",
        })
    }
    screen.selected_stage_objects = game.active_stages

    game.active_players = {
        active_objects.BaseActiveObject:new({
            game = game,
            dict = game.object_dict[game.selected_characters[1]],
            pos = {-300, -1},
            face = 1,
            inputdevice = game.input_device_list[1],
            team = 1,
        }),
        active_objects.BaseActiveObject:new({
            game = game,
            dict = game.object_dict[game.selected_characters[2]],
            pos = {300, -1},
            face = -1,
            inputdevice = #game.input_device_list > 1 and game.input_device_list[2] or game.dummy_input_device,
            team = 2,
        }),
    }
    screen.selected_character_objects = game.active_players

    screen.combo_counters = {}
    for _, p in ipairs(screen.selected_character_objects) do
        table.insert(screen.combo_counters, interface_objects.ComboCounter:new(game, p))
    end

    screen.life_bars = {}
    for _, p in ipairs(screen.selected_character_objects) do
        table.insert(screen.life_bars, interface_objects.GaugeBar:new({
            game = game,
            dict = game.object_dict["Reencor/LifeBar"],
            parent = p
        }))
    end

    screen.super_bars = {}
    for _, p in ipairs(screen.selected_character_objects) do
        table.insert(screen.super_bars, interface_objects.GaugeBar:new({
            game = game,
            dict = game.object_dict["Reencor/SuperBar"],
            parent = p
        }))
    end

    game.object_list = {}
    for _, o in ipairs(screen.selected_stage_objects) do table.insert(game.object_list, o) end
    for _, o in ipairs(screen.selected_character_objects) do table.insert(game.object_list, o) end
    for _, o in ipairs(screen.combo_counters) do table.insert(game.object_list, o) end
    for _, o in ipairs(screen.life_bars) do table.insert(game.object_list, o) end
    for _, o in ipairs(screen.super_bars) do table.insert(game.object_list, o) end
end

-- ModeSelectionScreen
local ModeSelectionScreen = {}
ModeSelectionScreen.__index = ModeSelectionScreen
function ModeSelectionScreen:new(game)
    local self = setmetatable({}, ModeSelectionScreen)
    self.game = game
    self.modes = {
        ["Single Player"] = {"VersusScreen", "SinglePlayerCharacterSelectionScreen"},
        ["Multi Player"] = {"VersusScreen", "MultiPlayerCharacterSelectionScreen"},
        ["Training"] = {"TrainingScreen", "SinglePlayerCharacterSelectionScreen"},
        -- ... other modes
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
    for _, item in ipairs(self.mode_menu) do item:update(dt) end
    for _, selector in ipairs(self.menu_selectors) do selector:update(dt) end

    local all_selected = true
    for _, selector in ipairs(self.menu_selectors) do
        if not selector.selected_name then
            all_selected = false
            break
        end
    end

    if all_selected then
        self.selection_timer = self.selection_timer - 1
        if self.selection_timer == 0 then
            self.game:next_screen(self.modes[self.menu_selectors[1].selected_name])
        end
    else
        self.selection_timer = 120
    end
end

function ModeSelectionScreen:draw()
    for _, item in ipairs(self.mode_menu) do item:draw(self.game.screen, self.game.camera.pos) end
    for _, selector in ipairs(self.menu_selectors) do selector:draw(self.game.screen, self.game.camera.pos) end
end

function ModeSelectionScreen:deinit() end

screens.ModeSelectionScreen = ModeSelectionScreen

-- Other screens will be defined here in a similar way.
-- For brevity, only the structure of ModeSelectionScreen is shown.

return screens
