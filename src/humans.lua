-- STALKER-style people of the Zone: loners resting at camp fires (neutral, talk, trade, fight
-- mutants) and bandits holding ruins (hostile, patrol, shoot, flee from armour).
local U = require("src.utils")
local P = require("src.physics")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")

local H = { list = {}, noises = {} }
local G

H.FACTIONS = {
    loner = { name = "LONER", hostile = false },
    bandit = { name = "BANDIT", hostile = true },
}

---------------------------------------------------------------------------
-- models (one set per faction look)
---------------------------------------------------------------------------
local function buildSet(look)
    local m = {}
    local coat = look == "bandit" and { 0.28, 0.27, 0.27 } or { 0.5, 0.52, 0.38 }
    local coatMat = look == "bandit" and "fur" or "cloth"
    local pants = look == "bandit" and { 0.3, 0.32, 0.38 } or { 0.42, 0.42, 0.34 }
    -- torso: pivot at the hips, includes the coat skirt and a backpack
    local mb = MB.new(601)
    mb.texScale = 2
    mb:material(coatMat):color(coat[1], coat[2], coat[3])
    mb:hexa({ { -0.13, -0.32, -0.21 }, { 0.15, -0.32, -0.21 }, { 0.15, -0.32, 0.21 }, { -0.13, -0.32, 0.21 },
              { -0.12, 0.02, -0.19 }, { 0.13, 0.02, -0.19 }, { 0.13, 0.02, 0.19 }, { -0.12, 0.02, 0.19 } })
    mb:hexa({ { -0.12, 0.0, -0.19 }, { 0.13, 0.0, -0.19 }, { 0.13, 0.0, 0.19 }, { -0.12, 0.0, 0.19 },
              { -0.13, 0.58, -0.25 }, { 0.14, 0.58, -0.25 }, { 0.14, 0.58, 0.25 }, { -0.13, 0.58, 0.25 } })
    mb:material("cloth"):color(coat[1] * 0.8, coat[2] * 0.8, coat[3] * 0.8)
    mb:box(-0.14, 0.12, -0.2, 0.15, 0.17, 0.2)                  -- belt
    if look == "bandit" then
        mb:material("cloth_red"):color(0.3, 0.3, 0.3)
        mb:box(0.13, 0.25, -0.12, 0.145, 0.5, 0.12)              -- tracksuit stripe
    else
        mb:material("crate"):color(0.6, 0.55, 0.4)
        mb:box(-0.33, 0.12, -0.17, -0.12, 0.55, 0.17)            -- backpack
        mb:material("cloth"):color(0.55, 0.5, 0.42)
        mb:cylinderZ(-0.2, 0.2, -0.24, 0.6, 0.07, 6)             -- bedroll
    end
    m.torso = mb:build()
    -- head: hood + gas mask (loner) or balaclava (bandit)
    mb = MB.new(602)
    if look == "bandit" then
        mb:material("fur"):color(0.15, 0.15, 0.16)
        mb:sphere(0.0, 0.12, 0, 0.12, 0.14, 0.11, 7, 5)
        mb:material("flesh"):color(0.8, 0.6, 0.5)
        mb:box(0.09, 0.12, -0.07, 0.115, 0.16, 0.07)             -- eye slit skin
        mb:material("window"):color(0.2, 0.2, 0.2)
        mb:box(0.112, 0.13, -0.05, 0.118, 0.15, 0.05)
    else
        mb:material("cloth"):color(coat[1] * 0.9, coat[2] * 0.9, coat[3] * 0.9)
        mb:sphere(-0.01, 0.13, 0, 0.14, 0.15, 0.13, 7, 5)        -- hood
        mb:material("metal"):color(0.35, 0.37, 0.33)
        mb:sphere(0.08, 0.1, 0, 0.08, 0.09, 0.085, 6, 4)          -- mask
        mb:material("window"):color(0.6, 0.75, 0.7)
        mb:cylinderX(0.12, 0.14, 0.14, -0.04, 0.025, 0.025, 6)   -- eyepieces
        mb:cylinderX(0.12, 0.14, 0.14, 0.04, 0.025, 0.025, 6)
        mb:material("metal"):color(0.3, 0.32, 0.28)
        mb:cylinderX(0.12, 0.2, 0.04, 0, 0.035, 0.03, 6)          -- filter
    end
    m.head = mb:build()
    -- leg parts (pivot at hip / knee, hanging down -y)
    mb = MB.new(603)
    mb:material("cloth"):color(pants[1], pants[2], pants[3])
    mb:hexa({ { -0.07, -0.44, -0.07 }, { 0.07, -0.44, -0.07 }, { 0.07, -0.44, 0.07 }, { -0.07, -0.44, 0.07 },
              { -0.09, 0, -0.09 }, { 0.09, 0, -0.09 }, { 0.09, 0, 0.09 }, { -0.09, 0, 0.09 } })
    m.thigh = mb:build()
    mb = MB.new(604)
    mb:material("cloth"):color(pants[1] * 0.95, pants[2] * 0.95, pants[3] * 0.95)
    mb:box(-0.06, -0.38, -0.06, 0.06, 0.0, 0.06)
    mb:material("fur"):color(0.22, 0.2, 0.18)
    mb:box(-0.07, -0.46, -0.065, 0.15, -0.36, 0.065)               -- boot
    m.shin = mb:build()
    -- arm (pivot at the shoulder)
    mb = MB.new(605)
    mb:material(coatMat):color(coat[1] * 0.95, coat[2] * 0.95, coat[3] * 0.95)
    mb:hexa({ { -0.05, -0.5, -0.05 }, { 0.05, -0.5, -0.05 }, { 0.05, -0.5, 0.05 }, { -0.05, -0.5, 0.05 },
              { -0.07, 0, -0.07 }, { 0.07, 0, -0.07 }, { 0.07, 0, 0.07 }, { -0.07, 0, 0.07 } })
    mb:material("fur"):color(0.25, 0.22, 0.2)
    mb:box(-0.045, -0.6, -0.045, 0.045, -0.5, 0.045)
    m.arm = mb:build()
    return m
