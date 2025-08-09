local common_functions = require("Util.common_functions")
local active_objects = require("Util.active_objects")
local interface_objects = require("Util.interface_objects")
local box_collisions = require("Util.box_collisions")
local renderer = require("Util.renderer")
local input_device = require("Util.input_device")
local game_screens = require("Util.game_screens")
local json = require("Util.json")

local game = {}
local load_assets, init_input_devices, next_screen -- Forward declarations

function love.load()
    -- love.graphics.setDepthMode("lequal", true) -- Disabled for debugging
    game.resolution = {love.graphics.getWidth(), love.graphics.getHeight()}
    game.internal_resolution = {1280, 800}

    game.camera = renderer.Camera:new(0.1)
    game.screen = renderer.Screen:new(game.internal_resolution)

    love.window.setTitle("REENCOR")

    -- ... (the rest of love.load)
end

function love.draw()
    love.graphics.clear(0.1, 0.1, 0.1, 1) -- Re-enabled color clearing

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 300, 200, 100, 100)
end

-- ... (the rest of the file)
