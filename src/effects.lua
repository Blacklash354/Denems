-- Particles (smoke, fire, sparks, snow, flashes), dynamic lights, tracers,
-- brass casings and ground decals (footprints / tank track marks).
local ffi = require("ffi")
local U = require("src.utils")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local Textures = require("src.engine.textures")
local M3 = require("src.engine.math3d")

local E = {}
local G
local lg = love.graphics

ffi.cdef [[ typedef struct { float x, y, z, u, v; unsigned char r, g, b, a; } bb_vertex; ]]
local BB_FORMAT = { { "VertexPosition", "float", 3 }, { "VertexTexCoord", "float", 2 }, { "VertexColor", "byte", 4 } }
local MAXP = 1600
local MAXDECAL = 2400

function E.init(game)
    G = game
    E.parts = {}
    E.flashes = {}
    E.casings = {}
    E.bbData = love.data.newByteData(MAXP * 6 * ffi.sizeof("bb_vertex"))
    E.bbPtr = ffi.cast("bb_vertex*", E.bbData:getFFIPointer())
    E.meshAlpha = lg.newMesh(BB_FORMAT, MAXP * 6, "triangles", "stream")
    E.meshAdd = lg.newMesh(BB_FORMAT, MAXP * 6, "triangles", "stream")
    -- sprite atlases from Kenney's CC0 packs (tools/fx_atlas.py): puffs and dirt for smoke, fireballs,
    -- muzzle flashes and a glow for the bright stuff; the old procedural textures if they are missing
    local function atlas(path)
        if not love.filesystem.getInfo(path) then return nil end
        local img = lg.newImage(path)
        img:setFilter("nearest", "nearest")
        return img
    end
    E.smokeAtlas, E.fireAtlas = atlas("assets/fx/smoke.png"), atlas("assets/fx/fire.png")
    E.meshAlpha:setTexture(E.smokeAtlas or Textures.get("smoke"))
    E.meshAdd:setTexture(E.fireAtlas or Textures.get("flare"))
    -- decals
    E.decalData = love.data.newByteData(MAXDECAL * 6 * ffi.sizeof("psx_vertex"))
    E.decalPtr = ffi.cast("psx_vertex*", E.decalData:getFFIPointer())
    E.decalMesh = lg.newMesh(MB.FORMAT, MAXDECAL * 6, "triangles", "dynamic")
    E.decalMesh:setTexture(Textures.get("trackprint"))
    E.decalCount, E.decalNext, E.decalDirty = 0, 0, false
    E.decalInfo = {}          -- per decal: base colour and how far the snow has filled it in
    E.fillT = 0
    E.decalModel = { parts = { { mesh = E.decalMesh } }, tris = 0 }
    -- blob shadows (rebuilt every frame)
    E.MAXSHADOW = 64
    E.shadowData = love.data.newByteData(E.MAXSHADOW * 6 * ffi.sizeof("psx_vertex"))
    E.shadowPtr = ffi.cast("psx_vertex*", E.shadowData:getFFIPointer())
    E.shadowMesh = lg.newMesh(MB.FORMAT, E.MAXSHADOW * 6, "triangles", "stream")
    E.shadowMesh:setTexture(Textures.get("blob"))
    E.shadowModel = { parts = { { mesh = E.shadowMesh } }, tris = 0 }
    -- casing models
    local mb = MB.new(5)
    mb:material("brass"):color(1, 1, 1)
    mb:cylinderX(-0.02, 0.02, 0, 0, 0.006, 0.006, 4)
    E.smallCasing = mb:build()
    mb = MB.new(6)
    mb:material("brass"):color(1, 1, 1)
    mb:cylinderX(-0.35, 0.3, 0, 0, 0.065, 0.06, 7)
    E.bigCasing = mb:build()
    E.casingMat = {}
    E.time = 0
end

function E.clear()
    E.parts, E.flashes, E.casings, E.debrisList = {}, {}, {}, {}
    E.decalCount, E.decalNext, E.decalDirty = 0, 0, true
    E.decalInfo = {}
    for i = 0, MAXDECAL * 6 - 1 do E.decalPtr[i].a = 0 end
end

-- atlas cells (see tools/fx_atlas.py): smoke 6x5 - puffs 0-24, dirt 25-27, soft smoke 28-29;
-- fire 4x4 - fireballs 0-8, muzzle flames 9-12, bright cores 13-14, glow 15
local SMOKE_COLS, SMOKE_ROWS, FIRE_COLS, FIRE_ROWS = 6, 5, 4, 4
E.CELL = { puff = { 0, 25 }, dirt = { 25, 3 }, fireball = { 0, 9 }, flame = { 9, 4 }, core = { 13, 2 }, glow = { 15, 1 } }
local function cellOf(kind) local c = E.CELL[kind] return c[1] + math.random(0, c[2] - 1) end

