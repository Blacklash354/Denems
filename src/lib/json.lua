-- Minimal JSON encoder/decoder used for save files and settings.
local json = {}

local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
                  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k <= 0 or k % 1 ~= 0 then return false end
        n = n + 1
    end
    for i = 1, n do if t[i] == nil then return false end end
    return true, n
end

local function encode(v, out)
    local tv = type(v)
    if tv == "nil" then out[#out + 1] = "null"
    elseif tv == "boolean" then out[#out + 1] = v and "true" or "false"
    elseif tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then v = 0 end
        if v % 1 == 0 and math.abs(v) < 1e15 then out[#out + 1] = string.format("%d", v)
        else out[#out + 1] = string.format("%.6g", v) end
    elseif tv == "string" then
        out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c)
            return escapes[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif tv == "table" then
        local arr, n = isArray(v)
        if arr and n > 0 then
            out[#out + 1] = "["
            for i = 1, n do
                if i > 1 then out[#out + 1] = "," end
                encode(v[i], out)
            end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            local first = true
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = tostring(k) end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local val = v[k]
                if val == nil then val = v[tonumber(k)] end
                if not first then out[#out + 1] = "," end
                first = false
                encode(k, out)
                out[#out + 1] = ":"
                encode(val, out)
            end
            out[#out + 1] = "}"
        end
    else
        out[#out + 1] = "null"
    end
end

function json.encode(v)
    local out = {}
    encode(v, out)
    return table.concat(out)
end

local function skip(s, i)
    local _, e = s:find("^[ \n\r\t]*", i)
    return e + 1
end

local decodeValue

local function decodeString(s, i)
    local out = {}
    i = i + 1
    while true do
        local c = s:sub(i, i)
        if c == "" then error("unterminated string") end
        if c == '"' then return table.concat(out), i + 1 end
        if c == "\\" then
            local n = s:sub(i + 1, i + 1)
            local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
            if n == "u" then
                local code = tonumber(s:sub(i + 2, i + 5), 16) or 63
                out[#out + 1] = code < 128 and string.char(code) or "?"
                i = i + 6
            else
                out[#out + 1] = map[n] or n
                i = i + 2
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
end

function decodeValue(s, i)
    i = skip(s, i)
    local c = s:sub(i, i)
    if c == "{" then
        local t = {}
        i = skip(s, i + 1)
        if s:sub(i, i) == "}" then return t, i + 1 end
        while true do
            local k
            k, i = decodeString(s, skip(s, i))
            i = skip(s, i)
            if s:sub(i, i) ~= ":" then error("expected ':' at " .. i) end
            local v
            v, i = decodeValue(s, i + 1)
            t[k] = v
            i = skip(s, i)
            local d = s:sub(i, i)
            if d == "}" then return t, i + 1 end
            if d ~= "," then error("expected ',' at " .. i) end
            i = i + 1
        end
    elseif c == "[" then
        local t = {}
        i = skip(s, i + 1)
        if s:sub(i, i) == "]" then return t, i + 1 end
        while true do
            local v
            v, i = decodeValue(s, i)
            t[#t + 1] = v
            i = skip(s, i)
            local d = s:sub(i, i)
            if d == "]" then return t, i + 1 end
            if d ~= "," then error("expected ',' at " .. i) end
            i = i + 1
        end
    elseif c == '"' then
        return decodeString(s, i)
    elseif s:sub(i, i + 3) == "true" then return true, i + 4
    elseif s:sub(i, i + 4) == "false" then return false, i + 5
    elseif s:sub(i, i + 3) == "null" then return nil, i + 4
    else
        local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
        if not num or num == "" then error("unexpected char at " .. i) end
        return tonumber(num), i + #num
    end
end

function json.decode(s)
    local ok, v = pcall(decodeValue, s, 1)
    if ok then return v end
    return nil, v
end

return json
