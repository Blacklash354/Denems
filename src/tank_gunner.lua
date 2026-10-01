-- Gunner's position: turret traverse, gun elevation, TZF optic, loading and firing.
local U = require("src.utils")
local Gn = { name = "gunner" }
local G

function Gn.init(game) G = game end

function Gn.enter()
    local T = G.tank
    Gn.targetYaw = T.turretYaw
    Gn.targetPitch = T.gunPitch
    Gn.optic = false
    Gn.zoom = 1
    Gn.lookYaw, Gn.lookPitch = 0, 0
    if G.missions then G.missions.event("gunner_seat") end
end

function Gn.exit()
    Gn.optic = false
    G.renderer.fx.optic = 0
    local T = G.tank
    -- stand up next to the gunner seat (turret-local -> tank-local)
    local x, y, z = T.turretLocal:toWorld(0.05, -1.73, -0.25)
    return x, 0.62, z, T.turretYaw + math.pi
end

function Gn.seatPos()
    local T = G.tank
    local x, y, z = T.turretLocal:toWorld(0.6, -1.73, -0.62)
    return x, y, z
end

function Gn.update(dt)
    local T = G.tank
    local k = love.keyboard.isDown
    -- handwheels on keyboard as an alternative
    if k("a") then Gn.targetYaw = Gn.targetYaw - dt * 0.4 end
    if k("d") then Gn.targetYaw = Gn.targetYaw + dt * 0.4 end
    if k("w") then Gn.targetPitch = Gn.targetPitch + dt * 0.12 end
    if k("s") then Gn.targetPitch = Gn.targetPitch - dt * 0.12 end
    -- don't let the target run away from the turret
    local diff = U.angleTo(T.turretYaw, Gn.targetYaw)
    if math.abs(diff) > 0.45 then Gn.targetYaw = T.turretYaw + U.sign(diff) * 0.45 diff = U.angleTo(T.turretYaw, Gn.targetYaw) end
    Gn.targetPitch = U.clamp(Gn.targetPitch, -0.14, 0.3)
    T.turretInput = diff * 3.5
    T.gunInput = (Gn.targetPitch - T.gunPitch) * 4
    G.renderer.fx.optic = Gn.optic and 1 or 0
    if love.mouse.isDown(1) and not Gn.fireLatch then
        Gn.fireLatch = true
        if T.loaded then
            T.fire()
            if G.missions then G.missions.event("cannon_fired") end
        elseif T.reloadT <= 0 then
            if G.ui then G.ui.notify("GUN NOT LOADED - PRESS R") end
            if G.audio then G.audio.play("click", { tank = true }) end
        end
    end
    if not love.mouse.isDown(1) then Gn.fireLatch = false end
    if T.turretRate ~= 0 and G.audio then G.audio.turretMotor(math.abs(T.turretRate)) end
end

function Gn.keypressed(key)
    local T = G.tank
    if key == "r" then T.startReload() return true end
    if key == "t" or key == "1" or key == "2" then
        if key == "1" then T.ammoSelect = "AP" elseif key == "2" then T.ammoSelect = "HE"
        else T.ammoSelect = T.ammoSelect == "AP" and "HE" or "AP" end
        if G.ui then G.ui.notify("NEXT ROUND: " .. T.ammoSelect) end
        if G.audio then G.audio.play("switch", { tank = true }) end
        return true
    end
    if key == "space" then Gn.optic = not Gn.optic return true end
end

function Gn.mousepressed(b)
    if b == 2 then
        Gn.optic = not Gn.optic
        if G.audio then G.audio.play("switch", { tank = true, volume = 0.4 }) end
    end
end

function Gn.wheelmoved(y)
    if Gn.optic then Gn.zoom = U.clamp(Gn.zoom + (y > 0 and 1 or -1), 1, 2) end
end

function Gn.mousemoved(dx, dy, sens)
    local scale = Gn.optic and (Gn.zoom == 2 and 0.12 or 0.25) or 0.7
    Gn.targetYaw = Gn.targetYaw + dx * sens * scale
    Gn.targetPitch = Gn.targetPitch - dy * sens * scale * 0.6
end

function Gn.camera(cam)
    local T = G.tank
    if Gn.optic then
        local gf = T.gunWorld
        local px, py, pz = gf:toWorld(0.5, 0.1, -0.38)
        G.camera.set(px, py, pz, gf.fx, gf.fy, gf.fz, gf.ux, gf.uy, gf.uz)
        G.camera.fov = math.rad(Gn.zoom == 2 and 11 or 24)
    else
        local tf = T.turretWorld
        -- eye beside the sight, looking at the breech and the turret front
        local px, py, pz = tf:toWorld(0.3, 0.3, -0.72)
        local fx, fy, fz = U.norm3(tf:dirToWorld(0.88, 0.05, 0.47))
        G.camera.set(px, py, pz, fx, fy, fz, tf.ux, tf.uy, tf.uz)
        G.camera.fov = G.camera.baseFov
    end
end

return Gn
