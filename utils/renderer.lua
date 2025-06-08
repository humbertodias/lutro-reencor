-- utils/renderer.lua

local Renderer = {}

-- This table will store loaded images (Love2D Image objects)
-- In the original, texture_id was an OpenGL texture ID. Here we'll use paths or a game-specific ID.
local image_cache = {}
local font_cache = {} -- For Love2D Font objects

-- Helper to convert Python color (0-255) to Love2D color (0-1)
local function toLoveColor(pyColor, default_alpha)
    default_alpha = default_alpha or 255
    if not pyColor then return 1,1,1,1 end -- Default to white
    return pyColor[1]/255, pyColor[2]/255, pyColor[3]/255, (pyColor[4] or default_alpha)/255
end

--------------------------------------------------------------------------------
-- Initialization (Replaces set_mode_opengl)
--------------------------------------------------------------------------------
-- In Love2D, this is typically handled in conf.lua and love.load()
-- For example, in conf.lua:
-- function love.conf(t)
--     t.window.width = 640
--     t.window.height = 400
--     t.window.title = "Reencor Remake - Love2D"
--     t.modules.joystick = true
--     t.modules.graphics = true
--     -- etc.
-- end
-- And in love.load():
-- love.graphics.setDefaultFilter("nearest", "nearest")
-- love.graphics.setBlendMode("alpha", "alphamultiply") -- Common blend mode

-- The detailed GL states from set_mode_opengl (depth test, lighting, etc.)
-- are mostly for 3D fixed-function pipeline. Love2D is primarily 2D.
-- Depth testing would require custom shaders or careful use of Canvases with depth buffers.
-- Lighting would require shaders.
-- For now, we'll assume standard Love2D 2D rendering.

--------------------------------------------------------------------------------
-- Texture Loading
--------------------------------------------------------------------------------
function Renderer.loadImage(filepath)
    if image_cache[filepath] then
        return image_cache[filepath]
    end
    local success, image_or_error = pcall(love.graphics.newImage, filepath)
    if success then
        image_or_error:setFilter("nearest", "nearest") -- Default filter from original
        image_cache[filepath] = image_or_error
        return image_or_error
    else
        print("Error loading image:", filepath, image_or_error)
        return nil
    end
end

-- The original font_texture created a texture for each character.
-- Love2D's approach is to use love.graphics.newFont and print strings.
-- If individual character images are strictly needed (as per original design):
function Renderer.loadFontCharacterAsImage(font_obj, character_string, r,g,b) -- color components 0-255
    local char_key = font_obj:getPath() .. "_" .. font_obj:getSize() .. "_" .. character_string .. "_" .. r ..g ..b
    if image_cache[char_key] then return image_cache[char_key] end

    local text_obj = love.graphics.newText(font_obj, character_string)
    local w, h = text_obj:getDimensions()
    if w == 0 or h == 0 then return nil end -- Cannot create empty canvas

    local canvas = love.graphics.newCanvas(w, h)
    canvas:setFilter("nearest", "nearest")
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    love.graphics.setColor(r/255, g/255, b/255, 1)
    love.graphics.draw(text_obj, 0, 0)
    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1,1)

    image_cache[char_key] = canvas
    return canvas -- Return the canvas (which is a Drawable and Texture)
end

-- More common Love2D font handling:
function Renderer.loadFont(font_path, size)
    local key = font_path .. "_" .. size
    if font_cache[key] then return font_cache[key] end
    local success, font_or_error = pcall(love.graphics.newFont, font_path, size)
    if success then
        font_or_error:setFilter("nearest", "nearest")
        font_cache[key] = font_or_error
        return font_or_error
    else
        print("Error loading font:", font_path, font_or_error)
        return nil
    end
end

--------------------------------------------------------------------------------
-- Drawing Functions
--------------------------------------------------------------------------------

