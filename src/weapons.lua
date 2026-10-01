-- Projectiles (tank shells), hitscan bullets, explosions and the player's personal firearms.
local U = require("src.utils")
local P = require("src.physics")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")

local Wp = {}
local G

-- Personal firearms. Each weapon is a set of model parts (body, magazine, bolt) plus arms,
-- animated procedurally: sway, bob, recoil, bolt cycling, reloads, sprinting and aiming down sights.
Wp.DEFS = {
    rifle = { name = "KARABINER 98K", ammo = "rifle_ammo", mag = 5, damage = 85, interval = 1.05, reload = 2.8, spread = 0.0015,
              hipSpread = 0.02, noise = 130, kick = 0.055, sound = "rifle", fov = 42, auto = false, bolt = true,
              hip = { 0.15, -0.155, 0.36 }, ads = { 0.0, -0.064, 0.21 }, casing = 0.35 },
    smg = { name = "PPSH-41", ammo = "pistol_ammo", mag = 71, damage = 19, interval = 60 / 900, reload = 3.0, spread = 0.009,
            hipSpread = 0.035, noise = 110, kick = 0.012, sound = "smg", fov = 58, auto = true,
            hip = { 0.14, -0.15, 0.32 }, ads = { 0.0, -0.074, 0.25 }, casing = 0 },
    pistol = { name = "TT-33 PISTOL", ammo = "pistol_ammo", mag = 8, damage = 32, interval = 0.18, reload = 1.6, spread = 0.006,
               hipSpread = 0.02, noise = 80, kick = 0.03, sound = "pistol", fov = 62, auto = false,
               hip = { 0.13, -0.13, 0.3 }, ads = { 0.0, -0.06, 0.34 }, casing = 0 },
}
Wp.ORDER = { "rifle", "smg", "pistol" }

-- shared arm geometry (sleeve + glove) from a shoulder point to a hand point
local function arm(mb, sx, sy, sz, hx, hy, hz, thick)
    local function beam(ax, ay, az, bx, by, bz, t, mat, r, g, b)
        mb:material(mat):color(r, g, b)
        local dx, dy, dz = bx - ax, by - ay, bz - az
        local l = math.sqrt(dx * dx + dy * dy + dz * dz)
        dx, dy, dz = dx / l, dy / l, dz / l
        local px, py, pz = U.norm3(U.cross(dx, dy, dz, 0, 1, 0))
        if px ~= px or (px == 0 and py == 0 and pz == 0) then px, py, pz = 0, 0, 1 end
        local qx, qy, qz = U.cross(px, py, pz, dx, dy, dz)
        local function c(x, y, z, s1, s2) return { x + px * s1 + qx * s2, y + py * s1 + qy * s2, z + pz * s1 + qz * s2 } end
        local h = t / 2
        mb:hexa({ c(ax, ay, az, -h, -h), c(ax, ay, az, h, -h), c(ax, ay, az, h, h), c(ax, ay, az, -h, h),
                  c(bx, by, bz, -h * 0.85, -h * 0.85), c(bx, by, bz, h * 0.85, -h * 0.85), c(bx, by, bz, h * 0.85, h * 0.85), c(bx, by, bz, -h * 0.85, h * 0.85) })
    end
    -- sleeve to the wrist, then the glove
    local wx, wy, wz = U.lerp(sx, hx, 0.82), U.lerp(sy, hy, 0.82), U.lerp(sz, hz, 0.82)
    beam(sx, sy, sz, wx, wy, wz, thick, "cloth", 0.5, 0.48, 0.4)
    beam(wx, wy, wz, hx, hy, hz, thick * 0.7, "fur", 0.32, 0.28, 0.24)
    mb:material("fur"):color(0.3, 0.26, 0.22)
    mb:boxC(hx, hy, hz, thick * 0.9, thick * 0.75, thick * 0.9)
end

