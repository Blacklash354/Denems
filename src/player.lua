-- First-person player: movement in world space or inside the tank (tank-local space),
-- ladders, seats (stations), interaction, footsteps and survival hooks.
local U = require("src.utils")
local P = require("src.physics")
local I = require("src.interaction")
local TM = require("src.tank_model")

local Pl = {}
local G

local STAND, CROUCH = 1.75, 1.1
local GRAV = 14
local RADIUS = 0.28
local STEP = 0.45

function Pl.init(game)
    G = game
    Pl.reset()
end

function Pl.reset()
    Pl.frameName = "tank"
    -- start inside the fighting compartment, facing forward
    Pl.x, Pl.y, Pl.z = 0.6, 0.62, 0.7
    Pl.vx, Pl.vy, Pl.vz = 0, 0, 0
    Pl.yaw, Pl.pitch = 0.3, -0.05
    Pl.height = STAND
    Pl.crouch = false
    Pl.mode = "walk"
    Pl.grounded = true
    Pl.health, Pl.stamina, Pl.warmth, Pl.radiation = 100, 100, 100, 0
    Pl.bob, Pl.bobAmt, Pl.stepAcc, Pl.stepSide = 0, 0, 0, 1
    Pl.flashlight = false
    Pl.battery = 100
    Pl.kneel = 0
    Pl.landKick = 0
    Pl.hurtFlash = 0
    Pl.platform = nil
    Pl.deadT = 0
    Pl.sprinting = false
    Pl.space = "interior"
    Pl.lastSafe = nil
end

function Pl.serialize()
    return { frameName = Pl.frameName, x = Pl.x, y = Pl.y, z = Pl.z, yaw = Pl.yaw, pitch = Pl.pitch,
             health = Pl.health, stamina = Pl.stamina, warmth = Pl.warmth, radiation = Pl.radiation,
             battery = Pl.battery, flashlight = Pl.flashlight }
end

function Pl.load(s)
    Pl.reset()
    for k, v in pairs(s) do Pl[k] = v end
    Pl.mode = "walk"
    Pl.height = STAND
end

---------------------------------------------------------------------------
-- collision sets for the current frame
---------------------------------------------------------------------------
function Pl.collisionSets()
    local T = G.tank
    if Pl.frameName == "tank" then
        return { T.intSet, T.turretIntSet }
    end
    local sets = { G.world.staticSet, T.extSet, T.turretExtSet, T.gunExtSet }
    if G.enemies then G.enemies.addSets(sets) end
    return sets
end

function Pl.inUnderground()
    if Pl.frameName ~= "world" then return nil end
    return G.world.isUnderground(Pl.x, Pl.y + 1, Pl.z)
end

-- world position of the eye
function Pl.eyeWorld()
    local ex, ey, ez = Pl.x, Pl.y + Pl.height - 0.12, Pl.z
    if Pl.frameName == "tank" then return G.tank.frame:toWorld(ex, ey, ez) end
    return ex, ey, ez
end

function Pl.feetWorld()
    if Pl.frameName == "tank" then return G.tank.frame:toWorld(Pl.x, Pl.y, Pl.z) end
    return Pl.x, Pl.y, Pl.z
end

---------------------------------------------------------------------------
-- ladders
---------------------------------------------------------------------------
Pl.LADDERS = {
    interior = {
        frameName = "tank", sub = "turret",
        bottom = { TM.CUPOLA[1], -1.73, TM.CUPOLA[3] }, top = { TM.CUPOLA[1], 1.15, TM.CUPOLA[3] },
        faceYaw = math.pi, blockT = 0.66, speed = 0.45,
    },
    rear = {
        frameName = "world", sub = "tank",
        bottom = { -4.45, 0, -1.2 }, top = { -4.45, 2.38, -1.2 }, faceYaw = 0, speed = 0.55,
    },
}

local function ladderPoint(L, t)
    local b, tp = L.bottom, L.top
    local lx, ly, lz = U.lerp(b[1], tp[1], t), U.lerp(b[2], tp[2], t), U.lerp(b[3], tp[3], t)
    local T = G.tank
    if L.sub == "turret" then return T.turretLocal:toWorld(lx, ly, lz) end   -- tank-local
    return T.frame:toWorld(lx, ly, lz)                                         -- world
end

