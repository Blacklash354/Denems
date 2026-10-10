-- Terrain heightfield, road network, chunked static geometry, instanced vegetation,
-- static colliders and world queries for a 4 km open world.
local U = require("src.utils")
local MB = require("src.engine.meshbuilder")
local P = require("src.physics")
local R = require("src.engine.renderer")
local M3 = require("src.engine.math3d")
local ffi = require("ffi")

local W = {}
W.HALF = 2048
W.CELL = 8
W.N = 512
W.CHUNK = 16       -- cells per chunk (128 m)
W.LIMIT = 1880     -- playable boundary
W.SEED = 1945

local floor, sqrt, max, min, abs = math.floor, math.sqrt, math.max, math.min, math.abs
local pi = math.pi

---------------------------------------------------------------------------
-- layout data: places are far apart, travel between them takes time
---------------------------------------------------------------------------
W.locations = {
    { id = "kolkhoz", name = "KOLKHOZ", area = "KOLKHOZ 'RED DAWN'", x = -270, z = 1430, r = 95, icon = "farm" },
    { id = "camp", name = "SURVIVOR CAMP", area = "SURVIVORS' CAMP", x = -600, z = 1170, r = 28, icon = "camp" },
    { id = "station", name = "FUEL STATION", area = "ABANDONED FUEL STATION", x = 252, z = 1180, r = 26, icon = "station" },
    { id = "checkpoint", name = "CHECKPOINT", area = "ARMY CHECKPOINT", x = 150, z = 935, r = 48, icon = "checkpoint" },
    { id = "garages", name = "GARAGES", area = "GARAGE COOPERATIVE No.4", x = 520, z = 600, r = 85, icon = "garage" },
    { id = "town", name = "PERVOMAISK", area = "PERVOMAISK", x = -720, z = 560, r = 150, icon = "town" },
    { id = "industrial", name = "INDUSTRIAL ZONE", area = "TRACTOR WORKS", x = -1320, z = 150, r = 150, icon = "factory" },
    { id = "forest", name = "FOREST", area = "FROZEN FOREST", x = 1180, z = 930, r = 230, icon = "forest", noFlatten = true },
    { id = "city", name = "ZARECHNY", area = "ZARECHNY", x = -200, z = -470, r = 330, icon = "city" },
    { id = "airfield", name = "AIRFIELD", area = "TANK AIRFIELD", x = 1200, z = -390, r = 290, icon = "airfield" },
    { id = "base", name = "MILITARY BASE", area = "ARMY BASE", x = -1160, z = -760, r = 110, icon = "base" },
    { id = "tower", name = "RADIO TOWER", area = "RADIO TOWER", x = 780, z = -1160, r = 45, icon = "tower", hill = 40 },
    { id = "bunker", name = "BUNKER", area = "OBJECT 12", x = -1430, z = -1380, r = 30, icon = "bunker" },
    { id = "plant", name = "NUCLEAR PLANT", area = "POWER PLANT", x = 280, z = -1540, r = 160, icon = "plant" },
}
for _, l in ipairs(W.locations) do W[l.id] = l end

-- road network: control points of smooth (Catmull-Rom) roads. half = half width, mat = surface
W.roads = {
    { name = "highway", half = 4.4, mat = "road", pts = { { 20, 1990 }, { 30, 1720 }, { 110, 1460 }, { 215, 1250 }, { 150, 935 },
        { 260, 760 }, { 330, 560 }, { 170, 230 }, { -60, -110 }, { -170, -300 }, { -180, -480 }, { -130, -760 },
        { 40, -1050 }, { 220, -1300 }, { 270, -1440 } } },
    { name = "town", half = 3.4, mat = "road", pts = { { 260, 760 }, { -60, 700 }, { -400, 620 }, { -720, 560 }, { -960, 500 },
        { -1160, 320 }, { -1320, 150 }, { -1560, 50 } } },
    { name = "kolkhoz", half = 2.6, mat = "track", pts = { { 30, 1720 }, { -120, 1510 }, { -270, 1430 }, { -440, 1300 }, { -600, 1170 } } },
    { name = "forest", half = 3.0, mat = "road", pts = { { 330, 560 }, { 520, 600 }, { 760, 760 }, { 1000, 880 }, { 1180, 930 } } },
    { name = "airfield", half = 3.6, mat = "road", pts = { { -60, -110 }, { 300, -250 }, { 700, -350 }, { 960, -390 }, { 1060, -390 } } },
    { name = "base", half = 3.4, mat = "road", pts = { { -180, -480 }, { -500, -600 }, { -850, -700 }, { -1160, -760 }, { -1360, -1000 },
        { -1420, -1300 } } },
    { name = "tower", half = 2.8, mat = "track", pts = { { -130, -760 }, { 200, -900 }, { 500, -1060 }, { 760, -1150 } } },
}
W.START = { x = 46, z = 1610, yaw = -pi / 2 - 0.2 }

