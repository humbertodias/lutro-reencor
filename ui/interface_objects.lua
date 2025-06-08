-- ui/interface_objects.lua

local CommonFunctions = require("utils.common_functions")
local nomatch = CommonFunctions.nomatch
local gradient_color_py = CommonFunctions.gradient_color -- Returns PyGame style color table {r,g,b,a} 0-255

-- Helper to convert Python color (0-255) to Love2D color (0-1)
local function toLoveColor(pyColor, default_alpha)
    default_alpha = default_alpha or 255
    if not pyColor then return 1,1,1,1 end
    return (pyColor[1] or 0)/255, (pyColor[2] or 0)/255, (pyColor[3] or 0)/255, (pyColor[4] or default_alpha)/255
end

local py_colors_list = {
    {255,0,0,255},{0,0,255,255},{0,255,0,255},{255,255,0,255},{255,0,255,255},{0,255,255,255},
    {255,128,0,255},{128,0,255,255},{0,128,255,255},{128,255,0,255},{255,0,128,255},{0,128,128,255},
}
local love_colors_list = {}
for _,c in ipairs(py_colors_list) do table.insert(love_colors_list, {toLoveColor(c)}) end


local InterfaceObjects = {}

InterfaceObjects.CustomJSONEncoder = {new = function() return setmetatable({}, {__index=InterfaceObjects.CustomJSONEncoder}) end}
function InterfaceObjects.CustomJSONEncoder:encode(obj)
    if _G.json and _G.json.encode then return _G.json.encode(obj) else return "" end -- Basic fallback
end

InterfaceObjects.Menu_Item = {}
InterfaceObjects.Menu_Item.__index = InterfaceObjects.Menu_Item
function InterfaceObjects.Menu_Item:new(args)
    local item = setmetatable({}, InterfaceObjects.Menu_Item)
    item.game = args.game; item.name = args.name or "dummy"; item.pos = args.pos or {0,0,0}
    item.size = args.size or {100,100}; item.face = args.face or 1 -- Changed default face to 1
    item.func = args.func or nomatch; item.param = args.param; item.timer = 0
    item.image_path = args.image or "reencor/none"; item.image = nil
    if item.game and item.game.image_dict and item.game.image_dict[item.image_path] then
         item.image = item.game.image_dict[item.image_path][1]
    elseif item.game and item.game.assets and item.game.assets.getImage then
        item.image = item.game.assets.getImage(item.image_path)
    end
    item.image_offset = args.image_offset or {0,0,0}; item.image_size_override = args.size
    item.image_mirror = args.image_mirror or {false,false}
    item.image_tint_py = args.image_tint or {255,255,255,255} -- Store PyColor
    item.image_angle_rad = math.rad((args.image_angle and args.image_angle[3]) or 0)
    item.scale = args.scale_xy or {1,1} -- Renamed from scale to avoid conflict
    item.draw_shake = {0,0,0,0,0,0}
    return item
end
function InterfaceObjects.Menu_Item:selected() self.timer = 8 end
function InterfaceObjects.Menu_Item:update(dt) if self.timer > 0 then self.timer = self.timer - (dt * 60) end end -- Use dt
function InterfaceObjects.Menu_Item:draw()
    if not self.image then return end
    local x = self.pos[1] + (self.draw_shake[1] or 0)
    local y = self.pos[2] + (self.draw_shake[2] or 0)
    local w = self.image:getWidth(); local h = self.image:getHeight()
    local sx = self.scale[1] * ((self.image_size_override and self.image_size_override[1]/w) or 1)
    local sy = self.scale[2] * ((self.image_size_override and self.image_size_override[2]/h) or 1)
    if self.face < 0 then sx = -sx end
    if self.image_mirror[1] then sx = -sx end; if self.image_mirror[2] then sy = -sy end
    love.graphics.setColor(toLoveColor(self.image_tint_py))
    love.graphics.draw(self.image, x, y, self.image_angle_rad, sx, sy, w/2 + self.image_offset[1], h/2 + self.image_offset[2])
    love.graphics.setColor(1,1,1,1)
end

InterfaceObjects.Menu_Item_String = {}
InterfaceObjects.Menu_Item_String.__index = InterfaceObjects.Menu_Item_String
function InterfaceObjects.Menu_Item_String:new(args)
    local item = setmetatable({}, InterfaceObjects.Menu_Item_String)
    item.game = args.game; item.name = args.name or ""; item.string_text = args.string or args.name or ""
    item.pos = args.pos or {0,0,0}; item.scale_xy = args.scale or {1,1} -- Renamed from scale
    item.func = args.func or nomatch; item.param = args.param
    item.alignment = args.alignment or "left" -- Changed default to left for Love2D print
    item.color_py = args.color or {255,255,255,255}
    item.font = (item.game and item.game.font_dict and item.game.font_dict["main_unispace_60"]) or love.graphics.getFont()
    item.size = {item.font:getWidth(item.string_text) * item.scale_xy[1], item.font:getHeight() * item.scale_xy[2]}
    item.timer = 0; item.draw_shake = {0,0,0,0,0,0}
    return item
