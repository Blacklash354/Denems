-- Places every location, prop, loot container, door and interior into the world.
local U = require("src.utils")
local W = require("src.world")
local Props = require("src.props")
local MB = require("src.engine.meshbuilder")

local G = {}
local pi = math.pi
local rng

local nextId = 0
local function id(prefix) nextId = nextId + 1 return prefix .. "_" .. nextId end

local LOOT = {
    house = { { "food", 0.55, 1, 2 }, { "water", 0.4, 1, 2 }, { "medkit", 0.15, 1, 1 }, { "rifle_ammo", 0.4, 5, 10 },
              { "antirad", 0.15, 1, 1 }, { "battery", 0.1, 1, 1 }, { "pistol_ammo", 0.25, 6, 12 } },
    military = { { "rifle_ammo", 0.6, 5, 15 }, { "mg_ammo", 0.45, 50, 150 }, { "medkit", 0.25, 1, 1 },
                 { "repair_kit", 0.2, 1, 1 }, { "food", 0.3, 1, 2 }, { "ap_shell", 0.15, 1, 2 }, { "he_shell", 0.15, 1, 2 } },
    industrial = { { "repair_kit", 0.3, 1, 1 }, { "battery", 0.3, 1, 1 }, { "tools", 0.35, 1, 1 }, { "antirad", 0.3, 1, 1 },
                   { "water", 0.3, 1, 2 }, { "rifle_ammo", 0.3, 5, 10 } },
    wreck = { { "mg_ammo", 0.3, 30, 90 }, { "fuel", 0.15, 1, 1 }, { "tools", 0.3, 1, 1 }, { "rifle_ammo", 0.3, 5, 10 } },
}

