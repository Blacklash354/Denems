-- Rare Soviet-inspired enemy tanks. Patrol, detect, traverse, aim and fire; armour zones; burning wrecks.
local U = require("src.utils")
local P = require("src.physics")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")
local TM = require("src.tank_model")

local E = { tanks = {} }
local G

-- Soviet tanks: a T-34-85 (sloped glacis and sides, five big Christie road wheels, cast turret with a
-- long 85 mm gun, fuel drums and an unditching log, a hasty winter whitewash and a white tactical
-- number) and an IS-2 (longer hull, six smaller wheels, a big turret and the 122 mm gun with its
-- muzzle brake). Hull-local: x forward, y up, z right, origin on the ground under the hull centre.
E.VARIANTS = {
    t34 = { len = 1.0, wheelR = 0.41, wheelY = 0.45, wheels = { 1.95, 1.0, 0.05, -0.9, -1.85 }, turretPos = { 0.15, 1.52, 0 },
            trunnion = { 1.15, 0.38, 0 }, muzzle = 4.85, turretScale = 1.0, hp = 100, speed = 4.2, number = "214" },
    is2 = { len = 1.1, wheelR = 0.34, wheelY = 0.38, wheels = { 2.3, 1.45, 0.6, -0.25, -1.1, -1.95 }, turretPos = { 0.1, 1.55, 0 },
            trunnion = { 1.3, 0.45, 0 }, muzzle = 5.3, turretScale = 1.18, hp = 160, speed = 3.4, number = "07", heavy = true },
}