function W.riverX(z) return 650 + 110 * math.sin(z / 430) + 35 * math.sin(z / 137 + 1) end

---------------------------------------------------------------------------
-- base height (no roads or places)
---------------------------------------------------------------------------
local function baseHeight(x, z)
    local h = U.fbm(x / 620, z / 620, 3, 11) * 46 + U.fbm(x / 170, z / 170, 2, 23) * 7 - 24
    -- mountains towards the border
    local e = max(abs(x), abs(z))
    local m = U.smoothstep(1720, 2010, e)
    h = h + m * (70 + U.fbm(x / 120, z / 120, 3, 31) * 80)
    for _, l in ipairs(W.locations) do
        if l.hill then
            local d = U.dist2(x, z, l.x, l.z)
            if d < 400 then h = h + l.hill * math.exp(-(d / 150) ^ 2) end
        end
    end
    return h
end
W.baseHeight = baseHeight

local function locationHeight(l)
    if not l.h then l.h = baseHeight(l.x, l.z) end
    return l.h
end

-- base height pulled towards the flattened places
local function placeHeight(x, z, h)
    h = h or baseHeight(x, z)
    for _, l in ipairs(W.locations) do
        if not l.noFlatten then
            local dx, dz = x - l.x, z - l.z
            if abs(dx) < l.r * 1.6 and abs(dz) < l.r * 1.6 then
                local w = U.smoothstep(l.r * 1.5, l.r * 0.9, sqrt(dx * dx + dz * dz))
                if w > 0 then h = U.lerp(h, locationHeight(l), w) end
            end
        end
    end
    return h
end

---------------------------------------------------------------------------
-- roads: sampled centre lines with smoothed height profiles and a segment grid for queries
---------------------------------------------------------------------------
local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    local function c(a, b, cc, d) return 0.5 * ((2 * b) + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3) end
    return c(p0[1], p1[1], p2[1], p3[1]), c(p0[2], p1[2], p2[2], p3[2])
end

local SEG_CELL = 48
local segGrid = {}
local function segKey(ix, iz) return ix * 4096 + iz end

