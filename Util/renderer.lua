local Renderer = {}

function Renderer.set_projection(fov, aspect, near, far)
    love.graphics.setProjection(fov, aspect, near, far)
end

function Renderer.load_image_path(path)
    local success, image = pcall(love.graphics.newImage, path)
    if success then
        return image, {image:getWidth(), image:getHeight()}
    else
        print("Failed to load image:", path)
        return nil, {0, 0}
    end
end

function Renderer.font_texture(font, text, color)
    -- LÖVE 2D handles fonts differently. This will be adapted later.
    return nil, {0, 0}
end

function Renderer.draw_texture(texture, pos, size, flip, tint, angle, should_repeat, glow, always_on_top, center_origin)
    pos = pos or {0, 0, 0}
    size = size or {texture:getWidth(), texture:getHeight()}
    flip = flip or {false, false}
    tint = tint or {255, 255, 255, 255}
    angle = angle or {0, 0, 0}
    should_repeat = should_repeat or false

    local x, y = pos[1], pos[2]
    local sx, sy = size[1] / texture:getWidth(), size[2] / texture:getHeight()
    if flip[1] then sx = -sx end
    if flip[2] then sy = -sy end

    local ox, oy = 0, 0
    if center_origin then
        ox = size[1] / 2
        oy = size[2] / 2
    end

    love.graphics.setColor(tint[1]/255, tint[2]/255, tint[3]/255, tint[4]/255)
    love.graphics.draw(texture, x, y, angle[3], sx, sy, ox, oy)
    love.graphics.setColor(1, 1, 1, 1)
end

function Renderer.draw_rect(rect, color, thickness, z_offset, glow)
    rect = rect or {0, 0, 10, 10}
    color = color or {255, 255, 255, 255}
    thickness = thickness or 0

    love.graphics.setColor(color[1]/255, color[2]/255, color[3]/255, color[4]/255)
    if thickness == 0 then
        love.graphics.rectangle("fill", rect[1], rect[2], rect[3], rect[4])
    else
        love.graphics.setLineWidth(thickness)
        love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local Camera = {}
Camera.__index = Camera

function Camera:new(smoothness)
    local self = setmetatable({}, Camera)
    self.smoothness = smoothness or 0.2
    self.pos = {0, 0, -400}
    self.target = {0, 0, -400}
    return self
end

function Camera:update(pos)
    self.target = pos
    self.pos[1] = self.pos[1] + (self.target[1] - self.pos[1]) * self.smoothness
    self.pos[2] = self.pos[2] + (self.target[2] - self.pos[2]) * self.smoothness
    self.pos[3] = self.pos[3] + (self.target[3] - self.pos[3]) * self.smoothness
end

function Camera:apply()
    love.graphics.lookAt(
        self.pos[1], self.pos[2], self.pos[3],
        self.pos[1], self.pos[2], self.pos[3] - 100,
        0, 1, 0
    )
end

local Screen = {}
Screen.__index = Screen

function Screen:new(size)
    local self = setmetatable({}, Screen)
    self.size = size or {800, 600}
    self.draw_list = {}
    return self
end

function Screen:draw_texture(...)
    table.insert(self.draw_list, {"texture", {...}})
end

function Screen:draw_rect(...)
    table.insert(self.draw_list, {"rect", {...}})
end

function Screen:display()
    for _, call in ipairs(self.draw_list) do
        if call[1] == "texture" then
            Renderer.draw_texture(unpack(call[2]))
        elseif call[1] == "rect" then
            Renderer.draw_rect(unpack(call[2]))
        end
    end
    self.draw_list = {}
end

function Renderer.draw_string(image_dict, screen, str, pos, scale, color, alignment, top)
    -- This will be replaced with love.graphics.printf
end

return {
    Renderer = Renderer,
    Camera = Camera,
    Screen = Screen
}
