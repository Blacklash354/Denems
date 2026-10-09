-- Autopilot drive test: love . --drivetest
-- Drives the tank from the start up the highway to the checkpoint and the garage cooperative
-- with simulated driver input and logs progress (time, fuel, hull).
local A = { keys = {} }
local G
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do if A.keys[k] then return true end end
    return false
end
love.mouse.isDown = function() return false end

local route = {}
local wp, t, lastCheck, lastX, lastZ, logT = 1, 0, 0, 0, 0, 0
local stuckCount = 0

local function log(...) print("[drive]", ...) end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.helpT = nil
    G.game.godMode = true
    local T, Pl = G.tank, G.player
    T.comp.trackR = 100
    T.fuel = 100
    -- follow the highway centre line from the start to the garages
    local path = G.world.roadPaths[1]
    for i = 1, #path, 6 do
        local p = path[i]
        if p.z < T.z - 10 and p.z > 560 then route[#route + 1] = { p.x, p.z } end
    end
    route[#route + 1] = { G.world.garages.x - 40, G.world.garages.z + 5 }
    Pl.enterSeat(G.stations.driver)
    local dmg = T.damage
    T.damage = function(amount, kind, ...)
        if amount > 1 then
            log(string.format("damage %.1f %s at (%.0f,%.0f) speed %.1f", amount, tostring(kind), T.x, T.z, T.speed))
            for _, b in ipairs(G.world.colliders:query(T.x - 6, T.z - 6, T.x + 6, T.z + 6, {})) do
                log(string.format("   box %.1f..%.1f x %.1f..%.1f z %.1f..%.1f  obj %s tree %s", b[1], b[4], b[2], b[5], b[3], b[6],
                    b.obj and b.obj.kind or "-", tostring(b.tree)))
            end
        end
        return dmg(amount, kind, ...)
    end
    T.startEngine()
    lastX, lastZ = T.x, T.z
end

function A.update(dt)
    local T = G.tank
    for i = 1, 3 do G.game.update(dt) end   -- fast forward
    t = t + dt * 4
    if t < 2.5 then return end
    local target = route[wp]
    if not target then
        log("ARRIVED at the garages in", math.floor(t), "s  fuel", math.floor(T.fuel), "hull", math.floor(T.comp.hull))
        love.event.quit()
        return
    end
    local dx, dz = target[1] - T.x, target[2] - T.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 14 then wp = wp + 1 if wp % 5 == 0 then log("waypoint", wp - 1, "/", #route, "reached at t", math.floor(t), "fuel", string.format("%.1f", T.fuel)) end return end
    local want = math.atan2(dz, dx)
    local diff = (want - T.yaw + math.pi) % (2 * math.pi) - math.pi
    A.keys = {}
    if A.backT and A.backT > 0 then
        -- like a player would: back up and swing around the obstacle
        A.backT = A.backT - dt * 4
        A.keys.s = true
        A.keys[A.backSide] = true
        return
    end
    if diff > 0.08 then A.keys.d = true elseif diff < -0.08 then A.keys.a = true end
    if math.abs(diff) < 0.6 then A.keys.w = true A.keys.lshift = true end
    if t - lastCheck > 6 then
        local moved = math.sqrt((T.x - lastX) ^ 2 + (T.z - lastZ) ^ 2)
        if moved < 3 then
            stuckCount = stuckCount + 1
            log("STUCK? at", math.floor(T.x), math.floor(T.z), "speed", T.speed, "wp", wp, "- reversing")
            A.backT = 4
            A.backSide = (stuckCount % 2 == 0) and "a" or "d"
            if stuckCount > 4 then love.event.quit() end
        end
        lastCheck, lastX, lastZ = t, T.x, T.z
    end
    if t - logT > 20 then
        logT = t
        log(string.format("t=%d pos=(%.0f,%.0f) y=%.1f speed=%.1f km/h fuel=%.1f wp=%d", t, T.x, T.z, T.y, T.speed * 3.6, T.fuel, wp))
    end
    if t > 900 then log("TIMEOUT") love.event.quit() end
end

function A.draw() end
return A
