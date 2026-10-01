-- The player's tank: mobile base, shelter, storage and weapon platform.
-- Handles driving physics, turret/gun state, component damage, frames, colliders and rendering.
local U = require("src.utils")
local M3 = require("src.engine.math3d")
local R = require("src.engine.renderer")
local P = require("src.physics")
local TM = require("src.tank_model")
local TI = require("src.tank_interior")

local T = {}
local G -- game registry

T.GEARS = { { 0, 2.0 }, { 1.6, 4.2 }, { 3.6, 6.8 }, { 6.0, 9.4 }, { 8.6, 12.0 } }

function T.init(game)
    G = game
    T.models = {
        hull = TM.buildHull(), turret = TM.buildTurret(), gun = TM.buildGun(), breech = TM.buildBreech(),
        hatch = TM.buildHatch(), mgExt = TM.buildMGExterior(), mgInt = TM.buildMGInterior(),
        trackL = TM.buildTrack(-1), trackR = TM.buildTrack(1), wheelsL = TM.buildWheels(-1), wheelsR = TM.buildWheels(1),
        sprocket = TM.buildSprocket(), lever = TM.buildLever(),
        hullInt = TI.buildHull(), turretInt = TI.buildTurret(), bulbs = TI.buildLampBulbs(), turretBulb = TI.buildTurretBulb(),
        radioDial = TI.buildRadioDial(),
    }
    T.frame = M3.frame()
    T.prevFrame = M3.frame()
    T.turretLocal = M3.frame()
    T.turretWorld = M3.frame()
    T.gunLocal = M3.frame()
    T.gunWorld = M3.frame()
    T.hatchLocal = M3.frame()
    T.hatchWorld = M3.frame()
    T.mgLocal = M3.frame()
    T.mgWorld = M3.frame()
    T.tmpFrame = M3.frame()
    T.mats = {}
    for _, k in ipairs({ "tank", "turret", "gun", "hatch", "mg", "sprL", "sprR", "levL", "levR" }) do T.mats[k] = {} end

    -- collider sets
    local ext = {
        { -3.95, 0.3, -1.45, 3.35, 1.55, 1.45 },
        { -3.95, 0.0, 1.45, 3.75, 1.55, 1.98 },
        { -3.95, 0.0, -1.98, 3.75, 1.55, -1.45 },
        { -3.95, 1.55, -1.85, 3.15, 2.35, 1.85 },
        { -3.9, 2.35, -1.78, -3.38, 2.82, -0.75 },
        { 3.15, 1.45, -1.98, 3.85, 1.55, 1.98 },
    }
    for _, b in ipairs(ext) do b.walk = true b.tank = true end
    T.extSet = { frame = T.frame, boxes = ext, tank = true }
    local tur = {
        { -1.75, 0, -1.6, 1.6, 1.1, 1.6 },
        { -2.37, 0.1, -1.1, -1.72, 0.75, 1.1 },
        { -1.41, 1.1, -1.21, -0.49, 1.42, -0.29, noRay = true },
    }
    for _, b in ipairs(tur) do b.walk = true b.tank = true b.turret = true end
    T.turretExtSet = { frame = T.turretWorld, boxes = tur, tank = true }
    local gun = { { 0.3, -0.16, -0.16, 6.05, 0.16, 0.16, noPlayer = true, tank = true, gun = true },
                  { 0.08, -0.34, -0.62, 0.42, 0.34, 0.62, tank = true, gun = true } }
    T.gunExtSet = { frame = T.gunWorld, boxes = gun, tank = true }
    T.intSet = { boxes = TI.hullColliders() }
    T.turretIntSet = { frame = T.turretLocal, boxes = TI.turretColliders() }
    T.reset()
end

