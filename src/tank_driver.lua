-- Driver's position: first-person view through the armoured vision slit.
local U = require("src.utils")
local D = { name = "driver" }
local G

function D.init(game) G = game end

function D.enter()
    D.lookYaw, D.lookPitch = 0, -0.02
    G.tank.driver = true
    if G.missions then G.missions.event("driver_seat") end
end

function D.exit()
    local T = G.tank
    T.driver = false
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
    elseif key == "l" then
        T.headlights = not T.headlights
        if G.audio then G.audio.play("switch", { tank = true }) end
        return true
    end
end

function D.mousepressed(b) end

function D.mousemoved(dx, dy, sens)
    D.lookYaw = U.clamp(D.lookYaw + dx * sens, -0.7, 0.7)
    D.lookPitch = U.clamp(D.lookPitch - dy * sens, -0.35, 0.3)
end

function D.camera(cam)
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