function Pl.startLadder(name, t)
    local L = Pl.LADDERS[name]
    local ox, oy, oz = Pl.eyeWorld()
    Pl.mode = "ladder"
    Pl.ladder = L
    Pl.ladderName = name
    Pl.ladderT = t
    Pl.frameName = L.frameName
    Pl.vx, Pl.vy, Pl.vz = 0, 0, 0
    Pl.height = STAND
    local fy = L.faceYaw
    if L.sub == "turret" then fy = fy + G.tank.turretYaw elseif L.frameName == "world" then fy = fy + G.tank.yaw end
    Pl.yaw = fy
    Pl.pitch = t > 0.5 and -0.4 or 0.3
    Pl.x, Pl.y, Pl.z = ladderPoint(L, t)
    G.camera.smoothFrom(ox, oy, oz)
    if G.audio then G.audio.play("ladder", { tank = Pl.frameName == "tank" }) end
end

local function placeWalking(frameName, x, y, z, yaw)
    local ox, oy, oz = Pl.eyeWorld()
    Pl.frameName = frameName
    Pl.x, Pl.y, Pl.z = x, y, z
    if yaw then Pl.yaw = yaw end
    Pl.mode = "walk"
    Pl.vx, Pl.vy, Pl.vz = 0, 0, 0
    Pl.grounded = false
    Pl.platform = nil
    G.camera.smoothFrom(ox, oy, oz)
end
Pl.placeWalking = placeWalking

local function updateLadder(dt)
    local L = Pl.ladder
    local T = G.tank
    local input = 0
    if love.keyboard.isDown("w") then input = 1 elseif love.keyboard.isDown("s") then input = -1 end
    local len = math.abs(L.top[2] - L.bottom[2])
    local before = Pl.ladderT
    Pl.ladderT = Pl.ladderT + input * dt * 1.6 / len
    if Pl.ladderName == "interior" and not T.hatchOpen and Pl.ladderT > L.blockT then
        Pl.ladderT = L.blockT
    end
    if math.floor(before * len / 0.33) ~= math.floor(Pl.ladderT * len / 0.33) and G.audio then
        G.audio.play("step_metal", { tank = Pl.frameName == "tank", volume = 0.5 })
    end
    if Pl.ladderT >= 1 then
        if Pl.ladderName == "interior" then
            -- climb out through the hatch onto the turret roof
            local x, y, z = T.turretWorld:toWorld(-0.25, 1.12, -0.45)
            local wyaw = T.yaw + T.turretYaw
            placeWalking("world", x, y + 0.02, z, wyaw + math.pi)
            Pl.platform = nil
            if G.missions then G.missions.event("exited_tank") end
            if G.audio then G.audio.play("wind_gust", {}) end
        else
            local x, y, z = T.frame:toWorld(-3.45, 2.42, -1.2)
            placeWalking("world", x, y + 0.02, z, T.yaw)
        end
        return
    elseif Pl.ladderT <= 0 then
        if Pl.ladderName == "interior" then
            local x, y, z = T.turretLocal:toWorld(TM.CUPOLA[1] + 0.35, -1.73, TM.CUPOLA[3])
            placeWalking("tank", x, y, z, Pl.yaw - T.turretYaw * 0)
        else
            local x, y, z = T.frame:toWorld(-4.9, 0, -1.2)
            placeWalking("world", x, G.world.height(x, z), z, T.yaw + math.pi)
        end
        return
    end
    Pl.x, Pl.y, Pl.z = ladderPoint(L, Pl.ladderT)
    Pl.y = Pl.y - 1.2   -- eye roughly 0.4 m above the current rung
    if Pl.ladderName == "interior" then Pl.y = Pl.y + 0.15 end
end

---------------------------------------------------------------------------
-- seats
---------------------------------------------------------------------------
function Pl.enterSeat(station)
    local ox, oy, oz = Pl.eyeWorld()
    Pl.mode = "seat"
    Pl.station = station
    Pl.frameName = "tank"
    station.enter()
    G.camera.smoothFrom(ox, oy, oz)
    if G.audio then G.audio.play("seat", { tank = true }) end
end

function Pl.leaveSeat()
    local st = Pl.station
    if not st then return end
    local ox, oy, oz = G.camera.x, G.camera.y, G.camera.z
    local x, y, z, yaw = st.exit()
    Pl.station = nil
    placeWalking("tank", x, y, z, yaw)
    Pl.grounded = true
    G.camera.smoothFrom(ox, oy, oz)
end

---------------------------------------------------------------------------
-- main update
---------------------------------------------------------------------------
local function wishInput()
    local f, r = 0, 0
    local k = love.keyboard.isDown
    if k("w") then f = f + 1 end
    if k("s") then f = f - 1 end
    if k("d") then r = r + 1 end
    if k("a") then r = r - 1 end
    return f, r
