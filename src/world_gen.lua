-- Places every location, building, prop, loot container, door, person and interior into the
-- 4 km world. Places sit far apart along the road network; the wilderness between them is
-- forest, fields, hamlets and the wreckage of the last war.
local U = require("src.utils")
local W = require("src.world")
local Props = require("src.props")
local B = require("src.buildings")

local G = {}
local pi = math.pi
local rng

local nextId = 0
local function id(prefix) nextId = nextId + 1 return prefix .. "_" .. nextId end

---------------------------------------------------------------------------
-- loot
---------------------------------------------------------------------------
local LOOT = {
    house = { { "food", 0.5, 1, 2 }, { "water", 0.4, 1, 2 }, { "medkit", 0.12, 1, 1 }, { "rifle_ammo", 0.25, 5, 10 },
              { "battery", 0.1, 1, 1 }, { "pistol_ammo", 0.25, 6, 12 }, { "shotgun_ammo", 0.2, 3, 8 },
              { "wool_cap", 0.08, 1, 1 }, { "sweater", 0.06, 1, 1 }, { "mittens", 0.06, 1, 1 } },
    apartment = { { "food", 0.35, 1, 1 }, { "water", 0.3, 1, 1 }, { "medkit", 0.1, 1, 1 }, { "battery", 0.12, 1, 1 },
                  { "pistol_ammo", 0.15, 4, 10 }, { "antirad", 0.08, 1, 1 }, { "gloves", 0.08, 1, 1 } },
    kitchen = { { "food", 0.55, 1, 2 }, { "water", 0.45, 1, 2 } },
    wardrobe = { { "sweater", 0.3, 1, 1 }, { "telogreika", 0.12, 1, 1 }, { "sheepskin", 0.05, 1, 1 }, { "wool_cap", 0.25, 1, 1 },
                 { "ushanka", 0.1, 1, 1 }, { "trousers", 0.25, 1, 1 }, { "quilted_pants", 0.08, 1, 1 }, { "mittens", 0.15, 1, 1 },
                 { "gloves", 0.15, 1, 1 }, { "valenki", 0.08, 1, 1 }, { "boots", 0.1, 1, 1 } },
    shop = { { "food", 0.6, 1, 3 }, { "water", 0.5, 1, 2 }, { "battery", 0.2, 1, 1 }, { "medkit", 0.1, 1, 1 } },
    military = { { "rifle_ammo", 0.55, 5, 15 }, { "mg_ammo", 0.35, 50, 150 }, { "medkit", 0.25, 1, 1 }, { "pistol_ammo", 0.3, 10, 24 },
                 { "repair_kit", 0.15, 1, 1 }, { "food", 0.3, 1, 2 }, { "ap_shell", 0.12, 1, 2 }, { "he_shell", 0.12, 1, 2 },
                 { "greatcoat", 0.06, 1, 1 }, { "ushanka", 0.1, 1, 1 }, { "boots", 0.1, 1, 1 }, { "quilted_pants", 0.06, 1, 1 } },
    armory = { { "ap_shell", 0.6, 1, 3 }, { "he_shell", 0.6, 1, 3 }, { "mg_ammo", 0.7, 100, 250 }, { "rifle_ammo", 0.5, 10, 20 },
               { "pistol_ammo", 0.4, 20, 40 } },
    industrial = { { "repair_kit", 0.25, 1, 1 }, { "battery", 0.3, 1, 1 }, { "tools", 0.4, 1, 2 }, { "antirad", 0.25, 1, 1 },
                   { "water", 0.3, 1, 2 }, { "rifle_ammo", 0.25, 5, 10 }, { "gloves", 0.1, 1, 1 } },
    garage = { { "tools", 0.45, 1, 2 }, { "fuel", 0.22, 1, 1 }, { "repair_kit", 0.12, 1, 1 }, { "battery", 0.2, 1, 1 },
               { "mg_ammo", 0.08, 30, 80 }, { "gloves", 0.08, 1, 1 } },
    depot = { { "repair_kit", 0.45, 1, 1 }, { "tools", 0.5, 1, 3 }, { "fuel", 0.4, 1, 1 }, { "ap_shell", 0.3, 1, 2 }, { "he_shell", 0.3, 1, 2 },
              { "mg_ammo", 0.35, 50, 150 } },
    wreck = { { "mg_ammo", 0.3, 30, 90 }, { "fuel", 0.15, 1, 1 }, { "tools", 0.3, 1, 1 }, { "rifle_ammo", 0.3, 5, 10 },
              { "shotgun_ammo", 0.25, 3, 8 } },
}
G.LOOT = LOOT

