--[[
    experimental adaptive weapon fast builder.lua   

    @author:
        nonterminal (qq2152599380)

    @ads:
        想要学习/交流Lua知识,却苦于圈内大神过于高冷无人解答?
        我们致力于提供免费的持续更新的开源项目,Lua技术问题解答/交流
        加入我们的群聊:554181322，一切均不收费


    @MIT License:
    
        Copyright (c) 2023 nonterminal

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
]]

local ex_weapon = {}

local ui, unpack, string, pair, pairs, table, assert, loadstring, print, client, type, math, setmetatable, getmetatable, json, pcall, entity, require
local bit = require 'bit'

local refs = {
    fov = ui.reference("RAGE", "Aimbot", "Maximum FOV"),
    target_selection = ui.reference("RAGE", "Aimbot", "Target selection"),
    target_hitbox = ui.reference("RAGE", "Aimbot", "Target hitbox"),
    multipoint = {ui.reference("RAGE", "Aimbot", "Multi-point")},
    unsafe = ui.reference("RAGE", "Aimbot", "Avoid unsafe hitboxes"),
    multipoint_scale = ui.reference("RAGE", "Aimbot", "Multi-point scale"),
    prefer_safepoint = ui.reference("RAGE", "Aimbot", "Prefer safe point"),
    automatic_fire = ui.reference("RAGE", "Aimbot", "Automatic fire"),
    automatic_penetration = ui.reference("RAGE", "Aimbot", "Automatic penetration"),
    silent_aim = ui.reference("RAGE", "Aimbot", "Silent aim"),
    hitchance = ui.reference("RAGE", "Aimbot", "Minimum hit chance"),
    mindamage = ui.reference("RAGE", "Aimbot", "Minimum damage"),
    automatic_scope = ui.reference("RAGE", "Aimbot", "Automatic scope"),
    reduce_aimstep = ui.reference("RAGE", "Aimbot", "Reduce aim step"),
    low_fps_mitigations = ui.reference("RAGE", "Aimbot", "Low FPS mitigations"),
    remove_recoil = ui.reference("RAGE", "Other", "Remove recoil"),
    accuracy_boost = ui.reference("RAGE", "Other", "Accuracy boost"),
    delay_shot = ui.reference("RAGE", "Other", "Delay shot"),
    quickstop = {ui.reference("RAGE", "Other", "Quick stop")},
    quickstop_options = ui.reference("RAGE", "Other", "Quick stop options"),
    prefer_bodyaim = ui.reference("RAGE", "Other", "Prefer body aim"),
    prefer_bodyaim_disablers = ui.reference("RAGE", "Other", "Prefer body aim disablers"),
    doubletap_hc = ui.reference("RAGE", "Other", "Double tap hit chance"),
    doubletap_stop = ui.reference("RAGE", "Other", "Double tap quick stop"),
    doubletap = { ui.reference('rage', 'Other', 'Double tap')},
}