local function buildRifle()
    local p = {}
    local mb = MB.new(201)
    mb.texScale = 3
    -- stock with pistol grip and butt
    mb:material("wood"):color(0.85, 0.62, 0.42)
    mb:hexa({ { -0.78, -0.13, -0.022 }, { -0.5, -0.05, -0.022 }, { -0.5, -0.05, 0.022 }, { -0.78, -0.13, 0.022 },
              { -0.78, 0.0, -0.024 }, { -0.5, 0.012, -0.024 }, { -0.5, 0.012, 0.024 }, { -0.78, 0.0, 0.024 } })
    mb:hexa({ { -0.5, -0.07, -0.022 }, { -0.3, -0.05, -0.022 }, { -0.3, -0.05, 0.022 }, { -0.5, -0.07, 0.022 },
              { -0.5, 0.012, -0.022 }, { -0.3, 0.012, -0.022 }, { -0.3, 0.012, 0.022 }, { -0.5, 0.012, 0.022 } })
    mb:box(-0.3, -0.045, -0.024, 0.32, 0.012, 0.024)       -- fore stock
    mb:box(0.32, -0.03, -0.019, 0.42, 0.01, 0.019)         -- nose
    mb:material("metal"):color(0.25, 0.24, 0.24)
    mb:box(-0.82, -0.14, -0.026, -0.78, 0.005, 0.026)      -- butt plate
    mb:box(0.06, -0.05, -0.026, 0.09, 0.016, 0.026)        -- barrel bands
    mb:box(0.3, -0.035, -0.022, 0.33, 0.016, 0.022)
    mb:material("steel"):color(0.45, 0.45, 0.47)
    mb:cylinderX(-0.05, 0.66, 0.026, 0, 0.0115, 0.0095, 6) -- barrel
    mb:box(-0.32, 0.008, -0.017, -0.04, 0.03, 0.017)       -- receiver
    mb:box(-0.07, 0.03, -0.007, -0.02, 0.052, 0.007)       -- rear sight base (tangent leaf)
    mb:box(-0.05, 0.052, -0.009, -0.04, 0.066, -0.0025)    -- rear sight notch walls
    mb:box(-0.05, 0.052, 0.0025, -0.04, 0.066, 0.009)
    mb:box(0.6, 0.03, -0.007, 0.65, 0.046, 0.007)          -- front sight base
    mb:box(0.62, 0.046, -0.0018, 0.635, 0.066, 0.0018)     -- front post
    mb:box(-0.22, -0.06, -0.008, -0.12, -0.045, 0.008)     -- trigger guard
    mb:material("metal"):color(0.2, 0.2, 0.2)
    mb:box(-0.18, -0.045, -0.003, -0.165, -0.015, 0.003)   -- trigger
    -- arms holding the rifle
    arm(mb, -0.35, -0.22, 0.2, -0.24, -0.04, 0.0, 0.07)      -- right hand on the grip
    arm(mb, -0.15, -0.3, -0.22, 0.16, -0.05, -0.012, 0.065)  -- left hand under the fore stock
    p.body = mb:build()
    mb = MB.new(202)
    mb:material("steel"):color(0.5, 0.5, 0.52)
    mb:cylinderX(-0.27, -0.12, 0.026, 0.0, 0.007, 0.007, 5)
    mb:box(-0.17, 0.02, 0.006, -0.155, 0.032, 0.05)        -- bolt handle
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:sphere(-0.162, 0.026, 0.052, 0.011, 0.011, 0.011, 5, 3)
    p.bolt = mb:build()
    mb = MB.new(203)
    mb:material("brass"):color(1, 1, 1)
    for i = 0, 4 do mb:cylinderX(-0.13, -0.07, 0.042, -0.012 + i * 0.006, 0.003, 0.003, 4) end
    p.mag = mb:build()   -- stripper clip shown during reloads
    p.boltPivot = { -0.2, 0.036, 0 }
    p.muzzle = { 0.68, 0.026, 0 }
    return p
end

