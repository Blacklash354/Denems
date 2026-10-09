-- Running-gear test: love . --geartest
-- Drives the tank in the chase camera (side view) and checks that tracks and every wheel move.
local A = { keys = {} }
local G
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do if A.keys[k] then return true end end
    return false
end
love.mouse.isDown = function() return false end

local t, shot, a0 = 0, 0, nil
local shots = { 5.0, 5.15, 9.0 }

function A.start(game)
    G = game
    G.startNewGame()
    G.game.helpT = nil
    G.game.godMode = true
    local T, D = G.tank, G.stations.driver
    T.comp.trackR = 100
    G.player.enterSeat(D)
    T.startEngine()
    D.third, D.camX = true, nil
    D.orbitYaw, D.orbitPitch = math.pi / 2, 0.12
end

function A.update(dt)
    local T, D = G.tank, G.stations.driver
    t = t + dt
    D.idle = 0
    D.orbitYaw, D.orbitPitch = math.pi / 2, 0.12
    A.keys = { w = t > 2.5, d = t > 7 }
    if t > 4 and not a0 then a0 = { T.wheelAngL, T.wheelAngR, T.trackOffL, T.trackOffR } end
    if shots[shot + 1] and t > shots[shot + 1] then
        shot = shot + 1
        love.graphics.captureScreenshot("geartest_" .. shot .. ".png")
        print(string.format("[gear] t=%.2f speed=%.2f wheelL=%.2f wheelR=%.2f trackL=%.2f trackR=%.2f wheels=%d",
            t, T.speed, T.wheelAngL, T.wheelAngR, T.trackOffL, T.trackOffR, #T.wheels))
    end
    if t > 10 then
        local moved = a0 and T.wheelAngL ~= a0[1] and T.wheelAngR ~= a0[2] and T.trackOffL ~= a0[3] and T.trackOffR ~= a0[4]
        local split = math.abs(T.trackVL - T.trackVR) > 0.05
        print("[gear] " .. ((moved and split) and "PASS" or "FAIL") .. " moved=" .. tostring(moved) .. " steering split=" .. tostring(split)
            .. "  screenshots in " .. love.filesystem.getSaveDirectory())
        love.event.quit()
    end
end

function A.draw() end
return A