-- weapon determination from @sigma adaptive

    local name_to_num = { ["Global"] = 1, ["Taser"] = 2, ["Revolver"] = 3, ["Pistol"] = 4, ["Auto"] = 5, ["Scout"] = 6, ["AWP"] = 7, ["Rifle"] = 8, ["SMG"] = 9, ["Shotgun"] = 10, ["Deagle"] = 11 }
    local weapon_idx_list = { [1] = 11, [2] = 4,[3] = 4,[4] = 4,[7] = 8,[8] = 8,[9] = 7,[10] = 8,[11] = 5,[13] = 8,[14] = 8,[16] = 8,[17] = 9,[19] = 9,[23] = 9,[24] = 9,[25] = 10,[26] = 9,[27] = 10,[28] = 8,[29] = 10,[30] = 4,[31] = 2,  [32] = 4,[33] = 9,[34] = 9,[35] = 10,[36] = 4,[38] = 5,[39] = 8,[40] = 6,[60] = 8,[61] = 4,[63] = 4,[64] = 3}
    local damage_idx = { [0] = "Auto", [101] = "HP + 1", [102] = "HP + 2", [103] = "HP + 3", [104] = "HP + 4", [105] = "HP + 5", [106] = "HP + 6", [107] = "HP + 7", [108] = "HP + 8", [109] = "HP + 9", [110] = "HP + 10", [111] = "HP + 11", [112] = "HP + 12", [113] = "HP + 13", [114] = "HP + 14", [115] = "HP + 15", [116] = "HP + 16", [117] = "HP + 17", [118] = "HP + 18", [119] = "HP + 19", [120] = "HP + 20", [121] = "HP + 21", [122] = "HP + 22", [123] = "HP + 23", [124] = "HP + 24", [125] = "HP + 25", [126] = "HP + 26" }
    local weapon_name = { "Global", "Taser", "Revolver", "Pistol", "Auto", "Scout", "AWP", "Rifle", "SMG", "Shotgun", "Deagle" }
    local function get_weapon_idx()
        local local_player = entity.get_local_player()
        if local_player == nil then return nil end
        local weapon_ent = entity.get_player_weapon(local_player)
        if weapon_ent == nil then return nil end
        local weapon_idx = bit.band(entity.get_prop(weapon_ent, "m_iItemDefinitionIndex"), 0xFFFF)
        if weapon_idx == nil then return nil end
        local get_idx = weapon_idx_list[weapon_idx] ~= nil and weapon_idx_list[weapon_idx] or 1
        return get_idx
    end

--

local AIMBOT = {'RAGE', 'Aimbot'}
local OTHER = {'RAGE', 'Other'}

local weapon_switch    = ui.new_checkbox(AIMBOT[1], AIMBOT[2], 'Enable Experimental Weapon Builder')
local weapon_selection = ui.new_combobox(AIMBOT[1], AIMBOT[2], 'Weapon Selection', weapon_name)

