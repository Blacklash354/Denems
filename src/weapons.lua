-- Projectiles (tank shells), hitscan bullets, explosions and the player's personal firearms.
local U = require("src.utils")
local P = require("src.physics")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")

local Wp = {}
local G

Wp.DEFS = {
    rifle = { name = "KARABINER 98", ammo = "rifle_ammo", mag = 5, damage = 75, interval = 1.15, reload = 2.6, spread = 0.002,
              noise = 120, kick = 0.06, sound = "rifle", zoom = math.rad(45) },
    pistol = { name = "P08 PISTOL", ammo = "pistol_ammo", mag = 8, damage = 30, interval = 0.22, reload = 1.6, spread = 0.012,
               noise = 70, kick = 0.03, sound = "pistol", zoom = math.rad(60) },
}

local function buildRifle()
    local mb = MB.new(201)
    mb:material("wood"):color(0.75, 0.6, 0.45)
    mb:box(-0.55, -0.05, -0.025, 0.05, 0.02, 0.025)       -- stock
    mb:hexa({ { -0.75, -0.12, -0.022 }, { -0.5, -0.06, -0.022 }, { -0.5, -0.06, 0.022 }, { -0.75, -0.12, 0.022 },
              { -0.75, -0.02, -0.022 }, { -0.5, 0.0, -0.022 }, { -0.5, 0.0, 0.022 }, { -0.75, -0.02, 0.022 } })
    mb:box(0.05, -0.04, -0.022, 0.4, 0.01, 0.022)          -- fore stock
    mb:material("metal"):color(0.35, 0.35, 0.36)
    mb:cylinderX(-0.2, 0.62, 0.025, 0, 0.011, 0.009, 5)    -- barrel
    mb:box(-0.3, 0.0, -0.018, -0.05, 0.04, 0.018)          -- receiver
    mb:box(-0.2, 0.03, 0.018, -0.17, 0.045, 0.06)          -- bolt handle
    mb:box(0.58, 0.035, -0.004, 0.6, 0.055, 0.004)         -- front sight
    return mb:build()
end

local function buildPistol()
    local mb = MB.new(202)
    mb:material("metal"):color(0.3, 0.3, 0.32)
    mb:box(-0.06, -0.01, -0.015, 0.14, 0.03, 0.015)
    mb:cylinderX(0.1, 0.2, 0.012, 0, 0.008, 0.008, 5)
    mb:material("wood"):color(0.5, 0.35, 0.25)
    mb:hexa({ { -0.07, -0.12, -0.017 }, { -0.02, -0.12, -0.017 }, { -0.02, -0.12, 0.017 }, { -0.07, -0.12, 0.017 },
              { -0.06, -0.01, -0.017 }, { 0.0, -0.01, -0.017 }, { 0.0, -0.01, 0.017 }, { -0.06, -0.01, 0.017 } })
    return mb:build()
end

local function buildHands()
    local mb = MB.new(203)
    mb:material("cloth"):color(0.45, 0.42, 0.36)
    mb:box(-0.35, -0.13, -0.05, -0.05, -0.03, 0.05)   -- right sleeve/glove
    mb:box(0.1, -0.1, -0.06, 0.32, -0.02, 0.04)       -- left glove under forestock
    return mb:build()
end

function Wp.init(game)
    G = game
    Wp.projectiles = {}
    Wp.models = { rifle = buildRifle(), pistol = buildPistol(), hands = buildHands() }
    Wp.vmMat = {}
    Wp.reset()
end

function Wp.reset()
    Wp.current = "rifle"
    Wp.mag = { rifle = 5, pistol = 8 }
    Wp.cool = 0
    Wp.reloadT = 0
    Wp.kick = 0
    Wp.aiming = false
    Wp.aimT = 0
    Wp.swayX, Wp.swayY = 0, 0
    Wp.holster = 0
    Wp.projectiles = {}
end

function Wp.serialize() return { current = Wp.current, mag = U.copy(Wp.mag) } end
function Wp.load(s) if s then Wp.current = s.current or "rifle" Wp.mag = s.mag or Wp.mag end end

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
        if owner ~= "foot" and G.player.frameName == "world" and G.player.mode ~= "dead" then
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
    if kind then return bestT, kind, obj, nx, ny, nz end
    return nil
end
Wp.traceAll = traceAll