function T.reset(state)
    local W = G.world
    T.x, T.z = W.START.x, W.START.z
    T.yaw = W.START.yaw
    T.y = W.height(T.x, T.z)
    T.speed, T.yawRate = 0, 0
    T.nx, T.ny, T.nz = 0, 1, 0
    T.pitchKick, T.pitchVel = 0, 0
    T.turretYaw, T.gunPitch = 0, 0.02
    T.turretRate, T.gunRate = 0, 0
    T.turretInput, T.gunInput = 0, 0
    T.recoil = 0
    T.hatchOpen, T.hatchAnim = false, 0
    T.engineOn, T.engineStarting = false, 0
    T.rpm, T.gear, T.throttle, T.steer = 0, 0, 0, 0
    T.fuel = 38
    T.comp = { engine = 85, trackL = 100, trackR = 45, turret = 100, cannon = 100, hull = 82 }
    T.trackOffL, T.trackOffR, T.sprocketAng = 0, 0, 0
    T.loaded = nil
    T.reloadT = 0
    T.ammoSelect = "AP"
    T.lightsOn = true
    T.headlights = false
    T.mgYaw, T.mgPitch, T.mgHeat, T.mgBelt, T.mgJam = 0, 0, 0, 75, false
    T.mgReload = 0
    T.radioOn = false
    T.destroyed = false
    T.distAcc = 0
    T.exhaustAcc = 0
    T.flicker = 0
    T.leverL, T.leverR = 0, 0
    T.rackKey = nil
    T.driver = false
    if state then
        for k, v in pairs(state) do
            if k == "comp" then for ck, cv in pairs(v) do T.comp[ck] = cv end
            else T[k] = v end
        end
    end
    T.updateFrames(0)
    T.prevFrame:copyFrom(T.frame)
end

function T.serialize()
    return {
        x = T.x, z = T.z, yaw = T.yaw, turretYaw = T.turretYaw, gunPitch = T.gunPitch, fuel = T.fuel,
        comp = U.copy(T.comp), loaded = T.loaded, ammoSelect = T.ammoSelect, hatchOpen = T.hatchOpen,
        hatchAnim = T.hatchOpen and 1 or 0, mgBelt = T.mgBelt, lightsOn = T.lightsOn, headlights = T.headlights,
    }
end

---------------------------------------------------------------------------
-- frames
---------------------------------------------------------------------------
function T.updateFrames(dt)
    local f = T.frame
    -- orientation from terrain normal, then pitch kick (recoil / bumps)
    f:setYawNormal(T.yaw, T.nx, T.ny, T.nz)
    if T.pitchKick ~= 0 then
        local a = T.pitchKick
        local c, s = math.cos(a), math.sin(a)
        local fx, fy, fz = f.fx * c + f.ux * s, f.fy * c + f.uy * s, f.fz * c + f.uz * s
        local ux, uy, uz = f.ux * c - f.fx * s, f.uy * c - f.fy * s, f.uz * c - f.fz * s
        f.fx, f.fy, f.fz, f.ux, f.uy, f.uz = fx, fy, fz, ux, uy, uz
    end
    f.px, f.py, f.pz = T.x, T.y, T.z
    local tl = T.turretLocal
    tl:setYaw(T.turretYaw)
    tl.px, tl.py, tl.pz = TM.TURRET_PIVOT[1], TM.TURRET_PIVOT[2], TM.TURRET_PIVOT[3]
    f:compose(tl, T.turretWorld)
    local gl = T.gunLocal
    gl:setYawPitchRoll(0, T.gunPitch, 0)
    local rc = T.recoil * 0.45
    gl.px, gl.py, gl.pz = TM.TRUNNION[1] - gl.fx * rc, TM.TRUNNION[2] - gl.fy * rc, TM.TRUNNION[3]
    T.turretWorld:compose(gl, T.gunWorld)
    local hl = T.hatchLocal
    hl:setYawPitchRoll(0, U.smoothstep(0, 1, T.hatchAnim) * 1.95, 0)
    hl.px, hl.py, hl.pz = TM.HATCH_HINGE[1], TM.HATCH_HINGE[2], TM.HATCH_HINGE[3]
    T.turretWorld:compose(hl, T.hatchWorld)
    local ml = T.mgLocal
    ml:setYawPitchRoll(T.mgYaw, T.mgPitch, 0)
    ml.px, ml.py, ml.pz = TM.MG_BALL[1], TM.MG_BALL[2], TM.MG_BALL[3]
    f:compose(ml, T.mgWorld)
end

-- frame accessors used by interactables
function T.getFrame() return T.frame end
function T.getTurretFrame() return T.turretWorld end
function T.getGunFrame() return T.gunWorld end

