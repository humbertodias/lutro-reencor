local common_functions = require("Util.common_functions")
local BaseActiveObject = require("Util.active_objects").BaseActiveObject

local BoxCollisions = {}

function BoxCollisions.box_collide(r1x, r1y, r1w, r1h, r2x, r2y, r2w, r2h)
    return r1x < r2x + r2w and r1x + r1w > r2x and r1y < r2y + r2h and r1y + r1h > r2y
end

-- ... (the rest of the collision functions)

function BoxCollisions.calculate_boxes_collitions(game)
    -- ...
end

function BoxCollisions.draw_boxes(game, object)
    -- ...
end

return BoxCollisions
