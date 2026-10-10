-- Destruction test: love . --treetest
-- Rams a tree at speed (it should come down on the tank and slide off), pushes another one over slowly,
-- fells trees with a shell blast, drops debris on the tank and collapses a building. Saves chase-camera
-- screenshots and logs what the falling trees did.
local A = { keys = {} }
local G
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do if A.keys[k] then return true end end
    return false
end
love.mouse.isDown = function() return false end

local t, phase, shotN = 0, "find", 0
local D, target, slowTarget, f
local function log(...) print("[trees]", ...) end

local function shot(name)
    shotN = shotN + 1
    love.graphics.captureScreenshot(string.format("treetest/%02d_%s.png", shotN, name))
end

local function orbit(yaw, pitch)
    D.orbitYaw, D.orbitPitch, D.idle = yaw, pitch or 0.3, 0
    D.camX = nil
end

local function placeTank(x, z, yaw)
    local T = G.tank
    T.x, T.z, T.yaw, T.speed, T.yawRate = x, z, yaw, 0, 0
    T.y = G.world.groundHeight(x, z)
    T.updateFrames(0)
    T.prevFrame:copyFrom(T.frame)
    D.camX = nil
end

-- a lone tree with open ground on the approach side (nothing else within the tank's path)
local function findTree(minS, avoid)
    local W = G.world
    local best
    for _, tr in ipairs(W.trees) do
        if not tr.down and tr.s >= minS and tr ~= avoid and math.abs(tr.x - W.START.x) < 900 and math.abs(tr.z - W.START.z) < 900 then
            local clear = true
            for _, o in ipairs(W.colliders:query(tr.x - 26, tr.z - 9, tr.x + 9, tr.z + 9, {})) do
                if o ~= tr.box and o.enabled ~= false and o[5] > tr.y + 0.5 then clear = false break end
            end
            if clear then
                local d = math.abs(tr.x - W.START.x) + math.abs(tr.z - W.START.z)
                if not best or d < best[1] then best = { d, tr } end
            end
        end
    end
    return best and best[2]
end

local function lastFallen(tr)
    for _, q in ipairs(G.destruction.fallen) do if q.t == tr then return q end end
end

function A.start(game)
    G = game
    love.filesystem.createDirectory("treetest")
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 11
    G.weather.intensity, G.weather.target = 0.1, 0.1
    D = G.stations.driver
    G.player.enterSeat(D)
    D.third = true
    G.tank.startEngine()
    G.snow.heat = 0.6
end

function A.update(dt)
    local T = G.tank
    t = t + dt
    A.keys = {}
    if D.third then D.idle = 0 end
    if phase == "find" then
        if t < 3 then return end
        target = findTree(1.0)
        if not target then log("no tree found") love.event.quit() return end
        log(string.format("ramming a %s (scale %.2f) at %.0f,%.0f", target.kind, target.s, target.x, target.z))
        -- 30 m short of it, heading at it along +x
        placeTank(target.x - 30, target.z, 0)
        orbit(1.25, 0.32)
        phase, t = "ram", 0
    elseif phase == "ram" then
        A.keys.w, A.keys.lshift = true, true
        -- steer straight at the trunk
        local want = math.atan2(target.z - T.z, target.x - T.x)
        local diff = (want - T.yaw + math.pi) % (2 * math.pi) - math.pi
        if not target.down then
            if diff > 0.03 then A.keys.d = true elseif diff < -0.03 then A.keys.a = true end
        end
        if target.down and not f then
            f = lastFallen(target)
            log(string.format("trunk snapped at %.1f km/h", T.speed * 3.6))
        end
        if f then
            if f.onTank and not A.onTankLogged then
                A.onTankLogged = true
                log(string.format("came down on the tank, tilt %.0f deg", math.deg(f.th)))
                shot("tree_on_tank")
            end
            f.maxTilt = math.max(f.maxTilt or 0, f.th)
        end
        if t > 2 and t - dt <= 2 and not f then shot("approach") end
        if f and A.onTankLogged and not A.shot2 and t > (A.onT or 0) then
            A.onT = A.onT or (t + 1.2)
            if t >= A.onT then A.shot2 = true shot("riding") end
        end
        if t > 9 or (f and f.state == "rest" and t > 4) then
            A.keys = {}
            A.keys.space = true
            phase, t = "after_ram", 0
            orbit(math.pi * 0.8, 0.4)
        end
    elseif phase == "after_ram" then
        A.keys.space = true
        if t > 2.5 then
            if f then
                log(string.format("tree now: state %s tilt %.0f deg, on tank %s, butt moved %.1f m", f.state, math.deg(f.th), tostring(f.onTank),
                    math.sqrt((f.bx - target.x) ^ 2 + (f.bz - target.z) ^ 2)))
            else log("the tree did not break") end
            shot("after_ram")
            -- now push a big tree over slowly
            slowTarget = findTree(1.1, target)
            placeTank(slowTarget.x - 12, slowTarget.z, 0)
            orbit(1.6, 0.25)
            phase, t = "push", 0
        end
    elseif phase == "push" then
        A.keys.w = true
        local want = math.atan2(slowTarget.z - T.z, slowTarget.x - T.x)
        local diff = (want - T.yaw + math.pi) % (2 * math.pi) - math.pi
        if not slowTarget.down then
            if diff > 0.03 then A.keys.d = true elseif diff < -0.03 then A.keys.a = true end
        end
        if T.speed > 1.2 then A.keys.w = false end      -- creep
        if slowTarget.down and not A.pushedT then A.pushedT = t log(string.format("pushed over at %.1f km/h", T.speed * 3.6)) end
        if A.pushedT and t > A.pushedT + 1.0 and not A.pushShot then A.pushShot = true shot("pushed_over") end
        if (A.pushedT and t > A.pushedT + 4) or t > 25 then
            local q = lastFallen(slowTarget)
            log(q and string.format("pushed tree: tilt %.0f deg, fell %s of the tank", math.deg(q.th),
                (q.dx * math.cos(T.yaw) + q.dz * math.sin(T.yaw)) > 0 and "ahead" or "behind") or "the pushed tree did not fall")
            phase, t = "blast", 0
        end
    elseif phase == "blast" then
        A.keys.space = true
        if t > 0.2 and not A.blasted then
            A.blasted = true
            -- an HE shell lands among trees 25 m to the side
            local tr = findTree(0.8, slowTarget)
            local before = #G.destruction.fallen
            G.weapons.explode(tr.x + 1.5, tr.y + 0.3, tr.z + 1.0, 10, 220, "world")
            log("HE blast felled", #G.destruction.fallen - before, "trees")
            placeTank(tr.x - 22, tr.z - 10, 0.4)
            orbit(0.9, 0.35)
        end
        if t > 2.0 then shot("blast_felled") phase, t = "debris", 0 end
    elseif phase == "debris" then
        if t > 0.1 and not A.dropped then
            A.dropped = true
            G.effects.debris(T.x, T.y + 7, T.z, "rubble", 18, 2, 0.5)
            orbit(2.4, 0.6)
        end
        if t > 2.0 and not A.dShot then
            A.dShot = true
            local n = 0
            for _, d in ipairs(G.effects.debrisList) do if d.onTank then n = n + 1 end end
            log("debris resting on the tank", n)
            shot("debris_on_tank")
        end
        if t > 2.2 then A.keys.w, A.keys.lshift = true, true end
        if t > 12 then
            local n = 0
            for _, d in ipairs(G.effects.debrisList) do if d.onTank then n = n + 1 end end
            log("debris still on the tank after 10 s of driving", n)
            phase, t = "building", 0
        end
    elseif phase == "building" then
        if not A.bobj then
            local W = G.world
            for _, o in ipairs(W.dobjs) do
                if o.alive and o.kind == "building" and o.radius and o.radius > 4 then A.bobj = o break end
            end
            if not A.bobj then log("no building") phase = "done" return end
            local o = A.bobj
            G.player.leaveSeat()
            local px, pz = o.cx - o.radius * 2.2, o.cz - o.radius * 0.8
            G.player.placeWalking("world", px, G.world.groundHeight(px, pz) + 0.05, pz, math.atan2(o.cz - pz, o.cx - px))
            G.player.pitch = 0.1
            t = 0
        end
        if t > 0.6 and not A.boom then A.boom = true G.destruction.destroy(A.bobj) end
        if t > 1.5 and not A.cShot then A.cShot = true shot("building_collapsing") end
        if t > 5.5 then shot("building_ruin") phase, t = "done", 0 end
    elseif phase == "done" then
        if t > 0.5 then
            log("fallen trees", #G.destruction.fallen)
            log("DONE  screenshots in " .. love.filesystem.getSaveDirectory() .. "/treetest")
            love.event.quit()
        end
    end
end

function A.draw() end
return A
