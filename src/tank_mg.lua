-- Bow machine gun position in the hull front (radio operator seat).
local U = require("src.utils")
local Mg = { name = "mg" }
local G

function Mg.init(game) G = game Mg.acc = 0 end

function Mg.enter()
    Mg.acc = 0
    if G.missions then G.missions.event("mg_seat") end
end

function Mg.exit()
    G.renderer.fx.optic = 0
    return 1.75, 0.62, 0.65, math.pi * 1.1
end

function Mg.seatPos() return 2.2, 0.62, 0.75 end

function Mg.update(dt)
    local T = G.tank
    G.renderer.fx.optic = 2
    if love.mouse.isDown(1) and not T.mgJam and T.mgReload <= 0 then
        if T.mgBelt <= 0 then
            if not Mg.clickLatch then
                Mg.clickLatch = true
                if G.audio then G.audio.play("click", { tank = true }) end
                if G.ui then G.ui.notify("BELT EMPTY - PRESS R") end
            end
        else
            Mg.acc = Mg.acc + dt
            local interval = 60 / 850
            while Mg.acc >= interval do
                Mg.acc = Mg.acc - interval
                Mg.fireOne()
                if T.mgBelt <= 0 or T.mgJam then break end
            end
        end
    else
        Mg.acc = math.min(Mg.acc, 0)
        if not love.mouse.isDown(1) then Mg.clickLatch = false end
    end
end

function Mg.fireOne()
    local T = G.tank
    T.mgBelt = T.mgBelt - 1
    T.mgHeat = T.mgHeat + 1.25
    if T.mgHeat >= 100 then
        T.mgJam = true
        if G.ui then G.ui.notify("MG OVERHEATED") end
        if G.audio then G.audio.play("steam", { tank = true }) end
    end
    local mf = T.mgWorld
    local mx, my, mz = mf:toWorld(0.65, 0, 0)
    local spread = 0.012 + T.mgHeat * 0.0002
    local dx, dy, dz = U.norm3(mf.fx + (math.random() - 0.5) * spread, mf.fy + (math.random() - 0.5) * spread, mf.fz + (math.random() - 0.5) * spread)
    G.weapons.hitscan(mx, my, mz, dx, dy, dz, 600, 22, "mg", T.mgBelt % 4 == 0)
    G.effects.muzzleFlash(mx, my, mz, dx, dy, dz, 0.5)
    G.effects.casing("tank", 2.55, 1.85, 0.68)
    if G.audio then G.audio.play("mg", { tank = true }) end
    if G.camera then G.camera.shake(0.12) end
    if G.humans then G.humans.noise(mx, my, mz, 140) end
    Mg.recoil = 1
end

function Mg.keypressed(key)
    local T = G.tank
    if key == "r" then
        if T.mgReload > 0 or T.mgBelt >= 150 then return true end
        if G.inventory.tank:count("mg_ammo") <= 0 then
            if G.ui then G.ui.notify("NO MG AMMO IN STORAGE") end
            return true
        end
        T.mgReload = 3.0
        if G.audio then G.audio.play("mg_reload", { tank = true }) end
        return true
    end
end

function Mg.mousepressed(b) end

function Mg.mousemoved(dx, dy, sens)
    local T = G.tank
    T.mgYaw = U.clamp(T.mgYaw + dx * sens * 0.5, -0.32, 0.32)
    T.mgPitch = U.clamp(T.mgPitch - dy * sens * 0.5, -0.18, 0.26)
end

function Mg.camera(cam)
    local T = G.tank
    local mf = T.mgWorld
    Mg.recoil = U.damp(Mg.recoil or 0, 0, 20, love.timer.getDelta())
    local r = (Mg.recoil or 0) * 0.02
    local px, py, pz = mf:toWorld(0.22 - r, 0.07, -0.11)
    G.camera.set(px, py, pz, mf.fx, mf.fy, mf.fz, mf.ux, mf.uy, mf.uz)
    G.camera.fov = math.rad(42)
end

return Mg
