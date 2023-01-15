--[[
    antiaim debugger.lua by nonterminal(fourm id:shriekz7)
    ads:
        欢迎加入 可以意见讨论/有诸多免费开源项目的 lua技术交流群 554181322 ！
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
        S
]]--

local vector = require 'vector'

local original_get = _G['ui']['get']

local render_pos = vector(300, 300)
local max_avg_tolerance = 1.4
local max_sample = 40 -- 请自行实验需要测试的way数的最佳数值
-- 以上两个数据纯粹为经验主义结果，不含有任何科学性

if max_sample % 2 == 1 then -- 给奇数会出一点bug 但是我也不知道怎么修了
    max_sample = max_sample - 1
end

local antiaim = {
    pitch = ui.reference("AA", "Anti-aimbot angles", "Pitch"),
    yaw_base = ui.reference("AA", "Anti-aimbot angles", "Yaw base"),
    yaw = { ui.reference("AA", "Anti-aimbot angles", "Yaw") },
    yaw_jitter = { ui.reference("AA", "Anti-aimbot angles", "Yaw jitter") } ,
    body_yaw = { ui.reference("AA", "Anti-aimbot angles", "Body yaw") },
    freestanding_body_yaw = ui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
    fake_yaw_limit = ui.reference("AA", "Anti-aimbot angles", "Fake yaw limit"),
    roll = ui.reference("AA", "Anti-aimbot angles", "Roll"),
    edge_yaw = ui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
    fakelag_mode = { ui.reference('AA', 'Fake Lag', 'Amount'), ui.reference('AA', 'Fake Lag', 'Variance'), ui.reference("AA", "Fake lag", "Limit")},
}

local traceback = {}

local analysis = ui.new_checkbox('lua', 'b', 'analysis data')
local prediction = ui.new_multiselect('lua', 'b', 'debug callback', {'paint_ui', 'setup_command', 'run_command', 'predict_command'})

local function ks_statistic(obs_one, obs_two)
    table.sort(obs_one, function(a, b)
        return a< b 
    end)
    table.sort(obs_two, function(a, b)
        return a< b 
    end)

    local i = 1
    local j = 1
    local d = 0.0
    local fn1 = 0.0
    local fn2 = 0.0

    local l1 = #obs_one
    local l2 = #obs_two

    while i < l1 and j < l2 do 
        local d1 = obs_one[i]
        local d2 = obs_two[j]
        if d1 <= d2 then 
            i = i + 1
            fn1 = i/l1
        end 

        if d2 <= d1 then 
            j = j + 1
            fn2 = j/l2 
        end 

        local dist = math.abs(fn2 - fn1)

        if dist > d then 
            d = dist 
        end
    end

    return d
end

local function get_switch(tbl)
    local switch = {}
    local count = {}
    local count_amt = 0

    for k, v in pairs(tbl) do
        if not count[v] then 
            count[v] = 1
            count_amt = count_amt + 1
        else 
            count[v] = count[v] + 1 
        end 
    end 

    local avg_amount = #tbl / count_amt

    for k, v in pairs(count) do 
        if v > avg_amount - max_avg_tolerance then 
            table.insert(switch, k)
        end 
    end 

    table.sort(switch, function(a, b)
        return a > b 
    end)

    return switch
end 

local function get_min_nd_max(tbl)
    local max = -math.huge
    local min = math.huge

    for k, v in pairs(tbl) do 
        max = math.max(v, max)
        min = math.min(v, min)
    end 

    return min, max
end 

local average = function(arg)
    local len = #arg
    local sum = 0

    for i = 1, len do
    sum = sum + arg[i]
    end

    return sum / len
end

local function is_static(tbl)
    local static = true 
    local avg = average(tbl)
    for k, v in pairs(tbl) do 
        if v ~= avg then 
            static = false 
        end 
    end 

    return static
end     

