-- Deep snow: how deep it lies (roads are packed, fields are deep), drifts across the roads that the
-- tank has to plough through, snow building up on the tank (tracks and running gear, the bow, the
-- decks, the turret roof) and the engine's heat melting it off again in clouds of steam.
local U = require("src.utils")
local MB = require("src.engine.meshbuilder")
local R = require("src.engine.renderer")
local M3 = require("src.engine.math3d")

local S = {}
local G

---------------------------------------------------------------------------
-- depth
---------------------------------------------------------------------------
-- metres of loose snow over the ground: packed thin on the roads, knee deep in the open
function S.depth(x, z)
    local W = G.world
    local _, onRoad = W.groundHeight(x, z)
    if onRoad then return 0.04 end
    local d = 0.26 + 0.2 * U.fbm(x / 70, z / 70, 2, 77)
    for _, l in ipairs(W.locations) do
        if not l.noFlatten and math.abs(x - l.x) < l.r and math.abs(z - l.z) < l.r then d = d * 0.65 break end
    end
    return d
end

---------------------------------------------------------------------------
-- models
---------------------------------------------------------------------------
-- a wind-shaped mound at its real size: x along the road (w), z across it (l). The mesh is rebuilt
-- as the drift is ploughed flatter and wider (the shader cannot correct normals for a scaled matrix).
local function buildDrift(d, h)
    local mb = MB.new(1801 + math.floor(d.x + d.z))
    mb.jitter = 0.03
    mb:material("snow"):color(0.97, 0.98, 1.0)
    local wl = d.w * (1 + (1 - h) * 0.3)
    local hgt = d.h0 * (0.15 + 0.85 * h)
    local segU, segV = 12, 4
    local function P(i, j)
        local a = i / segU * 2 * math.pi
        local t = j / segV                          -- 0 at the crest, 1 at the rim
        local r = 0.5 * math.sin(t * math.pi / 2)
        local y = math.cos(t * math.pi / 2) - 0.08
        -- a sharper lee side gives the drift its shape
        local lee = math.cos(a) > 0 and 0.8 or 1.15
        return math.cos(a) * r * lee * wl, y * (1 + 0.12 * math.sin(a * 3)) * hgt, math.sin(a) * r * d.l,
            math.cos(a) * 0.5 * t + 0.5, math.sin(a) * 0.5 * t + 0.5
    end
    for i = 0, segU - 1 do
        for j = 0, segV - 1 do
            local ax, ay, az, au, av = P(i, j)
            local bx, by, bz, bu, bv = P(i + 1, j)
            local cx, cy, cz, cu, cv = P(i + 1, j + 1)
            local dx, dy, dz, du, dv = P(i, j + 1)
            if j > 0 then mb:tri(ax, ay, az, au, av, bx, by, bz, bu, bv, cx, cy, cz, cu, cv) end
            mb:tri(ax, ay, az, au, av, cx, cy, cz, cu, cv, dx, dy, dz, du, dv)
        end
    end
    return mb:build()
end

-- thin overlays lying on the tank's surfaces, revealed by the alpha mask as snow builds up
local function overlay(fn, seed)
    local mb = MB.new(seed)
    mb.jitter = 0.02
    mb.texScale = 0.8
    mb:material("snowmask"):color(1, 1, 1)
    fn(mb)
    return mb:build()
end

local function buildOverlays()
    local o = {}
    -- engine deck and rear deck (melts first when the engine is warm)
    o.deck = overlay(function(mb)
        mb:box(-3.9, 2.35, -1.82, -2.05, 2.43, 1.82, { bottom = false })
        mb:box(-3.86, 2.82, -1.76, -3.42, 2.86, -0.86, { bottom = false })   -- on the jerry cans
    end, 1811)
    -- the hull roof in front of and around the turret
    o.hull = overlay(function(mb)
        mb:box(-2.05, 2.35, -1.84, 3.12, 2.42, -1.55, { bottom = false })
        mb:box(-2.05, 2.35, 1.55, 3.12, 2.42, 1.84, { bottom = false })
        mb:box(1.75, 2.35, -1.55, 3.12, 2.42, 1.55, { bottom = false })
        mb:box(-2.05, 2.35, -1.55, -1.45, 2.42, 1.55, { bottom = false })
    end, 1812)
    -- snow pushed up against the bow and the lower glacis
    o.front = overlay(function(mb)
        mb:box(3.15, 1.56, -1.84, 3.24, 2.34, 1.84, { back = false })
        mb:hexa({ { 2.95, 0.48, -1.5 }, { 3.42, 0.6, -1.5 }, { 3.42, 0.6, 1.5 }, { 2.95, 0.48, 1.5 },
                  { 3.2, 1.5, -1.5 }, { 3.27, 1.5, -1.5 }, { 3.27, 1.5, 1.5 }, { 3.2, 1.5, 1.5 } })
        mb:box(3.15, 1.5, -1.98, 3.9, 1.6, -1.42, { bottom = false })          -- front fenders
        mb:box(3.15, 1.5, 1.42, 3.9, 1.6, 1.98, { bottom = false })
    end, 1813)
    -- packed into the running gear: along both track faces, on the top run and between the wheels
    o.tracks = overlay(function(mb)
        for _, s in ipairs({ -1, 1 }) do
            local z0, z1 = s > 0 and 1.96 or -2.02, s > 0 and 2.02 or -1.96
            mb:box(-3.95, 0.02, z0, 3.75, 0.62, z1, { top = false, bottom = false })
            mb:box(-3.95, 0.02, s > 0 and 1.42 or -2.0, 3.75, 0.2, s > 0 and 2.0 or -1.42, { bottom = false })
            mb:box(-3.55, 1.17, s > 0 and 1.45 or -1.97, 3.3, 1.22, s > 0 and 1.97 or -1.45, { bottom = false })
        end
    end, 1814)
    -- turret roof (turret space)
    o.turret = overlay(function(mb)
        mb:box(-1.62, 1.1, -1.37, 1.37, 1.15, 1.37, { bottom = false })
    end, 1815)
    return o
