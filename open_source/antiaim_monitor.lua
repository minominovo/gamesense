--[[
    antiaim monitor.lua by nonterminal(fourm id:shriekz7)

    ads:
        欢迎加入 可以意见讨论/有诸多免费且开源项目的 lua技术交流群 554181322 ！

    MIT License:
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


local antiaim = require "gamesense/antiaim_funcs" 
local ent = require "gamesense/entity"

local ui_set_callback = ui.set_callback

function ui.set_callback(callback, func, init, ...)
    if init then
        func(...)
    end

    ui_set_callback(callback, func, ...)
end

local main_switch = ui.new_checkbox('lua', 'b', 'antiaim monitor')
local sample_amount = ui.new_slider('lua', 'b', 'sample amount', 50, 500, 100)
local accuarcy = ui.new_slider('lua', 'b', 'accuracy', 10, 100, 10)

local _playerlist = {}

local function collect_players()
    local list = {}
    local player_resource = entity.get_player_resource()
    for i = 1, globals.maxplayers() do
        if entity.get_prop(player_resource, "m_bConnected", i) == 1 then
            list[#list+1] = i
        end
    end

    return list
end

local function round(number) 
    if (number - (number % 0.1)) - (number - (number % 1)) < 0.5 then 
        number = number - (number % 1) 
    else 
        number = (number - (number % 1)) + 1 
    end 
    return number 
end

local normalize_yaw = function(ang)
    while (ang > 180.0) do
        ang = ang - 360.0
    end
    while (ang < -180.0) do
        ang = ang + 360.0
    end
    return ang
end

local function tbl_to_quantity_tbl(tbl)
    local quantity = {}

    for i, o in pairs(tbl) do 
        if not quantity[o] then 
            quantity[o] = 1 
        else 
            quantity[o] = quantity[o] + 1
        end 
    end 

    return quantity
end

local function valid_quantity_values(tbl, accuracy)
    local quantity_tbl = tbl_to_quantity_tbl(tbl)
    local valid_tbl = {}
    local sample_size = #tbl

    for k, v in pairs(quantity_tbl) do 
        if v > sample_size * (accuracy-0.1) / 100 then 
            table.insert(valid_tbl, k)
        end 
    end 

    return valid_tbl
end 

local function override_unexisted_value(tbl, solved_tbl)
    for _, v in pairs(solved_tbl) do 
        if not tbl[v] then 
            tbl[v] = 1
        end
    end 

    return tbl
end

local pairs_amount = function(tbl)
    local amt = 0
    for k, v in pairs(tbl) do 
        amt = amt + 1
    end

    return amt
end

local tbl_to_str = function(tbl)
    local str = ''
    local amt = 0
    for k, v in pairs(tbl) do 
        amt = amt + 1
        if amt ~= pairs_amount(tbl) then 
            str = str .. k .. ';'
        else 
            str = str .. k
        end 
    end

    return str
end 

local function _builder(p_idx)
    local player_name = entity.get_player_name(p_idx)
    
    if _playerlist[player_name] or player_name == 'unknown' or player_name == 'GOTV' then 
        return 
    end 

    local meta = {}
    meta.idx = p_idx

    meta.ui_list = {
        [1] = ui.new_label('lua', 'b', '| player: ' .. player_name),
        [2] = ui.new_label('lua', 'b', 'angle: '),
        [3] = ui.new_label('lua', 'b', 'jitter: '),
        [4] = ui.new_label('lua', 'b', 'odds: '),
        [5] = ui.new_label('lua', 'b', '\n')
    }

    meta.jitter_cache = {}
    meta.main_jitter = {}

    function meta:get_current_angle()
        local ents = ent.new(self.idx)
        local anim_state = ents:get_anim_state()
        local views = anim_state.eye_angles_y

        return entity.get_local_player() == self.idx and antiaim.get_abs_yaw() or views
    end

    function meta:callback()
        if entity.is_alive(self.idx) == false then 
            return 
        end 

        local real_offset = meta:get_current_angle()
        if not self.last_angle then 
            self.last_angle = real_offset 
        end 

        ui.set(meta.ui_list[1], '| player: ' .. player_name .. '   [' .. self.idx .. ']')
        ui.set(meta.ui_list[2], 'angle: ' .. round(meta:get_current_angle()))
        local differ = normalize_yaw(real_offset - self.last_angle)

        if differ ~= 0 then 
            local result = round(math.abs(differ))
            ui.set(meta.ui_list[3], 'jitter: ' .. result)

            if result ~= 0 then 
                table.insert(self.jitter_cache, 1, result)
            end
        end 

        self.last_angle = real_offset

        if #self.jitter_cache > ui.get(sample_amount) then 
            for i = ui.get(sample_amount) + 1, #self.jitter_cache do 
                self.jitter_cache[i] = nil
            end 
        end

        self.main_jitter = override_unexisted_value(self.main_jitter, valid_quantity_values(self.jitter_cache, ui.get(accuarcy)))

        ui.set(meta.ui_list[4], 'odds: ' .. tbl_to_str(self.main_jitter))
    end

    meta.recall = function()
        meta:callback()
    end

    function meta:set_visible(t)
        for k, v in pairs(self.ui_list) do 
            ui.set_visible(v, t)
        end
    end

    function meta:destroy()
        self:set_visible(false)

        client.unset_event_callback('net_update_end', self.recall)
    end

    client.set_event_callback('net_update_end', meta.recall)

    _playerlist[player_name] = meta
end 

local function commands()
    local players = collect_players()
    local names = {}

    for _, player in pairs(players) do 
        _builder(player)

        names[entity.get_player_name(player)] = 1
    end 

    for idx, meta in pairs(_playerlist) do
        if not names[idx] then 
            meta:destroy()
            _playerlist[idx] = nil
        end
    end
end

local funcs = {
    [true] = client.set_event_callback,
    [false] = client.unset_event_callback
}

ui.set_callback(main_switch, function()
    local swh = ui.get(main_switch)
    funcs[swh]('setup_command', commands)

    ui.set_visible(sample_amount, swh)
    ui.set_visible(accuarcy, swh)

    for _, meta in pairs(_playerlist) do
        meta:set_visible(swh)
    end 
end, true)
