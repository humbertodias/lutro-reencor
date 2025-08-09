local common_functions = require("Util.common_functions")
local active_objects = require("Util.active_objects")
local interface_objects = require("Util.interface_objects")
local box_collisions = require("Util.box_collisions")
local renderer = require("Util.renderer")
local input_device = require("Util.input_device")
local game_screens = require("Util.game_screens")
local json = require("Util.json")

local game = {}

function love.load()
    -- ... (love.load implementation)
    renderer.Renderer.set_projection(90, love.graphics.getWidth() / love.graphics.getHeight(), 0.1, 1000.0)
end

function love.update(dt)
    -- ... (love.update implementation)
end

function love.draw()
    -- ... (love.draw implementation)
end

-- ... (other helper functions)