end

local function groundSurfaceType()
    if Pl.frameName == "tank" then return "metal" end
    if Pl.groundBox then
        if Pl.groundBox.tank then return "metal" end
        return "hard"
    end
    return "snow"
end

local function footstep()
    local t = groundSurfaceType()
    local sprint = Pl.sprinting
    local vol = Pl.crouch and 0.35 or (sprint and 1 or 0.7)
    if G.audio then
        if t == "snow" then G.audio.play("step_snow", { volume = vol })
        elseif t == "metal" then G.audio.play("step_metal", { volume = vol * 0.8, tank = Pl.frameName == "tank" })
        else G.audio.play("step_hard", { volume = vol }) end
    end
    if t == "snow" and Pl.frameName == "world" and not Pl.inUnderground() then
        local side = Pl.stepSide * 0.18
        Pl.stepSide = -Pl.stepSide
        local fx, fz = math.cos(Pl.yaw), math.sin(Pl.yaw)
        G.effects.footprint(Pl.x - fz * side, Pl.z + fx * side, Pl.yaw)
    end
    if G.creatures and Pl.frameName == "world" then
        G.creatures.noise(Pl.x, Pl.y, Pl.z, Pl.crouch and 3 or (sprint and 16 or 8), "steps")
    end
end

function Pl.update(dt)
    local T = G.tank
    if Pl.mode == "dead" then
        Pl.deadT = Pl.deadT + dt
        return
    end
    Pl.hurtFlash = math.max(0, Pl.hurtFlash - dt * 2)
    if Pl.mode == "ladder" then
        updateLadder(dt)
    elseif Pl.mode == "seat" then
        Pl.station.update(dt)
        -- seated in the tank: keep position at the seat
        local x, y, z = Pl.station.seatPos()
        Pl.x, Pl.y, Pl.z = x, y, z
    elseif Pl.mode == "walk" then
        Pl.updateWalk(dt)
    end
    Pl.space = (Pl.frameName == "tank") and "interior" or "exterior"
    -- interaction targeting
    local occ = nil
    if Pl.frameName == "world" then occ = { G.world.staticSet } end
    if Pl.mode == "walk" or Pl.mode == "ladder" then
        I.update(dt, G.camera, Pl.space, occ, love.keyboard.isDown("e"))
    else
        I.current = nil
        I.holding = nil
    end
    Pl.kneel = U.damp(Pl.kneel, I.holding and I.holding.kneel and 1 or 0, 6, dt)
    -- flashlight battery
    if Pl.flashlight then
        Pl.battery = math.max(0, Pl.battery - dt * 0.12)
        if Pl.battery <= 0 then Pl.flashlight = false if G.ui then G.ui.notify("FLASHLIGHT BATTERY DEAD") end end
    end
end

