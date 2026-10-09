-- Mutated wildlife: Frost Hound, Crawler, Burrower and the rare Large Mutant.
-- AI states: idle, patrol, investigate, chase, attack, retreat, search, buried, dead.
local U = require("src.utils")
local P = require("src.physics")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")
local Gltf = require("src.engine.gltf")
local PA = require("src.psx_assets")

local C = {}
local G

C.KINDS = {
    hound = { name = "FROST HOUND", hp = 90, walk = 2.2, run = 7.6, dmg = 13, range = 1.9, sight = 48, hear = 1.0, radius = 0.55,
              cool = 1.1, height = 0.9, retreatAt = 0.25, tankDmg = 1.5 },
    crawler = { name = "CRAWLER", hp = 55, walk = 2.5, run = 8.8, dmg = 9, range = 1.5, sight = 26, hear = 1.4, radius = 0.5,
                cool = 0.8, height = 0.45, retreatAt = 0.2, tankDmg = 1.0 },
    burrower = { name = "BURROWER", hp = 130, walk = 1.5, run = 6.0, dmg = 22, range = 2.4, sight = 20, hear = 1.6, radius = 0.6,
                 cool = 1.6, height = 1.6, retreatAt = 0, tankDmg = 3 },
    mutant = { name = "LARGE MUTANT", hp = 750, walk = 1.8, run = 5.2, dmg = 42, range = 3.0, sight = 55, hear = 0.9, radius = 1.1,
               cool = 2.0, height = 3.0, retreatAt = 0, tankDmg = 9 },
    -- imported PSX models with their own animations (see C.draw)
    zombie = { name = "WALKER", hp = 80, walk = 0.9, run = 3.3, dmg = 15, range = 1.5, sight = 36, hear = 1.2, radius = 0.4,
               cool = 1.1, height = 1.8, retreatAt = 0, tankDmg = 0.5 },
    spider = { name = "GIANT SPIDER", hp = 65, walk = 1.8, run = 7.0, dmg = 11, range = 1.8, sight = 30, hear = 1.5, radius = 0.75,
               cool = 0.9, height = 1.0, retreatAt = 0.15, tankDmg = 0.8 },
}

---------------------------------------------------------------------------
-- models
---------------------------------------------------------------------------
local function legModel(len, thick, mat)
    local mb = MB.new(301)
    mb:material(mat or "fur"):color(0.7, 0.7, 0.72)
    -- hangs down from the hip (origin), knee bent forward
    mb:hexa({ { -thick, -len * 0.55, -thick }, { thick, -len * 0.55, -thick }, { thick, -len * 0.55, thick }, { -thick, -len * 0.55, thick },
              { -thick * 1.4, 0, -thick * 1.3 }, { thick * 1.4, 0, -thick * 1.3 }, { thick * 1.4, 0, thick * 1.3 }, { -thick * 1.4, 0, thick * 1.3 } })
    mb:material("flesh"):color(0.6, 0.55, 0.55)
    mb:hexa({ { -thick * 0.6 - len * 0.12, -len, -thick * 0.6 }, { thick * 0.6 - len * 0.12, -len, -thick * 0.6 }, { thick * 0.6 - len * 0.12, -len, thick * 0.6 }, { -thick * 0.6 - len * 0.12, -len, thick * 0.6 },
              { -thick, -len * 0.55, -thick }, { thick, -len * 0.55, -thick }, { thick, -len * 0.55, thick }, { -thick, -len * 0.55, thick } })
    -- claw
    mb:material("metal"):color(0.3, 0.28, 0.25)
    mb:box(-len * 0.12, -len - 0.04, -thick * 0.7, -len * 0.12 + thick * 2.5, -len + 0.02, thick * 0.7)
    return mb:build()
end

local function eyesModel(x, y, z, sep, s)
    local mb = MB.new(302)
    mb:material("white"):color(1.0, 0.35, 0.15)
    mb:boxC(x, y, -sep, s, s, s)
    mb:boxC(x, y, sep, s, s, s)
    return mb:build()
end

