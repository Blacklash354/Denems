-- The people left after the war: survivors ("loners") huddled at fires, bandits looting the
-- ruins and what remains of the army holding bases and roads. Factions fight each other on
-- sight; squads walk between places along the roads (and keep walking while you are far away),
-- and a destroyed squad is replaced after a while.
local U = require("src.utils")
local P = require("src.physics")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")
local PA = require("src.psx_assets")
local Rig = require("src.rig")
local Ch = require("src.characters")
local People = require("src.people")

local H = { list = {}, noises = {} }
local G

H.FACTIONS = {
    loner = { name = "SURVIVOR", hostile = false },
    bandit = { name = "BANDIT", hostile = true },
    military = { name = "SOLDIER", hostile = true },
    german = { name = "LANDSER", hostile = false },      -- our own, at the outpost in the north
}
-- who shoots whom on sight
H.ENEMIES = {
    loner = { bandit = true, military = true },
    bandit = { loner = true, military = true, german = true },
    military = { loner = true, bandit = true, german = true },
    german = { military = true, bandit = true },
}
local ACTIVE = 380          -- full AI inside this radius around the player
local RESPAWN = 420         -- seconds before a wiped-out squad is replaced

---------------------------------------------------------------------------
-- models
---------------------------------------------------------------------------
local function buildRifle()
    local mb = MB.new(606)
    if PA.has(PA.AK) then
        mb:color(1, 1, 1)
        PA.emitAK(mb)
        return mb:build()
    end
    mb:material("wood"):color(0.7, 0.5, 0.35)
    mb:box(-0.35, -0.05, -0.025, -0.05, 0.03, 0.025)
    mb:box(0.05, -0.04, -0.025, 0.3, 0.02, 0.025)
    mb:material("steel"):color(0.35, 0.35, 0.37)
    mb:box(-0.05, -0.03, -0.022, 0.12, 0.04, 0.022)
    mb:cylinderX(0.12, 0.62, 0.015, 0, 0.012, 0.01, 5)
    mb:material("metal"):color(0.25, 0.25, 0.25)
    mb:box(0.0, -0.17, -0.016, 0.05, -0.03, 0.016)
    return mb:build()
end

-- grip (right wrist) and handguard (left wrist) points in gun space, and the gun's origin offset
local GRIP = { -0.13, -0.06, 0.035 }
local GUARD = { 0.13, -0.05, -0.03 }

---------------------------------------------------------------------------
-- dialogue
---------------------------------------------------------------------------
H.LINES = {
    petro = { "Another one walked out of the snow. Sit, warm your bones. If you have goods, I have goods.",
              "Fuel? Medicine? Everything has a price now, friend." },
    wolf = { "Bandits sit in the garages east of the highway and in the old tractor works. The army still holds the airfield and the base - they shoot anyone who comes close.",
             "Keep your head down out there. The snow hides more than tracks." },
    kolya = { "Stay off the open fields in a blizzard. You walk in circles until the cold puts you to sleep.",
              "The tea is terrible but it is hot. That's what matters." },
    misha = { "Zarechny is a dead city now. Soldiers in the square, bandits in the east blocks. The flats still have warm clothes, if you look.",
              "I heard the radio tower is broadcasting again. Who would be crazy enough to go there?" },
    yegor = { "The forest feeds those who know it. The bridge on the forest road is down - the ice will carry a man, not a tank.",
              "This cabin is warm, the stove still works. Take what you need from the chest, leave something for the next one." },
    nadia = { "We came from the city when the soldiers started shooting looters. Looters... we only wanted bread.",
              "Wool and felt. Find valenki and a sheepskin, or the cold will take your feet first." },
    brandt = { "Kurt? Kurt Weber? Good God, man - we gave you up for dead with the rest of the company. Sit, sit. There's coffee, nearly.",
               "Hans made it in a week ago, half frozen. He said you'd bring the tank if anyone could. We hold this place until the thaw, and then we'll see." },
    vasya = { "Every flat in these blocks has a wardrobe. Most are empty. Most.",
              "The airfield? Tanks in rows like sleeping dogs. And soldiers who don't sleep." },
}
H.GIFTS = {
    wolf = { { "rifle_ammo", 15 } },
    kolya = { { "food", 2 }, { "water", 1 } },
    misha = { { "medkit", 1 } },
    yegor = { { "pistol_ammo", 40 }, { "valenki", 1 } },
    nadia = { { "mittens", 1 } },
    vasya = { { "battery", 1 } },
}
H.AMBIENT = {
    loner = { "Come sit by the fire.", "Quiet tonight... too quiet.", "Anyone got a smoke?", "Listen... wolves.",
              "Stay warm, friend.", "The cold gets in your bones out there." },
    bandit = { "Hey! Who's there?!", "Get him!", "That's a dead man walking!", "Over there!", "Surround him!", "He's got a tank! Run!" },
    military = { "Halt!", "Contact!", "Open fire!", "Flank him!", "Grenade... no, no grenades left!", "Hold the line!" },
    german = { "Halt! ...Kurt? Is that you?", "Close the gap in the wire!", "Ivan was probing the wire again last night.",
               "Keep your head down by the tower.", "Warm your hands, the coffee is almost real." },
}