function Pl.updateWalk(dt)
    local T = G.tank
    local W = G.world
    -- carried by the tank when standing on it
    if Pl.frameName == "world" and Pl.platform then
        local lp = Pl.platform
        local nx, ny, nz = T.frame:toWorld(lp[1], lp[2], lp[3])
        Pl.x, Pl.y, Pl.z = nx, ny, nz
        Pl.yaw = Pl.yaw + U.angleTo(lp[4], T.yaw)
    end
    local f, r = wishInput()
    local inTank = Pl.frameName == "tank"
    local crouchKey = love.keyboard.isDown("c") or love.keyboard.isDown("lctrl")
    Pl.crouch = crouchKey
    local wantSprint = love.keyboard.isDown("lshift") and f > 0 and not Pl.crouch and not inTank and Pl.stamina > 5
    local speed = inTank and 1.9 or (Pl.crouch and 1.6 or 3.1)
    Pl.sprinting = false
    if wantSprint and (f ~= 0 or r ~= 0) then
        speed = 5.4
        Pl.sprinting = true
        Pl.stamina = math.max(0, Pl.stamina - dt * 14)
    end
    if Pl.frameName == "world" and not Pl.groundBox and W.roadDistance(Pl.x, Pl.z) > 6 then speed = speed * 0.9 end
    if Pl.warmth < 25 then speed = speed * 0.85 end
    if G.weapons and G.weapons.aiming then speed = speed * 0.6 end
    local l = math.sqrt(f * f + r * r)
    if l > 0 then f, r = f / l, r / l end
    local c, s = math.cos(Pl.yaw), math.sin(Pl.yaw)
    local wx, wz = (c * f - s * r) * speed, (s * f + c * r) * speed
    local accel = Pl.grounded and 12 or 2.5
    Pl.vx = U.damp(Pl.vx, wx, accel, dt)
    Pl.vz = U.damp(Pl.vz, wz, accel, dt)

    -- headroom: auto-crouch under low ceilings (the driver's compartment is cramped)
    local sets = Pl.collisionSets()
    local ceil = P.ceilingHeight(sets, Pl.x, Pl.y, Pl.z, RADIUS)
    local wantH = Pl.crouch and CROUCH or STAND
    local room = ceil - Pl.y - 0.06
    local target = math.max(1.0, math.min(wantH, room))
    Pl.height = U.damp(Pl.height, target, 12, dt)
    if Pl.height > room and room > 1.0 then Pl.height = room end

    -- horizontal move + collision
    local nx, nz = Pl.x + Pl.vx * dt, Pl.z + Pl.vz * dt
    nx, nz = P.pushOut(sets, nx, Pl.y, nz, RADIUS, Pl.height, STEP)
    -- check headroom at the new position, refuse to squeeze below 1.0 m
    local c2 = P.ceilingHeight(sets, nx, Pl.y, nz, RADIUS)
    if c2 - Pl.y < 1.05 then nx, nz = Pl.x, Pl.z end
    if Pl.frameName == "world" then
        nx, nz = U.clamp(nx, -W.LIMIT - 30, W.LIMIT + 30), U.clamp(nz, -W.LIMIT - 30, W.LIMIT + 30)
    end
    local moved = U.dist2(Pl.x, Pl.z, nx, nz)
    Pl.x, Pl.z = nx, nz

    -- vertical
    if love.keyboard.isDown("space") and Pl.grounded and Pl.stamina > 8 and not Pl.jumpLatch then
        Pl.vy = 4.3
        Pl.stamina = Pl.stamina - 8
        Pl.grounded = false
        Pl.jumpLatch = true
        Pl.platform = nil
    end
    if not love.keyboard.isDown("space") then Pl.jumpLatch = false end
    Pl.vy = Pl.vy - GRAV * dt
    local ny = Pl.y + Pl.vy * dt
    -- ceiling bump
    if Pl.vy > 0 then
        local cc = P.ceilingHeight(sets, Pl.x, Pl.y, Pl.z, RADIUS)
        if ny + Pl.height > cc then ny = cc - Pl.height Pl.vy = 0 end
    end
    local ground, gbox = P.groundHeight(sets, Pl.x, math.max(ny, Pl.y), Pl.z, RADIUS, STEP)
    local under = Pl.inUnderground()
    if Pl.frameName == "world" and not under then
        local th = W.height(Pl.x, Pl.z)
        if th > ground then ground, gbox = th, nil end
        -- safety: never fall through the terrain
        if ny < th - 1.5 then ny = th end
    end
    local wasGrounded = Pl.grounded
    if ny <= ground + 0.001 then
        if not wasGrounded and Pl.vy < -9 then
            local dmg = (-Pl.vy - 9) * 9
            Pl.hurt(dmg, "fall")
        end
        if not wasGrounded and Pl.vy < -3 then
            Pl.landKick = math.min(0.12, -Pl.vy * 0.012)
            footstep()
        end
        -- smooth step-up
        if ground - Pl.y > 0.05 and wasGrounded then ny = U.damp(Pl.y, ground, 25, dt) else ny = ground end
        Pl.vy = 0
        Pl.grounded = true
        Pl.groundBox = gbox
    else
        -- snap down small steps while walking
        if wasGrounded and Pl.vy <= 0 and Pl.y - ground < STEP and Pl.y - ground > 0 then
            ny = ground
            Pl.vy = 0
            Pl.grounded = true
            Pl.groundBox = gbox
        else
            Pl.grounded = false
        end
    end
    Pl.y = ny
    -- platform tracking on the tank
    if Pl.frameName == "world" and Pl.grounded and Pl.groundBox and Pl.groundBox.tank then
        local lx, ly, lz = T.frame:toLocal(Pl.x, Pl.y, Pl.z)
        Pl.platform = { lx, ly, lz, T.yaw }
    else
        Pl.platform = nil
    end
    -- stamina regen
    if not Pl.sprinting then Pl.stamina = math.min(100, Pl.stamina + dt * (Pl.grounded and 11 or 4)) end
    -- head bob & footsteps
    local hs = math.sqrt(Pl.vx * Pl.vx + Pl.vz * Pl.vz)
    if Pl.grounded and hs > 0.3 then
        Pl.bob = Pl.bob + dt * hs * 2.2
        Pl.bobAmt = U.damp(Pl.bobAmt, math.min(1, hs / 4), 6, dt)
        Pl.stepAcc = Pl.stepAcc + moved
        local stepLen = Pl.sprinting and 0.95 or 0.72
        if Pl.stepAcc > stepLen then
            Pl.stepAcc = 0
            footstep()
        end
    else
        Pl.bobAmt = U.damp(Pl.bobAmt, 0, 6, dt)
    end
    Pl.landKick = U.damp(Pl.landKick, 0, 8, dt)
    -- remember last safe position outside
    if Pl.frameName == "world" and Pl.grounded then Pl.lastSafe = { Pl.x, Pl.y, Pl.z } end
end

function Pl.hurt(amount, kind)
    if Pl.mode == "dead" or (G.game and G.game.godMode) then return end
    Pl.health = Pl.health - amount
    Pl.hurtFlash = math.min(1, Pl.hurtFlash + amount / 30)
    if G.camera then G.camera.shake(math.min(1, amount / 30)) end
    if G.audio then G.audio.play("hurt", { volume = 0.8 }) end
    if Pl.health <= 0 then
        Pl.health = 0
        Pl.die(kind)
    end
end

function Pl.die(kind)
    if Pl.mode == "seat" and Pl.station then Pl.station.exit() Pl.station = nil end
    Pl.deadEye = Pl.height - 0.12
    if Pl.frameName == "tank" then Pl.y = math.max(Pl.y, 0.62) end
    Pl.mode = "dead"
    Pl.deadT = 0
    Pl.deathCause = kind
    if G.game then G.game.playerDied(kind) end
end

---------------------------------------------------------------------------
-- camera
---------------------------------------------------------------------------
function Pl.updateCamera(cam)
    local T = G.tank
    if Pl.mode == "seat" and Pl.station then
        Pl.station.camera(cam)
        return
    end
    if Pl.mode == "dead" then G.camera.fov = G.camera.baseFov
    else G.camera.fov = G.weapons.fov(G.camera.baseFov) end
    local bobY = math.abs(math.sin(Pl.bob * math.pi)) * 0.05 * Pl.bobAmt
    local bobX = math.sin(Pl.bob * math.pi) * 0.03 * Pl.bobAmt
    local eye = Pl.height - 0.12 - Pl.kneel * 0.75 + bobY - Pl.landKick
    if Pl.mode == "dead" then eye = math.max(0.35, (Pl.deadEye or eye) - Pl.deadT * 1.6) end
    local cy, sy = math.cos(Pl.yaw), math.sin(Pl.yaw)
    local pitch = Pl.pitch
    local roll = 0
    if Pl.mode == "dead" then roll = math.min(1.2, Pl.deadT * 0.9) end
    if Pl.warmth < 20 then roll = roll + math.sin(love.timer.getTime() * 30) * 0.004 * (20 - Pl.warmth) / 20 end
    local cp, sp = math.cos(pitch), math.sin(pitch)
    local fx, fy, fz = cy * cp, sp, sy * cp
    local rx, ry, rz = -sy, 0, cy
    local ux, uy, uz = U.cross(rx, ry, rz, fx, fy, fz)
    if roll ~= 0 then
        local cr, sr = math.cos(roll), math.sin(roll)
        ux, uy, uz = ux * cr + rx * sr, uy * cr + ry * sr, uz * cr + rz * sr
    end
    local px, py, pz = Pl.x + rx * bobX, Pl.y + eye, Pl.z + rz * bobX
    if Pl.frameName == "tank" then
        local f = T.frame
        px, py, pz = f:toWorld(px, py, pz)
        fx, fy, fz = f:dirToWorld(fx, fy, fz)
        ux, uy, uz = f:dirToWorld(ux, uy, uz)
    end
    G.camera.set(px, py, pz, fx, fy, fz, ux, uy, uz)
end

function Pl.mousemoved(dx, dy, sens)
    if Pl.mode == "dead" then return end
    if Pl.mode == "seat" and Pl.station then
        Pl.station.mousemoved(dx, dy, sens)
        return
    end
    local zoom = 1 - (G.weapons and G.weapons.aimT or 0) * 0.45
    if G.weapons then G.weapons.look(dx, dy) end
    Pl.yaw = Pl.yaw + dx * sens * zoom
    Pl.pitch = U.clamp(Pl.pitch - dy * sens * zoom, -1.5, 1.5)
end

return Pl