local function rollLoot(kind)
    local out = {}
    for _, e in ipairs(LOOT[kind] or LOOT.house) do
        if rng:next() < e[2] then out[#out + 1] = { e[1], rng:int(e[3], e[4]) } end
    end
    if #out == 0 then out[1] = { "food", 1 } end
    return out
end

-- containers/pickups are stored with world coordinates
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
    -- closed collider: panel from hinge along yaw direction
    local ex, ez = x + math.cos(yaw) * d.width, z + math.sin(yaw) * d.width
    local t = 0.12
    d.box = { math.min(x, ex) - t, y, math.min(z, ez) - t, math.max(x, ex) + t, y + d.height, math.max(z, ez) + t, walk = false }
    if not d.transition then W.colliders:add(d.box) end
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

local function spawn(x, z, kind, count, loc, opts)
    W.spawns[#W.spawns + 1] = { x = x, z = z, kind = kind, count = count or 1, loc = loc, y = opts and opts.y,
                                underground = opts and opts.underground, radius = opts and opts.radius or 25 }
end

local function placeHouse(x, z, rot, w, d, opts, lootKind)
    local ctx = W.ctx(x, z, rot)
    local info = Props.house(ctx, w, d, opts, rng)
    if not (opts and opts.noLoot) then
        local c = container(ctx, -w / 2 + 0.45, 0.25, -d / 2 + d * 0.3, lootKind or "house", "CUPBOARD")
        if opts and opts.extraLoot then for _, e in ipairs(opts.extraLoot) do table.insert(c.loot, e) end end
    end
    if opts and opts.door then
        door(ctx, w * (opts.doorAt or 0.5) - w / 2 - 0.55, 0.25, -d / 2, 0, 1.1, 2.1)
    end
    return ctx, info
end

local function trees(cx, cz, radius, count, pineRatio, minRoad)
    for i = 1, count do
        local a = rng:range(0, 2 * pi)
        local r = math.sqrt(rng:next()) * radius
        local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
        if math.abs(x) < W.LIMIT + 60 and math.abs(z) < W.LIMIT + 60 then
            local rd = W.roadDistance(x, z)
            local riv = math.abs(x - W.riverX(z))
            local list = W.colliders:query(x - 3, z - 3, x + 3, z + 3, {})
            local nearLoc = false
            for _, l in ipairs(W.locations) do
                if l.id ~= "forest" and U.dist2(x, z, l.x, l.z) < l.r * 0.9 then nearLoc = true end
            end
            if rd > (minRoad or 9) and riv > 16 and #list == 0 and not nearLoc then
                local y = W.height(x, z)
                local ctx = W.ctx(x, z, 0)
                ctx.mb:reset()
                local s = rng:range(0.8, 1.35)
                if rng:next() < pineRatio then Props.pine(ctx, x, y, z, s, rng)
                else Props.deadTree(ctx, x, y, z, s, rng) end
            end
        end
        if i % 200 == 0 and coroutine.isyieldable() then coroutine.yield("trees", i / count) end
    end
end

-- poles along roads
local function roadPoles(road, spacing, offset)
    for i = 1, #road - 1 do
        local a, b = road[i], road[i + 1]
        local dx, dz = b[1] - a[1], b[2] - a[2]
        local l = math.sqrt(dx * dx + dz * dz)
        local nx, nz = -dz / l, dx / l
        local n = math.floor(l / spacing)
        for k = 0, n - 1 do
            local t = k / n
            local x, z = a[1] + dx * t + nx * offset, a[2] + dz * t + nz * offset
            if math.abs(x - W.riverX(z)) > 16 then
                local ctx = W.ctx(x, z, math.atan2(dz, dx))
                if rng:next() > 0.12 then Props.pole(ctx, 0, 0, 0)
                else
                    -- fallen pole
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
    -- floor and ceiling slabs as colliders
    ctx:collider(0, -1, 0, Wd * cell, 0, H * cell)
    ctx:collider(0, height, 0, Wd * cell, height + 1, H * cell, { noPlayer = false })
    return ctx, markers, Wd * cell, H * cell
end

---------------------------------------------------------------------------
-- locations
---------------------------------------------------------------------------
local function buildVillage()
    local L = W.village
    local houseX = { -285, -262, -238, -214, -150, -126, -102 }
    for i, x in ipairs(houseX) do
        local zN = W.height(x, 284)
        local ruined = (i % 3 == 0)
        placeHouse(x, 283 + rng:range(-2, 2), pi, rng:range(7, 9), rng:range(6, 7.5),
            { ruined = ruined, door = not ruined and i % 2 == 0 }, "house")
    end
    for i, x in ipairs({ -275, -250, -226, -170, -140, -114, -90 }) do
        local ruined = (i % 4 == 1)
        placeHouse(x, 320 + rng:range(-2, 2), 0, rng:range(7, 9), rng:range(6, 7.5),
            { ruined = ruined, door = not ruined and i % 2 == 1, extraLoot = (i == 3) and { { "medkit", 1 } } or nil }, "house")
    end
    -- church on the north side
    local cctx = W.ctx(-196, 252, 0)
    Props.church(cctx, rng)
    -- well and square
    local s = W.ctx(-180, 302, 0)
    s:mat("concrete", 0.7, 0.7, 0.7)
    s.mb:cylinder(10, 0, -10, 1.2, 0.9, 1.2, 8)
    s:collider(8.8, 0, -11.2, 11.2, 0.9, -8.8)
    s:mat("wood", 0.5, 0.45, 0.4)
    s:beam(9, 0.9, -10, 9, 2.6, -10, 0.12) s:beam(11, 0.9, -10, 11, 2.6, -10, 0.12) s:beam(8.8, 2.6, -10, 11.2, 2.6, -10, 0.12)
    Props.billboard(s, 22, -22, -pi / 2, "cloth_red", 5, 3)
    Props.banner(W.ctx(-238, 283, pi), 0, 3.0, -4.2, pi / 2, 1.8, 2.6)
    Props.truck(W.ctx(-140, 302, 0.25), 0, 0, 0, true)
    Props.car(W.ctx(-232, 297, 0), 0, 0, 2.9)
    fireBarrel(W.ctx(-166, 309, 0), 0, 0)
    -- fences
    for i = 1, #houseX - 1 do
        local f = W.ctx(houseX[i], 0, 0)
    end
    for _, x in ipairs({ -270, -245, -200, -160, -120 }) do
        local f = W.ctx(x, 330, 0)
        Props.fence(f, -8, 0, 8, 0, 1.2)
    end
    -- loot pickups
    pickup(W.ctx(-205, 312, 0), 0, 0, 0, "fuel", 1, "jerrycan")
    pickup(W.ctx(-120, 294, 0), 0, 0, 0, "food", 2, "foodbox")
    pickup(W.ctx(-212, 260, 0), 3, 0, -10, "rifle_ammo", 10, "ammobox")
    spawn(-210, 330, "hound", 2, "village")
    spawn(-150, 270, "hound", 1, "village")
    spawn(-196, 262, "burrower", 1, "village")
end

local function buildIndustrial()
    -- main factory hall
    local f = W.ctx(-305, -62, 0)
    Props.hall(f, 54, 26, 11, rng, { mat = "metal", sideDoor = true, holes = 0.3 })
    -- machinery inside
    for i = -2, 2 do
        f:mat("metal", 0.5, 0.55, 0.5)
        f:solid(i * 9 - 2, 0, -3, i * 9 + 2, 2.2, 3)
        f:mat("rust", 0.6, 0.5, 0.4)
        f.mb:cylinderX(i * 9 - 1.5, i * 9 + 1.5, 2.8, 0, 0.6, 0.6, 7)
    end
    -- overhead crane
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
    -- chimneys (landmarks)
    for _, c in ipairs({ { -340, -105, 48 }, { -322, -112, 42 }, { -268, -108, 38 } }) do
        local lc = W.ctx(c[1], c[2], 0, { landmark = true })
        Props.chimney(lc, 0, 0, c[3], 2.8)
        W.emitters[#W.emitters + 1] = { x = c[1], y = lc.y + c[3], z = c[2], kind = "chimney", rate = 1, acc = 0 }
    end
    -- warehouses
    local wh = W.ctx(-238, 22, 0)
    Props.hall(wh, 26, 16, 7, rng, { mat = "brick", closedEnd = true, doorW = 5 })
    container(wh, 10, 0.1, 5, "industrial", "CRATE")
    Props.crate(wh, 8, 0.1, -5, 1.2) Props.crate(wh, 9.3, 0.1, -5, 1.0) Props.crate(wh, 8.5, 1.3, -5, 0.8)
    pickup(wh, 6, 0.1, 4, "fuel", 1, "jerrycan")
    local wh2 = W.ctx(-345, 32, pi / 2)
    Props.hall(wh2, 22, 14, 6.5, rng, { mat = "brick", doorW = 5, holes = 0.5 })
    container(wh2, -6, 0.1, 4, "industrial", "CRATE")
    -- rail line with wagons
    for x = -440, -150, 4 do
        local r = W.ctx(x, 62, 0)
        r:mat("wood", 0.4, 0.35, 0.3)
        r:box(-0.25, -0.1, -1.4, 0.25, 0.08, 1.4)
        r:mat("rust", 0.5, 0.45, 0.42)
        r:box(-2, 0.08, -0.8, 2, 0.2, -0.7)
        r:box(-2, 0.08, 0.7, 2, 0.2, 0.8)
    end
    for i, x in ipairs({ -400, -385, -300, -285 }) do
        local wg = W.ctx(x, 62, 0)
        wg:mat(i % 2 == 0 and "rust" or "wood", 0.55, 0.45, 0.4)
        wg:solid(-6.5, 0.9, -1.5, 6.5, 4.0, 1.5)
        wg:mat("snow", 1, 1, 1)
        wg:box(-6.5, 4.0, -1.5, 6.5, 4.1, 1.5)
        wg:mat("tread", 0.4, 0.4, 0.4)
        for _, wx in ipairs({ -4.5, 4.5 }) do wg.mb:cylinderZ(-1.0, 1.0, wx, 0.5, 0.45, 8) end
        if i == 3 then container(wg, 0, 0.9, 1.6, "wreck", "FREIGHT CAR") end
    end
    -- apartment blocks
    Props.apartment(W.ctx(-410, -55, pi / 2), 42, 12, 5, rng, false)
    Props.apartment(W.ctx(-215, 95, 0), 46, 12, 5, rng, true)
    Props.apartment(W.ctx(-300, 105, 0), 40, 12, 4, rng, false)
    Props.banner(W.ctx(-300, 105, 0), -10, 11, -6.1, -pi / 2, 2.6, 6)
    -- water tower
    local wt = W.ctx(-215, -70, 0, { landmark = true })
    wt:mat("rust", 0.6, 0.5, 0.45)
    for _, p in ipairs({ { -2, -2 }, { 2, -2 }, { 2, 2 }, { -2, 2 } }) do wt:beam(p[1] * 1.4, 0, p[2] * 1.4, p[1], 16, p[2], 0.3) end
    wt.mb:cylinder(0, 16, 0, 4, 21, 4, 10)
    wt.mb:cylinder(0, 21, 0, 4.2, 23, 0.5, 10)
    wt:collider(-3, 0, -3, 3, 16, 3)
    -- pipes
    for x = -270, -190, 10 do
        local p = W.ctx(x, -30, 0)
        p:mat("concrete", 0.6, 0.6, 0.6)
        p:solid(-0.3, 0, -0.3, 0.3, 3.2, 0.3)
    end
    local pp = W.ctx(-230, -30, 0)
    pp:mat("rust", 0.65, 0.55, 0.45)
    pp.mb:cylinderX(-42, 42, 3.6, 0, 0.5, 0.5, 7)
    pp.mb:cylinderX(-42, 42, 3.6, 1.3, 0.35, 0.35, 6)
    Props.truck(W.ctx(-250, -5, 1.7), 0, 0, 0, true)
    Props.tankWreck(W.ctx(-180, -30, 0.4), 0, 0, 0, true)
    container(W.ctx(-180, -30, 0.4), 0, 1.0, 1.7, "wreck", "WRECKAGE")
    W.radZones[#W.radZones + 1] = { x = -305, z = -62, r = 22, strength = 1.6 }
    W.radZones[#W.radZones + 1] = { x = -240, z = 45, r = 14, strength = 1.2 }
    spawn(-300, -62, "crawler", 3, "industrial")
    spawn(-240, 30, "crawler", 1, "industrial")
    spawn(-270, 10, "burrower", 1, "industrial")
end

local function buildCheckpoint()
    local cx, cz = 20, 95
    local c = W.ctx(cx, cz, 0)
    -- barrier poles across road (road runs roughly north-south)
    c:mat("hazard", 1, 1, 1)
    c:box(-6, 1.0, -0.1, -1, 1.15, 0.1)
    c:box(1.5, 1.0, -0.1, 6, 1.15, 0.1)
    c:mat("concrete", 0.7, 0.7, 0.7)
    c:solid(-6.5, 0, -0.3, -6, 1.2, 0.3)
    c:solid(6, 0, -0.3, 6.5, 1.2, 0.3)
    -- guard booth
    local b = W.ctx(cx + 11, cz + 3, -pi / 2)
    Props.house(b, 3.2, 3.2, { h = 2.5, empty = true, mat = "wood" }, rng)
    container(b, -1.1, 0.25, 0.6, "military", "LOCKER")
    pickup(b, 0.6, 0.25, 0.9, "ap_shell", 2, "shellcrate")
    -- sandbags & blocks
    Props.sandbags(c, -14, -6, -8, -6, 1.1)
    Props.sandbags(c, 8, -8, 14, -8, 1.1)
    Props.sandbags(c, -14, -6, -14, 0, 1.1)
    for i = -2, 2 do
        c:mat("concrete", 0.65, 0.65, 0.65)
        c:solid(-9 + i * 0.1, 0, 8 + i * 2.2, -7.8, 1.0, 9.6 + i * 2.2)
    end
    for i = 0, 3 do Props.hedgehog(c, -18 + i * 3.2, 14 + (i % 2) * 2) end
    for i = 0, 3 do Props.hedgehog(c, 12 + i * 3.2, 15 + (i % 2) * 2) end
    Props.watchtower(c, -13, 6)
    Props.sign(c, 7, -12, pi / 2, "sign")
    Props.sign(c, -7, 12, -pi / 2, "sign")
    Props.truck(W.ctx(cx - 4, cz - 22, 1.3), 0, 0, 0, true)
    Props.tankWreck(W.ctx(cx + 16, cz - 26, -0.4), 0, 0, 0, false)
    container(W.ctx(cx + 16, cz - 26, -0.4), -2.0, 0.6, 2.0, "wreck", "WRECKAGE")
    Props.truck(W.ctx(cx - 18, cz + 22, -0.2), 0, 0, 0, false)
    container(W.ctx(cx - 18, cz + 22, -0.2), -1, 1.2, 0, "military", "SUPPLY TRUCK")
    fireBarrel(c, 9, 4)
    pickup(c, -11, 0, -3, "mg_ammo", 150, "mgbox")
    pickup(c, 10, 0, -6, "repair_kit", 1, "repairkit")
    pickup(c, -10, 0, 3, "fuel", 1, "jerrycan")
    spawn(cx + 30, cz + 10, "crawler", 2, "checkpoint")
end

local function buildForest()
    local L = W.forest
    trees(L.x, L.z, 175, 1100, 0.72, 8)
    -- hunter's cabin
    local cab = W.ctx(338, 222, -pi / 2)
    Props.house(cab, 6, 5, { mat = "wood", h = 2.6 }, rng)
    container(cab, 2.2, 0.25, 1.5, "house", "HUNTER'S CHEST").loot = { { "food", 3 }, { "rifle_ammo", 15 }, { "medkit", 1 } }
    pickup(cab, -1.5, 0.25, 1.4, "fuel", 1, "jerrycan")
    door(cab, -0.55, 0.25, -2.5, 0, 1.1, 2.1)
    local fp = W.ctx(331, 225, 0)
    fireBarrel(fp, 0, -6)
    -- collapsed bridge pieces
    local br = W.bridgeBroken
    local bc = W.ctx(br.x, br.z, -0.45, { y = W.baseHeight(br.x - 24, br.z) })
    bc:mat("concrete", 0.6, 0.6, 0.62)
    bc.mb:push() bc.mb:translate(-16, -1.5, 0) bc.mb:rotateZ(-0.25)
    bc:box(-6, -0.4, -3.5, 6, 0.2, 3.5)
    bc.mb:pop()
    bc.mb:push() bc.mb:translate(14, -1.8, 0) bc.mb:rotateZ(0.3)
    bc:box(-6, -0.4, -3.5, 6, 0.2, 3.5)
    bc.mb:pop()
    bc:mat("concrete", 0.55, 0.55, 0.55)
    bc:solid(-24, -6, -3.5, -21, 0.2, 3.5)
    bc:solid(21, -6, -3.5, 24, 0.2, 3.5)
    bc:box(-2, -8, -2, 2, -2.5, 2)
    -- intact bridge railings on the other crossing
    local bi = W.bridgeIntact
    local bic = W.ctx(bi.x, bi.z, -0.13)
    bic:mat("rust", 0.6, 0.55, 0.5)
    for s = -1, 1, 2 do
        bic:beam(-20, 1.0, s * 5.2, 20, 1.0, s * 5.2, 0.12)
        for x = -20, 20, 4 do bic.mb:box(x - 0.08, 0, s * 5.2 - 0.08, x + 0.08, 1.0, s * 5.2 + 0.08) end
        bic:collider(-20, 0, s * 5.2 - 0.15, 20, 1.0, s * 5.2 + 0.15, { noVehicle = true })
    end
    bic:mat("concrete", 0.55, 0.55, 0.55)
    bic:box(-21, -6, -5.6, 21, 0.05, -4.9)
    bic:box(-21, -6, 4.9, 21, 0.05, 5.6)
    Props.car(W.ctx(240, 141, 0.35), 0, 0, 0)
    container(W.ctx(240, 141, 0.35), 0, 0.5, 1.0, "wreck", "CAR TRUNK")
    spawn(300, 150, "hound", 2, "forest")
    spawn(360, 230, "hound", 1, "forest")
    spawn(280, 200, "burrower", 2, "forest", { radius = 35 })
    spawn(340, 120, "burrower", 1, "forest")
end

local function buildBase()
    local L = W.base
    local cx, cz, R = L.x, L.z, 72
    -- perimeter concrete wall with gaps where the road crosses
    local function wallLine(x0, z0, x1, z1)
        local len = U.dist2(x0, z0, x1, z1)
        local n = math.floor(len / 6)
        for i = 0, n - 1 do
            local ax, az = x0 + (x1 - x0) * i / n, z0 + (z1 - z0) * i / n
            local bx, bz = x0 + (x1 - x0) * (i + 1) / n, z0 + (z1 - z0) * (i + 1) / n
            local mx, mz = (ax + bx) / 2, (az + bz) / 2
            if W.roadDistance(mx, mz) > 9 then
                local c = W.ctx(mx, mz, 0)
                Props.concreteWall(c, ax - mx, az - mz, bx - mx, bz - mz, 3.2)
            end
        end
    end
    wallLine(cx - R, cz - R, cx + R, cz - R)
    wallLine(cx + R, cz - R, cx + R, cz + R)
    wallLine(cx + R, cz + R, cx - R, cz + R)
    wallLine(cx - R, cz + R, cx - R, cz - R)
    for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local wc = W.ctx(cx + p[1] * (R - 3), cz + p[2] * (R - 3), 0)
        Props.watchtower(wc, 0, 0)
    end
    -- barracks (west of the road)
    for i, z in ipairs({ cz - 40, cz - 12, cz + 16 }) do
        local bctx = placeHouse(cx - 48, z, pi / 2, 20, 8, { h = 3, mat = "plaster", door = true, doorAt = 0.5 }, "military")
        Props.bed(bctx, -6, 2.6, 0) Props.bed(bctx, -2, 2.6, 0) Props.bed(bctx, 4, 2.6, 0)
        if i == 2 then pickup(bctx, 6, 0.25, -2, "medkit", 1, "medkit") end
    end
    -- hangars (east side)
    local h1 = W.ctx(cx + 42, cz - 22, pi)
    Props.hangar(h1, 24, 18, rng)
    Props.tankWreck(h1, 2, 0, 0.1, false)
    container(h1, -9, 0.1, 5, "military", "SPARE PARTS")
    pickup(h1, -9, 0.1, -5, "repair_kit", 1, "repairkit")
    local h2 = W.ctx(cx + 42, cz + 18, pi)
    Props.hangar(h2, 24, 18, rng)
    Props.truck(h2, 1, 0, -2, false)
    container(h2, -9, 0.1, 4, "military", "AMMO CRATE").loot = { { "he_shell", 3 }, { "ap_shell", 2 } }
    pickup(h2, -8, 0.1, -5, "mg_ammo", 200, "mgbox")
    -- fuel depot
    local fd = W.ctx(cx - 30, cz + 50, 0)
    Props.fuelTank(fd, 0, 0, 0, 12, 1.8)
    Props.fuelTank(fd, 0, 7, 0, 12, 1.8)
    Props.fuelTank(fd, 16, 3, pi / 2, 10, 1.6)
    pickup(fd, -8, 0, -4, "fuel", 1, "jerrycan")
    pickup(fd, -8.8, 0, -3.2, "fuel", 1, "jerrycan")
    W.radZones[#W.radZones + 1] = { x = cx - 5, z = cz + 60, r = 10, strength = 0.8 }
    -- HQ
    local hq, info = placeHouse(cx - 22, cz - 52, 0, 14, 9, { h = 3.2, mat = "brick", door = true }, "military")
    Props.banner(hq, 3, 3.2, -4.7, -pi / 2, 2, 3)
    container(hq, 5, 0.25, 3, "military", "FILING CABINET").loot = { { "documents", 1 }, { "rifle_ammo", 10 } }
    -- flag pole & motor pool
    local fpole = W.ctx(cx + 10, cz - 4, 0)
    fpole:mat("metal", 0.6, 0.6, 0.6)
    fpole.mb:cylinder(0, 0, 0, 0.08, 12, 0.06, 5)
    fpole:mat("cloth_red", 1, 1, 1)
    fpole.mb:panel(0.08, 9.5, 0, 0.08, 11.8, 0, 2.6, 11.6, 0.3, 2.6, 9.4, 0.3)
    Props.truck(W.ctx(cx + 20, cz + 46, 0.2), 0, 0, 0, true)
    Props.truck(W.ctx(cx + 26, cz + 52, 0.15), 0, 0, 0, false)
    fireBarrel(W.ctx(cx + 5, cz + 30, 0), 0, 0)
    Props.sandbags(W.ctx(cx, cz, 0), 18, 30, 24, 30, 1.1)
    spawn(cx - 30, cz - 10, "hound", 2, "base")
    spawn(cx + 40, cz + 18, "crawler", 2, "base")
    spawn(cx + 10, cz + 50, "hound", 1, "base")
end

local function buildTower()
    local L = W.tower
    local m = W.ctx(L.x, L.z, 0, { landmark = true })
    Props.radioMast(m, 70, 4.5)
    W.towerTop = { x = L.x, y = m.y + 78, z = L.z }
    light(m, 0, 79, 0, 1.0, 0.1, 0.05, 40, 2.0, "blink")
    -- guy wires
    m:mat("metal", 0.5, 0.5, 0.5)
    for _, a in ipairs({ 0.4, 2.5, 4.6 }) do
        local ax, az = math.cos(a) * 38, math.sin(a) * 38
        local gy = W.height(L.x + ax, L.z + az) - m.y
        m:beam(0, 45, 0, ax, gy, az, 0.05)
        m:beam(0, 25, 0, ax, gy, az, 0.05)
    end
    -- equipment shack with transmitter
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
    local fe = W.ctx(L.x, L.z, 0)
    Props.fence(fe, -22, -22, 22, -22, 2.2, "metal")
    Props.fence(fe, 22, -22, 22, 22, 2.2, "metal")
    Props.fence(fe, -22, 22, -22, -22, 2.2, "metal")
    Props.truck(W.ctx(L.x - 18, L.z + 30, 2.2), 0, 0, 0, true)
    spawn(L.x + 10, L.z - 30, "hound", 2, "tower")
    spawn(L.x - 30, L.z + 10, "crawler", 1, "tower")
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
    local h = W.height(L.x, L.z)
    -- surface entrance: concrete portal in a snow covered mound
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
    -- interior far below
    local oy = h - 45
    local ox, oz = L.x - 10, L.z - 30
    local ictx, markers, iw, ih = tileInterior(BUNKER_MAP, ox, oy, oz, 2.5, 3.0, { wall = "concrete", wr = 0.6, wg = 0.65, wb = 0.58 })
    W.underground[#W.underground + 1] = { ox - 2, oy - 5, oz - 2, ox + iw + 2, oy + 8, oz + ih + 2, name = "bunker" }
    W.bunkerInfo = { ox = ox, oy = oy, oz = oz }
    local exitPos
    for _, m in ipairs(markers) do
        local mx, mz = m.x, m.z
        if m.c == "E" then
            -- stairs leading up to the blast door
            ictx:mat("concrete", 0.5, 0.5, 0.5)
            for k = 0, 4 do ictx:box(mx - 1.2 - k * 0.0, k * 0.25, mz - 1.2 + k * 0.0, mx + 1.2, k * 0.25 + 0.25, mz - 0.6 + 0.0) end
            exitPos = { mx, mz }
            ictx:mat("metal", 0.45, 0.5, 0.45)
            ictx.mb:box(mx - 1.0, 1.25, mz - 1.24, mx + 1.0, 3.0, mz - 1.2)
            light(ictx, mx, 2.7, mz, 0.6, 0.8, 0.5, 7, 1.0, true)
        elseif m.c == "L" then
            light(ictx, mx, 2.8, mz, 0.85, 0.75, 0.5, 9, 1.0, true)
            ictx:mat("metal", 1, 0.9, 0.7)
            ictx.mb:box(mx - 0.3, 2.85, mz - 0.1, mx + 0.3, 3.0, mz + 0.1)
        elseif m.c == "S" then
            Props.shelf(ictx, mx, mz - 0.9, 0, 2.2)
        elseif m.c == "C" then
            Props.crate(ictx, mx, 0, mz, 0.9)
            container(ictx, mx, 0.9, mz, "military", "SUPPLY CRATE")
        elseif m.c == "A" then
            ictx:mat("crate", 0.7, 0.8, 0.6)
            ictx:solid(mx - 1, 0, mz - 0.6, mx + 1, 0.7, mz + 0.6)
            container(ictx, mx, 0.7, mz, "military", "ARMORY RACK").loot = { { "ap_shell", 4 }, { "he_shell", 4 }, { "mg_ammo", 300 } }
        elseif m.c == "B" then
            Props.bed(ictx, mx, mz, 0)
        elseif m.c == "T" then
            Props.table(ictx, mx, mz, 0)
            ictx:mat("paper", 1, 1, 1)
            ictx.mb:quad(mx - 0.5, 0.8, mz - 0.3, mx - 0.5, 0.8, mz + 0.3, mx + 0.4, 0.8, mz + 0.3, mx + 0.4, 0.8, mz - 0.3)
            light(ictx, mx, 2.7, mz, 0.9, 0.6, 0.3, 8, 1.1, true)
            -- radio console
            ictx:mat("metal", 0.4, 0.45, 0.4)
            ictx:solid(mx - 1.2, 0, mz - 3.6, mx + 1.2, 1.4, mz - 3.0)
            ictx:mat("gauge", 1, 1, 1)
            ictx.mb:quad(mx - 0.8, 1.0, mz - 2.99, mx - 0.8, 1.35, mz - 2.99, mx - 0.4, 1.35, mz - 2.99, mx - 0.4, 1.0, mz - 2.99)
            local wx, wy, wz = ictx:toWorld(mx, 1.2, mz - 2.9)
            W.bunkerRadio = { x = wx, y = wy, z = wz }
        elseif m.c == "K" then
            pickup(ictx, mx, 0, mz, "keycard", 1, "keycard")
            pickup(ictx, mx + 0.6, 0, mz + 0.4, "documents", 1, "documents")
        elseif m.c == "G" then
            ictx:mat("metal", 0.45, 0.5, 0.42)
            ictx:solid(mx - 0.9, 0, mz - 0.6, mx + 1.5, 1.5, mz + 0.9)
            ictx:mat("hazard", 1, 1, 1)
            ictx.mb:box(mx - 0.92, 1.0, mz - 0.62, mx + 1.52, 1.2, mz + 0.92)
            pickup(ictx, mx + 2.2, 0, mz, "fuel", 1, "jerrycan")
            pickup(ictx, mx + 2.2, 0, mz + 0.8, "fuel", 1, "jerrycan")
        elseif m.c == "D" then
            ictx:mat("metal", 0.5, 0.5, 0.48)
            ictx.mb:box(mx - 0.1, 2.4, mz - 1.25, mx + 0.1, 3.0, mz + 1.25)
        elseif m.c == "X" then
            local wx, wy, wz = ictx:toWorld(mx, 0, mz)
            spawn(wx, wz, "crawler", 3, "bunker", { y = wy, underground = true, radius = 4 })
        end
    end
    local ex, ey, ez = ictx:toWorld(exitPos[1], 0, exitPos[2])
    local doorOutX, doorOutZ = e:toWorld(0, 0, 1.6)
    -- transition doors (surface <-> bunker)
    local d1 = door(e, -1.6, 0, -6.9, 0, 3.2, 3.1, { transition = { x = ex, y = ey, z = ez, yaw = math.pi / 2, inside = true }, label = "BLAST DOOR", mat = "metal", heavy = true })
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
    -- cooling towers (landmarks)
    for _, c in ipairs({ { 62, -548 }, { 182, -560 } }) do
        local t = W.ctx(c[1], c[2], 0, { landmark = true })
        Props.coolingTower(t, 62, 26, 17, 19)
        W.emitters[#W.emitters + 1] = { x = c[1], y = t.y + 60, z = c[2], kind = "steam", rate = 1, acc = 0 }
    end
    -- reactor building with dome (landmark) - partly destroyed
    local r = W.ctx(120, -480, 0, { landmark = true })
    r:mat("concrete", 0.7, 0.7, 0.68)
    r:solid(-18, -1, -18, 18, 22, 18)
    r.mb:sphere(0, 22, 0, 15, 10, 15, 10, 5)
    r:mat("rubble", 0.4, 0.38, 0.36)
    r.mb:box(8, 22, -10, 16, 26, -2)
    r:mat("hazard", 1, 1, 1)
    r.mb:box(-18.05, 6, -6, -18.0, 7, 6)
    -- red/white vent stack
    r:mat("plaster", 0.85, 0.85, 0.85)
    r.mb:cylinder(24, 0, 0, 2.2, 55, 1.6, 8, false)
    r:mat("cloth_red", 1, 1, 1)
    r.mb:cylinder(24, 45, 0, 1.75, 50, 1.68, 8, false)
    r:collider(21.8, 0, -2.2, 26.2, 55, 2.2)
    -- turbine hall
    local th = W.ctx(55, -470, 0)
    th:mat("concrete", 0.65, 0.66, 0.68)
    th:solid(-12, -1, -30, 12, 18, 30)
    for i = -4, 4 do Props.window(th, 12, 9, i * 6, 3, 5, "x+") end
    -- control building (enterable interior with locked door)
    local ax, az = 182, -462
    local ah = W.height(ax, az)
    local cell = 2.5
    local ox, oz = ax - 12.5, az - 10
    -- exterior shell (visual)
    local sh = W.ctx(ax, az, 0, { y = ah })
    sh:mat("concrete", 0.72, 0.72, 0.7)
    local x0, x1, z0, z1 = -12.5 - 0.3, 12.5 + 0.3, -10 - 0.3, 10 + 0.3
    sh.mb:box(x0, -1, z0, x1, 7.2, z0 + 0.3)
    sh.mb:box(x0, -1, z1 - 0.3, x1, 7.2, z1)
    sh.mb:box(x1 - 0.3, -1, z0, x1, 7.2, z1)
    -- west wall with door opening (door at tile 'D' col 2,row 6)
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
    for _, m in ipairs(markers) do
        if m.c == "L" then
            light(ictx, m.x, 3.1, m.z, 0.4, 0.9, 0.6, 10, 1.0, true)
        elseif m.c == "R" then
            -- reactor control panels and the signal console
            ictx:mat("metal", 0.45, 0.5, 0.45)
            ictx:solid(m.x - 5, 0, m.z - 2.6, m.x + 5, 1.6, m.z - 1.6)
            ictx:mat("gauge", 1, 1, 1)
            for k = -4, 4 do
                ictx.mb:quad(m.x + k - 0.3, 1.0, m.z - 1.59, m.x + k - 0.3, 1.5, m.z - 1.59, m.x + k + 0.3, 1.5, m.z - 1.59, m.x + k + 0.3, 1.0, m.z - 1.59)
            end
            local wx, wy, wz = ictx:toWorld(m.x, 1.2, m.z - 1.5)
            W.signalConsole = { x = wx, y = wy, z = wz }
            light(ictx, m.x, 1.8, m.z - 1.2, 1.0, 0.2, 0.1, 5, 1.2, "blink")
        elseif m.c == "C" then
            container(ictx, m.x, 0, m.z, "military", "EMERGENCY LOCKER").loot = { { "antirad", 3 }, { "medkit", 2 } }
            Props.crate(ictx, m.x, 0, m.z - 0.8, 0.8, "metal")
        elseif m.c == "D" then
            local dz = m.z
        end
    end
    W.interiorBounds = W.interiorBounds or {}
    door(W.ctx(ax, az, 0, { y = ah }), -12.5 - 0.15, 0, doorZ + 1.1, -math.pi / 2, 2.2, 2.4,
        { locked = "keycard", label = "CONTROL BLOCK DOOR", mat = "metal", heavy = true })
    W.controlRoom = { x0 = ox, z0 = oz, x1 = ox + 25, z1 = oz + 20, y = ah }
    W.shelters[#W.shelters + 1] = { ox, ah - 1, oz, ox + 25, ah + 4, oz + 20 }
    -- fences, pylons, wrecks
    local pc = W.ctx(L.x, L.z, 0)
    for _, s in ipairs({ { -90, 60, 90, 60 }, { 90, 60, 90, -80 }, { -90, 60, -90, -80 } }) do
        local len = U.dist2(s[1], s[2], s[3], s[4])
        local n = math.floor(len / 12)
        for i = 0, n - 1 do
            local ax0, az0 = s[1] + (s[3] - s[1]) * i / n, s[2] + (s[4] - s[2]) * i / n
            local bx0, bz0 = s[1] + (s[3] - s[1]) * (i + 0.85) / n, s[2] + (s[4] - s[2]) * (i + 0.85) / n
            local mx, mz = L.x + (ax0 + bx0) / 2, L.z + (az0 + bz0) / 2
            if W.roadDistance(mx, mz) > 8 and math.abs(mx - W.riverX(mz)) > 14 then
                local fc = W.ctx(mx, mz, 0)
                Props.fence(fc, ax0 + L.x - mx, az0 + L.z - mz, bx0 + L.x - mx, bz0 + L.z - mz, 2.4, "metal")
            end
        end
    end
    for i, p in ipairs({ { 0, -380 }, { -40, -420 }, { -80, -455 } }) do
        local pyl = W.ctx(p[1], p[2], 0.6, { landmark = true })
        pyl:mat("rust", 0.55, 0.5, 0.48)
        for _, l in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do pyl:beam(l[1] * 3, 0, l[2] * 3, l[1] * 0.8, 24, l[2] * 0.8, 0.25) end
        pyl:beam(-6, 22, 0, 6, 22, 0, 0.3)
        pyl:beam(-4.5, 17, 0, 4.5, 17, 0, 0.3)
        pyl:collider(-3, 0, -3, 3, 24, 3)
    end
    Props.truck(W.ctx(140, -440, 0.8), 0, 0, 0, true)
    Props.car(W.ctx(160, -448, 2.0), 0, 0, 0)
    Props.tankWreck(W.ctx(100, -430, 2.5), 0, 0, 0, false)
    container(W.ctx(100, -430, 2.5), 2.5, 0.6, 2.0, "wreck", "WRECKAGE")
    fireBarrel(W.ctx(150, -455, 0), 0, 0)
    pickup(W.ctx(165, -452, 0), 0, 0, 0, "antirad", 1, "medkit")
    for i = 1, 4 do
        local sx, sz = 120 + rng:range(-60, 60), -470 + rng:range(-40, 50)
        Props.sign(W.ctx(sx, sz, 0), 0, 0, rng:range(0, 6), "hazard")
    end
    W.radZones[#W.radZones + 1] = { x = 120, z = -480, r = 75, strength = 2.2 }
    W.radZones[#W.radZones + 1] = { x = 120, z = -480, r = 160, strength = 0.5 }
    spawn(120, -440, "mutant", 1, "plant")
    spawn(60, -500, "crawler", 2, "plant")
    spawn(180, -500, "hound", 2, "plant")
end

local function buildWilderness()
    -- telephone poles along main road and village road
    roadPoles(W.roads[1], 32, 9)
    roadPoles(W.roads[2], 30, -8)
    roadPoles(W.roads[3], 34, 8)
    -- scattered trees and groves
    trees(-80, 420, 120, 160, 0.4)
    trees(150, 360, 120, 140, 0.5)
    trees(-120, 150, 120, 140, 0.3)
    trees(-420, 200, 140, 200, 0.6)
    trees(420, -60, 130, 180, 0.6)
    trees(-80, -250, 130, 140, 0.4)
    trees(420, -420, 120, 140, 0.7)
    trees(-470, -230, 120, 140, 0.6)
    trees(0, -560, 90, 60, 0.3)
    trees(250, 450, 150, 160, 0.6)
    trees(-330, 480, 150, 150, 0.6)
    trees(0, 0, 600, 500, 0.35, 12)
    -- rocks
    for i = 1, 120 do
        local x, z = rng:range(-600, 600), rng:range(-600, 600)
        if W.roadDistance(x, z) > 10 and math.abs(x - W.riverX(z)) > 16 then
            local c = W.ctx(x, z, 0)
            c.mb:reset()
            Props.rock(c, x, W.height(x, z), z, rng:range(0.6, 2.2), rng)
        end
    end
    -- wrecks along the roads
    Props.tankWreck(W.ctx(80, 205, 2.0), 0, 0, 0, false)
    container(W.ctx(80, 205, 2.0), 0, 1.8, 0, "wreck", "WRECKAGE")
    Props.tankWreck(W.ctx(-60, -120, 0.9), 0, 0, 0, true)
    Props.truck(W.ctx(35, 330, -1.4), 0, 0, 0, true)
    Props.car(W.ctx(52, 520, 1.3), 0, 0, 0)
    Props.truck(W.ctx(22, -10, -1.6), 0, 0, 0, false)
    container(W.ctx(22, -10, -1.6), -1, 1.2, 0, "military", "TRUCK BED")
    Props.billboard(W.ctx(52, 380, pi), 0, 0, 0, "cloth_red", 7, 4)
    Props.billboard(W.ctx(-15, -60, 0), 0, 0, 0, "star", 5, 4)
    Props.sign(W.ctx(36, 302, 0), 0, 0, 0, "sign")
    Props.sign(W.ctx(10, -70, 0), 0, 0, 0, "sign")
    -- crater with radiation
    W.radZones[#W.radZones + 1] = { x = 140, z = 40, r = 18, strength = 1.0 }
    -- roaming hounds
    spawn(100, 250, "hound", 2, "wild")
    spawn(-60, 150, "hound", 1, "wild")
    spawn(150, -150, "hound", 2, "wild")
    spawn(-120, -200, "crawler", 1, "wild")
    spawn(180, 330, "burrower", 1, "wild")
end

function G.build()
    rng = U.rng(W.SEED)
    nextId = 0
    local steps = {
        { "village", buildVillage }, { "industrial", buildIndustrial }, { "checkpoint", buildCheckpoint },
        { "base", buildBase }, { "tower", buildTower }, { "bunker", buildBunker }, { "plant", buildPlant },
        { "forest", buildForest }, { "wilderness", buildWilderness },
    }
    for i, s in ipairs(steps) do
        s[2]()
        if coroutine.isyieldable() then coroutine.yield(s[1], i / #steps) end
    end
end

return G