local function rollLoot(kind)
    local out = {}
    for _, e in ipairs(LOOT[kind] or LOOT.house) do
        if rng:next() < e[2] then out[#out + 1] = { e[1], rng:int(e[3], e[4]) } end
    end
    if #out == 0 and kind ~= "wardrobe" and kind ~= "kitchen" and kind ~= "apartment" then out[1] = { "food", 1 } end
    return out
end
G.rollLoot = function(kind) return rollLoot(kind) end

---------------------------------------------------------------------------
-- placement helpers
---------------------------------------------------------------------------
local function container(ctx, lx, ly, lz, kind, label, loot)
    local x, y, z = ctx:toWorld(lx, ly, lz)
    local c = { id = id("c"), x = x, y = y, z = z, label = label or "CRATE", loot = loot or rollLoot(kind), searched = false }
    W.containers[#W.containers + 1] = c
    return c
end
G.container = container

local function pickup(ctx, lx, ly, lz, item, count, model)
    local x, y, z = ctx:toWorld(lx, ly, lz)
    local p = { id = id("p"), x = x, y = y, z = z, item = item, count = count or 1, model = model or item, taken = false,
                yaw = rng:range(0, 6.28) }
    W.pickups[#W.pickups + 1] = p
    return p
end
G.pickup = pickup

local function door(ctx, lx, ly, lz, rotLocal, width, height, opts)
    -- hinge at lx, panel extends along local +x (rotated by rotLocal); stored in world space
    local x, y, z = ctx:toWorld(lx, ly, lz)
    local yaw = (ctx.rot or 0) + (rotLocal or 0)
    local d = { id = id("d"), x = x, y = y, z = z, yaw = yaw, width = width or 1.1, height = height or 2.1,
                open = false, angle = 0, locked = opts and opts.locked, transition = opts and opts.transition,
                label = opts and opts.label or "DOOR", mat = opts and opts.mat or "wood", heavy = opts and opts.heavy }
    local ex, ez = x + math.cos(yaw) * d.width, z + math.sin(yaw) * d.width
    local t = 0.12
    d.box = { math.min(x, ex) - t, y, math.min(z, ez) - t, math.max(x, ex) + t, y + d.height, math.max(z, ez) + t, walk = false }
    if not d.transition then W.colliders:add(d.box) end
    d.obj = ctx.obj
    W.doors[#W.doors + 1] = d
    return d
end
G.door = door

local function light(ctx, lx, ly, lz, r, g, b, radius, intensity, flicker)
    local x, y, z = ctx:toWorld(lx, ly, lz)
    local l = { x = x, y = y, z = z, r = r, g = g, b = b, radius = radius, intensity = intensity, flicker = flicker }
    W.staticLights[#W.staticLights + 1] = l
    return l
end
G.light = light

local function emitter(ctx, lx, ly, lz, kind, rate)
    local x, y, z = ctx:toWorld(lx, ly, lz)
    W.emitters[#W.emitters + 1] = { x = x, y = y, z = z, kind = kind, rate = rate or 1, acc = 0 }
end

local function fireBarrel(ctx, lx, lz)
    Props.barrel(ctx, lx, 0, lz, true)
    emitter(ctx, lx, 0.95, lz, "fire", 1)
    light(ctx, lx, 1.6, lz, 1.0, 0.55, 0.2, 9, 1.4, true)
    local x, y, z = ctx:toWorld(lx, 0, lz)
    W.fires[#W.fires + 1] = { x = x, y = y, z = z, r = 5 }
end
G.fireBarrel = fireBarrel

-- people: faction "loner" (survivors), "bandit" or "military"; role sit / guard / patrol / trader
local function npc(x, z, faction, role, name, key, yaw, opts)
    W.npcs[#W.npcs + 1] = { x = x, z = z, faction = faction, role = role, name = name, key = key, yaw = yaw or 0,
                            y = opts and opts.y, home = opts and opts.home }
end
G.npc = npc

-- a group walking a route between places (A-life): waypoints {x, z}
local function squad(faction, count, route, name)
    W.squads[#W.squads + 1] = { faction = faction, count = count, route = route, name = name }
end
G.squad = squad

local function campfire(cx, cz, logs)
    local c = W.ctx(cx, cz, 0)
    c:mat("rubble", 0.55, 0.55, 0.55)
    for i = 0, 7 do
        local a = i / 8 * 6.283
        c.mb:push() c.mb:translate(math.cos(a) * 0.55, 0, math.sin(a) * 0.55)
        c.mb:sphere(0, 0.05, 0, 0.16, 0.12, 0.14, 5, 3)
        c.mb:pop()
    end
    c:mat("wood", 0.35, 0.28, 0.22)
    c:beam(-0.35, 0.08, -0.2, 0.35, 0.18, 0.2, 0.1)
    c:beam(-0.3, 0.08, 0.25, 0.3, 0.18, -0.25, 0.1)
    c:mat("ground", 0.3, 0.25, 0.2)
    c.mb:cylinder(0, 0.01, 0, 0.45, 0.03, 0.45, 8)
    for _, a in ipairs(logs or {}) do
        local lx, lz = math.cos(a) * 2.3, math.sin(a) * 2.3
        c:mat("bark", 0.8, 0.75, 0.7)
        c.mb:push() c.mb:translate(lx, 0.18, lz) c.mb:rotateY(a + math.pi / 2)
        c.mb:cylinderX(-0.7, 0.7, 0, 0, 0.18, 0.18, 6)
        c.mb:pop()
    end
    local y = W.height(cx, cz)
    W.emitters[#W.emitters + 1] = { x = cx, y = y + 0.15, z = cz, kind = "fire", rate = 1, acc = 0 }
    W.staticLights[#W.staticLights + 1] = { x = cx, y = y + 1.2, z = cz, r = 1.0, g = 0.55, b = 0.22, radius = 12, intensity = 1.7, flicker = true }
    W.fires[#W.fires + 1] = { x = cx, y = y, z = cz, r = 6 }
    return cx, y, cz
end
G.campfire = campfire

local function tent(cx, cz, yaw, w, l, h, mat, tint)
    local c = W.dctx(cx, cz, yaw, "cloth", 35, { crush = true })
    c:mat(mat or "cloth", tint and tint[1] or 0.55, tint and tint[2] or 0.55, tint and tint[3] or 0.42)
    w, l, h = w or 2.2, l or 2.8, h or 1.6
    c.mb:hexa({ { -l / 2, 0, -w / 2 }, { l / 2, 0, -w / 2 }, { l / 2, 0, w / 2 }, { -l / 2, 0, w / 2 },
                { -l / 2, h, -0.04 }, { l / 2, h, -0.04 }, { l / 2, h, 0.04 }, { -l / 2, h, 0.04 } })
    c:mat("window", 0.25, 0.22, 0.2)
    c.mb:tri(l / 2 + 0.01, 0, -w * 0.3, 0, 0, l / 2 + 0.01, h * 0.75, 0, 0.5, 1, l / 2 + 0.01, 0, w * 0.3, 1, 0)
    c:mat("snow", 0.95, 0.97, 1)
    c.mb:hexa({ { -l / 2, h * 0.55, -w * 0.22 }, { l / 2, h * 0.55, -w * 0.22 }, { l / 2, h * 0.55, w * 0.22 }, { -l / 2, h * 0.55, w * 0.22 },
                { -l / 2, h + 0.03, -0.03 }, { l / 2, h + 0.03, -0.03 }, { l / 2, h + 0.03, 0.03 }, { -l / 2, h + 0.03, 0.03 } })
    c:collider(-l / 2, 0, -w / 2, l / 2, h, w / 2)
    local a, b, cc, d, e, f = c:worldBox(-l / 2, 0, -w / 2, l / 2, h, w / 2)
    W.shelters[#W.shelters + 1] = { a, b, cc, d, e, f }
end
G.tent = tent

-- destructible object contexts
local function V(x, z, rot) return (W.dctx(x, z, rot, "vehicle", 260, {})) end
local function TW(x, z, rot) return (W.dctx(x, z, rot, "metal", 650, {})) end
local function DW(x, z, rot) return (W.dctx(x, z, rot, "wood", 45, { crush = true })) end
local function DM(x, z, rot) return (W.dctx(x, z, rot, "metal", 120, { crush = true })) end
G.V, G.TW, G.DW, G.DM = V, TW, DW, DM

local function placeHouse(x, z, rot, w, d, opts, lootKind)
    local ctx = W.dctx(x, z, rot, "building", 900)
    local info = Props.house(ctx, w, d, opts, rng)
    if not (opts and opts.noLoot) then
        local c = container(ctx, -w / 2 + 0.45, 0.25, -d / 2 + d * 0.3, lootKind or "house", "CUPBOARD")
        if opts and opts.extraLoot then for _, e in ipairs(opts.extraLoot) do table.insert(c.loot, e) end end
        if rng:next() < 0.45 then container(ctx, w / 2 - 0.6, 0.25, d / 2 - 0.6, "wardrobe", "WARDROBE") end
    end
    if opts and opts.door then
        door(ctx, w * (opts.doorAt or 0.5) - w / 2 - 0.55, 0.25, -d / 2, 0, 1.1, 2.1)
    end
    return ctx, info
end
G.placeHouse = placeHouse

-- footprints already taken (world-space rectangles), so generated buildings never overlap
local taken = {}
local function free(x, z, hx, hz, roadMargin)
    local m = roadMargin or 5
    for _, p in ipairs({ { 0, 0 }, { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
        if W.roadInfo(x + p[1] * hx, z + p[2] * hz) < m then return false end
    end
    for _, t in ipairs(taken) do
        if math.abs(x - t[1]) < hx + t[3] and math.abs(z - t[2]) < hz + t[4] then return false end
    end
    return true
end
local function take(x, z, hx, hz) taken[#taken + 1] = { x, z, hx, hz } end
G.free, G.take = free, take

-- rotation (multiple of 90 degrees) that turns a building's front (local -z) towards the nearest road
local function faceRoad(x, z)
    local _, _, road, seg, t = W.roadInfo(x, z)
    if not seg then return 0 end
    local px, pz = seg.a.x + (seg.b.x - seg.a.x) * t, seg.a.z + (seg.b.z - seg.a.z) * t
    local dx, dz = px - x, pz - z
    if math.abs(dx) > math.abs(dz) then return dx > 0 and pi / 2 or -pi / 2 end
    return dz < 0 and 0 or pi
end
G.faceRoad = faceRoad

local function roadDir(x, z)
    local _, _, road, seg = W.roadInfo(x, z)
    if not seg then return 1, 0 end
    return seg.a.tx, seg.a.tz
end

-- half extents of a block once rotated by a multiple of 90 degrees
local function rotExtents(hx, hz, rot)
    if math.abs(math.sin(rot)) > 0.5 then return hz, hx end
    return hx, hz
end

local PANEL_TINTS = { { 0.82, 0.8, 0.76 }, { 0.75, 0.78, 0.8 }, { 0.84, 0.78, 0.68 }, { 0.72, 0.74, 0.7 }, { 0.8, 0.72, 0.66 } }

-- an enterable panel block at a free spot facing the road; returns ctx or nil
local function panelBlockAt(x, z, sections, floors, opts)
    opts = opts or {}
    local rot = opts.rot or faceRoad(x, z)
    local hx, hz = rotExtents(sections * B.SECTION_W / 2 + 1.5, B.BLOCK_DEPTH / 2 + 2.5, rot)
    if not opts.force and not free(x, z, hx, hz, opts.roadMargin) then return nil end
    take(x, z, hx, hz)
    local ctx = W.ctx(x, z, rot)
    local collapse
    if opts.damaged then
        collapse = {}
        collapse[rng:int(1, sections)] = rng:int(1, floors - 1)
    end
    B.panelBlock(ctx, { sections = sections, floors = floors, tint = opts.tint or PANEL_TINTS[rng:int(1, #PANEL_TINTS)], collapse = collapse,
                        Gen = G, loot = opts.loot, doors = opts.doors }, rng)
    W.blocks[#W.blocks + 1] = { ctx = ctx, x = x, z = z, rot = rot, sections = sections, floors = floors }
    return ctx
end
G.panelBlockAt = panelBlockAt

---------------------------------------------------------------------------
-- vegetation (instanced)
---------------------------------------------------------------------------
local function registerInstances()
    W.instanceKind("pine", function(mb)
        local ctx = { mb = mb, mat = W.Ctx.mat }
        mb:material("bark"):color(0.9, 0.85, 0.8)
        mb:cylinder(0, -0.5, 0, 0.22, 3, 0.12, 5, false)
        for k = 0, 2 do
            local by = 1.4 + k * 2.1
            local r = 2.4 - k * 0.6
            local top = by + 3.2 - k * 0.4
            mb:material("pine"):color(0.8, 0.9, 0.85)
            mb:cylinder(0, by, 0, r, top, 0, 6, "top")
            mb:material("snow"):color(0.95, 0.97, 1)
            mb:cylinder(0, top - (1.0 - k * 0.1), 0, r * 0.36, top + 0.05, 0, 6, false)
        end
    end)
    W.instanceKind("spruce", function(mb)
        mb:material("bark"):color(0.85, 0.8, 0.75)
        mb:cylinder(0, -0.5, 0, 0.25, 4, 0.1, 5, false)
        for k = 0, 3 do
            local by = 1.0 + k * 2.2
            local r = 2.0 - k * 0.42
            mb:material("pine"):color(0.7, 0.82, 0.76)
            mb:cylinder(0, by, 0, r, by + 3.0, 0, 7, "top")
            mb:material("snow"):color(0.95, 0.97, 1)
            mb:cylinder(0, by + 1.9, 0, r * 0.4, by + 3.05, 0, 7, false)
        end
    end)
    W.instanceKind("deadtree", function(mb)
        local r2 = U.rng(17)
        mb:material("bark"):color(0.75, 0.72, 0.7)
        mb:cylinder(0, -0.5, 0, 0.2, 6, 0.05, 5, false)
        local ctx = setmetatable({ mb = mb }, W.Ctx)
        for k = 1, 5 do
            local by = 6 * (0.35 + k * 0.11)
            local a = k * 2.3
            local l = 2.2 - k * 0.3
            ctx:beam(0, by, 0, math.cos(a) * l, by + l * 0.6, math.sin(a) * l, 0.08)
        end
    end)
    W.instanceKind("birch", function(mb)
        mb:material("plaster"):color(0.92, 0.9, 0.86)
        mb:cylinder(0, -0.5, 0, 0.16, 7, 0.06, 5, false)
        local ctx = setmetatable({ mb = mb }, W.Ctx)
        mb:material("bark"):color(0.6, 0.58, 0.56)
        for k = 1, 6 do
            local by = 2.5 + k * 0.7
            local a = k * 2.1
            local l = 1.6 - k * 0.15
            ctx:beam(0, by, 0, math.cos(a) * l, by + l * 0.9, math.sin(a) * l, 0.05)
        end
    end)
    W.instanceKind("bush", function(mb)
        mb:material("pine"):color(0.55, 0.6, 0.5)
        mb:sphere(0, 0.35, 0, 0.9, 0.6, 0.8, 6, 3)
        mb:material("snow"):color(0.95, 0.97, 1)
        mb:sphere(0, 0.55, 0, 0.75, 0.45, 0.65, 6, 2)
    end)
    W.instanceKind("rock", function(mb)
        mb:material("rubble"):color(0.75, 0.75, 0.78)
        mb:sphere(0, 0.3, 0, 1, 0.7, 0.85, 6, 4)
    end)
    W.instanceKind("grass", function(mb)
        mb.jitter = 0
        mb:material("grass"):color(1, 0.92, 0.85)
        for k = 0, 1 do
            local c, s = math.cos(k * 1.57) * 0.5, math.sin(k * 1.57) * 0.5
            mb:quadUV(-c, -0.05, -s, 0, 1, c, -0.05, s, 1, 1, c, 0.55, s, 1, 0, -c, 0.55, -s, 0, 0)
        end
    end)
    W.instanceKind("stump", function(mb)
        mb:material("bark"):color(0.8, 0.75, 0.7)
        mb:cylinder(0, -0.2, 0, 0.32, 0.55, 0.28, 6)
        mb:material("snow"):color(0.95, 0.97, 1)
        mb:cylinder(0, 0.55, 0, 0.29, 0.62, 0.2, 6)
    end)
end

local function nearLocation(x, z, k)
    for _, l in ipairs(W.locations) do
        if l.id ~= "forest" and U.dist2(x, z, l.x, l.z) < l.r * (k or 0.95) then return true end
    end
    return false
end

-- one tree at x, z (instanced, with a trunk collider)
local function tree(kind, x, z, s)
    local y = W.height(x, z)
    W.addInstance(kind, x, y, z, rng:range(0, 6.28), s, rng:range(0.85, 1.05))
    local r = (kind == "birch" and 0.2 or 0.3) * s
    W.colliders:add({ x - r, y - 1, z - r, x + r, y + 7 * s, z + r, walk = true, tree = true })
end

local function okForTree(x, z, minRoad)
    if math.abs(x) > W.LIMIT + 80 or math.abs(z) > W.LIMIT + 80 then return false end
    if W.roadDistance(x, z) < (minRoad or 10) then return false end
    if math.abs(x - W.riverX(z)) < 20 then return false end
    for _, t in ipairs(taken) do
        if math.abs(x - t[1]) < t[3] + 2 and math.abs(z - t[2]) < t[4] + 2 then return false end
    end
    return true
end

local function grove(cx, cz, radius, count, mix, minRoad)
    for i = 1, count do
        local a = rng:range(0, 2 * pi)
        local r = math.sqrt(rng:next()) * radius
        local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
        if okForTree(x, z, minRoad) and not nearLocation(x, z) then
            local k = rng:next()
            local kind = k < mix[1] and "pine" or (k < mix[1] + (mix[2] or 0) and "spruce" or (k < mix[1] + (mix[2] or 0) + (mix[3] or 0) and "birch" or "deadtree"))
            tree(kind, x, z, rng:range(0.8, 1.35))
        end
        if i % 400 == 0 and coroutine.isyieldable() then coroutine.yield("forests", 0.5) end
    end
end
G.grove = grove

-- poles along a road path
local function roadPoles(path, spacing, offset)
    local nextD = spacing * 0.5
    for i = 1, #path - 1 do
        local a = path[i]
        if a.d >= nextD then
            nextD = a.d + spacing
            local x, z = a.x - a.tz * offset, a.z + a.tx * offset
            if math.abs(x - W.riverX(z)) > 20 and not nearLocation(x, z, 0.6) then
                local ctx = W.dctx(x, z, math.atan2(a.tz, a.tx), "wood", 40, { crush = true })
                if rng:next() > 0.12 then Props.pole(ctx, 0, 0, 0)
                else
                    ctx:mat("wood", 0.5, 0.45, 0.4)
                    ctx:beam(0, 0.2, 0, 6, 0.4, 2, 0.25)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- tile-based interiors (bunker, control room)
---------------------------------------------------------------------------
-- legend: '#' wall, '.' floor, others are floor + marker
local function tileInterior(map, ox, oy, oz, cell, height, opts)
    opts = opts or {}
    local rows = {}
    for line in map:gmatch("[^\n]+") do rows[#rows + 1] = line end
    local H, Wd = #rows, #rows[1]
    local function at(i, j)
        if j < 1 or j > H or i < 1 or i > Wd then return "#" end
        return rows[j]:sub(i, i)
    end
    local ctx = W.ctx(ox, oz, 0, { interior = true, y = oy, maxEdge = 1.5 })
    local mb = ctx.mb
    if not opts.underground then ctx:flatten(0, 0, #rows[1] * cell, #rows * cell, 0) end
    local markers = {}
    local floorMat, wallMat, ceilMat = opts.floor or "concrete", opts.wall or "concrete", opts.ceil or "concrete"
    for j = 1, H do
        for i = 1, Wd do
            local c = at(i, j)
            local x0, z0 = (i - 1) * cell, (j - 1) * cell
            local x1, z1 = x0 + cell, z0 + cell
            if c ~= "#" then
                ctx:mat(floorMat, 0.7, 0.7, 0.68)
                mb:grid(x0, 0, z0, 0, 0, cell, cell, 0, 0)
                ctx:mat(ceilMat, 0.55, 0.55, 0.55)
                mb:grid(x0, height, z0, cell, 0, 0, 0, 0, cell)
                ctx:mat(wallMat, opts.wr or 0.62, opts.wg or 0.66, opts.wb or 0.6)
                local function wallAt(a, b)
                    if c == "O" and (a < 1 or a > Wd or b < 1 or b > H) then return false end
                    return at(a, b) == "#"
                end
                if wallAt(i - 1, j) then mb:grid(x0, 0, z0, 0, height, 0, 0, 0, cell) end
                if wallAt(i + 1, j) then mb:grid(x1, 0, z0, 0, 0, cell, 0, height, 0) end
                if wallAt(i, j - 1) then mb:grid(x0, 0, z0, cell, 0, 0, 0, height, 0) end
                if wallAt(i, j + 1) then mb:grid(x0, 0, z1, 0, height, 0, cell, 0, 0) end
                if c ~= "." and c ~= "O" then markers[#markers + 1] = { c = c, x = x0 + cell / 2, z = z0 + cell / 2, i = i, j = j } end
            else
                local nearFloor = false
                for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                    if at(i + d[1], j + d[2]) ~= "#" then nearFloor = true end
                end
                if nearFloor then ctx:collider(x0, -0.5, z0, x1, height + 0.5, z1) end
            end
        end
    end
    W.interiorAreas[#W.interiorAreas + 1] = { x = ox + Wd * cell / 2, y = oy, z = oz + H * cell / 2, r = math.max(Wd, H) * cell }
    ctx:collider(0, -1, 0, Wd * cell, 0, H * cell)
    ctx:collider(0, height, 0, Wd * cell, height + 1, H * cell, { noPlayer = false })
    return ctx, markers, Wd * cell, H * cell
end

---------------------------------------------------------------------------
-- locations
---------------------------------------------------------------------------
local function buildCamp()
    local L = W.camp
    take(L.x, L.z, 18, 18)
    local fx, fy, fz = campfire(L.x, L.z, { 0.3, 1.9, 3.5, 5.0 })
    W.guitars[#W.guitars + 1] = { x = fx, y = fy + 1, z = fz }
    tent(L.x - 7, L.z + 5, 0.4)
    tent(L.x + 6, L.z + 7, -0.5, 2.4, 3.2, 1.8, "cloth", { 0.45, 0.5, 0.38 })
    tent(L.x - 1, L.z - 9, 1.6)
    -- trader's stall
    local st = W.ctx(L.x + 8, L.z - 4, -0.6)
    Props.crate(st, 0, 0, 0, 0.9)
    Props.crate(st, 1.0, 0, 0.1, 0.8)
    Props.crate(st, 0.4, 0.9, 0.0, 0.6)
    st:mat("cloth", 0.4, 0.42, 0.32)
    st:beam(-0.8, 0, -1.2, -0.8, 2.3, -1.2, 0.08) st:beam(1.8, 0, -1.2, 1.8, 2.3, -1.2, 0.08)
    st:beam(-0.8, 0, 1.0, -0.8, 2.3, 1.0, 0.08) st:beam(1.8, 0, 1.0, 1.8, 2.3, 1.0, 0.08)
    st.mb:hexa({ { -1.0, 2.3, -1.4 }, { 2.0, 2.3, -1.4 }, { 2.0, 2.3, 1.2 }, { -1.0, 2.3, 1.2 },
                 { -1.0, 2.45, -1.4 }, { 2.0, 2.45, -1.4 }, { 2.0, 2.45, 1.2 }, { -1.0, 2.45, 1.2 } })
    G.light(st, 0.5, 1.9, 0, 1.0, 0.75, 0.4, 6, 0.9, true)
    Props.barrel(W.ctx(L.x - 4, L.z - 6, 0), 0, 0, 0, true)
    Props.fence(DW(L.x, L.z + 14, 0), -10, 0, 10, 0, 1.1)
    Props.car(V(L.x - 14, L.z - 2, 1.2), 0, 0, 0)
    pickup(W.ctx(L.x - 3, L.z + 8, 0), 0, 0, 0, "water", 2, "foodbox")
    container(W.ctx(L.x - 7, L.z + 5, 0.4), 0.8, 0.1, 0, "wardrobe", "KIT BAG", { { "mittens", 1 }, { "wool_cap", 1 } })
    local function sitAt(a, name, key)
        local x, z = L.x + math.cos(a) * 2.3, L.z + math.sin(a) * 2.3
        npc(x, z, "loner", "sit", name, key, a + math.pi)
    end
    sitAt(0.3, "KOLYA", "kolya")
    sitAt(1.9, "MISHA", "misha")
    sitAt(3.5, "SURVIVOR", nil)
    npc(L.x + 7.2, L.z - 3.0, "loner", "trader", "OLD PETRO", "petro", math.pi * 0.9)
    npc(L.x + 13, L.z + 1, "loner", "guard", "SERGEI 'WOLF'", "wolf", 0)
end

local function buildKolkhoz()
    local L = W.kolkhoz
    -- cowsheds and the machine barn
    local b1 = W.ctx(L.x + 45, L.z - 50, 0)
    take(L.x + 45, L.z - 50, 22, 9)
    Props.hall(b1, 40, 14, 6, rng, { mat = "wood", holes = 0.45, closedEnd = true, doorW = 5 })
    container(b1, -15, 0.1, 4, "garage", "FEED BIN")
    Props.truck(b1, 8, 0, 0, true)
    local b2 = W.ctx(L.x - 60, L.z + 55, pi / 2)
    take(L.x - 60, L.z + 55, 9, 18)
    Props.hall(b2, 32, 13, 6, rng, { mat = "brick", holes = 0.3, doorW = 6 })
    container(b2, 10, 0.1, -4, "garage", "TOOL LOCKER")
    pickup(b2, -8, 0.1, 3, "fuel", 1, "jerrycan")
    -- grain silos (seen from far)
    for i, p in ipairs({ { 85, 15 }, { 92, 26 } }) do
        local s = W.ctx(L.x + p[1], L.z + p[2], 0, { landmark = true })
        take(L.x + p[1], L.z + p[2], 5, 5)
        s:mat("concrete", 0.7, 0.7, 0.68)
        s.mb:cylinder(0, 0, 0, 4, 18, 4, 10)
        s.mb:cylinder(0, 18, 0, 4.2, 20, 0.6, 10)
        s:mat("snow", 0.95, 0.97, 1)
        s.mb:cylinder(0, 18.1, 0, 3.9, 19.6, 0.8, 10, false)
        s:collider(-3.5, 0, -3.5, 3.5, 18, 3.5)
    end
    -- farmhouses along the track
    local spots = { { -40, -30 }, { -10, -45 }, { 20, 35 }, { -30, 30 }, { 55, 45 }, { -75, -10 }, { 10, -10 } }
    for i, p in ipairs(spots) do
        local x, z = L.x + p[1], L.z + p[2]
        if free(x, z, 6, 6, 6) then
            take(x, z, 6, 6)
            placeHouse(x, z, faceRoad(x, z), rng:range(7, 9), rng:range(6, 7.5), { ruined = i % 3 == 0, door = i % 2 == 0 }, "house")
        end
    end
    -- kolkhoz office
    local ox, oz = L.x - 15, L.z + 70
    if free(ox, oz, 9, 7, 4) then
        take(ox, oz, 9, 7)
        B.shop(W.ctx(ox, oz, faceRoad(ox, oz)), 16, 10, rng, G, { tint = { 0.8, 0.74, 0.6 }, label = "OFFICE DESK", loot = "house", shelves = false })
    end
    -- machine yard with dead tractors and a knocked-out tank from the war
    for i = 0, 2 do Props.truck(V(L.x + 30 + i * 8, L.z + 5, 1.6), 0, 0, 0, i == 1) end
    Props.tankWreck(TW(L.x + 60, L.z - 10, 0.7), 0, 0, 0, false)
    container(W.ctx(L.x + 60, L.z - 10, 0.7), 0, 1.8, 0, "wreck", "WRECKAGE")
    local hay = W.ctx(L.x - 20, L.z - 75, 0)
    for i = 0, 4 do
        hay:mat("snow", 0.95, 0.97, 1)
        hay.mb:push() hay.mb:translate(i * 6, 0, (i % 2) * 4) hay.mb:sphere(0, 0.4, 0, 2.2, 1.6, 2.6, 7, 4) hay.mb:pop()
        hay:collider(i * 6 - 2, 0, (i % 2) * 4 - 2.4, i * 6 + 2, 1.8, (i % 2) * 4 + 2.4)
    end
    for _, x in ipairs({ -60, -35, 0, 35 }) do Props.fence(DW(L.x + x, L.z - 90, 0), -10, 0, 10, 0, 1.2) end
    pickup(W.ctx(L.x + 25, L.z + 12, 0), 0, 0, 0, "fuel", 1, "jerrycan")
    npc(L.x + 38, L.z + 12, "bandit", "guard", "BANDIT", nil, 2.5)
    npc(L.x + 48, L.z - 38, "bandit", "patrol", "BANDIT", nil, 0)
    fireBarrel(W.ctx(L.x + 42, L.z + 15, 0), 0, 0)
end

local function buildCheckpoint()
    local L = W.checkpoint
    local cx, cz = L.x, L.z
    local tx, tz = roadDir(cx, cz)
    local rot = math.atan2(tz, tx) - pi / 2      -- local +z runs along the road
    local function piece(kind, hp, opts) return (W.dctx(cx, cz, rot, kind, hp, opts)) end
    take(cx, cz, 26, 26)
    for _, x in ipairs({ { -6, -1 }, { 1.5, 6 } }) do
        local bp = piece("wood", 40, { crush = true })
        bp:mat("hazard", 1, 1, 1)
        bp:solid(x[1], 1.0, -0.1, x[2], 1.15, 0.1)
        bp:mat("metal", 0.4, 0.4, 0.4)
        bp:box(x[1] + 0.1, 0, -0.06, x[1] + 0.22, 1.0, 0.06)
    end
    for _, x in ipairs({ -6.5, 6 }) do
        local post = piece("stone", 300)
        post:mat("concrete", 0.7, 0.7, 0.7)
        post:solid(x, 0, -0.3, x + 0.5, 1.2, 0.3)
    end
    local bc = W.ctx(cx, cz, rot)
    local bx, bz = bc:toWorld(11, 0, 3)
    local b = W.dctx(bx, bz, rot - pi / 2, "building", 450)
    Props.house(b, 3.2, 3.2, { h = 2.5, empty = true, mat = "wood" }, rng)
    container(b, -1.1, 0.25, 0.6, "military", "LOCKER")
    pickup(b, 0.6, 0.25, 0.9, "ap_shell", 2, "shellcrate")
    Props.sandbags(piece("stone", 220, { crush = true }), -14, -6, -8, -6, 1.1)
    Props.sandbags(piece("stone", 220, { crush = true }), 8, -8, 14, -8, 1.1)
    Props.sandbags(piece("stone", 220, { crush = true }), -14, -6, -14, 0, 1.1)
    for i = -2, 2 do
        local blk = piece("stone", 350)
        blk:mat("concrete", 0.65, 0.65, 0.65)
        blk:solid(-9 + i * 0.1, 0, 8 + i * 2.2, -7.8, 1.0, 9.6 + i * 2.2)
    end
    for i = 0, 3 do Props.hedgehog(piece("metal", 160), -18 + i * 3.2, 14 + (i % 2) * 2) end
    for i = 0, 3 do Props.hedgehog(piece("metal", 160), 12 + i * 3.2, 15 + (i % 2) * 2) end
    Props.watchtower(piece("wood", 260), -13, 6)
    Props.sign(piece("wood", 40, { crush = true }), 7, -12, pi / 2, "sign")
    for i = 1, 5 do
        local cr = piece("wood", 50, { crush = true })
        Props.crate(cr, -4 + i * 1.9, 0, -9 - (i % 2) * 1.2, 0.8 + (i % 3) * 0.15)
    end
    local function at(lx, lz) return bc:toWorld(lx, 0, lz) end
    local x1, z1 = at(-11, -24) Props.truck(V(x1, z1, rot + 1.3), 0, 0, 0, true)
    local x2, z2 = at(16, -26) Props.tankWreck(TW(x2, z2, rot - 0.4), 0, 0, 0, false)
    container(W.ctx(x2, z2, rot - 0.4), -2.0, 0.6, 2.0, "wreck", "WRECKAGE")
    local x3, z3 = at(-18, 22) Props.truck(V(x3, z3, rot - 0.2), 0, 0, 0, false)
    container(W.ctx(x3, z3, rot - 0.2), -1, 1.2, 0, "military", "SUPPLY TRUCK")
    fireBarrel(bc, 9, 4)
    local tx1, tz1 = at(16, 8)
    tent(tx1, tz1, rot + 1.3, 2.4, 3.2, 1.7, "cloth", { 0.3, 0.32, 0.28 })
    local n1x, n1z = at(10.5, 4) npc(n1x, n1z, "military", "sit", "SOLDIER", nil, rot + math.pi)
    local n2x, n2z = at(3, -3) npc(n2x, n2z, "military", "guard", "SOLDIER", nil, rot - math.pi / 2)
    local n3x, n3z = at(-8, 4) npc(n3x, n3z, "military", "patrol", "SOLDIER", nil, rot)
    pickup(bc, -11, 0, -3, "mg_ammo", 150, "mgbox")
    pickup(bc, 10, 0, -6, "repair_kit", 1, "repairkit")
    pickup(bc, -10, 0, 3, "fuel", 1, "jerrycan")
end

local function buildGarages()
    local L = W.garages
    -- two alleys of garage rows north of the road
    local rows = { { 0, -36, 0 }, { 0, -56, pi }, { 0, -86, 0 }, { 0, -106, pi } }
    for i, r in ipairs(rows) do
        local x, z = L.x + r[1], L.z + r[2]
        take(x, z, 27, 4)
        B.garageRow(W.ctx(x, z, r[3]), 14, rng, G)
    end
    -- the tank repair depot south of the road
    local dx, dz = L.x - 10, L.z + 48
    take(dx, dz, 20, 11)
    local d = W.ctx(dx, dz, 0)
    Props.hall(d, 38, 20, 9, rng, { mat = "metal", holes = 0.25, sideDoor = true })
    Props.tankWreck(TW(dx - 6, dz, 0.05), 0, 0, 0, true)
    d:mat("concrete", 0.35, 0.35, 0.35)
    d.mb:box(4, 0.11, -2, 14, 0.13, 2)                 -- inspection pit cover
    d:mat("hazard", 1, 1, 1)
    d:box(-18, 7.6, -10, -17, 8.2, 10)
    d:box(-18, 7.6, -0.5, 18, 8.2, 0.5)
    container(d, 12, 0.1, -7, "depot", "SPARE PARTS")
    container(d, 12, 0.1, 7, "depot", "SHELL RACK", { { "ap_shell", 2 }, { "he_shell", 2 } })
    container(d, -14, 0.1, 7, "depot", "WORKBENCH")
    Props.shelf(d, -14, 9.2, 0, 3)
    pickup(d, 6, 0.1, 6, "repair_kit", 1, "repairkit")
    pickup(d, 7, 0.1, 6.8, "tools", 2, "repairkit")
    for i = 0, 2 do
        local ft = W.dctx(dx + 26, dz - 6 + i * 6, 0, "metal", 300, { explode = true })
        Props.fuelTank(ft, 0, 0, pi / 2, 5, 1.0)
    end
    pickup(W.ctx(dx + 22, dz + 12, 0), 0, 0, 0, "fuel", 1, "jerrycan")
    Props.tankWreck(TW(L.x + 40, L.z + 30, 2.4), 0, 0, 0, false)
    fireBarrel(W.ctx(L.x + 5, L.z - 46, 0), 0, 0)
    npc(L.x + 7, L.z - 46, "bandit", "sit", "BANDIT", nil, math.pi)
    npc(L.x + 3, L.z - 44, "bandit", "sit", "BANDIT", nil, 0)
    npc(L.x - 20, L.z - 47, "bandit", "patrol", "BANDIT", nil, 0)
    npc(L.x + 25, L.z - 72, "bandit", "guard", "BANDIT", nil, -1.2)
end

local function buildTown()
    local L = W.town
    take(L.x + 40, L.z - 70, 10, 14)
    Props.church(W.ctx(L.x + 40, L.z - 70, pi / 2), rng)
    -- village houses along the road
    local path = W.roadPaths[2]
    for i, p in ipairs(path) do
        if U.dist2(p.x, p.z, L.x, L.z) < L.r * 0.95 and i % 4 == 0 then
            for side = -1, 1, 2 do
                local off = 16 + rng:range(0, 4)
                local x, z = p.x - p.tz * off * side, p.z + p.tx * off * side
                if rng:next() < 0.8 and free(x, z, 5.5, 5.5, 6) then
                    take(x, z, 5.5, 5.5)
                    placeHouse(x, z, faceRoad(x, z), rng:range(7, 9), rng:range(6, 7.5), { ruined = rng:next() < 0.3, door = rng:next() < 0.5 }, "house")
                end
            end
        end
    end
    -- the new quarter: a few panel blocks behind the old street
    for _, p in ipairs({ { -80, -75, 3, 4 }, { 10, -110, 2, 5 }, { -40, 90, 3, 3 }, { 80, 70, 2, 4 } }) do
        panelBlockAt(L.x + p[1], L.z + p[2], p[3], p[4], { damaged = rng:next() < 0.35 })
    end
    -- school
    panelBlockAt(L.x - 115, L.z + 30, 2, 3, { tint = { 0.86, 0.78, 0.55 }, loot = 0.3 })
    -- gastronom and the square with its monument
    local gx, gz = L.x - 5, L.z - 40
    if free(gx, gz, 9, 7, 4) then
        take(gx, gz, 9, 7)
        B.shop(W.ctx(gx, gz, faceRoad(gx, gz)), 16, 11, rng, G, { label = "GASTRONOM SHELVES", sign = "sign" })
    end
    local mx, mz = L.x + 45, L.z + 30
    if free(mx, mz, 4, 4, 4) then take(mx, mz, 4, 4) B.monument(W.ctx(mx, mz, faceRoad(mx, mz) + pi)) end
    Props.truck(V(L.x - 30, L.z + 12, 0.3), 0, 0, 0, true)
    Props.car(V(L.x + 20, L.z + 8, 2.9), 0, 0, 0)
    -- survivors hold out in a block with a fire, bandits squat in the school
    local hx, hz = L.x - 80, L.z - 52
    fireBarrel(W.ctx(hx, hz, 0), 0, 0)
    npc(hx + 1.5, hz, "loner", "sit", "SURVIVOR", "nadia", pi)
    npc(hx - 1.5, hz + 0.5, "loner", "sit", "SURVIVOR", nil, 0)
    npc(L.x - 115, L.z + 10, "bandit", "guard", "BANDIT", nil, -pi / 2)
    npc(L.x - 100, L.z + 15, "bandit", "patrol", "BANDIT", nil, 0)
end

local function buildIndustrial()
    local L = W.industrial
    -- main factory hall
    local fx, fz = L.x - 20, L.z - 60
    take(fx, fz, 28, 14)
    local f = W.ctx(fx, fz, 0)
    Props.hall(f, 54, 26, 11, rng, { mat = "metal", sideDoor = true, holes = 0.3 })
    for i = -2, 2 do
        f:mat("metal", 0.5, 0.55, 0.5)
        f:solid(i * 9 - 2, 0, -3, i * 9 + 2, 2.2, 3)
        f:mat("rust", 0.6, 0.5, 0.4)
        f.mb:cylinderX(i * 9 - 1.5, i * 9 + 1.5, 2.8, 0, 0.6, 0.6, 7)
    end
    f:mat("hazard", 1, 1, 1)
    f:box(-26, 8.6, -12, -25, 9.2, 12)
    f:box(-26, 8.6, -0.5, 26, 9.2, 0.5)
    container(f, -20, 0.1, 9, "industrial", "TOOL LOCKER")
    container(f, 18, 0.1, -10, "industrial", "WORKBENCH")
    Props.crate(f, 15, 0.1, -10, 1.0)
    Props.crate(f, 16.2, 0.1, -10, 0.8)
    Props.shelf(f, -20, 11.6, 0, 3)
    pickup(f, 4, 0.1, 9, "repair_kit", 1, "repairkit")
    pickup(f, -10, 0.1, -9, "he_shell", 2, "shellcrate")
    fireBarrel(f, 8, 8)
    for _, c in ipairs({ { -55, -100, 48 }, { -37, -107, 42 }, { 17, -103, 38 } }) do
        local lc = W.ctx(L.x + c[1], L.z + c[2], 0, { landmark = true })
        take(L.x + c[1], L.z + c[2], 4, 4)
        Props.chimney(lc, 0, 0, c[3], 2.8)
        W.emitters[#W.emitters + 1] = { x = L.x + c[1], y = lc.y + c[3], z = L.z + c[2], kind = "chimney", rate = 1, acc = 0 }
    end
    for _, w in ipairs({ { 60, 25, 0, 26, 16 }, { -70, 35, pi / 2, 22, 14 } }) do
        local x, z = L.x + w[1], L.z + w[2]
        if free(x, z, w[4] / 2 + 1, w[5] / 2 + 1, 3) then
            take(x, z, w[4] / 2 + 1, w[5] / 2 + 1)
            local wh = W.ctx(x, z, w[3])
            Props.hall(wh, w[4], w[5], 7, rng, { mat = "brick", closedEnd = w[3] == 0, doorW = 5, holes = 0.4 })
            container(wh, w[4] / 2 - 3, 0.1, 4, "industrial", "CRATE")
            Props.crate(wh, w[4] / 2 - 5, 0.1, -5, 1.2) Props.crate(wh, w[4] / 2 - 3.7, 0.1, -5, 1.0)
            pickup(wh, -4, 0.1, 4, "fuel", 1, "jerrycan")
        end
    end
    -- rail line with wagons and the station building
    local rz = L.z + 95
    for x = L.x - 200, L.x + 160, 4 do
        if math.abs(W.roadDistance(x, rz)) > 6 then
            local r = W.ctx(x, rz, 0)
            r:mat("wood", 0.4, 0.35, 0.3)
            r:box(-0.25, -0.1, -1.4, 0.25, 0.08, 1.4)
            r:mat("rust", 0.5, 0.45, 0.42)
            r:box(-2, 0.08, -0.8, 2, 0.2, -0.7)
            r:box(-2, 0.08, 0.7, 2, 0.2, 0.8)
        end
    end
    for i, x in ipairs({ -160, -145, -60, -45, 90 }) do
        local wx = L.x + x
        if W.roadDistance(wx, rz) > 12 then
            take(wx, rz, 7, 2)
            local wg = W.ctx(wx, rz, 0)
            wg:mat(i % 2 == 0 and "rust" or "wood", 0.55, 0.45, 0.4)
            wg:solid(-6.5, 0.9, -1.5, 6.5, 4.0, 1.5)
            wg:mat("snow", 1, 1, 1)
            wg:box(-6.5, 4.0, -1.5, 6.5, 4.1, 1.5)
            wg:mat("tread", 0.4, 0.4, 0.4)
            for _, ox in ipairs({ -4.5, 4.5 }) do wg.mb:cylinderZ(-1.0, 1.0, ox, 0.5, 0.45, 8) end
            if i == 3 then container(wg, 0, 0.9, 1.6, "wreck", "FREIGHT CAR") end
        end
    end
    local sx, sz = L.x + 10, rz + 18
    if free(sx, sz, 11, 7, 3) then
        take(sx, sz, 11, 7)
        B.shop(W.ctx(sx, sz, pi), 20, 11, rng, G, { tint = { 0.78, 0.7, 0.58 }, label = "TICKET OFFICE", loot = "house", sign = "sign", shelves = false })
    end
    -- worker housing
    panelBlockAt(L.x + 100, L.z - 50, 3, 5, { damaged = true })
    panelBlockAt(L.x - 120, L.z + 40, 2, 4, {})
    local wt = W.ctx(L.x + 75, L.z - 105, 0, { landmark = true })
    take(L.x + 75, L.z - 105, 4, 4)
    wt:mat("rust", 0.6, 0.5, 0.45)
    for _, p in ipairs({ { -2, -2 }, { 2, -2 }, { 2, 2 }, { -2, 2 } }) do wt:beam(p[1] * 1.4, 0, p[2] * 1.4, p[1], 16, p[2], 0.3) end
    wt.mb:cylinder(0, 16, 0, 4, 21, 4, 10)
    wt.mb:cylinder(0, 21, 0, 4.2, 23, 0.5, 10)
    wt:collider(-3, 0, -3, 3, 16, 3)
    local pp = W.ctx(L.x + 50, L.z - 25, 0)
    pp:mat("rust", 0.65, 0.55, 0.45)
    pp.mb:cylinderX(-35, 35, 3.6, 0, 0.5, 0.5, 7)
    pp.mb:cylinderX(-35, 35, 3.6, 1.3, 0.35, 0.35, 6)
    for x = -30, 30, 10 do pp:mat("concrete", 0.6, 0.6, 0.6) pp:solid(x - 0.3, 0, -0.3, x + 0.3, 3.2, 0.3) end
    Props.truck(V(L.x + 35, L.z + 10, 1.7), 0, 0, 0, true)
    Props.tankWreck(TW(L.x + 110, L.z + 20, 0.4), 0, 0, 0, true)
    container(W.ctx(L.x + 110, L.z + 20, 0.4), 0, 1.0, 1.7, "wreck", "WRECKAGE")
    W.radZones[#W.radZones + 1] = { x = fx, z = fz, r = 22, strength = 1.2 }
    npc(L.x - 12, L.z - 52, "bandit", "sit", "BANDIT", nil, 0.5)
    npc(L.x - 26, L.z - 52, "bandit", "guard", "BANDIT", nil, 1.5)
    npc(L.x + 40, L.z + 20, "bandit", "patrol", "BANDIT", nil, 0)
    npc(L.x - 60, L.z + 80, "bandit", "guard", "BANDIT", nil, -1.5)
end

local function buildForest()
    local L = W.forest
    -- hunter's cabin (its clearing is reserved before the trees go in)
    local cx, cz = L.x + 18, L.z + 50
    take(cx - 3, cz, 9, 7)
    local cab = W.dctx(cx, cz, -pi / 2, "building", 800)
    Props.house(cab, 6, 5, { mat = "wood", h = 2.6 }, rng)
    container(cab, 2.2, 0.25, 1.5, "house", "HUNTER'S CHEST").loot = { { "food", 3 }, { "rifle_ammo", 15 }, { "medkit", 1 }, { "sheepskin", 1 } }
    pickup(cab, -1.5, 0.25, 1.4, "fuel", 1, "jerrycan")
    door(cab, -0.55, 0.25, -2.5, 0, 1.1, 2.1)
    W.cabin = { x = cx, z = cz }
    fireBarrel(W.ctx(cx - 7, cz + 3, 0), 0, -6)
    npc(cx - 4.8, cz - 3, "loner", "sit", "YEGOR THE HUNTER", "yegor", math.pi)
    grove(L.x, L.z, 260, 4200, { 0.45, 0.3, 0.1 }, 9)
    -- hunting stands in the trees
    for i = 1, 4 do
        local a = i * 1.6
        local x, z = L.x + math.cos(a) * 120, L.z + math.sin(a) * 120
        if okForTree(x, z, 6) then Props.watchtower(DW(x, z, a), 0, 0) end
    end
    -- the broken bridge on the forest road
    for _, br in ipairs(W.bridges) do
        if br.broken then
            local rot = math.atan2(br.tz, br.tx)
            local bc = W.ctx(br.x, br.z, rot, { y = br.h })
            bc:mat("concrete", 0.6, 0.6, 0.62)
            bc.mb:push() bc.mb:translate(-16, -1.5, 0) bc.mb:rotateZ(-0.25)
            bc:box(-6, -0.4, -3.5, 6, 0.2, 3.5)
            bc.mb:pop()
            bc.mb:push() bc.mb:translate(14, -1.8, 0) bc.mb:rotateZ(0.3)
            bc:box(-6, -0.4, -3.5, 6, 0.2, 3.5)
            bc.mb:pop()
            bc:mat("concrete", 0.55, 0.55, 0.55)
            bc:solid(-26, -7, -3.5, -21, 0.2, 3.5)
            bc:solid(21, -7, -3.5, 26, 0.2, 3.5)
            bc:box(-2, -8, -2, 2, -2.5, 2)
        end
    end
end

-- concrete bridge sides and railings over the intact crossings
local function buildBridges()
    for _, br in ipairs(W.bridges) do
        if not br.broken then
            local rot = math.atan2(br.tz, br.tx)
            local half = br.road.half
            local bic = W.ctx(br.x, br.z, rot, { y = br.h })
            bic:mat("rust", 0.6, 0.55, 0.5)
            for s = -1, 1, 2 do
                local zz = s * (half + 0.6)
                bic:beam(-22, 1.0, zz, 22, 1.0, zz, 0.12)
                for x = -22, 22, 4 do bic.mb:box(x - 0.08, 0, zz - 0.08, x + 0.08, 1.0, zz + 0.08) end
                bic:mat("concrete", 0.55, 0.55, 0.55)
                bic:box(-23, -6, zz - 0.35, 23, 0.05, zz + 0.35)
                bic:mat("rust", 0.6, 0.55, 0.5)
            end
        end
    end
end

local function buildCity()
    local L = W.city
    -- central square with the monument, kiosks and a stranded bus
    local sqx, sqz = L.x - 70, L.z + 10
    take(sqx, sqz, 26, 26)
    B.monument(W.ctx(sqx, sqz, pi / 2))
    local kiosk = W.ctx(sqx + 14, sqz - 12, 0)
    B.shop(kiosk, 5, 4, rng, G, { h = 2.6, tint = { 0.4, 0.55, 0.6 }, label = "KIOSK", shelves = false })
    Props.truck(V(sqx - 12, sqz + 14, 0.2), 0, 0, 0, true)
    Props.car(V(sqx + 8, sqz + 16, 1.4), 0, 0, 0)
    fireBarrel(W.ctx(sqx - 6, sqz - 9, 0), 0, 0)
    -- blocks on a loose grid, turned to face the nearest street
    local count = 0
    local types = {}
    for gx = -280, 280, 52 do
        for gz = -280, 280, 46 do
            local x, z = L.x + gx + rng:range(-6, 6), L.z + gz + rng:range(-6, 6)
            if U.dist2(x, z, L.x, L.z) < L.r * 0.95 then
                local k = rng:next()
                local done
                if k < 0.5 then
                    local s = rng:int(2, 4)
                    done = panelBlockAt(x, z, s, rng:int(4, 5), { damaged = rng:next() < 0.3, roadMargin = 4 })
                    if done then count = count + 1 end
                elseif k < 0.62 then
                    if free(x, z, 9, 7, 4) then
                        take(x, z, 9, 7)
                        B.shop(W.ctx(x, z, faceRoad(x, z)), 16, 11, rng, G, { label = "SHOP SHELVES", sign = rng:next() < 0.5 and "sign" or nil,
                            tint = { rng:range(0.6, 0.85), rng:range(0.6, 0.8), rng:range(0.55, 0.75) } })
                        done = true
                    end
                elseif k < 0.74 then
                    if free(x, z, 9, 8, 4) then
                        take(x, z, 9, 8)
                        B.ruin(W.ctx(x, z, faceRoad(x, z)), 16, 13, rng)
                        done = true
                    end
                elseif k < 0.82 then
                    local rot = faceRoad(x, z) + pi
                    local hx, hz = rotExtents(13, 4, rot)
                    if free(x, z, hx, hz, 4) then
                        take(x, z, hx, hz)
                        B.garageRow(W.ctx(x, z, rot), 7, rng, G)
                        done = true
                    end
                else
                    types[#types + 1] = { x, z }
                end
            end
        end
    end
    G.cityGlbSpots = types
    -- life in the yards: dead trees, wrecks, barricades
    for i = 1, 70 do
        local a, r = rng:range(0, 6.28), math.sqrt(rng:next()) * L.r * 0.9
        local x, z = L.x + math.cos(a) * r, L.z + math.sin(a) * r
        if okForTree(x, z, 7) then tree(rng:next() < 0.6 and "deadtree" or "birch", x, z, rng:range(0.8, 1.2)) end
    end
    local path = W.roadPaths[1]
    for i, p in ipairs(path) do
        if U.dist2(p.x, p.z, L.x, L.z) < L.r and i % 9 == 0 then
            local side = rng:next() < 0.5 and -1 or 1
            local off = path.road.half - 1.5
            local x, z = p.x - p.tz * off * side, p.z + p.tx * off * side
            local k = rng:next()
            if k < 0.45 then Props.car(V(x, z, math.atan2(p.tz, p.tx) + rng:range(-0.4, 0.4)), 0, 0, 0)
            elseif k < 0.6 then Props.truck(V(x, z, math.atan2(p.tz, p.tx) + rng:range(-0.3, 0.3)), 0, 0, 0, rng:next() < 0.5)
            elseif k < 0.8 then
                local rr = math.atan2(p.tz, p.tx) + pi / 2
                Props.sandbags(W.dctx(x, z, rr, "stone", 220, { crush = true }), -3, 0, 3, 0, 1.1)
            else Props.hedgehog(DM(x, z, 0), 0, 0) end
        end
    end
    Props.tankWreck(TW(L.x + 30, L.z - 60, 1.4), 0, 0, 0, true)
    container(W.ctx(L.x + 30, L.z - 60, 1.4), 0, 1.0, 1.7, "wreck", "WRECKAGE")
    Props.tankWreck(TW(L.x - 140, L.z + 150, 0.4), 0, 0, 0, false)
    -- people: bandits rule the east side, soldiers hold the square, survivors hide in the west
    npc(sqx + 3, sqz - 8, "military", "guard", "SOLDIER", nil, 0)
    npc(sqx - 4, sqz - 9, "military", "sit", "SOLDIER", nil, 1.5)
    npc(sqx - 8, sqz - 8, "military", "sit", "SOLDIER", nil, -0.3)
    npc(sqx + 10, sqz + 4, "military", "patrol", "SOLDIER", nil, 2)
    npc(L.x + 150, L.z - 90, "bandit", "guard", "BANDIT", nil, 0)
    npc(L.x + 160, L.z - 80, "bandit", "patrol", "BANDIT", nil, 0)
    npc(L.x + 120, L.z + 160, "bandit", "guard", "BANDIT", nil, 2)
    local hx, hz = L.x - 220, L.z - 40
    fireBarrel(W.ctx(hx, hz, 0), 0, 0)
    npc(hx + 1.6, hz, "loner", "sit", "SURVIVOR", "vasya", pi)
    npc(hx, hz + 1.6, "loner", "sit", "SURVIVOR", nil, -pi / 2)
    print(string.format("[gen] city: %d panel blocks", count))
end

local function planeWreck(ctx, x, z, rot)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot)
    ctx:mat("metal", 0.55, 0.6, 0.55)
    mb:cylinderX(-8, 7, 1.6, 0, 1.3, 1.1, 8)
    mb:cylinderX(7, 9, 1.6, 0, 1.1, 0.3, 8)
    mb:box(-1.5, 1.6, -11, 1.5, 1.8, -1.2)
    mb:box(-1.0, 0.5, 1.2, 1.2, 0.7, 8.5)          -- the broken wing lies in the snow
    mb:box(-8.5, 1.8, -3, -6.5, 2.0, 3)
    mb:box(-8.5, 1.8, -0.15, -6.5, 4.6, 0.15)
    ctx:mat("star", 1, 1, 1)
    mb:panel(-7.5, 2.8, 0.16, -6.6, 2.8, 0.16, -6.6, 3.7, 0.16, -7.5, 3.7, 0.16)
    ctx:mat("snow", 0.95, 0.97, 1)
    mb:box(-7, 2.75, -0.8, 6, 2.95, 0.8, { bottom = false })
    mb:pop()
    ctx:collider(x - 9, 0, z - 9, x + 9, 3, z + 9)
end

local function buildAirfield()
    local L = W.airfield
    -- runway, taxiway and apron
    local ry = W.height(L.x, L.z + 70)
    local rw = W.ctx(L.x, L.z + 70, 0)
    take(L.x, L.z + 70, 250, 22)
    rw:mat("concrete", 0.7, 0.71, 0.72)
    rw.mb.texScale = 0.15
    for i = -12, 11 do rw.mb:box(i * 20, -0.3, -20, i * 20 + 19.8, 0.08, 20, { bottom = false }) end
    rw:mat("snow", 0.92, 0.94, 0.98)
    for i = -12, 11, 2 do rw.mb:box(i * 20 + 2, 0.08, -1, i * 20 + 9, 0.1, 1, { bottom = false }) end
    for i = -12, 11 do
        if rng:next() < 0.4 then rw.mb:box(i * 20 + rng:range(0, 10), 0.08, rng:range(-18, 10), i * 20 + rng:range(10, 19), 0.13, rng:range(11, 19), { bottom = false }) end
    end
    rw.mb.texScale = 0.5
    local ap = W.ctx(L.x - 20, L.z - 45, 0)
    take(L.x - 20, L.z - 45, 120, 35)
    ap:mat("concrete", 0.66, 0.66, 0.66)
    ap.mb.texScale = 0.15
    for i = -6, 5 do ap.mb:box(i * 20, -0.3, -35, i * 20 + 19.8, 0.07, 35, { bottom = false }) end
    ap.mb:box(-12, -0.3, 35, 12, 0.07, 95, { bottom = false })
    ap.mb.texScale = 0.5
    -- hangars facing the apron, armour inside
    for i, x in ipairs({ -110, -40, 30, 100 }) do
        local hx, hz = L.x + x, L.z - 105
        take(hx, hz, 10, 13)
        local h = W.ctx(hx, hz, pi / 2)
        Props.hangar(h, 24, 18, rng)
        Props.tankWreck(TW(hx, hz - 2, pi / 2 + 0.05), 0, 0, 0, i == 2)
        container(h, -9, 0.1, 5, "military", "SPARE PARTS")
        container(h, -9, 0.1, -5, i % 2 == 0 and "armory" or "depot", i % 2 == 0 and "AMMO CRATE" or "TOOL CRATE")
        if i == 3 then pickup(h, -6, 0.1, -6, "repair_kit", 1, "repairkit") end
        if i == 1 then pickup(h, -6, 0.1, 6, "mg_ammo", 200, "mgbox") end
    end
    -- the tank park: rows of armour left to the snow
    for row = 0, 1 do
        for i = 0, 5 do
            local x, z = L.x - 230 + i * 14, L.z - 10 + row * 22
            take(x, z, 4, 3)
            Props.tankWreck(TW(x, z, -pi / 2 + rng:range(-0.1, 0.1)), 0, 0, 0, rng:next() < 0.3)
            if rng:next() < 0.35 then container(W.ctx(x, z, -pi / 2), 0, 1.8, 0, "depot", "TANK STOWAGE") end
        end
    end
    -- control tower: a small block with a glass cab
    local tx, tz = L.x + 175, L.z - 55
    local tc = panelBlockAt(tx, tz, 1, 3, { rot = pi, force = true, tint = { 0.85, 0.85, 0.82 }, loot = 0.8 })
    local cab = W.ctx(tx, tz, pi, { landmark = true, y = tc and tc.y })
    local topY = 0.35 + 3 * 2.8
    cab:mat("concrete", 0.7, 0.7, 0.7)
    cab.mb:box(-4, topY, -4, 4, topY + 0.6, 4)
    cab:mat("glass", 1, 1, 1)
    cab.mb:box(-3.6, topY + 0.6, -3.6, 3.6, topY + 2.8, 3.6)
    cab:mat("concrete", 0.6, 0.6, 0.6)
    cab.mb:box(-4.2, topY + 2.8, -4.2, 4.2, topY + 3.1, 4.2)
    cab:mat("metal", 0.4, 0.4, 0.4)
    cab:beam(0, topY + 3.1, 0, 0, topY + 7, 0, 0.12)
    G.light(cab, 0, topY + 7, 0, 1, 0.1, 0.05, 30, 1.5, "blink")
    -- barracks, fuel depot, wrecks
    for i, z in ipairs({ -160, -135 }) do
        local bx, bz = L.x + 175, L.z + z
        if free(bx, bz, 11, 5, 3) then
            take(bx, bz, 11, 5)
            local bctx = placeHouse(bx, bz, 0, 20, 8, { h = 3, mat = "plaster", door = true }, "military")
            Props.bed(bctx, -6, 2.6, 0) Props.bed(bctx, -2, 2.6, 0) Props.bed(bctx, 4, 2.6, 0)
            container(bctx, 7, 0.25, 2.5, "wardrobe", "LOCKER", { { "greatcoat", 1 }, { "ushanka", 1 } })
        end
    end
    for i = 0, 2 do
        local ft = W.dctx(L.x + 215, L.z - 170 + i * 9, 0, "metal", 300, { explode = true })
        Props.fuelTank(ft, 0, 0, 0, 12, 1.8)
    end
    take(L.x + 215, L.z - 160, 8, 15)
    pickup(W.ctx(L.x + 205, L.z - 175, 0), 0, 0, 0, "fuel", 1, "jerrycan")
    pickup(W.ctx(L.x + 205, L.z - 173, 0), 0, 0, 0, "fuel", 1, "jerrycan")
    planeWreck(W.ctx(L.x - 60, L.z + 130, 0), 0, 0, 0.6)
    take(L.x - 60, L.z + 130, 10, 10)
    for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local x, z = L.x + p[1] * 255, L.z + p[2] * 150
        if free(x, z, 2, 2, 2) then Props.watchtower(W.dctx(x, z, 0, "wood", 260), 0, 0) end
    end
    for i = 0, 3 do
        Props.sandbags(W.dctx(L.x + 60 + i * 40, L.z - 20, 0, "stone", 220, { crush = true }), -3, 0, 3, 0, 1.2)
    end
    fireBarrel(W.ctx(L.x + 150, L.z - 70, 0), 0, 0)
    -- the garrison
    npc(L.x + 152, L.z - 70, "military", "sit", "SOLDIER", nil, pi)
    npc(L.x + 148, L.z - 71, "military", "sit", "SOLDIER", nil, 0)
    npc(L.x + 160, L.z - 40, "military", "guard", "SOLDIER", nil, pi / 2)
    npc(L.x - 40, L.z - 70, "military", "patrol", "SOLDIER", nil, 0)
    npc(L.x + 60, L.z - 30, "military", "patrol", "SOLDIER", nil, pi)
    npc(L.x - 150, L.z - 5, "military", "guard", "SOLDIER", nil, pi / 2)
    npc(L.x + 30, L.z - 95, "military", "guard", "SOLDIER", nil, pi / 2)
end

local function buildBase()
    local L = W.base
    local cx, cz, R = L.x, L.z, 72
    take(cx, cz, R, R)
    local function wallLine(x0, z0, x1, z1)
        local len = U.dist2(x0, z0, x1, z1)
        local n = math.floor(len / 6)
        for i = 0, n - 1 do
            local ax, az = x0 + (x1 - x0) * i / n, z0 + (z1 - z0) * i / n
            local bx, bz = x0 + (x1 - x0) * (i + 1) / n, z0 + (z1 - z0) * (i + 1) / n
            local mx, mz = (ax + bx) / 2, (az + bz) / 2
            if W.roadDistance(mx, mz) > 9 then
                local c = W.dctx(mx, mz, 0, "stone", 420)
                Props.concreteWall(c, ax - mx, az - mz, bx - mx, bz - mz, 3.2)
            end
        end
    end
    wallLine(cx - R, cz - R, cx + R, cz - R)
    wallLine(cx + R, cz - R, cx + R, cz + R)
    wallLine(cx + R, cz + R, cx - R, cz + R)
    wallLine(cx - R, cz + R, cx - R, cz - R)
    for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        Props.watchtower(W.dctx(cx + p[1] * (R - 3), cz + p[2] * (R - 3), 0, "wood", 260), 0, 0)
    end
    for i, z in ipairs({ cz - 40, cz - 12, cz + 16 }) do
        local bctx = placeHouse(cx - 48, z, pi / 2, 20, 8, { h = 3, mat = "plaster", door = true, doorAt = 0.5 }, "military")
        Props.bed(bctx, -6, 2.6, 0) Props.bed(bctx, -2, 2.6, 0) Props.bed(bctx, 4, 2.6, 0)
        container(bctx, 7, 0.25, 2.6, "wardrobe", "LOCKER", i == 2 and { { "greatcoat", 1 }, { "valenki", 1 } } or nil)
        if i == 2 then pickup(bctx, 6, 0.25, -2, "medkit", 1, "medkit") end
    end
    local h1 = W.ctx(cx + 42, cz - 22, pi)
    Props.hangar(h1, 24, 18, rng)
    Props.tankWreck(TW(cx + 40, cz - 22, pi + 0.1), 0, 0, 0, false)
    container(h1, -9, 0.1, 5, "military", "SPARE PARTS")
    pickup(h1, -9, 0.1, -5, "repair_kit", 1, "repairkit")
    local h2 = W.ctx(cx + 42, cz + 18, pi)
    Props.hangar(h2, 24, 18, rng)
    Props.truck(h2, 1, 0, -2, false)
    container(h2, -9, 0.1, 4, "armory", "AMMO CRATE").loot = { { "he_shell", 3 }, { "ap_shell", 2 } }
    pickup(h2, -8, 0.1, -5, "mg_ammo", 200, "mgbox")
    for _, t in ipairs({ { 0, 0, 0, 12, 1.8 }, { 0, 7, 0, 12, 1.8 }, { 16, 3, pi / 2, 10, 1.6 } }) do
        local ft = W.dctx(cx - 30, cz + 50, 0, "metal", 300, { explode = true })
        Props.fuelTank(ft, t[1], t[2], t[3], t[4], t[5])
    end
    local fd = W.ctx(cx - 30, cz + 50, 0)
    pickup(fd, -8, 0, -4, "fuel", 1, "jerrycan")
    pickup(fd, -8.8, 0, -3.2, "fuel", 1, "jerrycan")
    local hq = placeHouse(cx - 22, cz - 52, 0, 14, 9, { h = 3.2, mat = "brick", door = true }, "military")
    Props.banner(hq, 3, 3.2, -4.7, -pi / 2, 2, 3)
    container(hq, 5, 0.25, 3, "military", "FILING CABINET").loot = { { "documents", 1 }, { "rifle_ammo", 10 } }
    local fpole = W.ctx(cx + 10, cz - 4, 0)
    fpole:mat("metal", 0.6, 0.6, 0.6)
    fpole.mb:cylinder(0, 0, 0, 0.08, 12, 0.06, 5)
    fpole:mat("cloth_red", 1, 1, 1)
    fpole.mb:panel(0.08, 9.5, 0, 0.08, 11.8, 0, 2.6, 11.6, 0.3, 2.6, 9.4, 0.3)
    Props.truck(V(cx + 20, cz + 46, 0.2), 0, 0, 0, true)
    Props.truck(V(cx + 26, cz + 52, 0.15), 0, 0, 0, false)
    fireBarrel(W.ctx(cx + 5, cz + 30, 0), 0, 0)
    npc(cx + 6.5, cz + 30, "military", "sit", "SOLDIER", nil, math.pi)
    npc(cx + 3.5, cz + 31, "military", "sit", "SOLDIER", nil, 0)
    npc(cx + 15, cz - 10, "military", "patrol", "SOLDIER", nil, 0)
    npc(cx - 20, cz + 25, "military", "guard", "SOLDIER", nil, 1.5)
    npc(cx + 40, cz + 5, "military", "guard", "SOLDIER", nil, pi)
    tent(cx + 8, cz + 36, 0.2, 2.4, 3.2, 1.7, "cloth", { 0.3, 0.32, 0.28 })
    Props.sandbags(W.dctx(cx, cz, 0, "stone", 220, { crush = true }), 18, 30, 24, 30, 1.1)
end

local function buildTower()
    local L = W.tower
    take(L.x, L.z, 24, 24)
    local m = W.ctx(L.x, L.z, 0, { landmark = true })
    Props.radioMast(m, 70, 4.5)
    W.towerTop = { x = L.x, y = m.y + 78, z = L.z }
    light(m, 0, 79, 0, 1.0, 0.1, 0.05, 40, 2.0, "blink")
    m:mat("metal", 0.5, 0.5, 0.5)
    for _, a in ipairs({ 0.4, 2.5, 4.6 }) do
        local ax, az = math.cos(a) * 38, math.sin(a) * 38
        local gy = W.height(L.x + ax, L.z + az) - m.y
        m:beam(0, 45, 0, ax, gy, az, 0.05)
        m:beam(0, 25, 0, ax, gy, az, 0.05)
    end
    local s = W.ctx(L.x + 14, L.z + 12, -pi / 2)
    Props.house(s, 6, 5, { h = 2.7, mat = "brick", empty = true }, rng)
    s:mat("metal", 0.45, 0.5, 0.45)
    s:solid(1.4, 0.25, 0.8, 2.7, 1.6, 2.2)
    s:mat("gauge", 1, 1, 1)
    s.mb:quad(1.39, 1.0, 1.0, 1.39, 1.4, 1.0, 1.39, 1.4, 1.4, 1.39, 1.0, 1.4)
    s.mb:quad(1.39, 1.0, 1.6, 1.39, 1.4, 1.6, 1.39, 1.4, 2.0, 1.39, 1.0, 2.0)
    local tx, ty, tz = s:toWorld(1.2, 1.2, 1.5)
    W.transmitter = { x = tx, y = ty, z = tz }
    Props.table(s, -1.2, 1.2, 0)
    container(s, -2.5, 0.25, -1.6, "military", "LOCKER").loot = { { "battery", 2 }, { "antirad", 1 }, { "medkit", 1 } }
    light(s, 0, 2.4, 0, 0.9, 0.7, 0.4, 6, 0.8, true)
    door(s, -0.55, 0.25, -2.5, 0, 1.1, 2.1)
    Props.fence(DM(L.x, L.z, 0), -22, -22, 22, -22, 2.2, "metal")
    Props.fence(DM(L.x, L.z, 0), 22, -22, 22, 22, 2.2, "metal")
    Props.fence(DM(L.x, L.z, 0), -22, 22, -22, -22, 2.2, "metal")
    Props.truck(V(L.x - 18, L.z + 30, 2.2), 0, 0, 0, true)
    npc(L.x + 6, L.z + 18, "military", "patrol", "SOLDIER", nil, 0)
    npc(L.x + 20, L.z + 8, "military", "guard", "SOLDIER", nil, -1.2)
end

local BUNKER_MAP = [[
###############
#E..#.....#.SS#
#...D.....D...#
#...#..T..#.C.#
##.##.....#.A.#
##.##..K..#####
##.##.....#.BB#
##.########...#
##...L........#
#####.#####.BB#
#####.#########
#G..........X.#
#..C......L...#
###############
]]

local function buildBunker()
    local L = W.bunker
    take(L.x, L.z, 15, 15)
    local h = W.height(L.x, L.z)
    local e = W.ctx(L.x, L.z, -0.75)
    e:mat("concrete", 0.6, 0.6, 0.62)
    e:solid(-4, 0, -8, 4, 3.6, -7)
    e:solid(-4, 0, -7, -3.2, 3.6, 0)
    e:solid(3.2, 0, -7, 4, 3.6, 0)
    e:solid(-4, 3.2, -7, 4, 4.0, 0.5)
    e:mat("snow", 0.95, 0.97, 1)
    e.mb:hexa({ { -10, -1, -22 }, { 10, -1, -22 }, { 10, -1, -6 }, { -10, -1, -6 },
                { -5, 6, -16 }, { 5, 6, -16 }, { 5, 4.2, -7 }, { -5, 4.2, -7 } })
    e:collider(-9, -1, -21, 9, 5, -7)
    e:mat("hazard", 1, 1, 1)
    e:box(-3.2, 3.2, -0.05, 3.2, 3.6, 0.05)
    e:mat("sign", 1, 1, 1)
    e.mb:panel(4.05, 1.8, -1.5, 4.05, 1.8, -0.5, 4.05, 2.8, -0.5, 4.05, 2.8, -1.5)
    local oy = h - 45
    local ox, oz = L.x - 10, L.z - 30
    local ictx, markers, iw, ih = tileInterior(BUNKER_MAP, ox, oy, oz, 2.5, 3.0, { wall = "concrete", wr = 0.6, wg = 0.65, wb = 0.58, underground = true })
    W.underground[#W.underground + 1] = { ox - 2, oy - 5, oz - 2, ox + iw + 2, oy + 8, oz + ih + 2, name = "bunker" }
    W.bunkerInfo = { ox = ox, oy = oy, oz = oz }
    local exitPos
    for _, mk in ipairs(markers) do
        local mx, mz = mk.x, mk.z
        if mk.c == "E" then
            ictx:mat("concrete", 0.5, 0.5, 0.5)
            for k = 0, 4 do ictx:box(mx - 1.2, k * 0.25, mz - 1.2, mx + 1.2, k * 0.25 + 0.25, mz - 0.6) end
            exitPos = { mx, mz }
            ictx:mat("metal", 0.45, 0.5, 0.45)
            ictx.mb:box(mx - 1.0, 1.25, mz - 1.24, mx + 1.0, 3.0, mz - 1.2)
            light(ictx, mx, 2.7, mz, 0.6, 0.8, 0.5, 7, 1.0, true)
        elseif mk.c == "L" then
            light(ictx, mx, 2.8, mz, 0.85, 0.75, 0.5, 9, 1.0, true)
            ictx:mat("metal", 1, 0.9, 0.7)
            ictx.mb:box(mx - 0.3, 2.85, mz - 0.1, mx + 0.3, 3.0, mz + 0.1)
        elseif mk.c == "S" then
            Props.shelf(ictx, mx, mz - 0.9, 0, 2.2)
        elseif mk.c == "C" then
            Props.crate(ictx, mx, 0, mz, 0.9)
            container(ictx, mx, 0.9, mz, "military", "SUPPLY CRATE")
        elseif mk.c == "A" then
            ictx:mat("crate", 0.7, 0.8, 0.6)
            ictx:solid(mx - 1, 0, mz - 0.6, mx + 1, 0.7, mz + 0.6)
            container(ictx, mx, 0.7, mz, "military", "ARMORY RACK").loot = { { "ap_shell", 4 }, { "he_shell", 4 }, { "mg_ammo", 300 } }
        elseif mk.c == "B" then
            Props.bed(ictx, mx, mz, 0)
        elseif mk.c == "T" then
            Props.table(ictx, mx, mz, 0)
            ictx:mat("paper", 1, 1, 1)
            ictx.mb:quad(mx - 0.5, 0.8, mz - 0.3, mx - 0.5, 0.8, mz + 0.3, mx + 0.4, 0.8, mz + 0.3, mx + 0.4, 0.8, mz - 0.3)
            light(ictx, mx, 2.7, mz, 0.9, 0.6, 0.3, 8, 1.1, true)
            ictx:mat("metal", 0.4, 0.45, 0.4)
            ictx:solid(mx - 1.2, 0, mz - 3.6, mx + 1.2, 1.4, mz - 3.0)
            ictx:mat("gauge", 1, 1, 1)
            ictx.mb:quad(mx - 0.8, 1.0, mz - 2.99, mx - 0.8, 1.35, mz - 2.99, mx - 0.4, 1.35, mz - 2.99, mx - 0.4, 1.0, mz - 2.99)
            local wx, wy, wz = ictx:toWorld(mx, 1.2, mz - 2.9)
            W.bunkerRadio = { x = wx, y = wy, z = wz }
        elseif mk.c == "K" then
            pickup(ictx, mx, 0, mz, "keycard", 1, "keycard")
            pickup(ictx, mx + 0.6, 0, mz + 0.4, "documents", 1, "documents")
        elseif mk.c == "G" then
            ictx:mat("metal", 0.45, 0.5, 0.42)
            ictx:solid(mx - 0.9, 0, mz - 0.6, mx + 1.5, 1.5, mz + 0.9)
            ictx:mat("hazard", 1, 1, 1)
            ictx.mb:box(mx - 0.92, 1.0, mz - 0.62, mx + 1.52, 1.2, mz + 0.92)
            pickup(ictx, mx + 2.2, 0, mz, "fuel", 1, "jerrycan")
            pickup(ictx, mx + 2.2, 0, mz + 0.8, "fuel", 1, "jerrycan")
        elseif mk.c == "D" then
            ictx:mat("metal", 0.5, 0.5, 0.48)
            ictx.mb:box(mx - 0.1, 2.4, mz - 1.25, mx + 0.1, 3.0, mz + 1.25)
        elseif mk.c == "X" then
            container(ictx, mx, 0.2, mz, "military", "DEAD SOLDIER'S KIT", { { "greatcoat", 1 }, { "rifle_ammo", 12 }, { "medkit", 1 } })
            ictx:mat("cloth", 0.32, 0.34, 0.26)
            ictx.mb:box(mx - 0.9, 0, mz - 0.25, mx + 0.8, 0.25, mz + 0.25)
        end
    end
    local ex, ey, ez = ictx:toWorld(exitPos[1], 0, exitPos[2])
    local doorOutX, doorOutZ = e:toWorld(0, 0, 1.6)
    door(e, -1.6, 0, -6.9, 0, 3.2, 3.1, { transition = { x = ex, y = ey, z = ez, yaw = math.pi / 2, inside = true }, label = "BLAST DOOR", mat = "metal", heavy = true })
    local inDoor = W.ctx(ox, oz, 0, { interior = true, y = oy })
    local d2 = door(inDoor, exitPos[1] - 1.0, 1.25, exitPos[2] - 1.15, 0, 2.0, 1.75,
        { transition = { x = doorOutX, y = W.height(doorOutX, doorOutZ), z = doorOutZ, yaw = -0.75 + math.pi / 2 }, label = "BLAST DOOR", mat = "metal", heavy = true })
    d2.interior = true
end

local CONTROL_MAP = [[
##########
#........#
#.L..R.L.#
#........#
###.##.###
O......#.#
#..C...#.#
##########
]]

local function buildPlant()
    local L = W.plant
    take(L.x, L.z, 110, 90)
    for _, c in ipairs({ { -68, -43 }, { 52, -55 } }) do
        local t = W.ctx(L.x + c[1], L.z + c[2], 0, { landmark = true })
        Props.coolingTower(t, 62, 26, 17, 19)
        W.emitters[#W.emitters + 1] = { x = L.x + c[1], y = t.y + 60, z = L.z + c[2], kind = "steam", rate = 1, acc = 0 }
    end
    local r = W.ctx(L.x - 10, L.z + 25, 0, { landmark = true })
    r:mat("concrete", 0.7, 0.7, 0.68)
    r:solid(-18, -1, -18, 18, 22, 18)
    r.mb:sphere(0, 22, 0, 15, 10, 15, 10, 5)
    r:mat("rubble", 0.4, 0.38, 0.36)
    r.mb:box(8, 22, -10, 16, 26, -2)
    r:mat("hazard", 1, 1, 1)
    r.mb:box(-18.05, 6, -6, -18.0, 7, 6)
    r:mat("plaster", 0.85, 0.85, 0.85)
    r.mb:cylinder(24, 0, 0, 2.2, 55, 1.6, 8, false)
    r:mat("cloth_red", 1, 1, 1)
    r.mb:cylinder(24, 45, 0, 1.75, 50, 1.68, 8, false)
    r:collider(21.8, 0, -2.2, 26.2, 55, 2.2)
    local th = W.ctx(L.x - 75, L.z + 35, 0)
    th:mat("concrete", 0.65, 0.66, 0.68)
    th:solid(-12, -1, -30, 12, 18, 30)
    for i = -4, 4 do Props.window(th, 12, 9, i * 6, 3, 5, "x+") end
    -- control building (enterable interior with locked door)
    local ax, az = L.x + 52, L.z + 43
    local ah = W.height(ax, az)
    local cell = 2.5
    local ox, oz = ax - 12.5, az - 10
    local sh = W.ctx(ax, az, 0, { y = ah })
    sh:mat("concrete", 0.72, 0.72, 0.7)
    local x0, x1, z0, z1 = -12.5 - 0.3, 12.5 + 0.3, -10 - 0.3, 10 + 0.3
    sh.mb:box(x0, -1, z0, x1, 7.2, z0 + 0.3)
    sh.mb:box(x0, -1, z1 - 0.3, x1, 7.2, z1)
    sh.mb:box(x1 - 0.3, -1, z0, x1, 7.2, z1)
    local doorZ = -10 + 5 * cell + cell / 2
    sh.mb:box(x0, -1, z0, x0 + 0.3, 7.2, doorZ - 1.2)
    sh.mb:box(x0, -1, doorZ + 1.2, x0 + 0.3, 7.2, z1)
    sh.mb:box(x0, 2.4, doorZ - 1.2, x0 + 0.3, 7.2, doorZ + 1.2)
    sh:mat("roof", 0.8, 0.8, 0.85)
    sh.mb:box(x0, 7.2, z0, x1, 7.6, z1)
    for i = -2, 2 do Props.window(sh, i * 4.5, 4.2, z0, 2, 1.6, "z-") end
    sh:mat("sign", 1, 1, 1)
    sh.mb:panel(x0 - 0.05, 2.8, doorZ - 1.5, x0 - 0.05, 2.8, doorZ + 1.5, x0 - 0.05, 3.8, doorZ + 1.5, x0 - 0.05, 3.8, doorZ - 1.5)
    local ictx, markers = tileInterior(CONTROL_MAP, ox, ah, oz, cell, 3.4, { wall = "plaster", wr = 0.7, wg = 0.75, wb = 0.7, floor = "concrete" })
    for _, mk in ipairs(markers) do
        if mk.c == "L" then
            light(ictx, mk.x, 3.1, mk.z, 0.4, 0.9, 0.6, 10, 1.0, true)
        elseif mk.c == "R" then
            ictx:mat("metal", 0.45, 0.5, 0.45)
            ictx:solid(mk.x - 5, 0, mk.z - 2.6, mk.x + 5, 1.6, mk.z - 1.6)
            ictx:mat("gauge", 1, 1, 1)
            for k = -4, 4 do
                ictx.mb:quad(mk.x + k - 0.3, 1.0, mk.z - 1.59, mk.x + k - 0.3, 1.5, mk.z - 1.59, mk.x + k + 0.3, 1.5, mk.z - 1.59, mk.x + k + 0.3, 1.0, mk.z - 1.59)
            end
            local wx, wy, wz = ictx:toWorld(mk.x, 1.2, mk.z - 1.5)
            W.signalConsole = { x = wx, y = wy, z = wz }
            light(ictx, mk.x, 1.8, mk.z - 1.2, 1.0, 0.2, 0.1, 5, 1.2, "blink")
        elseif mk.c == "C" then
            container(ictx, mk.x, 0, mk.z, "military", "EMERGENCY LOCKER").loot = { { "antirad", 3 }, { "medkit", 2 } }
            Props.crate(ictx, mk.x, 0, mk.z - 0.8, 0.8, "metal")
        end
    end
    door(W.ctx(ax, az, 0, { y = ah }), -12.5 - 0.15, 0, doorZ + 1.1, -math.pi / 2, 2.2, 2.4,
        { locked = "keycard", label = "CONTROL BLOCK DOOR", mat = "metal", heavy = true })
    W.controlRoom = { x0 = ox, z0 = oz, x1 = ox + 25, z1 = oz + 20, y = ah }
    W.shelters[#W.shelters + 1] = { ox, ah - 1, oz, ox + 25, ah + 4, oz + 20 }
    for _, s in ipairs({ { -100, 70, 100, 70 }, { 100, 70, 100, -90 }, { -100, 70, -100, -90 } }) do
        local len = U.dist2(s[1], s[2], s[3], s[4])
        local n = math.floor(len / 12)
        for i = 0, n - 1 do
            local ax0, az0 = s[1] + (s[3] - s[1]) * i / n, s[2] + (s[4] - s[2]) * i / n
            local bx0, bz0 = s[1] + (s[3] - s[1]) * (i + 0.85) / n, s[2] + (s[4] - s[2]) * (i + 0.85) / n
            local mx, mz = L.x + (ax0 + bx0) / 2, L.z + (az0 + bz0) / 2
            if W.roadDistance(mx, mz) > 8 and math.abs(mx - W.riverX(mz)) > 14 then
                Props.fence(DM(mx, mz, 0), ax0 + L.x - mx, az0 + L.z - mz, bx0 + L.x - mx, bz0 + L.z - mz, 2.4, "metal")
            end
        end
    end
    for i, p in ipairs({ { -130, 140 }, { -170, 100 }, { -210, 65 } }) do
        local pyl = W.ctx(L.x + p[1], L.z + p[2], 0.6, { landmark = true })
        pyl:mat("rust", 0.55, 0.5, 0.48)
        for _, l in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do pyl:beam(l[1] * 3, 0, l[2] * 3, l[1] * 0.8, 24, l[2] * 0.8, 0.25) end
        pyl:beam(-6, 22, 0, 6, 22, 0, 0.3)
        pyl:beam(-4.5, 17, 0, 4.5, 17, 0, 0.3)
        pyl:collider(-3, 0, -3, 3, 24, 3)
    end
    Props.truck(V(L.x + 10, L.z + 65, 0.8), 0, 0, 0, true)
    Props.car(V(L.x + 30, L.z + 57, 2.0), 0, 0, 0)
    Props.tankWreck(TW(L.x - 30, L.z + 75, 2.5), 0, 0, 0, false)
    container(W.ctx(L.x - 30, L.z + 75, 2.5), 2.5, 0.6, 2.0, "wreck", "WRECKAGE")
    fireBarrel(W.ctx(L.x + 20, L.z + 50, 0), 0, 0)
    pickup(W.ctx(L.x + 35, L.z + 53, 0), 0, 0, 0, "antirad", 1, "medkit")
    for i = 1, 4 do
        local sx, sz = L.x + rng:range(-60, 60), L.z + rng:range(-40, 50)
        Props.sign(DW(sx, sz, 0), 0, 0, rng:range(0, 6), "hazard")
    end
    W.radZones[#W.radZones + 1] = { x = L.x - 10, z = L.z + 25, r = 75, strength = 2.2 }
    W.radZones[#W.radZones + 1] = { x = L.x - 10, z = L.z + 25, r = 170, strength = 0.5 }
    npc(L.x + 22, L.z + 52, "military", "sit", "SOLDIER", nil, pi)
    npc(L.x + 18, L.z + 49, "military", "guard", "SOLDIER", nil, 0)
    npc(L.x + 40, L.z + 70, "military", "patrol", "SOLDIER", nil, 0)
end

---------------------------------------------------------------------------
-- the land between: forests, fields, hamlets and the last war's battlefields
---------------------------------------------------------------------------
local function buildWilderness()
    roadPoles(W.roadPaths[1], 34, 9.5)
    roadPoles(W.roadPaths[2], 32, -8)
    roadPoles(W.roadPaths[5], 36, 8)
    -- forests and groves across the map (a noise mask keeps fields open between them)
    local placed = 0
    for i = 1, 26000 do
        local x, z = rng:range(-W.LIMIT, W.LIMIT), rng:range(-W.LIMIT, W.LIMIT)
        local n = U.fbm(x / 380 + 3, z / 380 - 7, 3, 61)
        local dense = U.smoothstep(0.5, 0.68, n)
        if rng:next() < 0.04 + dense * 0.96 and okForTree(x, z, 11) and not nearLocation(x, z) then
            local k = rng:next()
            local kind = k < 0.4 and "pine" or (k < 0.7 and "spruce" or (k < 0.85 and "birch" or "deadtree"))
            tree(kind, x, z, rng:range(0.8, 1.4))
            placed = placed + 1
        end
        if i % 2000 == 0 and coroutine.isyieldable() then coroutine.yield("forests", i / 26000) end
    end
    grove(-900, 1500, 260, 900, { 0.4, 0.4, 0.1 })
    grove(-1300, -300, 300, 900, { 0.3, 0.5, 0.1 })
    grove(600, -800, 250, 700, { 0.4, 0.3, 0.2 })
    grove(1500, 300, 260, 800, { 0.5, 0.3, 0.1 })
    grove(-600, -1300, 300, 700, { 0.3, 0.4, 0.1 })
    -- bushes, stumps, rocks, dry grass
    for i = 1, 9000 do
        local x, z = rng:range(-W.LIMIT, W.LIMIT), rng:range(-W.LIMIT, W.LIMIT)
        if okForTree(x, z, 7) and not nearLocation(x, z, 0.7) then
            local k = rng:next()
            local y = W.height(x, z)
            if k < 0.35 then W.addInstance("bush", x, y, z, rng:range(0, 6.28), rng:range(0.7, 1.4), rng:range(0.85, 1.05))
            elseif k < 0.5 then W.addInstance("stump", x, y, z, rng:range(0, 6.28), rng:range(0.8, 1.3), 1)
            elseif k < 0.62 then
                local s = rng:range(0.6, 2.4)
                W.addInstance("rock", x, y, z, rng:range(0, 6.28), s, rng:range(0.85, 1.05))
                W.colliders:add({ x - s * 0.8, y - 1, z - s * 0.8, x + s * 0.8, y + s * 0.9, z + s * 0.8, walk = true })
            end
        end
    end
    for i = 1, 30000 do
        local x, z = rng:range(-W.LIMIT, W.LIMIT), rng:range(-W.LIMIT, W.LIMIT)
        if W.roadDistance(x, z) > 7 and math.abs(x - W.riverX(z)) > 16 then
            W.addInstance("grass", x, W.height(x, z), z, rng:range(0, 3.14), rng:range(0.6, 1.3), rng:range(0.85, 1.1))
        end
        if i % 5000 == 0 and coroutine.isyieldable() then coroutine.yield("grass", i / 30000) end
    end
    -- lonely hamlets: a few huts, a well, a fence
    for _, h in ipairs({ { -1100, 1100 }, { 900, 1450 }, { 1500, -1000 }, { -500, 200 }, { 500, -650 }, { -1550, 700 }, { 1450, 250 }, { -300, -1150 } }) do
        local n = rng:int(2, 4)
        for k = 1, n do
            local x, z = h[1] + rng:range(-30, 30), h[2] + rng:range(-30, 30)
            if free(x, z, 6, 6, 8) then
                take(x, z, 6, 6)
                placeHouse(x, z, rng:int(0, 3) * pi / 2, rng:range(6, 8), rng:range(5.5, 7), { ruined = rng:next() < 0.35, door = rng:next() < 0.5 }, "house")
            end
        end
    end
    -- battlefields of the last war: knocked-out armour, hedgehogs, sandbagged trenches
    for _, bf in ipairs({ { 350, 1350 }, { -450, 900 }, { 900, 200 }, { -800, -250 }, { 450, -1300 }, { -1000, 1300 } }) do
        for k = 1, 3 do
            local x, z = bf[1] + rng:range(-60, 60), bf[2] + rng:range(-60, 60)
            if free(x, z, 4, 4, 6) then
                take(x, z, 4, 4)
                Props.tankWreck(TW(x, z, rng:range(0, 6.28)), 0, 0, 0, rng:next() < 0.4)
                if rng:next() < 0.4 then container(W.ctx(x, z, 0), 0, 1.8, 0, "wreck", "WRECKAGE") end
            end
        end
        for k = 1, 6 do
            local x, z = bf[1] + rng:range(-80, 80), bf[2] + rng:range(-80, 80)
            if free(x, z, 2, 2, 4) then Props.hedgehog(DM(x, z, 0), 0, 0) end
        end
        local x, z = bf[1] + rng:range(-40, 40), bf[2] + rng:range(-40, 40)
        if free(x, z, 6, 2, 4) then
            Props.sandbags(W.dctx(x, z, rng:range(0, 3), "stone", 220, { crush = true }), -5, 0, 5, 0, 1.1)
        end
    end
    -- traffic that never arrived
    local path = W.roadPaths[1]
    for i = 1, #path, 55 do
        local p = path[i]
        if not nearLocation(p.x, p.z, 1.2) and rng:next() < 0.7 then
            local side = rng:next() < 0.5 and -1 or 1
            local off = path.road.half + rng:range(3.5, 7)
            local x, z = p.x - p.tz * off * side, p.z + p.tx * off * side
            local k = rng:next()
            if k < 0.5 then Props.car(V(x, z, math.atan2(p.tz, p.tx) + rng:range(-0.25, 0.25)), 0, 0, 0)
            else
                Props.truck(V(x, z, math.atan2(p.tz, p.tx) + rng:range(-0.2, 0.2)), 0, 0, 0, rng:next() < 0.5)
                if rng:next() < 0.5 then container(W.ctx(x, z, math.atan2(p.tz, p.tx)), -1, 1.2, 0, "military", "TRUCK BED") end
            end
        end
    end
    -- crater with radiation in the middle of the fields
    W.radZones[#W.radZones + 1] = { x = 600, z = 250, r = 22, strength = 1.0 }
    print(string.format("[gen] wilderness: %d trees", placed))
end

-- snow drifts blown across the roads between the places: the tank has to plough through them
local function buildDrifts()
    W.drifts = {}
    for _, path in ipairs(W.roadPaths) do
        local road = path.road
        local nextD = rng:range(80, 200)
        for i, p in ipairs(path) do
            if p.d >= nextD then
                nextD = p.d + rng:range(110, 260)
                local nearBridge = false
                for _, b in ipairs(W.bridges) do if U.dist2(p.x, p.z, b.x, b.z) < 45 then nearBridge = true end end
                if not nearLocation(p.x, p.z, 0.8) and not nearBridge and U.dist2(p.x, p.z, W.START.x, W.START.z) > 140 then
                    local off = rng:range(-0.3, 0.3) * road.half
                    local x, z = p.x - p.tz * off, p.z + p.tx * off
                    W.drifts[#W.drifts + 1] = { x = x, z = z, y = p.h + road.lift - 0.06, yaw = math.atan2(p.tz, p.tx),
                        w = rng:range(3.2, 6.0), l = rng:range(1.4, 2.3) * road.half, h0 = rng:range(0.6, 1.25), h = 1 }
                end
            end
        end
    end
    print(string.format("[gen] %d snow drifts on the roads", #W.drifts))
end

-- people on the move between places
local function buildSquads()
    local function loc(id, dx, dz) local l = W[id] return { l.x + (dx or 0), l.z + (dz or 0) } end
    squad("military", 3, { loc("airfield", -140, -40), { 700, -350 }, { 300, -250 }, loc("city", 120, 80), { -150, -760 },
        { 200, -900 }, loc("tower", 0, 30), { 200, -900 }, loc("city", 120, 80), { 300, -250 } }, "ARMY PATROL")
    squad("military", 3, { loc("base", 0, 60), { -850, -700 }, { -500, -600 }, loc("city", -60, 40), { -60, -110 }, { 170, 230 },
        { 330, 560 }, loc("checkpoint", 0, 0), { 330, 560 }, { 170, 230 }, loc("city", -60, 40) }, "ARMY PATROL")
    squad("bandit", 3, { loc("garages", 0, -46), { 260, 760 }, { -60, 700 }, loc("town", 30, 0), { -960, 500 }, loc("industrial", 0, 20),
        { -960, 500 }, loc("town", 30, 0), { -60, 700 } }, "BANDIT GANG")
    squad("bandit", 2, { loc("industrial", 0, 20), { -1160, 320 }, { -1350, -100 }, loc("base", 120, 120), { -1350, -100 } }, "BANDIT SCOUTS")
    squad("loner", 2, { loc("camp", 10, 0), { -440, 1300 }, loc("kolkhoz", 0, 0), { 30, 1720 }, loc("station", -30, 0), { 150, 935 },
        loc("station", -30, 0), { 30, 1720 }, loc("kolkhoz", 0, 0) }, "SURVIVORS")
    squad("loner", 2, { loc("town", -80, -45), { -400, 620 }, { 260, 760 }, loc("garages", 0, 30), { 760, 760 }, loc("forest", -60, 0),
        { 760, 760 }, loc("garages", 0, 30), { 260, 760 } }, "SCAVENGERS")
end

function G.build()
    rng = U.rng(W.SEED)
    nextId = 0
    taken = {}
    registerInstances()
    local steps = {
        { "kolkhoz", buildKolkhoz }, { "camp", buildCamp }, { "checkpoint", buildCheckpoint }, { "garages", buildGarages },
        { "town", buildTown }, { "industrial", buildIndustrial }, { "city", buildCity }, { "airfield", buildAirfield },
        { "base", buildBase }, { "tower", buildTower }, { "bunker", buildBunker }, { "plant", buildPlant },
        { "bridges", buildBridges }, { "forest", buildForest },
        { "station", function() require("src.world_psx").build(G, rng) end },
        { "wilderness", buildWilderness }, { "squads", buildSquads }, { "drifts", buildDrifts },
        { "roads", W.buildRoadMeshes },
    }
    for i, s in ipairs(steps) do
        local t0 = love.timer.getTime()
        s[2]()
        if os.getenv("STEEL_TIMING") then print(string.format("[timing]   %-12s %.2f s", s[1], love.timer.getTime() - t0)) end
        if coroutine.isyieldable() then coroutine.yield(s[1], 0.3 + i / #steps * 0.45) end
    end
end

return G
