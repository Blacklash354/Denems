-- Projectiles (tank shells), hitscan bullets, explosions and the player's personal firearms.
local U = require("src.utils")
local P = require("src.physics")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local Gltf = require("src.engine.gltf")
local PA = require("src.psx_assets")
local Obj = require("src.engine.obj")
local Textures = require("src.engine.textures")
local M3 = require("src.engine.math3d")
local VM = require("src.viewmodel")

local Wp = {}
local G

-- Personal firearms. Each weapon is a set of model parts (body, magazine, bolt) plus arms,
-- animated procedurally: sway, bob, recoil, bolt cycling, reloads, sprinting and aiming down sights.
Wp.DEFS = {
    rifle = { name = "KARABINER 98K", ammo = "rifle_ammo", mag = 5, damage = 85, interval = 1.05, reload = 2.8, spread = 0.0015,
              hipSpread = 0.02, noise = 130, kick = 0.055, sound = "rifle", fov = 42, auto = false, bolt = true,
              hip = { 0.13, -0.1, 0.42 }, ads = { 0.0, -0.064, 0.21 }, casing = 0.35 },
    smg = { name = "PPSH-41", ammo = "pistol_ammo", mag = 71, damage = 19, interval = 60 / 900, reload = 3.0, spread = 0.009,
            hipSpread = 0.035, noise = 110, kick = 0.012, sound = "smg", fov = 58, auto = true,
            hip = { 0.13, -0.11, 0.46 }, ads = { 0.0, -0.074, 0.25 }, casing = 0 },
    pistol = { name = "TT-33 PISTOL", ammo = "pistol_ammo", mag = 8, damage = 32, interval = 0.18, reload = 1.6, spread = 0.006,
               hipSpread = 0.02, noise = 80, kick = 0.03, sound = "pistol", fov = 62, auto = false,
               hip = { 0.11, -0.095, 0.46 }, ads = { 0.0, -0.098, 0.36 }, casing = 0 },
    shotgun = { name = "PUMP SHOTGUN", ammo = "shotgun_ammo", mag = 6, damage = 15, pellets = 9, interval = 0.95, reload = 2.6, shellTime = 0.62,
                spread = 0.03, hipSpread = 0.045, noise = 140, kick = 0.075, sound = "rifle", fov = 60, auto = false, pump = true,
                hip = { 0.13, -0.11, 0.52 }, ads = { 0.0, -0.066, 0.3 }, casing = 0, range = 60 },
}
Wp.ORDER = { "rifle", "smg", "pistol", "shotgun" }

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

