-- Autopilot drive test: love . --drivetest
-- Drives the tank from the start to the Radio Tower with simulated driver input and logs progress.
local A = { keys = {} }
local G
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do if A.keys[k] then return true end end
    return false
end
love.mouse.isDown = function() return false end

local route = { { 42, 430 }, { 30, 250 }, { 20, 95 }, { 0, -80 }, { 55, -245 }, { 180, -262 }, { 290, -250 } }
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
    Pl.enterSeat(G.stations.driver)
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
        log("ARRIVED at tower area in", math.floor(t), "s  fuel", math.floor(T.fuel), "hull", math.floor(T.comp.hull))
        love.event.quit()
        return
    end
    local dx, dz = target[1] - T.x, target[2] - T.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 14 then wp = wp + 1 log("waypoint", wp - 1, "reached at t", math.floor(t), "fuel", string.format("%.1f", T.fuel)) return end
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
