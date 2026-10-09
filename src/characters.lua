-- People from assets/characters_psx.glb. The file holds static one-piece figures in an A-pose;
-- each is cut into rigid parts (torso, head, arms, thighs, shins) around the joints of the
-- procedural rig in humans.lua, so the existing walk / sit / aim / death poses drive them.
local Gltf = require("src.engine.gltf")
local MB = require("src.engine.meshbuilder")

local Ch = { cache = {} }

Ch.FILE = "assets/characters_psx.glb"
Ch.HEIGHT = 1.78

-- who wears what
Ch.LOOKS = {
    loner = { "Character_01", "Character_03", "Character_05", "Character_08", "Character_11", "Character_14", "Character_16", "Character_29" },
    bandit = { "Character_Killer", "Character_Killer_01", "Character_Killer_02", "Character_Killer_03", "Character_Killer_04",
               "Character_Killer_05", "Character_Killer_06", "Character_Killer_07" },
}

-- rig joints in metres (x forward, y up, z right), matching the offsets used in humans.lua
local PIVOT = {
    torso = { 0, 0.94, 0 }, head = { 0.02, 1.54, 0 },
    thighL = { 0, 0.90, -0.1 }, thighR = { 0, 0.90, 0.1 }, shinL = { 0, 0.46, -0.1 }, shinR = { 0, 0.46, 0.1 },
    armL = { 0.02, 1.46, -0.24 }, armR = { 0.02, 1.46, 0.24 },
}

local function partOf(x, y, z)
    local h = Ch.HEIGHT
    if y > 0.845 * h then return "head" end
    if math.abs(z) > 0.108 * h and y > 0.38 * h then return z < 0 and "armL" or "armR" end
    if y < 0.515 * h then
        if y < 0.27 * h then return z < 0 and "shinL" or "shinR" end
        return z < 0 and "thighL" or "thighR"
    end
    return "torso"
end

function Ch.available()
    if Ch.ok == nil then Ch.ok = love.filesystem.getInfo(Ch.FILE) ~= nil end
    return Ch.ok
end

-- rigid part models for one figure (by node name), or nil when the file is missing
function Ch.build(name)
    if Ch.cache[name] ~= nil then return Ch.cache[name] or nil end
    Ch.cache[name] = false
    if not Ch.available() then return nil end
    local asset = Gltf.load(Ch.FILE)
    if not asset.byName[name] then return nil end
    local prims, x0, y0, z0, x1, y1, z1 = Gltf.collect(asset, name)
    local s = Ch.HEIGHT / (y1 - y0)
    local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    local builders = {}
    for part in pairs(PIVOT) do builders[part] = MB.new(700) end
    local t = {}
    for _, pr in ipairs(prims) do
        local v = pr.verts
        for k = 0, #v - 36, 36 do
            -- the figures face along the file's -z axis: turn them to face +x
            local function P(j)
                return -(v[j + 3] - cz) * s, (v[j + 2] - y0) * s, (v[j + 1] - cx) * s
            end
            local ax, ay, az = P(k)
            local bx, by, bz = P(k + 12)
            local ex, ey, ez = P(k + 24)
            local part = partOf((ax + bx + ex) / 3, (ay + by + ey) / 3, (az + bz + ez) / 3)
            local piv = PIVOT[part]
            local mb = builders[part]
            mb:material(pr.tex)
            for j = k, k + 24, 12 do
                local x, y, z = P(j)
                t[1], t[2], t[3] = x - piv[1], y - piv[2], z - piv[3]
                t[4], t[5] = v[j + 4], v[j + 5]
                t[6], t[7], t[8] = -v[j + 8], v[j + 7], v[j + 6]
                t[9], t[10], t[11], t[12] = v[j + 9], v[j + 10], v[j + 11], v[j + 12]
                mb:vertex(t)
            end
        end
    end
    local set = {}
    for part, mb in pairs(builders) do set[part] = mb:build() end
    Ch.cache[name] = set
    return set
end

-- build every look up front, then let go of the 22 MB file
function Ch.preload()
    if not Ch.available() then return end
    for _, list in pairs(Ch.LOOKS) do
        for _, name in ipairs(list) do Ch.build(name) end
    end
    Gltf.release(Gltf.load(Ch.FILE))
end

-- the figure assigned to an NPC of a faction (stable per id)
function Ch.forNpc(faction, id)
    local list = Ch.LOOKS[faction] or Ch.LOOKS.loner
    return Ch.build(list[(id - 1) % #list + 1])
end

return Ch
