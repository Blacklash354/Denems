-- Challenge test: love . --talktest
-- Stands in front of a wary soldier until he walks up and challenges, answers by handing over food and
-- checks the post lets us pass; then lets a wary bandit stop us and refuses, which must start a fight.
local A = {}
local G
love.keyboard.isDown = function() return false end
love.mouse.isDown = function() return false end

local t, phase = 0, "start"
local soldier, bandit
local function log(...) print("[talk]", ...) end

local function placeBefore(h, dist)
    local W = G.world
    local c, s = math.cos(h.yaw), math.sin(h.yaw)
    local x, z = h.x + c * dist, h.z + s * dist
    G.player.placeWalking("world", x, W.groundHeight(x, z) + 0.05, z, math.atan2(h.z - z, h.x - x))
    G.player.pitch = 0
    G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
end

local function find(faction, avoid)
    local best
    for _, h in ipairs(G.humans.list) do
        if h.faction == faction and h.wary and not h.squad and not h.fixedY and h.state ~= "dead" and h ~= avoid then
            -- an open spot: nobody of another faction nearby to start a fight
            local quiet = true
            for _, o in ipairs(G.humans.list) do
                if o.faction ~= faction and o.state ~= "dead" and math.abs(o.x - h.x) + math.abs(o.z - h.z) < 120 then quiet = false end
            end
            if quiet then best = h break end
        end
    end
    return best
end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 12
    G.weather.intensity, G.weather.target = 0.05, 0.05
    G.inventory.player:add("food", 4)
    local nw = 0
    for _, h in ipairs(G.humans.list) do if h.wary then nw = nw + 1 end end
    log("wary people", nw, "of", #G.humans.list)
end

function A.update(dt)
    local Game = G.game
    t = t + dt
    if phase == "start" then
        if t < 0.5 then return end
        soldier = find("military")
        if not soldier then log("no wary soldier") love.event.quit() return end
        log(string.format("soldier at %.0f,%.0f role %s", soldier.x, soldier.z, soldier.role))
        placeBefore(soldier, 15)
        phase, t = "approach", 0
    elseif phase == "approach" then
        A.logT = (A.logT or 0) + dt
        if A.logT > 1 then
            A.logT = 0
            local pl = G.player
            log(string.format("  t=%.0f player %.1f,%.1f,%.1f frame %s mode %s  soldier %.1f,%.1f state %s", t, pl.x, pl.y, pl.z, pl.frameName, pl.mode,
                soldier.x, soldier.z, soldier.state) .. string.format(" hostile %s wary %s target %s", tostring(soldier.hostile), tostring(soldier.wary),
                type(soldier.target) == "table" and soldier.target.faction or tostring(soldier.target)))
        end
        if Game.state == "dialog" then
            log(string.format("challenged after %.1f s at %.1f m: %s", t, math.sqrt((soldier.x - G.player.x) ^ 2 + (soldier.z - G.player.z) ^ 2), G.dialog.cur.node.text))
            local sp = G.dialog.cur.h
            log(string.format("speaker %s role %s at %.1f m (the soldier we stood by: %s)", sp.name, sp.role,
                math.sqrt((sp.x - G.player.x) ^ 2 + (sp.z - G.player.z) ^ 2), tostring(sp == soldier)))
            love.graphics.captureScreenshot("talk_1_challenge.png")
            phase, t = "answer", 0
        elseif t > 15 then log("never challenged, state", soldier.state) love.event.quit() end
    elseif phase == "answer" then
        if t > 0.5 then
            G.dialog.choose(3)        -- hand over two tins of food
            phase, t = "reply", 0
        end
    elseif phase == "reply" then
        if t > 0.4 then
            love.graphics.captureScreenshot("talk_2_reply.png")
            log("reply:", G.dialog.cur and G.dialog.cur.reply, "result:", G.dialog.cur and G.dialog.cur.result)
            G.dialog.choose(1)
            phase, t = "passed", 0
        end
    elseif phase == "passed" then
        if t > 3 then
            local n, hostile = 0, 0
            for _, o in ipairs(G.humans.list) do
                if o.faction == "military" and math.abs(o.x - soldier.x) + math.abs(o.z - soldier.z) < 70 then
                    n = n + 1
                    if o.hostile then hostile = hostile + 1 end
                end
            end
            log(string.format("after paying: %d soldiers at the post, %d hostile, food left %d, state %s", n, hostile,
                G.inventory.player:count("food"), soldier.state))
            love.graphics.captureScreenshot("talk_3_passed.png")
            bandit = find("bandit")
            if not bandit then log("no wary bandit") phase = "done" return end
            log(string.format("bandit at %.0f,%.0f", bandit.x, bandit.z))
            placeBefore(bandit, 14)
            phase, t = "bandit", 0
        end
    elseif phase == "bandit" then
        if Game.state == "dialog" then
            log("bandit says:", G.dialog.cur.node.text)
            love.graphics.captureScreenshot("talk_4_bandit.png")
            G.dialog.choose(4)        -- "come and take it"
            G.dialog.choose(1)
            phase, t = "fight", 0
        elseif t > 15 then log("bandit never challenged, state", bandit.state) phase = "done" end
    elseif phase == "fight" then
        if t > 2 then
            log(string.format("refused the bandit: state %s, hostile %s", bandit.state, tostring(bandit.hostile)))
            love.graphics.captureScreenshot("talk_5_fight.png")
            phase = "done"
        end
    elseif phase == "done" then
        log("DONE  screenshots in " .. love.filesystem.getSaveDirectory())
        love.event.quit()
    end
end

function A.draw() end
return A