---------------------------------------------------------------------------
-- driving physics
---------------------------------------------------------------------------
local cornerOffsets = { { 3.3, -1.7 }, { 3.3, 1.7 }, { -3.4, -1.7 }, { -3.4, 1.7 } }

function T.maxSpeed()
    local engineF = 0.45 + 0.55 * U.clamp(T.comp.engine / 60, 0, 1)
    local trackMin = math.min(T.comp.trackL, T.comp.trackR)
    local trackF = trackMin <= 0 and 0 or (0.45 + 0.55 * U.clamp(trackMin / 70, 0, 1))
    return 11.5 * engineF * trackF
end

function T.startEngine()
    if T.engineOn or T.engineStarting > 0 or T.destroyed then return end
    T.engineStarting = 1.6
    if G.audio then G.audio.play("engine_start", { tank = true }) end
end

function T.stopEngine()
    if not T.engineOn then return end
    T.engineOn = false
    if G.audio then G.audio.play("engine_stop", { tank = true }) end
end

local function engineCanRun() return T.fuel > 0 and T.comp.engine > 8 and not T.destroyed end

function T.update(dt)
    local W = G.world
    T.prevFrame:copyFrom(T.frame)
    -- engine start sequence
    if T.engineStarting > 0 then
        T.engineStarting = T.engineStarting - dt
        if T.engineStarting <= 0 then
            T.engineStarting = 0
            if engineCanRun() and (T.comp.engine > 30 or math.random() < 0.6) then
                T.engineOn = true
                if G.missions then G.missions.event("engine_started") end
            else
                if G.ui then G.ui.notify(T.fuel <= 0 and "NO FUEL" or "ENGINE FAILED TO START - TRY AGAIN") end
            end
        end
    end
    if T.engineOn and not engineCanRun() then
        T.engineOn = false
        if G.ui then G.ui.notify(T.fuel <= 0 and "OUT OF FUEL" or "ENGINE STALLED") end
    end

    local throttle, steer = T.throttle, T.steer
    if not T.driver then throttle, steer = 0, 0 end
    local maxF = T.maxSpeed()
    local target = 0
    if T.engineOn then
        if throttle > 0 then target = throttle * maxF elseif throttle < 0 then target = throttle * 3.5 end
    end
    local accel
    if T.engineOn and math.abs(target) > math.abs(T.speed) and U.sign(target) == U.sign(T.speed + target * 0.01) then
        accel = 1.4 * (0.5 + 0.5 * T.comp.engine / 100)
    elseif throttle == 0 then
        accel = T.engineOn and 2.2 or 1.4     -- engine braking / rolling resistance
    else
        accel = 4.0                            -- braking against motion
    end
    T.speed = U.approach(T.speed, target, accel * dt)
    -- slopes pull the tank
    local slope = T.frame.fy
    T.speed = T.speed - slope * 9.8 * 0.55 * dt
    if not T.engineOn and math.abs(T.speed) < 0.3 and math.abs(slope) < 0.2 then T.speed = U.approach(T.speed, 0, dt) end
    -- steering: pivot turns when slow, wider when fast; damaged tracks pull
    local trackF = math.min(T.comp.trackL, T.comp.trackR) > 0 and 1 or 0.25
    local turnRate = (0.42 - 0.18 * U.clamp(math.abs(T.speed) / 11, 0, 1)) * trackF
    if not T.engineOn then turnRate = 0 end
    local yawTarget = steer * turnRate * (T.speed < -0.3 and -1 or 1)
    local pull = (T.comp.trackR - T.comp.trackL) / 100 * 0.04 * U.clamp(math.abs(T.speed) / 5, 0, 1)
    yawTarget = yawTarget - pull * U.sign(T.speed)
    T.yawRate = U.damp(T.yawRate, yawTarget, 2.5, dt)
    T.yaw = T.yaw + T.yawRate * dt

    -- integrate position
    local c, s = math.cos(T.yaw), math.sin(T.yaw)
    local nx, nz = T.x + c * T.speed * dt, T.z + s * T.speed * dt
    -- collisions with the static world (three circles along the hull)
    local totalPush = 0
    for _, off in ipairs({ -2.5, 0, 2.5 }) do
        local cx, cz = nx + c * off, nz + s * off
        local px, pz, hit, box = P.circlePush({ W.staticSet }, cx, T.y, cz, 2.0, 0.7, 3.0)
        if hit then
            nx, nz = nx + px, nz + pz
            totalPush = totalPush + math.sqrt(px * px + pz * pz)
        end
    end
    -- other vehicles
    if G.enemies then
        for _, e in ipairs(G.enemies.tanks) do
            local d = U.dist2(nx, nz, e.x, e.z)
            if d < 6.5 and d > 0.01 then
                local push = (6.5 - d)
                nx, nz = nx + (nx - e.x) / d * push * 0.5, nz + (nz - e.z) / d * push * 0.5
                totalPush = totalPush + push
            end
        end
    end
    if totalPush > 0.02 then
        local impact = math.abs(T.speed)
        if impact > 3.5 then
            T.damage((impact - 3.5) * 4, "collision")
            if G.camera then G.camera.shake(0.4) end
            if G.audio then G.audio.play("clang", { x = T.x, y = T.y + 1, z = T.z }) end
        end
        T.speed = T.speed * math.max(0, 1 - totalPush * 3)
    end
    local L = W.LIMIT
    nx, nz = U.clamp(nx, -L, L), U.clamp(nz, -L, L)
    local moved = U.dist2(T.x, T.z, nx, nz)
    T.x, T.z = nx, nz

    -- terrain following: sample corners
    local hs = {}
    local f = T.frame
    for i, o in ipairs(cornerOffsets) do
        local wx, wz = T.x + c * o[1] - s * o[2], T.z + s * o[1] + c * o[2]
        hs[i] = W.surfaceHeight(wx, wz, T.y + 1.5, 0.5)
    end
    local front, back = (hs[1] + hs[2]) / 2, (hs[3] + hs[4]) / 2
    local left, right = (hs[1] + hs[3]) / 2, (hs[2] + hs[4]) / 2
    local targetY = math.max((front + back) / 2, W.surfaceHeight(T.x, T.z, T.y + 1.5, 0.5) - 0.1)
    local dpitch = (front - back) / 6.7
    local droll = (right - left) / 3.4
    -- normal from pitch/roll in world terms
    local fx, fy, fz = U.norm3(c, dpitch, s)
    local rx, ry, rz = U.norm3(-s, droll, c)
    local tnx, tny, tnz = U.norm3(U.cross(rx, ry, rz, fx, fy, fz))
    local k = 1 - math.exp(-5 * dt)
    T.nx, T.ny, T.nz = U.norm3(T.nx + (tnx - T.nx) * k, T.ny + (tny - T.ny) * k, T.nz + (tnz - T.nz) * k)
    local prevY = T.y
    T.y = U.damp(T.y, targetY, 9, dt)
    if T.y < targetY - 0.6 then T.y = targetY - 0.6 end
    -- bumps from moving over rough ground
    local bump = math.abs(T.speed) * 0.004 * (U.noise2(T.x * 0.6, T.z * 0.6, 5) - 0.5)
    T.pitchVel = T.pitchVel - T.pitchKick * 40 * dt - T.pitchVel * 6 * dt + bump * 60 * dt
    T.pitchKick = T.pitchKick + T.pitchVel * dt

    -- tracks animation (left track faster when turning right)
    local half = 1.7
    local vL = T.speed + T.yawRate * half
    local vR = T.speed - T.yawRate * half
    T.trackVL, T.trackVR = vL, vR
    T.trackOffL = (T.trackOffL - vL * dt * 1.6) % 1000
    T.trackOffR = (T.trackOffR - vR * dt * 1.6) % 1000
    T.sprocketAng = T.sprocketAng - (vL + vR) * 0.5 * dt / 0.42
    T.leverL = U.damp(T.leverL, (steer < 0 and 1 or 0) * 0.5 + (throttle < 0 and 0.4 or 0), 10, dt)
    T.leverR = U.damp(T.leverR, (steer > 0 and 1 or 0) * 0.5 + (throttle < 0 and 0.4 or 0), 10, dt)

    -- engine rpm & gear
    if T.engineOn then
        local sp = math.abs(T.speed)
        local gear = 1
        for i, g in ipairs(T.GEARS) do if sp >= g[1] then gear = i end end
        if T.speed < -0.2 then T.gear = -1 else T.gear = (sp < 0.2 and throttle == 0) and 0 or gear end
        local g = T.GEARS[math.max(1, gear)]
        local frac = U.clamp((sp - g[1]) / (g[2] - g[1]), 0, 1)
        local targetRpm = 750 + frac * 1900 + math.abs(throttle) * 450
        if T.gear == 0 then targetRpm = 750 + math.abs(throttle) * 300 end
        T.rpm = U.damp(T.rpm, targetRpm, 4, dt)
        T.fuel = math.max(0, T.fuel - dt * (0.008 + (math.max(0, T.rpm - 700) / 2300) ^ 2 * 0.15))
        -- exhaust
        T.exhaustAcc = T.exhaustAcc + dt * (2 + T.rpm / 500)
        while T.exhaustAcc > 1 do
            T.exhaustAcc = T.exhaustAcc - 1
            for _, z in ipairs({ -0.75, 0.75 }) do
                local ex, ey, ez = f:toWorld(-4.08, 2.8, z)
                G.effects.smoke(ex, ey, ez, 0.35 + T.rpm / 6000, 0.25, 0.25, 0.27, 2.5)
            end
        end
        if G.creatures then G.creatures.noise(T.x, T.y, T.z, 35 + T.rpm / 3000 * 70, "engine") end
    else
        T.rpm = U.damp(T.rpm, T.engineStarting > 0 and 300 or 0, 3, dt)
        T.gear = 0
    end

    -- track marks and snow spray
    T.distAcc = T.distAcc + moved
    if T.distAcc > 0.7 then
        T.distAcc = 0
        for _, z in ipairs({ -1.7, 1.7 }) do
            local wx, wy, wz = f:toWorld(-2.8, 0, z)
            G.effects.trackMark(wx, wz, T.yaw)
        end
        if math.abs(T.speed) > 3 then
            for _, z in ipairs({ -1.7, 1.7 }) do
                local wx, wy, wz = f:toWorld(-3.8 * U.sign(T.speed), 0.2, z)
                G.effects.snowPuff(wx, wy, wz, 0.5)
            end
        end
    end

    -- turret traverse (hydraulic, heavy)
    local maxTrav = (T.engineOn and 0.38 or 0.12) * (0.25 + 0.75 * T.comp.turret / 100)
    if T.comp.turret <= 0 then maxTrav = 0 end
    local tr = U.clamp(T.turretInput, -maxTrav, maxTrav)
    T.turretRate = U.approach(T.turretRate, tr, dt * 1.2)
    T.turretYaw = U.wrapAngle(T.turretYaw + T.turretRate * dt)
    local gr = U.clamp(T.gunInput, -0.18, 0.18)
    T.gunRate = U.approach(T.gunRate, gr, dt * 2.0)
    T.gunPitch = U.clamp(T.gunPitch + T.gunRate * dt, -0.14, 0.3)
    if (T.gunPitch <= -0.14 and T.gunRate < 0) or (T.gunPitch >= 0.3 and T.gunRate > 0) then T.gunRate = 0 end
    T.turretInput, T.gunInput = 0, 0
    -- recoil recovery
    T.recoil = U.approach(T.recoil, 0, dt * 1.1)
    -- reload
    if T.reloadT > 0 then
        T.reloadT = T.reloadT - dt * (0.6 + 0.4 * T.comp.cannon / 100)
        if T.reloadT <= 0 then
            T.reloadT = 0
            T.loaded = T.reloading
            T.reloading = nil
            if G.audio then G.audio.play("breech_close", { tank = true }) end
        end
    end
    -- hatch animation
    T.hatchAnim = U.approach(T.hatchAnim, T.hatchOpen and 1 or 0, dt * 1.6)
    -- MG cooling
    T.mgHeat = math.max(0, T.mgHeat - dt * (T.mgJam and 9 or 6))
    if T.mgJam and T.mgHeat < 25 then T.mgJam = false end
    if T.mgReload > 0 then
        T.mgReload = T.mgReload - dt
        if T.mgReload <= 0 then
            local have = G.inventory.tank:count("mg_ammo")
            local take = math.min(150 - T.mgBelt, have)
            G.inventory.tank:remove("mg_ammo", take)
            T.mgBelt = T.mgBelt + take
            T.mgReload = 0
        end
    end
    T.flicker = T.flicker + dt
    T.updateFrames(dt)
    T.updateRacks()