end
function InterfaceObjects.Menu_Item_String:selected() self.timer = 8 end
function InterfaceObjects.Menu_Item_String:update(dt) if self.timer > 0 then self.timer = self.timer - (dt*60) end end
function InterfaceObjects.Menu_Item_String:draw()
    local x = self.pos[1] + (self.draw_shake[1] or 0)
    local y = self.pos[2] + (self.draw_shake[2] or 0)
    local z_visual_offset = self.pos[3] - (self.timer > 0 and self.timer or 0) -- Apply visual pop using Z as Y offset

    love.graphics.setColor(toLoveColor(self.color_py))
    love.graphics.push()
    love.graphics.translate(x, y + z_visual_offset)
    love.graphics.scale(self.scale_xy[1], self.scale_xy[2])

    local text_width = self.font:getWidth(self.string_text) -- unscaled
    local draw_x_aligned = 0
    if self.alignment == "right" then draw_x_aligned = -text_width
    elseif self.alignment == "center" then draw_x_aligned = -text_width / 2
    end
    love.graphics.print(self.string_text, draw_x_aligned, 0, 0) -- Rotation is 0
    love.graphics.pop()
    love.graphics.setColor(1,1,1,1)
end

InterfaceObjects.Menu_Selector = {}
InterfaceObjects.Menu_Selector.__index = InterfaceObjects.Menu_Selector
function InterfaceObjects.Menu_Selector:new(args)
    local selector = setmetatable({}, InterfaceObjects.Menu_Selector)
    selector.game = args.game; selector.team = args.team or 1
    selector.inputdevice = args.inputdevice
    selector.menu_items = args.menu or {}
    selector.selected_index = args.index or 1
    selector.last_index = args.index or 1
    selector.timer = 0; selector.is_selected_action = false; selector.selected_name = nil
    selector.base_color_py = py_colors_list[((args.index-1) % #py_colors_list) + 1] or {255,255,255,255} -- Use PyColor table
    selector.select_int = 0; selector.index_int = 0; selector.draw_shake = {0,0,0,0,0,0}
    return selector
end
function InterfaceObjects.Menu_Selector:on_selection()
    if self.menu_items[self.selected_index] then
        self.menu_items[self.selected_index]:selected()
        if self.menu_items[self.selected_index].func then self.menu_items[self.selected_index]:func(self.menu_items[self.selected_index].param) end
        self.is_selected_action = true; self.selected_name = self.menu_items[self.selected_index].name; self.select_int = 1
    end
end
function InterfaceObjects.Menu_Selector:on_deselection() self.is_selected_action = false; self.selected_name = nil; self.select_int = -1 end
function InterfaceObjects.Menu_Selector:change_index(new_idx)
    if new_idx ~= self.selected_index and self.menu_items[new_idx] then
        self.last_index = self.selected_index; self.selected_index = new_idx; self.timer = 6; self.index_int = 1
    end
end
function InterfaceObjects.Menu_Selector:update(dt)
    self.select_int = 0; self.index_int = 0
    if self.timer > 0 then self.timer = self.timer - (dt*60) end
    if self.timer <= 0 then self.last_index = self.selected_index end -- Snap to position after anim

    if self.inputdevice and self.inputdevice.inter_press == 1 then
        local current_input_list = self.inputdevice.current_input_processed or {}
        local p_b3, p_b2 = false, false; for _,inp in ipairs(current_input_list) do if inp=="p_b3" then p_b3=true end if inp=="p_b2" then p_b2=true end end
        if p_b3 then self:on_selection() elseif p_b2 then self:on_deselection() end

        if not self.is_selected_action then
            local dir = current_input_list[1]
            if dir and dir ~= "5" and #self.menu_items > 0 then
                local best_opt, best_score = -1, math.huge
                local cur_item = self.menu_items[self.selected_index]
                if not cur_item then return end
                local cx = cur_item.pos[1] + (cur_item.size[1] or 0)/2; local cy = cur_item.pos[2] + (cur_item.size[2] or 0)/2
                for i,item in ipairs(self.menu_items) do
                    if i ~= self.selected_index then
                        local ix = item.pos[1]+(item.size[1]or 0)/2; local iy = item.pos[2]+(item.size[2]or 0)/2
                        local dx, dy = cx-ix, iy-cy
                        local skip = false
                        if (dir=="6" and dx>=0) or (dir=="4" and dx<=0) or (dir=="2" and dy>=0) or (dir=="8" and dy<=0) then skip=true end
                        if string.len(dir)==1 and skip then -- Pure cardinal, already excluded
                        elseif string.len(dir)==1 and not skip then -- Valid cardinal
                        elseif dir=="9" and (dx>=0 or dy<=0) then skip=true -- up-right
                        elseif dir=="7" and (dx<=0 or dy<=0) then skip=true -- up-left
                        elseif dir=="3" and (dx>=0 or dy>=0) then skip=true -- down-right
                        elseif dir=="1" and (dx<=0 or dy>=0) then skip=true -- down-left
                        end
                        if not skip then
                            local sc_x_mul=(string.find(dir,"[134679]")) and 3 or 1; local sc_y_mul=(string.find(dir,"[123789]")) and 3 or 1
                            local score = (math.abs(dx)*sc_x_mul)+(math.abs(dy)*sc_y_mul)
                            if score<best_score then best_score=score; best_opt=i end
                        end
                    end
                end
                if best_opt ~= -1 then self:change_index(best_opt) end
            end
        end
    end
end
function InterfaceObjects.Menu_Selector:draw()
    local cur_item = self.menu_items[self.selected_index]; local last_item = self.menu_items[self.last_index]
    if not cur_item then return end
    local tx,ty,tw,th = cur_item.pos[1], cur_item.pos[2], cur_item.size[1], cur_item.size[2]
    local dx,dy = tx,ty
    if self.timer > 0 and last_item and last_item.pos and last_item.size then -- Animate position
        dx = tx + (last_item.pos[1] - tx) / 6 * self.timer
        dy = ty + (last_item.pos[2] - ty) / 6 * self.timer
        -- Size could also be animated if items have different sizes
    end
    local color_eff_py = self.base_color_py
    if not self.is_selected_action then
        local pulse_factor = self.timer / 30 -- timer goes from 30 down to 0 (or 6 down to 0 for move anim)
        color_eff_py = gradient_color_py(pulse_factor * 30, 30, self.base_color_py, {255,255,255,255})
    end
    love.graphics.setColor(toLoveColor(color_eff_py))
    love.graphics.setLineWidth(5)
    love.graphics.rectangle("line", dx, dy, tw, th)
    love.graphics.setColor(1,1,1,1); love.graphics.setLineWidth(1)
end

InterfaceObjects.Menu_Deck = {new=function() print("WARN: Menu_Deck not fully translated"); return {} end, update=function() end, draw=function() end}
InterfaceObjects.Menu_Cursor = {new=function() print("WARN: Menu_Cursor not fully translated"); return {} end, update=function() end, draw=function() end}

InterfaceObjects.Combo_Counter = {new=function(a) local o={game=a.game,parent=a.parent,combo=0,timer=0,grad_timer=0,pos={a.game.internal_resolution[1]*0.1, a.game.internal_resolution[2]*0.7,0},scale={0.8,0.8},draw_shake={0,0,0,0,0,0},font=a.game.font_dict["main_unispace_60"] or love.graphics.getFont()}; setmetatable(o, {__index=InterfaceObjects.Combo_Counter}); return o end}
function InterfaceObjects.Combo_Counter:update(dt)
    if self.parent.combo ~= self.combo then self.combo=self.parent.combo; self.timer=(self.combo>1 and 150 or 0); self.grad_timer=(self.combo>1 and 90 or 0) end
    if self.timer>0 then self.timer=self.timer-(dt*60) end; if self.grad_timer>0 then self.grad_timer=self.grad_timer-(dt*60) else self.grad_timer=6 end
end
function InterfaceObjects.Combo_Counter:draw()
    if self.timer>0 and self.parent then
        local x = self.pos[1]+(self.draw_shake[1] or 0); local y = self.pos[2]+(self.draw_shake[2] or 0)
        if self.parent.team ~= 1 then x = self.game.internal_resolution[1] - self.pos[1] - (self.font:getWidth("COMBO " .. self.combo)*self.scale[1]) end -- Adjust for P2
        local color_py = gradient_color_py(self.grad_timer, 6, {0,0,0,0}, {255,255,255,255})
        love.graphics.setColor(toLoveColor(color_py))
        love.graphics.setFont(self.font)
        love.graphics.printf("COMBO " .. self.combo, x, y, self.game.internal_resolution[1], self.parent.team==1 and "left" or "right", 0, self.scale[1], self.scale[2])
        love.graphics.setColor(1,1,1,1)
    end
end

InterfaceObjects.Gauge_Bar = {new=function(a) local o={game=a.game,dict=a.dict,parent=a.parent,pos=a.pos or {0,0,0},face=a.parent.face,scale_xy=a.dict.scale,timer=0,draw_shake={0,0,0,0,0,0}}; setmetatable(o,{__index=InterfaceObjects.Gauge_Bar}); return o end}
function InterfaceObjects.Gauge_Bar:update(dt) if self.timer>0 then self.timer=self.timer-(dt*60) else self.timer=(self.dict.bar and self.dict.bar.blink or 0) end end
function InterfaceObjects.Gauge_Bar:draw()
    if not (self.parent and self.dict and self.dict.name and self.parent.gauges and self.parent.dict.gauges) then return end
    local bar_def = self.dict.bar; local gauge_name=self.dict.name; local p_gauges=self.parent.gauges; local p_dict_gauges=self.parent.dict.gauges
    local cur_val=(p_gauges[gauge_name] or 0); local max_val=(p_dict_gauges[gauge_name] and p_dict_gauges[gauge_name].max) or 1; if max_val==0 then max_val=1 end
    local perc=math.max(0, math.min(1, cur_val/max_val))
    local color_py = (bar_def.blink and bar_def.blink > 0) and gradient_color_py(self.timer,bar_def.blink,bar_def.color[1],bar_def.color[2]) or gradient_color_py(cur_val,max_val,bar_def.color[1],bar_def.color[2])

    local start_x_rel = bar_def.start[1]; local end_x_rel = bar_def.end[1]; local y_pos = bar_def.start[2]
    local bar_full_len = math.abs(end_x_rel - start_x_rel)
    local current_bar_len = bar_full_len * perc

    local draw_start_x = self.game.internal_resolution[1]/2 + (start_x_rel * (self.parent.team==1 and 1 or -1))
    if self.parent.team == 2 then draw_start_x = draw_start_x - bar_full_len end -- Adjust P2 bar to grow leftwards correctly

    love.graphics.setColor(toLoveColor(color_py)); love.graphics.setLineWidth(bar_def.thickness or 10)
    if self.parent.team == 1 then love.graphics.line(draw_start_x, self.pos[2]+y_pos, draw_start_x + current_bar_len, self.pos[2]+y_pos)
    else love.graphics.line(draw_start_x + bar_full_len, self.pos[2]+y_pos, draw_start_x + bar_full_len - current_bar_len, self.pos[2]+y_pos) end

    if bar_def.level_indicator then
        local font = self.game.font_dict["main_unispace_60"] or love.graphics.getFont(); love.graphics.setFont(font)
        local level_str = tostring(math.floor((cur_val/max_val)*(bar_def.level or 1)))
        local text_x = self.game.internal_resolution[1]/2 + (bar_def.level_indicator[1]*(self.parent.team==1 and 1 or -1))
        local text_y = self.pos[2] + bar_def.level_indicator[2]
        love.graphics.printf(level_str, text_x, text_y, 100, self.parent.team==1 and "left" or "right",0,1.5,1.5)
    end
    love.graphics.setColor(1,1,1,1); love.graphics.setLineWidth(1)
end

InterfaceObjects.Message = {new=function(a) local o={game=a.game,pos=a.pos,scale_xy=a.scale,string_text=a.string,texture_string=a.texture_string,bg_color_py=a.background_pycolor,timer=a.time,color_py=a.color or {255,255,255,255},grad_timer=a.gradient_timer,kill_on_time=a.kill_on_time,top=a.top,draw_shake={0,0,0,0,0,0},allign=a.allign or "right",font=a.game.font_dict["main_unispace_60"] or love.graphics.getFont()}; setmetatable(o,{__index=InterfaceObjects.Message}); return o end}
function InterfaceObjects.Message:update(dt) if self.timer>0 then self.timer=self.timer-(dt*60) end; if self.grad_timer>0 then self.grad_timer=self.grad_timer-(dt*60) else self.grad_timer=6 end; if self.kill_on_time and self.timer<=0 then if self.game and self.game.remove_object then self.game:remove_object(self) end end end
function InterfaceObjects.Message:draw()
    local x=self.pos[1]+(self.draw_shake[1] or 0); local y=self.pos[2]+(self.draw_shake[2] or 0)
    local font_w = self.font:getWidth(self.string_text or "") * self.scale_xy[1]
    local font_h = self.font:getHeight() * self.scale_xy[2]
    -- TODO: Add texture_string_size calculation
    local total_w = font_w; local total_h = font_h

    if self.bg_color_py then
        love.graphics.setColor(toLoveColor(self.bg_color_py))
        local bg_x = x; if self.allign=="left" then bg_x=x elseif self.allign=="center" then bg_x=x-total_w/2 elseif self.allign=="right" then bg_x=x-total_w end
        love.graphics.rectangle("fill",bg_x,y,total_w,total_h)
    end
    love.graphics.setColor(toLoveColor(self.color_py)); love.graphics.setFont(self.font)
    love.graphics.printf(self.string_text or "", x,y,total_w,self.allign,0,self.scale_xy[1],self.scale_xy[2])
    -- TODO: Draw texture_string
    love.graphics.setColor(1,1,1,1)
end

return InterfaceObjects