end

local function buildGun()
    local mb = MB.new(606)
    mb:material("wood"):color(0.7, 0.5, 0.35)
    mb:box(-0.35, -0.05, -0.025, -0.05, 0.03, 0.025)
    mb:box(0.05, -0.04, -0.025, 0.3, 0.02, 0.025)
    mb:material("steel"):color(0.35, 0.35, 0.37)
    mb:box(-0.05, -0.03, -0.022, 0.12, 0.04, 0.022)
    mb:cylinderX(0.12, 0.62, 0.015, 0, 0.012, 0.01, 5)
    mb:material("metal"):color(0.25, 0.25, 0.25)
    mb:box(0.0, -0.17, -0.016, 0.05, -0.03, 0.016)                 -- magazine
    return mb:build()
end

---------------------------------------------------------------------------
-- dialogue
---------------------------------------------------------------------------
H.LINES = {
    petro = { "Another one crawled out of the snow. Sit, warm your bones. If you have goods, I have goods.",
              "Fuel? Medicine? Everything has a price in the Zone, friend." },
    wolf = { "Bandits sit on the old checkpoint up the north road, and more of them in the military base. They have rifles - but they run from armour. Use that steel monster of yours.",
             "Keep your head down out there. The snow hides more than tracks." },
    kolya = { "Stay out of the forest east of the river after dark. Frost hounds hunt in packs near the water.",
              "The tea is terrible but it is hot. That's what matters." },
    misha = { "The factory in the industrial zone is crawling with... crawlers. Ha. Not funny when they're on your back.",
              "I heard the radio tower is broadcasting again. Who would be crazy enough to go there?" },
    yegor = { "The burrowers sleep under the snow, stalker. If you see a mound that breathes, shoot it first.",
              "This cabin is warm, the stove still works. Take what you need from the chest, leave something for the next one." },
}
H.GIFTS = {
    wolf = { { "rifle_ammo", 15 } },
    kolya = { { "food", 2 }, { "water", 1 } },
    misha = { { "medkit", 1 } },
    yegor = { { "pistol_ammo", 40 }, { "antirad", 1 } },
}
H.AMBIENT = {
    loner = { "Hey stalker, come sit by the fire.", "Quiet tonight... too quiet.", "Anyone got a smoke?", "Listen... hear that howling?",
              "Good hunting, friend.", "The cold gets in your bones out there." },
    bandit = { "Hey! Who's there?!", "Get him!", "That's a dead man walking!", "Over there!", "Surround him!", "He's got a tank! Run!" },
}

