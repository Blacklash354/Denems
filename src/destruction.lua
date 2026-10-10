-- Destructible world: objects take damage from bullets, shells, explosions and the tank's weight,
-- then break apart into flying debris, dust and smoke. Buildings collapse into rubble,
-- vehicles burn out, fuel tanks explode.
local U = require("src.utils")
local MB = require("src.engine.meshbuilder")
local R = require("src.engine.renderer")

local D = { fallen = {}, collapsing = {} }
local G

-- damage multipliers per material class
local RES = {
    wood = { bullet = 1.0, explosion = 1.0, ram = 1.0 },
    cloth = { bullet = 1.0, explosion = 1.0, ram = 1.0 },
    metal = { bullet = 0.55, explosion = 1.0, ram = 0.8 },
    stone = { bullet = 0.3, explosion = 1.0, ram = 0.6 },
    vehicle = { bullet = 0.4, explosion = 1.0, ram = 0.7 },
    building = { bullet = 0.03, explosion = 1.0, ram = 0.5 },
}
local SOUND = { wood = "wood_break", cloth = "wood_break", metal = "clang", stone = "collapse", vehicle = "explosion", building = "collapse" }

function D.init(game) G = game end

function D.reset(saved)
    local W = G.world
    -- stand every tree back up, then knock down the ones the save remembers
    for _, f in ipairs(D.fallen) do
        local t = f.t
        t.down = false
        t.box.enabled = true
        W.setInstanceVisible(t.ch, t.kind, t.idx, true)
    end
    D.fallen, D.collapsing = {}, {}
    for _, r in ipairs(saved and saved.trees or {}) do
        local t = W.trees[r[1]]
        if t and D.knockTree(t, r[4], r[5], 0, true) then
            local f = D.fallen[#D.fallen]
            f.bx, f.bz = r[2], r[3]
            f.by = W.groundHeight(f.bx, f.bz)
            f.th, f.w, f.state = r[6], 0, "rest"
        end
    end
end

function D.serialize()
    local trees = {}
    for _, f in ipairs(D.fallen) do
        local q = function(v) return math.floor(v * 100 + 0.5) / 100 end
        trees[#trees + 1] = { f.t.i, q(f.bx), q(f.bz), q(f.dx), q(f.dz), q(math.max(f.th, f.restTh or 0)) }
    end
    return { trees = trees }
end

local function dominantMat(obj)
    local best, bn = "rubble", 0
    for name, r in pairs(obj.raw or {}) do
        if r.n > bn and name ~= "window" and name ~= "snow" then best, bn = name, r.n end
    end
    return best
end
D.dominantMat = dominantMat

-- rubble mound + broken wall stubs where a building stood
local function buildRuin(obj, mat)
    local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
    for _, b in ipairs(obj.colliders) do
        x0, z0, x1, z1 = math.min(x0, b[1]), math.min(z0, b[3]), math.max(x1, b[4]), math.max(z1, b[6])
    end
    if x0 > x1 then return end
    local y = obj.baseY
    local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    local w, d = x1 - x0, z1 - z0
    local mb = MB.new(obj.id * 13 + 5)
    mb.texScale = 0.5
    local rng = U.rng(obj.id * 7 + 1)
    mb:material("rubble"):color(0.85, 0.83, 0.8)
    mb:sphere(cx, y - 0.2, cz, w * 0.48, 1.4, d * 0.48, 8, 4)
    for i = 1, 5 do
        mb:push() mb:translate(cx + rng:range(-w / 3, w / 3), y + 0.2, cz + rng:range(-d / 3, d / 3)) mb:rotateY(rng:range(0, 6))
        mb:sphere(0, 0, 0, rng:range(0.6, 1.4), rng:range(0.4, 0.9), rng:range(0.6, 1.2), 5, 3)
        mb:pop()
    end
    -- jagged wall stubs along the old outline
    mb:material(mat):color(0.75, 0.72, 0.68)
    for i = 1, 6 do
        local side = i % 4
        local t = rng:range(0.1, 0.8)
        local h = rng:range(0.4, 2.2)
        local len = rng:range(1.0, 2.6)
        if side == 0 then mb:box(x0 + t * w, y, z0 - 0.12, x0 + t * w + len, y + h, z0 + 0.12)
        elseif side == 1 then mb:box(x0 + t * w, y, z1 - 0.12, x0 + t * w + len, y + h, z1 + 0.12)
        elseif side == 2 then mb:box(x0 - 0.12, y, z0 + t * d, x0 + 0.12, y + h, z0 + t * d + len)
        else mb:box(x1 - 0.12, y, z0 + t * d, x1 + 0.12, y + h, z0 + t * d + len) end
    end
    mb:material("wood"):color(0.35, 0.3, 0.26)
    for i = 1, 3 do
        local ax, az = cx + rng:range(-w / 2, w / 2), cz + rng:range(-d / 2, d / 2)
        mb:push() mb:translate(ax, y + 0.6, az) mb:rotateY(rng:range(0, 6)) mb:rotateZ(rng:range(-0.5, 0.5))
        mb:box(-1.5, -0.08, -0.08, 1.5, 0.08, 0.08)
        mb:pop()
    end
    mb:material("snow"):color(0.95, 0.97, 1)
    mb:sphere(cx, y + 0.9, cz, w * 0.25, 0.25, d * 0.25, 6, 3)
    local raw, b = mb:buildRaw()
    local ruin = { ruin = true, alive = false, raw = raw, bounds = { b[1], b[2], b[3], b[4], b[5], b[6] },
                   cx = cx, cy = y, cz = cz, radius = math.max(w, d), colliders = {} }
    local box = { x0 + 0.5, y - 1, z0 + 0.5, x1 - 0.5, y + 0.6, z1 - 0.5, walk = true, noVehicle = true }
    G.world.colliders:add(box)
    G.world.addDObj(ruin)
end

function D.destroy(obj, hx, hy, hz)
    if not obj.alive then return end
    obj.alive = false
    local W = G.world
    local E = G.effects
    local cx, cy, cz = obj.cx, obj.cy, obj.cz
    local mat = dominantMat(obj)
    local size = obj.radius or 2
    if obj.kind == "vehicle" then
        -- burns out: keep the hulk, charred black, on fire for a while
        obj.ruin = true
        MB.tintRaw(obj.raw, 0.25)
        G.weapons.explode(cx, cy, cz, 6, 90, "world")
        W.emitters[#W.emitters + 1] = { x = cx, y = cy + 0.6, z = cz, kind = "fire", rate = 1, acc = 0, life = 90 }
        W.emitters[#W.emitters + 1] = { x = cx, y = cy + 1.2, z = cz, kind = "blacksmoke", rate = 1, acc = 0, life = 120 }
        W.staticLights[#W.staticLights + 1] = { x = cx, y = cy + 1.5, z = cz, r = 1, g = 0.5, b = 0.2, radius = 10, intensity = 1.4, flicker = true, life = 90 }
        W.fires[#W.fires + 1] = { x = cx, y = cy, z = cz, r = 5 }
        E.debris(cx, cy + 1, cz, mat, 10, 7, 0.35)
    else
        for _, b in ipairs(obj.colliders) do b.enabled = false end
        for _, d in ipairs(W.doors) do if d.obj == obj then d.box.enabled = false end end
        if obj.shelter then
            for i, s in ipairs(W.shelters) do if s == obj.shelter then table.remove(W.shelters, i) break end end
        end
        local n = math.floor(U.clamp(size * 4, 6, 40))
        E.debris(cx, cy, cz, mat, n, 4 + size, obj.kind == "building" and 0.7 or 0.4)
        -- dust cloud, bigger for buildings (rolling out low along the ground)
        local dust = obj.kind == "building" and 22 or 8
        for i = 1, dust do
            local a = math.random() * 6.28
            local r = math.random() * size * 0.5
            E.spawn(cx + math.cos(a) * r, cy - size * 0.2 + math.random() * size * 0.4, cz + math.sin(a) * r,
                math.cos(a) * (1 + math.random() * 3), 0.3 + math.random() * 1.2, math.sin(a) * (1 + math.random() * 3), 2.5 + math.random() * 3,
                0.8 + math.min(size, 10) * 0.08, 0.7 + math.min(size, 10) * 0.06, 0.5, 0.48, 0.45, 0.42, false, 0.9, -0.05)
        end
        for i = 1, 6 do E.snowPuff(cx + (math.random() - 0.5) * size, W.groundHeight(cx, cz), cz + (math.random() - 0.5) * size, 2) end
        if obj.kind == "building" then buildRuin(obj, mat) D.startCollapse(obj) end
        if obj.explode then
            G.weapons.explode(cx, cy, cz, 14, 320, "world")
            W.emitters[#W.emitters + 1] = { x = cx, y = cy, z = cz, kind = "fire", rate = 1, acc = 0, life = 120 }
            W.emitters[#W.emitters + 1] = { x = cx, y = cy + 1, z = cz, kind = "blacksmoke", rate = 1, acc = 0, life = 150 }
            W.staticLights[#W.staticLights + 1] = { x = cx, y = cy + 2, z = cz, r = 1, g = 0.5, b = 0.2, radius = 16, intensity = 2, flicker = true, life = 120 }
        end
    end
    if G.audio then G.audio.play(SOUND[obj.kind] or "wood_break", { x = cx, y = cy, z = cz, big = obj.kind == "building" or obj.kind == "vehicle" }) end
    if G.camera and obj.kind == "building" then
        local px, py, pz = G.player.feetWorld()
        local d = U.dist3(px, py, pz, cx, cy, cz)
        if d < 60 then G.camera.shake(0.6 * (1 - d / 60)) end
    end
    if G.humans then G.humans.noise(cx, cy, cz, obj.kind == "building" and 150 or 50) end
    W.rebuildChunkD(obj.chunk)
end

function D.damage(obj, amount, kind, hx, hy, hz)
    if not obj or not obj.alive then return false end
    local res = RES[obj.kind] or RES.wood
    local dmg = amount * (res[kind] or 1)
    obj.hp = obj.hp - dmg
    -- chips fly off on every hit
    if hx and dmg > 1 and kind ~= "ram" then
        G.effects.debris(hx, hy, hz, dominantMat(obj), kind == "bullet" and 2 or 6, kind == "bullet" and 3 or 6, kind == "bullet" and 0.12 or 0.25)
        G.effects.dust(hx, hy, hz)
    end
    if obj.hp <= 0 then
        D.destroy(obj, hx, hy, hz)
        return true
    end
    return false
end

function D.splash(x, y, z, radius, damage)
    for _, o in ipairs(G.world.dobjs) do
        if o.alive and o.cx then
            local d = U.dist3(x, y, z, o.cx, o.cy, o.cz) - (o.radius or 1) * 0.6
            if d < radius then D.damage(o, damage * U.clamp(1 - d / radius, 0.2, 1), "explosion", o.cx, o.cy, o.cz) end
        end
    end
end

-- the tank driving into something
function D.ram(obj, speed)
    if not obj.alive then return false end
    if obj.crush then
        if speed > 0.8 then D.destroy(obj) return true end
        return false
    end
    if speed > 4 then return D.damage(obj, speed * 30, "ram") end
    return false
end

---------------------------------------------------------------------------
-- trees: snapped by the tank or a blast, they topple as a rigid rod hinged at the stump. A tree
-- that comes down on the tank rests on it, is dragged along and slides off as the tank drives on.
---------------------------------------------------------------------------
-- top surface of the tank (hull space), nil outside its outline
local function tankTop(lx, lz)
    if lx < -4.05 or lx > 3.95 or lz < -2.05 or lz > 2.05 then return nil end
    local dx = lx - 0.35
    if dx * dx + lz * lz < 1.75 * 1.75 then return 3.55 end          -- turret
    if lx > 3.15 then return 1.65 end                                 -- glacis and front fenders
    if math.abs(lz) > 1.86 then return 1.65 end                       -- track guards
    return 2.45
end

local function rodPoint(f, k, th)
    local sn, cs = math.sin(th), math.cos(th)
    return f.bx + f.dx * f.L * k * sn, f.by + f.L * k * cs, f.bz + f.dz * f.L * k * sn
end

-- is any part of the trunk/crown inside the tank at tilt th?
local function hitsTank(f, th)
    local T = G.tank
    if T.destroyed then return false end
    for k = 0.2, 1.0, 0.1 do
        local x, y, z = rodPoint(f, k, th)
        local lx, ly, lz = T.frame:toLocal(x, y, z)
        local top = tankTop(lx, lz)
        if top and ly < top + (k > 0.5 and 0.35 or 0.15) and ly > -0.5 then return true end
    end
    return false
end

-- the angle at which the tree lies on the ground (a little past 90 degrees down a slope)
local function groundAngle(f)
    local W = G.world
    local tx, tz = f.bx + f.dx * f.L * 0.9, f.bz + f.dz * f.L * 0.9
    local gy = W.groundHeight(tx, tz) + 0.25 * f.t.s
    return math.acos(U.clamp((gy - f.by) / (f.L * 0.9), -0.6, 1))
end

local function snowFromCrown(f, n, th)
    local E = G.effects
    for i = 1, n do
        local x, y, z = rodPoint(f, 0.5 + math.random() * 0.5, th or f.th)
        E.snowPuff(x + (math.random() - 0.5) * 2, y, z + (math.random() - 0.5) * 2, 1.2 + math.random())
    end
end

-- knock tree record t over towards (dx, dz). w0: initial swing; quiet: no sound or snow (loading)
function D.knockTree(t, dx, dz, w0, quiet)
    if t.down then return false end
    local W = G.world
    if not W.setInstanceVisible(t.ch, t.kind, t.idx, false) then return false end   -- baked instances stay up
    t.down = true
    t.box.enabled = false
    local l = math.sqrt(dx * dx + dz * dz)
    if l < 1e-4 then dx, dz, l = 1, 0, 1 end
    local f = { t = t, bx = t.x, by = t.y + 0.35 * t.s, bz = t.z, dx = dx / l, dz = dz / l, th = 0.02, w = w0 or 0.2,
                L = 7 * t.s, vbx = 0, vbz = 0, state = "fall", restT = 0, m = {} }
    D.fallen[#D.fallen + 1] = f
    if not quiet then
        if G.audio then G.audio.play("tree_crack", { x = t.x, y = t.y + 1, z = t.z, volume = 0.9 }) end
        snowFromCrown(f, 8, 0)
        G.effects.debris(t.x, t.y + 0.6, t.z, "wood", 5, 3, 0.2)
        if G.humans then G.humans.noise(t.x, t.y, t.z, 40) end
    end
    return true
end

-- the tank runs into a tree collider; returns true when it broke (the tank drives on)
function D.ramTree(box, speed, fx, fz, dt)
    local t = box.treeRec
    if not t or t.down then return false end
    local sp = math.abs(speed)
    local tough = (t.kind == "birch" or t.kind == "deadtree") and 0.6 or 1.0
    tough = tough * t.s
    t.push = (t.push or 0) + dt * sp
    local sgn = speed >= 0 and 1 or -1
    local T = G.tank
    if sp > 3.2 * tough then
        -- a hard hit snaps the trunk: the butt is kicked forward and the crown comes down backwards,
        -- onto the tank if it keeps going
        local a = math.atan2(-fz * sgn, -fx * sgn) + (math.random() - 0.5) * 1.1
        if D.knockTree(t, math.cos(a), math.sin(a), 0.35 + sp * 0.05) then
            local f = D.fallen[#D.fallen]
            f.vbx, f.vbz = fx * speed * 0.85, fz * speed * 0.85
            T.speed = T.speed * 0.8
            if G.camera and G.player.frameName == "tank" then G.camera.shake(0.35) end
            return true
        end
    elseif sp > 0.4 and t.push > 1.6 * tough then
        -- pushed slowly, it leans away and goes over in front of the tank
        local a = math.atan2(fz * sgn, fx * sgn) + (math.random() - 0.5) * 0.8
        if D.knockTree(t, math.cos(a), math.sin(a), 0.12) then
            T.speed = T.speed * 0.9
            return true
        end
    end
    return false
end

-- trees in a blast fall away from it
function D.blastTrees(x, y, z, radius)
    local W = G.world
    for _, b in ipairs(W.colliders:query(x - radius, z - radius, x + radius, z + radius, {})) do
        local t = b.treeRec
        if t and not t.down then
            local d = U.dist2(x, z, t.x, t.z)
            if d < radius * 0.7 and math.abs(y - t.y) < 6 then
                D.knockTree(t, t.x - x, t.z - z, 0.4 + (1 - d / radius) * 1.2)
            end
        end
    end
end

local function landThud(f, onTank)
    local x, y, z = rodPoint(f, 0.7, f.th)
    if G.audio then G.audio.play(onTank and "tree_on_tank" or "impact_snow", { x = x, y = y, z = z, volume = 0.6 + math.min(0.4, f.w * 0.3) }) end
    snowFromCrown(f, onTank and 10 or 6)
    local pd = U.dist2(G.player.x, G.player.z, x, z)
    if onTank then
        local S = G.snow
        if S then
            S.cover.hull = math.min(1, S.cover.hull + 0.2)
            S.cover.turret = math.min(1, S.cover.turret + 0.25)
            S.cover.deck = math.min(1, S.cover.deck + 0.12)
        end
        if G.camera and G.player.frameName == "tank" then G.camera.shake(0.45) end
        G.tank.pitchVel = (G.tank.pitchVel or 0) - 0.25
    elseif G.camera and pd < 25 and G.player.frameName == "world" then
        G.camera.shake(0.2 * (1 - pd / 25))
    end
end

-- a tree lying across a moving tank: carried along in hull space, shaken back bit by bit, dropped
-- when its middle is no longer over the tank
local RIDE_TH = 1.42
local function startRiding(f)
    local T = G.tank
    local cx, cy, cz = rodPoint(f, 0.45, f.th)
    local lx, _, lz = T.frame:toLocal(cx, cy, cz)
    lx, lz = U.clamp(lx, -3.2, 2.8), U.clamp(lz, -1.6, 1.6)
    local ldx, _, ldz = T.frame:dirToLocal(f.dx, 0, f.dz)
    local l = math.sqrt(ldx * ldx + ldz * ldz)
    if l < 1e-4 then ldx, ldz, l = -1, 0, 1 end
    f.ride = { lx = lx, lz = lz, dx = ldx / l, dz = ldz / l, vx = 0, vz = 0, last = T.speed }
    f.state = "ride"
end

local function updateRiding(f, dt)
    local T = G.tank
    local o = f.ride
    -- inertia when the tank speeds up or brakes, a slow creep backwards as it drives out from under,
    -- and a slew in turns
    o.vx = o.vx - (T.speed - o.last) * 0.45
    o.last = T.speed
    o.vx = o.vx * math.exp(-1.5 * dt)
    o.vz = (o.vz + (T.yawRate or 0) * math.abs(T.speed) * 0.25 * dt) * math.exp(-1.5 * dt)
    o.lx = o.lx + (o.vx - math.abs(T.speed) * 0.13) * dt
    o.lz = o.lz + o.vz * dt
    local top = tankTop(o.lx, o.lz)
    local sn, cs = math.sin(RIDE_TH), math.cos(RIDE_TH)
    local half = f.L * 0.45
    local bxl, byl, bzl = o.lx - o.dx * half * sn, (top or 2.4) + 0.25 * f.t.s - half * cs, o.lz - o.dz * half * sn
    f.bx, f.by, f.bz = T.frame:toWorld(bxl, byl, bzl)
    local wx, _, wz = T.frame:dirToWorld(o.dx, 0, o.dz)
    local l = math.sqrt(wx * wx + wz * wz)
    f.dx, f.dz, f.th = wx / l, wz / l, RIDE_TH
    if not top or T.destroyed then
        -- slides off: drops with the tank's speed and settles on the ground
        local c, s = math.cos(T.yaw), math.sin(T.yaw)
        f.vbx, f.vbz, f.vy = c * T.speed * 0.7, s * T.speed * 0.7, 0
        f.ride, f.state = nil, "drop"
        if G.audio then G.audio.play("wood_break", { x = f.bx, y = f.by, z = f.bz, volume = 0.5 }) end
    end
end

local function updateDrop(f, dt)
    local W = G.world
    f.vy = f.vy - 9.8 * dt
    f.bx, f.by, f.bz = f.bx + f.vbx * dt, f.by + f.vy * dt, f.bz + f.vbz * dt
    f.th = U.damp(f.th, groundAngle(f), 3, dt)
    local gy = W.groundHeight(f.bx, f.bz) + 0.12 * f.t.s
    if f.by <= gy then
        f.by = gy
        f.w = 0
        f.state = "fall"
        landThud(f, false)
    end
end

local function updateFallen(f, dt)
    local W = G.world
    local T = G.tank
    -- the stump end slides: kicked by the tank, braked by the ground
    f.bx, f.bz = f.bx + f.vbx * dt, f.bz + f.vbz * dt
    local fr = math.exp(-(f.onTank and 1.5 or 3.5) * dt)
    f.vbx, f.vbz = f.vbx * fr, f.vbz * fr
    f.by = U.damp(f.by, W.groundHeight(f.bx, f.bz) + 0.12 * f.t.s, 6, dt)
    -- the tank bulldozes the butt end out of its way
    local lx, ly, lz = T.frame:toLocal(f.bx, f.by, f.bz)
    if tankTop(lx, lz) and ly < 2.5 then
        if lx > 0 then lx = 4.0 else lx = -4.1 end
        f.bx, f.by, f.bz = T.frame:toWorld(lx, ly, lz)
        local c, s = math.cos(T.yaw), math.sin(T.yaw)
        f.vbx, f.vbz = c * T.speed, s * T.speed
    end
    -- topple: a uniform rod pivoting on its end
    f.w = f.w + 1.5 * 9.8 / f.L * math.sin(f.th) * dt
    local th = f.th + f.w * dt
    local gth = groundAngle(f)
    f.restTh = gth
    local wasOnTank = f.onTank
    f.onTank = false
    if math.abs(T.x - f.bx) < f.L + 6 and math.abs(T.z - f.bz) < f.L + 6 and hitsTank(f, th) then
        -- find the angle where it just rests on the tank
        local lo, hi = 0, th
        if not hitsTank(f, f.th) then lo = f.th end
        for _ = 1, 8 do
            local mid = (lo + hi) / 2
            if hitsTank(f, mid) then hi = mid else lo = mid end
        end
        th = lo
        if not wasOnTank and f.w > 0.5 then landThud(f, true) end
        f.w = 0
        f.onTank = true
        -- coming down on a tank that is on the move: it ends up lying across the hull
        if math.abs(T.speed) > 1.5 then startRiding(f) return end
        -- friction drags it along with the tank
        local c, s = math.cos(T.yaw), math.sin(T.yaw)
        local k = 1 - math.exp(-2.5 * dt)
        f.vbx, f.vbz = f.vbx + (c * T.speed * 0.8 - f.vbx) * k, f.vbz + (s * T.speed * 0.8 - f.vbz) * k
    end
    if th >= gth then
        th = gth
        if f.w > 0.6 then landThud(f, false) f.w = -f.w * 0.12
        else f.w = 0 end
    end
    f.th = th
    if not f.onTank and th >= gth - 0.01 and math.abs(f.w) < 0.05 and math.abs(f.vbx) + math.abs(f.vbz) < 0.05 then
        f.restT = f.restT + dt
        if f.restT > 0.5 then f.state = "rest" end
    else
        f.restT = 0
    end
end

-- a log the tank drives over: wake it so the tank can push it about
local function nudgeRested(f)
    local T = G.tank
    if math.abs(T.speed) < 0.5 then return end
    local x, y, z = rodPoint(f, 0.5, f.th)
    if math.abs(T.x - x) < f.L * 0.5 + 4 and math.abs(T.z - z) < f.L * 0.5 + 4 then
        local lx, _, lz = T.frame:toLocal(f.bx, f.by, f.bz)
        if tankTop(lx, lz) then f.state = "fall" f.restT = 0 end
    end
end

---------------------------------------------------------------------------
-- buildings sink into their own rubble in a cloud of dust instead of vanishing
---------------------------------------------------------------------------
function D.startCollapse(obj)
    if not obj.raw then return end
    local b = obj.bounds
    local h = b and (b[5] - b[2]) or 6
    D.collapsing[#D.collapsing + 1] = { model = MB.mergeRaw({ obj.raw }), t = 0, dur = 1.6 + math.min(2.5, h * 0.15), mat = dominantMat(obj),
        cx = obj.cx, cz = obj.cz, by = b and b[2] or obj.cy, h = h, r = obj.radius or 4,
        ax = math.random() - 0.5, az = math.random() - 0.5, m = {} }
end

local function updateCollapse(c, dt)
    c.t = c.t + dt
    local E = G.effects
    if math.random() < dt * 14 then
        local a = math.random() * 6.28
        local r = math.min(c.r, 12) * (0.3 + math.random() * 0.5)
        E.spawn(c.cx + math.cos(a) * r, c.by + math.random() * c.h * (1 - c.t / c.dur), c.cz + math.sin(a) * r,
            math.cos(a) * 1.5, 0.4 + math.random(), math.sin(a) * 1.5, 2.5 + math.random() * 2, 0.9 + math.min(c.r, 12) * 0.06, 0.8,
            0.5, 0.48, 0.45, 0.38, false, 0.9, -0.05)
    end
    -- chunks breaking off as it goes down
    if math.random() < dt * 4 then
        local a = math.random() * 6.28
        G.effects.debris(c.cx + math.cos(a) * c.r * 0.4, c.by + c.h * (1 - c.t / c.dur) * 0.8, c.cz + math.sin(a) * c.r * 0.4, c.mat or "rubble", 2, 3, 0.35)
    end
end

function D.update(dt)
    for i = #D.fallen, 1, -1 do
        local f = D.fallen[i]
        if f.state == "rest" then nudgeRested(f)
        elseif f.state == "ride" then updateRiding(f, dt)
        elseif f.state == "drop" then updateDrop(f, dt)
        else updateFallen(f, dt) end
    end
    for i = #D.collapsing, 1, -1 do
        local c = D.collapsing[i]
        updateCollapse(c, dt)
        if c.t >= c.dur then table.remove(D.collapsing, i) end
    end
end

-- rotation taking +y towards (dx, 0, dz) by th, times the tree's own yaw (instancing convention)
local function treeMatrix(f, m)
    local th, dx, dz = f.th, f.dx, f.dz
    local c, s = math.cos(th), math.sin(th)
    local kx, kz = dz, -dx                          -- axis = up x dir
    local t1 = 1 - c
    local r11, r12, r13 = c + kx * kx * t1, -kz * s, kx * kz * t1
    local r21, r22, r23 = kz * s, c, -kx * s
    local r31, r32, r33 = kz * kx * t1, kx * s, c + kz * kz * t1
    local cy, sy = math.cos(f.t.yaw), math.sin(f.t.yaw)
    local sc = f.t.s
    -- R_tilt * R_yaw(x' = c x - s z, z' = s x + c z) * scale
    m[1], m[2], m[3], m[4] = (r11 * cy + r13 * sy) * sc, r12 * sc, (-r11 * sy + r13 * cy) * sc, f.bx
    m[5], m[6], m[7], m[8] = (r21 * cy + r23 * sy) * sc, r22 * sc, (-r21 * sy + r23 * cy) * sc, f.by - 0.3 * sc
    m[9], m[10], m[11], m[12] = (r31 * cy + r33 * sy) * sc, r32 * sc, (-r31 * sy + r33 * cy) * sc, f.bz
    m[13], m[14], m[15], m[16] = 0, 0, 0, 1
    return m
end

function D.draw()
    local W = G.world
    local cam = R.cam
    local models = W.instModels
    if not models then return end
    for _, f in ipairs(D.fallen) do
        local t = f.t
        if math.abs(t.x - cam.x) < 260 and math.abs(t.z - cam.z) < 260 then
            local model = models[t.kind]
            local x, y, z = rodPoint(f, 0.5, f.th)
            if model and R.visible(x, y, z, f.L * 0.6) then
                f.tint = f.tint or { t.tint, t.tint, t.tint, 1 }
                f.params = f.params or { tint = f.tint }
                R.drawModel(model, treeMatrix(f, f.m), f.params)
            end
            -- the snapped stump stays where the tree stood
            if models.stump and R.visible(t.x, t.y, t.z, 1) then
                f.sm = f.sm or { 0.8 * t.s, 0, 0, t.x, 0, 0.75 * t.s, 0, t.y, 0, 0, 0.8 * t.s, t.z, 0, 0, 0, 1 }
                R.drawModel(models.stump, f.sm)
            end
        end
    end
    for _, c in ipairs(D.collapsing) do
        local k = c.t / c.dur
        local e = k * k * (3 - 2 * k)
        local drop = -c.h * 0.85 * e
        local tilt = e * 0.12
        local m = c.m
        -- a small lean towards (ax, az) about the base centre, then the sink
        local ax, az = c.ax * tilt, c.az * tilt
        m[1], m[2], m[3] = 1, ax, 0
        m[5], m[6], m[7] = -ax, 1, -az
        m[9], m[10], m[11] = 0, az, 1
        m[4] = -(m[1] * c.cx + m[2] * c.by + m[3] * c.cz) + c.cx
        m[8] = -(m[5] * c.cx + m[6] * c.by + m[7] * c.cz) + c.by + drop
        m[12] = -(m[9] * c.cx + m[10] * c.by + m[11] * c.cz) + c.cz
        m[13], m[14], m[15], m[16] = 0, 0, 0, 1
        R.drawModel(c.model, m)
    end
end

return D