end

---------------------------------------------------------------------------
-- cannon
---------------------------------------------------------------------------
function T.startReload()
    if T.loaded or T.reloadT > 0 then return false end
    local item = T.ammoSelect == "AP" and "ap_shell" or "he_shell"
    if G.inventory.tank:count(item) <= 0 then
        local other = T.ammoSelect == "AP" and "he_shell" or "ap_shell"
        if G.inventory.tank:count(other) > 0 then
            T.ammoSelect = T.ammoSelect == "AP" and "HE" or "AP"
            item = other
        else
            if G.ui then G.ui.notify("NO SHELLS IN STORAGE") end
            return false
        end
    end
    G.inventory.tank:remove(item, 1)
    T.reloading = T.ammoSelect
    T.reloadT = 4.2
    if G.audio then G.audio.play("shell_load", { tank = true }) end
    return true
end

function T.fire()
    if not T.loaded or T.destroyed then return false end
    if T.comp.cannon <= 0 then
        if G.ui then G.ui.notify("CANNON DAMAGED - REPAIR REQUIRED") end
        return false
    end
    local kind = T.loaded
    T.loaded = nil
    local gf = T.gunWorld
    local mx, my, mz = gf:toWorld(6.1, 0, 0)
    -- accuracy depends on cannon condition
    local spread = (1 - T.comp.cannon / 100) * 0.006
    local dx, dy, dz = U.norm3(gf.fx + (math.random() - 0.5) * spread, gf.fy + (math.random() - 0.5) * spread, gf.fz + (math.random() - 0.5) * spread)
    G.weapons.fireShell(kind, mx, my, mz, dx, dy, dz, "player")
    T.recoil = 1
    T.pitchVel = T.pitchVel + 0.25 * (gf.fx * T.frame.fx + gf.fz * T.frame.fz)
    G.effects.muzzleBlast(mx, my, mz, dx, dy, dz, 1.0)
    -- blast blows snow around the tank
    for i = 1, 10 do
        local a = math.random() * 6.28
        G.effects.snowPuff(mx - dx * 3 + math.cos(a) * 3, T.y + 0.3, mz - dz * 3 + math.sin(a) * 3, 1.5)
    end
    local inside = G.player and G.player.frameName == "tank"
    if G.camera then G.camera.shake(inside and 1.2 or 0.7) end
    if G.audio then G.audio.play("cannon", { x = mx, y = my, z = mz, big = true }) end
    if inside and G.audio then G.audio.ring(1.0) end
    if G.creatures then G.creatures.noise(mx, my, mz, 450, "cannon") end
    -- brass case ejected inside
    G.effects.casing("tank", -0.6, 2.4, 0.2, true)
    T.flicker = 0
    T.lightFlick = 0.4
    return true
