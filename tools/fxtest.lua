-- Effects test: love . --fxtest
-- Fires a rifle, the tank's cannon and a shell into the snow, and lights a fire, freezing the frame
-- at the interesting moments. Saves screenshots.
local A = {}
local G
love.keyboard.isDown = function() return false end
love.mouse.isDown = function() return false end

local steps, idx, stepT = {}, 1, 0
local function S(dur, fn, shot) steps[#steps + 1] = { dur = dur, fn = fn, shot = shot } end

local function look(x, z, tx, ty, tz)
    local W, Pl = G.world, G.player
    local y = W.groundHeight(x, z)
    Pl.placeWalking("world", x, y + 0.05, z, math.atan2(tz - z, tx - x))
    Pl.pitch = math.atan2(ty - (y + 1.6), math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2))
    G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 16.5
    G.weather.intensity, G.weather.target = 0.05, 0.05
    local W, E, T = G.world, G.effects, G.tank
    local ox, oz = W.START.x + 70, W.START.z - 60
    local oy = W.groundHeight(ox, oz)
    -- a burst from the AK
    S(0.6, function() look(ox, oz, ox + 30, oy + 1.4, oz) end)
    S(0.02, function() G.weapons.fire() end, "fx_1_rifle")
    -- the tank's cannon, seen from the side
    S(0.5, function()
        T.x, T.z, T.yaw = ox + 20, oz + 30, 0
        T.y = W.groundHeight(T.x, T.z)
        T.updateFrames(0)
        T.prevFrame:copyFrom(T.frame)
        look(ox + 26, oz + 14, ox + 30, T.y + 2.4, oz + 30)
    end)
    S(0.08, function()
        local gf = T.gunWorld
        local mx, my, mz = gf:toWorld(5.6, 0, 0)
        E.muzzleBlast(mx, my, mz, gf.fx, gf.fy, gf.fz, 1)
    end, "fx_2_cannon")
    S(0.6, nil, "fx_3_cannon_smoke")
    -- an HE shell landing 40 m away
    S(0.4, function() look(ox - 20, oz, ox + 20, oy + 3, oz) end)
    S(0.12, function() G.weapons.explode(ox + 20, W.groundHeight(ox + 20, oz) + 0.2, oz, 10, 0, "world") end, "fx_4_explosion")
    S(0.6, nil, "fx_5_explosion_later")
    S(2.0, nil, "fx_6_smoke_column")
    -- a fire burning in a barrel
    S(0.2, function()
        A.fireAt = { ox - 4, W.groundHeight(ox - 4, oz + 6), oz + 6 }
        look(ox - 8, oz + 6, ox - 4, A.fireAt[2] + 1, oz + 6)
    end)
    S(1.5, nil, "fx_7_fire")
    S(0.2, function()
        print("[fx] DONE  screenshots in " .. love.filesystem.getSaveDirectory())
        love.event.quit()
    end)
end

function A.update(dt)
    if A.fireAt then G.effects.fire(A.fireAt[1], A.fireAt[2], A.fireAt[3], 1.2) end
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