end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------
function S.init(game)
    G = game
    S.overlays = buildOverlays()
    S.mats = {}
    S.reset()
end

function S.reset(saved)
    -- the tank has stood in the snow for days when the game begins
    S.cover = { deck = 0.55, hull = 0.6, front = 0.35, tracks = 0.45, turret = 0.65 }
    S.heat = 0
    S.steamT, S.sprayT, S.plowSound = 0, 0, 0
    for _, d in ipairs(G.world.drifts or {}) do d.h = 1 end
    if saved then
        for k, v in pairs(saved.cover or {}) do S.cover[k] = v end
        S.heat = saved.heat or 0
        for i, h in ipairs(saved.drifts or {}) do
            local d = G.world.drifts[i]
            if d then d.h = h end
        end
    end
end

function S.serialize()
    local drifts = {}
    for i, d in ipairs(G.world.drifts or {}) do drifts[i] = math.floor(d.h * 100) / 100 end
    return { cover = U.copy(S.cover), heat = S.heat, drifts = drifts }
end

local function add(k, v) S.cover[k] = U.clamp(S.cover[k] + v, 0, 1) end

-- a ploughed drift is not gone: the snow is shoved aside into a low, wide heap
local PLOUGHED = 0.2

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------
function S.update(dt)
    local T = G.tank
    local W = G.world
    local E = G.effects
    local w = G.weather.intensity
    local speed = math.abs(T.speed)
    -- engine temperature: warms in a couple of minutes, takes a long time to cool down
    if T.engineOn then S.heat = math.min(1, S.heat + dt / 90 * (0.6 + T.rpm / 2500))
    else S.heat = math.max(0, S.heat - dt / 600) end
    local depth = S.depth(T.x, T.z)
    T.snowDepth = depth
    -- snowfall settles on a tank that stands still; wind and speed blow the loose top layer off
    local still = speed < 0.8 and 1 or 0.2
    local fall = dt * w / 380 * still * (1 - S.heat * 0.8)
    add("deck", fall) add("hull", fall) add("turret", fall) add("front", fall * 0.5)
    add("hull", -dt * speed * 0.0006) add("turret", -dt * speed * 0.0005)
    -- the running gear packs up in deep snow and sheds on roads
    add("tracks", dt * speed * depth * 0.012 - dt * speed * 0.0016)
    add("front", dt * speed * math.max(0, depth - 0.15) * 0.01 - dt * speed * 0.0012)
    -- the engine's heat melts it: the deck over the engine first, the turret roof last
    local heat = S.heat
    local melt = { deck = heat / 45, hull = heat / 160, front = heat / 220, tracks = heat / 300, turret = heat / 400 }
    local melting = 0
    for k, m in pairs(melt) do
        local before = S.cover[k]
        add(k, -m * dt)
        melting = melting + (before - S.cover[k])
    end
    -- melt water steams off the hot deck
    S.steamT = S.steamT - dt
    if melting > 0 and heat > 0.3 and S.steamT <= 0 then
        S.steamT = 0.25 / math.max(0.2, heat)
        local f = T.frame
        local x, y, z = f:toWorld(-2.6 - math.random() * 1.2, 2.5, (math.random() - 0.5) * 3)
        E.spawn(x, y, z, (math.random() - 0.5) * 0.4, 0.5 + math.random() * 0.4, (math.random() - 0.5) * 0.4,
            2.2, 0.35, 0.7, 0.88, 0.9, 0.95, 0.35 * math.min(1, (S.cover.deck + S.cover.hull) * 2 + 0.3), false, 0.5, -0.15)
    end
    -- snow thrown up by the tracks in deep snow
    S.sprayT = S.sprayT - dt
    if speed > 1.5 and S.sprayT <= 0 then
        S.sprayT = 0.06 / math.max(0.3, depth * speed / 4)
        local f = T.frame
        local back = T.speed > 0 and -3.6 or 3.4
        for _, side in ipairs({ -1.75, 1.75 }) do
            local x, y, z = f:toWorld(back, 0.3, side)
            local vx, vy, vz = f:dirToWorld((T.speed > 0 and -1 or 1) * (1 + speed * 0.25), 1.5 + depth * 4, side * 0.4)
            E.spawn(x, y, z, vx + (math.random() - 0.5), vy * (0.6 + math.random() * 0.6), vz + (math.random() - 0.5),
                0.9, 0.18 + depth * 0.4, 0.5, 0.93, 0.95, 1, 0.75, false, 0.6, 4)
        end
    end
    -- drifts: ploughing through them slows the tank, throws snow and plasters the bow
    S.plowSound = S.plowSound - dt
    for _, d in ipairs(W.drifts or {}) do
        if d.h < 1 then d.h = math.min(1, d.h + dt * w / 900) end
        if d.h > PLOUGHED + 0.01 and math.abs(d.x - T.x) < 12 and math.abs(d.z - T.z) < 12 then
            local lx, ly, lz = T.frame:toLocal(d.x, T.y, d.z)
            local ca, sa = math.abs(math.cos(d.yaw - T.yaw)), math.abs(math.sin(d.yaw - T.yaw))
            local ext = (d.w * ca + d.l * sa) / 2       -- drift extent along the tank
            local wid = (d.w * sa + d.l * ca) / 2       -- across it
            if lx > -4.0 - ext and lx < 3.7 + ext and math.abs(lz) < 1.95 + wid * 0.8 then
                local hgt = d.h0 * d.h
                if speed > 0.3 then
                    local dh = dt * (0.25 + speed * 0.22) / math.max(0.4, d.h0)
                    d.h = math.max(PLOUGHED, d.h - dh)
                    T.speed = T.speed * (1 - math.min(0.9, dt * hgt * (1.2 + speed * 0.12)))
                    add("front", dh * 0.6) add("tracks", dh * 0.35)
                    if hgt > 0.35 then add("hull", dh * 0.15) end
                    local f = T.frame
                    local nose = T.speed > 0 and 3.6 or -4.1
                    for k = 1, 3 do
                        local x, y, z = f:toWorld(nose, 0.6 + math.random() * hgt, (math.random() - 0.5) * 3.6)
                        local sx = (math.random() < 0.5 and -1 or 1)
                        local vx, vy, vz = f:dirToWorld((T.speed > 0 and 1 or -1) * speed * 0.35, 1.5 + math.random() * 2.5, sx * (1.5 + math.random() * 2))
                        E.spawn(x, y, z, vx, vy, vz, 1.1, 0.25 + hgt * 0.4, 0.8, 0.94, 0.96, 1, 0.85, false, 0.5, 5)
                    end
                    if S.plowSound <= 0 then
                        S.plowSound = 0.35
                        if G.audio then G.audio.play("impact_snow", { x = d.x, y = d.y + 0.5, z = d.z, volume = 0.5 + hgt * 0.5 }) end
                        if G.camera and G.player.frameName == "tank" and hgt > 0.3 then G.camera.shake(0.15 + hgt * 0.2) end
                    end
                end
            end
        end
    end