function Wp.hitscan(ox, oy, oz, dx, dy, dz, range, damage, kind, tracer)
    local owner = kind == "enemy" and "enemy" or (kind == "foot" and "foot" or "player")
    local t, what, obj, nx, ny, nz = traceAll(ox, oy, oz, dx, dy, dz, range, owner)
    local hx, hy, hz = ox + dx * (t or range), oy + dy * (t or range), oz + dz * (t or range)
    if tracer then G.effects.tracer(ox + dx * 2, oy + dy * 2, oz + dz * 2, dx, dy, dz, 420, math.min(0.35, (t or range) / 420)) end
    if not t then return end
    if what == "creature" then
        local mult = obj.part == "head" and 2.0 or 1
        G.creatures.damage(obj.c, damage * mult, hx, hy, hz, dx, dz)
        G.effects.blood(hx, hy, hz, 5)
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
    Wp.kick = U.damp(Wp.kick, 0, 9, dt)
    local def = Wp.DEFS[Wp.current]
    if Wp.reloadT > 0 then
        Wp.reloadT = Wp.reloadT - dt
        if Wp.reloadT <= 0 then
            local inv = G.inventory.player
            local need = def.mag - Wp.mag[Wp.current]
            local got = math.min(need, inv:count(def.ammo))
            inv:remove(def.ammo, got)
            Wp.mag[Wp.current] = Wp.mag[Wp.current] + got
        end
    end
    Wp.aiming = usable and love.mouse.isDown(2) and Wp.reloadT <= 0
    Wp.aimT = U.damp(Wp.aimT, Wp.aiming and 1 or 0, 12, dt)
    if usable and love.mouse.isDown(1) and Wp.cool <= 0 and Wp.reloadT <= 0 then
        if Wp.current == "pistol" and Wp.triggerLatch then return end
        Wp.fire()
    end
    if not love.mouse.isDown(1) then Wp.triggerLatch = false end
    -- weapon sway follows movement
    local t = love.timer.getTime()
    local bob = pl.bobAmt or 0
    Wp.swayX = U.damp(Wp.swayX, math.sin(pl.bob * math.pi) * 0.012 * bob, 10, dt)
    Wp.swayY = U.damp(Wp.swayY, math.abs(math.cos(pl.bob * math.pi)) * 0.01 * bob + math.sin(t * 1.3) * 0.002, 10, dt)
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
    local spread = def.spread * (Wp.aiming and 0.3 or 1) * (G.player.sprinting and 4 or 1)
    local dx, dy, dz = U.norm3(cam.fx + (math.random() - 0.5) * spread, cam.fy + (math.random() - 0.5) * spread, cam.fz + (math.random() - 0.5) * spread)
    Wp.hitscan(cam.x, cam.y, cam.z, dx, dy, dz, 300, def.damage, "foot", false)
    local rx, ry, rz = R.camRight[1], R.camRight[2], R.camRight[3]
    local mx, my, mz = cam.x + cam.fx * 0.8 + rx * 0.12 - cam.ux * 0.08, cam.y + cam.fy * 0.8 + ry * 0.12 - cam.uy * 0.08, cam.z + cam.fz * 0.8 + rz * 0.12 - cam.uz * 0.08
    G.effects.muzzleFlash(mx, my, mz, dx, dy, dz, Wp.current == "rifle" and 0.6 or 0.35)
    Wp.kick = 1
    G.player.pitch = G.player.pitch + def.kick * (0.6 + math.random() * 0.4)
    G.player.yaw = G.player.yaw + (math.random() - 0.5) * def.kick * 0.3
    if G.audio then G.audio.play(def.sound, {}) end
    if G.creatures then G.creatures.noise(cam.x, cam.y, cam.z, def.noise, "gunshot") end
    if Wp.current == "rifle" and G.audio then G.audio.play("bolt", { delay = 0.35 }) end
end

function Wp.reload()
    local def = Wp.DEFS[Wp.current]
    if Wp.reloadT > 0 or Wp.mag[Wp.current] >= def.mag then return end
    if G.inventory.player:count(def.ammo) <= 0 then
        if G.ui then G.ui.notify("NO " .. (Wp.current == "rifle" and "RIFLE" or "PISTOL") .. " AMMO") end
        return
    end
    Wp.reloadT = def.reload
    if G.audio then G.audio.play("reload", {}) end
end

function Wp.switch(name)
    if name == Wp.current or not Wp.DEFS[name] then return end
    Wp.current = name
    Wp.reloadT = 0
    Wp.cool = 0.4
    Wp.holster = 0.8
    if G.audio then G.audio.play("switch", { volume = 0.5 }) end
end

function Wp.drawViewmodel()
    if Wp.holster > 0.95 then return end
    local cam = G.camera
    love.graphics.clear(false, false, true)
    local f = M3.frame()
    local rx, ry, rz = R.camRight[1], R.camRight[2], R.camRight[3]
    local aim = Wp.aimT
    local isRifle = Wp.current == "rifle"
    local ox = U.lerp(isRifle and 0.16 or 0.18, 0.0, aim) + Wp.swayX
    local oy = U.lerp(isRifle and -0.17 or -0.15, isRifle and -0.065 or -0.075, aim) - Wp.swayY - Wp.holster * 0.4
    local oz = 0.32 - Wp.kick * 0.06
    local reloadDip = 0
    if Wp.reloadT > 0 then reloadDip = math.sin(math.min(1, Wp.reloadT / Wp.DEFS[Wp.current].reload) * math.pi) * 0.12 end
    oy = oy - reloadDip
    f.px = cam.x + cam.fx * oz + rx * ox + cam.ux * oy
    f.py = cam.y + cam.fy * oz + ry * ox + cam.uy * oy
    f.pz = cam.z + cam.fz * oz + rz * ox + cam.uz * oy
    -- orientation: forward = cam forward pitched up by kick
    local k = Wp.kick * 0.12 + reloadDip * 1.5
    local fx, fy, fz = U.norm3(cam.fx + cam.ux * k, cam.fy + cam.uy * k, cam.fz + cam.uz * k)
    f.fx, f.fy, f.fz = fx, fy, fz
    f.ux, f.uy, f.uz = U.norm3(U.cross(rx, ry, rz, fx, fy, fz))
    f.rx, f.ry, f.rz = rx, ry, rz
    local m = f:matrix(Wp.vmMat)
    local under = G.world.isUnderground(cam.x, cam.y, cam.z)
    R.drawModel(Wp.models[Wp.current], m, { interior = under and 1 or 0, fog = { 100, 200, 0 } })
    R.drawModel(Wp.models.hands, m, { interior = under and 1 or 0, fog = { 100, 200, 0 } })
end

return Wp
