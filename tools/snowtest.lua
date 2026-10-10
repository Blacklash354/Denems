-- Snow test: love . --snowtest
-- Starts a new game, warms the engine, drives the tank through a snowdrift on the highway and off into
-- the deep snow, then lets time pass. Saves chase-camera screenshots and logs the snow on the tank,
-- the drift's height, the sink and the track prints.
local A = { keys = {} }
local G
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do if A.keys[k] then return true end end
    return false
end
love.mouse.isDown = function() return false end

local t, phase, shotN = 0, "parked", 0
local drift, D
local function log(...) print("[snow]", ...) end

local function cover()
    local c = G.snow.cover
    return string.format("deck %.2f hull %.2f front %.2f tracks %.2f turret %.2f heat %.2f", c.deck, c.hull, c.front, c.tracks, c.turret, G.snow.heat)
end

local function shot(name)
    shotN = shotN + 1
    love.graphics.captureScreenshot(string.format("snowtest/%02d_%s.png", shotN, name))
    log("shot", name, cover())
end

local function orbit(yaw, pitch)
    D.orbitYaw, D.orbitPitch, D.idle = yaw, pitch or 0.3, 0
    D.camX = nil     -- snap, no easing
end

local function placeTank(x, z, yaw)
    local T = G.tank
    T.x, T.z, T.yaw, T.speed = x, z, yaw, 0
    T.y = G.world.groundHeight(x, z)
    T.updateFrames(0)
    T.prevFrame:copyFrom(T.frame)
    D.camX = nil
end

local function liveDecals()
    local n = 0
    for _, d in ipairs(G.effects.decalInfo or {}) do if d and d.a and d.a > 0.05 then n = n + 1 end end
    return n
end