local function handle_ks_test(tbl)
    if type(tbl[1]) == 'number' then
        local tbl1, tbl2 = {}, {}
        for i = 1, max_sample/2 do 
            table.insert(tbl1, tbl[i])
        end 

        for i = max_sample/2 + 1, max_sample do
            table.insert(tbl2, tbl[i])
        end 

        return(ks_statistic(tbl1, tbl2))
    end
end 

local handler = function(idx)
    local meta = {}

    meta.cache = {
        paint_ui = {},
        setup_command = {},
        run_command = {},
        predict_command = {},
    }

    meta.data = {
        paint_ui = 0,
        setup_command = 0,
        run_command = 0,
        predict_command = 0
    }

    meta.idx = idx

    function meta:handle_cache(cache)
        local ks = handle_ks_test(cache)
        if ks then 
            if is_static(cache) then 
                return 'Static', cache[1]
            elseif ks > 0.101 then 
                local min, max = get_min_nd_max(cache) 
                return 'Random', {min, max}
            else 
                local switcher = get_switch(cache)
                return 'Switch', switcher
            end 
        end
    end 

    function meta:handle_callback(typ)
        return function(cmd)
            self.data[typ] = tostring(original_get(self.idx))
            if cmd then
                if cmd.chokedcommands == 0 then
                    table.insert(self.cache[typ], 1,  original_get(self.idx))
                end
            else 
                table.insert(self.cache[typ], 1,  original_get(self.idx))
            end

            if #self.cache[typ] > max_sample then
                for i = max_sample, #self.cache[typ] do 
                    self.cache[typ][i] = nil
                end 
            end 
        end
    end

    function meta:get_cache(name)
        local str = ''
        local mode, para = self:handle_cache(self.cache[name])
        if mode == 'Random' and ui.get(analysis) then 
            str = str .. 'Random:{' .. para[1] .. ',' .. para[2] .. '} '
        elseif mode == 'Switch' and ui.get(analysis) then 
            str = str .. #para .. 'Way Switch:{' 
            for k, v in pairs(para) do 
                if k ~= #para then 
                    str = str .. v .. ';'
                else 
                    str = str .. v
                end 
            end 
            str = str .. '} '
        else 
            str = str .. self.data[name] .. ' '
        end 

        return str
    end 

    function meta:get_str(_prediction)
        local str = ''
        if #_prediction == 1 then 
            str = str .. self:get_cache(_prediction[1])
        else 
            for k, v in pairs(_prediction) do 
                str = str .. v .. ':' .. self:get_cache(v) .. ' '
            end 
        end 

        return str
    end

    function meta:render_buffer(pos, _prediction)
        local r_name = ui.name(self.idx)
        local str = r_name == nil and 'Value' or r_name

        str = string.upper(str) .. ': [ '
        local res = self:get_str(_prediction)
        str = str .. self:get_str(_prediction)

        str = str .. ']'

        renderer.text(pos.x, pos.y, 255, 255, 255, 255, nil, 0, str)
    end

    for k, v in pairs(meta.data) do 
        client.set_event_callback(k, meta:handle_callback(k))
    end 
    
    return meta
end 

for k, v in pairs(antiaim) do 
    if type(v) == 'table' then 
        traceback[k] = {}
        for i, o in pairs(v) do 
            traceback[k][i] = handler(o)
        end 
    else 
        traceback[k] = handler(v)
    end 
end 

client.set_event_callback('paint', function()
    local y_add = 0
    for k, v in pairs(traceback) do 
        if type(antiaim[k]) == 'table' then 
            y_add = y_add + 12

            for i, o in pairs(v) do 
                o:render_buffer(render_pos + vector(0, y_add), ui.get(prediction))
                y_add = y_add + 12
            end 

            y_add = y_add + 12
        else
            v:render_buffer(render_pos + vector(0, y_add), ui.get(prediction))
            y_add = y_add + 12
        end 
    end 
end)
