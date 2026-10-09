-- World content built from the imported PSX model packs: the abandoned fuel station,
-- roadside wrecks, forest clutter and the lairs of the walkers and giant spiders.
-- Runs as the last world-gen step so existing object and spawn ids stay stable.
local W = require("src.world")
local Props = require("src.props")
local PA = require("src.psx_assets")
local Gltf = require("src.engine.gltf")

local X = {}
local pi = math.pi

local SNOW = { 0.95, 0.97, 1 }
local COLD = { 0.82, 0.86, 0.95 }      -- frost-bitten tint for imported props

local function snowCap(ctx, x0, z0, x1, z1, y, h)
    ctx:mat("snow", SNOW[1], SNOW[2], SNOW[3])
    ctx.mb:box(x0, y, z0, x1, y + (h or 0.06), z1, { bottom = false })
end

-- a wrecked car/pickup as a destructible vehicle (burns out when shot up)
local function wreck(Gen, name, x, z, rot)
    local c = W.dctx(x, z, rot, "vehicle", 380, {})
    PA.put(c, "vehicles", name, 0, 0, 0, 0, 1, COLD)
    local x0, y0, z0, x1, y1, z1 = PA.bounds("vehicles", name)
    c:collider(x0 + 0.1, 0, z0 + 0.05, x1 - 0.1, y1 - 0.25, z1 - 0.05)
    snowCap(c, -0.9, z0 + 0.25, 0.7, z1 - 0.25, y1 - 0.02, 0.07)
    snowCap(c, x1 - 1.3, z0 + 0.2, x1 - 0.25, z1 - 0.2, y1 * 0.64, 0.05)
    return c
end
X.wreck = wreck