function A.start(game)
    G = game
    love.filesystem.createDirectory("snowtest")
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 11
    G.weather.intensity, G.weather.target = 0.25, 0.25
    -- STEEL_WOBBLE=1: run with the retro wobble on (the ground must still not swim)
    if os.getenv("STEEL_WOBBLE") then G.renderer.wobble = true end
    D = G.stations.driver
    G.player.enterSeat(D)
    D.third = true
    orbit(2.3, 0.3)
    -- the first drift on the highway ahead of the start
    local W = G.world
    local best
    for _, d in ipairs(W.drifts) do
        local dist = math.sqrt((d.x - W.START.x) ^ 2 + (d.z - W.START.z) ^ 2)
        if not best or dist < best[1] then best = { dist, d } end
    end
    drift = best[2]
    log(string.format("%d drifts, nearest %.0f m away: h0 %.2f w %.1f l %.1f", #W.drifts, best[1], drift.h0, drift.w, drift.l))
end

function A.update(dt)
    local T, S, E = G.tank, G.snow, G.effects
    t = t + dt
    A.keys = {}
    if D.third then D.idle = 0 end
    if phase == "parked" then
        if t > 1.2 then shot("parked_cold") T.startEngine() phase = "start" t = 0 end
    elseif phase == "start" then
        if t > 0.1 and t - dt <= 0.1 then orbit(math.pi * 0.85, 0.2) end
        if t > 0.7 and t - dt <= 0.7 then shot("engine_start_smoke") end
        if t > 3 then
            -- warm up a little and line up 40 m short of the drift
            S.heat = 0.35
            local c, s = math.cos(drift.yaw), math.sin(drift.yaw)
            local cx, cz = drift.x - c * 40, drift.z - s * 40
            placeTank(cx, cz, drift.yaw)
            log(string.format("on the road: tank y %.3f  road surface %.3f  terrain %.3f", T.y, G.world.groundHeight(cx, cz), G.world.height(cx, cz)))
            phase, t = "approach", 0
            orbit(0.05, 0.12)
        end
    elseif phase == "approach" then
        A.keys.w, A.keys.lshift = true, true
        local dd = math.sqrt((drift.x - T.x) ^ 2 + (drift.z - T.z) ^ 2)
        if t > 1.8 and t - dt <= 1.8 then shot("exhaust_driving") end
        if dd < 5 and not A.hit then
            A.hit = true
            log(string.format("hitting the drift at %.1f km/h, drift h %.2f", T.speed * 3.6, drift.h))
        end
        if t > 0.5 and t - dt <= 0.5 then shot("drift_ahead") end
        if t > 0.7 and t - dt <= 0.7 then D.third = false end
        if t > 1.1 and t - dt <= 1.1 then shot("driver_view_road") end
        if t > 1.2 and t - dt <= 1.2 then D.third = true orbit(0.55, 0.25) end
        if A.hit and not A.shotPlough and dd < 3.5 then A.shotPlough = true orbit(0.9, 0.22) shot("ploughing") end
        if A.hit and dd > 14 then
            log(string.format("through the drift: speed %.1f km/h, drift h %.2f", T.speed * 3.6, drift.h))
            phase, t = "lookback", 0
            orbit(math.pi, 0.45)
        end
        if t > 25 then log("never reached the drift") phase, t = "lookback", 0 end
    elseif phase == "lookback" then
        if t > 0.9 then
            shot("tracks_on_road")
            log("track prints", liveDecals())
            -- climb out and look at the ploughed drift and the prints
            local W = G.world
            local c, s = math.cos(drift.yaw), math.sin(drift.yaw)
            local px, pz = drift.x - c * 9 - s * 2.5, drift.z - s * 9 + c * 2.5
            G.player.leaveSeat()
            G.player.placeWalking("world", px, W.groundHeight(px, pz) + 0.05, pz, math.atan2(drift.z - pz, drift.x - px))
            G.player.pitch = -0.2
            phase, t = "foot", 0
        end
    elseif phase == "foot" then
        if t > 0.8 and t - dt <= 0.8 then shot("on_foot_ploughed_drift") end
        if t > 0.9 then
            G.player.pitch = 0
            G.player.enterSeat(D)
            D.third = true
            -- turn off the road into the fields
            phase, t = "offroad", 0
            orbit(0.4, 0.3)
        end
    elseif phase == "offroad" then
        A.keys.w = true
        if t < 2.2 then A.keys.d = true end
        if t > 3 and t - dt <= 3 then log(string.format("off the road: depth %.2f sink %.2f speed %.1f km/h", T.snowDepth, T.sink, T.speed * 3.6)) end
        if t > 12 then
            log(string.format("deep snow: depth %.2f sink %.2f speed %.1f km/h  y %.2f terrain %.2f", T.snowDepth, T.sink, T.speed * 3.6, T.y, G.world.height(T.x, T.z)))
            shot("deep_snow_run")
            phase, t = "stop", 0
            orbit(math.pi * 0.9, 0.5)
        end
    elseif phase == "stop" then
        A.keys.space = true
        if t > 2.5 then
            shot("trench_behind")
            log("track prints", liveDecals())
            -- a hot engine idling for a minute: the deck steams clean
            S.heat = 1
            for i = 1, 60 * 20 do S.update(1 / 20) E.update(1 / 20) end
            log("after a minute idling hot:", cover())
            phase, t = "steam", 0
            orbit(-2.2, 0.55)
        end
    elseif phase == "steam" then
        if t > 1.2 then
            shot("hot_engine_steam")
            -- ten minutes of snowfall: the prints fill in
            E.fillT = 600
            E.update(0.001)
            log("after ten minutes of snowfall: track prints", liveDecals())
            orbit(math.pi * 0.9, 0.5)
            phase, t = "filled", 0
        end
    elseif phase == "filled" then
        if t > 0.8 then
            shot("tracks_snowed_over")
            log("drift h after ploughing", string.format("%.2f", drift.h))
            log("DONE  screenshots in " .. love.filesystem.getSaveDirectory() .. "/snowtest")
            love.event.quit()
        end
    end
end

function A.draw() end
return A
