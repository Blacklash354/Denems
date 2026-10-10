-- Enemy armour test: love . --tanktest
-- Parks a T-34-85 and an IS-2 on open snow next to our tank, photographs them, then shoots a track off
-- one of them and off our own tank. Saves screenshots and logs what happened.
local A = {}
local G
love.keyboard.isDown = function() return false end
love.mouse.isDown = function() return false end

local steps, idx, stepT = {}, 1, 0
local function S(dur, fn, shot) steps[#steps + 1] = { dur = dur, fn = fn, shot = shot } end
local function log(...) print("[tanks]", ...) end

local function look(x, z, tx, ty, tz)
    local W = G.world
    local Pl = G.player
    local y = W.groundHeight(x, z)
    Pl.placeWalking("world", x, y + 0.05, z, math.atan2(tz - z, tx - x))
    Pl.pitch = math.atan2(ty - (y + 1.6), math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2))
    G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 11.5
    G.weather.intensity, G.weather.target = 0.05, 0.05
    local W, E, T = G.world, G.enemies, G.tank
    -- freeze the enemy crews: we only want to look at them
    local frozen = function() end
    local ox, oz = W.START.x + 60, W.START.z - 70
    local t34, is2
    for _, t in ipairs(E.tanks) do
        if t.kind == "t34" and not t34 then t34 = t elseif t.kind == "is2" and not is2 then is2 = t end
    end
    local function park(t, x, z, yaw, tyaw)
        t.x, t.z, t.yaw, t.turretYaw = x, z, yaw, tyaw or 0
        t.y = W.groundHeight(x, z)
        t.state = "frozen"
        E.updateFrames(t)
    end
    park(t34, ox, oz, 0.3, 0.35)
    park(is2, ox + 14, oz + 4, 2.6, -0.4)
    E.update = function() for _, t in ipairs(E.tanks) do E.updateFrames(t) end end
    log("parked", t34.name, "and", is2.name)
    S(0.8, function() look(ox + 8, oz - 9, ox, t34.y + 1.4, oz) end, "tank_t34_front34")
    S(0.8, function() look(ox - 9, oz + 3, ox, t34.y + 1.4, oz) end, "tank_t34_rear34")
    S(0.8, function() look(ox + 5, oz - 3.5, ox + 1, t34.y + 1.6, oz) end, "tank_t34_close")
    S(0.8, function() look(ox + 20, oz - 6, ox + 14, is2.y + 1.4, oz + 4) end, "tank_is2")
    S(0.8, function() look(ox + 7, oz + 16, ox + 7, t34.y + 1.2, oz + 2) end, "tank_pair")
    -- a shell into the T-34's running gear
    S(0.6, function()
        local x, y, z = t34.frame:toWorld(0.2, 0.6, 1.35)
        local before = t34.hp
        E.hit(t34, 70, x, y, z, 0, -1, "AP")
        E.hit(t34, 70, x, y, z, 0, -1, "AP")
        log(string.format("T-34 hit twice in the right track: track %.0f, hull %.0f -> %.0f, lying %d", t34.trackR, before, t34.hp, #t34.lying))
        look(ox + 6, oz + 10, ox, t34.y + 0.8, oz)
    end)
    S(1.2, nil, "tank_t34_track_thrown")
    -- and into ours
    S(0.6, function()
        T.x, T.z, T.yaw = ox - 20, oz - 10, 0
        T.y = W.groundHeight(T.x, T.z)
        T.updateFrames(0)
        T.prevFrame:copyFrom(T.frame)
        T.damage(40, "shell", 0.5, 0.8, 1.8)
        T.damage(40, "shell", 0.5, 0.8, 1.8)
        log(string.format("our right track %.0f, thrown %d, max speed %.1f", T.comp.trackR, #T.lying, T.maxSpeed()))
        look(T.x + 6, T.z + 10, T.x, T.y + 1, T.z)
    end)
    S(1.2, nil, "tank_ours_track_thrown")
    S(0.3, function()
        log("DONE  screenshots in " .. love.filesystem.getSaveDirectory())
        love.event.quit()
    end)
end

function A.update(dt)
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
