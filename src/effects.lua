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
local MAXDECAL = 1400

function E.init(game)
    G = game
    E.parts = {}
    E.flashes = {}
    E.casings = {}
    E.bbData = love.data.newByteData(MAXP * 6 * ffi.sizeof("bb_vertex"))
    E.bbPtr = ffi.cast("bb_vertex*", E.bbData:getFFIPointer())
    E.meshAlpha = lg.newMesh(BB_FORMAT, MAXP * 6, "triangles", "stream")
    E.meshAdd = lg.newMesh(BB_FORMAT, MAXP * 6, "triangles", "stream")
    E.meshAlpha:setTexture(Textures.get("smoke"))
    E.meshAdd:setTexture(Textures.get("flare"))
    -- decals
    E.decalData = love.data.newByteData(MAXDECAL * 6 * ffi.sizeof("psx_vertex"))
    E.decalPtr = ffi.cast("psx_vertex*", E.decalData:getFFIPointer())
    E.decalMesh = lg.newMesh(MB.FORMAT, MAXDECAL * 6, "triangles", "dynamic")
    E.decalMesh:setTexture(Textures.get("white"))
    E.decalCount, E.decalNext, E.decalDirty = 0, 0, false
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
    E.parts, E.flashes, E.casings = {}, {}, {}
    E.decalCount, E.decalNext, E.decalDirty = 0, 0, true
end

local function spawn(x, y, z, vx, vy, vz, life, size, grow, r, g, b, a, add, drag, grav)
    if #E.parts >= MAXP then table.remove(E.parts, 1) end
    local p = { x = x, y = y, z = z, vx = vx, vy = vy, vz = vz, life = life, max = life, size = size, grow = grow or 0,
                r = r, g = g, b = b, a = a, add = add, drag = drag or 0, grav = grav or 0, rot = math.random() * 6.28 }
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
    spawn(x + dx * 0.1, y + dy * 0.1, z + dz * 0.1, dx * 2, dy * 2, dz * 2, 0.05, 0.35 * s, 1.5 * s, 1, 0.8, 0.45, 1, true)
    spawn(x + dx * 0.3, y + dy * 0.3, z + dz * 0.3, dx * 4, dy * 4, dz * 4, 0.04, 0.2 * s, 1 * s, 1, 0.9, 0.6, 1, true)
    E.flash(x, y, z, 6 * s, 1, 0.75, 0.4, 1.6, 0.06)
    spawn(x, y, z, dx * 1 + rs(0.2), dy + 0.3, dz * 1 + rs(0.2), 0.8, 0.15 * s, 0.6 * s, 0.6, 0.6, 0.6, 0.35, false, 1, -0.2)
end

function E.muzzleBlast(x, y, z, dx, dy, dz, s)
    for i = 1, 4 do
        local k = i * 0.6
        spawn(x + dx * k, y + dy * k, z + dz * k, dx * 6 + rs(1), dy * 6 + rs(1), dz * 6 + rs(1), 0.12, 0.8 + i * 0.3, 6, 1, 0.75, 0.4, 1, true, 3)
    end
    for i = 1, 14 do
        local a = rnd() * 6.28
        local px, pz = math.cos(a), math.sin(a)
        spawn(x + dx, y + dy, z + dz, dx * 8 + px * 4, dy * 8 + rnd() * 2, dz * 8 + pz * 4, 2.5 + rnd() * 1.5, 1.0, 2.2,
              0.55, 0.55, 0.56, 0.6, false, 2.0, -0.15)
    end
    E.flash(x, y, z, 22, 1, 0.7, 0.35, 3.0, 0.12)
end