local function buildSMG()
    local p = {}
    local mb = MB.new(211)
    mb.texScale = 3
    mb:material("wood"):color(0.8, 0.55, 0.36)
    mb:hexa({ { -0.62, -0.12, -0.024 }, { -0.33, -0.05, -0.024 }, { -0.33, -0.05, 0.024 }, { -0.62, -0.12, 0.024 },
              { -0.62, 0.005, -0.026 }, { -0.3, 0.015, -0.026 }, { -0.3, 0.015, 0.026 }, { -0.62, 0.005, 0.026 } })
    mb:box(-0.33, -0.06, -0.024, -0.05, 0.018, 0.024)
    mb:material("metal"):color(0.24, 0.24, 0.25)
    mb:box(-0.63, -0.125, -0.027, -0.6, 0.008, 0.027)
    mb:material("steel"):color(0.4, 0.4, 0.42)
    mb:box(-0.3, 0.015, -0.022, -0.02, 0.048, 0.022)       -- receiver
    mb:cylinderX(-0.02, 0.27, 0.03, 0, 0.026, 0.026, 8)    -- ventilated barrel shroud
    mb:material("grille"):color(0.8, 0.8, 0.8)
    mb:cylinderX(0.0, 0.25, 0.03, 0, 0.0265, 0.0265, 8, false)
    mb:material("steel"):color(0.45, 0.45, 0.46)
    mb:cylinderX(0.26, 0.32, 0.03, 0, 0.012, 0.012, 6)     -- muzzle brake
    mb:box(0.265, 0.03, -0.024, 0.295, 0.058, 0.024)
    mb:box(-0.12, 0.048, -0.008, -0.09, 0.064, 0.008)      -- rear sight block
    mb:box(-0.11, 0.064, -0.008, -0.1, 0.076, -0.0025)     -- notch walls
    mb:box(-0.11, 0.064, 0.0025, -0.1, 0.076, 0.008)
    mb:box(0.235, 0.05, -0.006, 0.26, 0.062, 0.006)        -- front sight base
    mb:box(0.24, 0.062, -0.0018, 0.255, 0.076, 0.0018)     -- front post
    mb:box(-0.27, -0.05, -0.008, -0.17, -0.035, 0.008)     -- trigger guard
    arm(mb, -0.36, -0.22, 0.2, -0.26, -0.03, 0.0, 0.07)
    arm(mb, -0.2, -0.3, -0.24, -0.04, -0.12, -0.04, 0.065) -- left hand on the drum
    p.body = mb:build()
    mb = MB.new(212)
    mb:material("metal"):color(0.3, 0.3, 0.31)
    mb:cylinderZ(-0.03, 0.03, -0.11, -0.1, 0.085, 10)       -- drum magazine
    mb:material("steel"):color(0.45, 0.45, 0.45)
    mb:cylinderZ(-0.032, 0.032, -0.11, -0.1, 0.03, 8)
    p.mag = mb:build()
    mb = MB.new(213)
    mb:material("steel"):color(0.5, 0.5, 0.5)
    mb:box(-0.18, 0.02, 0.022, -0.15, 0.04, 0.034)         -- cocking handle
    p.bolt = mb:build()
    p.muzzle = { 0.33, 0.03, 0 }
    return p
end

local function buildPistol()
    local p = {}
    local mb = MB.new(221)
    mb.texScale = 4
    mb:material("steel"):color(0.38, 0.38, 0.4)
    mb:box(-0.08, 0.0, -0.013, 0.1, 0.03, 0.013)           -- frame
    mb:material("metal"):color(0.28, 0.28, 0.3)
    mb:box(-0.035, -0.085, -0.014, 0.0, 0.0, 0.014)        -- grip front
    mb:material("fur"):color(0.35, 0.25, 0.2)
    mb:hexa({ { -0.07, -0.1, -0.015 }, { -0.03, -0.1, -0.015 }, { -0.03, -0.1, 0.015 }, { -0.07, -0.1, 0.015 },
              { -0.06, 0.0, -0.015 }, { -0.005, 0.0, -0.015 }, { -0.005, 0.0, 0.015 }, { -0.06, 0.0, 0.015 } })
    mb:material("metal"):color(0.25, 0.25, 0.25)
    mb:box(-0.02, -0.03, -0.006, 0.02, -0.02, 0.006)
    arm(mb, -0.3, -0.25, 0.16, -0.05, -0.06, 0.0, 0.07)
    arm(mb, -0.25, -0.3, -0.14, -0.045, -0.075, -0.02, 0.065)
    p.body = mb:build()
    mb = MB.new(222)
    mb:material("steel"):color(0.45, 0.45, 0.47)
    mb:box(-0.08, 0.03, -0.014, 0.105, 0.056, 0.014)       -- slide
    mb:box(-0.075, 0.056, -0.006, -0.065, 0.063, -0.002)
    mb:box(-0.075, 0.056, 0.002, -0.065, 0.063, 0.006)
    mb:box(0.09, 0.056, -0.0015, 0.1, 0.064, 0.0015)
    p.bolt = mb:build()
    mb = MB.new(223)
    mb:material("metal"):color(0.3, 0.3, 0.32)
    mb:box(-0.06, -0.11, -0.011, -0.02, -0.02, 0.011)
    p.mag = mb:build()
    p.muzzle = { 0.11, 0.043, 0 }
    return p
end

function Wp.init(game)
    G = game
    Wp.projectiles = {}
    Wp.models = { rifle = buildRifle(), smg = buildSMG(), pistol = buildPistol() }
    Wp.mats = { {}, {}, {} }
    Wp.reset()
end

function Wp.reset()
    Wp.current = "rifle"
    Wp.mag = { rifle = 5, smg = 71, pistol = 8 }
    Wp.cool = 0
    Wp.reloadT = 0
    Wp.kick, Wp.kickRot, Wp.kickSide = 0, 0, 0
    Wp.aiming = false
    Wp.aimT = 0
    Wp.swayX, Wp.swayY = 0, 0
    Wp.lookX, Wp.lookY = 0, 0
    Wp.holster = 0
    Wp.boltT = 0
    Wp.sprintT = 0
    Wp.switchT = 0
    Wp.hitT = 0
    Wp.burst = 0
    Wp.projectiles = {}
