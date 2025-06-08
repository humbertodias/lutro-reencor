-- utils/common_functions.lua

local CommonFunctions = {}

-- Helper to convert Python color (0-255) back to a table if needed by game logic expecting 0-255
local function toPyColorTable(pyColor)
    if not pyColor then return {0,0,0,255} end
    return {pyColor[1], pyColor[2], pyColor[3], pyColor[4] or 255}
end

CommonFunctions.colors = {
    hurtbox = {20, 20, 255, 255}, hitbox = {255, 20, 20, 255}, takebox = {20, 255, 255, 255},
    grabbox = {20, 255, 20, 255}, pushbox = {255, 0, 255, 255}, triggerbox = {255, 128, 0, 255},
    boundingbox = {255, 255, 255, 255},
}
CommonFunctions.default_substate = {dur = 1}
CommonFunctions.default_hitbox = {
    damage = {0, 0}, gain = {{0,0},{0,0}}, stamina = {0, 0}, hitstun = {0, 0}, hitstop = 10, juggle = 1, -- gain was tuple of tuples
    knockback = {grounded = {0, 0}}, hittype = {"medium", "middle"},
}
CommonFunctions.attack_type_value = {
    parry = {scaling = 10, min_scaling = 0}, block = {scaling = 10, min_scaling = 10},
    critical = {scaling = 10, min_scaling = 40}, super = {scaling = 10, min_scaling = 36},
    special = {scaling = 10, min_scaling = 16}, heavy = {scaling = 10, min_scaling = 14},
    medium = {scaling = 9, min_scaling = 12}, light = {scaling = 8, min_scaling = 10},
    no_match = {scaling = 8, min_scaling = 40},
}
CommonFunctions.dummy_json = {
    type = "projectile", palette = {}, scale = {1, 1}, gravity = 0, mass = 1, music = "", terminal_velocity = 1,
    gauges = {}, boxes = {
        hurtbox = {boxes = {}}, hitbox = {boxes = {}, hitset = 1}, takebox = {boxes = {}},
        grabbox = {boxes = {}}, pushbox = {boxes = {}}, triggerbox = {boxes = {}},
        boundingbox = {boxes = {{-75, 0, 150, 310}}, grounded_friction = 0.7},
    },
    offset = {0, 0}, timekill = false, trials = {}, states = {},
}

function CommonFunctions.nomatch(...) end

function CommonFunctions.gradient_color(value, max_value, color1_py, color2_py)
    local c1 = {(color1_py[1]), (color1_py[2]), (color1_py[3]), color1_py[4] or 255}
    local c2 = {(color2_py[1]), (color2_py[2]), (color2_py[3]), color2_py[4] or 255}
    if max_value == 0 then return {0,0,0,255} end
    value = math.max(0, math.min(value, max_value))
    local t = value / max_value
    return {
        math.floor(c1[1] + (c2[1] - c1[1]) * t), math.floor(c1[2] + (c2[2] - c1[2]) * t),
        math.floor(c1[3] + (c2[3] - c1[3]) * t), math.floor(c1[4] + (c2[4] - c1[4]) * t)
    }
end

function CommonFunctions.normalizar(valor, min_valor, max_valor)
    if (max_valor - min_valor) == 0 then return 0 end
    return (valor - min_valor) / (max_valor - min_valor)
end

function CommonFunctions.reescale(values, escale)
    local result = {}
    for _, v in ipairs(values) do table.insert(result, math.floor(v * escale + 0.5)) end
    return result
end

function CommonFunctions.RoundSign(n)
    if n > 0 then return 1 elseif n < 0 then return -1 else return 0 end
end

