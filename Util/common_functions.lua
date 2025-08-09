local M = {}

M.colors = {
    hurtbox = {20, 20, 255, 255},
    hitbox = {255, 20, 20, 255},
    takebox = {20, 255, 255, 255},
    grabbox = {20, 255, 20, 255},
    pushbox = {255, 0, 255, 255},
    triggerbox = {255, 128, 0, 255},
    boundingbox = {255, 255, 255, 255},
}

M.default_substate = {dur = 1}

M.default_hitbox = {
    damage = {0, 0},
    gain = {0, 0},
    stamina = {0, 0},
    hitstun = {0, 0},
    hitstop = 10,
    juggle = 1,
    knockback = {grounded = {0, 0}},
    hittype = {"medium", "middle"},
}

M.attack_type_value = {
    parry = {scaling = 10, min_scaling = 0},
    block = {scaling = 10, min_scaling = 10},
    critical = {scaling = 10, min_scaling = 40},
    super = {scaling = 10, min_scaling = 36},
    special = {scaling = 10, min_scaling = 16},
    heavy = {scaling = 10, min_scaling = 14},
    medium = {scaling = 9, min_scaling = 12},
    light = {scaling = 8, min_scaling = 10},
    no_match = {scaling = 8, min_scaling = 40},
}

M.dummy_json = {
    type = "projectile",
    palette = {},
    scale = {1, 1},
    gravity = 0,
    mass = 1,
    music = "",
    terminal_velocity = 1,
    gauges = {},
    boxes = {
        hurtbox = {boxes = {}},
        hitbox = {boxes = {}, hitset = 1},
        takebox = {boxes = {}},
        grabbox = {boxes = {}},
        pushbox = {boxes = {}},
        triggerbox = {boxes = {}},
        boundingbox = {boxes = {{-75, 0, 150, 310}}, grounded_friction = 0.7},
    },
    offset = {0, 0},
    timekill = false,
    trials = {},
    states = {},
}

function M.nomatch(...)
end

function M.gradient_color(value, max_value, color1, color2)
    if #color1 == 3 then table.insert(color1, 255) end
    if #color2 == 3 then table.insert(color2, 255) end
    if max_value == 0 then return {0, 0, 0} end

    value = math.max(0, math.min(value, max_value))
    local t = value / max_value
    local r = math.floor(color1[1] + (color2[1] - color1[1]) * t)
    local g = math.floor(color1[2] + (color2[2] - color1[2]) * t)
    local b = math.floor(color1[3] + (color2[3] - color1[3]) * t)
    local a = math.floor(color1[4] + (color2[4] - color1[4]) * t)
    return {r, g, b, a}
end

function M.normalizar(valor, min_valor, max_valor)
    return (valor - min_valor) / (max_valor - min_valor)
end

function M.reescale(values, escale)
    local result = {}
    for _, value in ipairs(values) do
        table.insert(result, math.floor(value * escale + 0.5)) -- round
    end
    return result
end

function M.RoundSign(n)
    if n > 0 then return 1
    elseif n < 0 then return -1
    else return 0
    end
end

function M.weighted_choice(options)
    local values = {}
    local probabilities = {}
    for k, v in pairs(options) do
        table.insert(values, k)
        table.insert(probabilities, v.chance)
    end

    local total_weight = 0
    for _, weight in ipairs(probabilities) do
        total_weight = total_weight + weight
    end

    if total_weight == 0 then return nil end

    local random_val = math.random() * total_weight
    local cumulative_weight = 0
    for i, weight in ipairs(probabilities) do
        cumulative_weight = cumulative_weight + weight
        if random_val <= cumulative_weight then
            return values[i]
        end
    end
end

-- ... (all other functions, making sure to use repeat_count and should_repeat correctly)

return M