end

---------------------------------------------------------------------------
-- damage
---------------------------------------------------------------------------
local COMP_NAMES = { engine = "ENGINE", trackL = "LEFT TRACK", trackR = "RIGHT TRACK", turret = "TURRET", cannon = "CANNON", hull = "HULL" }
T.COMP_NAMES = COMP_NAMES

function T.damage(amount, kind, lx, ly, lz)
    if T.destroyed then return end
    local comp = "hull"
    if lx then
        if ly > 2.3 then
            comp = (lx > 1.2 and math.random() < 0.6) and "cannon" or "turret"
            local tx, ty, tz = T.turretLocal:toLocal(lx, ly, lz)
            if tx > 1.3 and math.abs(tz) < 0.7 then comp = "cannon" end
        elseif lx < -2.2 then comp = "engine"
        elseif ly < 1.4 and math.abs(lz) > 1.3 then comp = lz > 0 and "trackR" or "trackL"
        end
        -- frontal armour is much stronger
        if lx > 2.8 and kind ~= "collision" then amount = amount * 0.45 end
    elseif kind == "collision" then
        comp = math.random() < 0.5 and "hull" or (math.random() < 0.5 and "trackL" or "trackR")
    elseif kind == "melee" then
        local r = math.random()
        comp = r < 0.4 and "trackL" or (r < 0.8 and "trackR" or "hull")
    end
    T.comp[comp] = math.max(0, T.comp[comp] - amount)
    if comp ~= "hull" then T.comp.hull = math.max(0, T.comp.hull - amount * 0.35) end
    T.lightFlick = 0.6
    local inside = G.player and G.player.frameName == "tank"
    if inside and G.camera then G.camera.shake(math.min(1.5, amount / 25)) end
    if amount > 8 and G.ui then
        G.ui.notify(COMP_NAMES[comp] .. " DAMAGED (" .. math.floor(T.comp[comp]) .. "%)")
    end
    if comp == "engine" and T.comp.engine < 15 and T.engineOn and math.random() < 0.5 then T.engineOn = false end
    if T.comp.hull <= 0 then
        T.destroyed = true
        T.engineOn = false
        local x, y, z = T.frame:toWorld(0, 2, 0)
        G.effects.explosion(x, y, z, 3)
        G.world.fires[#G.world.fires + 1] = { x = x, y = y, z = z, r = 6, tank = true }
        if G.audio then G.audio.play("explosion", { x = x, y = y, z = z, big = true }) end
        if G.game then G.game.tankDestroyed() end
    end
    if G.missions then G.missions.event("tank_damaged") end
end

function T.repair(comp, amount)
    T.comp[comp] = math.min(100, T.comp[comp] + amount)
end

function T.worstComponent()
    local worst, val = nil, 100
    for k, v in pairs(T.comp) do if v < val then worst, val = k, v end end
    return worst, val
end

---------------------------------------------------------------------------
-- racks (visual ammo)
---------------------------------------------------------------------------
function T.updateRacks()
    local ap, he = G.inventory.tank:count("ap_shell"), G.inventory.tank:count("he_shell")
    local key = ap * 1000 + he
    if key ~= T.rackKey then
        T.rackKey = key
        T.models.racks = TI.buildRacks(math.min(ap, 32), math.min(he, 32 - math.min(ap, 32)))
    end
end

---------------------------------------------------------------------------
-- lights
---------------------------------------------------------------------------
function T.addLights(list)
    local flick = 1
    if T.lightFlick and T.lightFlick > 0 then
        T.lightFlick = T.lightFlick - 1 / 60
        flick = (math.random() > 0.5) and 0.2 or 1
    end
    if T.lightsOn and not T.destroyed then
        for _, l in ipairs(TI.LAMPS) do
            local x, y, z
            if l.frame == "turret" then x, y, z = T.turretWorld:toWorld(l[1], l[2], l[3])
            else x, y, z = T.frame:toWorld(l[1], l[2], l[3]) end
            local n = 0.94 + math.sin(T.flicker * 23 + l[1] * 7) * 0.03 + math.sin(T.flicker * 7.1) * 0.03
            list[#list + 1] = { x, y, z, l.radius, l.r, l.g, l.b, l.i * n * flick }
        end
    end
    -- cold daylight pouring through the open hatch
    if T.hatchAnim > 0.05 then
        local x, y, z = T.turretWorld:toWorld(TM.CUPOLA[1], 0.6, TM.CUPOLA[3])
        local e = G.environment
        local day = e and e.daylight or 1
        list[#list + 1] = { x, y, z, 3.4, 0.55, 0.65, 0.85, T.hatchAnim * (0.35 + 0.65 * day) }
    end
    if T.headlights and not T.destroyed then
        for _, d in ipairs({ 7, 15 }) do
            local x, y, z = T.frame:toWorld(3.4 + d, 0.8, 0)
            list[#list + 1] = { x, y, z, d * 0.9 + 4, 1.0, 0.92, 0.75, 1.4 }
        end
    end
    if T.radioOn then
        local x, y, z = T.frame:toWorld(2.4, 1.8, 1.25)
        list[#list + 1] = { x, y, z, 0.9, 1.0, 0.7, 0.3, 0.6 }
    end
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------
local function fm(frame, key) return frame:matrix(T.mats[key]) end

function T.draw(cam)
    local tankM = fm(T.frame, "tank")
    local m = T.models
    local dmgTint = T.destroyed and { 0.25, 0.22, 0.2, 1 } or nil
    local dparams = dmgTint and { tint = dmgTint } or nil
    R.drawModel(m.hull, tankM, dparams)
    R.drawModel(m.trackL, tankM, { uv = { T.trackOffL, 0 }, tint = dmgTint })
    R.drawModel(m.trackR, tankM, { uv = { T.trackOffR, 0 }, tint = dmgTint })
    R.drawModel(m.wheelsL, tankM, dparams)
    R.drawModel(m.wheelsR, tankM, dparams)
    for _, sp in ipairs({ { "sprL", -1.72 }, { "sprR", 1.72 } }) do
        local tf = T.tmpFrame
        tf:setYawPitchRoll(0, T.sprocketAng, 0)
        tf.px, tf.py, tf.pz = 3.32, 0.72, sp[2]
        local wf = T.frame:compose(tf, M3.frame())
        R.drawModel(m.sprocket, wf:matrix(T.mats[sp[1]]), dparams)
    end
    local turM = fm(T.turretWorld, "turret")
    R.drawModel(m.turret, turM, dparams)
    local gunM = fm(T.gunWorld, "gun")
    -- the barrel is outside the sight's field of view; skip it while looking through the optic
    local optic = G.stations and G.stations.gunner.optic and G.player.station == G.stations.gunner
    if not optic then R.drawModel(m.gun, gunM, dparams) end
    R.drawModel(m.hatch, fm(T.hatchWorld, "hatch"), dparams)
    local mgM = fm(T.mgWorld, "mg")
    R.drawModel(m.mgExt, mgM, dparams)
    -- interior only when the camera is close
    local d = U.dist3(cam.x, cam.y, cam.z, T.x, T.y + 1.5, T.z)
    if d < 14 then
        local ip = { interior = 1 }
        R.drawModel(m.hullInt, tankM, ip)
        R.drawModel(m.turretInt, turM, ip)
        R.drawModel(m.breech, gunM, ip)
        R.drawModel(m.mgInt, mgM, ip)
        if m.racks then R.drawModel(m.racks, tankM, ip) end
        for i, lv in ipairs({ { "levL", -0.98, T.leverL }, { "levR", -0.52, T.leverR } }) do
            local tf = T.tmpFrame
            tf:setYawPitchRoll(0, -0.25 - lv[3] * 0.5, 0)
            local ux, uy, uz = tf.ux, tf.uy, tf.uz
            tf:setYawPitchRoll(0, 0, 0)
            -- rotate around z: forward/up swap
            local a = lv[3] * 0.5 + 0.2
            tf.fx, tf.fy, tf.fz = math.cos(a), -math.sin(a), 0
            tf.ux, tf.uy, tf.uz = math.sin(a), math.cos(a), 0
            tf.rx, tf.ry, tf.rz = 0, 0, 1
            tf.px, tf.py, tf.pz = 2.62, 0.8, lv[2]
            local wf = T.frame:compose(tf, M3.frame())
            R.drawModel(m.lever, wf:matrix(T.mats[lv[1]]), ip)
        end
        if T.lightsOn then
            R.drawModel(m.bulbs, tankM, { emissive = 1 })
            R.drawModel(m.turretBulb, turM, { emissive = 1 })
        end
        if T.radioOn then R.drawModel(m.radioDial, tankM, { emissive = 1 }) end
    end
end

-- point in tank local space -> is it inside the hull volume (for projectiles)
function T.containsLocal(lx, ly, lz)
    return lx > -3.95 and lx < 3.4 and ly > 0.3 and ly < 2.35 and math.abs(lz) < 1.98
end

-- collider sets for an outside observer (player on foot, projectiles)
function T.exteriorSets() return T.extSet, T.turretExtSet, T.gunExtSet end

return T