end

function Wp.serialize() return { current = Wp.current, mag = U.copy(Wp.mag) } end
function Wp.load(s)
    if s then
        Wp.current = Wp.DEFS[s.current] and s.current or "rifle"
        for k, v in pairs(s.mag or {}) do if Wp.mag[k] then Wp.mag[k] = v end end
    end
end

---------------------------------------------------------------------------
-- hit resolution helpers
---------------------------------------------------------------------------
-- returns t, kind, object, nx,ny,nz
local function traceAll(ox, oy, oz, dx, dy, dz, maxT, owner)
    local W = G.world
    local bestT, kind, obj, nx, ny, nz = maxT, nil, nil, 0, 1, 0
    local sets = { W.staticSet }
    local t, a, b, c, box = P.raycast(sets, ox, oy, oz, dx, dy, dz, bestT)
    if t and t < bestT then bestT, kind, obj, nx, ny, nz = t, "world", box, a, b, c end
    if not W.isUnderground(ox, oy, oz) then
        local tt = W.rayTerrain(ox, oy, oz, dx, dy, dz, math.min(bestT, 450))
        if tt and tt < bestT then bestT, kind, obj = tt, "terrain", nil nx, ny, nz = W.normal(ox + dx * tt, oz + dz * tt) end
    end
    -- the player's own tank (its own guns fire from outside the hull and skip it)
    if owner ~= "player" then
        local T = G.tank
        local t2, a2, b2, c2, box2 = P.raycast({ T.extSet, T.turretExtSet, T.gunExtSet }, ox, oy, oz, dx, dy, dz, bestT)
        if t2 and t2 < bestT then bestT, kind, obj, nx, ny, nz = t2, "playertank", box2, a2, b2, c2 end
        -- the player on foot
        if owner ~= "foot" and owner ~= "npc" and G.player.frameName == "world" and G.player.mode ~= "dead" then
            local px, py, pz = G.player.x, G.player.y + 0.9, G.player.z
            local t3 = P.raySphere(ox, oy, oz, dx, dy, dz, px, py, pz, 0.55)
            if t3 and t3 < bestT then bestT, kind, obj = t3, "player", nil end
        end
    end
    if G.enemies then
        local t4, e, hx, hy, hz = G.enemies.raycast(ox, oy, oz, dx, dy, dz, bestT)
        if t4 and t4 < bestT then bestT, kind, obj, nx, ny, nz = t4, "enemytank", e, hx, hy, hz end
    end
    if G.creatures then
        local t5, cr, part = G.creatures.raycast(ox, oy, oz, dx, dy, dz, bestT)
        if t5 and t5 < bestT then bestT, kind, obj = t5, "creature", { c = cr, part = part } end
    end
    if G.humans then
        local t6, hu, part = G.humans.raycast(ox, oy, oz, dx, dy, dz, bestT)
        if t6 and t6 < bestT then bestT, kind, obj = t6, "human", { h = hu, part = part } end
    end
    if kind then return bestT, kind, obj, nx, ny, nz end
    return nil
end
Wp.traceAll = traceAll

function Wp.hitscan(ox, oy, oz, dx, dy, dz, range, damage, kind, tracer)
    local owner = (kind == "enemy" or kind == "foot" or kind == "npc") and kind or "player"
    local t, what, obj, nx, ny, nz = traceAll(ox, oy, oz, dx, dy, dz, range, owner)
    local hx, hy, hz = ox + dx * (t or range), oy + dy * (t or range), oz + dz * (t or range)
    if tracer then G.effects.tracer(ox + dx * 2, oy + dy * 2, oz + dz * 2, dx, dy, dz, 420, math.min(0.35, (t or range) / 420)) end
    if not t then return end
    if what == "creature" then
        local mult = obj.part == "head" and 2.0 or 1
        G.creatures.damage(obj.c, damage * mult, hx, hy, hz, dx, dz)
        G.effects.blood(hx, hy, hz, 5)
        if G.audio then G.audio.play("flesh", { x = hx, y = hy, z = hz, volume = 0.6 }) end
    elseif what == "human" then
        local mult = obj.part == "head" and 2.5 or 1
        G.humans.damage(obj.h, damage * mult, owner == "foot" or owner == "player")
        G.effects.blood(hx, hy, hz, 6)
        if G.audio then G.audio.play("flesh", { x = hx, y = hy, z = hz, volume = 0.6 }) end
    elseif what == "enemytank" or what == "playertank" then
        G.effects.sparks(hx, hy, hz, nx, ny, nz, 5)
        if G.audio then G.audio.play("ricochet", { x = hx, y = hy, z = hz, volume = 0.6 }) end
        if what == "enemytank" then G.enemies.alert(obj, ox, oz) end
    elseif what == "player" then
        G.player.hurt(damage * 0.6, "shot")
    elseif what == "terrain" then
        G.effects.impactSnow(hx, hy, hz)
        if G.audio then G.audio.play("impact_snow", { x = hx, y = hy, z = hz, volume = 0.5 }) end
    else
        G.effects.dust(hx, hy, hz)
        if obj and (obj.door or math.random() < 0.4) then G.effects.sparks(hx, hy, hz, nx, ny, nz, 3) end
        if G.audio then G.audio.play("impact_hard", { x = hx, y = hy, z = hz, volume = 0.5 }) end
    end
    return t, what
