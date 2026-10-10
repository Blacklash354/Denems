-- The way north: love . --northtest
-- Reads Hans' note in the tank, looks down at the driver's compass and round at the radar, checks the
-- map's fog of war, visits the outpost garrison and drives the tank in to the homecoming. Screenshots.
local A = {}
local G
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do if A.keys and A.keys[k] then return true end end
    return false
end
love.mouse.isDown = function() return false end

local steps, idx, stepT = {}, 1, 0
local function S(dur, fn, shot) steps[#steps + 1] = { dur = dur, fn = fn, shot = shot } end
local function log(...) print("[north]", ...) end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 11
    G.weather.intensity, G.weather.target = 0.1, 0.1
    local W, Pl, T, Game = G.world, G.player, G.tank, G.game
    local D = G.stations.driver
    -- the note by the driver's seat
    S(0.3, function()
        local found
        for _, d in ipairs(require("src.interaction").list) do
            if d.prompt == "READ NOTE" and d.space == "interior" then found = d end
        end
        log("note in the tank:", found ~= nil)
        if found then found.use() end
        log("outpost on the map after reading:", tostring(G.missions.revealed.outpost))
    end)
    S(0.8, nil, "north_1_note")
    S(0.1, function() Game.state = "play" Pl.enterSeat(D) D.third = false end)
    -- look down at the compass, then turn round to the radar
    S(0.8, function() D.lookYaw, D.lookPitch = 0.9, -0.05 end, "north_2_compass")
    S(0.8, function() D.lookYaw, D.lookPitch = -2.35, -0.25 end, "north_3_radar")
    S(0.3, function()
        D.lookYaw, D.lookPitch = 0, 0
        Pl.leaveSeat()
        Game.state = "map"
        local n = 0
        for _ in pairs(G.map.seen) do n = n + 1 end
        log("map cells seen at the start:", n)
    end)
    S(0.8, nil, "north_4_map_fog")
    -- a long walk later: the garrison at the outpost
    S(0.2, function()
        Game.state = "play"
        G.map.reveal(W.START.x, W.START.z - 900, 300)
        local O = W.outpost
        local x, z = O.x - 12, O.z + 40
        Pl.placeWalking("world", x, W.groundHeight(x, z) + 0.05, z, math.atan2(O.z - z, O.x - x))
        Pl.pitch = 0.02
        G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
        local n = 0
        for _, h in ipairs(G.humans.list) do if h.faction == "german" then n = n + 1 end end
        log("German garrison:", n)
    end)
    S(1.0, nil, "north_5_outpost")
    S(0.3, function() Game.state = "map" end)
    S(0.8, nil, "north_6_map_later")
    -- the tank rolls in: home
    S(0.2, function()
        Game.state = "play"
        local O = W.outpost
        T.x, T.z, T.yaw = O.x, O.z + 160, -math.pi / 2
        T.y = W.groundHeight(T.x, T.z)
        T.updateFrames(0)
        T.prevFrame:copyFrom(T.frame)
        Pl.enterSeat(D)
        T.engineOn = true
        A.keys = { w = true }
    end)
    S(14, function() end)
    S(0.1, function()
        A.keys = {}
        log("state after driving in:", Game.state, "ending:", tostring(Game.endingKind),
            string.format("tank %.0f m from the outpost", math.sqrt((T.x - W.outpost.x) ^ 2 + (T.z - W.outpost.z) ^ 2)))
    end)
    S(3.0, nil, "north_7_home")
    S(0.2, function()
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