-- 7-segment style digits made of thin plates on a turret side (z = side face)
local SEGS = { ["0"] = "abcdef", ["1"] = "bc", ["2"] = "abged", ["3"] = "abgcd", ["4"] = "fgbc", ["5"] = "afgcd",
               ["6"] = "afgedc", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg" }
local function number(mb, text, x0, y0, z, w, h)
    local t = 0.035
    -- seen from the left (-z) side the tank's nose is on the viewer's left: lay the digits out
    -- the other way round and mirror each one so the number reads the same on both sides
    local mirror = z < 0
    for i = 1, #text do
        local segs = SEGS[text:sub(i, i)] or ""
        local col = mirror and (#text - i) or (i - 1)
        local x = x0 + col * w * 1.45
        local function X(px) return mirror and (2 * x + w - px) or px end
        local function seg(name, ax, ay, bx, by)
            if segs:find(name, 1, true) then
                ax, bx = X(ax), X(bx)
                mb:box(math.min(ax, bx) - t, math.min(ay, by) - t, z - 0.012, math.max(ax, bx) + t, math.max(ay, by) + t, z + 0.012)
            end
        end
        seg("a", x, y0 + h, x + w, y0 + h)
        seg("b", x + w, y0 + h / 2, x + w, y0 + h)
        seg("c", x + w, y0, x + w, y0 + h / 2)
        seg("d", x, y0, x + w, y0)
        seg("e", x, y0, x, y0 + h / 2)
        seg("f", x, y0 + h / 2, x, y0 + h)
        seg("g", x, y0 + h / 2, x + w, y0 + h / 2)
    end
end

local function buildVariant(v, seed)
    local m = {}
    local L = v.len
    local mb = MB.new(seed)
    mb.texScale = 0.55
    mb.maxEdge = 1.0
    local CAMO = "sovwinter"
    mb:material(CAMO):color(1, 1, 1)
    local nose, tail = 3.02 * L, -3.05 * L
    local glacisTop, deckRear = 1.9 * L, -2.55 * L
    -- lower hull between the tracks and its sloped nose / tail plates
    mb:box(tail + 0.1, 0.38, -1.02, nose - 0.27, 1.05, 1.02, { top = false })
    mb:hexa({ { nose - 0.27, 0.38, -1.02 }, { nose, 0.97, -1.02 }, { nose, 0.97, 1.02 }, { nose - 0.27, 0.38, 1.02 },
              { nose - 0.27, 1.05, -1.02 }, { nose - 0.02, 1.05, -1.02 }, { nose - 0.02, 1.05, 1.02 }, { nose - 0.27, 1.05, 1.02 } })
    mb:hexa({ { tail, 1.05, -1.02 }, { tail + 0.1, 0.38, -1.02 }, { tail + 0.1, 0.38, 1.02 }, { tail, 1.05, 1.02 },
              { tail, 1.07, -1.02 }, { tail + 0.1, 1.07, -1.02 }, { tail + 0.1, 1.07, 1.02 }, { tail, 1.07, 1.02 } })
    -- upper hull with the sloped sides out over the tracks
    mb:hexa({ { deckRear, 1.05, -1.5 }, { glacisTop, 1.05, -1.5 }, { glacisTop, 1.05, 1.5 }, { deckRear, 1.05, 1.5 },
              { deckRear, 1.52, -1.18 }, { glacisTop, 1.52, -1.18 }, { glacisTop, 1.52, 1.18 }, { deckRear, 1.52, 1.18 } })
    -- the glacis: one long sloped plate down to the nose
    mb:hexa({ { glacisTop, 1.05, -1.5 }, { nose, 0.97, -1.45 }, { nose, 0.97, 1.45 }, { glacisTop, 1.05, 1.5 },
              { glacisTop, 1.52, -1.18 }, { nose - 0.02, 1.0, -1.42 }, { nose - 0.02, 1.0, 1.42 }, { glacisTop, 1.52, 1.18 } })
    -- engine deck sloping down to the rear plate
    mb:hexa({ { tail, 1.05, -1.5 }, { deckRear, 1.05, -1.5 }, { deckRear, 1.05, 1.5 }, { tail, 1.05, 1.5 },
              { tail + 0.05, 1.3, -1.18 }, { deckRear, 1.52, -1.18 }, { deckRear, 1.52, 1.18 }, { tail + 0.05, 1.3, 1.18 } })
    -- fenders over the tracks, front tips bent down
    for _, sd in ipairs({ -1, 1 }) do
        local z0, z1 = sd > 0 and 1.0 or -1.56, sd > 0 and 1.56 or -1.0
        mb:box(tail - 0.05, 1.03, z0, nose + 0.12, 1.07, z1)
        mb:hexa({ { nose + 0.12, 1.03, z0 }, { nose + 0.35, 0.82, z0 }, { nose + 0.35, 0.82, z1 }, { nose + 0.12, 1.03, z1 },
                  { nose + 0.12, 1.07, z0 }, { nose + 0.36, 0.86, z0 }, { nose + 0.36, 0.86, z1 }, { nose + 0.12, 1.07, z1 } })
    end
    -- driver's hatch and spare track links on the glacis
    local ga = -math.atan2(1.52 - 0.97, glacisTop - nose)
    mb:push() mb:translate(glacisTop + 0.55, 1.27, -0.45) mb:rotateZ(ga - math.pi)
    mb:box(-0.3, 0, -0.27, 0.3, 0.07, 0.27)
    mb:pop()
    mb:material("tread"):color(0.75, 0.72, 0.7)
    for i = 0, 3 do
        mb:push() mb:translate(nose - 0.3 - i * 0.02, 1.03 + i * 0.01, 0.25 + i * 0.27) mb:rotateZ(ga - math.pi)
        mb:box(-0.05, 0, -0.12, 0.25, 0.05, 0.12)
        mb:pop()
    end
    -- hull machine gun in its ball and a headlight
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:sphere(nose - 0.45, 1.24, 0.55, 0.13, 0.13, 0.13, 6, 4)
    mb:cylinderX(nose - 0.45, nose + 0.05, 1.27, 0.55, 0.025, 0.02, 5)
    mb:cylinder(nose - 0.15, 1.07, -1.2, 0.09, 1.2, 0.1, 7)
    mb:material("white"):color(0.9, 0.85, 0.6)
    mb:cylinderX(nose - 0.06, nose - 0.04, 1.14, -1.2, 0.07, 0.07, 7)
    -- engine deck grilles and the round transmission hatch
    mb:material("metal"):color(0.22, 0.22, 0.2)
    mb:box(deckRear + 0.15, 1.52, -0.75, deckRear + 1.2, 1.56, 0.75)
    mb:cylinderX(tail - 0.02, tail + 0.03, 0.78, 0, 0.32, 0.32, 10)
    -- exhaust pipes out of the rear plate
    for _, z in ipairs({ -0.55, 0.55 }) do mb:cylinderX(tail - 0.22, tail + 0.05, 0.86, z, 0.09, 0.09, 6) end
    -- external fuel drums on the hull sides
    mb:material(CAMO):color(0.9, 0.9, 0.88)
    for _, sd in ipairs({ -1, 1 }) do
        for _, x0 in ipairs({ -2.35 * L, -1.3 * L }) do mb:cylinderX(x0, x0 + 0.85, 1.36, sd * 1.36, 0.19, 0.19, 8) end
    end
    -- unditching log and tow cable
    mb:material("bark"):color(0.6, 0.5, 0.4)
    mb:cylinderX(-1.0 * L, 1.6 * L, 1.2, 1.42, 0.12, 0.12, 7)
    mb:material("metal"):color(0.25, 0.24, 0.22)
    mb:cylinderX(-2.4 * L, 1.4 * L, 1.1, -1.45, 0.03, 0.03, 4)
    m.hull = mb:build()

    -- tracks: around the front idler, along the wheel tops, round the rear sprocket and back underneath
    local pts = {}
    local function arc(cx, cy, r, a0, a1)
        for i = 0, 5 do
            local a = a0 + (a1 - a0) * i / 5
            pts[#pts + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r }
        end
    end
    local idlerX, sprX = nose - 0.3, tail + 0.3
    local top = v.wheelY + v.wheelR + 0.04
    arc(idlerX, 0.5, 0.45, -math.pi / 2, math.pi / 2)
    for i = 1, #v.wheels do
        local wx = v.wheels[i]
        pts[#pts + 1] = { wx + 0.25, top - (v.heavy and 0 or 0.03) + (v.heavy and 0.08 or 0) }
        pts[#pts + 1] = { wx, top + (v.heavy and 0.08 or 0) }
    end
    arc(sprX, 0.5, 0.45, math.pi / 2, 3 * math.pi / 2)
    for i = #v.wheels, 1, -1 do pts[#pts + 1] = { v.wheels[i], 0.04 } end
    m.trackL = TM.buildBelt(pts, -1.0, -1.5, -1, seed + 5)
    m.trackR = TM.buildBelt(pts, 1.0, 1.5, 1, seed + 6)
    m.wheel = TM.buildWheel(v.wheelR, 0.13, 10)
    m.sprocket = TM.buildSprocket()
    m.lyingTrack = TM.buildLyingTrack(0.5, 7.5, seed + 7)
    m.idlerX, m.sprX = idlerX, sprX

    -- turret (turret-local, origin on the hull roof at the ring centre)
    mb = MB.new(seed + 1)
    mb.texScale = 0.55
    mb:push() mb:scale(v.turretScale, v.turretScale, v.turretScale)
    mb:material(CAMO):color(1, 1, 1)
    mb:hexa({ { -1.35, 0, -1.12 }, { 1.05, 0, -1.18 }, { 1.05, 0, 1.18 }, { -1.35, 0, 1.12 },
              { -1.2, 0.7, -0.92 }, { 0.75, 0.7, -0.98 }, { 0.75, 0.7, 0.98 }, { -1.2, 0.7, 0.92 } })
    mb:hexa({ { 1.05, 0.04, -1.1 }, { 1.32, 0.15, -0.78 }, { 1.32, 0.15, 0.78 }, { 1.05, 0.04, 1.1 },
              { 0.75, 0.7, -0.98 }, { 1.15, 0.6, -0.68 }, { 1.15, 0.6, 0.68 }, { 0.75, 0.7, 0.98 } })
    mb:hexa({ { -1.85, 0.12, -0.85 }, { -1.35, 0.04, -1.1 }, { -1.35, 0.04, 1.1 }, { -1.85, 0.12, 0.85 },
              { -1.75, 0.62, -0.72 }, { -1.2, 0.7, -0.92 }, { -1.2, 0.7, 0.92 }, { -1.75, 0.62, 0.72 } })
    -- commander's cupola with its vision blocks, the loader's hatch and two ventilator domes
    mb:cylinder(-0.7, 0.7, -0.45, 0.36, 0.95, 0.33, 10)
    mb:cylinder(-0.7, 0.95, -0.45, 0.3, 1.0, 0.24, 10)
    mb:material("metal"):color(0.12, 0.13, 0.14)
    for i = 0, 4 do
        local a = i / 5 * 2 * math.pi + 0.3
        mb:boxC(-0.7 + math.cos(a) * 0.35, 0.86, -0.45 + math.sin(a) * 0.35, 0.06, 0.05, 0.08)
    end
    mb:material(CAMO):color(0.95, 0.95, 0.93)
    mb:cylinder(-0.55, 0.7, 0.45, 0.3, 0.76, 0.3, 9)
    mb:sphere(-1.45, 0.62, -0.3, 0.13, 0.08, 0.13, 6, 3)
    mb:sphere(-1.45, 0.62, 0.3, 0.13, 0.08, 0.13, 6, 3)
    -- grab rails
    mb:material("metal"):color(0.28, 0.28, 0.26)
    mb:box(-1.2, 0.42, -1.07, 0.4, 0.46, -1.03)
    mb:box(-1.2, 0.42, 1.03, 0.4, 0.46, 1.07)
    -- white tactical number on both sides
    mb:material("white"):color(0.88, 0.88, 0.85)
    number(mb, v.number, -1.05, 0.2, -1.07, 0.16, 0.26)
    number(mb, v.number, -1.05, 0.2, 1.07, 0.16, 0.26)
    mb:pop()
    m.turret = mb:build()

    -- gun with its mantlet (gun-local, origin at the trunnions)
    mb = MB.new(seed + 2)
    mb.texScale = 0.55
    local k = v.turretScale
    mb:material(CAMO):color(1, 1, 1)
    mb:box(-0.15 * k, -0.26 * k, -0.45 * k, 0.22 * k, 0.26 * k, 0.45 * k)
    mb:cylinderZ(-0.42 * k, 0.42 * k, 0.22 * k, 0, 0.22 * k, 8)
    mb:box(0.3 * k, -0.14, -0.14, 0.55 * k, 0.14, 0.14)
    local r0 = v.heavy and 0.115 or 0.09
    mb:cylinderX(0.5 * k, v.muzzle - 0.2, 0, 0, r0, r0 * 0.82, 8)
    mb:material("metal"):color(0.3, 0.3, 0.28)
    if v.heavy then
        -- double-baffle muzzle brake
        mb:cylinderX(v.muzzle - 0.25, v.muzzle - 0.1, 0, 0, 0.12, 0.12, 8)
        mb:box(v.muzzle - 0.32, -0.13, -0.2, v.muzzle - 0.24, 0.13, 0.2)
        mb:box(v.muzzle - 0.14, -0.13, -0.2, v.muzzle - 0.06, 0.13, 0.2)
        mb:cylinderX(v.muzzle - 0.06, v.muzzle, 0, 0, 0.12, 0.12, 8)
    else
        mb:cylinderX(v.muzzle - 0.25, v.muzzle, 0, 0, r0 * 0.95, r0 * 0.95, 8)
    end
    m.gun = mb:build()
    -- searchlight lens on the mantlet (drawn bright while the crew is alive)
    mb = MB.new(seed + 3)
    mb:material("white"):color(1.0, 0.85, 0.6)
    mb:cylinderX(1.24 * v.turretScale, 1.26 * v.turretScale, 0.48, -0.72, 0.08, 0.08, 7)
    m.light = mb:build()
    return m
end

local function buildModels()
    return { t34 = buildVariant(E.VARIANTS.t34, 401), is2 = buildVariant(E.VARIANTS.is2, 451) }
end

local function newTank(def)
    local W = G.world
    local kind = def.kind or "t34"
    local v = E.VARIANTS[kind]
    local t = { name = def.name, route = def.route, wp = 2, x = def.route[1][1], z = def.route[1][2], yaw = 0, kind = kind, v = v,
                models = E.models[kind], hp = v.hp, trackL = 60, trackR = 60, state = "patrol", turretYaw = 0, gunPitch = 0,
                reload = 3, aimT = 0, speed = 0, timer = 0, alive = true, spotted = false, burnT = 0, mgCool = 0, searchT = 0,
                id = def.id, lying = {} }
    t.y = W.groundHeight(t.x, t.z)
    t.frame = M3.frame()
    t.turretFrame = M3.frame()
    t.gunFrame = M3.frame()
    local L, k = v.len, v.turretScale
    t.set = { frame = t.frame, boxes = {
        { -3.15 * L, 0.0, -1.56, 3.1 * L, 1.52, 1.56, walk = true, enemy = t },
    } }
    t.turretSet = { frame = t.turretFrame, boxes = { { -1.85 * k, 0, -1.18 * k, 1.32 * k, 1.0 * k, 1.18 * k, walk = true, enemy = t } } }
    t.mats = { {}, {}, {}, {}, {}, {}, {}, {} }
    t.trackOffL, t.trackOffR, t.wheelAngL, t.wheelAngR = 0, 0, 0, 0
    t.wheels = {}
    for _, s in ipairs({ -1, 1 }) do
        for _, wx in ipairs(v.wheels) do t.wheels[#t.wheels + 1] = { x = wx, y = v.wheelY, z = s * 1.25, side = s, mat = {} } end
        t.wheels[#t.wheels + 1] = { x = t.models.idlerX, y = 0.5, z = s * 1.25, side = s, mat = {}, idler = true }
        t.wheels[#t.wheels + 1] = { x = t.models.sprX, y = 0.5, z = s * 1.25, side = s, mat = {}, sprocket = true }
    end
    t.nx, t.ny, t.nz = 0, 1, 0
    return t
end

function E.init(game)
    G = game
    E.models = buildModels()
    local W = G.world
    local A, Pn = W.airfield, W.plant
    E.defs = {
        { id = 1, name = "T-34 PATROL", route = { { -190, -500 }, { -500, -600 }, { -850, -700 }, { -1040, -742 }, { -850, -700 }, { -500, -600 } } },
        { id = 2, name = "PLANT GUARD", kind = "is2", route = { { Pn.x - 40, Pn.z + 115 }, { Pn.x + 60, Pn.z + 110 }, { Pn.x + 120, Pn.z + 60 }, { Pn.x + 60, Pn.z + 110 } } },
        { id = 3, name = "AIRFIELD ARMOUR", route = { { A.x - 200, A.z + 70 }, { A.x + 200, A.z + 70 }, { A.x + 120, A.z + 20 }, { A.x - 120, A.z + 20 } } },
        { id = 4, name = "AIRFIELD ARMOUR", route = { { A.x + 150, A.z - 60 }, { A.x - 150, A.z - 60 }, { A.x - 220, A.z + 10 }, { A.x + 220, A.z + 10 } } },
        { id = 5, name = "BASE T-34", route = { { -1040, -742 }, { -1160, -650 }, { -1260, -760 }, { -1160, -860 } } },
        { id = 6, name = "TOWN ROAD T-34", route = { { -1160, 320 }, { -960, 500 }, { -720, 560 }, { -960, 500 } } },
        { id = 7, name = "TOWER IS-2", kind = "is2", route = { { 700, -350 }, { 760, -700 }, { 780, -1080 }, { 760, -700 } } },
    }
    E.reset()
end

function E.reset(saved)
    E.tanks = {}
    for i, d in ipairs(E.defs) do
        local t = newTank(d)
        if saved and saved[i] then
            t.trackL, t.trackR = saved[i].trackL or t.trackL, saved[i].trackR or t.trackR
            if saved[i].x and not saved[i].dead then t.x, t.z, t.yaw = saved[i].x, saved[i].z, saved[i].yaw or 0 t.y = G.world.groundHeight(t.x, t.z) end
        end
        if saved and saved[i] and saved[i].dead then
            t.alive = false
            t.state = "dead"
            t.x, t.z, t.yaw = saved[i].x, saved[i].z, saved[i].yaw
            t.y = G.world.groundHeight(t.x, t.z)
            t.burnT = 999
            t.turretOff = true
            t.looted = saved[i].looted
        end
        E.tanks[#E.tanks + 1] = t
        E.updateFrames(t)
        if t.trackL <= 0 then E.throwTrack(t, -1, true) end
        if t.trackR <= 0 then E.throwTrack(t, 1, true) end
    end
end

function E.serialize()
    local out = {}
    for i, t in ipairs(E.tanks) do
        out[i] = { dead = not t.alive, x = t.x, z = t.z, yaw = t.yaw, looted = t.looted, trackL = t.trackL, trackR = t.trackR }
    end
    return out
end

function E.updateFrames(t)
    t.frame:setYawNormal(t.yaw, t.nx, t.ny, t.nz)
    t.frame.px, t.frame.py, t.frame.pz = t.x, t.y, t.z
    local tl = M3.frame()
    tl:setYaw(t.turretYaw)
    local tp = t.v.turretPos
    tl.px, tl.py, tl.pz = tp[1], tp[2], tp[3]
    if t.turretOff and t.turretFly then
        t.turretFrame:setYawPitchRoll(t.turretFly.yaw, t.turretFly.pitch, t.turretFly.roll)
        t.turretFrame.px, t.turretFrame.py, t.turretFrame.pz = t.turretFly.x, t.turretFly.y, t.turretFly.z
    else
        t.frame:compose(tl, t.turretFrame)
    end
    local gl = M3.frame()
    gl:setYawPitchRoll(0, t.gunPitch, 0)
    local tr = t.v.trunnion
    gl.px, gl.py, gl.pz = tr[1], tr[2], tr[3]
    t.turretFrame:compose(gl, t.gunFrame)
end

function E.addSets(sets)
    for _, t in ipairs(E.tanks) do
        sets[#sets + 1] = t.set
        sets[#sets + 1] = t.turretSet
    end
end

---------------------------------------------------------------------------
-- perception & aiming
---------------------------------------------------------------------------
local function chooseTarget(t)
    local pl = G.player
    local T = G.tank
    local cands = {}
    if not T.destroyed then cands[#cands + 1] = { x = T.x, y = T.y + 1.6, z = T.z, kind = "tank" } end
    if pl.frameName == "world" and pl.mode ~= "dead" then cands[#cands + 1] = { x = pl.x, y = pl.y + 1.2, z = pl.z, kind = "player" } end
    local best, bd = nil, 1e9
    local vis = 1
    if G.environment then vis = 0.55 + 0.45 * G.environment.daylight end
    if G.weather then vis = vis * (1 - 0.4 * G.weather.intensity) end
    local range = 240 * vis
    if t.alertT and t.alertT > 0 then range = range * 1.4 end
    for _, c in ipairs(cands) do
        local d = U.dist3(t.x, t.y + 2.4, t.z, c.x, c.y, c.z)
        if d < range and d < bd then
            local dx, dy, dz, l = U.norm3(c.x - t.x, c.y - t.y - 2.4, c.z - t.z)
            local blocked = G.world.rayTerrain(t.x, t.y + 2.4, t.z, dx, dy, dz, l - 3)
            if not blocked then
                local hit = P.raycast({ G.world.staticSet }, t.x, t.y + 2.4, t.z, dx, dy, dz, l - 3, function(b) return not b.tree end)
                if not hit then best, bd = c, d end
            end
        end
    end
    return best, bd
end

-- simple ballistic pitch for a given range and height difference
local function ballisticPitch(dist, dh, speed)
    local g = 9.8
    local v2 = speed * speed
    local root = v2 * v2 - g * (g * dist * dist + 2 * dh * v2)
    if root < 0 then return math.atan2(dh, dist) end
    return math.atan((v2 - math.sqrt(root)) / (g * dist))
end

function E.alert(t, x, z)
    if not t.alive then return end
    t.alertT = 20
    t.alertX, t.alertZ = x, z
    if t.state == "patrol" then t.state = "alert" t.timer = 15 end
end

local function driveTo(t, x, z, speed, dt)
    local W = G.world
    -- a thrown track: going nowhere, the turret still turns
    if t.trackL <= 0 or t.trackR <= 0 then t.speed = U.approach(t.speed, 0, dt * 4) return false end
    speed = speed * t.v.speed / 4.2
    local want = math.atan2(z - t.z, x - t.x)
    local diff = U.angleTo(t.yaw, want)
    t.yaw = t.yaw + U.clamp(diff, -0.4 * dt, 0.4 * dt)
    local sp = math.abs(diff) > 0.6 and 0.6 or speed
    t.speed = U.approach(t.speed, sp, dt * 1.5)
    local c, s = math.cos(t.yaw), math.sin(t.yaw)
    local nx, nz = t.x + c * t.speed * dt, t.z + s * t.speed * dt
    for _, off in ipairs({ -2.0, 0, 2.0 }) do
        local px, pz, hit = P.circlePush({ W.staticSet }, nx + c * off, t.y, nz + s * off, 1.9, 0.7, 3.0)
        if hit then nx, nz = nx + px, nz + pz t.speed = t.speed * 0.8 end
    end
    -- prints in the snow, like ours (only where someone might see them: the decal ring is shared)
    t.markAcc = (t.markAcc or 0) + U.dist2(t.x, t.z, nx, nz)
    t.x, t.z = nx, nz
    if t.markAcc > 0.7 then
        t.markAcc = 0
        local cam = G.camera
        if math.abs(cam.x - t.x) < 250 and math.abs(cam.z - t.z) < 250 then
            local depth = G.snow and G.snow.depth(t.x, t.z) or 0.3
            for _, side in ipairs({ -1.15, 1.15 }) do
                G.effects.trackMark(t.x - c * 2.2 - s * side, t.z - s * 2.2 + c * side, t.yaw, depth)
            end
        end
    end
    return U.dist2(t.x, t.z, x, z) < 6
end

local function updateTank(t, dt)
    local W = G.world
    if not t.alive then
        t.burnT = t.burnT + dt
        if t.turretFly then
            local f = t.turretFly
            if f.vy then
                f.vy = f.vy - 9.8 * dt
                f.x, f.y, f.z = f.x + f.vx * dt, f.y + f.vy * dt, f.z + f.vz * dt
                f.pitch, f.roll = f.pitch + f.spin * dt, f.roll + f.spin * 0.6 * dt
                local gh = W.height(f.x, f.z) + 0.5
                if f.y < gh then
                    f.y = gh
                    f.vy = nil
                    G.effects.snowPuff(f.x, f.y, f.z, 3)
                    if G.audio then G.audio.play("clang", { x = f.x, y = f.y, z = f.z, big = true }) end
                end
            end
        end
        if t.burnT < 240 and math.random() < dt * 25 then
            local fx, fy, fz = t.frame:toWorld(-0.5 + (math.random() - 0.5) * 3, 1.7, (math.random() - 0.5) * 2)
            G.effects.fire(fx, fy, fz, 1.8)
        end
        E.updateFrames(t)
        return
    end
    t.reload = math.max(0, t.reload - dt)
    t.mgCool = math.max(0, t.mgCool - dt)
    t.alertT = math.max(0, (t.alertT or 0) - dt)
    t.senseT = (t.senseT or 0) - dt
    if t.senseT <= 0 then
        t.senseT = 0.4
        local target, d = chooseTarget(t)
        t.target, t.targetD = target, d
        if target then
            t.lastX, t.lastZ = target.x, target.z
            if t.state ~= "engage" then
                t.state = "engage"
                if G.audio then G.audio.play("enemy_alert", { x = t.x, y = t.y, z = t.z }) end
            end
            t.lostT = 0
        end
    end
    -- hear the player's engine and gunfire
    if t.state == "patrol" and G.tank.engineOn and U.dist2(t.x, t.z, G.tank.x, G.tank.z) < 120 then
        E.alert(t, G.tank.x, G.tank.z)
    end
    local targetYaw = nil
    if t.state == "patrol" then
        local wp = t.route[t.wp]
        if driveTo(t, wp[1], wp[2], 4.2, dt) then t.wp = t.wp % #t.route + 1 end
        t.turretYaw = U.dampAngle(t.turretYaw, math.sin(love.timer.getTime() * 0.15 + t.id) * 0.8, 0.5, dt)
    elseif t.state == "alert" then
        t.speed = U.approach(t.speed, 0, dt * 2)
        targetYaw = math.atan2(t.alertZ - t.z, t.alertX - t.x)
        t.timer = t.timer - dt
        if t.timer < 8 then driveTo(t, t.alertX, t.alertZ, 3, dt) end
        if t.timer <= 0 then t.state = "patrol" end
    elseif t.state == "engage" then
        if t.target then
            t.lostT = 0
            targetYaw = math.atan2(t.target.z - t.z, t.target.x - t.x)
            -- close in to effective range, then stop to shoot
            if t.targetD > 170 then driveTo(t, t.target.x, t.target.z, 4.5, dt)
            else t.speed = U.approach(t.speed, 0, dt * 2.5) end
        else
            t.lostT = (t.lostT or 0) + dt
            t.speed = U.approach(t.speed, 0, dt * 2)
            if t.lastX then targetYaw = math.atan2(t.lastZ - t.z, t.lastX - t.x) end
            if t.lostT > 3 and t.lastX then driveTo(t, t.lastX, t.lastZ, 3.5, dt) end
            if t.lostT > 25 then t.state = "patrol" end
        end
    end
    -- turret traverse toward target: work in the hull frame so slopes are handled
    if targetYaw then
        local aimX, aimY, aimZ
        if t.target then aimX, aimY, aimZ = t.target.x, t.target.y, t.target.z
        else aimX, aimY, aimZ = t.x + math.cos(targetYaw) * 50, t.y + 2.2, t.z + math.sin(targetYaw) * 50 end
        local px, py, pz = t.turretFrame.px, t.turretFrame.py + 0.5, t.turretFrame.pz
        local dist = U.dist2(px, pz, aimX, aimZ)
        local elev = ballisticPitch(dist, aimY - py, 760)
        local hx, hz = aimX - px, aimZ - pz
        local hl = math.sqrt(hx * hx + hz * hz)
        local wx, wy, wz = hx / hl * math.cos(elev), math.sin(elev), hz / hl * math.cos(elev)
        local lx, ly, lz = t.frame:dirToLocal(wx, wy, wz)
        local rel = math.atan2(lz, lx)
        local diff = U.angleTo(t.turretYaw, rel)
        t.turretYaw = t.turretYaw + U.clamp(diff, -0.32 * dt, 0.32 * dt)
        if t.target then
            local tx2, ty2, tz2 = t.turretFrame:dirToLocal(wx, wy, wz)
            local want = math.atan2(ty2, math.sqrt(tx2 * tx2 + tz2 * tz2))
            t.gunPitch = U.approach(t.gunPitch, U.clamp(want, -0.3, 0.35), dt * 0.25)
            local pitchOk = math.abs(t.gunPitch - U.clamp(want, -0.3, 0.35)) < 0.015
            t.dbgWant, t.dbgDiff = want, diff
            if math.abs(diff) < 0.03 and pitchOk then t.aimT = t.aimT + dt else t.aimT = math.max(0, t.aimT - dt) end
            if t.reload <= 0 and t.aimT > 1.4 then
                E.fire(t)
            end
            -- coaxial MG bursts against infantry
            if t.target.kind == "player" and t.targetD < 120 and math.abs(diff) < 0.08 and t.mgCool <= 0 then
                t.mgCool = 0.1
                t.burst = (t.burst or 0) + 1
                if t.burst > 12 then t.burst = 0 t.mgCool = 2.5 end
                local gf = t.gunFrame
                local mx, my, mz = gf:toWorld(0.5, 0, 0.3)
                local dx, dy, dz = U.norm3(t.target.x - mx + (math.random() - 0.5) * 2, t.target.y - my + (math.random() - 0.5), t.target.z - mz + (math.random() - 0.5) * 2)
                G.weapons.hitscan(mx, my, mz, dx, dy, dz, 150, 9, "enemy", t.burst % 3 == 0)
                G.effects.muzzleFlash(mx, my, mz, dx, dy, dz, 0.4)
                if G.audio then G.audio.play("mg", { x = mx, y = my, z = mz }) end
            end
        end
    end
    -- terrain following
    local c, s = math.cos(t.yaw), math.sin(t.yaw)
    local hs = {}
    for i, o in ipairs({ { 2.6, -1.4 }, { 2.6, 1.4 }, { -2.8, -1.4 }, { -2.8, 1.4 } }) do
        hs[i] = W.groundHeight(t.x + c * o[1] - s * o[2], t.z + s * o[1] + c * o[2])
    end
    local dp, dr = ((hs[1] + hs[2]) - (hs[3] + hs[4])) / 2 / 5.4, ((hs[2] + hs[4]) - (hs[1] + hs[3])) / 2 / 2.8
    local fx, fy, fz = U.norm3(c, dp, s)
    local rx, ry, rz = U.norm3(-s, dr, c)
    local nx, ny, nz = U.norm3(U.cross(rx, ry, rz, fx, fy, fz))
    local k = 1 - math.exp(-4 * dt)
    t.nx, t.ny, t.nz = U.norm3(t.nx + (nx - t.nx) * k, t.ny + (ny - t.ny) * k, t.nz + (nz - t.nz) * k)
    t.y = U.damp(t.y, (hs[1] + hs[2] + hs[3] + hs[4]) / 4, 8, dt)
    if t.speed > 0.5 and math.random() < dt * 4 then
        local ex, ey, ez = t.frame:toWorld(-3.2, 1.3, 0)
        G.effects.smoke(ex, ey, ez, 0.5, 0.2, 0.2, 0.22, 2.5)
    end
    -- running gear: each side follows its own belt speed (hull speed +/- the turn)
    local yawRate = dt > 0 and U.angleTo(t.prevYaw or t.yaw, t.yaw) / dt or 0
    t.prevYaw = t.yaw
    local vL, vR = t.speed + yawRate * 1.5, t.speed - yawRate * 1.5
    t.trackOffL = (t.trackOffL - vL * dt * TM.TRACK_UV) % 1000
    t.trackOffR = (t.trackOffR - vR * dt * TM.TRACK_UV) % 1000
    t.wheelAngL = (t.wheelAngL - vL * dt / t.v.wheelR) % (2 * math.pi)
    t.wheelAngR = (t.wheelAngR - vR * dt / t.v.wheelR) % (2 * math.pi)
    E.updateFrames(t)
end

function E.fire(t)
    t.reload = 8 + math.random() * 3
    local gf = t.gunFrame
    local mx, my, mz = gf:toWorld(t.v.muzzle + 0.05, 0, 0)
    local err = math.max(0.004, 0.02 - t.aimT * 0.004)
    local dx, dy, dz = U.norm3(gf.fx + (math.random() - 0.5) * err, gf.fy + (math.random() - 0.5) * err, gf.fz + (math.random() - 0.5) * err)
    local kind = (t.target and t.target.kind == "player") and "HE" or "AP"
    G.weapons.fireShell(kind, mx, my, mz, dx, dy, dz, "enemy")
    G.effects.muzzleBlast(mx, my, mz, dx, dy, dz, 1)
    if G.audio then G.audio.play("cannon_far", { x = mx, y = my, z = mz, big = true }) end
    t.aimT = t.aimT * 0.5
end

function E.update(dt)
    local px, py, pz = G.player.feetWorld()
    for _, t in ipairs(E.tanks) do
        local d = U.dist2(px, pz, t.x, t.z)
        if d < 650 or not t.alive then updateTank(t, dt) end
        -- first sighting: make it very clear that this is dangerous
        if t.alive and not t.spotted and d < 210 then
            local cam = G.camera
            local dx, dy, dz, l = U.norm3(t.x - cam.x, t.y + 1.5 - cam.y, t.z - cam.z)
            if dx * cam.fx + dy * cam.fy + dz * cam.fz > 0.8 and not G.world.rayTerrain(cam.x, cam.y, cam.z, dx, dy, dz, l - 3) then
                t.spotted = true
                if G.ui then G.ui.notify("ENEMY ARMOUR") end
                if G.audio then G.audio.play("sting", {}) end
                if G.missions then G.missions.event("enemy_spotted", t) end
            end
        end
    end
end

---------------------------------------------------------------------------
-- damage
---------------------------------------------------------------------------
function E.raycast(ox, oy, oz, dx, dy, dz, maxT)
    local bestT, best, nx, ny, nz
    for _, t in ipairs(E.tanks) do
        if U.dist3(ox, oy, oz, t.x, t.y, t.z) < maxT + 8 then
            local h, a, b, c = P.raycast({ t.set, t.turretSet }, ox, oy, oz, dx, dy, dz, bestT or maxT)
            if h then bestT, best, nx, ny, nz = h, t, a, b, c end
        end
    end
    if best then return bestT, best, nx, ny, nz end
end

-- a track shot off: the tank sits where it is, the belt lies beside it
local function throwTrack(t, side, quiet)
    local f = t.frame
    local x, y, z = f:toWorld(t.models.idlerX + 0.3, 0, side * 2.2)
    t.lying[#t.lying + 1] = { side = side, x = x, y = G.world.groundHeight(x, z), z = z, yaw = t.yaw + side * 0.06, mat = {} }
    if quiet then return end
    for k = 0, 3 do
        local px, py, pz = f:toWorld(1.8 - k * 1.3, 0.5, side * 1.3)
        G.effects.debris(px, py, pz, "metal", 2, 3.5, 0.16)
    end
    if G.audio then G.audio.play("track_snap", { x = x, y = y + 0.5, z = z, big = true }) end
    if G.ui then G.ui.notify("TRACK HIT - " .. (t.v.heavy and "IS-2" or "T-34") .. " IMMOBILISED") end
end

E.throwTrack = throwTrack

function E.hit(t, dmg, x, y, z, dx, dz, kind)
    if not t.alive then return end
    local lx, ly, lz = t.frame:toLocal(x, y, z)
    -- running gear: a hit low on the side tears the track off
    if ly < 1.05 and math.abs(lz) > 0.95 then
        local key = lz > 0 and "trackR" or "trackL"
        local before = t[key]
        t[key] = math.max(0, t[key] - dmg * 1.1)
        if before > 0 and t[key] <= 0 then throwTrack(t, lz > 0 and 1 or -1) end
        dmg = dmg * 0.35
    end
    local mult = 1
    if lx > 1.8 and ly < 1.7 then mult = 0.55 end           -- sloped glacis
    if lx < -2.2 then mult = 1.5 end                         -- rear
    if math.abs(lz) > 1.3 and ly < 1.7 then mult = 1.15 end  -- sides
    if kind == "AP" and math.random() < 0.08 and mult < 1 then
        if G.ui then G.ui.notify("RICOCHET!") end
        mult = 0.1
    end
    t.hp = t.hp - dmg * mult
    E.alert(t, G.tank.x, G.tank.z)
    if t.hp <= 0 then E.destroy(t) elseif G.ui and kind then G.ui.notify(mult > 1.2 and "HIT - REAR ARMOR" or (mult < 0.7 and "HIT - FRONT ARMOR" or "HIT")) end
end

function E.splash(x, y, z, radius, damage, skip)
    for _, t in ipairs(E.tanks) do
        if t ~= skip and t.alive then
            local d = U.dist3(x, y, z, t.x, t.y + 1, t.z)
            if d < radius * 0.7 then t.hp = t.hp - damage * 0.05 * (1 - d / radius) if t.hp <= 0 then E.destroy(t) end end
        end
    end
end

function E.destroy(t)
    t.alive = false
    t.state = "dead"
    t.burnT = 0
    t.turretOff = true
    local x, y, z = t.turretFrame.px, t.turretFrame.py, t.turretFrame.pz
    t.turretFly = { x = x, y = y, z = z, vx = (math.random() - 0.5) * 6, vy = 11, vz = (math.random() - 0.5) * 6,
                    yaw = t.yaw + t.turretYaw, pitch = 0, roll = 0, spin = (math.random() - 0.5) * 4 }
    G.effects.explosion(t.x, t.y + 1.5, t.z, 2.5)
    G.effects.explosion(t.x, t.y + 2.5, t.z, 1.5)
    if G.audio then G.audio.play("explosion", { x = t.x, y = t.y, z = t.z, big = true }) end
    if G.ui then G.ui.notify("ENEMY TANK DESTROYED") end
    if G.missions then G.missions.event("enemy_destroyed", t) end
    G.world.fires[#G.world.fires + 1] = { x = t.x, y = t.y + 1.5, z = t.z, r = 6 }
end

function E.addLights(list)
    for _, t in ipairs(E.tanks) do
        if t.alive then
            -- dim searchlight beam ahead of the turret
            local x, y, z = t.turretFrame:toWorld(8, 0.4, 0.8)
            list[#list + 1] = { x, y, z, 10, 1.0, 0.85, 0.6, 0.9 }
        elseif t.burnT < 240 then
            list[#list + 1] = { t.x, t.y + 2.5, t.z, 14, 1.0, 0.5, 0.2, 1.4 * (0.8 + math.random() * 0.4) }
        end
    end
end

local wheelLocal, wheelWorld = M3.frame(), M3.frame()

function E.draw()
    for _, t in ipairs(E.tanks) do
        if R.visible(t.x, t.y + 1.5, t.z, 7) then
            local m = t.models
            local tint = (not t.alive) and { 0.22, 0.2, 0.18, 1 } or nil
            local p = tint and { tint = tint } or nil
            local hullM = t.frame:matrix(t.mats[1])
            R.drawModel(m.hull, hullM, p)
            if t.trackL > 0 then R.drawModel(m.trackL, hullM, { uv = { t.trackOffL, 0 }, tint = tint }) end
            if t.trackR > 0 then R.drawModel(m.trackR, hullM, { uv = { t.trackOffR, 0 }, tint = tint }) end
            for _, w in ipairs(t.wheels) do
                local ang = (w.side < 0 and t.wheelAngL or t.wheelAngR)
                wheelLocal:setYawPitchRoll(0, ang * (w.sprocket and 1.1 or 1) + w.x * 1.3, 0)
                wheelLocal.px, wheelLocal.py, wheelLocal.pz = w.x, w.y, w.z
                t.frame:compose(wheelLocal, wheelWorld)
                R.drawModel(w.sprocket and m.sprocket or m.wheel, wheelWorld:matrix(w.mat), p)
            end
            R.drawModel(m.turret, t.turretFrame:matrix(t.mats[2]), p)
            R.drawModel(m.gun, t.gunFrame:matrix(t.mats[3]), p)
            if t.alive then R.drawModel(m.light, t.turretFrame:matrix(t.mats[4]), { emissive = 1 }) end
        end
        for _, l in ipairs(t.lying) do
            if R.visible(l.x, l.y, l.z, 6) then
                local c, s = math.cos(l.yaw), math.sin(l.yaw)
                local mm = l.mat
                mm[1], mm[2], mm[3], mm[4] = c, 0, -s, l.x
                mm[5], mm[6], mm[7], mm[8] = 0, 1, 0, l.y
                mm[9], mm[10], mm[11], mm[12] = s, 0, c, l.z
                mm[13], mm[14], mm[15], mm[16] = 0, 0, 0, 1
                R.drawModel(t.models.lyingTrack, mm)
            end
        end
    end
end

return E