function CommonFunctions.weighted_choice(options_map)
    if not options_map or next(options_map) == nil then return nil end -- Handle empty or nil input
    local total_weight = 0; local choices = {}
    for val, data in pairs(options_map) do
        if type(data) ~= "table" or data.chance == nil then -- Handle cases where options_map might be a list of strings
            return options_map[math.random(#options_map)] -- Fallback to random choice from list if not weighted map
        end
        total_weight = total_weight + (data.chance or 0)
        table.insert(choices, {value = val, chance = data.chance or 0})
    end
    if total_weight == 0 then
        if #choices > 0 then return choices[math.random(#choices)].value end -- All chances are 0, pick one randomly
        return nil
    end
    local random_num = math.random() * total_weight; local current_weight = 0
    for _, choice_d in ipairs(choices) do
        current_weight = current_weight + choice_d.chance
        if random_num <= current_weight then return choice_d.value end
    end
    return choices[#choices] and choices[#choices].value or nil -- Fallback
end

function CommonFunctions.get_object_per_team(object_list, team, opposite, type_filter)
    type_filter = string.lower(type_filter or "character")
    for _, obj in ipairs(object_list or {}) do
        if obj.type_name == "BaseActiveObject" and obj.type == type_filter then
            if (opposite and obj.team ~= team) or (not opposite and obj.team == team) then return obj end
        end
    end
    return nil
end

function CommonFunctions.get_object_per_class(object_list, type_filter) -- In Lua, type_name is more akin to class name
    type_filter = string.lower(type_filter or "BaseActiveObject") -- Default to BaseActiveObject if no specific type given
    for _, obj in ipairs(object_list or {}) do
        if string.lower(obj.type_name or "") == type_filter then return obj end
    end
    return nil
end

function CommonFunctions.update_display_shake(obj_with_shake)
    if not obj_with_shake.draw_shake or #obj_with_shake.draw_shake < 6 then obj_with_shake.draw_shake = {0,0,0,0,0,0} return end
    local current_dur, total_dur = obj_with_shake.draw_shake[3], obj_with_shake.draw_shake[6]
    if current_dur >= total_dur then obj_with_shake.draw_shake = {0,0,0,0,0,0}; return end

    if total_dur ~= 0 then
        local mag_x, mag_y = obj_with_shake.draw_shake[4], obj_with_shake.draw_shake[5]
        local factor = (math.sin((current_dur % 3) / 3 * math.pi * 2) * math.abs(total_dur - current_dur)) / total_dur
        obj_with_shake.draw_shake[1] = mag_x * factor; obj_with_shake.draw_shake[2] = mag_y * factor
        obj_with_shake.draw_shake[3] = current_dur + 1
    end
end

function CommonFunctions.normalize_vector(x, y, base_length)
    base_length = base_length or 1; local mag = math.sqrt(x^2 + y^2)
    if mag == 0 then return {0, base_length} end
    return {x / mag * base_length, y / mag * base_length}
end

CommonFunctions.mirror_pad = {
    ["1"]="3",["3"]="1",["4"]="6",["6"]="4",["7"]="9",["9"]="7",["12"]="32",["13"]="31",["14"]="36",["15"]="35",["16"]="34",["17"]="39",["18"]="38",["19"]="37",
    ["21"]="23",["23"]="21",["24"]="26",["26"]="24",["27"]="29",["29"]="27",["31"]="13",["32"]="12",["34"]="16",["35"]="15",["36"]="14",["37"]="19",["38"]="18",["39"]="17",
    ["41"]="63",["42"]="62",["43"]="61",["45"]="65",["46"]="64",["47"]="69",["48"]="68",["49"]="67",["51"]="53",["53"]="51",["54"]="56",["56"]="54",["57"]="59",["59"]="57",
    ["61"]="43",["62"]="42",["63"]="41",["64"]="46",["65"]="45",["67"]="49",["68"]="48",["69"]="47",["71"]="93",["72"]="92",["73"]="91",["74"]="96",["75"]="95",["76"]="94",["78"]="98",["79"]="97",
    ["81"]="83",["83"]="81",["84"]="86",["86"]="84",["87"]="89",["89"]="87",["91"]="73",["92"]="72",["93"]="71",["94"]="76",["95"]="75",["96"]="74",["97"]="79",["98"]="78",
}

local function split_string(str, sep) local res={}; if str == nil then return res end; for p in string.gmatch(str, "([^"..sep.."]+)") do table.insert(res,p) end return res end
local function table_contains(tbl, val) if not tbl then return false end; for _,v in ipairs(tbl) do if v==val then return true end end return false end
CommonFunctions.table_contains = table_contains
local function table_intersection_check(t1, t2)
    if not t1 or not t2 then return false end; local s1={}; for _,v in ipairs(t1) do s1[v]=true end
    for _,v in ipairs(t2) do if s1[v] then return true end end; return false
end
CommonFunctions.table_intersection_check = table_intersection_check
local function merge_tables(base, override) local nt={}; for k,v in pairs(base or {}) do nt[k]=v end if override then for k,v in pairs(override) do nt[k]=v end end return nt end
CommonFunctions.merge_tables = merge_tables

function CommonFunctions.get_command(obj, current_inputs_list)
    local state_check_list = {obj.current_state, ((obj.boxes and obj.boxes.hurtbox and obj.boxes.hurtbox.crouch) and "crouch" or "stand"),
                              ((obj.gauges and obj.gauges.health and obj.gauges.health <= 0) and "defeated" or "alive")}
    for _,inp in ipairs(current_inputs_list or {}) do table.insert(state_check_list,inp) end

    for move_name, timer_data_list in pairs(obj.command_index_timer or {}) do
        for timer_idx=1, #timer_data_list do
            local progress_entry = timer_data_list[timer_idx]
            local current_progress = progress_entry[1]
            if progress_entry[2] == 0 and current_progress > 0 then current_progress = 0; progress_entry[1]=0 end

            local command_seq_def = obj.dict.states[move_name].command[timer_idx]
            if not command_seq_def then goto next_timer_entry end -- Skip if command definition missing for this index
            local current_gate_str = command_seq_def[current_progress + 1]

            if current_gate_str then
                local gate_parts = split_string(current_gate_str, ",")
                local matches = 0
                for _,part in ipairs(gate_parts) do
                    if string.find(part,"|") then if table_intersection_check(split_string(part,"|"), state_check_list) then matches=matches+1 end
                    elseif string.sub(part,1,1)=="!" then if not table_contains(state_check_list, string.sub(part,2)) then matches=matches+1 end
                    else if table_contains(state_check_list, part) then matches=matches+1 end
                    end
                end
                if matches >= #gate_parts then
                    progress_entry[1] = current_progress + 1
                    progress_entry[2] = obj.dict.states[move_name].command_link_time or 14
                    if progress_entry[1] >= #command_seq_def then
                        obj.buffer_state = obj.buffer_state or {}; obj.buffer_state[move_name] = obj.dict.states[move_name].buffer or 1
                        progress_entry[1]=0; progress_entry[2]=0
                    end
                end
            end
            ::next_timer_entry::
        end
    end
end

function CommonFunctions.get_state(obj, buffer, force)
    buffer = buffer or {}; local states_to_check = {}
    if obj.dict and obj.dict.states then for mn,_ in pairs(obj.dict.states) do if buffer[mn] then states_to_check[mn]=buffer[mn] end end end

    for move_name,_ in pairs(states_to_check) do
        local move_def = obj.dict.states[move_name]
        if not move_def then goto continue_move_check end

        local req_fet = move_def.state or {"grounded"}; if type(req_fet)=="string" then req_fet={req_fet} end
        local fet_ok = table_contains(req_fet, obj.fet)

        local cur_st_cancels = (obj.dict.states[obj.current_state] and obj.dict.states[obj.current_state].cancel) or {nil}
        local move_cancels = move_def.cancel or {nil}
        local no_cancel_from = move_def.no_cancel_states or {}

        -- obj.frame[1] is index from end of framedata (0 means last substate, #fd-1 means first)
        -- obj.frame[2] is duration left in current substate
        local is_first_frame_of_state = (obj.dict.states[obj.current_state] and obj.frame[1] == (#obj.dict.states[obj.current_state].framedata -1))

        local cancel_ok = ( (is_first_frame_of_state and obj.frame[2]==0 and table_contains(move_cancels, "neutral")) or
                           (table_contains(move_cancels, "kara") and obj.kara > 0 and not table_contains(cur_st_cancels, "kara")) or
                           table_intersection_check(obj.cancel or {nil}, move_cancels) ) and
                           (not table_contains(no_cancel_from, obj.current_state))

        local super_ok = (obj.gauges.super or 0) >= (move_def.bar_use or 0)

        if force or (fet_ok and cancel_ok and super_ok) then
            if move_def.bar_use and move_def.bar_use > 0 then obj.gauges.super = (obj.gauges.super or 0) - move_def.bar_use end
            obj.current_state = move_name
            obj.boxes = merge_tables(obj.dict.boxes)
            obj.frame = {#move_def.framedata - 1, 0} -- index from end, duration
            obj.kara = 2; obj.buffer_state = {}; obj.acceleration = {0,0}; obj.con_speed = {0,0}
            if string.find(move_name, "ummble") and obj.fet == "airborne" then obj.hitstun = -1 end
            obj.repeat_count = 0
            return obj.current_state
        end
        ::continue_move_check::
    end
    return false
end

function CommonFunctions.next_frame(obj, current_substate_data)
    local substate_data = merge_tables(CommonFunctions.default_substate, current_substate_data or {})

    if obj.frame[1] < 0 then obj.frame={-1,0}; return end

    obj.image_size = obj.dict.def_image_size or {100,100,0}
    obj.image_offset = obj.dict.def_image_offset or {0,0,0}
    obj.image_mirror = {false,false}; obj.image_tint = {255,255,255,255}; obj.image_angle = {0,0,0}
    obj.image_repeat = false; obj.image_glow = 0; obj.draw_textures = {}; obj.ignore_stop = false
    obj.hold_on_stun = false; obj.cancel = {nil}

    for func_name, val in pairs(substate_data) do
        if CommonFunctions.function_dict[func_name] then
            CommonFunctions.function_dict[func_name](obj, val, false)
        end
    end
    obj.frame[1] = obj.frame[1] - 1
end

CommonFunctions.object_kill = function(obj, ...) if obj.game and obj.game.object_list then for i,v in ipairs(obj.game.object_list) do if v==obj then table.remove(obj.game.object_list,i); return end end end end
CommonFunctions.object_remove_box_key = function(obj,key_info,...) if obj.boxes and obj.boxes[key_info[1]] then obj.boxes[key_info[1]][key_info[2]]=nil end end
CommonFunctions.object_hitset = function(obj, ...) obj.boxes = obj.boxes or {}; obj.boxes.hitbox = obj.boxes.hitbox or {}; obj.boxes.hitbox.hitset = ((obj.boxes.hitbox.hitset or 1) - 1) end
CommonFunctions.object_hit_damage = function(obj, dmg, other, ...)
    local scale = 100; if obj.self_main_object and obj.self_main_object.damage_scaling then scale = math.min(obj.self_main_object.damage_scaling[1], obj.self_main_object.damage_scaling[2]) end
    scale = scale / 100
    local type = (other.current_command and other.current_command[1]) or "hurt"
    local val = math.ceil(math.abs(type=="parry" and 0 or (type=="block" and dmg[2]*scale or dmg[1]*scale)))
    other.gauges.health = (other.gauges.health or 0)-val; other.last_damage = {(other.hitstun and other.hitstun>0 and (other.last_damage and other.last_damage[1] or 0) or 0)+val, val}
end
CommonFunctions.object_hit_hitgain = function(obj,gain,other,...)
    local type=(other.current_command and other.current_command[1]) or "hurt"; local gain_p = gain[1]; local gain_o = gain[2]
    obj.gauges.super=(obj.gauges.super or 0) + (type=="parry" and 0 or (type=="block" and gain_p[2] or gain_p[1]))
    other.gauges.super=(other.gauges.super or 0) + (type=="parry" and 8 or (type=="block" and gain_o[2] or gain_o[1]))
end
CommonFunctions.object_hit_stamina = function(obj,stm,other,...) local type=(other.current_command and other.current_command[1]) or "hurt"; other.gauges.stamina=(other.gauges.stamina or 0)+({parry=0,block=stm[2],hurt=stm[1]})[type] or 0 end
CommonFunctions.object_hit_hitstun = function(obj,stn,other,...) local type=(other.current_command and other.current_command[1]) or "hurt"; other.hitstun=({hurt=stn[1],block=stn[2],parry=0})[type] or 0 end
CommonFunctions.object_hit_hitstop = function(obj,stop,other,...)
    local is_parry = table_contains(other.current_command or {}, "parry")
    obj.hitstop = is_parry and 16 or stop; other.hitstop = is_parry and 16 or stop
    if CommonFunctions.object_display_shake then
        CommonFunctions.object_display_shake(other, {is_parry and 20*obj.face or other.speed[1], is_parry and 0 or other.speed[2], obj.hitstop, is_parry and "other" or "self"}, obj)
        for _,act_obj in ipairs(obj.game.object_list) do if act_obj.type_name=="Combo_Counter" and act_obj.parent==obj then CommonFunctions.object_display_shake(act_obj,{other.speed[1],other.speed[2],20,"self"},obj) end end
    end
end
CommonFunctions.object_hit_juggle = function(obj,jug,other,...) if other.fet=="airborne" then other.juggle = (other.juggle or 0) - math.floor(jug) end end
CommonFunctions.object_hit_knockback = function(obj,knk,other,...)
    local spd=knk.grounded or {14,0}
    if table_contains(other.current_command or {},"hurt") and knk.airborne and other.fet=="airborne" then spd=knk.airborne end
    if table_contains(other.current_command or {},"block") then spd=knk.block or {spd[1],0} end
    if table_contains(other.current_command or {},"parry") then spd=knk.parry or {0,0} end
    spd = {(spd[1]*obj.face)+((#spd>2) and obj.speed[1] or 0), spd[2]+((#spd>2) and obj.speed[2] or 0)}
    other.speed=spd; if spd[2]>0 and other.fet=="grounded" then other.fet="airborne" end
    if obj.self_main_object and other.pos and obj.self_main_object.pos then other.face = (obj.self_main_object.pos[1] > other.pos[1]) and -1 or 1 end
    other.pos[2]=other.pos[2]+(spd[2]>0 and other.fet=="grounded" and 10 or 0)
    if (other.gauges.health or 0)<=0 then spd[2]=20; other.fet="airborne" end
end
CommonFunctions.object_hit_hittype = function(obj,htype,other,...)
    local main_obj = obj.self_main_object
    local atk_type_key = "no_match"; for k,_ in pairs(CommonFunctions.attack_type_value) do if table_contains(htype,k) then atk_type_key=k; break end end
    if main_obj then
        main_obj.damage_scaling = main_obj.damage_scaling or {100,100}
        main_obj.damage_scaling[1] = (main_obj.damage_scaling[1] or 100) - CommonFunctions.attack_type_value[atk_type_key].scaling
        main_obj.damage_scaling[2] = CommonFunctions.attack_type_value[atk_type_key].min_scaling
    end
    other.frame={0,0}
    if (other.gauges.health or 0)<=0 then htype=merge_tables(htype,{"sidetummble"}) end
    if table_contains(other.current_command or {},"hurt") then other.current_command=merge_tables(other.current_command or {},htype); other.cancel={nil} end
end
CommonFunctions.object_wallbounce = function(obj,_,other,...) other.wallbounce=true end
CommonFunctions.object_duration = function(obj,d,...) obj.frame[2]=d end
CommonFunctions.object_image = function(obj,img_path,...) obj.image=img_path; if obj.game and obj.game.image_dict and obj.game.image_dict[img_path] then obj.real_image_size=obj.game.image_dict[img_path][2] else obj.real_image_size={100,100} end end
CommonFunctions.object_image_size=function(obj,s,...) obj.image_size=(#s==3) and s or {s[1],s[2],0} end
CommonFunctions.object_image_offset=function(obj,o,...) obj.image_offset=(#o==3) and o or {o[1],o[2],0} end
CommonFunctions.object_image_mirror=function(obj,m,...) obj.image_mirror=(#m==3) and m or {m[1],m[2],0} end
CommonFunctions.object_image_tint=function(obj,t,...) obj.image_tint=t end
CommonFunctions.object_image_angle=function(obj,a,...) obj.image_angle=a end
CommonFunctions.object_image_repeat=function(obj,r,...) obj.image_repeat=r end
CommonFunctions.object_image_glow=function(obj,g,...) obj.image_glow=g end
CommonFunctions.object_draw_textures=function(obj,dt,...) obj.draw_textures=dt end
CommonFunctions.object_display_shake=function(target_obj,shake_params,other_obj,...)
    local normalized_shake = CommonFunctions.normalize_vector(shake_params[1],shake_params[2],20)
    local who_to_shake; local game_obj = target_obj.game or (other_obj and other_obj.game)
    if shake_params[4]=="self" then who_to_shake = target_obj
    elseif shake_params[4]=="other" then who_to_shake = other_obj
    elseif shake_params[4]=="camera" and game_obj then who_to_shake = game_obj.camera
    end
    if who_to_shake then who_to_shake.draw_shake = {0,0,0,normalized_shake[1],normalized_shake[2],shake_params[3]} end
end
CommonFunctions.object_voice=function(obj,voice_data,...)
    local key_to_play = type(voice_data) == "string" and voice_data or CommonFunctions.weighted_choice(voice_data)
    local snd=obj.game.sound_dict[key_to_play]; if snd then snd:setLooping(false); love.audio.play(snd) end -- love.audio.play can take a Source object
end
CommonFunctions.object_sound=function(obj,sound_key,...) local snd=obj.game.sound_dict[sound_key]; if snd then snd:setLooping(false); love.audio.play(snd) end end
CommonFunctions.object_facing=function(obj,f,...) obj.face=obj.face*((type(f) == "number") and f or 1) end -- Ensure f is number
CommonFunctions.object_set_relative_pos=function(obj,p,other,...) other.pos={obj.pos[1]+p[1]*obj.face, obj.pos[2]+p[2],0} end
CommonFunctions.object_pos_offset=function(obj,po,...) obj.pos={obj.pos[1]+po[1]*obj.face, obj.pos[2]+po[2], obj.pos[3]} end
CommonFunctions.object_speed=function(obj,s,...) obj.speed={s[1]*obj.face,s[2]} end
CommonFunctions.object_acceleration=function(obj,a,...) obj.acceleration={a[1],a[2]} end
CommonFunctions.object_add_speed=function(obj,as,...) obj.speed={obj.speed[1]+as[1]*obj.face, obj.speed[2]+as[2]} end
CommonFunctions.object_con_speed=function(obj,cs,...) obj.con_speed={cs[1]*obj.face, cs[2]} end
CommonFunctions.object_cancel=function(obj,c,...) if type(c)=="string" then obj.cancel={c} else obj.cancel=c or {nil} end end
CommonFunctions.object_main_cancel=function(obj,c,...) if obj.self_main_object then if type(c)=="string" then obj.self_main_object.cancel={c} else obj.self_main_object.cancel=c or {nil} end end end
CommonFunctions.object_ignore_stop=function(obj,...) obj.ignore_stop=true end
CommonFunctions.object_hold_on_stun=function(obj,...) obj.hold_on_stun=true end
CommonFunctions.object_smear=function(obj,img_path,...) local c=obj.cancel; CommonFunctions.next_frame(obj,obj.dict.states[obj.current_state].framedata[#obj.dict.states[obj.current_state].framedata - obj.frame[1]]); obj.cancel=c end -- frame[1] is idx_from_end
CommonFunctions.object_gain=function(obj,g,...) obj.gauges.super=(obj.gauges.super or 0)+g end
CommonFunctions.object_superstop=function(obj,ss,...) for _,o in ipairs(obj.game.object_list) do if o.type_name=="BaseActiveObject" and table_contains({"projectile","character","stage"},o.type) then o.hitstop=(o.hitstop or 0)+ss end end end
CommonFunctions.object_camera_path=function(obj,cp,...) obj.game.camera_path={path=cp.path,object=cp.object}; obj.game.frame_camera_path={0,1} end
CommonFunctions.object_hurtbox=function(obj,hb,...) obj.boxes.hurtbox=merge_tables(obj.dict.boxes and obj.dict.boxes.hurtbox or {},hb) end
CommonFunctions.object_hitbox=function(obj,hb,...) obj.boxes.hitbox=merge_tables(obj.dict.boxes and obj.dict.boxes.hitbox or {},hb) end
CommonFunctions.object_grabbox=function(obj,gb,...) obj.boxes.grabbox=merge_tables(obj.dict.boxes and obj.dict.boxes.grabbox or {},gb) end
CommonFunctions.object_pushbox=function(obj,pb,...) obj.boxes.pushbox=merge_tables(obj.dict.boxes and obj.dict.boxes.pushbox or {},pb) end
CommonFunctions.object_takebox=function(obj,tb,...) obj.boxes.takebox=merge_tables(obj.dict.boxes and obj.dict.boxes.takebox or {},tb) end
CommonFunctions.object_triggerbox=function(obj,tb,...) obj.boxes.triggerbox=merge_tables(obj.dict.boxes and obj.dict.boxes.triggerbox or {},tb) end
CommonFunctions.object_boundingbox=function(obj,bb,...) obj.boxes.boundingbox=merge_tables(obj.dict.boxes and obj.dict.boxes.boundingbox or {},bb) end
CommonFunctions.object_boxes=function(...) end -- Placeholder, was pass in Python
CommonFunctions.object_update_box=function(obj,upd_box,...) for box_type,data in pairs(upd_box) do obj.boxes[box_type]=merge_tables(obj.boxes[box_type] or {}, data) end end
CommonFunctions.object_guard=function(...) end -- Placeholder, was pass in Python
CommonFunctions.object_repeat_substate=function(obj,rs,...) if (obj.repeat_count or 0)<rs[2] or rs[2]==-1 then obj.frame[1]=obj.frame[1]+rs[1]; obj.repeat_count=(obj.repeat_count or 0)+1 else obj.frame[2]=0 end end
CommonFunctions.object_get_state_from_frame_data=function(obj,command_list,...) -- Renamed to avoid conflict with main get_state
    command_list = command_list or {}; local combined_cmds = {}
    for _,c in ipairs(obj.current_command or {}) do table.insert(combined_cmds,c) end
    if obj.inputdevice and obj.inputdevice.current_input_processed then for _,c in ipairs(obj.inputdevice.current_input_processed) do table.insert(combined_cmds,c) end end
    for _,c in ipairs(command_list) do table.insert(combined_cmds,c) end
    CommonFunctions.get_command(obj, combined_cmds)
    local got_state = CommonFunctions.get_state(obj, obj.buffer_state)
    if got_state and obj.dict.states[obj.current_state] then
        local fd = obj.dict.states[obj.current_state].framedata
        local idx = #fd - obj.frame[1] -- obj.frame[1] is idx from end
        if fd[idx] then CommonFunctions.next_frame(obj, fd[idx]) end
    end
end
CommonFunctions.object_other_get_state=function(obj,cmd,other,...)
    local combined_cmds = {}; for _,c in ipairs(other.current_command or {}) do table.insert(combined_cmds,c) end
    if other.inputdevice and other.inputdevice.current_input_processed then for _,c in ipairs(other.inputdevice.current_input_processed) do table.insert(combined_cmds,c) end end
    table.insert(combined_cmds, obj.dict.name or "unknown_source_char"); table.insert(combined_cmds, obj.current_state)
    for _,c in ipairs(cmd or {}) do table.insert(combined_cmds,c) end
    CommonFunctions.get_command(other,combined_cmds)
    local got = CommonFunctions.get_state(other,other.buffer_state)
    if got and other.dict.states[other.current_state] then local fd=other.dict.states[other.current_state].framedata; local idx=#fd-other.frame[1]; if fd[idx] then CommonFunctions.next_frame(other,fd[idx]) end end
end
CommonFunctions.object_random_state=function(obj,rnd_state_map,...)
    local state_key = CommonFunctions.weighted_choice(rnd_state_map)
    if state_key and obj.dict.states[state_key] then
        obj.current_state=state_key; obj.boxes=merge_tables(obj.dict.boxes); obj.frame={#obj.dict.states[state_key].framedata-1,0}
        CommonFunctions.next_frame(obj, obj.dict.states[state_key].framedata[1])
    end
end
CommonFunctions.object_trigger_state=function(obj,state_key,...)
    if obj.dict.states[state_key] then
        obj.current_state=state_key; obj.boxes=merge_tables(obj.dict.boxes); obj.frame={#obj.dict.states[state_key].framedata-1,0}
        CommonFunctions.next_frame(obj, obj.dict.states[state_key].framedata[1])
    end
end
CommonFunctions.object_influence=function(obj,who,other,...)
    local game_obj_ref = obj.game
    if who=="other" then obj.influence_object=other; if other then other.grabed=obj; other.frame={0,0} end
    elseif who=="global" and game_obj_ref then obj.influence_object=other; if other then other.grabed=game_obj_ref end -- Assuming other is the one being influenced by game
    elseif who=="camera" and game_obj_ref and game_obj_ref.camera then obj.influence_object=other; if other then other.grabed=game_obj_ref.camera end
    end
end
CommonFunctions.object_influence_pos=function(obj,p,...) if obj.influence_object then obj.influence_object.pos={obj.pos[1]+p[1]*obj.face, obj.pos[2]-p[2],0} end end
CommonFunctions.object_influence_speed=function(obj,s,...) if obj.influence_object then obj.influence_object.speed={s[1]*obj.face, s[2]} end end
CommonFunctions.object_off_influence=function(obj,...) if obj.influence_object then if obj.influence_object.grabed==obj then obj.influence_object.grabed=nil end; obj.influence_object=nil end end
CommonFunctions.object_stop=function(obj,s,...) obj.hitstop=s end
CommonFunctions.object_create_object = function(obj, obj_list, ...)
    local BaseActiveObject = require("objects.base_active_object").BaseActiveObject
    for _, new_obj_def in ipairs(obj_list) do
        local dict_data = type(new_obj_def[1]) == "string" and obj.game.object_dict[new_obj_def[1]] or new_obj_def[1]
        if dict_data then
            table.insert(obj.game.object_list, BaseActiveObject:new({
                game=obj.game, dict=dict_data, pos={obj.pos[1]+new_obj_def[2][1]*obj.face, obj.pos[2]+new_obj_def[2][2]},
                face=obj.face*((new_obj_def[3] == 0 and 1) or new_obj_def[3] or 1), -- Ensure face is not 0
                inicial_state=new_obj_def[4], palette=new_obj_def[5] or 0, team=obj.team, parent=obj
            }))
        end
    end
end

CommonFunctions.function_dict = {
    remove_box_key=CommonFunctions.object_remove_box_key, hitset=CommonFunctions.object_hitset, damage=CommonFunctions.object_hit_damage,
    knockback=CommonFunctions.object_hit_knockback, hitstop=CommonFunctions.object_hit_hitstop, hitstun=CommonFunctions.object_hit_hitstun,
    stamina=CommonFunctions.object_hit_stamina, hit_bar_gain=CommonFunctions.object_hit_hitgain, hittype=CommonFunctions.object_hit_hittype,
    juggle=CommonFunctions.object_hit_juggle, wallbounce=CommonFunctions.object_wallbounce, dur=CommonFunctions.object_duration,
    image=CommonFunctions.object_image, image_size=CommonFunctions.object_image_size, image_offset=CommonFunctions.object_image_offset,
    image_mirror=CommonFunctions.object_image_mirror, image_tint=CommonFunctions.object_image_tint, image_angle=CommonFunctions.object_image_angle,
    image_repeat=CommonFunctions.object_image_repeat, image_glow=CommonFunctions.object_image_glow, draw_textures=CommonFunctions.object_draw_textures,
    draw_shake=CommonFunctions.object_display_shake, voice=CommonFunctions.object_voice, sound=CommonFunctions.object_sound,
    facing=CommonFunctions.object_facing, speed=CommonFunctions.object_speed, accel=CommonFunctions.object_acceleration,
    cancel=CommonFunctions.object_cancel, ignore_stop=CommonFunctions.object_ignore_stop, hold_on_stun=CommonFunctions.object_hold_on_stun,
    bar_gain=CommonFunctions.object_gain, superstop=CommonFunctions.object_superstop, camera_path=CommonFunctions.object_camera_path,
    hurtbox=CommonFunctions.object_hurtbox, hitbox=CommonFunctions.object_hitbox, grabbox=CommonFunctions.object_grabbox,
    pushbox=CommonFunctions.object_pushbox, takebox=CommonFunctions.object_takebox, triggerbox=CommonFunctions.object_triggerbox,
    boundingbox=CommonFunctions.object_boundingbox, update_box=CommonFunctions.object_update_box,
    repeat_substate=CommonFunctions.object_repeat_substate, get_state=CommonFunctions.object_get_state_from_frame_data, -- This is the one called by frame data
    stop=CommonFunctions.object_stop, create_object=CommonFunctions.object_create_object, kill=CommonFunctions.object_kill,
    light=CommonFunctions.nomatch, ambient=CommonFunctions.nomatch, music=CommonFunctions.nomatch, double_image=CommonFunctions.nomatch,
    set_relative_pos=CommonFunctions.object_set_relative_pos, pos_offset=CommonFunctions.object_pos_offset, add_speed=CommonFunctions.object_add_speed, con_speed=CommonFunctions.object_con_speed,
    main_cancel=CommonFunctions.object_main_cancel, guard=CommonFunctions.object_guard, smear=CommonFunctions.object_smear, boxes=CommonFunctions.object_boxes,
    influence=CommonFunctions.object_influence, influence_pos=CommonFunctions.object_influence_pos, influence_speed=CommonFunctions.object_influence_speed, off_influence=CommonFunctions.object_off_influence,
    other_get_state=CommonFunctions.object_other_get_state, trigg_state=CommonFunctions.object_trigger_state, random_state=CommonFunctions.object_random_state,
}

return CommonFunctions