-- texture_id (image_obj in Love2D), pos={x,y,z}, size={w,h}, flip={boolX,boolY}, tint_py={r,g,b,a}, angle_euler={ax,ay,az}
function Renderer.drawTexture(image_obj, args)
    args = args or {}
    local pos = args.pos or {0,0,0}
    local size = args.size or {image_obj:getWidth(), image_obj:getHeight()}
    local flip = args.flip or {false, false}
    local tint_py = args.tint -- Python color (0-255)
    local angle_euler = args.angle or {0,0,0} -- Assuming z-axis rotation is angle_euler[3]
    -- local repeat_mode = args.repeat -- TODO: Use Quad with wrap mode if needed
    -- local glow = args.glow or 0 -- TODO: Requires shader
    -- local always_on_top = args.always_on_top -- TODO: Manage with draw order or Canvases
    -- local center_origin = args.center_origin

    if not image_obj then return end

    local x, y = pos[1], pos[2] -- Z (pos[3]) would be for layer sorting

    local sx, sy = size[1] / image_obj:getWidth(), size[2] / image_obj:getHeight()
    if flip[1] then sx = -sx end
    if flip[2] then sy = -sy end

    local r_rad = math.rad(angle_euler[3]) -- Use Z-axis rotation for 2D

    local ox, oy = 0, 0
    if args.center_origin then
        ox = image_obj:getWidth() / 2
        oy = image_obj:getHeight() / 2
    end
    -- The original draw_texture had complex translation logic before drawing at (0,0) relative to new origin.
    -- Love2D's draw(image, x, y, r, sx, sy, ox, oy) is simpler if x,y is the desired top-left or center.
    -- For now, assume x,y is top-left unless center_origin is true, then x,y is center.

    if args.center_origin then
        x = x - (image_obj:getWidth()/2 * sx) -- Adjust if sx,sy are part of size already
        y = y - (image_obj:getHeight()/2 * sy)
    end

    love.graphics.push()
    love.graphics.setColor(toLoveColor(tint_py))

    -- Original logic: translate(x + size[0]/2, y + size[1]/2, z), rotate, translate(-size[0]/2, -size[1]/2, 0)
    -- This means rotation happens around the center of the quad.
    -- Love2D: draw(img, x,y, rot, sx,sy, ox,oy) where ox,oy is the local origin for rot and scale.
    -- To rotate around center: ox = width/2, oy = height/2. x,y are then the world coords of this local origin.

    local draw_x = x
    local draw_y = y
    local origin_x = image_obj:getWidth() / 2
    local origin_y = image_obj:getHeight() / 2

    love.graphics.draw(image_obj, draw_x, draw_y, r_rad, sx, sy, origin_x, origin_y)

    love.graphics.pop()
end

function Renderer.drawCross(args)
    args = args or {}
    local pos = args.pos or {0,0,0}
    local size = args.size or 40
    local color_py = args.color
    local thickness = args.thickness or 2

    local x, y = pos[1], pos[2]
    local half_size = size / 2

    love.graphics.push()
    love.graphics.setColor(toLoveColor(color_py))
    love.graphics.setLineWidth(thickness)
    love.graphics.line(x - half_size, y, x + half_size, y)
    love.graphics.line(x, y - half_size, x, y + half_size)
    love.graphics.pop()
end

function Renderer.drawLine(args)
    args = args or {}
    local pos1 = args.pos or {0,0,0}
    local pos2 = args.end_pos or {1,1,1}
    local color_py = args.color
    local thickness = args.thickness or 2

    love.graphics.push()
    love.graphics.setColor(toLoveColor(color_py))
    love.graphics.setLineWidth(thickness)
    love.graphics.line(pos1[1], pos1[2], pos2[1], pos2[2])
    love.graphics.pop()
end

function Renderer.drawRect(args)
    args = args or {}
    local rect_coords = args.rect -- {x,y,w,h}
    local color_py = args.color
    local line_thickness = args.thickness or 0 -- 0 for fill
    -- local z_offset = args.z_offset or 0 -- For layering
    -- local glow = args.glow or 1 -- Requires shader

    if not rect_coords then return end
    local x,y,w,h = rect_coords[1], rect_coords[2], rect_coords[3], rect_coords[4]

    local mode = "fill"
    if line_thickness > 0 then
        mode = "line"
        love.graphics.setLineWidth(line_thickness)
    end

    love.graphics.push()
    -- if z_offset ~= 0 then love.graphics.translate(0,0) -- Z would be part of a 3D camera or layer system
    love.graphics.setColor(toLoveColor(color_py))
    love.graphics.rectangle(mode, x, y, w, h)
    love.graphics.pop()
end

-- draw_teapod is GLUT specific, cannot be directly translated.
function Renderer.drawTeapot(...)
    -- print("Renderer.drawTeapot: Not implemented in Love2D")
end

-- Palette swapping needs shaders or ImageData manipulation in Love2D
function Renderer.paletteSwap(image_obj, palette_map)
    -- print("Renderer.paletteSwap: Requires shaders or ImageData manipulation in Love2D.")
    -- For ImageData:
    -- local imageData = image_obj:getData()
    -- imageData:mapPixel(function(x,y,r,g,b,a) ... end)
    -- local new_image = love.graphics.newImage(imageData)
    return image_obj -- Return original for now
end