end

---------------------------------------------------------------------------
-- shells
---------------------------------------------------------------------------
function Wp.fireShell(kind, x, y, z, dx, dy, dz, owner)
    local speed = kind == "AP" and 760 or 560
    Wp.projectiles[#Wp.projectiles + 1] = { x = x, y = y, z = z, vx = dx * speed, vy = dy * speed, vz = dz * speed,
                                            kind = kind, owner = owner, life = 4 }
end

function Wp.explode(x, y, z, radius, damage, owner, skipObj)
    G.effects.explosion(x, y, z, radius / 8)
    if G.audio then G.audio.play("explosion", { x = x, y = y, z = z, big = radius > 6 }) end
    if G.creatures then
        G.creatures.noise(x, y, z, 350, "explosion")
        G.creatures.splash(x, y, z, radius, damage)
    end
    -- player on foot
    local pl = G.player
    if pl.frameName == "world" and pl.mode ~= "dead" then
        local d = U.dist3(x, y, z, pl.x, pl.y + 0.9, pl.z)
        if d < radius then pl.hurt(damage * 0.5 * (1 - d / radius), "explosion") end
        if d < radius * 3 then G.camera.shake(1 - d / (radius * 3)) end
    end
    -- splash against tanks (light)
    local T = G.tank
    local dT = U.dist3(x, y, z, T.x, T.y + 1.2, T.z)
    if dT < radius * 0.8 and skipObj ~= T then
        local lx, ly, lz = T.frame:toLocal(x, y, z)
        T.damage(damage * 0.08 * (1 - dT / radius), "splash", lx, ly, lz)
    end
    if G.enemies then G.enemies.splash(x, y, z, radius, damage, skipObj) end
    if G.humans then G.humans.splash(x, y, z, radius, damage) end
end

function Wp.updateProjectiles(dt)
    local list = Wp.projectiles
    for i = #list, 1, -1 do
        local p = list[i]
        p.life = p.life - dt
        local ox, oy, oz = p.x, p.y, p.z
        p.vy = p.vy - 9.8 * dt
        local nx, ny, nz = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
        local dx, dy, dz, len = U.norm3(nx - ox, ny - oy, nz - oz)
        local t, what, obj, hnx, hny, hnz = traceAll(ox, oy, oz, dx, dy, dz, len, p.owner)
        -- glowing tracer
        if math.random() < 0.7 then
            local tr = G.effects.spawn(ox, oy, oz, p.vx * 0.02, p.vy * 0.02, p.vz * 0.02, 0.12, 0.12, 0, 1, 0.75, 0.4, 1, true)
        end
        if t then
            local hx, hy, hz = ox + dx * t, oy + dy * t, oz + dz * t
            Wp.shellImpact(p, hx, hy, hz, what, obj, hnx or 0, hny or 1, hnz or 0, dx, dy, dz)
            table.remove(list, i)
        elseif p.life <= 0 then
            table.remove(list, i)
        else
            p.x, p.y, p.z = nx, ny, nz
        end
    end
end