local function buildHound()
    local m = {}
    local mb = MB.new(311)
    mb.texScale = 1.5
    mb:material("fur"):color(0.62, 0.64, 0.7)
    mb:hexa({ { -0.75, 0.55, -0.22 }, { 0.55, 0.5, -0.25 }, { 0.55, 0.5, 0.25 }, { -0.75, 0.55, 0.22 },
              { -0.7, 0.95, -0.2 }, { 0.5, 1.08, -0.28 }, { 0.5, 1.08, 0.28 }, { -0.7, 0.95, 0.2 } })
    -- exposed ribs / flesh on the flank
    mb:material("flesh"):color(0.8, 0.6, 0.6)
    mb:quad(-0.3, 0.6, 0.235, 0.3, 0.58, 0.255, 0.3, 0.88, 0.27, -0.3, 0.86, 0.225)
    mb:quad(0.3, 0.58, -0.255, -0.3, 0.6, -0.235, -0.3, 0.86, -0.225, 0.3, 0.88, -0.27)
    -- ice crystal spines along the back
    mb:material("ice"):color(0.85, 0.95, 1.1)
    for i = 0, 5 do
        local x = -0.6 + i * 0.22
        mb:push() mb:translate(x, 0.98 + i * 0.015, 0) mb:rotateZ(0.5)
        mb:cylinder(0, 0, 0, 0.06, 0.25 + (i % 2) * 0.12, 0, 4)
        mb:pop()
    end
    -- tail
    mb:material("fur"):color(0.5, 0.5, 0.55)
    mb:hexa({ { -1.2, 0.7, -0.04 }, { -0.72, 0.8, -0.08 }, { -0.72, 0.8, 0.08 }, { -1.2, 0.7, 0.04 },
              { -1.2, 0.76, -0.04 }, { -0.72, 0.92, -0.08 }, { -0.72, 0.92, 0.08 }, { -1.2, 0.76, 0.04 } })
    m.body = mb:build()
    mb = MB.new(312)
    mb:material("fur"):color(0.6, 0.62, 0.68)
    -- head relative to neck pivot
    mb:hexa({ { 0.0, -0.18, -0.18 }, { 0.3, -0.15, -0.15 }, { 0.3, -0.15, 0.15 }, { 0.0, -0.18, 0.18 },
              { 0.0, 0.16, -0.17 }, { 0.3, 0.13, -0.14 }, { 0.3, 0.13, 0.14 }, { 0.0, 0.16, 0.17 } })
    mb:material("flesh"):color(0.7, 0.5, 0.5)
    mb:hexa({ { 0.3, -0.06, -0.1 }, { 0.62, -0.03, -0.06 }, { 0.62, -0.03, 0.06 }, { 0.3, -0.06, 0.1 },
              { 0.3, 0.1, -0.1 }, { 0.6, 0.04, -0.06 }, { 0.6, 0.04, 0.06 }, { 0.3, 0.1, 0.1 } })
    mb:material("plaster"):color(1, 1, 0.9)
    for i = 0, 3 do mb:box(0.35 + i * 0.07, -0.09, -0.07, 0.38 + i * 0.07, -0.03, 0.07) end
    mb:material("fur"):color(0.5, 0.5, 0.55)
    mb:box(-0.02, 0.12, -0.15, 0.08, 0.3, -0.08)
    mb:box(-0.02, 0.12, 0.08, 0.08, 0.3, 0.15)
    m.head = mb:build()
    mb = MB.new(313)
    mb:material("flesh"):color(0.55, 0.3, 0.3)
    mb:hexa({ { 0.0, -0.1, -0.09 }, { 0.32, -0.08, -0.05 }, { 0.32, -0.08, 0.05 }, { 0.0, -0.1, 0.09 },
              { 0.0, 0.0, -0.09 }, { 0.32, -0.02, -0.05 }, { 0.32, -0.02, 0.05 }, { 0.0, 0.0, 0.09 } })
    m.jaw = mb:build()
    m.leg = legModel(0.62, 0.07)
    m.eyes = eyesModel(0.28, 0.06, 0, 0.1, 0.035)
    m.legs = { { 0.38, 0.62, -0.18, 0 }, { 0.38, 0.62, 0.18, math.pi }, { -0.55, 0.62, -0.18, math.pi }, { -0.55, 0.62, 0.18, 0 } }
    m.neck = { 0.52, 0.9, 0 }
    return m
end