--------------------------------------------------------------------------------
-- Camera Class
--------------------------------------------------------------------------------
Renderer.Camera = {}
Renderer.Camera.__index = Renderer.Camera

function Renderer.Camera:new(smoothness)
    local cam = setmetatable({}, Renderer.Camera)
    cam.smoothness = smoothness or 0.2
    cam.draw_shake = {0,0,0,0,0,0} -- x,y current; x_mag,y_mag,current_dur,total_dur
    cam.pos = {0,0, -400} -- x,y,z (z for zoom/scaling)
    cam.target_pos = {0,0, -400}
    cam.zoom = 1 -- Calculated from Z
    cam.x = 0
    cam.y = 0
    return cam
end

function Renderer.Camera:update(dt, target_world_pos) -- target_world_pos = {x,y,z}
    self.target_pos = target_world_pos

    -- Interpolate position
    self.pos[1] = self.pos[1] + (self.target_pos[1] - self.pos[1]) * self.smoothness -- * dt (optional for frame-rate independence)
    self.pos[2] = self.pos[2] + (self.target_pos[2] - self.pos[2]) * self.smoothness -- * dt
    self.pos[3] = self.pos[3] + (self.target_pos[3] - self.pos[3]) * self.smoothness -- * dt

    -- Apply shake (conceptual, needs to be driven by gameplay)
    CommonFunctions.update_display_shake(self) -- Assuming CommonFunctions is available

    self.x = self.pos[1] + (self.draw_shake[1] or 0)
    self.y = self.pos[2] + (self.draw_shake[2] or 0)

    -- Z to Zoom: Original gluPerspective had fov 90. gluLookAt Z pos was used for distance.
    -- A common way to simulate zoom from Z is scaling. If pos[3] is distance, larger Z = further away = smaller scale.
    if self.pos[3] == 0 then self.zoom = 1000 -- Avoid div by zero, very zoomed in
    elseif self.pos[3] < 0 then self.zoom = math.abs(400 / self.pos[3]) -- Example scaling factor
    else self.zoom = math.abs(self.pos[3] / 400) -- Needs tuning based on desired effect
    end
    if self.zoom == 0 then self.zoom = 0.01 end -- Avoid zero scale
end

-- Apply camera transformations
function Renderer.Camera:attach()
    love.graphics.push()
    local screen_w, screen_h = love.graphics.getDimensions()
    -- Translate to make camera's (x,y) the center of the screen, then scale for zoom
    love.graphics.translate(screen_w / 2, screen_h / 2)
    love.graphics.scale(self.zoom, self.zoom)
    love.graphics.translate(-self.x, -self.y)
end

function Renderer.Camera:detach()
    love.graphics.pop()
end

--------------------------------------------------------------------------------
-- Screen Class (Draw Call Batcher)
--------------------------------------------------------------------------------
-- This class collected draw calls. In Love2D, this can be useful for layers or specific render targets (Canvases).
-- For a direct translation, it will store function calls and their args.
Renderer.Screen = {}
Renderer.Screen.__index = Renderer.Screen

function Renderer.Screen:new(size_w, size_h)
    local screen = setmetatable({}, Renderer.Screen)
    screen.size = {size_w or love.graphics.getWidth(), size_h or love.graphics.getHeight()}
    screen.draw_list = {}
    return screen
end

-- These methods add calls to the list. Note: texture_id becomes image_obj.
function Renderer.Screen:drawTexture(image_obj, args) table.insert(self.draw_list, {Renderer.drawTexture, image_obj, args}) end
function Renderer.Screen:drawRect(args) table.insert(self.draw_list, {Renderer.drawRect, args}) end
function Renderer.Screen:drawCross(args) table.insert(self.draw_list, {Renderer.drawCross, args}) end
function Renderer.Screen:drawLine(args) table.insert(self.draw_list, {Renderer.drawLine, args}) end
-- Teapot is omitted

function Renderer.Screen:clear()
    self.draw_list = {}
end