function Wp.shellImpact(p, x, y, z, what, obj, nx, ny, nz, dx, dy, dz)
    if Wp.debug then print("[shell]", p.owner, p.kind, "hit", what, x, y, z, obj and (obj.tree and "tree" or "") or "") end
    local he = p.kind == "HE"
    if what == "enemytank" then
        local dmg = he and 22 or 70
        G.enemies.hit(obj, dmg, x, y, z, dx, dz, p.kind)
        G.effects.sparks(x, y, z, nx, ny, nz, 14)
        Wp.explode(x, y, z, he and 9 or 4, he and 160 or 60, p.owner, obj)
        if G.audio then G.audio.play("armor_hit", { x = x, y = y, z = z, big = true }) end
        return
    elseif what == "playertank" then
        local T = G.tank
        local lx, ly, lz = T.frame:toLocal(x, y, z)
        local dmg = he and 12 or 32
        T.damage(dmg, "shell", lx, ly, lz)
        G.effects.sparks(x, y, z, nx, ny, nz, 14)
        Wp.explode(x, y, z, he and 7 or 3.5, he and 120 or 40, p.owner, T)
        if G.audio then G.audio.play("armor_hit", { x = x, y = y, z = z, big = true, tankHit = true }) end
        return
    elseif what == "creature" then
        G.creatures.damage(obj.c, he and 300 or 600, x, y, z, dx, dz)
    elseif what == "human" then
        G.humans.damage(obj.h, 500, p.owner == "player")
    end
    Wp.explode(x, y, z, he and 10 or 4, he and 220 or 70, p.owner)
    if what == "terrain" then
        for i = 1, 8 do G.effects.impactSnow(x, y, z) end
    end
end

---------------------------------------------------------------------------
-- personal firearm
---------------------------------------------------------------------------
function Wp.canUse()
    local pl = G.player
    return pl.mode == "walk" and pl.frameName == "world"
end

function Wp.update(dt)
    Wp.updateProjectiles(dt)
    local pl = G.player
    local usable = Wp.canUse()
    Wp.holster = U.damp(Wp.holster, usable and 0 or 1, 10, dt)
    Wp.cool = math.max(0, Wp.cool - dt)
    Wp.kick = U.damp(Wp.kick, 0, 12, dt)
    Wp.kickRot = U.damp(Wp.kickRot, 0, 9, dt)
    Wp.kickSide = U.damp(Wp.kickSide, 0, 10, dt)
    Wp.boltT = math.max(0, Wp.boltT - dt)
    Wp.switchT = math.max(0, Wp.switchT - dt * 3)
    Wp.hitT = math.max(0, Wp.hitT - dt * 3)
    Wp.lookX = U.damp(Wp.lookX, 0, 8, dt)
    Wp.lookY = U.damp(Wp.lookY, 0, 8, dt)
    Wp.burst = U.damp(Wp.burst, 0, 4, dt)
    local def = Wp.DEFS[Wp.current]
    if Wp.reloadT > 0 then
        Wp.reloadT = Wp.reloadT - dt
        if Wp.reloadT <= 0 then
            Wp.reloadT = 0
            local inv = G.inventory.player
            local need = def.mag - Wp.mag[Wp.current]
            local got = math.min(need, inv:count(def.ammo))
            inv:remove(def.ammo, got)
            Wp.mag[Wp.current] = Wp.mag[Wp.current] + got
        end
    end
    Wp.aiming = usable and love.mouse.isDown(2) and Wp.reloadT <= 0 and not pl.sprinting
    Wp.aimT = U.damp(Wp.aimT, Wp.aiming and 1 or 0, 14, dt)
    Wp.sprintT = U.damp(Wp.sprintT, (pl.sprinting and not Wp.aiming) and 1 or 0, 8, dt)
    if usable and love.mouse.isDown(1) and Wp.cool <= 0 and Wp.reloadT <= 0 and Wp.switchT <= 0 and Wp.sprintT < 0.3 then
        if def.auto or not Wp.triggerLatch then Wp.fire() end
    end
    if not love.mouse.isDown(1) then Wp.triggerLatch = false end
    local bob = pl.bobAmt or 0
    local aimK = 1 - Wp.aimT * 0.85
    Wp.swayX = U.damp(Wp.swayX, math.sin(pl.bob * math.pi) * 0.014 * bob * aimK, 10, dt)
    Wp.swayY = U.damp(Wp.swayY, math.abs(math.cos(pl.bob * math.pi)) * 0.012 * bob * aimK, 10, dt)
end

-- mouse movement drags the weapon slightly behind the view
function Wp.look(dx, dy)
    Wp.lookX = U.clamp(Wp.lookX - dx * 0.00012, -0.03, 0.03)
    Wp.lookY = U.clamp(Wp.lookY + dy * 0.00012, -0.03, 0.03)
end