function E.explosion(x, y, z, s)
    s = s or 1
    for i = 1, 10 do
        spawn(x, y + 0.5, z, rs(6 * s), rnd() * 7 * s, rs(6 * s), 0.25 + rnd() * 0.2, 1.0 * s, 4 * s, 1, 0.6, 0.25, 1, true, 3, -1)
    end
    for i = 1, 18 do
        spawn(x + rs(1.5 * s), y + rnd() * 2 * s, z + rs(1.5 * s), rs(3 * s), 2 + rnd() * 4 * s, rs(3 * s), 4 + rnd() * 3, 1.4 * s, 2.6 * s,
              0.18, 0.17, 0.17, 0.75, false, 1.3, -0.4)
    end
    for i = 1, 16 do
        spawn(x, y + 0.3, z, rs(9 * s), 4 + rnd() * 10 * s, rs(9 * s), 1.4 + rnd(), 0.18, 0.2, 0.75, 0.75, 0.78, 0.9, false, 0.3, 12)
    end
    for i = 1, 10 do
        spawn(x, y + 0.5, z, rs(14 * s), 3 + rnd() * 9 * s, rs(14 * s), 0.6 + rnd() * 0.6, 0.06, 0, 1, 0.6, 0.2, 1, true, 0.2, 12)
    end
    E.flash(x, y + 1, z, 30 * s, 1, 0.6, 0.25, 4.0, 0.35)
    E.scorch(x, z, 2.2 * s)
end

function E.fire(x, y, z, s)
    s = s or 1
    spawn(x + rs(0.2 * s), y, z + rs(0.2 * s), rs(0.2), 1.2 + rnd() * 0.8, rs(0.2), 0.45 + rnd() * 0.3, 0.25 * s, 0.4 * s, 1, 0.55 + rnd() * 0.2, 0.2, 1, true, 0.5, -1)
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
            else floor = G.world.height(c.x, c.z) + 0.02 end
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
local function addDecal(x, z, yaw, w, l, r, g, b, a)
    local W = G.world
    local c, s = math.cos(yaw), math.sin(yaw)
    local hw, hl = w / 2, l / 2
    local pts = {}
    for k, o in ipairs({ { -hl, -hw }, { hl, -hw }, { hl, hw }, { -hl, hw } }) do
        local px, pz = x + c * o[1] - s * o[2], z + s * o[1] + c * o[2]
        pts[k] = { px, W.height(px, pz) + 0.05, pz }
    end
    local idx = E.decalNext
    E.decalNext = (E.decalNext + 1) % MAXDECAL
    E.decalCount = math.min(MAXDECAL, E.decalCount + 1)
    local base = idx * 6
    local order = { 1, 3, 2, 1, 4, 3 }
    local uv = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }
    for i = 1, 6 do
        local p = pts[order[i]]
        local v = E.decalPtr[base + i - 1]
        v.x, v.y, v.z = p[1], p[2], p[3]
        v.u, v.v = uv[order[i]][1], uv[order[i]][2]
        v.nx, v.ny, v.nz = 0, 1, 0
        v.r, v.g, v.b, v.a = r * 255, g * 255, b * 255, a * 255
    end
    E.decalDirty = true
end

function E.footprint(x, z, yaw)
    if G.world.isRiver(x, z) then return end
    addDecal(x, z, yaw, 0.14, 0.3, 0.55, 0.58, 0.66, 0.55)
end

function E.trackMark(x, z, yaw)
    addDecal(x, z, yaw, 0.58, 0.85, 0.45, 0.47, 0.52, 0.6)
end

function E.scorch(x, z, r)
    addDecal(x, z, rnd() * 6, r * 2, r * 2, 0.12, 0.11, 0.1, 0.8)
end

---------------------------------------------------------------------------
-- update & draw
---------------------------------------------------------------------------
function E.update(dt)
    E.time = E.time + dt
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
                local corners = {
                    { p.x - ax - bx, p.y - ay - by, p.z - az - bz, 0, 0 },
                    { p.x + ax - bx, p.y + ay - by, p.z + az - bz, 1, 0 },
                    { p.x + ax + bx, p.y + ay + by, p.z + az + bz, 1, 1 },
                    { p.x - ax + bx, p.y - ay + by, p.z - az + bz, 0, 1 },
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
    R.drawModel(E.decalModel, nil, { fog = { R.env.fogStart, R.env.fogEnd, 1 } })
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
            local py = s.y or W.height(px, pz)
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