H.TRADES = {
    { give = { { "food", 3 } }, get = { { "medkit", 1 } } },
    { give = { { "tools", 2 } }, get = { { "repair_kit", 1 } } },
    { give = { { "medkit", 1 } }, get = { { "pistol_ammo", 60 } } },
    { give = { { "water", 2 } }, get = { { "rifle_ammo", 15 } } },
    { give = { { "battery", 1 }, { "food", 1 } }, get = { { "fuel", 1 } } },
    { give = { { "documents", 1 } }, get = { { "antirad", 2 }, { "repair_kit", 1 } } },
    { give = { { "rifle_ammo", 20 } }, get = { { "he_shell", 1 } } },
    { give = { { "food", 4 }, { "water", 2 } }, get = { { "telogreika", 1 } } },
    { give = { { "pistol_ammo", 40 } }, get = { { "ushanka", 1 } } },
}

local function lootFor(faction)
    local r = math.random
    if faction == "military" then
        local l = { { "rifle_ammo", r(6, 14) }, { "pistol_ammo", r(10, 25) } }
        if r() < 0.35 then l[#l + 1] = { "medkit", 1 } else l[#l + 1] = { "food", 1 } end
        if r() < 0.18 then l[#l + 1] = { "greatcoat", 1 } end
        if r() < 0.22 then l[#l + 1] = { "ushanka", 1 } end
        if r() < 0.15 then l[#l + 1] = { "boots", 1 } end
        if r() < 0.1 then l[#l + 1] = { "mg_ammo", r(40, 90) } end
        return l
    elseif faction == "bandit" then
        local l = { { "pistol_ammo", r(10, 30) }, { "shotgun_ammo", r(2, 8) } }
        if r() < 0.4 then l[#l + 1] = { "medkit", 1 } else l[#l + 1] = { "food", 1 } end
        if r() < 0.15 then l[#l + 1] = { "gloves", 1 } end
        if r() < 0.12 then l[#l + 1] = { "fuel", 1 } end
        return l
    end
    return { { "food", 1 }, { "water", 1 } }
end

---------------------------------------------------------------------------
-- spawn / save
---------------------------------------------------------------------------
local LOOKS = { military = { "military", "military", "military_winter" }, bandit = { "bandit", "bandit2" }, loner = { "loner", "loner2" },
                german = { "military_winter" } }

function H.init(game)
    G = game
    H.looks = {
        military = Rig.build("military", 610), military_winter = Rig.build("military_winter", 620),
        bandit = Rig.build("bandit", 630), bandit2 = Rig.build("bandit2", 640),
        loner = Rig.build("loner", 650), loner2 = Rig.build("loner2", 660),
    }
    -- modelled people (assets/people, Quaternius CC0) replace the procedural outfits where available
    for faction, list in pairs(People.LOOKS) do
        local have = {}
        for _, name in ipairs(list) do
            local set = People.build(name)
            if set then H.looks[name] = set have[#have + 1] = name end
        end
        if #have > 0 then LOOKS[faction] = have end
    end
    -- figures from the character pack (assets/characters_psx.glb): the masked raiders join the bandits
    -- and the NBC-suited chemical troops guard the power plant
    if Ch.available() then
        Ch.preload()
        for faction, list in pairs(Ch.LOOKS) do
            for _, name in ipairs(list) do
                local set = Ch.get(name)
                if set then
                    H.looks[name] = set
                    if faction == "bandit" and name:find("Killer") then table.insert(LOOKS[faction], name) end
                end
            end
        end
    end
    H.gun = buildRifle()
    H.reset()
end


local function wary(faction, key)
    key = key % 6
    if faction == "military" then return key % 2 == 0 end
    if faction == "bandit" then return key % 3 == 0 end
    return false
end

local function newHuman(i, d)
    local W = G.world
    local looks = LOOKS[d.faction] or LOOKS.loner
    local h = { id = i, def = d, name = d.name or H.FACTIONS[d.faction].name, faction = d.faction, role = d.role, key = d.key,
                x = d.x, z = d.z, y = d.y or W.groundHeight(d.x, d.z), yaw = d.yaw or 0, homeX = d.x, homeZ = d.z, homeYaw = d.yaw or 0,
                hp = d.faction == "loner" and 110 or 95, state = d.role == "sit" and "sit" or "idle", timer = math.random() * 4,
                phase = math.random() * 6, speed = 0, cool = 1 + math.random() * 2, burst = 0, aim = 0, lookYaw = 0, aimPitch = 0,
                hostile = H.FACTIONS[d.faction].hostile, talked = false, looted = false, deathT = 0, sayT = 5 + math.random() * 20,
                look = looks[(i - 1) % #looks + 1], loot = lootFor(d.faction) }
    -- chemical troops in NBC suits guard the power plant
    local Pn = W.plant
    if d.faction == "military" and Pn and H.looks.Character_28_HM and U.dist2(d.x, d.z, Pn.x, Pn.z) < Pn.r * 1.3 then
        h.look = "Character_28_HM"
    end
    if d.y then h.fixedY = true end
    -- not everyone shoots first: wary posts walk up and ask who you are (dialog.lua). Decided per place
    -- (the location it guards, else a 150 m cell), so a group either challenges you or opens fire together
    local key = math.floor(d.x / 150) * 31 + math.floor(d.z / 150) * 17
    for li, l in ipairs(W.locations) do
        if math.abs(d.x - l.x) < l.r * 1.4 and math.abs(d.z - l.z) < l.r * 1.4 then key = li * 5 + 1 break end
    end
    if wary(d.faction, key) then h.wary, h.hostile = true, false end
    return h
end

function H.reset(saved)
    H.list = {}
    H.squads = {}
    local W = G.world
    for i, d in ipairs(W.npcs or {}) do H.list[#H.list + 1] = newHuman(#H.list + 1, d) end
    for si, s in ipairs(W.squads or {}) do
        local sq = { def = s, members = {}, wp = 2, x = s.route[1][1], z = s.route[1][2], deadT = 0, id = si }
        for k = 1, s.count do
            local a = k / s.count * 6.28
            local d = { x = sq.x + math.cos(a) * 2, z = sq.z + math.sin(a) * 2, faction = s.faction, role = "squad", name = H.FACTIONS[s.faction].name }
            local h = newHuman(#H.list + 1, d)
            h.squad = sq
            h.slot = k
            h.state = "idle"
            h.wary = wary(s.faction, si * 7)
            if h.wary then h.hostile = false else h.hostile = H.FACTIONS[s.faction].hostile end
            H.list[#H.list + 1] = h
            sq.members[#sq.members + 1] = h
        end
        H.squads[si] = sq
    end
    -- a post is everyone of a faction standing within reach of each other: they all share the first
    -- one's choice to challenge or to shoot
    local done = {}
    for _, h in ipairs(H.list) do
        if not h.squad and not done[h] then
            local w, stack = h.wary, { h }
            done[h] = true
            while #stack > 0 do
                local a = table.remove(stack)
                a.wary = w
                a.hostile = (not w) and H.FACTIONS[a.faction].hostile
                for _, o in ipairs(H.list) do
                    if not done[o] and not o.squad and o.faction == a.faction and math.abs(o.x - a.x) + math.abs(o.z - a.z) < 60 then
                        done[o] = true
                        stack[#stack + 1] = o
                    end
                end
            end
        end
    end
    if saved then
        for i, h in ipairs(H.list) do
            local s = saved[i]
            if s then
                h.hp = s.hp or h.hp
                h.talked, h.looted, h.hostile = s.talked, s.looted, s.hostile
                h.wary, h.passed = s.wary, s.passed
                if s.x then h.x, h.z = s.x, s.z h.y = h.fixedY and h.y or W.groundHeight(h.x, h.z) end
                if s.dead then h.state = "dead" h.deathT = 99 end
            end
        end
        for si, sq in ipairs(H.squads) do
            local s = saved.squads and saved.squads[si]
            if s then sq.x, sq.z, sq.wp, sq.deadT = s.x or sq.x, s.z or sq.z, s.wp or sq.wp, s.deadT or 0 end
        end
    end
end

function H.serialize()
    local out = {}
    for i, h in ipairs(H.list) do
        out[i] = { hp = h.hp, dead = h.state == "dead", talked = h.talked, looted = h.looted, hostile = h.hostile, x = h.x, z = h.z,
                   wary = h.wary, passed = h.passed }
    end
    out.squads = {}
    for si, sq in ipairs(H.squads) do out.squads[si] = { x = sq.x, z = sq.z, wp = sq.wp, deadT = sq.deadT } end
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
    if not G.world.isUnderground(ax, ay, az) and G.world.rayTerrain(ax, ay, az, dx, dy, dz, l - 0.5) then return false end
    return true
end

local function say(h, text)
    local pl = G.player
    local px, py, pz = pl.feetWorld()
    if U.dist2(px, pz, h.x, h.z) < 25 and G.ui then
        local lines = H.AMBIENT[h.faction]
        G.ui.say(h.faction == "loner" and h.name or H.FACTIONS[h.faction].name, text or lines[math.random(#lines)])
        if G.audio then G.audio.play("voice", { x = h.x, y = h.y + 1.6, z = h.z, volume = 0.5, pitch = h.faction == "loner" and 1.0 or 0.82 }) end
    end
end

local function groundY(h, x, z)
    local W = G.world
    local t = W.groundHeight(x, z)
    local g = P.groundHeight({ W.staticSet }, x, h.y + 0.5, z, 0.3, 0.6)
    return math.max(t, g)
end

local function moveTo(h, x, z, speed, dt)
    local dx, dz = x - h.x, z - h.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 0.5 then h.speed = U.damp(h.speed, 0, 8, dt) return true end
    local want = math.atan2(dz, dx)
    h.yaw = U.dampAngle(h.yaw, want, 6, dt)
    h.speed = U.damp(h.speed, speed, 5, dt)
    local nx, nz = h.x + math.cos(h.yaw) * h.speed * dt, h.z + math.sin(h.yaw) * h.speed * dt
    local px, pz = P.pushOut({ G.world.staticSet, G.tank.extSet }, nx, h.y, nz, 0.3, 1.7, 0.45)
    -- stuck against something: sidestep
    if U.dist2(px, pz, nx, nz) > 0.01 then h.stuck = (h.stuck or 0) + dt else h.stuck = 0 end
    if h.stuck > 1.2 then h.yaw = h.yaw + (math.random() < 0.5 and 1.3 or -1.3) h.stuck = 0 end
    h.x, h.z = px, pz
    h.y = U.damp(h.y, groundY(h, h.x, h.z), 12, dt)
    h.phase = h.phase + dt * h.speed * 2.6
    return false
end

local function muzzle(h)
    local c, s = math.cos(h.yaw), math.sin(h.yaw)
    return h.x + c * 0.8 - s * 0.12, h.y + 1.42, h.z + s * 0.8 + c * 0.12
end

local function shootAt(h, tx, ty, tz, accuracy, kind)
    H.shots = (H.shots or 0) + 1
    local mx, my, mz = muzzle(h)
    local dist = U.dist3(mx, my, mz, tx, ty, tz)
    local err = accuracy * (0.6 + dist / 60)
    local dx, dy, dz = U.norm3(tx - mx + (math.random() - 0.5) * err * dist * 0.05, ty - my + (math.random() - 0.5) * err * dist * 0.05,
        tz - mz + (math.random() - 0.5) * err * dist * 0.05)
    G.weapons.hitscan(mx, my, mz, dx, dy, dz, 160, kind == "enemy" and 14 or 24, kind, math.random() < 0.35)
    G.effects.muzzleFlash(mx, my, mz, dx, dy, dz, 0.4)
    if G.audio then G.audio.play(h.faction == "loner" and "rifle" or "smg", { x = mx, y = my, z = mz, volume = 0.8 }) end
    H.noise(mx, my, mz, 120)
end

local function playerTarget()
    local pl = G.player
    if pl.mode == "dead" then return nil end
    if pl.frameName == "tank" then local T = G.tank return T.x, T.y + 1.5, T.z, true end
    return pl.x, pl.y + 1.3, pl.z, false
end

-- nearest visible enemy: the player (if this one is hostile to them) or a person of a hostile faction
local function pickTarget(h)
    local best, bd, bx, by, bz, inTank = nil, 1e9, nil, nil, nil, false
    local vis = 0.5 + 0.5 * G.environment.daylight
    local fog = 1 - 0.35 * G.weather.intensity
    local fx, fz = math.cos(h.yaw), math.sin(h.yaw)
    if h.hostile then
        local tx, ty, tz, tank = playerTarget()
        if tx then
            local v = vis
            if G.player.flashlight then v = 1 end
            if G.player.crouch and not tank then v = v * 0.6 end
            local range = (tank and 140 or 70) * v * fog
            local d = U.dist3(h.x, h.y + 1.6, h.z, tx, ty, tz)
            local facing = (fx * (tx - h.x) + fz * (tz - h.z)) / math.max(d, 0.1)
            if d < range and (facing > -0.3 or d < 10 or h.state == "combat") and los(h.x, h.y + 1.6, h.z, tx, ty, tz) then
                best, bd, bx, by, bz, inTank = "player", d, tx, ty, tz, tank
            end
        end
    end
    local enemies = H.ENEMIES[h.faction]
    for _, o in ipairs(H.list) do
        if o ~= h and o.state ~= "dead" and enemies[o.faction] then
            local d = U.dist2(h.x, h.z, o.x, o.z)
            if d < 75 * vis * fog and d < bd then
                local facing = (fx * (o.x - h.x) + fz * (o.z - h.z)) / math.max(d, 0.1)
                if (facing > -0.2 or d < 12 or h.state == "combat") and los(h.x, h.y + 1.6, h.z, o.x, o.y + 1.3, o.z) then
                    best, bd, bx, by, bz, inTank = o, d, o.x, o.y + 1.2, o.z, false
                end
            end
        end
    end
    return best, bx, by, bz, inTank
end

-- the rest of a wary post turns to watch while one of them does the talking
local function alertFriendsChallenge(h)
    local px, _, pz = G.player.feetWorld()
    local speaker, sd = h, h.role == "sit" and 1e9 or U.dist2(h.x, h.z, px, pz)
    for _, o in ipairs(H.list) do
        if o ~= h and o.faction == h.faction and o.state ~= "dead" and o.wary and not o.hostile
            and math.abs(o.x - h.x) + math.abs(o.z - h.z) < 40 and o.state ~= "combat" then
            o.state, o.timer, o.watchOnly, o.challenged = "challenge", 0, true, false
            -- the nearest one on his feet walks over and does the talking
            local d = U.dist2(o.x, o.z, px, pz)
            if o.role ~= "sit" and not o.fixedY and d < sd then speaker, sd = o, d end
        end
    end
    h.watchOnly = true
    speaker.watchOnly = false
end

local function alertFriends(h, tx, tz, target)
    for _, o in ipairs(H.list) do
        if o ~= h and o.faction == h.faction and o.state ~= "dead" and o.state ~= "combat" and o.state ~= "flee"
            and U.dist2(o.x, o.z, h.x, h.z) < 45 then
            -- a fight with the player: the wary ones join in
            if target == "player" and h.hostile then o.hostile, o.wary = true, false end
            o.state = "combat" o.lastX, o.lastZ, o.lastSeen = tx, tz, 0
        end
    end
end

---------------------------------------------------------------------------
-- AI
---------------------------------------------------------------------------
-- where a squad member should stand when the squad is walking
local function squadGoal(h)
    local sq = h.squad
    local wp = sq.def.route[sq.wp]
    local hx, hz = wp[1] - sq.x, wp[2] - sq.z
    local l = math.max(0.1, math.sqrt(hx * hx + hz * hz))
    hx, hz = hx / l, hz / l
    local back = (h.slot - 1) * 3
    local side = (h.slot % 2 == 0) and 1.6 or -1.6
    if h.slot == 1 then side = 0 end
    return sq.x - hx * back - hz * side, sq.z - hz * back + hx * side
end

local function updateSquad(sq, dt, px, pz)
    local alive, fighting = 0, false
    for _, m in ipairs(sq.members) do
        if m.state ~= "dead" then
            alive = alive + 1
            if m.state == "combat" or m.state == "search" or m.state == "flee" then fighting = true end
        end
    end
    if alive == 0 then
        sq.deadT = sq.deadT + dt
        local r = sq.def.route[1]
        if sq.deadT > RESPAWN and U.dist2(px, pz, r[1], r[2]) > 300 then
            -- a new group takes their place
            sq.deadT, sq.wp, sq.x, sq.z = 0, 2, r[1], r[2]
            for k, m in ipairs(sq.members) do
                m.state, m.hp, m.looted, m.deathT, m.speed = "idle", 95, false, 0, 0
                m.wary = wary(m.faction, sq.id * 7)
                m.hostile = (not m.wary) and H.FACTIONS[m.faction].hostile
                m.passed = false
                m.loot = lootFor(m.faction)
                m.x, m.z = r[1] + math.cos(k) * 2, r[2] + math.sin(k) * 2
                m.y = G.world.groundHeight(m.x, m.z)
            end
        end
        return
    end
    if fighting then return end
    -- the squad anchor walks the route; members follow it in a loose file
    local wp = sq.def.route[sq.wp]
    local dx, dz = wp[1] - sq.x, wp[2] - sq.z
    local d = math.sqrt(dx * dx + dz * dz)
    local near = U.dist2(px, pz, sq.x, sq.z) < ACTIVE
    -- online the anchor waits for stragglers
    local lag = 0
    if near then
        for _, m in ipairs(sq.members) do
            if m.state ~= "dead" then
                local gx, gz = squadGoal(m)
                lag = math.max(lag, U.dist2(m.x, m.z, gx, gz))
            end
        end
    end
    local speed = lag > 8 and 0.3 or 1.35
    if d < 2 then
        sq.wp = sq.wp % #sq.def.route + 1
        sq.pause = 8 + math.random() * 20
    elseif (sq.pause or 0) > 0 then
        sq.pause = sq.pause - dt
    else
        sq.x, sq.z = sq.x + dx / d * speed * dt, sq.z + dz / d * speed * dt
    end
    if not near then
        -- offline: members just travel with the anchor
        for _, m in ipairs(sq.members) do
            if m.state ~= "dead" then
                m.x, m.z = squadGoal(m)
                m.yaw = math.atan2(dz, dx)
                m.state = "idle"
                m.offline = true
            end
        end
    end
end

-- a wary sentry notices the player: on foot you get challenged, a German tank gets no questions
local function watchPlayer(h)
    if not h.wary or h.hostile or h.passed or h.state == "combat" or h.state == "flee" or h.state == "challenge" then return end
    local tx, ty, tz, tank = playerTarget()
    if not tx then return end
    local d = U.dist3(h.x, h.y + 1.6, h.z, tx, ty, tz)
    if d > (tank and 130 or 24) then return end
    local fx, fz = math.cos(h.yaw), math.sin(h.yaw)
    local facing = (fx * (tx - h.x) + fz * (tz - h.z)) / math.max(d, 0.1)
    if (facing > -0.3 or d < 8) and los(h.x, h.y + 1.6, h.z, tx, ty, tz) then
        if tank then
            h.wary, h.hostile = false, true
        else
            h.state, h.timer, h.challenged = "challenge", 0, false
            alertFriendsChallenge(h)
        end
    end
end

local function updateFighter(h, dt)
    h.watchT = (h.watchT or math.random() * 0.4) - dt
    if h.watchT <= 0 then h.watchT = 0.4 watchPlayer(h) end
    -- sensing
    h.senseT = (h.senseT or math.random() * 0.3) - dt
    if h.senseT <= 0 then
        h.senseT = 0.35
        local t, tx, ty, tz, inTank = pickTarget(h)
        h.target, h.tx, h.ty, h.tz, h.tInTank = t, tx, ty, tz, inTank
        if t then
            h.lastX, h.lastZ, h.lastSeen = tx, tz, 0
            if h.state ~= "combat" and h.state ~= "flee" then
                h.state = "combat"
                h.cool = 0.8 + math.random()
                say(h)
                alertFriends(h, tx, tz, t)
            end
        else
            for _, n in ipairs(H.noises) do
                if h.state ~= "combat" and h.state ~= "flee" and U.dist3(h.x, h.y, h.z, n.x, n.y, n.z) < n.r then
                    if h.faction ~= "loner" or h.hostile then h.state = "search" h.lastX, h.lastZ = n.x, n.z h.timer = 15 end
                end
            end
        end
    end
    h.lastSeen = (h.lastSeen or 99) + dt
    local s = h.state
    if s == "combat" then
        local t = h.target
        if t and t ~= "player" and t.state == "dead" then h.target = nil t = nil end
        if t then
            local tx, ty, tz = h.tx, h.ty, h.tz
            if t ~= "player" then tx, ty, tz = t.x, t.y + 1.2, t.z end
            local d = U.dist2(h.x, h.z, tx, tz)
            -- bandits run from armour
            if h.faction == "bandit" and h.tInTank and d < 70 and math.random() < dt * 0.6 then
                h.state = "flee" h.timer = 8 say(h, "He's got a tank! Run!")
                return
            end
            local want = math.atan2(tz - h.z, tx - h.x)
            -- keep a fighting distance and strafe (sitting and fixed guards stay put)
            h.strafeT = (h.strafeT or 0) - dt
            if h.strafeT <= 0 then h.strafeT = 1.5 + math.random() * 2 h.strafe = (math.random() - 0.5) * 2 end
            local ideal = h.faction == "military" and 34 or 26
            local fwd = d > ideal + 8 and 1 or (d < ideal - 10 and -1 or 0)
            if h.role ~= "trader" and not h.fixedY then
                local c, sn = math.cos(want), math.sin(want)
                moveTo(h, h.x + (c * fwd - sn * h.strafe) * 4, h.z + (sn * fwd + c * h.strafe) * 4, 2.4, dt)
            else
                h.speed = U.damp(h.speed, 0, 6, dt)
            end
            h.yaw = U.dampAngle(h.yaw, want, 10, dt)
            h.aim = U.damp(h.aim, 1, 8, dt)
            h.aimPitch = math.atan2(ty - (h.y + 1.42), math.max(d, 0.5))
            h.cool = h.cool - dt
            if h.cool <= 0 and h.aim > 0.8 then
                h.burst = h.burst + 1
                local moving = t == "player" and (G.player.bobAmt or 0) or (t.speed or 0) / 3
                local kind = t == "player" and "enemy" or "npc"
                local acc = (t == "player" and h.tInTank) and 0.4 or (0.5 + moving * 0.8)
                if h.faction == "military" then acc = acc * 0.8 end
                shootAt(h, tx + (math.random() - 0.5) * moving * 1.5, ty, tz, acc, kind)
                if h.burst >= (h.faction == "military" and 4 or 3) then h.burst = 0 h.cool = 1.3 + math.random() * 1.6 else h.cool = 0.12 end
            end
        else
            h.aim = U.damp(h.aim, 0, 4, dt)
            if h.lastX and not h.fixedY and h.role ~= "trader" then moveTo(h, h.lastX, h.lastZ, 2.6, dt) end
            if h.lastSeen > 10 then h.state = "search" h.timer = 10 end
        end
    elseif s == "challenge" then
        -- rifle up, walk to talking distance and ask; run off or point a gun at them and they open fire
        local tx, ty, tz, tank = playerTarget()
        if not tx or tank then h.state = "combat" h.hostile = true return end
        local d = U.dist2(h.x, h.z, tx, tz)
        local want = math.atan2(tz - h.z, tx - h.x)
        h.yaw = U.dampAngle(h.yaw, want, 6, dt)
        h.aim = U.damp(h.aim, 1, 5, dt)
        h.aimPitch = math.atan2(ty - (h.y + 1.42), math.max(d, 0.5))
        h.timer = h.timer + dt
        if not h.challenged and not h.watchOnly then
            h.challenged = true
            say(h, h.faction == "military" and "STOI! Don't move!" or "Hey you! Stay right there!")
        end
        if not h.watchOnly and d > 4.5 and not h.fixedY and h.role ~= "sit" then moveTo(h, tx, tz, 1.8, dt)
        else h.speed = U.damp(h.speed, 0, 6, dt) end
        if d > 40 then
            -- walked off: that settles it
            h.state, h.hostile = "combat", true
            h.lastX, h.lastZ, h.lastSeen = tx, tz, 0
        elseif not h.watchOnly and (d < 6.5 or h.timer > 6) and G.game.state == "play" and G.player.frameName == "world" then
            G.dialog.open(h)
        end
        -- a rifle pointed at them is an answer too
        local Wp = G.weapons
        if Wp.aiming and d < 30 then
            local cam = G.camera
            local ax, az = h.x - cam.x, h.z - cam.z
            local al = math.max(0.1, math.sqrt(ax * ax + az * az))
            if (cam.fx * ax + cam.fz * az) / al > 0.97 then
                h.aimedAt = (h.aimedAt or 0) + dt
                if h.aimedAt > 1.0 then
                    say(h, "He's going for his gun!")
                    h.state, h.hostile = "combat", true
                    h.lastX, h.lastZ, h.lastSeen = tx, tz, 0
                end
            end
        end
    elseif s == "flee" then
        h.timer = h.timer - dt
        local tx, ty, tz = playerTarget()
        if tx then
            local ax, az = h.x - tx, h.z - tz
            local l = math.max(0.1, math.sqrt(ax * ax + az * az))
            moveTo(h, h.x + ax / l * 8, h.z + az / l * 8, 4.2, dt)
        end
        if h.timer <= 0 then h.state = "combat" end
    elseif s == "search" then
        h.aim = U.damp(h.aim, 0, 3, dt)
        h.timer = (h.timer or 10) - dt
        if h.lastX and not h.fixedY then moveTo(h, h.lastX, h.lastZ, 2.0, dt) end
        if h.timer <= 0 then h.state = "return" end
    else
        h.aim = U.damp(h.aim, 0, 3, dt)
        if h.squad then
            local gx, gz = squadGoal(h)
            if U.dist2(h.x, h.z, gx, gz) > 1.2 then moveTo(h, gx, gz, U.dist2(h.x, h.z, gx, gz) > 6 and 2.2 or 1.4, dt)
            else h.speed = U.damp(h.speed, 0, 6, dt) end
            h.state = "idle"
        elseif s == "return" then
            if moveTo(h, h.homeX, h.homeZ, 1.4, dt) then
                h.state = h.role == "sit" and "sit" or "idle"
                h.timer = 3
            end
        elseif s == "sit" then
            h.speed = 0
            h.yaw = U.dampAngle(h.yaw, h.homeYaw, 3, dt)
        elseif s == "walk" then
            h.timer = h.timer - dt
            if moveTo(h, h.px, h.pz, 1.2, dt) or h.timer <= 0 then h.state = "idle" h.timer = 4 + math.random() * 6 end
        else
            h.speed = U.damp(h.speed, 0, 6, dt)
            h.timer = (h.timer or 3) - dt
            if h.timer <= 0 then
                if h.role == "patrol" or (h.role == "guard" and math.random() < 0.4) then
                    local a = math.random() * 6.28
                    local r = h.role == "patrol" and 14 or 6
                    h.px, h.pz = h.homeX + math.cos(a) * r, h.homeZ + math.sin(a) * r
                    h.state = "walk" h.timer = 20
                else
                    h.timer = 3 + math.random() * 5
                    h.yaw = h.yaw + (math.random() - 0.5) * 1.5
                end
            end
        end
    end
    -- survivors chat when the player is around
    if not h.hostile and h.faction == "loner" then
        h.sayT = h.sayT - dt
        if h.sayT <= 0 then h.sayT = 22 + math.random() * 30 if h.state == "sit" then say(h) end end
    end
end

function H.update(dt)
    local px, py, pz = G.player.feetWorld()
    for _, sq in ipairs(H.squads) do updateSquad(sq, dt, px, pz) end
    for _, h in ipairs(H.list) do
        if h.state == "dead" then
            h.deathT = h.deathT + dt
        else
            local d = U.dist2(px, pz, h.x, h.z)
            if d < ACTIVE then
                if h.offline then h.offline = false h.y = G.world.groundHeight(h.x, h.z) end
                updateFighter(h, dt)
            end
        end
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
        if h.state ~= "dead" and math.abs(h.x - ox) < maxT + 3 and math.abs(h.z - oz) < maxT + 3 and U.dist3(ox, oy, oz, h.x, h.y, h.z) < maxT + 3 then
            local sit = h.state == "sit"
            local cy = h.y + (sit and 0.8 or 1.1)
            local t = P.raySphere(ox, oy, oz, dx, dy, dz, h.x, cy, h.z, sit and 0.4 or 0.33)
            if not t then t = P.raySphere(ox, oy, oz, dx, dy, dz, h.x, h.y + (sit and 0.4 or 0.5), h.z, 0.3) end
            if t and t > 0.6 and t < bestT then bestT, best, part = t, h, "body" end
            local ht = P.raySphere(ox, oy, oz, dx, dy, dz, h.x, h.y + (sit and 1.25 or 1.7), h.z, 0.16)
            if ht and ht > 0.6 and ht < bestT then bestT, best, part = ht, h, "head" end
        end
    end
    if best then return bestT, best, part end
end

function H.damage(h, amount, byPlayer)
    if h.state == "dead" then return end
    h.hp = h.hp - amount
    if G.audio then G.audio.play("hurt", { x = h.x, y = h.y + 1.5, z = h.z, volume = 0.6, pitch = 0.8 }) end
    if byPlayer and not h.hostile then
        -- shooting a survivor turns their friends against you
        for _, o in ipairs(H.list) do
            if o.faction == h.faction and U.dist2(o.x, o.z, h.x, h.z) < 40 then o.hostile = true end
        end
        if G.ui then G.ui.warning(h.faction == "loner" and "THE SURVIVORS TURNED HOSTILE" or (h.faction == "military" and "THE SOLDIERS OPEN FIRE" or "THE BANDITS OPEN FIRE")) end
    end
    if h.state ~= "combat" and h.state ~= "flee" then
        h.state = "combat"
        if byPlayer then
            local tx, ty, tz = playerTarget()
            h.lastX, h.lastZ, h.lastSeen = tx, tz, 0
        end
    end
    if h.hp <= 0 then
        h.state = "dead"
        h.deathT = 0
        h.speed = 0
        if G.audio then G.audio.play("hurt", { x = h.x, y = h.y + 1, z = h.z, pitch = 0.6, volume = 0.8 }) end
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

-- is anyone fighting near the player (music ducking)
function H.nearestThreat(x, z, r)
    for _, h in ipairs(H.list) do
        if h.state == "combat" and h.hostile and math.abs(h.x - x) < r and math.abs(h.z - z) < r then return h end
    end
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
local framePool, frameIdx = {}, 0
local function frame()
    frameIdx = frameIdx + 1
    local f = framePool[frameIdx]
    if not f then f = M3.frame() framePool[frameIdx] = f end
    return f
end

local tmpChild = M3.frame()
local function child(parent, x, y, z, yaw, pitch, roll)
    tmpChild:setYawPitchRoll(yaw or 0, pitch or 0, roll or 0)
    tmpChild.px, tmpChild.py, tmpChild.pz = x, y, z
    return parent:compose(tmpChild, frame())
end

-- rotate a frame's basis by the shortest rotation taking direction a onto direction b
local function swingFrame(f, ax, ay, az, bx, by, bz)
    local kx, ky, kz = U.cross(ax, ay, az, bx, by, bz)
    local s = math.sqrt(kx * kx + ky * ky + kz * kz)
    local c = ax * bx + ay * by + az * bz
    if s < 1e-6 then return f end
    kx, ky, kz = kx / s, ky / s, kz / s
    local function rot(x, y, z)
        -- Rodrigues
        local d = kx * x + ky * y + kz * z
        local cx, cy, cz = U.cross(kx, ky, kz, x, y, z)
        return x * c + cx * s + kx * d * (1 - c), y * c + cy * s + ky * d * (1 - c), z * c + cz * s + kz * d * (1 - c)
    end
    f.fx, f.fy, f.fz = rot(f.fx, f.fy, f.fz)
    f.ux, f.uy, f.uz = rot(f.ux, f.uy, f.uz)
    f.rx, f.ry, f.rz = rot(f.rx, f.ry, f.rz)
    return f
end

H.DRAW_DIST = 170

-- joint layout of the procedural outfits and the character-pack figures; modelled people carry their own
local RIG_DIMS = { hipY = 0.92, legY = -0.02, torsoY = 0.02, hip = Rig.HIP, knee = { 0, -Rig.THIGH, 0 }, neck = { 0.02, 0.6, 0 },
                   shoulder = Rig.SHOULDER, upper = Rig.UPPER, fore = Rig.FORE }

function H.draw()
    matIdx, frameIdx = 0, 0
    local cam = R.cam
    for _, h in ipairs(H.list) do
        if math.abs(h.x - cam.x) < H.DRAW_DIST and math.abs(h.z - cam.z) < H.DRAW_DIST and R.visible(h.x, h.y + 1, h.z, 2) then
            local m = H.looks[h.look] or H.looks.loner
            local dm = m.dims or RIG_DIMS
            local sit = h.state == "sit"
            local dead = h.state == "dead"
            local walk = math.min(1, h.speed / 1.5)
            local ph = h.phase
            local root = frame()
            local fall = dead and math.min(1.45, h.deathT * 3) or 0
            root:setYawPitchRoll(h.yaw, -fall, 0)
            local hipH = sit and dm.hipY * 0.5 or (dm.hipY + math.abs(math.sin(ph)) * 0.03 * walk)
            if dead then hipH = U.lerp(dm.hipY, 0.18, fall / 1.45) end
            root.px, root.py, root.pz = h.x, h.y + hipH, h.z
            local p = { interior = 0 }
            -- legs
            for side = -1, 1, 2 do
                local swing = sit and 1.45 or (math.sin(ph + (side > 0 and math.pi or 0)) * 0.55 * walk)
                local thigh = child(root, 0, dm.legY or 0, side * dm.hip, 0, swing, 0)
                local split = m.pack or m.people
                R.drawModel(split and (side < 0 and m.thighL or m.thighR) or m.thigh, thigh:matrix(mat()), p)
                local knee = sit and -1.5 or (-math.max(0, math.sin(ph + (side > 0 and math.pi or 0) - 1.2)) * 0.8 * walk)
                local k = dm.knee
                local shin = child(thigh, k[1], k[2], k[3] * side, 0, knee, 0)
                R.drawModel(split and (side < 0 and m.shinL or m.shinR) or m.shin, shin:matrix(mat()), p)
            end
            -- torso leans into the aim
            local lean = sit and 0.25 or (h.aim * 0.1)
            local torso = child(root, 0, dm.torsoY or 0, 0, 0, -lean, 0)
            R.drawModel(m.torso, torso:matrix(mat()), p)
            local head = child(torso, dm.neck[1], dm.neck[2], 0, h.lookYaw, sit and -0.2 or h.aimPitch * h.aim * 0.6, 0)
            R.drawModel(m.head, head:matrix(mat()), p)
            -- weapon: low ready -> shouldered, resting across the knees when sitting
            local aim = h.aim
            local gun
            if sit then gun = child(torso, 0.38, 0.12, 0.02, 0.35, -0.12, 0.2)
            elseif dead then gun = child(root, 0.3, -0.75, 0.4, 1.2, 0, 1.4)
            else
                local pitch = U.lerp(-0.55, h.aimPitch + lean, aim)
                gun = child(torso, U.lerp(0.3, 0.4, aim), U.lerp(0.2, 0.47, aim), U.lerp(0.06, 0.13, aim), U.lerp(-0.55, 0, aim), pitch, U.lerp(0.25, 0, aim))
            end
            if not dead or h.deathT < 30 then R.drawModel(H.gun, gun:matrix(mat()), p) end
            -- arms reach for the grip and the handguard (two-bone IK in world space)
            for side = -1, 1, 2 do
                local sh = dm.shoulder
                local sx, sy, sz = torso:toWorld(sh[1], sh[2], sh[3] * side)
                local hp = side > 0 and GRIP or GUARD
                local tx, ty, tz
                if dead and h.deathT > 0.3 then
                    tx, ty, tz = torso:toWorld(0.1, 0.0, side * 0.45)
                else
                    tx, ty, tz = gun:toWorld(hp[1], hp[2], hp[3])
                end
                if m.pack then
                    -- one-piece arm from the character pack: swing it from the shoulder towards the hand target
                    local af = child(torso, 0.02, 0.52, side * 0.24, 0, 0, 0)
                    local rest = side < 0 and m.armLDir or m.armRDir
                    local rx, ry, rz = torso:dirToWorld(rest[1], rest[2], rest[3])
                    local dx, dy, dz = U.norm3(tx - af.px, ty - af.py, tz - af.pz)
                    swingFrame(af, rx, ry, rz, dx, dy, dz)
                    R.drawModel(side < 0 and m.armL or m.armR, af:matrix(mat()), p)
                else
                    -- elbows point down and out
                    local ox, oy, oz = torso:dirToWorld(-0.2, -1, side * 0.7)
                    local uf, ff = frame(), frame()
                    Rig.armFrames(sx, sy, sz, tx, ty, tz, ox, oy, oz, torso.ux, torso.uy, torso.uz, uf, ff, dm.upper, dm.fore)
                    R.drawModel(m.people and (side < 0 and m.upperL or m.upperR) or m.upper, uf:matrix(mat()), p)
                    R.drawModel(m.people and (side < 0 and m.foreL or m.foreR) or m.fore, ff:matrix(mat()), p)
                end
            end
        end
    end
end

return H