function Wp.fire()
    local def = Wp.DEFS[Wp.current]
    Wp.triggerLatch = true
    if Wp.mag[Wp.current] <= 0 then
        Wp.cool = 0.3
        if G.audio then G.audio.play("click", {}) end
        Wp.reload()
        return
    end
    Wp.mag[Wp.current] = Wp.mag[Wp.current] - 1
    Wp.cool = def.interval
    local cam = G.camera
    local pl = G.player
    local moving = (pl.bobAmt or 0)
    local spread = U.lerp(def.hipSpread, def.spread, Wp.aimT) * (1 + moving * 1.5) * (pl.crouch and 0.7 or 1) + Wp.burst * 0.004
    local rx, ry, rz = R.camRight[1], R.camRight[2], R.camRight[3]
    local a, r = math.random() * 6.28, math.sqrt(math.random()) * spread
    local ox, oy = math.cos(a) * r, math.sin(a) * r
    local dx, dy, dz = U.norm3(cam.fx + rx * ox + cam.ux * oy, cam.fy + ry * ox + cam.uy * oy, cam.fz + rz * ox + cam.uz * oy)
    local t, what = Wp.hitscan(cam.x, cam.y, cam.z, dx, dy, dz, 320, def.damage, "foot", Wp.current == "smg" and Wp.mag.smg % 4 == 0)
    if what == "creature" or what == "human" then Wp.hitT = 1 end
    -- muzzle position from the viewmodel
    local m = Wp.models[Wp.current]
    local mx, my, mz = cam.x + cam.fx, cam.y + cam.fy, cam.z + cam.fz
    if Wp.vmFrame then mx, my, mz = Wp.vmFrame:toWorld(m.muzzle[1], m.muzzle[2], m.muzzle[3]) end
    G.effects.muzzleFlash(mx, my, mz, dx, dy, dz, Wp.current == "rifle" and 0.7 or (Wp.current == "smg" and 0.45 or 0.35))
    -- recoil: visual kick plus a little view climb
    Wp.kick = math.min(1.4, Wp.kick + 1)
    Wp.kickRot = math.min(1.5, Wp.kickRot + 1)
    Wp.kickSide = (math.random() - 0.5) * 2
    Wp.burst = math.min(4, Wp.burst + 1)
    local climb = def.kick * (Wp.aiming and 0.6 or 1)
    pl.pitch = pl.pitch + climb * (0.7 + math.random() * 0.3)
    pl.yaw = pl.yaw + (math.random() - 0.5) * climb * 0.5
    if G.camera then G.camera.shake(Wp.current == "rifle" and 0.25 or 0.08) end
    if G.audio then G.audio.play(def.sound, {}) end
    if G.creatures then G.creatures.noise(cam.x, cam.y, cam.z, def.noise, "gunshot") end
    if G.humans then G.humans.noise(cam.x, cam.y, cam.z, def.noise) end
    if def.bolt then
        Wp.boltT = 0.75
        if G.audio then G.audio.play("bolt", { delay = 0.3 }) end
    else
        -- semi/auto weapons eject brass immediately
        if Wp.vmFrame then
            local ex, ey, ez = Wp.vmFrame:toWorld(-0.1, 0.05, 0.03)
            G.effects.casing("world", ex, ey, ez)
        end
    end
end

function Wp.reload()
    local def = Wp.DEFS[Wp.current]
    if Wp.reloadT > 0 or Wp.mag[Wp.current] >= def.mag then return end
    if G.inventory.player:count(def.ammo) <= 0 then
        if G.ui then G.ui.notify("NO AMMO FOR THE " .. def.name) end
        return
    end
    Wp.reloadT = def.reload
    if G.audio then G.audio.play(Wp.current == "rifle" and "reload" or "mg_reload", { volume = 0.7 }) end
end

function Wp.switch(name)
    if name == Wp.current or not Wp.DEFS[name] then return end
    Wp.current = name
    Wp.reloadT = 0
    Wp.cool = 0.35
    Wp.switchT = 1
    if G.audio then G.audio.play("switch", { volume = 0.5 }) end
end