local __init = {
    ['new_checkbox'] = {
        { refs.prefer_safepoint, nil, AIMBOT},
        { refs.automatic_fire, nil, AIMBOT} ,
        { refs.automatic_penetration, nil, AIMBOT},
        { refs.silent_aim, nil, AIMBOT},
        { refs.reduce_aimstep, nil, AIMBOT},
        { refs.delay_shot, nil, OTHER},
        { refs.quickstop[1], nil, OTHER},
        { refs.prefer_bodyaim, nil, OTHER},
    },
    ['new_slider'] = {
        { refs.fov, {1, 180, 180, true, "°", 1}, AIMBOT}, 
        { refs.multipoint_scale, {24, 100, 60, true, "%", 1, { [24] = "Auto" }}, AIMBOT},
        { refs.hitchance, {0, 100, 60, true, "%", 1, { [0] = "Off" }}, AIMBOT},
        { refs.mindamage, {0, 126, 60, true, nil, 1, damage_idx}, AIMBOT},
        { refs.doubletap_hc, {0, 100, 0, true, "%", 1}, OTHER}
    },
    ['new_combobox'] = {
        { refs.target_selection, {"Cycle", "Cycle (2x)", "Near crosshair", "Highest damage", "Lowest ping", "Best K/D ratio", "Best hit chance"}, AIMBOT},
        { refs.accuracy_boost, {'Low', 'Medium', 'High', 'Maximum'}, OTHER},
    },
    ['new_multiselect'] = {
        { refs.target_hitbox, { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" }, AIMBOT },
        { refs.multipoint[1], { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" }, AIMBOT },
        { refs.unsafe, { "Head", "Chest", "Arms", "Stomach", "Legs", "Feet" }, AIMBOT },
        { refs.low_fps_mitigations, {'Force low accuracy boost','Disable multipoint: feet','Disable multipoint: arms','Disable multipoint: legs','Disable hitbox: feet','Lower hit chance precision','Limit targets per tick'}, AIMBOT},
        { refs.quickstop_options, {'Early','Slow motion','Duck','Fake duck','Move between shots','Ignore molotov','Taser'}, OTHER },
        { refs.prefer_bodyaim_disablers, {"Low inaccuracy", "Target shot fired", "Target resolved", "Safe point headshot"}, OTHER },
        { refs.doubletap_stop, { "Slow motion", "Duck", "Move between shots" }, OTHER },
    }
}

local function clone(object, deep)
    local copy = {}
    for k, v in pairs(object) do
        if deep and type(v) == "table" then
            v = clone(v, deep)
        end
        copy[k] = v
    end

    return setmetatable(copy, getmetatable(object))
end

local pather = function(tbl, var)
    for k, v in pairs(tbl) do 
        if v == var then 
            return true 
        end 
    end

    return false
end 

local contains = function(table, value)
    for i = 0, #table do
       if table[i] == value then
          return true
       end
    end

    return false
end

local compare_max = function(tbl)
    local max_value = 0
    for i = 1, #tbl do 
        local priority = tbl[i].priority
        max_value = math.max(priority, max_value)
    end

    return max_value
end

local str_to_func = function(str)
    return assert(loadstring(str))
end

local kill_same_priority = function(tbl, priority) 
    local illegal = {}
    local to_search
    for k, v in pairs(tbl) do 
        if v.priority == priority then 
            to_search = 1
            table.insert(illegal, tbl[k])
        elseif v.priority > priority then 
            table.insert(illegal, tbl[k])
        end
    end 

    if to_search then 
        for i = 1, #illegal do 
            illegal[i].priority = illegal[i].priority + 1
        end
    end
end

ex_weapon.relevant = {}

ex_weapon.__builder = function(name, ref)

    local origin_name = ui.name(ref)
    local cache = ui.new_string('__wpwp__' .. name)

    local state = ui.new_string('__wpwp__' .. name .. 'state')
    ui.set(state, 'Global/default') -- init

    local parameter, func, loc
    local lists, configs, existed = {}, {}, {}

    local function creater(E, ...)
        local single = {}

        local names = origin_name
        if E then 
            names = '[' .. E .. '] ' .. names
        end 
        
        local loc_1, loc_2 = unpack(loc)

        for k, v in pairs(weapon_name) do 
            if not lists[v] then lists[v] = {} end 
            local created = ui[func](loc_1, loc_2, names .. '\n' .. v, ...)

            table.insert(lists[v], created)
            table.insert(single, created)
        end

        return single
    end

    for i, o in pairs(__init) do 
        for k, v in pairs(o) do 
            if ref == v[1] then 
                parameter = v[2]
                func = i
                loc = v[3]
            end
        end 
    end

    if not parameter and func ~= 'new_checkbox' then 
        return
    end

    if func == 'new_checkbox' then
        creater(nil)
    else 
        creater(nil, unpack(parameter))
    end
    
    local function add_logic(logic_name, priority, paper, created)
        local max_priority = compare_max(configs)
        kill_same_priority(configs, priority)

        if priority > max_priority then 
            priority = max_priority + 1
        end

        table.insert(configs, {name = logic_name, func = paper, ref = created, priority = priority})
        table.insert(existed, logic_name)
    end

    local function new_logic(logic_name, priority, paper)
        if pather(existed, logic_name) or logic_name == 'default' then 
            print('[error] logic name existed'); return
        end

        if type(paper) == 'function' then 
            local new_create
            if func == 'new_checkbox' then
                new_create = creater(logic_name)
            else 
                new_create = creater(logic_name, unpack(parameter))
            end

            add_logic(logic_name, paper, priority, new_create)
        elseif type(paper) == 'string' then
            if pcall(str_to_func, paper) then 
                local new_create
                if func == 'new_checkbox' then
                    new_create = creater(logic_name)
                else 
                    new_create = creater(logic_name, unpack(parameter))
                end

                add_logic(logic_name, str_to_func(paper), priority, new_create)
            else 
                print('[error] illegal function')
            end
        else
            print('[error] illegal type')
        end
    end

    local function delete_logic(logic_name, renewing)
        local illegal = {}
        local to_search
        for k, v in pairs(configs) do 
            if v.name == logic_name then 
                to_search = v.priority

                table.remove(configs, k)
            end
        end 
    
        if to_search then 
            for k, v in pairs(configs) do 
                if v.priority > to_search then 
                    configs[k].priority = configs[k].priority - 1
                end 
            end 
        elseif not to_search and not renewing then 
            print('[error] cant find logic ', logic_name)
        end
    end

    local function renew_priority(logic_name, new_priority)
        local pathe
        for k,v in pairs(configs) do 
            if v.name == logic_name then 
                pathe = configs[k]
            end
        end 

        if not pathe then 
            print('[error] cant find logic ', logic_name); return
        end

        local old_priority = clone(pathe, true)

        delete_logic(logic_name)

        add_logic(logic_name, new_priority, old_priority.func, old_priority.ref)
    end

    local function list_logic()
        print('listing ' .. origin_name .. ' logic')
        local configs_copy = clone(configs, true)
        table.sort(configs_copy, function(a, b) return a.priority > b.priority end)
        for k, v in pairs(configs_copy) do 
            print('priority: ', v.priority, ' name: ', v.name)
        end 
    end

    local function get_logic_refs(logic_name)
        if logic_name == 'default' then 
            return lists
        else 
            for k=1, #configs do 
                if configs[k].name == logic_name then 
                    return configs[k].ref 
                end
            end
        end
    end

    local function callback(val)
        local resort = json.parse(val)
        local weapon, logic = resort[1], resort[2]
        local weapon_ref = get_logic_refs(logic)[weapon]

        ui.set(ref, ui.get(weapon_ref))
    end

    client.delay_call(0.3, function()
        local allextra_modes = {}

        local update_ui = {}

        for k, v in pairs(configs) do 
            table.insert(allextra_modes, v.name)
        end

        for k, v in pairs(weapon_name) do
            local uix = ui.new_multiselect('RAGE', 'Other', origin_name ..' Tweaks' .. '\n' .. v, allextra_modes)
            local parsed = json.parse(ui.get(cache))
            if parsed and parsed[v] then
                ui.set(uix, parsed[v])
            end

            table.insert(update_ui, uix)

            ui.set_callback(uix, function(val)
                local to_str = json.parse(ui.get(cache))
                if not to_str[v] then 
                    to_str[v] = ''
                end

                to_str[v] = json.stringify(val)

                ui.set(cache, json.stringify(to_str))

                for i, o in pairs(configs) do 
                    if not contains(ui.get(uix), o.name) then  
                        ui.set_visible(o.ref[k], false)
                    end
                end
            end)

            local weapon_name = ui.get(weapon_selection)

            if v ~= weapon_name then 
                ui.set_visible(uix, false) 
            end
        end

        ex_weapon.relevant[name].update = update_ui
    end)

    ex_weapon.relevant[name] = {
        ui_cache = cache,
        ui_list = lists,
        ui_state = state,
        configs = configs,
        new_logic = new_logic,
        list_logic = list_logic,
        renew_priority = renew_priority,
        delete_logic = delete_logic,
        get_logic_refs = get_logic_refs,
        callback = callback,
        update = {}
    }
end

for k, v in pairs(refs) do 
    if type(v) == 'table' then 
        for i, o in pairs(v) do 
            ex_weapon.__builder(k .. '['..i..']', o)
        end
    else 
        ex_weapon.__builder(k, v)
    end
end 

local function search(ref_name)
    return ex_weapon.relevant[ref_name]
end 

local init_func = function(val)
    if val then 
        for k, v in pairs(refs) do 
            if type(v) == 'table' then 
                for i, o in pairs(v) do 
                    local ref = search(k .. '['..i..']')
                    ui.set_callback(ref.ui_state, ref.callback)
                end
            else 
                local ref = search(k)
                ui.set_callback(ref.ui_state, ref.callback)
            end
        end
    else 
        for k, v in pairs(refs) do 
            if type(v) == 'table' then 
                for i, o in pairs(v) do 
                    local ref = search(k .. '['..i..']')
                    ui.set_callback(ref.ui_state, function() end)
                end
            else 
                local ref = search(k)
                ui.set_callback(ref.ui_state, function() end)
            end
        end
    end
end

local collect_uis = function(val, ref)
    local ui_visible, ui_invisible = {}, {}

    for k, v in pairs(ref.lists) do
        if k == val then
            table.insert(ui_visible, v)
        else 
            table.insert(ui_invisible, v)
        end
    end

    for k, v in pairs(ref.configs) do 
        for i, o in pairs(v.ref) do 
            if i == val then
                table.insert(ui_visible, o)
            else 
                table.insert(ui_invisible, o)
            end
        end
    end 

    for k, v in pairs(ref.update) do 
        if k == val then
            table.insert(ui_visible, v)
        else 
            table.insert(ui_invisible, v)
        end
    end

    for k, v in pairs(ui_visible) do 
        ui.set_visible(v, true)
    end 

    for k, v in pairs(ui_invisible) do 
        ui.set_visible(v, false)
    end
end

local update_func = function(val)
    for k, v in pairs(refs) do 
        if type(v) == 'table' then 
            for i, o in pairs(v) do 
                local ref = search(k .. '['..i..']')
                collect_uis(ref)
            end
        else 
            local ref = search(k)
            collect_uis(ref)
        end
    end
end

init_func()
update_func()
ui.set_callback(weapon_switch, init_func)
ui.set_callback(weapon_selection, update_func)

local renew_state = function(e, prefer)
    local modes = clone(prefer.configs, true)
    table.sort(modes, function(a, b) 
        return a.priority > b.priority 
    end)

    local state = ui.get(prefer.ui_state)

    local resort = json.parse(state)
    local weapon, logic = resort[1], resort[2]

    if #modes ~= 0 then
        for idx = 1, #modes do
            local mode = modes[idx]
            local mode_should_run = mode.func(e) and contains(ui.get(prefer.update[weapon]), mode.name)
            if mode_should_run and logic ~= mode.name and weapon_name ~= weapon then 
                ui.set(state, json.stringify({weapon_name, mode.name}))
            elseif mode_should_run and logic ~= mode.name then 
                ui.set(state, json.stringify({weapon, mode.name}))
            elseif weapon_name ~= weapon then 
                ui.set(state, json.stringify({weapon_name, logic}))
            end
        end
    else 
        if weapon_name ~= weapon then 
            ui.set(state, weapon_name .. '/' .. 'default')
        end
    end
end

client.set_event_callback("setup_command", function(e)
    local weapon_name = weapon_idx_list[get_weapon_idx()]

    for k, v in pairs(refs) do 
        if type(v) == 'table' then 
            for i, o in pairs(v) do 
                renew_state(e, search(k .. '['..i..']'))
                ui.set_visible(o, false)
            end
        else 
            renew_state(e, search(k))
            ui.set_visible(v, false)
        end
    end
end)

-- 在这里创建你的功能
    -- example:
        local hitchance = search('hitchance')

        hitchance.new_logic('in_air', 1, function()
            return bit.band(entity.get_prop(entity.get_local_player(), 'm_fFlags'), 1) == 1
        end) -- 新建一个逻辑层 名:in_air 逻辑:本地玩家在空中运行 优先级为最高

        hitchance.list_logic() -- 查询hitchance的所有逻辑

        hitchance.renew_priority('in_air', 5) -- 将in_air逻辑层的优先级设为5

        hitchance.delete_logic('in_air') -- 删除in_air逻辑层

        local dmg_on_key = ui.new_hotkey('override damage on key', false, 0x00)
        local damage = search('damage')

        damage.new_logic('on_key', 1, function()
            return ui.get(dmg_on_key)
        end) -- 创建一个优先级最高的伤害覆盖逻辑层
-- 