H.TRADES = {
    { give = { { "food", 3 } }, get = { { "medkit", 1 } } },
    { give = { { "tools", 2 } }, get = { { "repair_kit", 1 } } },
    { give = { { "medkit", 1 } }, get = { { "pistol_ammo", 60 } } },
    { give = { { "water", 2 } }, get = { { "rifle_ammo", 15 } } },
    { give = { { "battery", 1 }, { "food", 1 } }, get = { { "fuel", 1 } } },
    { give = { { "documents", 1 } }, get = { { "antirad", 2 }, { "repair_kit", 1 } } },
    { give = { { "rifle_ammo", 20 } }, get = { { "he_shell", 1 } } },
}

---------------------------------------------------------------------------
-- spawn / save
---------------------------------------------------------------------------
function H.init(game)
    G = game
    H.models = { loner = buildSet("loner"), bandit = buildSet("bandit"), gun = buildGun() }
    H.frames = { M3.frame(), M3.frame(), M3.frame() }
    H.reset()
end

function H.reset(saved)
    H.list = {}
    for i, d in ipairs(G.world.npcs or {}) do
        local h = { id = i, def = d, name = d.name, faction = d.faction, role = d.role, key = d.key,
                    x = d.x, z = d.z, y = G.world.height(d.x, d.z), yaw = d.yaw or 0, homeX = d.x, homeZ = d.z, homeYaw = d.yaw or 0,
                    hp = d.faction == "bandit" and 90 or 110, state = d.role == "sit" and "sit" or "idle", timer = math.random() * 4,
                    phase = math.random() * 6, speed = 0, cool = 1 + math.random() * 2, burst = 0, aim = 0, lookYaw = 0,
                    hostile = H.FACTIONS[d.faction].hostile, talked = false, looted = false, deathT = 0, sayT = 5 + math.random() * 20,
                    loot = d.faction == "bandit" and { { "rifle_ammo", math.random(6, 14) }, { "pistol_ammo", math.random(10, 30) },
                    math.random() < 0.4 and { "medkit", 1 } or { "food", 1 } } or { { "food", 1 }, { "water", 1 } } }
        local s = saved and saved[i]
        if s then
            h.hp = s.hp or h.hp
            h.talked, h.looted, h.hostile = s.talked, s.looted, s.hostile
            if s.dead then h.state = "dead" h.deathT = 99 h.x, h.z = s.x or h.x, s.z or h.z h.y = G.world.height(h.x, h.z) end
        end
        H.list[#H.list + 1] = h
    end
end

function H.serialize()
    local out = {}
    for i, h in ipairs(H.list) do
        out[i] = { hp = h.hp, dead = h.state == "dead", talked = h.talked, looted = h.looted, hostile = h.hostile, x = h.x, z = h.z }
    end
    return out
end

function H.noise(x, y, z, r) H.noises[#H.noises + 1] = { x = x, y = y, z = z, r = r } end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function los(ax, ay, az, bx, by, bz)
    local dx, dy, dz, l = U.norm3(bx - ax, by - ay, bz - az)
    if l < 1 then return true end
    if P.raycast({ G.world.staticSet }, ax, ay, az, dx, dy, dz, l - 0.5, function(b) return not b.tree end) then return false end
    if G.world.rayTerrain(ax, ay, az, dx, dy, dz, l - 0.5) then return false end
    return true
end

local function say(h, list)
    local pl = G.player
    local px, py, pz = pl.feetWorld()
    if U.dist2(px, pz, h.x, h.z) < 30 and G.ui then
        local lines = H.AMBIENT[h.faction]
        G.ui.say(h.faction == "bandit" and "BANDIT" or h.name, list or lines[math.random(#lines)])
        if G.audio then G.audio.play("voice", { x = h.x, y = h.y + 1.6, z = h.z, volume = 0.5, pitch = h.faction == "bandit" and 0.8 or 1.0 }) end
    end
end

local function moveTo(h, x, z, speed, dt)
    local dx, dz = x - h.x, z - h.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 0.4 then h.speed = U.damp(h.speed, 0, 8, dt) return true end
    local want = math.atan2(dz, dx)
    h.yaw = U.dampAngle(h.yaw, want, 6, dt)
    h.speed = U.damp(h.speed, speed, 5, dt)
    local nx, nz = h.x + math.cos(h.yaw) * h.speed * dt, h.z + math.sin(h.yaw) * h.speed * dt
    nx, nz = P.pushOut({ G.world.staticSet, G.tank.extSet }, nx, h.y, nz, 0.3, 1.7, 0.45)
    h.x, h.z = nx, nz
    h.y = U.damp(h.y, P.groundHeight({ G.world.staticSet }, h.x, h.y + 0.5, h.z, 0.3, 0.6) > G.world.height(h.x, h.z) and
        P.groundHeight({ G.world.staticSet }, h.x, h.y + 0.5, h.z, 0.3, 0.6) or G.world.height(h.x, h.z), 12, dt)
    h.phase = h.phase + dt * h.speed * 2.6
    return false
end

local function muzzle(h)
    local c, s = math.cos(h.yaw), math.sin(h.yaw)
    return h.x + c * 0.75 - s * 0.15, h.y + 1.42, h.z + s * 0.75 + c * 0.15
end

local function shootAt(h, tx, ty, tz, accuracy, kind)
    H.shots = (H.shots or 0) + 1
    local mx, my, mz = muzzle(h)
    local dist = U.dist3(mx, my, mz, tx, ty, tz)
    local err = accuracy * (0.6 + dist / 60)
    local dx, dy, dz = U.norm3(tx - mx + (math.random() - 0.5) * err * dist * 0.05, ty - my + (math.random() - 0.5) * err * dist * 0.05,
        tz - mz + (math.random() - 0.5) * err * dist * 0.05)
    G.weapons.hitscan(mx, my, mz, dx, dy, dz, 140, kind == "enemy" and 15 or 26, kind, math.random() < 0.35)
    G.effects.muzzleFlash(mx, my, mz, dx, dy, dz, 0.4)
    if G.audio then G.audio.play(h.faction == "bandit" and "smg" or "rifle", { x = mx, y = my, z = mz, volume = 0.8 }) end
    if G.creatures then G.creatures.noise(mx, my, mz, 100, "gunshot") end
end

---------------------------------------------------------------------------
-- AI
---------------------------------------------------------------------------
local function playerTarget()
    local pl = G.player
    if pl.mode == "dead" then return nil end
    if pl.frameName == "tank" then local T = G.tank return T.x, T.y + 1.5, T.z, true end
    return pl.x, pl.y + 1.3, pl.z, false
end

local function updateBandit(h, dt)
    local tx, ty, tz, inTank = playerTarget()
    h.senseT = (h.senseT or math.random() * 0.3) - dt
    if h.senseT <= 0 and tx then
        h.senseT = 0.3
        local d = U.dist3(h.x, h.y + 1.6, h.z, tx, ty, tz)
        local vis = 0.5 + 0.5 * G.environment.daylight
        if G.player.flashlight then vis = 1 end
        if G.player.crouch and not inTank then vis = vis * 0.6 end
        local range = (inTank and 120 or 60) * vis * (1 - 0.35 * G.weather.intensity)
        local fx, fz = math.cos(h.yaw), math.sin(h.yaw)
        local facing = (fx * (tx - h.x) + fz * (tz - h.z)) / math.max(d, 0.1)
        h.sees = d < range and (facing > -0.3 or d < 10 or h.state == "combat") and los(h.x, h.y + 1.6, h.z, tx, ty, tz)
        if h.sees then
            h.lastX, h.lastZ, h.lastSeen = tx, tz, 0
            if h.state ~= "combat" and h.state ~= "flee" then
                h.state = "combat"
                h.cool = 0.8 + math.random()
                say(h)
                -- alert the rest of the gang
                for _, o in ipairs(H.list) do
                    if o ~= h and o.faction == "bandit" and o.state ~= "dead" and U.dist2(o.x, o.z, h.x, h.z) < 45 and o.state ~= "combat" then
                        o.state = "combat" o.lastX, o.lastZ, o.lastSeen = tx, tz, 0
                    end
                end
            end
        end
        for _, n in ipairs(H.noises) do
            if h.state ~= "combat" and h.state ~= "flee" and U.dist3(h.x, h.y, h.z, n.x, n.y, n.z) < n.r then
                h.state = "search" h.lastX, h.lastZ = n.x, n.z h.timer = 15
            end
        end
    end
    h.lastSeen = (h.lastSeen or 99) + dt
    local s = h.state
    if s == "sit" then
        h.speed = 0
    elseif s == "idle" then
        h.speed = U.damp(h.speed, 0, 6, dt)
        h.timer = h.timer - dt
        if h.timer <= 0 then
            if h.role == "patrol" or math.random() < 0.4 then
                local a = math.random() * 6.28
                h.px, h.pz = h.homeX + math.cos(a) * 10, h.homeZ + math.sin(a) * 10
                h.state = "walk" h.timer = 20
            else
                h.timer = 3 + math.random() * 5
                h.yaw = h.yaw + (math.random() - 0.5) * 1.5
            end
        end
    elseif s == "walk" then
        h.timer = h.timer - dt
        if moveTo(h, h.px, h.pz, 1.3, dt) or h.timer <= 0 then h.state = "idle" h.timer = 4 + math.random() * 6 end
    elseif s == "search" then
        h.timer = h.timer - dt
        moveTo(h, h.lastX, h.lastZ, 2.2, dt)
        if h.timer <= 0 then h.state = "walk" h.px, h.pz = h.homeX, h.homeZ h.timer = 30 end
    elseif s == "combat" then
        if not tx then h.state = "idle" return end
        local d = U.dist2(h.x, h.z, tx, tz)
        -- armour scares them: run if the tank comes close
        if inTank and d < 70 and math.random() < dt * 0.6 then
            h.state = "flee" h.timer = 8 say(h, "He's got a tank! Run!")
            return
        end
        local want = math.atan2(tz - h.z, tx - h.x)
        if h.sees then
            -- keep a fighting distance and strafe
            h.strafeT = (h.strafeT or 0) - dt
            if h.strafeT <= 0 then h.strafeT = 1.5 + math.random() * 2 h.strafe = (math.random() - 0.5) * 2 end
            local ideal = 28
            local fwd = d > ideal + 8 and 1 or (d < ideal - 10 and -1 or 0)
            local c, sn = math.cos(want), math.sin(want)
            local gx = h.x + (c * fwd - sn * h.strafe) * 4
            local gz = h.z + (sn * fwd + c * h.strafe) * 4
            moveTo(h, gx, gz, 2.4, dt)
            h.yaw = U.dampAngle(h.yaw, want, 10, dt)
            h.aim = U.damp(h.aim, 1, 8, dt)
            h.cool = h.cool - dt
            if h.cool <= 0 and h.aim > 0.8 then
                h.burst = h.burst + 1
                local moving = G.player.bobAmt or 0
                shootAt(h, tx + (math.random() - 0.5) * moving * 1.5, ty, tz, inTank and 0.4 or (0.5 + moving * 0.8), "enemy")
                if h.burst >= 3 then h.burst = 0 h.cool = 1.4 + math.random() * 1.6 else h.cool = 0.12 end
            end
        else
            h.aim = U.damp(h.aim, 0, 4, dt)
            moveTo(h, h.lastX or h.x, h.lastZ or h.z, 2.6, dt)
            if h.lastSeen > 12 then h.state = "search" h.timer = 12 end
        end
    elseif s == "flee" then
        h.timer = h.timer - dt
        if tx then
            local ax, az = h.x - tx, h.z - tz
            local l = math.max(0.1, math.sqrt(ax * ax + az * az))
            moveTo(h, h.x + ax / l * 8, h.z + az / l * 8, 4.2, dt)
        end
        if h.timer <= 0 then h.state = "combat" end
    end
end

local function updateLoner(h, dt)
    -- fight mutants that come close to the camp
    h.senseT = (h.senseT or math.random() * 0.5) - dt
    if h.senseT <= 0 then
        h.senseT = 0.5
        local best, bd = nil, 38
        for _, c in ipairs(G.creatures.list) do
            if c.state ~= "dead" and c.state ~= "buried" then
                local d = U.dist2(h.x, h.z, c.x, c.z)
                if d < bd and los(h.x, h.y + 1.5, h.z, c.x, c.y + c.def.height * 0.6, c.z) then best, bd = c, d end
            end
        end
        h.enemy = best
        if h.hostile and G.player.mode ~= "dead" then
            local tx, ty, tz = playerTarget()
            if U.dist2(h.x, h.z, tx, tz) < 50 and los(h.x, h.y + 1.6, h.z, tx, ty, tz) then h.enemyPlayer = true else h.enemyPlayer = false end
        end
    end
    local tx, ty, tz
    if h.enemy and h.enemy.state ~= "dead" then
        tx, ty, tz = h.enemy.x, h.enemy.y + h.enemy.def.height * 0.6, h.enemy.z
    elseif h.hostile and h.enemyPlayer then
        tx, ty, tz = playerTarget()
    end
    if tx then
        if h.state == "sit" then h.state = "idle" say(h, "Mutants! Grab your guns!") end
        h.yaw = U.dampAngle(h.yaw, math.atan2(tz - h.z, tx - h.x), 8, dt)
        h.speed = U.damp(h.speed, 0, 6, dt)
        h.aim = U.damp(h.aim, 1, 6, dt)
        h.cool = h.cool - dt
        if h.cool <= 0 and h.aim > 0.8 then
            shootAt(h, tx, ty, tz, 0.35, h.enemyPlayer and "enemy" or "npc")
            h.cool = 0.9 + math.random() * 0.8
        end
        return
    end
    h.aim = U.damp(h.aim, 0, 3, dt)
    if h.role == "sit" then
        -- walk back to the fire and sit down again
        if U.dist2(h.x, h.z, h.homeX, h.homeZ) > 0.6 then moveTo(h, h.homeX, h.homeZ, 1.2, dt)
        else h.state = "sit" h.yaw = U.dampAngle(h.yaw, h.homeYaw, 3, dt) h.speed = 0 end
    elseif h.role == "guard" or h.role == "trader" then
        if h.state == "walk" then
            h.timer = h.timer - dt
            if moveTo(h, h.px, h.pz, 1.1, dt) or h.timer <= 0 then h.state = "idle" h.timer = 6 + math.random() * 8 end
        else
            h.speed = U.damp(h.speed, 0, 6, dt)
            h.timer = h.timer - dt
            if h.timer <= 0 then
                if h.role == "guard" then
                    local a = math.random() * 6.28
                    h.px, h.pz = h.homeX + math.cos(a) * 6, h.homeZ + math.sin(a) * 6
                    h.state = "walk" h.timer = 15
                else
                    h.timer = 5 h.yaw = U.dampAngle(h.yaw, h.homeYaw, 1, 1)
                end
            end
        end
    end
    -- chatter when the player is around
    h.sayT = h.sayT - dt
    if h.sayT <= 0 then
        h.sayT = 18 + math.random() * 25
        if not h.hostile then say(h) end
    end
end

function H.update(dt)
    local px, py, pz = G.player.feetWorld()
    for _, h in ipairs(H.list) do
        if h.state == "dead" then
            h.deathT = h.deathT + dt
        elseif U.dist2(px, pz, h.x, h.z) < 420 then
            if h.faction == "bandit" or h.hostile and h.faction ~= "loner" then updateBandit(h, dt)
            else updateLoner(h, dt) end
        end
        -- look at the player when close and friendly
        local d = U.dist2(px, pz, h.x, h.z)
        local wantLook = 0
        if d < 6 and not h.hostile and h.state ~= "dead" then
            wantLook = U.clamp(U.angleTo(h.yaw, math.atan2(pz - h.z, px - h.x)), -1.0, 1.0)
        end
        h.lookYaw = U.damp(h.lookYaw, wantLook, 4, dt)
    end
    H.noises = {}
end

---------------------------------------------------------------------------
-- damage
---------------------------------------------------------------------------
function H.raycast(ox, oy, oz, dx, dy, dz, maxT)
    local bestT, best, part = maxT, nil, nil
    for _, h in ipairs(H.list) do
        if h.state ~= "dead" and U.dist3(ox, oy, oz, h.x, h.y, h.z) < maxT + 3 then
            local sit = h.state == "sit"
            local cy = h.y + (sit and 0.8 or 1.1)
            local t = P.raySphere(ox, oy, oz, dx, dy, dz, h.x, cy, h.z, sit and 0.4 or 0.33)
            if not t then t = P.raySphere(ox, oy, oz, dx, dy, dz, h.x, h.y + (sit and 0.4 or 0.5), h.z, 0.3) end
            if t and t < bestT then bestT, best, part = t, h, "body" end
            local ht = P.raySphere(ox, oy, oz, dx, dy, dz, h.x, h.y + (sit and 1.25 or 1.7), h.z, 0.16)
            if ht and ht < bestT then bestT, best, part = ht, h, "head" end
        end
    end
    if best then return bestT, best, part end
end

function H.damage(h, amount, byPlayer)
    if h.state == "dead" then return end
    h.hp = h.hp - amount
    if G.audio then G.audio.play("hurt", { x = h.x, y = h.y + 1.5, z = h.z, volume = 0.6, pitch = 0.8 }) end
    if byPlayer and not h.hostile then
        -- shooting a loner turns the whole camp against you
        for _, o in ipairs(H.list) do
            if o.faction == h.faction and U.dist2(o.x, o.z, h.x, h.z) < 40 then o.hostile = true end
        end
        if G.ui then G.ui.warning("THE LONERS TURNED HOSTILE") end
    end
    if h.state == "sit" or h.state == "idle" or h.state == "walk" then
        if h.faction == "bandit" then
            h.state = "combat"
            local tx, ty, tz = playerTarget()
            h.lastX, h.lastZ, h.lastSeen = tx, tz, 0
        else h.state = "idle" end
    end
    if h.hp <= 0 then
        h.state = "dead"
        h.deathT = 0
        h.speed = 0
        if G.audio then G.audio.play("creature_die", { x = h.x, y = h.y + 1, z = h.z, pitch = 1.6, volume = 0.7 }) end
        if G.missions then G.missions.event("human_killed", h.faction) end
    end
end

function H.splash(x, y, z, radius, damage)
    for _, h in ipairs(H.list) do
        if h.state ~= "dead" then
            local d = U.dist3(x, y, z, h.x, h.y + 1, h.z)
            if d < radius then H.damage(h, damage * (1 - d / radius), false) end
        end
    end
end

function H.nearestHostile(x, z, maxD)
    local best, bd = nil, maxD
    for _, h in ipairs(H.list) do
        if h.state ~= "dead" and h.hostile then
            local d = U.dist2(x, z, h.x, h.z)
            if d < bd then best, bd = h, d end
        end
    end
    return best, bd
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------
local matPool, matIdx = {}, 0
local function mat()
    matIdx = matIdx + 1
    local m = matPool[matIdx]
    if not m then m = {} matPool[matIdx] = m end
    return m
end

local function child(parent, x, y, z, yaw, pitch, roll)
    local f = M3.frame()
    f:setYawPitchRoll(yaw or 0, pitch or 0, roll or 0)
    f.px, f.py, f.pz = x, y, z
    return parent:compose(f, M3.frame())
end

function H.draw()
    matIdx = 0
    for _, h in ipairs(H.list) do
        if R.visible(h.x, h.y + 1, h.z, 2) then
            local m = H.models[h.faction] or H.models.loner
            local sit = h.state == "sit"
            local dead = h.state == "dead"
            local walk = math.min(1, h.speed / 1.5)
            local ph = h.phase
            local root = M3.frame()
            local fall = dead and math.min(1.45, h.deathT * 3) or 0
            root:setYawPitchRoll(h.yaw, -fall, 0)
            local hipH = sit and 0.46 or (0.92 + math.abs(math.sin(ph)) * 0.03 * walk)
            if dead then hipH = U.lerp(0.92, 0.18, fall / 1.45) end
            root.px, root.py, root.pz = h.x, h.y + hipH, h.z
            local p = { interior = 0 }
            -- legs
            for side = -1, 1, 2 do
                local swing = sit and 1.45 or (math.sin(ph + (side > 0 and math.pi or 0)) * 0.55 * walk)
                local thigh = child(root, 0, -0.02, side * 0.1, 0, swing, 0)
                R.drawModel(m.thigh, thigh:matrix(mat()), p)
                local knee = sit and -1.5 or (-math.max(0, math.sin(ph + (side > 0 and math.pi or 0) - 1.2)) * 0.8 * walk)
                local shin = child(thigh, 0, -0.44, 0, 0, knee, 0)
                R.drawModel(m.shin, shin:matrix(mat()), p)
            end
            -- torso leans forward a little when sitting or aiming
            local lean = sit and 0.25 or (h.aim * 0.12)
            local torso = child(root, 0, 0.02, 0, 0, -lean, 0)
            R.drawModel(m.torso, torso:matrix(mat()), p)
            local head = child(torso, 0.02, 0.6, 0, h.lookYaw, sit and -0.2 or 0, 0)
            R.drawModel(m.head, head:matrix(mat()), p)
            -- arms and weapon: low ready, aiming, or resting on the lap
            local aim = h.aim
            local armPitch = sit and 0.9 or U.lerp(0.55 + math.sin(ph) * 0.1 * walk, 1.45, aim)
            for side = -1, 1, 2 do
                local yaw = side < 0 and U.lerp(0.25, 0.45, aim) or U.lerp(-0.05, 0.0, aim)
                local arm = child(torso, 0.02, 0.52, side * 0.24, yaw, armPitch + (side < 0 and 0.15 or 0), 0)
                R.drawModel(m.arm, arm:matrix(mat()), p)
            end
            local gun
            if sit then gun = child(torso, 0.35, 0.1, 0.0, 0.4, -0.15, 0)
            else gun = child(torso, U.lerp(0.32, 0.42, aim), U.lerp(0.22, 0.47, aim), U.lerp(0.12, 0.12, aim), U.lerp(-0.6, 0, aim), U.lerp(-0.55, 0, aim), 0) end
            if not dead or h.deathT < 0.3 then R.drawModel(H.models.gun, gun:matrix(mat()), p) end
        end
    end
end

return H