function Wp.cycle(dir)
    for i, n in ipairs(Wp.ORDER) do
        if n == Wp.current then
            Wp.switch(Wp.ORDER[(i - 1 + dir) % #Wp.ORDER + 1])
            return
        end
    end
end

-- aim-down-sights field of view
function Wp.fov(base)
    local def = Wp.DEFS[Wp.current]
    return U.lerp(base, math.rad(def.fov), Wp.aimT * (1 - Wp.holster))
end

local function partFrame(base, x, y, z, pitch, yaw, out)
    out:setYawPitchRoll(yaw or 0, pitch or 0, 0)
    out.px, out.py, out.pz = x, y, z
    return base:compose(out, M3.frame())
end

function Wp.drawViewmodel()
    if Wp.holster > 0.95 then return end
    local cam = G.camera
    love.graphics.clear(false, false, true)
    local def = Wp.DEFS[Wp.current]
    local m = Wp.models[Wp.current]
    local f = Wp.vmFrame or M3.frame()
    Wp.vmFrame = f
    local rx, ry, rz = R.camRight[1], R.camRight[2], R.camRight[3]
    local aim = Wp.aimT
    local hip, ads = def.hip, def.ads
    -- reload choreography: lower and roll the weapon
    local rl = 0
    if Wp.reloadT > 0 then
        local p = 1 - Wp.reloadT / def.reload
        rl = math.sin(math.min(1, p * 1.25) * math.pi)
    end
    local sw = Wp.switchT
    local spr = Wp.sprintT
    local ox = U.lerp(hip[1], ads[1], aim) + Wp.swayX + Wp.lookX + Wp.kickSide * 0.004 * Wp.kick - spr * 0.04
    local oy = U.lerp(hip[2], ads[2], aim) - Wp.swayY + Wp.lookY - Wp.holster * 0.45 - rl * 0.07 - sw * 0.25 - spr * 0.05
    local oz = U.lerp(hip[3], ads[3], aim) - Wp.kick * 0.055 + rl * 0.02
    -- idle breathing
    local t = love.timer.getTime()
    oy = oy + math.sin(t * 1.6) * 0.0025 * (1 - aim * 0.7)
    f.px = cam.x + cam.fx * oz + rx * ox + cam.ux * oy
    f.py = cam.y + cam.fy * oz + ry * ox + cam.uy * oy
    f.pz = cam.z + cam.fz * oz + rz * ox + cam.uz * oy
    -- orientation: muzzle climb from recoil, roll during reload, tilt while sprinting
    local pitch = Wp.kickRot * 0.09 + rl * 0.25 - spr * 0.5
    local yawOff = rl * 0.35 + spr * 0.7 - Wp.lookX * 2
    local cp, sp = math.cos(pitch), math.sin(pitch)
    local cy2, sy2 = math.cos(yawOff), math.sin(yawOff)
    -- forward rotated by yaw (around camera up) then pitch (around right)
    local fx = cam.fx * cy2 + rx * sy2
    local fy = cam.fy * cy2 + ry * sy2
    local fz = cam.fz * cy2 + rz * sy2
    local rrx, rry, rrz = U.norm3(U.cross(fx, fy, fz, cam.ux, cam.uy, cam.uz))
    fx, fy, fz = fx * cp + cam.ux * sp, fy * cp + cam.uy * sp, fz * cp + cam.uz * sp
    local ux, uy, uz = U.cross(rrx, rry, rrz, fx, fy, fz)
    local roll = rl * 0.6
    local cr, sr = math.cos(roll), math.sin(roll)
    f.fx, f.fy, f.fz = fx, fy, fz
    f.ux, f.uy, f.uz = ux * cr + rrx * sr, uy * cr + rry * sr, uz * cr + rrz * sr
    f.rx, f.ry, f.rz = rrx * cr - ux * sr, rry * cr - uy * sr, rrz * cr - uz * sr
    local under = G.world.isUnderground(cam.x, cam.y, cam.z)
    local params = { interior = under and 1 or 0, fog = { 100, 200, 0 } }
    R.drawModel(m.body, f:matrix(Wp.mats[1]), params)
    -- moving parts
    local tmp = M3.frame()
    local bx, bby, bz = 0, 0, 0
    if Wp.current == "rifle" then
        -- bolt: lift and pull back after each shot or during reload
        local b = 0
        if Wp.boltT > 0 then b = math.sin((1 - Wp.boltT / 0.75) * math.pi) end
        if Wp.reloadT > 0 then b = math.max(b, math.min(1, rl * 2)) end
        bx = -b * 0.08
        local bf = partFrame(f, bx, 0, 0, 0, 0, tmp)
        R.drawModel(m.bolt, bf:matrix(Wp.mats[2]), params)
        if Wp.reloadT > 0 and rl > 0.3 then
            local cf = partFrame(f, 0, 0.03 + (1 - rl) * 0.08, 0, 0, 0, M3.frame())
            R.drawModel(m.mag, cf:matrix(Wp.mats[3]), params)
        end
    else
        -- slide/cocking handle snaps back on each shot
        local back = (Wp.current == "pistol" and math.min(1, Wp.kick) * 0.03) or (Wp.cool > 0 and 0.03 or 0)
        local bf = partFrame(f, -back, 0, 0, 0, 0, tmp)
        R.drawModel(m.bolt, bf:matrix(Wp.mats[2]), params)
        -- magazine drops away and returns during reloads
        local drop = rl * 0.3
        local mf = partFrame(f, -drop * 0.3, -drop, 0, 0, 0, M3.frame())
        R.drawModel(m.mag, mf:matrix(Wp.mats[3]), params)
    end
end

return Wp