local function buildCrawler()
    local m = {}
    local mb = MB.new(321)
    mb:material("flesh"):color(0.65, 0.6, 0.62)
    mb:hexa({ { -0.7, 0.18, -0.3 }, { 0.5, 0.2, -0.32 }, { 0.5, 0.2, 0.32 }, { -0.7, 0.18, 0.3 },
              { -0.6, 0.48, -0.2 }, { 0.45, 0.45, -0.25 }, { 0.45, 0.45, 0.25 }, { -0.6, 0.48, 0.2 } })
    mb:material("ice"):color(0.7, 0.75, 0.8)
    mb:sphere(-0.15, 0.48, 0, 0.3, 0.12, 0.22, 6, 3)
    mb:material("metal"):color(0.25, 0.22, 0.22)
    for i = 0, 4 do mb:box(-0.55 + i * 0.22, 0.46, -0.03, -0.45 + i * 0.22, 0.58, 0.03) end
    m.body = mb:build()
    mb = MB.new(322)
    mb:material("flesh"):color(0.55, 0.45, 0.45)
    mb:hexa({ { 0.0, -0.12, -0.16 }, { 0.28, -0.1, -0.12 }, { 0.28, -0.1, 0.12 }, { 0.0, -0.12, 0.16 },
              { 0.0, 0.1, -0.14 }, { 0.25, 0.06, -0.1 }, { 0.25, 0.06, 0.1 }, { 0.0, 0.1, 0.14 } })
    mb:material("metal"):color(0.3, 0.25, 0.22)
    mb:push() mb:translate(0.25, -0.05, -0.08) mb:rotateY(0.4) mb:box(0, -0.02, -0.02, 0.22, 0.02, 0.02) mb:pop()
    mb:push() mb:translate(0.25, -0.05, 0.08) mb:rotateY(-0.4) mb:box(0, -0.02, -0.02, 0.22, 0.02, 0.02) mb:pop()
    m.head = mb:build()
    m.leg = legModel(0.42, 0.04, "flesh")
    m.eyes = eyesModel(0.22, 0.04, 0, 0.07, 0.03)
    m.legs = {}
    for i = 0, 2 do
        local x = 0.3 - i * 0.4
        m.legs[#m.legs + 1] = { x, 0.32, -0.35, i * 2.1, splay = -0.9 }
        m.legs[#m.legs + 1] = { x, 0.32, 0.35, i * 2.1 + math.pi, splay = 0.9 }
    end
    m.neck = { 0.48, 0.32, 0 }
    return m
end

local function buildBurrower()
    local m = {}
    local mb = MB.new(331)
    mb.texScale = 1
    -- segmented body rearing out of the snow, curving forward like a striking worm
    local segs = 6
    for i = 0, segs - 1 do
        local t = i / (segs - 1)
        local r = 0.58 - t * 0.2
        local x = t * t * 0.9
        local y = t * 1.9
        mb:material(i % 2 == 0 and "flesh" or "fur"):color(0.72, 0.62, 0.62)
        mb:sphere(x, y, 0, r, 0.34, r * 0.92, 7, 4)
        -- chitin ridge plates
        mb:material("ice"):color(0.75, 0.82, 0.9)
        mb:push() mb:translate(x - r * 0.7, y + 0.1, 0) mb:rotateZ(0.9)
        mb:cylinder(0, 0, 0, 0.08, 0.3, 0, 4)
        mb:pop()
    end
    -- forward facing maw ringed with teeth
    mb:push()
    mb:translate(0.95, 1.95, 0)
    mb:rotateZ(-1.1)
    mb:material("flesh"):color(0.45, 0.12, 0.12)
    mb:cylinder(0, 0, 0, 0.38, 0.32, 0.22, 8, false)
    mb:material("plaster"):color(1, 1, 0.9)
    for i = 0, 7 do
        local a = i / 8 * 6.28
        mb:push() mb:translate(math.cos(a) * 0.3, 0.28, math.sin(a) * 0.3)
        mb:rotateX(math.sin(a) * 0.5) mb:rotateZ(-math.cos(a) * 0.5)
        mb:cylinder(0, 0, 0, 0.05, 0.24, 0, 4)
        mb:pop()
    end
    mb:pop()
    m.body = mb:build()
    mb = MB.new(332)
    mb:material("snow"):color(0.95, 0.97, 1)
    mb:sphere(0, 0, 0, 1.1, 0.35, 0.9, 7, 3)
    m.mound = mb:build()
    m.eyes = eyesModel(0.9, 1.75, 0, 0.22, 0.06)
    m.legs = {}
    return m
end

local function buildMutant()
    local m = {}
    local mb = MB.new(341)
    mb.texScale = 0.8
    mb:material("flesh"):color(0.7, 0.62, 0.62)
    mb:hexa({ { -0.5, 1.5, -0.55 }, { 0.4, 1.5, -0.5 }, { 0.4, 1.5, 0.5 }, { -0.5, 1.5, 0.55 },
              { -0.55, 2.7, -0.85 }, { 0.6, 2.8, -0.8 }, { 0.6, 2.8, 0.8 }, { -0.55, 2.7, 0.85 } })
    mb:material("fur"):color(0.55, 0.55, 0.6)
    mb:sphere(-0.1, 2.7, 0, 0.7, 0.4, 0.95, 7, 4)
    mb:material("ice"):color(0.85, 0.95, 1.1)
    for i = 0, 4 do
        mb:push() mb:translate(-0.2 + i * 0.12, 2.95, -0.5 + i * 0.25) mb:rotateZ(0.4)
        mb:cylinder(0, 0, 0, 0.12, 0.6, 0, 4)
        mb:pop()
    end
    mb:material("cloth"):color(0.3, 0.3, 0.25)
    mb:box(-0.45, 1.4, -0.5, 0.35, 1.7, 0.5)
    m.body = mb:build()
    mb = MB.new(342)
    mb:material("flesh"):color(0.6, 0.5, 0.5)
    mb:hexa({ { 0.0, -0.2, -0.2 }, { 0.35, -0.2, -0.17 }, { 0.35, -0.2, 0.17 }, { 0.0, -0.2, 0.2 },
              { 0.0, 0.2, -0.18 }, { 0.3, 0.16, -0.15 }, { 0.3, 0.16, 0.15 }, { 0.0, 0.2, 0.18 } })
    mb:material("plaster"):color(1, 1, 0.9)
    mb:box(0.3, -0.18, -0.12, 0.38, -0.08, 0.12)
    m.head = mb:build()
    m.leg = legModel(1.5, 0.2, "flesh")
    m.arm = legModel(1.9, 0.16, "fur")
    m.eyes = eyesModel(0.33, 0.05, 0, 0.08, 0.05)
    m.legs = { { -0.05, 1.5, -0.35, 0 }, { -0.05, 1.5, 0.35, math.pi } }
    m.arms = { { 0.2, 2.6, -0.95, math.pi }, { 0.2, 2.6, 0.95, 0 } }
    m.neck = { 0.55, 2.65, 0 }
    return m
end

function C.init(game)
    G = game
    C.models = { hound = buildHound(), crawler = buildCrawler(), burrower = buildBurrower(), mutant = buildMutant(),
                 -- stride: ground speed at which the walk cycle plays at its authored rate
                 zombie = { gltf = PA.model("creatures", "zombie"), scale = 1.0, stride = 0.8, neck = { -0.15, 1.62, 0 } },
                 spider = { gltf = PA.model("creatures", "giant_spider"), scale = 1.35, stride = 2.4 } }
    C.list = {}
    C.noises = {}
    C.groups = {}
    C.mats = {}
    C.killed = {}
    C.tmp = M3.frame()
    for i, s in ipairs(G.world.spawns) do
        C.groups[i] = { spawn = s, alive = {}, killed = 0, active = false, id = i }
    end
    C.time = 0
end

function C.serialize()
    local k = {}
    for i, g in ipairs(C.groups) do k[i] = g.killed end
    return k
end

function C.load(k)
    for i, g in ipairs(C.groups) do
        g.killed = (k and k[i]) or 0
        g.alive = {}
        g.active = false
    end
    C.list = {}
end

---------------------------------------------------------------------------
-- spawning
---------------------------------------------------------------------------
local function groundAt(c, x, y, z)
    if c.underground then
        local h = P.groundHeight({ G.world.staticSet }, x, y + 0.6, z, 0.3, 1.0)
        if h > -math.huge then return h end
        return y
    end
    return G.world.height(x, z)
end

local function newCreature(kind, x, z, group)
    local def = C.KINDS[kind]
    local s = group.spawn
    local c = { kind = kind, def = def, x = x, y = 0, z = z, yaw = math.random() * 6.28, hp = def.hp, state = "idle", timer = math.random() * 3,
                homeX = s.x, homeZ = s.z, homeR = s.radius or 25, group = group, phase = math.random() * 6, speed = 0, attackT = 0,
                underground = s.underground, jaw = 0, hurtT = 0, alertT = 0, deathT = 0, lastSeenT = 99, pain = 0 }
    c.y = s.y or G.world.height(x, z)
    c.y = groundAt(c, x, c.y, z)
    if kind == "burrower" then c.state = "buried" c.emerge = 0 end
    return c
end

local function updateSpawns()
    local pl = G.player
    local px, py, pz = pl.feetWorld()
    for _, g in ipairs(C.groups) do
        local s = g.spawn
        local d = U.dist2(px, pz, s.x, s.z)
        local want = s.count - g.killed
        if not g.active and d < 190 and want > 0 then
            g.active = true
            for i = 1, want do
                local a = math.random() * 6.28
                local r = math.random() * (s.underground and s.radius or 12)
                local c = newCreature(s.kind, s.x + math.cos(a) * r, s.z + math.sin(a) * r, g)
                g.alive[#g.alive + 1] = c
                C.list[#C.list + 1] = c
            end
        elseif g.active and d > 290 then
            -- despawn living members that are not engaged
            local engaged = false
            for _, c in ipairs(g.alive) do if c.state == "chase" or c.state == "attack" then engaged = true end end
            if not engaged then
                for _, c in ipairs(g.alive) do c.remove = true end
                g.alive = {}
                g.active = false
            end
        end
    end
end

---------------------------------------------------------------------------
-- perception
---------------------------------------------------------------------------
function C.noise(x, y, z, radius, kind)
    C.noises[#C.noises + 1] = { x = x, y = y, z = z, r = radius, kind = kind }
end

-- what the creature is hunting: the player on foot, or the tank the player sits in
local function targetPos()
    local pl = G.player
    if pl.mode == "dead" then return nil end
    if pl.frameName == "tank" then
        local T = G.tank
        return T.x, T.y + 1, T.z, "tank"
    end
    return pl.x, pl.y, pl.z, "player"
end

local function lineOfSight(ax, ay, az, bx, by, bz)
    local dx, dy, dz, l = U.norm3(bx - ax, by - ay, bz - az)
    if l < 0.5 then return true end
    local t = P.raycast({ G.world.staticSet }, ax, ay, az, dx, dy, dz, l - 0.4, function(b) return not b.tree end)
    return t == nil
end

local function perceive(c, dt)
    local tx, ty, tz, tkind = targetPos()
    if not tx then return false end
    local def = c.def
    local d = U.dist3(c.x, c.y, c.z, tx, ty, tz)
    local env = G.environment
    local vis = 1
    if env then vis = vis * (0.45 + 0.55 * env.daylight) end
    if G.weather then vis = vis * (1 - 0.45 * G.weather.intensity) end
    if G.player.flashlight and tkind == "player" then vis = math.max(vis, 0.95) end
    if G.player.crouch and tkind == "player" then vis = vis * 0.6 end
    if tkind == "tank" then vis = vis * 1.4 end
    local sight = def.sight * vis
    if (c.underground and true or false) ~= (G.world.isUnderground(tx, ty + 1, tz) ~= nil) then return false end
    if d < sight then
        local fx, fz = math.cos(c.yaw), math.sin(c.yaw)
        local dx, dz = (tx - c.x) / math.max(d, 0.01), (tz - c.z) / math.max(d, 0.01)
        local facing = fx * dx + fz * dz
        if (facing > -0.2 or d < 7) and lineOfSight(c.x, c.y + def.height, c.z, tx, ty + 1.2, tz) then
            c.lastX, c.lastY, c.lastZ = tx, ty, tz
            c.lastSeenT = 0
            return true
        end
    end
    return false
end

local function hearNoises(c)
    local best
    for _, n in ipairs(C.noises) do
        local d = U.dist3(c.x, c.y, c.z, n.x, n.y, n.z)
        if d < n.r * c.def.hear then
            if not best or n.r - d > best.r - best.d then best = { x = n.x, y = n.y, z = n.z, r = n.r, d = d, kind = n.kind } end
        end
    end
    return best
end

---------------------------------------------------------------------------
-- movement
---------------------------------------------------------------------------
local tmpSets = {}
local function moveTowards(c, x, z, speed, dt)
    local dx, dz = x - c.x, z - c.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 0.2 then c.speed = U.damp(c.speed, 0, 8, dt) return true end
    local want = math.atan2(dz, dx)
    -- simple obstacle avoidance probe
    local probe = 1.6 + c.def.radius
    for _, off in ipairs({ 0, 0.7, -0.7, 1.4, -1.4 }) do
        local a = want + off + (c.avoidBias or 0)
        local tx, tz = c.x + math.cos(a) * probe, c.z + math.sin(a) * probe
        local _, _, hit = P.circlePush({ G.world.staticSet }, tx, c.y, tz, c.def.radius, 0.3, 1.5)
        if not hit then want = a break end
    end
    c.yaw = U.dampAngle(c.yaw, want, 7, dt)
    c.speed = U.damp(c.speed, speed, 4, dt)
    local nx, nz = c.x + math.cos(c.yaw) * c.speed * dt, c.z + math.sin(c.yaw) * c.speed * dt
    local sets = tmpSets
    sets[1] = G.world.staticSet
    sets[2] = G.tank.extSet
    sets[3] = nil
    nx, nz = P.pushOut(sets, nx, c.y, nz, c.def.radius, c.def.height, 0.5)
    local moved = U.dist2(c.x, c.z, nx, nz)
    if moved < c.speed * dt * 0.25 and c.speed > 1 then
        c.stuck = (c.stuck or 0) + dt
        if c.stuck > 0.6 then c.avoidBias = (math.random() - 0.5) * 3 c.stuck = 0 end
    else
        c.stuck = 0
    end
    local L = G.world.LIMIT
    c.x, c.z = U.clamp(nx, -L, L), U.clamp(nz, -L, L)
    local gy = groundAt(c, c.x, c.y, c.z)
    c.y = U.damp(c.y, gy, 15, dt)
    c.phase = c.phase + dt * c.speed * (c.kind == "crawler" and 4 or (c.kind == "mutant" and 1.6 or 2.6))
    return d < 1.0
end

local function setState(c, s, t)
    c.state = s
    c.timer = t or 0
end

---------------------------------------------------------------------------
-- attacks
---------------------------------------------------------------------------
local function doAttack(c)
    local tx, ty, tz, tkind = targetPos()
    if not tx then return end
    local def = c.def
    if tkind == "tank" then
        G.tank.damage(def.tankDmg, "melee")
        if G.audio then G.audio.play("claw_metal", { x = c.x, y = c.y + 1, z = c.z }) end
        if G.player.frameName == "tank" and G.camera then G.camera.shake(c.kind == "mutant" and 0.8 or 0.25) end
    else
        local d = U.dist3(c.x, c.y + def.height * 0.5, c.z, tx, ty + 0.9, tz)
        if d < def.range + 0.9 then
            G.player.hurt(def.dmg * (0.8 + math.random() * 0.4), c.kind)
            if G.audio then G.audio.play("bite", { x = c.x, y = c.y + 1, z = c.z }) end
        end
    end
end

local function distToTarget(c, tx, ty, tz, tkind)
    if tkind == "tank" then
        -- distance to the hull surface rather than centre
        local lx, ly, lz = G.tank.frame:toLocal(c.x, c.y, c.z)
        local cx = U.clamp(lx, -4, 3.8)
        local cz = U.clamp(lz, -2, 2)
        return U.dist2(lx, lz, cx, cz)
    end
    return U.dist3(c.x, c.y, c.z, tx, ty, tz)
end

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------
local function updateCreature(c, dt)
    local def = c.def
    c.hurtT = math.max(0, c.hurtT - dt)
    c.timer = c.timer - dt
    c.lastSeenT = c.lastSeenT + dt
    c.jaw = U.damp(c.jaw, (c.state == "chase" or c.state == "attack") and 1 or 0.1, 6, dt)
    if c.state == "dead" then
        c.deathT = c.deathT + dt
        if c.deathT > 90 then c.remove = true end
        return
    end
    c.perceiveT = (c.perceiveT or math.random() * 0.2) - dt
    local sees = c.sees
    if c.perceiveT <= 0 then
        c.perceiveT = 0.2
        sees = perceive(c, dt)
        c.sees = sees
        if not sees and c.state ~= "chase" and c.state ~= "attack" then
            local n = hearNoises(c)
            if n and c.state ~= "retreat" then
                if c.state == "buried" then
                    if n.d < 25 then c.emerge = 0.01 end
                else
                    c.lastX, c.lastY, c.lastZ = n.x, n.y, n.z
                    setState(c, "investigate", 12)
                    if n.kind == "cannon" or n.kind == "explosion" then c.alertT = 1 end
                end
            end
        end
    end
    local tx, ty, tz, tkind = targetPos()
    local s = c.state

    if s == "buried" then
        -- waits beneath the snow; erupts when prey comes close
        if tx and tkind == "player" and U.dist2(c.x, c.z, tx, tz) < 9 and not c.underground then c.emerge = c.emerge > 0 and c.emerge or 0.01 end
        if sees and U.dist2(c.x, c.z, tx, tz) < 14 then c.emerge = c.emerge > 0 and c.emerge or 0.01 end
        if c.emerge > 0 then
            c.emerge = c.emerge + dt * 1.8
            if c.emerge < 0.1 + dt * 2 then
                for i = 1, 6 do G.effects.snowPuff(c.x, c.y, c.z, 2) end
                if G.audio then G.audio.play("burrow", { x = c.x, y = c.y, z = c.z }) end
            end
            if c.emerge >= 1 then c.emerge = 1 setState(c, "chase", 0) end
        end
        if tx then c.yaw = U.dampAngle(c.yaw, math.atan2(tz - c.z, tx - c.x), 3, dt) end
        return
    end

    if sees and s ~= "retreat" and s ~= "attack" then
        if s ~= "chase" and G.audio then G.audio.play(c.kind == "mutant" and "roar" or "growl", { x = c.x, y = c.y + 1, z = c.z }) end
        setState(c, "chase", 0)
        s = "chase"
    end

    if s == "idle" then
        c.speed = U.damp(c.speed, 0, 5, dt)
        if c.timer <= 0 then
            local a = math.random() * 6.28
            local r = math.random() * c.homeR
            c.px, c.pz = c.homeX + math.cos(a) * r, c.homeZ + math.sin(a) * r
            setState(c, "patrol", 15)
        end
        if math.random() < dt * 0.05 and G.audio then G.audio.play(c.kind == "hound" and "howl" or "growl", { x = c.x, y = c.y + 1, z = c.z, volume = 0.6 }) end
    elseif s == "patrol" then
        if c.underground then c.px, c.pz = c.homeX + (math.random() - 0.5) * 6, c.homeZ + (math.random() - 0.5) * 6 end
        if moveTowards(c, c.px, c.pz, def.walk, dt) or c.timer <= 0 then setState(c, "idle", 2 + math.random() * 4) end
    elseif s == "investigate" then
        local arrived = moveTowards(c, c.lastX, c.lastZ, (c.alertT > 0) and def.run * 0.8 or def.walk * 1.6, dt)
        if arrived or c.timer <= 0 then setState(c, "search", 8) end
    elseif s == "chase" then
        if not tx then setState(c, "search", 6)
        else
            if sees then c.lastX, c.lastZ = tx, tz end
            local d = distToTarget(c, tx, ty, tz, tkind)
            local vertical = math.abs((ty or c.y) - c.y)
            if d < def.range and vertical < (tkind == "tank" and 4 or 2.8) then
                setState(c, "attack", 0.45)
                c.attackT = 0
                c.yaw = math.atan2(tz - c.z, tx - c.x)
            else
                -- run toward the target; against the tank, aim for the nearest hull point
                local gx, gz = c.lastX or tx, c.lastZ or tz
                if tkind == "tank" then
                    local lx, ly, lz = G.tank.frame:toLocal(c.x, c.y, c.z)
                    local cx, cz = U.clamp(lx, -4.2, 4.0), U.clamp(lz, -2.3, 2.3)
                    local gy
                    gx, gy, gz = G.tank.frame:toWorld(cx, 0, cz)
                end
                moveTowards(c, gx, gz, def.run, dt)
                if c.lastSeenT > 4 then setState(c, "search", 8) end
            end
        end
    elseif s == "attack" then
        c.speed = U.damp(c.speed, 0, 10, dt)
        if tx then c.yaw = U.dampAngle(c.yaw, math.atan2(tz - c.z, tx - c.x), 10, dt) end
        if c.timer <= 0 and c.attackT == 0 then
            c.attackT = 1
            doAttack(c)
            c.timer = def.cool
        elseif c.timer <= 0 and c.attackT == 1 then
            setState(c, "chase", 0)
        end
    elseif s == "retreat" then
        if tx then
            local ax, az = c.x - tx, c.z - tz
            local l = math.max(0.01, math.sqrt(ax * ax + az * az))
            moveTowards(c, c.x + ax / l * 10, c.z + az / l * 10, def.run, dt)
        end
        if c.timer <= 0 then setState(c, "search", 10) end
    elseif s == "search" then
        if not c.px or c.timer % 3 < dt then
            local a = math.random() * 6.28
            c.px, c.pz = (c.lastX or c.x) + math.cos(a) * 8, (c.lastZ or c.z) + math.sin(a) * 8
        end
        moveTowards(c, c.px, c.pz, def.walk * 1.4, dt)
        if c.timer <= 0 then
            if c.kind == "burrower" then
                setState(c, "buried", 0)
                c.emerge = 0
                G.effects.snowPuff(c.x, c.y, c.z, 2)
            else
                setState(c, "patrol", 20)
                c.px, c.pz = c.homeX, c.homeZ
            end
        end
    end
    c.alertT = math.max(0, c.alertT - dt * 0.1)
end

-- pick the animation clip for an imported model and advance its clock
local function animate(c, m, dt)
    local want, loop, rate = "idle", true, 1
    if c.state == "dead" then want, loop = "death", false
    elseif c.hitT and c.hitT > 0 then want, loop = "hit", false
    elseif c.state == "attack" then
        -- stretch the strike over the wind-up plus the recovery
        want, loop, rate = "attack", false, Gltf.duration(m.gltf, "attack") / (0.45 + c.def.cool)
    elseif c.speed > 0.15 then
        want, rate = "walk", U.clamp(c.speed / m.stride, 0.5, 3.2)
    end
    c.hitT = math.max(0, (c.hitT or 0) - dt)
    if c.anim ~= want then c.anim, c.animT = want, 0 end
    c.animLoop = loop
    c.animT = c.animT + dt * rate
end

function C.update(dt)
    C.time = C.time + dt
    C.spawnT = (C.spawnT or 0) - dt
    if C.spawnT <= 0 then
        C.spawnT = 1
        updateSpawns()
    end
    for _, c in ipairs(C.list) do
        updateCreature(c, dt)
        local m = C.models[c.kind]
        if m.gltf then animate(c, m, dt) end
    end
    for i = #C.list, 1, -1 do
        if C.list[i].remove then table.remove(C.list, i) end
    end
    C.noises = {}
    -- separation between creatures
    for i = 1, #C.list do
        local a = C.list[i]
        if a.state ~= "dead" then
            for j = i + 1, #C.list do
                local b = C.list[j]
                if b.state ~= "dead" then
                    local d = U.dist2(a.x, a.z, b.x, b.z)
                    local minD = a.def.radius + b.def.radius
                    if d < minD and d > 0.001 then
                        local p = (minD - d) * 0.5
                        local nx, nz = (a.x - b.x) / d, (a.z - b.z) / d
                        a.x, a.z = a.x + nx * p, a.z + nz * p
                        b.x, b.z = b.x - nx * p, b.z - nz * p
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- damage
---------------------------------------------------------------------------
function C.damage(c, amount, hx, hy, hz, dx, dz)
    if c.state == "dead" then return end
    if c.state == "buried" then c.emerge = 0.5 end
    c.hp = c.hp - amount
    c.hurtT = 0.15
    if c.state ~= "attack" then c.hitT = 0.5 end
    c.x, c.z = c.x + (dx or 0) * math.min(0.6, amount / 200), c.z + (dz or 0) * math.min(0.6, amount / 200)
    if c.hp <= 0 then
        c.state = "dead"
        c.deathT = 0
        c.group.killed = c.group.killed + 1
        if G.audio then G.audio.play("creature_die", { x = c.x, y = c.y + 1, z = c.z }) end
        G.effects.blood(c.x, c.y + c.def.height * 0.6, c.z, 12)
        if G.missions then G.missions.event("creature_killed", c.kind) end
        return
    end
    if G.audio then G.audio.play("yelp", { x = c.x, y = c.y + 1, z = c.z, volume = 0.7 }) end
    local tx, ty, tz = targetPos()
    if tx then c.lastX, c.lastY, c.lastZ = tx, ty, tz end
    if c.def.retreatAt > 0 and c.hp < c.def.hp * c.def.retreatAt and c.state ~= "retreat" then
        c.state = "retreat"
        c.timer = 5
    elseif c.state ~= "attack" and c.state ~= "retreat" then
        c.state = "chase"
        c.lastSeenT = 0
    end
end

function C.splash(x, y, z, radius, damage)
    for _, c in ipairs(C.list) do
        if c.state ~= "dead" then
            local d = U.dist3(x, y, z, c.x, c.y + c.def.height * 0.5, c.z)
            if d < radius then
                C.damage(c, damage * (1 - d / radius), c.x, c.y, c.z, (c.x - x) / math.max(d, 0.1), (c.z - z) / math.max(d, 0.1))
            end
        end
    end
end

-- ray against creature hit volumes; returns t, creature, part
function C.raycast(ox, oy, oz, dx, dy, dz, maxT)
    local bestT, best, part = maxT, nil, nil
    for _, c in ipairs(C.list) do
        if c.state ~= "dead" and not (c.state == "buried" and c.emerge == 0) then
            local h = c.def.height
            local r = c.def.radius
            if c.kind == "burrower" then
                local e = c.emerge or 1
                local t = P.raySphere(ox, oy, oz, dx, dy, dz, c.x, c.y + 1.0 * e, c.z, 0.7)
                if t and t < bestT then bestT, best, part = t, c, "body" end
            else
                local t = P.raySphere(ox, oy, oz, dx, dy, dz, c.x, c.y + h * 0.6, c.z, r * 1.1)
                if t and t < bestT then bestT, best, part = t, c, "body" end
                local n = C.models[c.kind].neck
                if n then
                    local fx, fz = math.cos(c.yaw), math.sin(c.yaw)
                    local hx, hz = c.x + fx * (n[1] + 0.2), c.z + fz * (n[1] + 0.2)
                    local t2 = P.raySphere(ox, oy, oz, dx, dy, dz, hx, c.y + n[2], hz, r * 0.5)
                    if t2 and t2 < bestT then bestT, best, part = t2, c, "head" end
                end
            end
        end
    end
    if best then return bestT, best, part end
    return nil
end

function C.nearestThreat(x, z, maxD)
    local best, bd = nil, maxD
    for _, c in ipairs(C.list) do
        if c.state ~= "dead" and c.state ~= "buried" then
            local d = U.dist2(x, z, c.x, c.z)
            if d < bd then best, bd = c, d end
        end
    end
    return best, bd
end

---------------------------------------------------------------------------
-- rendering (hierarchical parts)
---------------------------------------------------------------------------
local frameA, frameB = M3.frame(), M3.frame()
local matPool, matIdx = {}, 0
local function mat()
    matIdx = matIdx + 1
    local m = matPool[matIdx]
    if not m then m = {} matPool[matIdx] = m end
    return m
end

function C.draw()
    matIdx = 0
    local cam = R.cam
    for _, c in ipairs(C.list) do
        if R.visible(c.x, c.y + 1, c.z, 4) then
            local m = C.models[c.kind]
            local root = frameA
            local deadRoll = c.state == "dead" and math.min(1.5, c.deathT * 4) or 0
            root:setYawPitchRoll(c.yaw, 0, deadRoll)
            local bob = math.abs(math.sin(c.phase)) * 0.04 * math.min(1, c.speed / 3)
            root.px, root.py, root.pz = c.x, c.y + bob - (c.state == "dead" and 0.15 or 0), c.z
            local params = { tint = c.hurtT > 0 and { 1.4, 0.85, 0.85, 1 } or nil, interior = c.underground and 1 or 0 }
            if m.gltf then
                root:setYawPitchRoll(c.yaw, 0, 0)
                root.px, root.py, root.pz = c.x, c.y, c.z
                Gltf.pose(m.gltf, c.anim or "idle", c.animT or 0, c.animLoop ~= false)
                Gltf.draw(R, m.gltf, root:matrix(mat(), m.scale), params)
            elseif c.kind == "burrower" then
                local e = c.state == "buried" and (c.emerge or 0) or 1
                if c.state == "dead" then e = math.max(0, 1 - c.deathT * 0.5) end
                R.drawModel(m.mound, root:matrix(mat()), params)
                if e > 0.02 then
                    local f = frameB
                    f:setYawPitchRoll(c.yaw, 0, math.sin(C.time * 3 + c.phase) * 0.12 * e)
                    f.px, f.py, f.pz = c.x, c.y - 2.3 * (1 - e), c.z
                    local mm = f:matrix(mat())
                    R.drawModel(m.body, mm, params)
                    R.drawModel(m.eyes, mm, { emissive = 1 })
                end
            else
                local rootM = root:matrix(mat())
                R.drawModel(m.body, rootM, params)
                local moving = math.min(1, c.speed / 2)
                for i, l in ipairs(m.legs) do
                    local swing = math.sin(c.phase + l[4]) * 0.55 * moving
                    if c.state == "dead" then swing = 0.6 end
                    local f = frameB
                    f:setYawPitchRoll(l.splay or 0, swing, (l.splay or 0) * 0.6)
                    f.px, f.py, f.pz = l[1], l[2], l[3]
                    local wf = root:compose(f, M3.frame())
                    R.drawModel(m.leg, wf:matrix(mat()), params)
                end
                if m.arms then
                    for _, a in ipairs(m.arms) do
                        local swing = math.sin(c.phase + a[4]) * 0.5 * moving
                        if c.state == "attack" then swing = -1.2 + (c.timer or 0) * 2 end
                        local f = frameB
                        f:setYawPitchRoll(0, swing, 0)
                        f.px, f.py, f.pz = a[1], a[2], a[3]
                        local wf = root:compose(f, M3.frame())
                        R.drawModel(m.arm, wf:matrix(mat()), params)
                    end
                end
                -- head with jaw
                local n = m.neck
                local f = frameB
                local look = c.state == "attack" and -0.2 or math.sin(C.time * 1.3 + c.phase) * 0.15
                f:setYawPitchRoll(look * 0.5, -0.1 + look * 0.3, 0)
                f.px, f.py, f.pz = n[1], n[2], n[3]
                local hf = root:compose(f, M3.frame())
                local hm = hf:matrix(mat())
                R.drawModel(m.head, hm, params)
                if c.state ~= "dead" then R.drawModel(m.eyes, hm, { emissive = 1 }) end
                if m.jaw then
                    local jf = M3.frame()
                    jf:setYawPitchRoll(0, -0.5 * c.jaw * (0.6 + 0.4 * math.sin(C.time * 9)), 0)
                    jf.px, jf.py, jf.pz = 0.3, -0.05, 0
                    R.drawModel(m.jaw, hf:compose(jf, M3.frame()):matrix(mat()), params)
                end
            end
        end
    end
end

return C
