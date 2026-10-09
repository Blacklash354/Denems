-- Wavefront .obj loader: returns the file's objects as flat vertex arrays
-- (12 numbers per vertex: position, uv, normal, white colour), triangulated.
local Obj = {}

function Obj.load(path)
    local text = assert(love.filesystem.read(path), "missing model " .. path)
    local V, VT, VN = {}, {}, {}
    local objects, cur = {}, nil
    local function corner(spec, out)
        local vi, ti, ni = spec:match("^(-?%d+)/?(-?%d*)/?(-?%d*)")
        vi, ti, ni = tonumber(vi), tonumber(ti), tonumber(ni)
        local p = V[vi < 0 and #V + 1 + vi or vi]
        local t = ti and VT[ti < 0 and #VT + 1 + ti or ti]
        local n = ni and VN[ni < 0 and #VN + 1 + ni or ni]
        local k = #out
        out[k + 1], out[k + 2], out[k + 3] = p[1], p[2], p[3]
        out[k + 4], out[k + 5] = t and t[1] or 0, t and 1 - t[2] or 0
        out[k + 6], out[k + 7], out[k + 8] = n and n[1] or 0, n and n[2] or 1, n and n[3] or 0
        out[k + 9], out[k + 10], out[k + 11], out[k + 12] = 1, 1, 1, 1
    end
    for line in text:gmatch("[^\r\n]+") do
        local kind, rest = line:match("^(%S+)%s+(.*)$")
        if kind == "v" or kind == "vn" or kind == "vt" then
            local a, b, c = rest:match("(%S+)%s+(%S+)%s*(%S*)")
            local t = { tonumber(a), tonumber(b), tonumber(c) or 0 }
            if kind == "v" then V[#V + 1] = t elseif kind == "vn" then VN[#VN + 1] = t else VT[#VT + 1] = t end
        elseif kind == "o" or kind == "g" then
            cur = { name = rest, verts = {} }
            objects[rest] = cur
        elseif kind == "f" then
            if not cur then cur = { name = "default", verts = {} } objects.default = cur end
            local specs = {}
            for s in rest:gmatch("%S+") do specs[#specs + 1] = s end
            for i = 2, #specs - 1 do
                corner(specs[1], cur.verts) corner(specs[i], cur.verts) corner(specs[i + 1], cur.verts)
            end
        end
    end
    return objects
end

-- emit named objects into a meshbuilder: (v - origin) * scale, textured with the builder's material
function Obj.emit(mb, objects, names, scale, ox, oy, oz)
    local t = {}
    for _, name in ipairs(names) do
        local o = assert(objects[name], "no object " .. name)
        local v = o.verts
        for k = 0, #v - 12, 12 do
            t[1], t[2], t[3] = (v[k + 1] - ox) * scale, (v[k + 2] - oy) * scale, (v[k + 3] - oz) * scale
            for c = 4, 12 do t[c] = v[k + c] end
            mb:vertex(t)
        end
    end
end

return Obj