local function buildStation(Gen, rng)
    local L = W.station
    -- local +x points at the main road (west of the station)
    local c = W.ctx(L.x, L.z, pi)
    c:flatten(-17, -9, 10, 9, 0)
    local put = function(name, x, y, z, rot, tint) PA.put(c, "gas_station_kit", name, x, y, z, rot, 1, tint or COLD) end

    -- forecourt: 4 x 3 slabs of concrete, oil-stained where the cars stood
    for i = 0, 3 do
        for j = -1, 1 do
            local x = -6 + i * 4
            put((i == 2 and j ~= 0) and "forecourt_oil" or "forecourt", x, 0.02, j * 4, (i + j) % 2 * pi)
        end
    end
    c:collider(-8, -0.4, -6, 8, 0.03, 6)
    -- drifts creeping over the slab edges
    snowCap(c, -8, -6.2, 8, -5.2, 0.03, 0.05)
    snowCap(c, 6.6, -6, 8.2, 6, 0.03, 0.05)
    snowCap(c, -8, 5.4, -1, 6.2, 0.03, 0.05)

    -- two pump islands under the canopy, each with a pump either side of its column
    for _, z in ipairs({ -4, 4 }) do
        put("pump_island", 2, 0.03, z, 0)
        put("canopy_column", 2, 0.18, z, 0)
        put("fuel_pump", 2, 0.18, z - 1.25, 0)
        put("fuel_pump", 2, 0.18, z + 1.25, pi)
        c:collider(1.4, 0, z - 2, 2.6, 0.18, z + 2)
        c:collider(1.75, 0.18, z - 0.25, 2.25, 4.8, z + 0.25)
        c:collider(1.7, 0.18, z - 1.65, 2.3, 2.2, z - 0.85, { walk = false })
        c:collider(1.7, 0.18, z + 0.85, 2.3, 2.2, z + 1.65, { walk = false })
        for _, bz in ipairs({ z - 2.3, z + 2.3 }) do
            put("bollard", 2, 0.03, bz, 0)
            c:collider(1.88, 0, bz - 0.12, 2.12, 1.1, bz + 0.12, { walk = false })
        end
    end
    -- canopy: 2 x 3 deck tiles at 4.78 m with a fascia all round and snow on top
    local cy = 4.78
    for _, x in ipairs({ 0, 4 }) do
        for _, z in ipairs({ -4, 0, 4 }) do put("canopy_deck", x, cy, z, 0) end
    end
    for _, z in ipairs({ -4, 0, 4 }) do
        put(z == 0 and "canopy_fascia_logo" or "canopy_fascia", 6, cy, z, 0)
        put("canopy_fascia", -2, cy, z, pi)
    end
    for _, x in ipairs({ 0, 4 }) do
        put("canopy_fascia", x, cy, 6, pi / 2)
        put("canopy_fascia", x, cy, -6, -pi / 2)
    end
    for _, k in ipairs({ { 6, 6, 0 }, { -2, 6, pi / 2 }, { -2, -6, pi }, { 6, -6, -pi / 2 } }) do put("canopy_corner", k[1], cy, k[2], k[3]) end
    snowCap(c, -1.9, -5.9, 5.9, 5.9, cy + 0.6, 0.22)
    c:collider(-2, cy - 0.05, -6, 6, cy + 0.8, 6)

    -- shop: the kit's glazed front, a plain block built around it
    local sx, depth, h = -9, 6, 3
    for i = -2, 2 do
        local z = i * 2
        if i == 0 then
            put("wall_shopfront_doorway", sx, 0.03, z, pi)
        else
            put("wall_shopfront", sx, 0.03, z, pi)
            put("window_shop", sx, 0.03, z, pi)
        end
    end
    c:collider(sx - 0.1, 0, -5, sx + 0.1, h, -0.87)
    c:collider(sx - 0.1, 0, 0.87, sx + 0.1, h, 5)
    c:collider(sx - 0.1, 2.55, -0.87, sx + 0.1, h, 0.87)
    c.mb.maxEdge = 1.5
    c:mat("concrete", 0.72, 0.72, 0.7)
    c:solid(sx - depth, 0, -5.2, sx - 0.1, h, -5)                 -- side walls
    c:solid(sx - depth, 0, 5, sx - 0.1, h, 5.2)
    c:solid(sx - depth - 0.2, 0, -5.2, sx - depth, h, 5.2)       -- back wall
    c:mat("concrete", 0.5, 0.5, 0.5)
    c:solid(sx - depth - 0.4, h, -5.4, sx + 0.5, h + 0.25, 5.4)  -- roof slab
    c:mat("concrete", 0.42, 0.4, 0.38)
    c:solid(sx - depth, -0.3, -5, sx, 0.04, 5)                    -- floor
    c.mb.maxEdge = nil
    snowCap(c, sx - depth - 0.3, -5.3, sx + 0.4, 5.3, h + 0.25, 0.2)
    local a, b, d, e, f, g = c:worldBox(sx - depth, 0, -5, sx, h, 5)
    W.shelters[#W.shelters + 1] = { a, b, d, e, f, g }
    -- shop fittings and what is left on the shelves
    Props.shelf(c, sx - depth + 0.45, -3.4, pi / 2, 2.4)
    Props.shelf(c, sx - depth + 0.45, 2.6, pi / 2, 2.4)
    Props.shelf(c, sx - 3, 3.2, 0, 2.2)
    Props.crate(c, sx - 1.2, 0.04, -4.2, 0.8)
    Props.crate(c, sx - 2.1, 0.04, -4.3, 0.6)
    c:mat("wood", 0.5, 0.45, 0.4)
    c:solid(sx - 3.4, 0.04, -2.6, sx - 2.6, 1.05, -0.4)             -- counter
    Gen.container(c, sx - depth + 0.5, 0.9, -3.4, "house", "SHOP SHELVES")
    Gen.container(c, sx - 3.0, 1.1, -1.5, "house", "TILL", { { "shotgun_ammo", 12 }, { "pistol_ammo", 14 }, { "battery", 1 }, { "medkit", 1 } })
    Gen.pickup(c, sx - 2.0, 0.1, 3.4, "food", 2, "foodbox")
    Gen.light(c, sx - 3, 2.6, 0, 0.75, 0.85, 1.0, 7, 0.55, true)
    put("payphone", sx + 0.14, 0.03, 4.4, 0)

    -- clutter on the forecourt
    local v = function(name, x, y, z, rot, s) PA.put(c, "vehicles", name, x, y, z, rot, s or 1, COLD) end
    v("tire_stack", -7.2, 0.03, -5.2, 0.4)
    v("tire_stack", -6.4, 0.03, -5.4, 2.1)
    v("tire", -5.6, 0.03, -4.9, 0)
    v("tire", 6.9, 0.03, 2.2, 1.1)
    c:collider(-7.6, 0, -5.8, -6.0, 0.8, -4.8, { walk = false })
    for i, p in ipairs({ { 7.2, -5.2 }, { 7.3, -2.6 }, { 7.1, 0.3 }, { 5.2, 5.5 } }) do v("traffic_cone", p[1], 0.03, p[2], i) end
    v("hydrant", -8.4, 0.0, 5.6, 0)
    v("jerry_can", 2.5, 0.18, -4.4, 0.6)
    v("jerry_can", -8.3, 0.03, -3.6, 1.9)
    Gen.pickup(c, 2.4, 0.2, 3.55, "fuel", 1, "fuel")
    Gen.pickup(c, -8.2, 0.05, -3.1, "fuel", 1, "fuel")
    -- corrugated fence along the back of the lot, a few panels missing
    for i = -4, 5 do
        if i ~= 1 and i ~= -2 then
            v("fence_corrugated", -16.2, 0, i * 2 - 1, pi / 2)
            c:collider(-16.35, 0, i * 2 - 2, -16.1, 2.1, i * 2)
        end
    end

    -- the cars that never left
    wreck(Gen, "sedan_rusted", L.x - 5.2, L.z + 4.1, pi / 2 + 0.06)
    wreck(Gen, "pickup_red", L.x + 6.5, L.z - 7.5, 0.35)
    Gen.container(W.ctx(L.x + 6.5, L.z - 7.5, 0.35), -1.6, 0.9, 0, "wreck", "PICKUP BED")

    -- the walkers shamble around the pumps
    Gen.spawn(L.x - 2, L.z + 2, "zombie", 4, "station", { radius = 16 })
end

-- logs, stumps and boulders from the forest pack; dead trunks around the spider nest
local function buildClutter(Gen, rng)
    local F = W.forest
    local function scatter(name, cx, cz, radius, count, sMin, sMax, collide)
        for i = 1, count do
            local a = rng:range(0, 2 * pi)
            local r = math.sqrt(rng:next()) * radius
            local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
            local hits = W.colliders:query(x - 2, z - 2, x + 2, z + 2, {})
            if W.roadDistance(x, z) > 9 and math.abs(x - W.riverX(z)) > 16 and #hits == 0 then
                local s = rng:range(sMin, sMax)
                local c = W.ctx(x, z, rng:range(0, 2 * pi))
                PA.put(c, "forest", name, 0, -0.04, 0, 0, s, COLD)
                local x0, y0, z0, x1, y1, z1 = PA.bounds("forest", name, s)
                if collide then c:collider(x0 * 0.8, 0, z0 * 0.8, x1 * 0.8, y1 * 0.85, z1 * 0.8) end
                if name ~= "tree_dead" then snowCap(c, x0 * 0.55, z0 * 0.55, x1 * 0.55, z1 * 0.55, y1 * 0.9, 0.05) end
            end
        end
    end
    scatter("log", F.x, F.z, 110, 26, 0.9, 1.3, true)
    scatter("stump", F.x, F.z, 110, 30, 0.8, 1.4, true)
    scatter("boulder", F.x, F.z, 120, 22, 1.0, 2.4, true)
    scatter("log", -80, 420, 110, 10, 0.9, 1.2, true)
    scatter("stump", -420, 200, 130, 14, 0.8, 1.3, true)
    scatter("boulder", 0, 0, 560, 60, 1.0, 2.6, true)
    -- spider nest: a ring of dead trunks deep in the forest
    local nx, nz = F.x + 62, F.z - 58
    for i = 1, 9 do
        local a = i / 9 * 2 * pi + rng:range(-0.2, 0.2)
        local r = rng:range(7, 13)
        local c = W.ctx(nx + math.cos(a) * r, nz + math.sin(a) * r, rng:range(0, 6.28))
        PA.put(c, "forest", "tree_dead", 0, -0.05, 0, 0, rng:range(1.0, 1.5), { 0.7, 0.72, 0.8 })
        c:collider(-0.22, 0, -0.22, 0.22, 4, 0.22, { tree = true })
    end
    Gen.spawn(nx, nz, "spider", 3, "forest", { radius = 12 })
    Gen.spawn(-330, -70, "spider", 2, "industrial", { radius = 14 })
    Gen.spawn(-215, 250, "zombie", 3, "village", { radius = 18 })

    -- roadside wrecks
    wreck(Gen, "sedan_blue", 36, 168, 1.35)
    wreck(Gen, "sedan_rusted", -96, 323, 0.2)
    wreck(Gen, "pickup_red", 101, -332, -1.1)
    wreck(Gen, "sedan_rusted", -161, -128, 2.2)
end

-- a model from one of the user's .glb files, centred on its footprint and standing on the ground.
-- Returns the context and the half extents / height of the placed model.
local function placeGlb(file, node, x, z, rot, scale, opts)
    opts = opts or {}
    local asset = Gltf.load("assets/" .. file)
    local prims, x0, y0, z0, x1, y1, z1 = Gltf.collect(asset, node)
    local c = W.ctx(x, z, rot, { landmark = opts.landmark, y = opts.y })
    local tint = opts.tint or COLD
    c.mb:color(tint[1], tint[2], tint[3])
    c.mb:push()
    c.mb:translate(0, opts.lift or 0, 0)
    Gltf.emitPrims(c.mb, prims, scale, (x0 + x1) / 2, y0, (z0 + z1) / 2)
    c.mb:pop()
    local hx, hz, h = (x1 - x0) / 2 * scale, (z1 - z0) / 2 * scale, (y1 - y0) * scale
    if opts.collide then
        local k = opts.collide
        c:collider(-hx * k, 0, -hz * k, hx * k, h, hz * k, opts.props)
    end
    if opts.snow then snowCap(c, -hx * opts.snow, -hz * opts.snow, hx * opts.snow, hz * opts.snow, h + (opts.lift or 0), 0.25) end
    return c, hx, hz, h
end

-- the dead microdistrict west of the village: panel blocks around a yard, a stranded metro car,
-- a helicopter that never took off again
local function buildDistrict(Gen, rng)
    local L = W.district
    local has = function(f) return love.filesystem.getInfo("assets/" .. f) ~= nil end
    local PANELKA, KHRUSH, TOWER = "lowpoly_panelka_psx.glb", "soviet_khrushchyovka_-_ps1_style.glb", "psx_russian_soviet_housing_3d_model.glb"
    local BLOCKS, HELI, METRO = "russian_residential_blocks_spalny_rayon_psx.glb", "ps1low_poly_kamov_ka29_helix_helicopter.glb",
                                "low_poly_psx_style_soviet_subway_-_metro_props.glb"
    local wall = { 0.8, 0.82, 0.88 }
    if has(PANELKA) then
        placeGlb(PANELKA, nil, L.x - 6, L.z - 38, 0, 1, { collide = 0.97, tint = wall })
        placeGlb(PANELKA, nil, L.x + 4, L.z + 40, math.pi, 1, { collide = 0.97, tint = wall })
    end
    if has(KHRUSH) then
        placeGlb(KHRUSH, nil, L.x - 40, L.z + 2, 0, 1, { collide = 0.96, tint = wall })
        placeGlb(KHRUSH, nil, L.x + 38, L.z - 4, math.pi, 1, { collide = 0.96, tint = wall })
    end
    if has(TOWER) then
        placeGlb(TOWER, nil, L.x - 38, L.z + 44, 0.2, 1, { collide = 1, tint = wall })
        placeGlb(TOWER, nil, L.x + 40, L.z - 44, -0.3, 1, { collide = 1, tint = wall })
    end
    if has(BLOCKS) then
        -- a row of big slabs on the skyline behind the district, visible from far away
        placeGlb(BLOCKS, nil, L.x - 96, L.z + 6, 0, 4.5, { landmark = true, collide = 0.95, y = W.height(L.x - 96, L.z + 6) - 3, tint = { 0.7, 0.72, 0.8 } })
    end
    if has(HELI) then
        local c, hx, hz, h = placeGlb(HELI, nil, L.x + 6, L.z + 4, 0.7, 2, { collide = 0.55, tint = { 0.9, 0.9, 0.95 } })
        Gen.container(c, 0, 1.2, hz * 0.3, "military", "HELICOPTER CARGO")
    end
    if has(METRO) then
        local prop = function(node, dx, dz, rot, scale, collide, props)
            return placeGlb(METRO, node, L.x + dx, L.z + dz, rot, scale or 1, { collide = collide, props = props })
        end
        prop("SM_Metro", -14, -12, 0.35, 1, 0.92)
        local k = prop("SM_MagazineStand", 16, -20, 0.2, 1.1, 0.9)
        Gen.container(k, 0, 1.0, 0, "house", "NEWS KIOSK")
        local v = prop("SM_VendingMachine", 19, -21.5, 0.2, 1.1, 0.9, { walk = false })
        Gen.container(v, 0, 1.0, 0, "house", "VENDING MACHINE", { { "water", 2 }, { "food", 1 } })
        prop("SM_TrashBin02", 13, -19, 1.1, 1.2, 0.9, { walk = false })
        prop("SM_TrashBin01", -22, 16, 0.3, 1.2, 0.9, { walk = false })
        prop("SM_TrashBin01", 21, 20, 2.0, 1.2, 0.9, { walk = false })
        prop("SM_Barrel", -20, 18, 0, 1.2, 0.9, { walk = false })
        prop("SM_Barrel", -19, 19.2, 1.4, 1.2, 0.9, { walk = false })
        prop("SM_Table", 22, 18, 0.5, 1.2, 0.9)
        prop("SM_FloorSign", -9, -16, 2.2, 1.2)
        Gltf.release(Gltf.load("assets/" .. METRO))
    end
    for _, f in ipairs({ PANELKA, KHRUSH, TOWER, BLOCKS, HELI }) do
        if has(f) then Gltf.release(Gltf.load("assets/" .. f)) end
    end
    -- what else is lying around
    wreck(Gen, "sedan_rusted", L.x + 24, L.z + 4, 1.4)
    wreck(Gen, "sedan_blue", L.x - 4, L.z + 22, 0.1)
    Gen.pickup(W.ctx(L.x + 17, L.z - 18, 0), 0, 0.1, 0, "medkit", 1, "medkit")
    Gen.spawn(L.x, L.z, "zombie", 5, "district", { radius = 30 })
    Gen.npc(L.x - 12, L.z + 30, "bandit", "guard", "BANDIT", nil, 1.2)
    Gen.npc(L.x + 26, L.z - 26, "bandit", "guard", "BANDIT", nil, -2.0)
end

function X.build(Gen, rng)
    buildStation(Gen, rng)
    buildClutter(Gen, rng)
    if W.district then buildDistrict(Gen, rng) end
end

return X