end

-- the player wading through a drift
function S.driftAt(x, z)
    for _, d in ipairs(G.world.drifts or {}) do
        if d.h > 0.15 and math.abs(d.x - x) < 5 and math.abs(d.z - z) < 5 then
            local c, s = math.cos(-d.yaw), math.sin(-d.yaw)
            local lx, lz = (x - d.x) * c - (z - d.z) * s, (x - d.x) * s + (z - d.z) * c
            local nx, nz = lx / (d.w / 2), lz / (d.l / 2)
            local q = nx * nx + nz * nz
            if q < 1 then return d.h0 * d.h * (1 - q) end
        end
    end
    return 0
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
function S.drawDrifts()
    local cam = R.cam
    local i = 0
    for _, d in ipairs(G.world.drifts or {}) do
        if math.abs(d.x - cam.x) < 220 and math.abs(d.z - cam.z) < 220 and R.visible(d.x, d.y, d.z, d.l) then
            local hq = math.floor(d.h * 20 + 0.5) / 20
            if d.meshH ~= hq then d.mesh, d.meshH = buildDrift(d, hq), hq end
            i = i + 1
            local m = S.mats[i] or {}
            S.mats[i] = m
            local c, s = math.cos(d.yaw), math.sin(d.yaw)
            m[1], m[2], m[3], m[4] = c, 0, -s, d.x
            m[5], m[6], m[7], m[8] = 0, 1, 0, d.y
            m[9], m[10], m[11], m[12] = s, 0, c, d.z
            m[13], m[14], m[15], m[16] = 0, 0, 0, 1
            R.drawModel(d.mesh, m)
        end
    end
end

-- snow layers on the tank; hullM / turretM are the tank's model matrices for this frame
function S.drawTank(hullM, turretM)
    local c = S.cover
    local o = S.overlays
    for _, k in ipairs({ "deck", "hull", "front", "tracks" }) do
        if c[k] > 0.03 then R.drawModel(o[k], hullM, { alphaCut = 1 - c[k] * 0.97 }) end
    end
    if c.turret > 0.03 then R.drawModel(o.turret, turretM, { alphaCut = 1 - c.turret * 0.97 }) end
end

return S