local function buildRoadPaths()
    W.roadPaths = {}
    for ri, road in ipairs(W.roads) do
        local pts = road.pts
        local path = { road = road, index = ri }
        local n = #pts
        for i = 1, n - 1 do
            local p0, p1, p2, p3 = pts[math.max(1, i - 1)], pts[i], pts[i + 1], pts[math.min(n, i + 2)]
            local len = U.dist2(p1[1], p1[2], p2[1], p2[2])
            local steps = math.max(2, math.ceil(len / 4))
            for s = 0, steps - 1 do
                local x, z = catmull(p0, p1, p2, p3, s / steps)
                path[#path + 1] = { x = x, z = z }
            end
        end
        path[#path + 1] = { x = pts[n][1], z = pts[n][2] }
        -- distances, tangents, raw heights
        local dist = 0
        for i, p in ipairs(path) do
            if i > 1 then dist = dist + U.dist2(p.x, p.z, path[i - 1].x, path[i - 1].z) end
            p.d = dist
            local a, b = path[math.max(1, i - 1)], path[math.min(#path, i + 1)]
            local tx, tz = b.x - a.x, b.z - a.z
            local l = sqrt(tx * tx + tz * tz)
            p.tx, p.tz = tx / l, tz / l
            p.raw = placeHeight(p.x, p.z)
        end
        -- smooth the height profile along the road (gentle grades)
        for i, p in ipairs(path) do
            local sum, wsum = 0, 0
            for k = math.max(1, i - 7), math.min(#path, i + 7) do
                local w = 1 - abs(k - i) / 8
                sum, wsum = sum + path[k].raw * w, wsum + w
            end
            p.h = sum / wsum
        end
        path.length = dist
        road.lift = 0.03 + ri * 0.004      -- road surface above its profile (separate roads never z-fight)
        W.roadPaths[ri] = path
    end
    -- segment grid
    segGrid = {}
    for _, path in ipairs(W.roadPaths) do
        local reach = path.road.half + 40
        for i = 1, #path - 1 do
            local a, b = path[i], path[i + 1]
            local seg = { a = a, b = b, path = path }
            for ix = floor((min(a.x, b.x) - reach) / SEG_CELL), floor((max(a.x, b.x) + reach) / SEG_CELL) do
                for iz = floor((min(a.z, b.z) - reach) / SEG_CELL), floor((max(a.z, b.z) + reach) / SEG_CELL) do
                    local k = segKey(ix, iz)
                    local list = segGrid[k]
                    if not list then list = {} segGrid[k] = list end
                    list[#list + 1] = seg
                end
            end
        end
    end
end

-- nearest road: distance to its centre line, profile height there, the road, the path point
local function roadInfo(x, z)
    local list = segGrid[segKey(floor(x / SEG_CELL), floor(z / SEG_CELL))]
    if not list then return 1e9, 0, nil end
    local best, bestH, bestRoad, bt, bseg = 1e9, 0, nil, 0, nil
    for i = 1, #list do
        local s = list[i]
        local a, b = s.a, s.b
        local d, t = U.distToSegment(x, z, a.x, a.z, b.x, b.z)
        d = d - s.path.road.half
        if d < best then best, bestH, bestRoad, bt, bseg = d, a.h + (b.h - a.h) * t, s.path.road, t, s end
    end
    return best, bestH, bestRoad, bseg, bt
end
W.roadInfo = roadInfo
-- distance from the road edge (negative on the road surface); old callers compare with ~6-10 m
function W.roadDistance(x, z)
    local d, _, road = roadInfo(x, z)
    if not road then return 1e9 end
    return d + road.half
end

---------------------------------------------------------------------------
-- rivers and bridges
---------------------------------------------------------------------------
W.bridges = {}
local function findBridges()
    W.bridges = {}
    for _, path in ipairs(W.roadPaths) do
        for i = 1, #path - 1 do
            local a, b = path[i], path[i + 1]
            local sa, sb = a.x - W.riverX(a.z), b.x - W.riverX(b.z)
            if sa * sb <= 0 then
                local t = sa / (sa - sb)
                local x, z = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
                W.bridges[#W.bridges + 1] = { x = x, z = z, h = a.h + (b.h - a.h) * t, tx = a.tx, tz = a.tz, road = path.road,
                                              broken = path.road.name == "forest", path = path, i = i }
            end
        end
    end
end

local function nearBridge(x, z, r)
    for _, b in ipairs(W.bridges) do
        if abs(x - b.x) < r and abs(z - b.z) < r and U.dist2(x, z, b.x, b.z) < r then return b end
    end
end

---------------------------------------------------------------------------
-- height function
---------------------------------------------------------------------------
function W.computeHeight(x, z)
    local base = baseHeight(x, z)
    local h = placeHeight(x, z, base)
    -- river valley
    local rd = abs(x - W.riverX(z))
    local rw = U.smoothstep(40, 13, rd)
    if rw > 0 then
        local riverBed = baseHeight(W.riverX(z), z) - 5
        h = U.lerp(h, min(h, riverBed), rw)
    end
    -- roads: a flat corridor wide enough that no terrain triangle can poke through the road surface.
    -- Intact bridges sit on an earth causeway; at the broken bridge the river keeps its bed.
    local d, rh, road = roadInfo(x, z)
    if road then
        local br = rw > 0.2 and nearBridge(x, z, 70)
        if not (br and br.broken) then
            -- well under the road surface so the coarse terrain triangles never show through it; wheels,
            -- feet and decals stand on the road itself (W.groundHeight)
            local w = U.smoothstep(30, 11.5, d)
            if w > 0 then h = U.lerp(h, rh - 0.22, w) end
        end
    end
    return h
end

---------------------------------------------------------------------------
-- heightfield storage and queries
---------------------------------------------------------------------------
function W.computeHeights()
    buildRoadPaths()
    findBridges()
    local N, C, H = W.N, W.CELL, W.HALF
    W.hgrid = {}
    for i = 0, N do
        local row = {}
        for j = 0, N do
            row[j] = W.computeHeight(-H + i * C, -H + j * C)
        end
        W.hgrid[i] = row
        if i % 16 == 0 and coroutine.isyieldable() then coroutine.yield("terrain", i / N * 0.3) end
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

function W.isRiver(x, z) return abs(x - W.riverX(z)) < 14 and W.height(x, z) < baseHeight(W.riverX(z), z) - 3.5 end

-- ground height including the road surface (terrain sits a few cm below the road meshes)
function W.groundHeight(x, z)
    local h = W.height(x, z)
    local d, rh, road = roadInfo(x, z)
    if road and d < 0.3 then
        local r = rh + road.lift
        if r > h then h = r end
    end
    return h, road and d < 0.3
end

-- surface height including walkable static boxes (for vehicles/creatures)
local gtmp = {}
function W.surfaceHeight(x, z, fromY, radius)
    local h = W.groundHeight(x, z)
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
        if t > 120 then step = 4.0 end
    end
    return nil
end

---------------------------------------------------------------------------
-- chunks & generation context
---------------------------------------------------------------------------
local CHUNK_SIZE = W.CELL * W.CHUNK
W.CHUNK_SIZE = CHUNK_SIZE
local NCH = W.N / W.CHUNK
W.NCH = NCH

function W.chunkIndex(x, z)
    local ci = U.clamp(floor((x + W.HALF) / CHUNK_SIZE), 0, NCH - 1)
    local cj = U.clamp(floor((z + W.HALF) / CHUNK_SIZE), 0, NCH - 1)
    return ci, cj
end

function W.initChunks()
    W.chunks = {}
    for ci = 0, NCH - 1 do
        for cj = 0, NCH - 1 do
            local c = { ci = ci, cj = cj, mb = MB.new(ci * 131 + cj * 7 + 1), rmb = MB.new(ci * 131 + cj * 7 + 5), inst = {} }
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
    W.npcs, W.guitars, W.squads, W.blocks = {}, {}, {}, {}
    W.dobjs = {}
    W.instanceKinds = {}
    W.trees = {}
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

Ctx.__index = Ctx
W.Ctx = Ctx

function W.ctx(x, z, rot, opts)
    opts = opts or {}
    local mb
    if opts.landmark then mb = W.landmarkMB:view()
    elseif opts.interior then mb = W.interiorMB:view()
    else mb = W.chunkAt(x, z).mb:view() end
    local y = opts.y or W.height(x, z)
    local c = setmetatable({ mb = mb, x = x, y = y, z = z, rot = rot or 0, opts = opts }, Ctx)
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
-- instanced props (trees, bushes, rocks, grass): one small model drawn many times per chunk
---------------------------------------------------------------------------
-- kinds are registered with a builder function(mb) that emits the model at the origin
function W.instanceKind(name, build, opts)
    W.instanceKinds[name] = { build = build, opts = opts or {} }
end

function W.addInstance(name, x, y, z, yaw, scale, tint)
    local ch = W.chunkAt(x, z)
    local list = ch.inst[name]
    if not list then list = {} ch.inst[name] = list end
    list[#list + 1] = { x, y, z, yaw or 0, scale or 1, tint or 1 }
    return ch, #list
end

-- hide / show one instance (a tree knocked down, or put back up on a reset). Only with hardware
-- instancing: baked instances are part of the chunk geometry.
function W.setInstanceVisible(ch, name, idx, visible)
    local d = ch.instByKind and ch.instByKind[name]
    if not d then return false end
    local t = d.list[idx]
    d.mesh:setVertex(idx, t[1], t[2], t[3], t[4], visible and t[5] or 0, t[6])
    return true
end

local INST_FORMAT = { { "InstXf", "float", 4 }, { "InstSc", "float", 2 } }

local function buildInstances()
    W.instModels = {}
    for name, k in pairs(W.instanceKinds) do
        local mb = MB.new(900 + #name)
        mb.texScale = k.opts.texScale or 0.5
        k.build(mb)
        W.instModels[name] = mb:build()
    end
    for _, c in pairs(W.chunks) do
        c.instDraw = {}
        for name, list in pairs(c.inst) do
            local model = W.instModels[name]
            if model and #list > 0 then
                local verts = {}
                for i, t in ipairs(list) do verts[i] = { t[1], t[2], t[3], t[4], t[5], t[6] } end
                local im = love.graphics.newMesh(INST_FORMAT, verts, "points", "dynamic")
                local d = { model = model, mesh = im, count = #list, list = list }
                c.instDraw[#c.instDraw + 1] = d
                c.instByKind = c.instByKind or {}
                c.instByKind[name] = d
            end
        end
        c.inst = nil
    end
end

-- no hardware instancing: bake the copies into the chunk geometry before it is finalised
local function bakeInstances()
    for _, c in pairs(W.chunks) do
        for name, list in pairs(c.inst) do
            local k = W.instanceKinds[name]
            local mb = c.mb
            for _, t in ipairs(list) do
                mb:reset()
                mb:translate(t[1], t[2], t[3])
                mb:rotateY(t[4])
                mb:scale(t[5], t[5], t[5])
                k.build(mb)
            end
        end
        c.inst = {}
    end
end

---------------------------------------------------------------------------
-- terrain meshes: one indexed 17x17 vertex grid per chunk, smooth normals, one mesh per surface
---------------------------------------------------------------------------
local VSIZE = ffi.sizeof("psx_vertex")
local function terrainChunk(ci, cj)
    local N, C, H = W.N, W.CELL, W.HALF
    local g = W.hgrid
    local K = W.CHUNK
    local i0, j0 = ci * K, cj * K
    local nv = (K + 1) * (K + 1)
    local function vid(a, b) return a * (K + 1) + b + 1 end
    local data = love.data.newByteData(nv * VSIZE)
    local p = ffi.cast("psx_vertex*", data:getFFIPointer())
    local b0, b1 = math.huge, -math.huge
    for a = 0, K do
        for b = 0, K do
            local i, j = i0 + a, j0 + b
            local x, z = -H + i * C, -H + j * C
            local h = g[i][j]
            local hl, hr = g[math.max(0, i - 1)][j], g[math.min(N, i + 1)][j]
            local hd, hu = g[i][math.max(0, j - 1)], g[i][math.min(N, j + 1)]
            local nx, ny, nz = U.norm3(hl - hr, 2 * C, hd - hu)
            local q = p[vid(a, b) - 1]
            q.x, q.y, q.z = x, h, z
            q.u, q.v = x * 0.25, z * 0.25
            q.nx, q.ny, q.nz = nx, ny, nz
            local n = U.fbm(x / 40, z / 40, 2, 5)
            local v = 0.86 + n * 0.14 + (U.hash2(i, j, 3) - 0.5) * 0.05
            q.r, q.g, q.b, q.a = floor(math.min(1, v * 0.97) * 255), floor(math.min(1, v * 0.98) * 255), floor(math.min(1, v) * 255), 255
            if h < b0 then b0 = h end
            if h > b1 then b1 = h end
        end
    end
    local idx = { snow = {}, ice = {}, rubble = {} }
    for a = 0, K - 1 do
        for b = 0, K - 1 do
            local i, j = i0 + a, j0 + b
            local h00, h10, h01, h11 = g[i][j], g[i + 1][j], g[i][j + 1], g[i + 1][j + 1]
            local cx, cz = -H + (i + 0.5) * C, -H + (j + 0.5) * C
            local slope = max(abs(h10 - h00), abs(h01 - h00), abs(h11 - h00)) / C
            local mat = "snow"
            if abs(cx - W.riverX(cz)) < 14 and h00 < baseHeight(W.riverX(cz), cz) - 3.5 then mat = "ice"
            elseif slope > 0.95 then mat = "rubble" end
            local l = idx[mat]
            local v00, v10, v01, v11 = vid(a, b), vid(a + 1, b), vid(a, b + 1), vid(a + 1, b + 1)
            -- same diagonal as W.height(): (0,0)-(1,1)
            l[#l + 1], l[#l + 2], l[#l + 3] = v00, v11, v10
            l[#l + 1], l[#l + 2], l[#l + 3] = v00, v01, v11
        end
    end
    local model = { parts = {}, tris = 0 }
    for _, mat in ipairs({ "snow", "ice", "rubble" }) do
        local l = idx[mat]
        if #l > 0 then
            local mesh = love.graphics.newMesh(MB.FORMAT, nv, "triangles", "static")
            mesh:setVertices(data)
            mesh:setVertexMap(l)
            local Textures = require("src.engine.textures")
            local tex = Textures.get(mat)
            mesh:setTexture(tex)
            model.parts[#model.parts + 1] = { mesh = mesh, tex = tex, mat = mat }
            model.tris = model.tris + #l / 3
        end
    end
    local x0, z0 = -H + i0 * C, -H + j0 * C
    model.cx, model.cy, model.cz = x0 + K * C / 2, (b0 + b1) / 2, z0 + K * C / 2
    model.radius = sqrt((K * C) ^ 2 * 2 + (b1 - b0) ^ 2) / 2
    return model
end

function W.buildTerrain()
    for ci = 0, NCH - 1 do
        for cj = 0, NCH - 1 do
            W.chunks[ci * NCH + cj].terrain = terrainChunk(ci, cj)
        end
        if coroutine.isyieldable() and ci % 4 == 0 then coroutine.yield("terrain", 0.75 + ci / NCH * 0.1) end
    end
end

---------------------------------------------------------------------------
-- road surfaces: strips following the centre lines, texture mapped along the road
---------------------------------------------------------------------------
-- quad whose normal faces up whatever the corner order
local function upQuad(mb, ax, ay, az, au, av, bx, by, bz, bu, bv, cx, cy, cz, cu, cv, dx, dy, dz, du, dv)
    local ux, uz = bx - ax, bz - az
    local vx, vz = cx - ax, cz - az
    if uz * vx - ux * vz >= 0 then
        mb:quadUV(ax, ay, az, au, av, bx, by, bz, bu, bv, cx, cy, cz, cu, cv, dx, dy, dz, du, dv)
    else
        mb:quadUV(dx, dy, dz, du, dv, cx, cy, cz, cu, cv, bx, by, bz, bu, bv, ax, ay, az, au, av)
    end
end
W.upQuad = upQuad

function W.buildRoadMeshes()
    for ri, path in ipairs(W.roadPaths) do
        local road = path.road
        local half = road.half
        local lift = road.lift
        local repeatLen = road.mat == "track" and 6 or 8
        for i = 1, #path - 1 do
            local a, b = path[i], path[i + 1]
            local mx, mz = (a.x + b.x) / 2, (a.z + b.z) / 2
            local bridge = nearBridge(mx, mz, 30)
            if not (bridge and bridge.broken and U.dist2(mx, mz, bridge.x, bridge.z) < 18) then
                local mb = W.chunkAt(mx, mz).rmb
                mb:reset()
                mb.jitter = 0.02
                local anx, anz = -a.tz, a.tx
                local bnx, bnz = -b.tz, b.tx
                local ha, hb = a.h + lift, b.h + lift
                local va, vb = a.d / repeatLen, b.d / repeatLen
                mb:material(road.mat):color(1, 1, 1)
                upQuad(mb, a.x - anx * half, ha, a.z - anz * half, 0, va,
                           a.x + anx * half, ha, a.z + anz * half, 1, va,
                           b.x + bnx * half, hb, b.z + bnz * half, 1, vb,
                           b.x - bnx * half, hb, b.z - bnz * half, 0, vb)
                -- ploughed snow banks along both edges
                if not bridge then
                    mb:material("snow"):color(0.97, 0.98, 1)
                    for s = -1, 1, 2 do
                        local function P(p, nx, nz, off, dy) return p.x + nx * off * s, p.h + lift + dy, p.z + nz * off * s end
                        local e0x, e0y, e0z = P(a, anx, anz, half, -0.02)
                        local e1x, e1y, e1z = P(b, bnx, bnz, half, -0.02)
                        local t0x, t0y, t0z = P(a, anx, anz, half + 0.5, 0.22)
                        local t1x, t1y, t1z = P(b, bnx, bnz, half + 0.5, 0.22)
                        local o0x, o0y, o0z = P(a, anx, anz, half + 1.4, -0.3)
                        local o1x, o1y, o1z = P(b, bnx, bnz, half + 1.4, -0.3)
                        -- same texel density as the terrain snow: 0.25 repeats per metre both ways
                        local sa, sb = a.d * 0.25, b.d * 0.25
                        upQuad(mb, e0x, e0y, e0z, 0, sa, t0x, t0y, t0z, 0.125, sa, t1x, t1y, t1z, 0.125, sb, e1x, e1y, e1z, 0, sb)
                        upQuad(mb, t0x, t0y, t0z, 0.125, sa, o0x, o0y, o0z, 0.35, sa, o1x, o1y, o1z, 0.35, sb, t1x, t1y, t1z, 0.125, sb)
                    end
                end
                mb.jitter = 0.06
            end
        end
    end
end

function W.finalize()
    if not R.instancing then bakeInstances() end
    for k, c in pairs(W.chunks) do
        c.model = c.mb:build()
        c.mb = nil
        -- roads in a model of their own, drawn like the terrain (see W.draw)
        c.roads = c.rmb:build()
        c.rmb = nil
        c.cx, c.cy, c.cz = c.model.cx, c.model.cy, c.model.cz
        c.radius = c.model.radius
    end
    buildInstances()
    W.landmarks = W.landmarkMB:build()
    W.landmarkMB = nil
    W.interiorModel = W.interiorMB:build()
    W.interiorMB = nil
    for _, o in ipairs(W.dobjs) do if o.builder then W.finishDObj(o) end end
    for _, c in pairs(W.chunks) do if c.dobjs then W.rebuildChunkD(c) end end
    W.indexShelters()
    collectgarbage()
end

---------------------------------------------------------------------------
-- distant silhouettes (mountains + ruined skyline) to hide the world border
---------------------------------------------------------------------------
function W.buildSilhouettes()
    local mb = MB.new(5)
    mb.jitter = 0.02
    mb.texScale = 0.02
    mb:material("rubble"):color(0.55, 0.57, 0.62)
    local seg = 128
    local R0 = 3000
    local prevTop
    for i = 0, seg do
        local a = i / seg * 2 * pi
        local top = 140 + U.fbm(math.cos(a) * 3 + 10, math.sin(a) * 3 + 10, 4, 3) * 320
        if i > 0 then
            local a0 = (i - 1) / seg * 2 * pi
            local x0, z0 = math.cos(a0) * R0, math.sin(a0) * R0
            local x1, z1 = math.cos(a) * R0, math.sin(a) * R0
            mb:quad(x0, -60, z0, x1, -60, z1, x1, top, z1, x0, prevTop, z0)
            mb:quad(x0, prevTop, z0, x1, top, z1, x1, -60, z1, x0, -60, z0)
        end
        prevTop = top
    end
    W.silhouettes = mb:build()
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local ident = M3.identity()
local landmarkFog = { 120, 1300, 0.88 }
-- the ground (terrain, roads) never takes the retro affine texture wobble: on big ground triangles
-- it made the roads swim and stretch as you moved
local FLAT = { flat = true }
local silFog = { 400, 3200, 0.82 }
function W.draw(underground)
    if not underground then
        R.drawModel(W.silhouettes, ident, { fog = silFog })
        R.drawModel(W.landmarks, ident, { fog = landmarkFog })
        local chunks = W.chunks
        for _, c in pairs(chunks) do
            local t = c.terrain
            if R.visible(t.cx, t.cy, t.cz, t.radius) then
                R.drawModel(t, ident, FLAT)
                if c.roads.radius > 0 then R.drawModel(c.roads, ident, FLAT) end
                if c.model.radius > 0 and R.visible(c.cx, c.cy, c.cz, c.radius) then R.drawModel(c.model, ident) end
                if c.dmodel and R.visible(c.dcx, c.dcy, c.dcz, c.dradius) then R.drawModel(c.dmodel, ident) end
                for _, d in ipairs(c.instDraw) do R.drawInstanced(d.model, d.mesh, d.count) end
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

-- shelters are many (every room of every block): a coarse grid keeps the lookup cheap
local shelterGrid
local function shelterKey(ix, iz) return ix * 4096 + iz end
function W.indexShelters()
    shelterGrid = {}
    for _, r in ipairs(W.shelters) do
        for ix = floor(r[1] / 32), floor(r[4] / 32) do
            for iz = floor(r[3] / 32), floor(r[6] / 32) do
                local k = shelterKey(ix, iz)
                shelterGrid[k] = shelterGrid[k] or {}
                table.insert(shelterGrid[k], r)
            end
        end
    end
end

function W.inShelter(x, y, z)
    local list
    if shelterGrid then list = shelterGrid[shelterKey(floor(x / 32), floor(z / 32))] or {} else list = W.shelters end
    for _, r in ipairs(list) do
        if x > r[1] and x < r[4] and y > r[2] and y < r[5] and z > r[3] and z < r[6] then return r end
    end
    return nil
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
