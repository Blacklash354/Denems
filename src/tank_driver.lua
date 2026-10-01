-- Driver's position: first-person view through the armoured vision slit.
local U = require("src.utils")
local D = { name = "driver" }
local G

function D.init(game) G = game end

function D.enter()
    D.lookYaw, D.lookPitch = 0, -0.02
    D.orbitYaw, D.orbitPitch = 0, 0.28
    D.camX = nil
    G.tank.driver = true
    if G.missions then G.missions.event("driver_seat") end
end

function D.exit()
    local T = G.tank
    T.driver = false
    D.third = false
    T.throttle, T.steer = 0, 0
    return 1.75, 0.62, -0.65, math.pi * 0.9
end

function D.seatPos() return 2.2, 0.62, -0.75 end

function D.update(dt)
    local T = G.tank
    local k = love.keyboard.isDown
    local th = 0
    if k("w") then th = 1 elseif k("s") then th = -1 end
    if k("lshift") and th > 0 then th = 1 elseif th > 0 then th = 0.65 end
    local st = 0
    if k("a") then st = -1 elseif k("d") then st = 1 end
    T.throttle = U.damp(T.throttle, th, 3, dt)
    if th == 0 and math.abs(T.throttle) < 0.05 then T.throttle = 0 end
    T.steer = st
    if k("space") then T.throttle = 0 T.speed = U.approach(T.speed, 0, dt * 3.5) end
end

function D.keypressed(key)
    local T = G.tank
    if key == "f" then
        if T.engineOn then T.stopEngine() else T.startEngine() end
        return true
    elseif key == "v" then
        D.third = not D.third
        D.camX = nil
        return true
    elseif key == "l" then
        T.headlights = not T.headlights
        if G.audio then G.audio.play("switch", { tank = true }) end
        return true
    end
end

function D.mousepressed(b) end

function D.mousemoved(dx, dy, sens)
    if D.third then
        D.idle = 0
        D.orbitYaw = D.orbitYaw + dx * sens
        D.orbitPitch = U.clamp(D.orbitPitch + dy * sens, -0.15, 1.1)
        return
    end
    D.lookYaw = U.clamp(D.lookYaw + dx * sens, -0.7, 0.7)
    D.lookPitch = U.clamp(D.lookPitch - dy * sens, -0.35, 0.3)
end

-- chase camera: orbits the hull, eases in behind it, never dips below the ground
local function chaseCamera(dt)
    local T = G.tank
    local f = T.frame
    local hx, hz = f.fx, f.fz
    local hl = math.sqrt(hx * hx + hz * hz)
    if hl < 1e-4 then hx, hz, hl = 1, 0, 1 end
    local hy = math.atan2(hz / hl, hx / hl)
    -- with the mouse idle the orbit swings back behind the hull while driving
    D.idle = (D.idle or 0) + dt
    if D.idle > 1.5 and math.abs(T.speed) > 1 then
        D.orbitYaw = U.damp(D.orbitYaw, 0, 1.2, dt)
    end
    local yaw = hy + D.orbitYaw
    local pitch = D.orbitPitch
    local dist = 11.5
    local tx, ty, tz = T.x, T.y + 2.4, T.z
    local dx, dz = -math.cos(yaw) * math.cos(pitch), -math.sin(yaw) * math.cos(pitch)
    local px, py, pz = tx + dx * dist, ty + math.sin(pitch) * dist, tz + dz * dist
    local gy = G.world.height(px, pz) + 0.8
    if py < gy then py = gy end
    if not D.camX then
        D.camX, D.camY, D.camZ = px, py, pz
    else
        local k = 1 - math.exp(-dt * 10)
        D.camX = D.camX + (px - D.camX) * k
        D.camY = D.camY + (py - D.camY) * k
        D.camZ = D.camZ + (pz - D.camZ) * k
    end
    local fx, fy, fz = U.norm3(tx - D.camX, ty - D.camY, tz - D.camZ)
    local rx, ry, rz = U.norm3(U.cross(fx, fy, fz, 0, 1, 0))
    local ux, uy, uz = U.cross(rx, ry, rz, fx, fy, fz)
    G.camera.set(D.camX, D.camY, D.camZ, fx, fy, fz, ux, uy, uz)
    G.camera.fov = G.camera.baseFov + math.min(math.abs(T.speed) * 0.006, 0.12)
end

function D.camera(cam)
    if D.third then
        local now = love.timer.getTime()
        local dt = math.min(now - (D.lastT or now), 0.1)
        D.lastT = now
        return chaseCamera(dt)
    end
    local T = G.tank
    local f = T.frame
    -- eye behind the slit, slight engine vibration
    local vib = T.engineOn and (math.sin(love.timer.getTime() * 60) * 0.002 * (T.rpm / 2000)) or 0
    local ex, ey, ez = 2.74 + vib, 2.0 + vib, -0.75
    local cy, sy = math.cos(D.lookYaw), math.sin(D.lookYaw)
    local cp, sp = math.cos(D.lookPitch), math.sin(D.lookPitch)
    local fx, fy, fz = cy * cp, sp, sy * cp
    local rx, ry, rz = -sy, 0, cy
    local ux, uy, uz = U.cross(rx, ry, rz, fx, fy, fz)
    local px, py, pz = f:toWorld(ex, ey, ez)
    fx, fy, fz = f:dirToWorld(fx, fy, fz)
    ux, uy, uz = f:dirToWorld(ux, uy, uz)
    G.camera.set(px, py, pz, fx, fy, fz, ux, uy, uz)
    G.camera.fov = G.camera.baseFov
end

return D