local function spawn(x, y, z, vx, vy, vz, life, size, grow, r, g, b, a, add, drag, grav, cell)
    if #E.parts >= MAXP then table.remove(E.parts, 1) end
    local p = { x = x, y = y, z = z, vx = vx, vy = vy, vz = vz, life = life, max = life, size = size, grow = grow or 0,
                r = r, g = g, b = b, a = a, add = add, drag = drag or 0, grav = grav or 0, rot = math.random() * 6.28,
                cell = cell or (add and 15 or math.random(0, 24)) }
    E.parts[#E.parts + 1] = p
    return p
end
E.spawn = spawn

local rnd = math.random
local function rs(s) return (rnd() - 0.5) * 2 * s end

function E.smoke(x, y, z, size, r, g, b, life)
    spawn(x, y, z, rs(0.3), 0.6 + rnd() * 0.5, rs(0.3), life or 3, size, size * 0.8, r or 0.3, g or 0.3, b or 0.32, 0.55, false, 0.4, -0.1)
end

function E.snowPuff(x, y, z, s)
    s = s or 1
    for i = 1, 3 do
        spawn(x + rs(0.3), y + 0.1, z + rs(0.3), rs(1.2 * s), 0.8 + rnd() * s, rs(1.2 * s), 0.9 + rnd() * 0.6, 0.3 * s, 0.9 * s,
              0.85, 0.88, 0.95, 0.6, false, 1.2, 2.5)
    end
end

function E.sparks(x, y, z, nx, ny, nz, n)
    for i = 1, (n or 6) do
        spawn(x, y, z, nx * 3 + rs(3), ny * 3 + rs(3) + 1, nz * 3 + rs(3), 0.25 + rnd() * 0.25, 0.05, 0, 1, 0.75, 0.35, 1, true, 0.5, 9)
    end
    E.flash(x, y, z, 3, 1, 0.7, 0.3, 0.8, 0.06)
end

function E.blood(x, y, z, n)
    for i = 1, (n or 6) do
        spawn(x, y, z, rs(1.5), rnd() * 2, rs(1.5), 0.6 + rnd() * 0.4, 0.12, 0.1, 0.35, 0.05, 0.05, 0.9, false, 0.5, 9)
    end
end

function E.impactSnow(x, y, z)
    for i = 1, 5 do
        spawn(x, y, z, rs(1.5), 1 + rnd() * 2, rs(1.5), 0.7 + rnd() * 0.5, 0.15, 0.6, 0.82, 0.85, 0.9, 0.7, false, 1.5, 6)
    end
end

function E.dust(x, y, z)
    for i = 1, 4 do
        spawn(x, y, z, rs(1), 0.5 + rnd(), rs(1), 0.8 + rnd() * 0.5, 0.15, 0.5, 0.5, 0.48, 0.45, 0.6, false, 1.5, 3)
    end
end

-- short-lived point light
function E.flash(x, y, z, radius, r, g, b, intensity, life)
    E.flashes[#E.flashes + 1] = { x = x, y = y, z = z, radius = radius, r = r, g = g, b = b, i = intensity, life = life, max = life }
end

function E.muzzleFlash(x, y, z, dx, dy, dz, s)
    s = s or 1
    -- a star of flame out of the muzzle, a hot core and a wisp of smoke
    spawn(x + dx * 0.1, y + dy * 0.1, z + dz * 0.1, dx * 2, dy * 2, dz * 2, 0.05, 0.3 * s, 1.5 * s, 1, 0.8, 0.45, 1, true, 0, 0, cellOf("flame"))
    spawn(x + dx * 0.3, y + dy * 0.3, z + dz * 0.3, dx * 4, dy * 4, dz * 4, 0.04, 0.2 * s, 1 * s, 1, 0.9, 0.6, 1, true, 0, 0, cellOf("core"))
    E.flash(x, y, z, 6 * s, 1, 0.75, 0.4, 1.6, 0.06)
    spawn(x, y, z, dx * 1 + rs(0.2), dy + 0.3, dz * 1 + rs(0.2), 0.8, 0.15 * s, 0.6 * s, 0.6, 0.6, 0.6, 0.35, false, 1, -0.2)
end

function E.muzzleBlast(x, y, z, dx, dy, dz, s)
    -- the cannon: a long tongue of fire, a fireball at the muzzle brake, then a ring of smoke and a
    -- burst of snow kicked off the ground by the blast
    for i = 1, 4 do
        local k = i * 0.6
        spawn(x + dx * k, y + dy * k, z + dz * k, dx * 6 + rs(1), dy * 6 + rs(1), dz * 6 + rs(1), 0.12, 0.8 + i * 0.3, 6, 1, 0.75, 0.4, 1, true, 3, 0,
              i == 1 and cellOf("core") or cellOf("fireball"))
    end
    for i = 1, 3 do
        spawn(x + dx * 0.5, y + dy * 0.5, z + dz * 0.5, dx * 10, dy * 10, dz * 10, 0.08, 0.6, 9, 1, 0.85, 0.5, 1, true, 4, 0, cellOf("flame"))
    end
    for i = 1, 18 do
        local a = rnd() * 6.28
        local px, pz = math.cos(a), math.sin(a)
        spawn(x + dx, y + dy, z + dz, dx * 8 + px * 4, dy * 8 + rnd() * 2, dz * 8 + pz * 4, 2.5 + rnd() * 1.5, 1.0, 2.2,
              0.55, 0.55, 0.56, 0.6, false, 2.0, -0.15)
    end
    local gy = G.world.groundHeight(x, z)
    if y - gy < 3.5 then
        for i = 1, 10 do
            local a = rnd() * 6.28
            spawn(x + math.cos(a) * 1.5, gy + 0.2, z + math.sin(a) * 1.5, math.cos(a) * 6, 0.5 + rnd() * 1.5, math.sin(a) * 6,
                  1.2 + rnd(), 0.6, 2.5, 0.88, 0.9, 0.95, 0.65, false, 1.6, 1)
        end
    end
    E.flash(x, y, z, 22, 1, 0.7, 0.35, 3.0, 0.12)
end

function E.explosion(x, y, z, s)
    s = s or 1
    -- fireball
    for i = 1, 14 do
        spawn(x, y + 0.5, z, rs(6 * s), rnd() * 7 * s, rs(6 * s), 0.3 + rnd() * 0.3, 1.4 * s, 5 * s, 1, 0.6, 0.25, 1, true, 3, -1, cellOf("fireball"))
    end
    spawn(x, y + 0.8, z, 0, 1, 0, 0.2, 2.8 * s, 7 * s, 1, 0.9, 0.6, 1, true, 0, 0, cellOf("core"))
    -- a column of dirty smoke that rolls up and hangs
    for i = 1, 18 do
        spawn(x + rs(1.5 * s), y + rnd() * 2 * s, z + rs(1.5 * s), rs(3 * s), 2 + rnd() * 4 * s, rs(3 * s), 4 + rnd() * 3, 1.4 * s, 2.6 * s,
              0.18, 0.17, 0.17, 0.75, false, 1.3, -0.4)
    end
    -- earth and snow thrown up: dark clods fall back, white spray drifts
    for i = 1, 14 do
        spawn(x, y + 0.3, z, rs(9 * s), 4 + rnd() * 10 * s, rs(9 * s), 1.4 + rnd(), 0.45 * s, 0.4, 0.28, 0.24, 0.2, 0.95, false, 0.3, 12, cellOf("dirt"))
    end
    for i = 1, 16 do
        spawn(x, y + 0.3, z, rs(9 * s), 4 + rnd() * 10 * s, rs(9 * s), 1.4 + rnd(), 0.18, 0.6, 0.82, 0.84, 0.9, 0.85, false, 0.6, 9)
    end
    -- glowing fragments
    for i = 1, 10 do
        spawn(x, y + 0.5, z, rs(14 * s), 3 + rnd() * 9 * s, rs(14 * s), 0.6 + rnd() * 0.6, 0.06, 0, 1, 0.6, 0.2, 1, true, 0.2, 12)
    end
    E.flash(x, y + 1, z, 30 * s, 1, 0.6, 0.25, 4.0, 0.35)
    E.scorch(x, z, 2.2 * s)
end

function E.fire(x, y, z, s)
    s = s or 1
    -- licking flames (tinted muzzle-flame sprites) and the odd small fireball
    local f = spawn(x + rs(0.2 * s), y, z + rs(0.2 * s), rs(0.2), 1.2 + rnd() * 0.8, rs(0.2), 0.45 + rnd() * 0.3, 0.3 * s, 0.4 * s, 1,
                    0.55 + rnd() * 0.2, 0.2, 1, true, 0.5, -1, rnd() < 0.7 and cellOf("flame") or cellOf("fireball"))
    f.rot = rs(0.25)          -- flames stand up
    if rnd() < 0.3 then
        spawn(x, y + 0.8 * s, z, rs(0.3), 1.2, rs(0.3), 4, 0.5 * s, 1.5 * s, 0.15, 0.14, 0.14, 0.5, false, 0.3, -0.2)
    end
end

-- glowing streak following a fast projectile
function E.tracer(x, y, z, dx, dy, dz, speed, life)
    local p = spawn(x, y, z, dx * speed, dy * speed, dz * speed, life or 0.25, 0.05, 0, 1, 0.75, 0.35, 1, true, 0, 0)
    p.stretch = 0.035
    return p
end

---------------------------------------------------------------------------
-- debris chunks flung from destroyed objects
---------------------------------------------------------------------------
E.debrisList = {}
E.debrisModels = {}
local WOODY = { wood = true, cloth = true, bark = true, planks = true, crate = true }
local METAL = { metal = true, vehicle = true, rust = true, sheet = true, car = true }
-- three shapes per kind of material: splintered planks, bent sheet metal, broken masonry
local function debrisModel(mat, v)
    local key = mat .. v
    local m = E.debrisModels[key]
    if m then return m end
    local mb = MB.new(9 + v * 7)
    mb.texScale = 2
    if WOODY[mat] then
        mb:material(mat):color(0.85, 0.8, 0.74)
        local l = 0.7 + v * 0.3
        -- a plank snapped at both ends: ragged, one corner torn away
        mb:hexa({ { -l, -0.06, -0.13 }, { l * 0.75, -0.06, -0.13 }, { l, -0.06, 0.12 }, { -l * 0.85, -0.06, 0.13 },
                  { -l * 0.95, 0.06, -0.13 }, { l * 0.8, 0.06, -0.12 }, { l * 0.9, 0.06, 0.13 }, { -l * 0.7, 0.06, 0.12 } })
        if v ~= 2 then
            -- a long splinter peeling off
            mb:hexa({ { l * 0.3, 0.05, -0.04 }, { l * 1.25, 0.12, -0.02 }, { l * 1.25, 0.12, 0.0 }, { l * 0.3, 0.05, 0.04 },
                      { l * 0.3, 0.09, -0.04 }, { l * 1.25, 0.13, -0.02 }, { l * 1.25, 0.13, 0.0 }, { l * 0.3, 0.09, 0.04 } })
        end
    elseif METAL[mat] then
        mb:material("metal"):color(0.55, 0.52, 0.5)
        -- a torn panel bent along a crease
        local w = 0.5 + v * 0.15
        local a = 0.5 + v * 0.35
        mb:box(-w, -0.02, -0.4, 0, 0.02, 0.4)
        mb:push() mb:rotateZ(a) mb:box(0, -0.02, -0.38, w * 0.9, 0.02, 0.35) mb:pop()
    else
        mb:material(mat):color(0.85, 0.85, 0.85)
        if v == 3 then
            -- a slab of wall with the rebar sticking out of the break
            mb:hexa({ { -0.6, -0.12, -0.45 }, { 0.55, -0.12, -0.5 }, { 0.6, -0.12, 0.45 }, { -0.5, -0.12, 0.5 },
                      { -0.58, 0.12, -0.42 }, { 0.5, 0.12, -0.5 }, { 0.62, 0.12, 0.4 }, { -0.55, 0.12, 0.48 } })
            mb:material("metal"):color(0.35, 0.25, 0.2)
            mb:box(0.55, -0.02, -0.25, 0.95, 0.02, -0.21)
            mb:box(0.55, -0.02, 0.15, 0.85, 0.02, 0.19)
        else
            local k = v == 1 and 1 or 0.7
            mb:hexa({ { -0.5, -0.4 * k, -0.45 }, { 0.5, -0.5 * k, -0.4 }, { 0.45, -0.45 * k, 0.5 }, { -0.45, -0.5 * k, 0.45 },
                      { -0.4, 0.45 * k, -0.5 }, { 0.5, 0.3 * k, -0.45 }, { 0.3, 0.5 * k, 0.45 }, { -0.5, 0.4 * k, 0.3 } })
        end
    end
    m = mb:build()
    E.debrisModels[key] = m
    return m
end

function E.debris(x, y, z, mat, n, power, size)
    for i = 1, n do
        if #E.debrisList > 160 then table.remove(E.debrisList, 1) end
        local a = rnd() * 6.28
        local sp = power * (0.3 + rnd() * 0.7)
        local tint = 0.7 + rnd() * 0.3
        E.debrisList[#E.debrisList + 1] = { x = x + rs(0.5), y = y + rnd() * 0.5, z = z + rs(0.5), vx = math.cos(a) * sp, vy = 2 + rnd() * power,
            vz = math.sin(a) * sp, rx = rnd() * 6, ry = rnd() * 6, sx = rs(8), sy = rs(8), s = size * (0.4 + rnd()),
            model = debrisModel(mat, math.random(1, 3)), tint = { tint, tint, tint, 1 }, life = 14 + rnd() * 8, rest = false, mat = {} }
    end
end

-- top of the tank's hull / turret at a hull-space point (nil off the tank)
local function tankTop(lx, lz)
    if lx < -4.0 or lx > 3.9 or lz < -2.0 or lz > 2.0 then return nil end
    local dx = lx - 0.35
    if dx * dx + lz * lz < 1.6 * 1.6 then return 3.5 end
    if lx > 3.15 or math.abs(lz) > 1.86 then return 1.62 end
    return 2.43
end

local function updateDebris(dt)
    local W = G.world
    local T = G.tank
    for i = #E.debrisList, 1, -1 do
        local d = E.debrisList[i]
        d.life = d.life - dt
        if d.life <= 0 then table.remove(E.debrisList, i)
        elseif d.onTank then
            -- riding on the tank: carried along, shaken loose bit by bit, slides off the back or the sides
            local o = d.onTank
            local sp = math.abs(T.speed)
            local gx, _, gz = T.frame:dirToLocal(0, -1, 0)
            o.vx = o.vx - (T.speed - (o.lastSpeed or T.speed)) * 0.6 + gx * 5 * dt + (math.random() - 0.5) * sp * 0.6 * dt
            o.vz = o.vz + (T.yawRate or 0) * T.speed * dt * 0.8 + gz * 5 * dt + (math.random() - 0.5) * sp * 0.6 * dt
            o.lastSpeed = T.speed
            o.vx, o.vz = o.vx * math.exp(-2 * dt), o.vz * math.exp(-2 * dt)
            -- the rattle of driving shakes it slowly towards the back
            o.lx, o.lz = o.lx + (o.vx - sp * 0.1) * dt, o.lz + o.vz * dt
            local top = tankTop(o.lx, o.lz)
            if not top or T.destroyed then
                local wx, wy, wz = T.frame:toWorld(o.lx, o.ly, o.lz)
                local cy, sy = math.cos(T.yaw), math.sin(T.yaw)
                d.x, d.y, d.z = wx, wy, wz
                d.vx, d.vy, d.vz = cy * T.speed, 0, sy * T.speed
                d.onTank, d.rest = nil, false
            else
                o.ly = top + d.s * 0.35
                d.x, d.y, d.z = T.frame:toWorld(o.lx, o.ly, o.lz)
                d.ry = o.ry + T.yaw
            end
        elseif not d.rest then
            d.vy = d.vy - 12 * dt
            d.x, d.y, d.z = d.x + d.vx * dt, d.y + d.vy * dt, d.z + d.vz * dt
            d.rx, d.ry = d.rx + d.sx * dt, d.ry + d.sy * dt
            -- landing on the tank's decks and turret roof
            if d.vy < 0 and not T.destroyed and math.abs(d.x - T.x) < 5 and math.abs(d.z - T.z) < 5 then
                local lx, ly, lz = T.frame:toLocal(d.x, d.y, d.z)
                local top = tankTop(lx, lz)
                if top and ly < top + d.s * 0.35 and ly > top - 0.6 then
                    d.onTank = { lx = lx, ly = top + d.s * 0.35, lz = lz, vx = 0, vz = 0, ry = d.ry - T.yaw }
                    d.life = math.max(d.life, 30)
                    if G.audio and math.random() < 0.5 then G.audio.play("clang", { x = d.x, y = d.y, z = d.z, volume = 0.25 + d.s * 0.6 }) end
                end
            end
            local gy = W.surfaceHeight(d.x, d.z, d.y + 0.5, 0.1) + d.s * 0.4
            if d.onTank then
                -- (landed this frame)
            elseif d.y < gy then
                d.y = gy
                if math.abs(d.vy) < 1.5 then d.rest = true
                else
                    d.vy = -d.vy * 0.3
                    d.vx, d.vz = d.vx * 0.5, d.vz * 0.5
                    d.sx, d.sy = d.sx * 0.5, d.sy * 0.5
                    if math.random() < 0.3 then E.snowPuff(d.x, d.y, d.z, 0.4) end
                end
            end
        end
    end
end

function E.drawDebris()
    for _, d in ipairs(E.debrisList) do
        if R.visible(d.x, d.y, d.z, 1) then
            local f = M3.frame()
            f:setYawPitchRoll(d.ry, d.rx, d.rx * 0.5)
            f.px, f.py, f.pz = d.x, d.y, d.z
            d.params = d.params or { tint = d.tint }
            R.drawModel(d.model, f:matrix(d.mat, d.s), d.params)
        end
    end
end

---------------------------------------------------------------------------
-- casings (physical bits of brass)
---------------------------------------------------------------------------
function E.casing(frameName, x, y, z, big)
    if #E.casings > 40 then table.remove(E.casings, 1) end
    local c = { frame = frameName, x = x, y = y, z = z, vx = rs(0.6) - (big and 1.5 or 0.3), vy = big and 0.5 or 1.5, vz = big and 0.2 or (0.8 + rnd()),
                rot = rnd() * 6, spin = rs(15), big = big, life = big and 60 or 20, bounced = 0 }
    E.casings[#E.casings + 1] = c
end

local function updateCasings(dt)
    local T = G.tank
    for i = #E.casings, 1, -1 do
        local c = E.casings[i]
        c.life = c.life - dt
        if c.life <= 0 then table.remove(E.casings, i)
        else
            c.vy = c.vy - 9.8 * dt
            c.x, c.y, c.z = c.x + c.vx * dt, c.y + c.vy * dt, c.z + c.vz * dt
            c.rot = c.rot + c.spin * dt
            local floor
            if c.frame == "tank" then
                floor = 0.64
                c.z = U.clamp(c.z, -1.3, 1.3)
                c.x = U.clamp(c.x, -1.6, 2.95)
            else floor = G.world.groundHeight(c.x, c.z) + 0.02 end
            if c.y < floor then
                c.y = floor
                if c.vy < -1 and c.bounced < 3 then
                    c.bounced = c.bounced + 1
                    if G.audio and c.bounced == 1 then G.audio.play(c.big and "casing_big" or "casing", { tank = c.frame == "tank", volume = 0.5 }) end
                end
                c.vy = -c.vy * 0.3
                c.vx, c.vz = c.vx * 0.5, c.vz * 0.5
                c.spin = c.spin * 0.5
            end
        end
    end
end

---------------------------------------------------------------------------
-- decals
---------------------------------------------------------------------------
-- a flat quad on the ground (roads included). fill: 0 = fresh; falling snow raises it to 1 and the
-- print fades into the snow (see fillDecals). permanent decals (scorches) never fill.
local function addDecal(x, z, yaw, w, l, r, g, b, a, permanent)
    local W = G.world
    local c, s = math.cos(yaw), math.sin(yaw)
    local hw, hl = w / 2, l / 2
    local pts = {}
    for k, o in ipairs({ { -hl, -hw }, { hl, -hw }, { hl, hw }, { -hl, hw } }) do
        local px, pz = x + c * o[1] - s * o[2], z + s * o[1] + c * o[2]
        pts[k] = { px, W.groundHeight(px, pz) + 0.025, pz }
    end
    local idx = E.decalNext
    E.decalNext = (E.decalNext + 1) % MAXDECAL
    E.decalCount = math.min(MAXDECAL, E.decalCount + 1)
    E.decalInfo[idx] = { r = r, g = g, b = b, a = a, fill = 0, permanent = permanent }
    local base = idx * 6
    local order = { 1, 3, 2, 1, 4, 3 }
    local uv = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 1, 0 } }
    for i = 1, 6 do
        local p = pts[order[i]]
        local v = E.decalPtr[base + i - 1]
        v.x, v.y, v.z = p[1], p[2], p[3]
        v.u, v.v = uv[order[i]][1], uv[order[i]][2] * l / 0.85
        v.nx, v.ny, v.nz = 0, 1, 0
        v.r, v.g, v.b, v.a = r * 255, g * 255, b * 255, a * 255
    end
    E.decalDirty = true
end

-- snow slowly fills the prints: slowly in calm weather, within a minute or so in a blizzard
local SNOWR, SNOWG, SNOWB = 0.92, 0.94, 0.98
local function fillDecals(step)
    local w = G.weather and G.weather.intensity or 0.3
    local rate = (1 / 420 + w * w / 50) * step
    local any = false
    for idx, d in pairs(E.decalInfo) do
        if not d.permanent and d.fill < 1 then
            d.fill = math.min(1, d.fill + rate)
            local f = d.fill
            local r, g, b = U.lerp(d.r, SNOWR, f), U.lerp(d.g, SNOWG, f), U.lerp(d.b, SNOWB, f)
            local a = d.a * (1 - f * f)
            local base = idx * 6
            for i = 0, 5 do
                local v = E.decalPtr[base + i]
                v.r, v.g, v.b, v.a = r * 255, g * 255, b * 255, a * 255
            end
            any = true
            if f >= 1 then E.decalInfo[idx] = nil end
        end
    end
    if any then E.decalDirty = true end
end

function E.footprint(x, z, yaw)
    if G.world.isRiver(x, z) then return end
    local _, onRoad = G.world.groundHeight(x, z)
    if onRoad then addDecal(x, z, yaw, 0.14, 0.3, 0.5, 0.5, 0.52, 0.6)
    else addDecal(x, z, yaw, 0.15, 0.32, 0.55, 0.6, 0.72, 0.6) end
end

-- one link-width print per track; darker on roads (pressed slush), a blue-shadowed trench in deep snow
function E.trackMark(x, z, yaw, depth)
    local _, onRoad = G.world.groundHeight(x, z)
    if onRoad then addDecal(x, z, yaw, 0.56, 0.85, 0.46, 0.46, 0.5, 0.78)
    else
        local k = U.clamp((depth or 0.3) / 0.45, 0.3, 1)
        addDecal(x, z, yaw, 0.6, 0.85, U.lerp(0.75, 0.5, k), U.lerp(0.78, 0.56, k), U.lerp(0.86, 0.7, k), 0.8)
    end
end

function E.scorch(x, z, r)
    addDecal(x, z, rnd() * 6, r * 2, r * 2, 0.12, 0.11, 0.1, 0.8, true)
end

---------------------------------------------------------------------------
-- update & draw
---------------------------------------------------------------------------
function E.update(dt)
    E.time = E.time + dt
    E.fillT = E.fillT + dt
    if E.fillT > 0.25 then fillDecals(E.fillT) E.fillT = 0 end
    local parts = E.parts
    local n = #parts
    local i = 1
    while i <= n do
        local p = parts[i]
        p.life = p.life - dt
        if p.life <= 0 then
            parts[i] = parts[n]
            parts[n] = nil
            n = n - 1
        else
            local d = math.exp(-p.drag * dt)
            p.vx, p.vy, p.vz = p.vx * d, p.vy * d - p.grav * dt, p.vz * d
            p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
            p.size = p.size + p.grow * dt
            i = i + 1
        end
    end
    for j = #E.flashes, 1, -1 do
        local f = E.flashes[j]
        f.life = f.life - dt
        if f.life <= 0 then table.remove(E.flashes, j) end
    end
    updateCasings(dt)
    updateDebris(dt)
    -- wind drift for smoke
    local wx, wz = 0, 0
    if G.weather then wx, wz = G.weather.windX or 0, G.weather.windZ or 0 end
    for _, p in ipairs(parts) do
        if not p.add and p.grav <= 0 then p.x, p.z = p.x + wx * 0.15 * dt, p.z + wz * 0.15 * dt end
    end
end

function E.addLights(list)
    for _, f in ipairs(E.flashes) do
        local k = f.life / f.max
        list[#list + 1] = { f.x, f.y, f.z, f.radius, f.r, f.g, f.b, f.i * k }
    end
end

local function buildBillboards(additive)
    local cam = R.cam
    local atlas = additive and E.fireAtlas or (not additive and E.smokeAtlas)
    local rx, ry, rz = R.camRight[1], R.camRight[2], R.camRight[3]
    local ux, uy, uz = R.camUp[1], R.camUp[2], R.camUp[3]
    local ptr = E.bbPtr
    local count = 0
    for _, p in ipairs(E.parts) do
        if p.add == additive then
            local dx, dy, dz = p.x - cam.x, p.y - cam.y, p.z - cam.z
            local along = dx * cam.fx + dy * cam.fy + dz * cam.fz
            if along > -2 and along < 260 then
                local k = p.life / p.max
                local a = p.a * (additive and k or math.min(1, k * 2.5))
                local s = p.size
                local ax, ay, az, bx, by, bz
                if p.stretch then
                    -- velocity aligned streak
                    local vx, vy, vz = U.norm3(p.vx, p.vy, p.vz)
                    local len = math.sqrt(p.vx * p.vx + p.vy * p.vy + p.vz * p.vz) * p.stretch
                    local wx, wy, wz = U.norm3(U.cross(vx, vy, vz, dx, dy, dz))
                    local w = 0.03 + along * 0.0015
                    ax, ay, az = wx * w, wy * w, wz * w
                    bx, by, bz = vx * len, vy * len, vz * len
                else
                    local c, sn = math.cos(p.rot), math.sin(p.rot)
                    ax, ay, az = (rx * c + ux * sn) * s, (ry * c + uy * sn) * s, (rz * c + uz * sn) * s
                    bx, by, bz = (ux * c - rx * sn) * s, (uy * c - ry * sn) * s, (uz * c - rz * sn) * s
                end
                local cr, cg, cb, ca = p.r * 255, p.g * 255, p.b * 255, a * 255
                local u0, v0, u1, v1 = 0, 0, 1, 1
                if atlas then
                    local cols, rows = additive and FIRE_COLS or SMOKE_COLS, additive and FIRE_ROWS or SMOKE_ROWS
                    local cell = p.cell
                    u0, v0 = (cell % cols) / cols, math.floor(cell / cols) / rows
                    u1, v1 = u0 + 1 / cols, v0 + 1 / rows
                end
                local corners = {
                    { p.x - ax - bx, p.y - ay - by, p.z - az - bz, u0, v1 },
                    { p.x + ax - bx, p.y + ay - by, p.z + az - bz, u1, v1 },
                    { p.x + ax + bx, p.y + ay + by, p.z + az + bz, u1, v0 },
                    { p.x - ax + bx, p.y - ay + by, p.z - az + bz, u0, v0 },
                }
                local order = { 1, 2, 3, 1, 3, 4 }
                for oi = 1, 6 do
                    local c = corners[order[oi]]
                    local v = ptr[count]
                    v.x, v.y, v.z, v.u, v.v = c[1], c[2], c[3], c[4], c[5]
                    v.r, v.g, v.b, v.a = cr, cg, cb, ca
                    count = count + 1
                end
                if count >= MAXP * 6 then break end
            end
        end
    end
    return count
end

function E.drawDecals()
    if E.decalCount == 0 then return end
    if E.decalDirty then
        E.decalMesh:setVertices(E.decalData)
        E.decalDirty = false
    end
    E.decalMesh:setDrawRange(1, E.decalCount * 6)
    lg.setDepthMode("lequal", false)
    E.decalModel.tris = E.decalCount * 2
    R.drawModel(E.decalModel, nil, { fog = { R.env.fogStart, R.env.fogEnd, 1 }, flat = true })
    lg.setDepthMode("lequal", true)
end

-- soft-edged dark blobs under vehicles and creatures (classic PSX grounding trick)
function E.drawShadows(list)
    local n = 0
    local W = G.world
    local ptr = E.shadowPtr
    local order = { 1, 3, 2, 1, 4, 3 }
    local uv = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }
    for _, s in ipairs(list) do
        if n >= E.MAXSHADOW then break end
        local c, sn = math.cos(s.yaw), math.sin(s.yaw)
        local pts = {}
        for k, o in ipairs({ { -s.l, -s.w }, { s.l, -s.w }, { s.l, s.w }, { -s.l, s.w } }) do
            local px, pz = s.x + c * o[1] - sn * o[2], s.z + sn * o[1] + c * o[2]
            local py = s.y or W.groundHeight(px, pz)
            pts[k] = { px, py + 0.07, pz }
        end
        for i = 1, 6 do
            local p = pts[order[i]]
            local v = ptr[n * 6 + i - 1]
            v.x, v.y, v.z = p[1], p[2], p[3]
            v.u, v.v = uv[order[i]][1], uv[order[i]][2]
            v.nx, v.ny, v.nz = 0, 1, 0
            v.r, v.g, v.b, v.a = 0, 0, 0, (s.a or 0.5) * 255
        end
        n = n + 1
    end
    if n == 0 then return end
    E.shadowMesh:setVertices(E.shadowData)
    E.shadowMesh:setDrawRange(1, n * 6)
    E.shadowModel.tris = n * 2
    lg.setDepthMode("lequal", false)
    R.drawModel(E.shadowModel, nil, { emissive = 1, alphaCut = 0.02 })
    lg.setDepthMode("lequal", true)
end

function E.drawCasings()
    local T = G.tank
    for i, c in ipairs(E.casings) do
        local f = M3.frame()
        f:setYawPitchRoll(c.rot, c.rot * 0.3, 0)
        f.px, f.py, f.pz = c.x, c.y, c.z
        if c.frame == "tank" then f = T.frame:compose(f) end
        E.casingMat[i] = E.casingMat[i] or {}
        R.drawModel(c.big and E.bigCasing or E.smallCasing, f:matrix(E.casingMat[i]), { interior = c.frame == "tank" and 1 or 0 })
    end
end

function E.drawParticles()
    local sh = R.billboard
    lg.setShader(sh)
    R.send(sh, "viewProj", "row", R.viewProj)
    R.send(sh, "camPos", { R.cam.x, R.cam.y, R.cam.z })
    R.send(sh, "fogRange", { R.env.fogStart, R.env.fogEnd })
    R.send(sh, "fogColor", R.env.fogColor)
    R.send(sh, "flipY", -1)
    lg.setDepthMode("lequal", false)
    local n = buildBillboards(false)
    if n > 0 then
        E.meshAlpha:setVertices(E.bbData, 1, n)
        E.meshAlpha:setDrawRange(1, n)
        R.send(sh, "additive", 0)
        lg.setBlendMode("alpha")
        lg.draw(E.meshAlpha)
    end
    n = buildBillboards(true)
    if n > 0 then
        E.meshAdd:setVertices(E.bbData, 1, n)
        E.meshAdd:setDrawRange(1, n)
        R.send(sh, "additive", 1)
        lg.setBlendMode("add")
        lg.draw(E.meshAdd)
    end
    lg.setBlendMode("alpha")
    lg.setDepthMode("lequal", true)
    lg.setShader(R.world)
end

return E