-- imported PSX firearm (parts animated by the model's own clips)
local function buildImported(name, muzzle)
    return { gltf = PA.model("firearms", name), muzzle = muzzle }
end

-- gun from the .obj pack: body / moving slide / magazine as separate models, like the procedural guns
local function buildObjGun(file, texture, scale, origin, parts, muzzle, seed)
    local tex = "gun_" .. file:match("([^/]+)%.obj$")
    Textures.loadFile(tex, PA.GUNS .. texture)
    local objects = Obj.load(PA.GUNS .. file)
    local out = { muzzle = muzzle }
    for i, key in ipairs({ "body", "bolt", "mag" }) do
        local mb = MB.new(seed + i)
        mb:material(tex):color(1, 1, 1)
        Obj.emit(mb, objects, parts[key], scale, origin[1], origin[2], origin[3])
        out[key] = mb:build()
    end
    return out
end

-- the AK is one mesh: the curved magazine is cut out of it so the hands can swap it
local function inAKMag(x, y, z) return x > -0.045 and x < 0.125 and y < -0.018 end
local function buildAK()
    local mb = MB.new(241)
    mb:color(1, 1, 1)
    local half = PA.emitAK(mb, function(x, y, z) return not inAKMag(x, y, z) end)
    local mm = MB.new(242)
    mm:color(1, 1, 1)
    PA.emitAK(mm, inAKMag)
    return { body = mb:build(), mag = mm:build(), muzzle = { half, 0.03, 0 } }
end

function Wp.init(game)
    G = game
    Wp.projectiles = {}
    -- the user's gun pack replaces the procedural rifle, SMG and pistol when it is present
    local D = Wp.DEFS
    if PA.has(PA.GUNS .. "tactical rifle/tactical_Rifle.obj") then
        Wp.packRifle = buildObjGun("tactical rifle/tactical_Rifle.obj", "tactical rifle/Textures/Tac_M14_Text.png", 0.098, { 0, 1.65, -0.02 },
            { body = { "Tac_M14_Body", "Tac_M14_Trigger" }, bolt = { "Tac_M14_Slide" }, mag = { "Tac_M14_Magazene" } },
            { 0.72, 0.034, 0 }, 250)
        D.rifle.name, D.rifle.bolt, D.rifle.interval, D.rifle.mag, D.rifle.casing = "M14 RIFLE", false, 0.42, 10, 0
    end
    if PA.has(PA.GUNS .. "Makarov/Makarov.obj") then
        Wp.packPistol = buildObjGun("Makarov/Makarov.obj", "Makarov/Texture/Mak_Textiure_240.png", 0.102, { -0.6, 1.0, 0 },
            { body = { "Makarov_Body", "Makarov_Hammer" }, bolt = { "Makarov_Slide" }, mag = { "Makarov_Mag_empty" } },
            { 0.114, 0.061, 0 }, 260)
        D.pistol.name, D.pistol.ads = "MAKAROV PM", { 0.0, -0.079, 0.36 }
    end
    if PA.has(PA.AK) then
        Wp.packSMG = buildAK()
        D.smg.name, D.smg.mag, D.smg.interval, D.smg.damage, D.smg.spread = "AK-74", 30, 60 / 650, 27, 0.006
        D.smg.ads = { 0.0, -0.079, 0.25 }
    end
    Wp.models = { rifle = Wp.packRifle or buildRifle(), smg = Wp.packSMG or buildSMG(),
        pistol = Wp.packPistol or buildImported("pistol", { 0.152, 0.071, 0 }),
        shotgun = buildImported("pump_shotgun", { 0.66, 0.035, 0 }) }
    Wp.mats = { {}, {}, {} }
    VM.init()
    Wp.reset()
end

function Wp.reset()
    Wp.current = PA.has(PA.AK) and "smg" or "rifle"
    Wp.mag = {}
    for id, def in pairs(Wp.DEFS) do Wp.mag[id] = def.mag end
    Wp.shotT = 99
    Wp.cool = 0
    Wp.reloadT = 0
    Wp.reloadLen = 1
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
        Wp.current = Wp.DEFS[s.current] and s.current or Wp.current
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
    if what == "human" then
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
        if obj and obj.obj and G.destruction then G.destruction.damage(obj.obj, damage, "bullet", hx, hy, hz) end
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
    if G.humans then G.humans.noise(x, y, z, 350) end
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
    if G.destruction then
        G.destruction.splash(x, y, z, radius * 1.1, damage * 2.5)
        if radius >= 4 then G.destruction.blastTrees(x, y, z, radius * 1.2) end
    end
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
    elseif what == "human" then
        G.humans.damage(obj.h, 500, p.owner == "player")
    elseif what == "world" and obj and obj.obj and G.destruction then
        G.destruction.damage(obj.obj, he and 700 or 520, "explosion", x, y, z)
    elseif what == "world" and obj and obj.treeRec and G.destruction then
        -- a shell through a trunk fells it along the shell's path
        G.destruction.knockTree(obj.treeRec, dx or 1, dz or 0, 0.8)
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
    Wp.shotT = Wp.shotT + dt
    Wp.switchT = math.max(0, Wp.switchT - dt * 3)
    Wp.hitT = math.max(0, Wp.hitT - dt * 3)
    Wp.lookX = U.damp(Wp.lookX, 0, 8, dt)
    Wp.lookY = U.damp(Wp.lookY, 0, 8, dt)
    Wp.burst = U.damp(Wp.burst, 0, 4, dt)
    local def = Wp.DEFS[Wp.current]
    if Wp.reloadT > 0 then
        Wp.reloadT = Wp.reloadT - dt
        local inv = G.inventory.player
        if def.pellets then
            -- the shotgun is fed one shell at a time; firing stops the reload after the current shell
            if Wp.reloadT <= 0 then
                if inv:count(def.ammo) > 0 and Wp.mag[Wp.current] < def.mag then
                    inv:remove(def.ammo, 1)
                    Wp.mag[Wp.current] = Wp.mag[Wp.current] + 1
                    if G.audio then G.audio.play("click", { volume = 0.5, pitch = 1.4 }) end
                end
                if Wp.mag[Wp.current] < def.mag and inv:count(def.ammo) > 0 and not Wp.stopReload then
                    Wp.reloadT = def.shellTime
                else
                    Wp.reloadT = 0
                    if Wp.reloadEmpty then Wp.shotT = Gltf.duration(Wp.models.shotgun.gltf, "fire") Wp.reloadEmpty = false
                        if G.audio then G.audio.play("bolt", {}) end end
                end
            end
        else
            -- magazines go in at the moment the hand seats them
            local p = 1 - Wp.reloadT / Wp.reloadLen
            if not Wp.magIn and p >= (Wp.current == "pistol" and 0.78 or 0.7) then
                Wp.magIn = true
                local need = def.mag - Wp.mag[Wp.current]
                local got = math.min(need, inv:count(def.ammo))
                inv:remove(def.ammo, got)
                Wp.mag[Wp.current] = Wp.mag[Wp.current] + got
                if G.audio then G.audio.play("click", { volume = 0.7 }) end
            end
            if Wp.reloadT <= 0 then Wp.reloadT = 0 end
        end
    end
    Wp.aiming = usable and love.mouse.isDown(2) and Wp.reloadT <= 0 and not pl.sprinting
    Wp.aimT = U.damp(Wp.aimT, Wp.aiming and 1 or 0, 14, dt)
    Wp.sprintT = U.damp(Wp.sprintT, (pl.sprinting and not Wp.aiming) and 1 or 0, 8, dt)
    if usable and love.mouse.isDown(1) and def.pellets and Wp.reloadT > 0 then Wp.stopReload = true end
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
    local t, what = Wp.hitscan(cam.x, cam.y, cam.z, dx, dy, dz, def.range or 320, def.damage, "foot", Wp.current == "smg" and Wp.mag.smg % 4 == 0)
    if what == "human" then Wp.hitT = 1 end
    -- buckshot: the rest of the pellets scatter around the first
    for i = 2, def.pellets or 1 do
        local pa, pr = math.random() * 6.28, math.sqrt(math.random()) * spread
        local px, py = math.cos(pa) * pr, math.sin(pa) * pr
        local ex, ey, ez = U.norm3(cam.fx + rx * px + cam.ux * py, cam.fy + ry * px + cam.uy * py, cam.fz + rz * px + cam.uz * py)
        local _, w2 = Wp.hitscan(cam.x, cam.y, cam.z, ex, ey, ez, def.range or 320, def.damage, "foot", false)
        if w2 == "human" then Wp.hitT = 1 end
    end
    Wp.shotT = 0
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
    if G.humans then G.humans.noise(cam.x, cam.y, cam.z, def.noise) end
    if def.bolt then
        Wp.boltT = 0.75
        if G.audio then G.audio.play("bolt", { delay = 0.3 }) end
    elseif def.pump then
        if G.audio then G.audio.play("bolt", { delay = 0.32 }) end
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
    Wp.reloadEmpty = Wp.mag[Wp.current] == 0
    Wp.magIn = false
    Wp.stopReload = false
    if def.pellets then
        Wp.reloadT = def.shellTime + 0.25
        Wp.reloadLen = Wp.reloadT
    else
        -- a tactical reload (round still chambered) skips working the charging handle
        Wp.reloadLen = def.reload * (Wp.reloadEmpty and 1 or 0.85)
        Wp.reloadT = Wp.reloadLen
    end
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
    -- reload choreography comes from the hand track
    local rig = VM.RIGS[Wp.current]
    local reloading = Wp.reloadT > 0
    local smp, shellPhase
    if reloading and rig and rig.track ~= "shells" then
        local p = U.clamp(1 - Wp.reloadT / Wp.reloadLen, 0, 1)
        smp = VM.sample(VM.TRACKS[rig.track], p, Wp.reloadEmpty)
    elseif reloading and rig and rig.track == "shells" then
        shellPhase = U.clamp(1 - Wp.reloadT / def.shellTime, 0, 1)
        smp = { roll = 0.25, pitch = 0.05, drop = 0.03 }
    end
    local roll0 = smp and smp.roll or 0
    local pitch0 = smp and smp.pitch or 0
    local drop0 = smp and smp.drop or 0
    local sw = Wp.switchT
    local spr = Wp.sprintT
    local ox = U.lerp(hip[1], ads[1], aim) + Wp.swayX + Wp.lookX + Wp.kickSide * 0.004 * Wp.kick - spr * 0.04 - roll0 * 0.04
    local oy = U.lerp(hip[2], ads[2], aim) - Wp.swayY + Wp.lookY - Wp.holster * 0.45 - drop0 - sw * 0.25 - spr * 0.05
    local oz = U.lerp(hip[3], ads[3], aim) - Wp.kick * 0.055
    local t = love.timer.getTime()
    oy = oy + math.sin(t * 1.6) * 0.0025 * (1 - aim * 0.7)
    -- shiver when freezing
    local pl = G.player
    if pl.warmth < 25 then
        local k = (25 - pl.warmth) / 25
        ox = ox + math.sin(t * 37) * 0.0015 * k
        oy = oy + math.sin(t * 41 + 1) * 0.0015 * k
    end
    f.px = cam.x + cam.fx * oz + rx * ox + cam.ux * oy
    f.py = cam.y + cam.fy * oz + ry * ox + cam.uy * oy
    f.pz = cam.z + cam.fz * oz + rz * ox + cam.uz * oy
    -- orientation: muzzle climb from recoil, tilt for the reload, swing while sprinting
    local pitch = Wp.kickRot * 0.09 + pitch0 - spr * 0.45
    local yawOff = spr * 0.75 - Wp.lookX * 2 + roll0 * 0.25
    local cp, sp = math.cos(pitch), math.sin(pitch)
    local cy2, sy2 = math.cos(yawOff), math.sin(yawOff)
    local fx = cam.fx * cy2 + rx * sy2
    local fy = cam.fy * cy2 + ry * sy2
    local fz = cam.fz * cy2 + rz * sy2
    local rrx, rry, rrz = U.norm3(U.cross(fx, fy, fz, cam.ux, cam.uy, cam.uz))
    fx, fy, fz = fx * cp + cam.ux * sp, fy * cp + cam.uy * sp, fz * cp + cam.uz * sp
    local ux, uy, uz = U.cross(rrx, rry, rrz, fx, fy, fz)
    local roll = roll0 + spr * 0.25
    local cr, sr = math.cos(roll), math.sin(roll)
    f.fx, f.fy, f.fz = fx, fy, fz
    f.ux, f.uy, f.uz = ux * cr + rrx * sr, uy * cr + rry * sr, uz * cr + rrz * sr
    f.rx, f.ry, f.rz = rrx * cr - ux * sr, rry * cr - uy * sr, rrz * cr - uz * sr
    local under = G.world.isUnderground(cam.x, cam.y, cam.z)
    local params = { interior = under and 1 or 0, fog = { 100, 200, 0 } }
    local worn = G.inventory.worn or {}
    local st = { reload = smp and not shellPhase, sample = smp, shellPhase = shellPhase, pump = 0, torso = worn.torso, hands = worn.hands }
    if m.gltf then
        -- the model's own clips animate the pump and trigger; the hands follow
        local clip, ct = nil, 0
        local fireD = Gltf.duration(m.gltf, "fire")
        local pumpD = Gltf.duration(m.gltf, "pump")
        if Wp.shotT < fireD then clip, ct = "fire", Wp.shotT
        elseif def.pump and Wp.shotT < fireD + pumpD then
            clip, ct = "pump", Wp.shotT - fireD
            st.pump = math.sin(ct / math.max(pumpD, 0.01) * math.pi)
        end
        Gltf.pose(m.gltf, clip, ct, false)
        local wm = f:matrix(Wp.mats[1])
        Gltf.draw(R, m.gltf, wm, params)
        VM.drawArms(Wp.current, f, st, params)
        return
    end
    R.drawModel(m.body, f:matrix(Wp.mats[1]), params)
    local tmp = M3.frame()
    -- slide / bolt: snaps back on each shot, worked by hand at the end of an empty reload
    local back = 0
    if Wp.current == "pistol" then back = math.min(1, Wp.kick) * 0.03 else back = (Wp.cool > def.interval * 0.5 and 0.03 or 0) end
    if smp and smp.pull and rig then back = math.max(back, smp.pull * (rig.chargeTravel or 0.05)) end
    if Wp.current == "rifle" and def.bolt and Wp.boltT > 0 then back = math.max(back, math.sin((1 - Wp.boltT / 0.75) * math.pi) * 0.08) end
    if m.bolt then
        local bf = partFrame(f, -back, 0, 0, 0, 0, tmp)
        R.drawModel(m.bolt, bf:matrix(Wp.mats[2]), params)
    end
    if m.mag then
        if smp and rig and rig.magTop then
            local mf = VM.magFrame(Wp.current, f, smp, M3.frame())
            R.drawModel(m.mag, mf:matrix(Wp.mats[3]), params)
        else
            R.drawModel(m.mag, f:matrix(Wp.mats[3]), params)
        end
    end
    VM.drawArms(rig and Wp.current or "smg", f, st, params)
end

return Wp