function Renderer.Screen:display()
    -- Original also had glClear. In Love2D, clearing is usually at the start of love.draw()
    -- love.graphics.clear(toLoveColor(clear_color_py or {0,0,0,255}))

    for _, call_data in ipairs(self.draw_list) do
        local func = call_data[1]
        -- Unpack arguments after the function itself
        func(unpack(call_data, 2, #call_data))
    end
    self:clear() -- Clear list after drawing
end

--------------------------------------------------------------------------------
-- Text Utilities (Conceptual - Original relies on pre-rendered char textures)
--------------------------------------------------------------------------------
-- These need to be re-thought for Love2D's font system if not using pre-rendered chars.
-- Assuming image_dict now stores Love2D Image objects for each character if that path is taken.

function Renderer.getStringSize(image_dict_lua, text_str, scale_xy)
    scale_xy = scale_xy or {1,1}
    local total_width = 0
    local max_height = 0
    for i = 1, #text_str do
        local char = string.sub(text_str, i, i)
        local char_img_data = image_dict_lua["font " .. char] -- {img_obj, {w,h}}
        if char_img_data then
            total_width = total_width + char_img_data[2][1] * scale_xy[1]
            max_height = math.max(max_height, char_img_data[2][2] * scale_xy[2])
        end
    end
    return total_width, max_height
end

function Renderer.getTextureStringSize(image_dict_lua, texture_list, scale_xy)
    scale_xy = scale_xy or {1,1}
    local total_width = 0
    local max_height = 0
    for _, tex_info in ipairs(texture_list) do
        if image_dict_lua[tex_info.image] then
            local img_data = image_dict_lua[tex_info.image] -- {img_obj, {w,h}}
            local char_w = (tex_info.size and tex_info.size[1]) or img_data[2][1]
            local char_h = (tex_info.size and tex_info.size[2]) or img_data[2][2]
            total_width = total_width + char_w * scale_xy[1]
            max_height = math.max(max_height, char_h * scale_xy[2])
        end
    end
    return total_width, max_height
end

-- draw_string and draw_texture_as_string used Screen:draw_texture in Python.
-- In Lua, they would directly call Renderer.drawTexture or love.graphics.draw.
-- This makes the Screen batcher less necessary if these are called outside its list.

function Renderer.drawString(image_dict_lua, text_str, args)
    args = args or {}
    local pos = args.pos or {0,0,0}
    local scale_xy = args.scale or {1,1}
    local tint_py = args.color
    local alignment = args.alignment or "right" -- Love2D: "left", "center", "right"
    -- local top = args.top -- for z-ordering?

    local current_x = pos[1]
    local current_y = pos[2]

    -- If alignment is not "right", calculate total width first for left/center
    local total_w = 0
    if alignment ~= "right" then
        total_w, _ = Renderer.getStringSize(image_dict_lua, text_str, scale_xy)
        if alignment == "center" then
            current_x = current_x - total_w / 2
        else -- left
            current_x = current_x -- current_x - total_w; (Python version was sum(...) for left align start)
                                  -- If pos[1] is the starting point for left-align, then this is fine.
                                  -- Original: pos[0] - (0 if align="right" else sum_of_widths)
                                  -- So for left align, it should be pos[0] - total_w if pos[0] is the END of the string.
                                  -- Or, if pos[0] is the START, then no adjustment for 'left', current_x = pos[0]
        end
    end


    for i = 1, #text_str do
        local char = string.sub(text_str, i, i)
        local char_img_data = image_dict_lua["font " .. char] -- {img_obj, {w,h}}
        if char_img_data then
            local img_obj = char_img_data[1]
            local char_w, char_h = char_img_data[2][1], char_img_data[2][2]

            Renderer.drawTexture(img_obj, {
                pos = {current_x, current_y, pos[3]},
                size = {char_w * scale_xy[1], char_h * scale_xy[2]},
                tint = tint_py,
                -- other params like angle, flip default to false/0
            })
            current_x = current_x + char_w * scale_xy[1]
        end
    end
end


-- draw_texture_as_string is similar but iterates a list of texture objects.
function Renderer.drawTextureAsString(image_dict_lua, texture_info_list, args)
    args = args or {}
    local pos = args.pos or {0,0,0}
    local scale_xy = args.scale or {1,1}
    local tint_py = args.color
    local alignment = args.alignment or "right"

    local current_x = pos[1]

    local total_w = 0
    if alignment ~= "right" then
        total_w, _ = Renderer.getTextureStringSize(image_dict_lua, texture_info_list, scale_xy)
        if alignment == "center" then
            current_x = current_x - total_w / 2
        -- else: for left align, if pos[1] is the start, no change.
        end
    end

    for _, tex_info in ipairs(texture_info_list) do
        if image_dict_lua[tex_info.image] then
            local img_data = image_dict_lua[tex_info.image]
            local img_obj = img_data[1]
            local char_w = (tex_info.size and tex_info.size[1]) or img_data[2][1]
            local char_h = (tex_info.size and tex_info.size[2]) or img_data[2][2]

            Renderer.drawTexture(img_obj, {
                pos = {current_x, pos[2], pos[3]},
                size = {char_w * scale_xy[1], char_h * scale_xy[2]},
                tint = tint_py
            })
            current_x = current_x + char_w * scale_xy[1]
        end
    end
end


return Renderer
