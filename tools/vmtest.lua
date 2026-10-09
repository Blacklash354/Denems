-- First-person weapon test: love . --vmtest
-- Every gun at the hip, aimed, and frozen at several moments of its reload; saves screenshots.
local A = {}
local G
love.keyboard.isDown = function() return false end
love.mouse.isDown = function() return false end

local steps, idx, stepT = {}, 1, 0
local function S(dur, fn, shot) steps[#steps + 1] = { dur = dur, fn = fn, shot = shot } end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 12
    G.weather.intensity, G.weather.target = 0, 0
    local W, Wp = G.world, G.weapons
    local x, z = W.START.x + 30, W.START.z - 40
    G.player.placeWalking("world", x, W.height(x, z) + 0.1, z, -1.2)
    G.player.pitch = -0.05
    G.inventory.player:add("pistol_ammo", 200) G.inventory.player:add("rifle_ammo", 60) G.inventory.player:add("shotgun_ammo", 30)
    for _, gun in ipairs({ "smg", "rifle", "pistol", "shotgun" }) do
        S(0.6, function() Wp.switch(gun) Wp.switchT = 0 end, "vm_" .. gun .. "_hip")
        S(0.5, function() Wp.aimT = 1 Wp.forceAim = true end, "vm_" .. gun .. "_ads")
        S(0.1, function() Wp.forceAim = false Wp.aimT = 0 end)
        local phases = gun == "shotgun" and { 0.2, 0.5, 0.85 } or { 0.1, 0.25, 0.42, 0.62, 0.7, 0.86 }
        for _, ph in ipairs(phases) do
            S(0.35, function()
                Wp.mag[gun] = 0
                Wp.reload()
                Wp.freezeReload = ph
            end, string.format("vm_%s_reload_%02d", gun, math.floor(ph * 100)))
        end
        S(0.1, function() Wp.freezeReload = nil Wp.reloadT = 0 end)
    end
    S(0.3, function()
        print("[vm] DONE  screenshots in " .. love.filesystem.getSaveDirectory())
        love.event.quit()
    end)
end

function A.update(dt)
    local Wp = G.weapons
    if Wp.freezeReload then
        local def = Wp.DEFS[Wp.current]
        if def.pellets then Wp.reloadT = def.shellTime * (1 - Wp.freezeReload)
        else Wp.reloadT = Wp.reloadLen * (1 - Wp.freezeReload) end
        Wp.magIn = false
    end
    if Wp.forceAim then Wp.aimT = 1 end
    local st = steps[idx]
    if not st then return end
    if stepT == 0 and st.fn then st.fn() end
    stepT = stepT + dt
    if stepT >= st.dur then
        if st.shot then love.graphics.captureScreenshot(st.shot .. ".png") end
        idx, stepT = idx + 1, 0
    end
end

function A.draw() end
return A
