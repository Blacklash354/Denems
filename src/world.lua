-- Terrain heightfield, chunked static geometry, static colliders and world queries.
local U = require("src.utils")
local MB = require("src.engine.meshbuilder")
local P = require("src.physics")
local R = require("src.engine.renderer")
local M3 = require("src.engine.math3d")

local W = {}
W.HALF = 704
W.CELL = 8
W.N = 176
W.CHUNK = 16       -- cells per chunk
W.LIMIT = 610      -- playable boundary
W.SEED = 1941

local floor, sqrt, max, min, abs = math.floor, math.sqrt, math.max, math.min, math.abs

---------------------------------------------------------------------------
-- layout data
---------------------------------------------------------------------------
W.locations = {
    { id = "camp", name = "LONER CAMP", area = "LONERS' CAMP", x = -120, z = 392, r = 26, icon = "camp" },
    { id = "village", name = "SOVIET TOWN", area = "FROZEN VILLAGE", x = -195, z = 300, r = 95, icon = "town" },
    { id = "industrial", name = "INDUSTRIAL ZONE", area = "ABANDONED INDUSTRIAL AREA", x = -285, z = -15, r = 115, icon = "factory" },
    { id = "forest", name = "FOREST", area = "FROZEN FOREST", x = 320, z = 180, r = 120, icon = "forest", noFlatten = true },
    { id = "checkpoint", name = "CHECKPOINT", area = "MILITARY CHECKPOINT", x = 20, z = 95, r = 45, icon = "checkpoint" },
    { id = "base", name = "MILITARY BASE", area = "SOVIET MILITARY BASE", x = -255, z = -335, r = 105, icon = "base" },
    { id = "tower", name = "RADIO TOWER", area = "RADIO TOWER", x = 305, z = -250, r = 45, icon = "tower", hill = 26 },
    { id = "bunker", name = "BUNKER", area = "UNDERGROUND BUNKER", x = -405, z = -455, r = 30, icon = "bunker" },
    { id = "plant", name = "NUCLEAR PLANT", area = "NUCLEAR FACILITY", x = 130, z = -505, r = 115, icon = "plant" },
    { id = "station", name = "FUEL STATION", area = "ABANDONED FUEL STATION", x = 60, z = 352, r = 24, icon = "station" },
}
-- the microdistrict only exists when the user's building models are in assets/
if love.filesystem.getInfo("assets/lowpoly_panelka_psx.glb") then
    W.locations[#W.locations + 1] = { id = "district", name = "MICRODISTRICT", area = "DEAD MICRODISTRICT", x = -405, z = 300, r = 64, icon = "town" }
end
for _, l in ipairs(W.locations) do W[l.id] = l end

W.roads = {
    { { 60, 640 }, { 42, 430 }, { 30, 250 }, { 20, 95 }, { 0, -80 }, { 55, -245 }, { 115, -400 }, { 130, -450 } },
    { { 31, 300 }, { -80, 312 }, { -200, 300 }, { -300, 285 }, { -352, 296 } },
    { { 0, -80 }, { -140, -45 }, { -285, -15 }, { -380, 0 } },
    { { -140, -45 }, { -205, -200 }, { -255, -335 }, { -330, -405 }, { -395, -445 } },
    { { 55, -245 }, { 180, -262 }, { 290, -250 } },
    { { 20, 95 }, { 150, 105 }, { 265, 150 }, { 390, 205 } },
}
W.START = { x = 44, z = 452, yaw = -math.pi / 2 - 0.05 }

function W.riverX(z) return 180 + 40 * math.sin(z / 130) + 15 * math.sin(z / 41) end
W.bridgeIntact = { x = W.riverX(-258), z = -258 }
W.bridgeBroken = { x = W.riverX(118), z = 118 }

---------------------------------------------------------------------------
-- height function
---------------------------------------------------------------------------
local function baseHeight(x, z)
    local h = U.fbm(x / 240, z / 240, 3, 11) * 22 + U.fbm(x / 70, z / 70, 2, 23) * 4 - 12
    -- mountains towards the border
    local e = max(abs(x), abs(z))
    local m = U.smoothstep(530, 690, e)
    h = h + m * (60 + U.fbm(x / 90, z / 90, 3, 31) * 70)
    for _, l in ipairs(W.locations) do
        if l.hill then
            local d = U.dist2(x, z, l.x, l.z)
            h = h + l.hill * math.exp(-(d / 110) ^ 2)
        end
    end
    return h
end
W.baseHeight = baseHeight

local roadCenterCache = {}
local function locationHeight(l)
    if not l.h then l.h = baseHeight(l.x, l.z) end
    return l.h
end

local function roadInfo(x, z)
    local best, bestH = 1e9, 0
    for ri, road in ipairs(W.roads) do
        for i = 1, #road - 1 do
            local a, b = road[i], road[i + 1]
            -- quick reject
            local minx, maxx = min(a[1], b[1]) - 20, max(a[1], b[1]) + 20
            local minz, maxz = min(a[2], b[2]) - 20, max(a[2], b[2]) + 20
            if x > minx and x < maxx and z > minz and z < maxz then
                local d, t = U.distToSegment(x, z, a[1], a[2], b[1], b[2])
                if d < best then
                    best = d
                    local cx, cz = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
                    bestH = baseHeight(cx, cz)
                end
            end
        end
    end
    return best, bestH
end
W.roadDistance = function(x, z) return (roadInfo(x, z)) end

function W.computeHeight(x, z)
    local h = baseHeight(x, z)
    for _, l in ipairs(W.locations) do
        if not l.noFlatten then
            local d = U.dist2(x, z, l.x, l.z)
            local w = U.smoothstep(l.r * 1.5, l.r * 0.9, d)
            if w > 0 then h = U.lerp(h, locationHeight(l) + (l.hill and 0 or 0), w) end
        end
    end
    -- river valley
    local rd = abs(x - W.riverX(z))
    local nearIntact = U.dist2(x, z, W.bridgeIntact.x, W.bridgeIntact.z) < 22
    local rw = U.smoothstep(34, 11, rd)
    local riverBed = baseHeight(W.riverX(z), z) - 4.5
    if rw > 0 and not nearIntact then
        h = U.lerp(h, min(h, riverBed), rw)
    end
    -- roads
    local d, rh = roadInfo(x, z)
    local nearBroken = U.dist2(x, z, W.bridgeBroken.x, W.bridgeBroken.z) < 30
    if d < 14 and not (nearBroken and rw > 0.2) then
        for _, l in ipairs(W.locations) do
            if not l.noFlatten then
                local dl = U.dist2(x, z, l.x, l.z)
                rh = U.lerp(rh, locationHeight(l), U.smoothstep(l.r * 1.5, l.r * 0.9, dl))
            end
        end
        h = U.lerp(h, rh - 0.15, U.smoothstep(14, 6, d))
    end
    return h
end

---------------------------------------------------------------------------
-- heightfield storage and queries
---------------------------------------------------------------------------
function W.computeHeights()
    local N, C, H = W.N, W.CELL, W.HALF
    W.hgrid = {}
    for i = 0, N do
        local row = {}
        for j = 0, N do
            row[j] = W.computeHeight(-H + i * C, -H + j * C)
        end
        W.hgrid[i] = row
        if i % 16 == 0 and coroutine.isyieldable() then coroutine.yield("terrain", i / N) end
    end
end

function W.height(x, z)
    local N, C, H = W.N, W.CELL, W.HALF
    local gx, gz = (x + H) / C, (z + H) / C
    local i, j = floor(gx), floor(gz)
    if i < 0 then i = 0 elseif i > N - 1 then i = N - 1 end
    if j < 0 then j = 0 elseif j > N - 1 then j = N - 1 end
    local fx, fz = U.clamp(gx - i, 0, 1), U.clamp(gz - j, 0, 1)
    local g = W.hgrid
    local h00, h10, h01, h11 = g[i][j], g[i + 1][j], g[i][j + 1], g[i + 1][j + 1]
    if fx > fz then
        return h00 + (h10 - h00) * fx + (h11 - h10) * fz
    else
        return h00 + (h11 - h01) * fx + (h01 - h00) * fz
    end
end

function W.normal(x, z)
    local e = 1.5
    local hx = W.height(x + e, z) - W.height(x - e, z)
    local hz = W.height(x, z + e) - W.height(x, z - e)
    local nx, ny, nz = U.norm3(-hx, 2 * e, -hz)
    return nx, ny, nz
end

function W.isRiver(x, z) return abs(x - W.riverX(z)) < 12 and W.height(x, z) < baseHeight(W.riverX(z), z) - 3 end

-- surface height including walkable static boxes (for vehicles/creatures)
local gtmp = {}
function W.surfaceHeight(x, z, fromY, radius)
    local h = W.height(x, z)
    radius = radius or 0.3
    local list, n = W.colliders:query(x - radius, z - radius, x + radius, z + radius, gtmp)
    for i = 1, n do
        local b = list[i]
        if b.walk and x > b[1] and x < b[4] and z > b[3] and z < b[6] and b[5] <= (fromY or 1e9) + 1.0 and b[5] > h then
            h = b[5]
        end
    end
    return h
end

-- terrain ray march
function W.rayTerrain(ox, oy, oz, dx, dy, dz, maxT)
    local step = 1.0
    local t = 0
    local prevT = 0
    while t < maxT do
        local x, y, z = ox + dx * t, oy + dy * t, oz + dz * t
        if y < W.height(x, z) then
            -- bisect
            local a, b = prevT, t
            for _ = 1, 8 do
                local m = (a + b) * 0.5
                local mx, my, mz = ox + dx * m, oy + dy * m, oz + dz * m
                if my < W.height(mx, mz) then b = m else a = m end
            end
            return b
        end
        prevT = t
        t = t + step
        if t > 30 then step = 2.0 end
    end
    return nil
end

---------------------------------------------------------------------------
-- chunks & generation context
---------------------------------------------------------------------------
local CHUNK_SIZE = W.CELL * W.CHUNK
W.CHUNK_SIZE = CHUNK_SIZE
local NCH = W.N / W.CHUNK

function W.chunkIndex(x, z)
    local ci = U.clamp(floor((x + W.HALF) / CHUNK_SIZE), 0, NCH - 1)
    local cj = U.clamp(floor((z + W.HALF) / CHUNK_SIZE), 0, NCH - 1)
    return ci, cj
end

function W.initChunks()
    W.chunks = {}
    for ci = 0, NCH - 1 do
        for cj = 0, NCH - 1 do
            local c = { ci = ci, cj = cj, mb = MB.new(ci * 131 + cj * 7 + 1) }
            c.mb.texScale = 0.5
            W.chunks[ci * NCH + cj] = c
        end
    end
    W.colliders = P.newGrid(16)
    W.staticSet = { grid = W.colliders }
    W.landmarkMB = MB.new(77)
    W.landmarkMB.texScale = 0.3
    W.underground = {}   -- regions where terrain is ignored {x0,y0,z0,x1,y1,z1}
    W.interiorMB = MB.new(99)  -- underground interiors (drawn with interior lighting)
    W.interiorMB.maxEdge = 2.0
    W.containers, W.pickups, W.doors, W.emitters, W.staticLights = {}, {}, {}, {}, {}
    W.radZones, W.shelters, W.spawns, W.signals, W.fires = {}, {}, {}, {}, {}
    W.interactables = {}
    W.interiorAreas = {}
    W.npcs, W.guitars, W.anomalies = {}, {}, {}
    W.dobjs = {}
end

-- context for a destructible object: geometry goes into its own builder so it can be removed later
local Ctx = {}
function W.dctx(x, z, rot, kind, hp, opts)
    opts = opts or {}
    local obj = { kind = kind, hp = hp or 100, maxHp = hp or 100, colliders = {}, alive = true, crush = opts.crush,
                  explode = opts.explode, burn = opts.burn, id = #W.dobjs + 1 }
    local mb = MB.new(#W.dobjs * 31 + 7)
    mb.texScale = 0.5
    mb.maxEdge = opts.maxEdge
    local y = opts.y or W.height(x, z)
    obj.baseY = y
    local c = setmetatable({ mb = mb, x = x, y = y, z = z, rot = rot or 0, opts = opts, obj = obj }, Ctx)
    mb:translate(x, y, z)
    mb:rotateY(rot or 0)
    obj.builder = mb
    W.dobjs[#W.dobjs + 1] = obj
    return c, obj
end

function W.addDObj(obj)
    local ch = W.chunkAt(obj.cx, obj.cz)
    ch.dobjs = ch.dobjs or {}
    ch.dobjs[#ch.dobjs + 1] = obj
    obj.chunk = ch
end

function W.finishDObj(obj)
    local raw, b = obj.builder:buildRaw()
    obj.builder = nil
    obj.raw = raw
    if b[1] > b[4] then obj.alive = false obj.empty = true return end
    obj.bounds = { b[1], b[2], b[3], b[4], b[5], b[6] }
    obj.cx, obj.cy, obj.cz = (b[1] + b[4]) / 2, (b[2] + b[5]) / 2, (b[3] + b[6]) / 2
    obj.radius = sqrt((b[4] - b[1]) ^ 2 + (b[5] - b[2]) ^ 2 + (b[6] - b[3]) ^ 2) / 2
    W.addDObj(obj)
end

-- re-batch the destructible objects of one chunk (after something was destroyed)
function W.rebuildChunkD(ch)
    local list = {}
    local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
    for _, o in ipairs(ch.dobjs or {}) do
        if o.alive or o.ruin then
            list[#list + 1] = o.raw
            local b = o.bounds
            x0, y0, z0 = min(x0, b[1]), min(y0, b[2]), min(z0, b[3])
            x1, y1, z1 = max(x1, b[4]), max(y1, b[5]), max(z1, b[6])
        end
    end
    if #list == 0 then ch.dmodel = nil return end
    ch.dmodel = MB.mergeRaw(list)
    ch.dcx, ch.dcy, ch.dcz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    ch.dradius = sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2 + (z1 - z0) ^ 2) / 2
end

function W.chunkAt(x, z)
    local ci, cj = W.chunkIndex(x, z)
    return W.chunks[ci * NCH + cj]
end

-- Context used by generators: transform + target builder (declared above)
Ctx.__index = Ctx
W.Ctx = Ctx

function W.ctx(x, z, rot, opts)
    opts = opts or {}
    local mb
    if opts.landmark then mb = W.landmarkMB
    elseif opts.interior then mb = W.interiorMB
    else mb = W.chunkAt(x, z).mb end
    local y = opts.y or W.height(x, z)
    local c = setmetatable({ mb = mb, x = x, y = y, z = z, rot = rot or 0, opts = opts }, Ctx)
    mb:reset()
    mb:translate(x, y, z)
    mb:rotateY(rot or 0)
    mb.maxEdge = opts.maxEdge
    return c
end

function Ctx:mat(name, r, g, b)
    self.mb:material(name)
    self.mb:color(r or 1, g or 1, b or 1)
    return self
end

-- transform a local point to world
function Ctx:toWorld(x, y, z) return self.mb:xf(x, y, z) end

function Ctx:worldBox(x0, y0, z0, x1, y1, z1)
    local mb = self.mb
    local ax, ay, az = mb:xf(x0, y0, z0)
    local bx, by, bz = mb:xf(x1, y1, z1)
    local cx, cy, cz = mb:xf(x0, y0, z1)
    local dx, dy, dz = mb:xf(x1, y1, z0)
    return min(ax, bx, cx, dx), min(ay, by), min(az, bz, cz, dz), max(ax, bx, cx, dx), max(ay, by), max(az, bz, cz, dz)
end

-- lower the heightfield under a footprint (local rect) so terrain never pokes through floors
function Ctx:flatten(x0, z0, x1, z1, yLocal)
    local a, b, c, d, e, f = self:worldBox(x0, yLocal, z0, x1, yLocal, z1)
    W.flattenRect(a, c, d, f, b)
end

function W.flattenRect(x0, z0, x1, z1, y)
    local N, C, H = W.N, W.CELL, W.HALF
    local i0, i1 = math.floor((x0 + H) / C) - 1, math.ceil((x1 + H) / C) + 1
    local j0, j1 = math.floor((z0 + H) / C) - 1, math.ceil((z1 + H) / C) + 1
    for i = math.max(0, i0), math.min(N, i1) do
        for j = math.max(0, j0), math.min(N, j1) do
            local gx, gz = -H + i * C, -H + j * C
            -- vertices adjacent to the footprint
            if gx >= x0 - C and gx <= x1 + C and gz >= z0 - C and gz <= z1 + C then
                if W.hgrid[i][j] > y - 0.15 then W.hgrid[i][j] = y - 0.15 end
            end
        end
    end
end

function Ctx:collider(x0, y0, z0, x1, y1, z1, props)
    local a, b, c, d, e, f = self:worldBox(x0, y0, z0, x1, y1, z1)
    local box = { a, b, c, d, e, f }
    box.walk = true
    if props then for k, v in pairs(props) do box[k] = v end end
    if self.obj then
        box.obj = self.obj
        self.obj.colliders[#self.obj.colliders + 1] = box
    end
    W.colliders:add(box)
    return box
end

function Ctx:solid(x0, y0, z0, x1, y1, z1, props)
    self.mb:box(x0, y0, z0, x1, y1, z1)
    return self:collider(x0, y0, z0, x1, y1, z1, props)
end

function Ctx:box(x0, y0, z0, x1, y1, z1, faces) self.mb:box(x0, y0, z0, x1, y1, z1, faces) end

-- thin beam between two local points (poles, braces, wires)
function Ctx:beam(ax, ay, az, bx, by, bz, t1, t2)
    t2 = t2 or t1
    local dx, dy, dz = bx - ax, by - ay, bz - az
    local l = sqrt(dx * dx + dy * dy + dz * dz)
    if l < 1e-6 then return end
    dx, dy, dz = dx / l, dy / l, dz / l
    -- perpendicular vectors
    local px, py, pz
    if abs(dy) < 0.9 then px, py, pz = U.norm3(U.cross(dx, dy, dz, 0, 1, 0))
    else px, py, pz = U.norm3(U.cross(dx, dy, dz, 1, 0, 0)) end
    local qx, qy, qz = U.cross(px, py, pz, dx, dy, dz)
    local h1, h2 = t1 / 2, t2 / 2
    local function c(x, y, z, s1, s2)
        return { x + px * s1 + qx * s2, y + py * s1 + qy * s2, z + pz * s1 + qz * s2 }
    end
    self.mb:hexa({
        c(ax, ay, az, -h1, -h2), c(ax, ay, az, h1, -h2), c(ax, ay, az, h1, h2), c(ax, ay, az, -h1, h2),
        c(bx, by, bz, -h1, -h2), c(bx, by, bz, h1, -h2), c(bx, by, bz, h1, h2), c(bx, by, bz, -h1, h2),
    })
end

---------------------------------------------------------------------------
-- terrain meshes
---------------------------------------------------------------------------
function W.buildTerrain()
    local N, C, H = W.N, W.CELL, W.HALF
    local g = W.hgrid
    for ci = 0, NCH - 1 do
        for cj = 0, NCH - 1 do
            local chunk = W.chunks[ci * NCH + cj]
            local mb = chunk.mb
            mb:reset()
            mb.maxEdge = nil
            mb.jitter = 0.03
            for i = ci * W.CHUNK, (ci + 1) * W.CHUNK - 1 do
                for j = cj * W.CHUNK, (cj + 1) * W.CHUNK - 1 do
                    local x0, z0 = -H + i * C, -H + j * C
                    local x1, z1 = x0 + C, z0 + C
                    local h00, h10, h01, h11 = g[i][j], g[i + 1][j], g[i][j + 1], g[i + 1][j + 1]
                    local cx, cz = x0 + C / 2, z0 + C / 2
                    local rd = roadInfo(cx, cz)
                    local slope = max(abs(h10 - h00), abs(h01 - h00), abs(h11 - h00)) / C
                    local mat, r, gg, b = "snow", 0.93, 0.95, 1.0
                    local riverD = abs(cx - W.riverX(cz))
                    if riverD < 12 and h00 < baseHeight(W.riverX(cz), cz) - 3 then
                        mat, r, gg, b = "ice", 0.85, 0.92, 1.0
                    elseif rd < 5.5 then
                        mat, r, gg, b = "snowroad", 0.95, 0.94, 0.94
                    elseif slope > 0.9 then
                        mat, r, gg, b = "rubble", 0.9, 0.9, 0.95
                    else
                        local n = U.fbm(cx / 40, cz / 40, 2, 5)
                        local v = 0.86 + n * 0.14
                        r, gg, b = v * 0.97, v * 0.98, v
                        if U.hash2(i, j, 3) > 0.985 then r, gg, b = r * 0.9, gg * 0.9, b * 0.92 end
                    end
                    mb:material(mat)
                    mb:color(r, gg, b)
                    local s = 0.25
                    mb:tri(x0, h00, z0, x0 * s, z0 * s, x1, h11, z1, x1 * s, z1 * s, x1, h10, z0, x1 * s, z0 * s)
                    mb:tri(x0, h00, z0, x0 * s, z0 * s, x0, h01, z1, x0 * s, z1 * s, x1, h11, z1, x1 * s, z1 * s)
                end
            end
            mb.jitter = 0.06
        end
        if coroutine.isyieldable() then coroutine.yield("meshes", ci / NCH) end
    end
end

function W.finalize()
    for k, c in pairs(W.chunks) do
        c.model = c.mb:build()
        c.mb = nil
        local b = c.model.bounds
        c.cx, c.cy, c.cz = c.model.cx, c.model.cy, c.model.cz
        c.radius = c.model.radius
    end
    W.landmarks = W.landmarkMB:build()
    W.landmarkMB = nil
    W.interiorModel = W.interiorMB:build()
    W.interiorMB = nil
    for _, o in ipairs(W.dobjs) do if o.builder then W.finishDObj(o) end end
    for _, c in pairs(W.chunks) do if c.dobjs then W.rebuildChunkD(c) end end
end

---------------------------------------------------------------------------
-- distant silhouettes (mountains + ruined skyline) to hide the world border
---------------------------------------------------------------------------
function W.buildSilhouettes()
    local mb = MB.new(5)
    mb.jitter = 0.02
    mb.texScale = 0.05
    mb:material("rubble"):color(0.55, 0.57, 0.62)
    local seg = 96
    local R0 = 1000
    local prevTop
    for i = 0, seg do
        local a = i / seg * 2 * math.pi
        local top = 70 + U.fbm(math.cos(a) * 3 + 10, math.sin(a) * 3 + 10, 4, 3) * 150
        if i > 0 then
            local a0 = (i - 1) / seg * 2 * math.pi
            local x0, z0 = math.cos(a0) * R0, math.sin(a0) * R0
            local x1, z1 = math.cos(a) * R0, math.sin(a) * R0
            mb:quad(x0, -30, z0, x1, -30, z1, x1, top, z1, x0, prevTop, z0)
            mb:quad(x0, prevTop, z0, x1, top, z1, x1, -30, z1, x0, -30, z0)
            -- snow caps
        end
        prevTop = top
    end
    -- ruined skyline clusters in a few directions
    mb:material("concrete"):color(0.5, 0.5, 0.55)
    local rng = U.rng(9)
    for _, dirA in ipairs({ 3.4, 3.7, 4.4, 1.2, 5.6 }) do
        for k = 1, 9 do
            local a = dirA + rng:range(-0.12, 0.12)
            local d = rng:range(760, 880)
            local x, z = math.cos(a) * d, math.sin(a) * d
            local w, h = rng:range(12, 30), rng:range(25, 75)
            mb:push()
            mb:translate(x, 0, z)
            mb:rotateY(-a)
            mb:box(-w / 2, -20, -w / 3, w / 2, h, w / 3)
            if rng:next() > 0.5 then mb:cylinder(w * 0.3, h, 0, 2.5, h + rng:range(20, 50), 1.6, 6) end
            mb:pop()
        end
    end
    W.silhouettes = mb:build()
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local ident = M3.identity()
local landmarkFog = { 80, 760, 0.86 }
local silFog = { 300, 1500, 0.8 }
function W.draw(underground)
    if not underground then
        R.drawModel(W.silhouettes, ident, { fog = silFog })
        R.drawModel(W.landmarks, ident, { fog = landmarkFog })
        local chunks = W.chunks
        for _, c in pairs(chunks) do
            if c.model.radius > 0 and R.visible(c.cx, c.cy, c.cz, c.radius) then
                R.drawModel(c.model, ident)
            end
            if c.dmodel and R.visible(c.dcx, c.dcy, c.dcz, c.dradius) then
                R.drawModel(c.dmodel, ident)
            end
        end
    end
    local cam = R.cam
    local near = underground
    for _, a in ipairs(W.interiorAreas) do
        if U.dist3(cam.x, cam.y, cam.z, a.x, a.y, a.z) < a.r + 40 then near = true end
    end
    if near and W.interiorModel.radius > 0 then
        R.drawModel(W.interiorModel, ident, { interior = 1, amb = W.interiorAmbient })
    end
end

function W.surfaceY(x, z) return W.height(x, z) end

function W.isUnderground(x, y, z)
    for _, r in ipairs(W.underground) do
        if x > r[1] and x < r[4] and y > r[2] and y < r[5] and z > r[3] and z < r[6] then return r end
    end
    return nil
end

function W.inShelter(x, y, z)
    for _, r in ipairs(W.shelters) do
        if x > r[1] and x < r[4] and y > r[2] and y < r[5] and z > r[3] and z < r[6] then return true end
    end
    return false
end

function W.radiationAt(x, y, z)
    local rad = 0
    for _, zn in ipairs(W.radZones) do
        local d = U.dist3(x, y, z, zn.x, zn.y or y, zn.z)
        if d < zn.r then rad = rad + zn.strength * (1 - d / zn.r) end
    end
    return rad
end

function W.nearestLocation(x, z)
    local best, bd = nil, 1e9
    for _, l in ipairs(W.locations) do
        local d = U.dist2(x, z, l.x, l.z)
        if d < bd then best, bd = l, d end
    end
    return best, bd
end

return W
