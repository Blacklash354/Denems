-- Automated playtest: drives the game with simulated input and captures screenshots:
-- the tank and its stations, the places of the open world, stairs in a panel block, clothing
-- against the cold, factions fighting, squads on the move, reloads, save/load and the ending.
-- Run: love . --autotest   (screenshots land in the LÖVE save directory under autotest/)
local A = { keys = {}, mouse = {} }
local U = require("src.utils")
local G
local steps, idx, stepT = {}, 1, 0
local shotPending

local realIsDown = love.keyboard.isDown
local realMouseDown = love.mouse.isDown
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do if A.keys[k] then return true end end
    return false
end
love.mouse.isDown = function(...)
    for _, b in ipairs({ ... }) do if A.mouse[b] then return true end end
    return false
end

local function log(...) print("[autotest]", ...) end
local function S(dur, fn, shot) steps[#steps + 1] = { dur = dur, fn = fn, shot = shot } end
local function press(k) A.keys = {} if k then A.keys[k] = true end end

local function lookAt(x, y, z)
    local Pl = G.player
    local ex, ey, ez = Pl.eyeWorld()
    local dx, dy, dz = x - ex, y - ey, z - ez
    if Pl.frameName == "tank" then dx, dy, dz = G.tank.frame:dirToLocal(dx, dy, dz) end
    Pl.yaw = math.atan2(dz, dx)
    Pl.pitch = math.atan2(dy, math.sqrt(dx * dx + dz * dz))
end

local function teleport(x, z, yaw, pitch)
    local Pl = G.player
    Pl.placeWalking("world", x, G.world.height(x, z) + 0.1, z, yaw)
    Pl.pitch = pitch or 0
    G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.helpT = nil
    -- scripted walks must not be stopped by a sentry asking questions (tools/talktest.lua covers that)
    G.dialog.open = function() end
    love.filesystem.createDirectory("autotest")
    local Pl, T, Game = G.player, G.tank, G.game
    local W = G.world
    -- 1: inside the tank
    S(1.5, function() Pl.yaw = 0.4 Pl.pitch = -0.1 end, "01_interior_spawn")
    S(0.1, function() Pl.yaw = math.pi Pl.pitch = 0.05 end)
    S(1.0, nil, "02_interior_rear_storage")
    S(0.1, function() Pl.yaw = 0 Pl.pitch = -0.15 end)
    S(1.6, function() press("w") end)
    S(0.5, function() press() log("walked forward inside, pos", Pl.x, Pl.y, Pl.z, "height", Pl.height) end, "03_interior_front_compartment")
    -- 2: open storage
    S(0.6, function() Game.openStorage() end, "04_storage_ui")
    S(0.2, function() Game.state = "play" end)
    -- 3: climb ladder, open hatch, climb out
    S(0.3, function() Pl.placeWalking("tank", -0.3, 0.62, -0.75, math.pi) end)
    S(0.2, function() Pl.startLadder("interior", 0.05) press("w") end)
    S(2.5, function() end)
    S(0.4, function() press() log("ladder t", Pl.ladderT, "mode", Pl.mode) Pl.pitch = 0.9 end, "05_ladder_hatch_closed")
    S(1.8, function() Game.toggleHatch() end, "06_hatch_open_from_inside")
    S(2.0, function() press("w") end)
    S(0.8, function() press() log("after climb: frame", Pl.frameName, "mode", Pl.mode, "pos", Pl.x, Pl.y, Pl.z) Pl.pitch = -0.2 end, "07_on_turret_roof")
    S(0.2, function() Pl.yaw = Pl.yaw + math.pi Pl.pitch = -0.6 end)
    S(0.8, nil, "08_looking_into_hatch")
    -- 4: walk off and look at the tank
    S(0.2, function()
        local x, y, z = T.frame:toWorld(9, 0, 6)
        teleport(x, z, 0)
        lookAt(T.x, T.y + 1.5, T.z)
    end)
    S(1.2, nil, "09_tank_exterior")
    S(0.2, function()
        local x, y, z = T.frame:toWorld(-7, 0, -3)
        teleport(x, z, 0)
        lookAt(T.x - 2, T.y + 1.2, T.z)
    end)
    S(1.2, nil, "10_tank_rear_ladder")
    -- climb rear ladder
    S(0.2, function() Pl.startLadder("rear", 0.02) press("w") end)
    S(2.5, function() end)
    S(0.5, function() press() log("rear ladder: frame", Pl.frameName, "mode", Pl.mode, "y", Pl.y, "tankY", T.y) end, "11_on_engine_deck")
    -- 5: driver
    S(0.3, function() Pl.placeWalking("tank", 1.5, 0.62, -0.7, 0) Pl.enterSeat(G.stations.driver) end)
    S(0.3, function() T.startEngine() end)
    S(2.5, function() end)
    S(0.1, function() log("engine on", T.engineOn) press("w") A.keys.lshift = true end)
    S(5.0, function() end, "12_driver_view")
    S(0.1, function() log("tank speed", T.speed, "pos", T.x, T.z, "fuel", T.fuel, "gear", T.gear, "rpm", T.rpm) A.keys.d = true end)
    S(2.0, function() end)
    S(0.1, function() press() log("tank yaw", T.yaw) end)
    S(2.0, function() end)
    S(0.1, function() love.keypressed("v") log("driver third person", G.stations.driver.third) G.stations.driver.mousemoved(0, 0, 0) press("w") end)
    S(2.5, nil, "12b_driver_third_person")
    S(0.1, function() G.stations.driver.mousemoved(900, 0, 0.002) end)
    S(0.6, nil, "12c_third_person_orbit")
    S(0.1, function() press() love.keypressed("v") log("third person off", G.stations.driver.third) end)
    -- 6: gunner
    S(0.2, function() Pl.leaveSeat() Pl.enterSeat(G.stations.gunner) end)
    S(1.0, nil, "13_gunner_seat")
    S(0.2, function() T.startReload() end)
    S(4.8, function() end)
    S(0.3, function() log("loaded", T.loaded) G.stations.gunner.optic = true G.stations.gunner.targetYaw = T.turretYaw + 0.4 end)
    S(2.0, nil, "14_cannon_optic")
    S(0.05, function() A.mouse[1] = true end)
    S(0.15, function() A.mouse[1] = false end, "15_cannon_fire")
    S(1.5, function() end, "16_cannon_impact")
    S(0.2, function() G.stations.gunner.optic = false end)
    S(0.5, nil, "17_gunner_after_shot_interior")
    -- 7: MG
    S(0.2, function() Pl.leaveSeat() Pl.enterSeat(G.stations.mg) end)
    S(0.3, function() A.mouse[1] = true end)
    S(0.4, nil, "18_mg_firing")
    S(0.6, function() A.mouse[1] = false log("mg belt", T.mgBelt, "heat", T.mgHeat) end)
    S(0.2, function() Pl.leaveSeat() end)
    -- 8: places of the open world
    local I = require("src.interaction")
    local function visit(name, id, dist, yawOff, pitch)
        S(0.2, function()
            local l = W[id]
            local a = (yawOff or 0.7)
            local x, z = l.x + math.cos(a) * dist, l.z + math.sin(a) * dist
            teleport(x, z, 0, pitch or 0.05)
            lookAt(l.x, W.height(l.x, l.z) + 3, l.z)
        end)
        S(1.6, nil, name)
    end
    visit("19_kolkhoz", "kolkhoz", 70)
    visit("20_town", "town", 90, 2.0)
    visit("21_city", "city", 120, -0.4)
    visit("22_garages", "garages", 60, 1.5)
    visit("23_airfield", "airfield", 150, 1.8)
    visit("24_industrial", "industrial", 90, 0.3)
    visit("25_military_base", "base", 95, 0.9)
    visit("26_radio_tower", "tower", 60, 2.5, 0.3)
    visit("27_nuclear_plant", "plant", 140, 1.6, 0.15)
    S(0.2, function()
        local b = W.bunkerInfo
        Pl.placeWalking("world", b.ox + 2.5 * 2.5, b.oy + 0.05, b.oz + 2.5 * 8.5, 0)
        Pl.flashlight = true
    end)
    S(2.0, function() end, "29_bunker_interior")
    S(0.1, function() log("underground", G.environment.underground, "cam", G.camera.x, G.camera.y, G.camera.z) end)
    S(0.2, function() Pl.flashlight = false teleport(W.bunker.x + 6, W.bunker.z + 6, -2.4, 0.05) end)
    S(1.5, nil, "30_bunker_entrance")
    -- 9: climbing the stairs of a panel block by walking (real collision, simulated keys)
    S(0.2, function()
        local blk = W.blocks[1]
        A.blk = blk
        local c = blk.ctx
        local sx = -blk.sections * 12 / 2
        -- stand at the foot of the first flight (left lane), facing up the stairs (+z local)
        local x, y, z = c:toWorld(sx + 5.2, 0.4, -5.5 + 0.3 + 1.2)
        local fx, _, fz = c:toWorld(sx + 5.2, 0.4, 5)
        Pl.placeWalking("world", x, y + 0.05, z, math.atan2(fz - z, fx - x))
        Pl.pitch = 0.1
        A.stairY0 = y
        log("block at", blk.x, blk.z, "sections", blk.sections, "floors", blk.floors)
    end)
    S(0.4, nil, "31_stairs_bottom")
    S(1.6, function() press("w") end)
    S(0.1, function() press() log("after first flight: y gain", Pl.y - A.stairY0, "(1.4 expected)") end, "32_half_landing")
    S(0.1, function()
        -- turn round onto the second flight (right lane, back towards the front facade)
        local c = A.blk.ctx
        local sx = -A.blk.sections * 12 / 2
        local x, y, z = c:toWorld(sx + 6.8, 0, -0.5)
        local tx, _, tz = c:toWorld(sx + 6.8, 0, -6)
        Pl.x, Pl.z = x, z
        Pl.yaw = math.atan2(tz - z, tx - x)
    end)
    S(1.6, function() press("w") end)
    S(0.1, function() press() log("after second flight: y gain", Pl.y - A.stairY0, "(2.8 expected = first floor)") end, "33_first_floor_landing")
    -- 10: clothing and the cold
    S(0.2, function()
        local Inv = G.inventory
        log("insulation start", Inv.insulation())
        Inv.player:add("sheepskin", 1) Inv.player:add("valenki", 1) Inv.player:add("ushanka", 1)
        Inv.use("sheepskin") Inv.use("valenki") Inv.use("ushanka")
        log("insulation dressed", Inv.insulation(), "torso", Inv.worn.torso, "old jacket in pack", Inv.player:count("telogreika"))
        Game.state = "inventory"
    end, nil)
    S(0.3, nil, "34_inventory_clothes")
    S(0.2, function() Game.state = "play" teleport(W.START.x + 60, W.START.z - 80, 0, 0) G.weather.intensity = 1 G.weather.target = 1 G.environment.time = 2 Pl.warmth = 100 end)
    S(10, function() end)
    S(0.1, function()
        log("warmth after 10s night blizzard, dressed", Pl.warmth)
        local Inv = G.inventory
        for _, slot in ipairs(Inv.SLOTS) do Inv.worn[slot] = nil end
        Pl.warmth = 100
    end)
    S(10, function() end)
    S(0.1, function()
        log("warmth after 10s night blizzard, naked", Pl.warmth)
        G.inventory.worn = { head = "wool_cap", torso = "telogreika", legs = "trousers", hands = "gloves", feet = "boots" }
        G.weather.intensity = 0.3 G.weather.target = 0.3 G.environment.time = 13 Pl.warmth = 100
    end)
    -- 11: people fighting each other
    S(0.2, function()
        local H = G.humans
        local sol, ban
        for _, h in ipairs(H.list) do
            if h.faction == "military" and not sol and not h.squad and h.state ~= "dead" then sol = h end
            if h.faction == "bandit" and not ban and not h.squad and h.state ~= "dead" then ban = h end
        end
        A.sol, A.ban = sol, ban
        -- put the bandit 25 m in front of the soldier, the player watches from the side
        ban.x, ban.z = sol.x + math.cos(sol.yaw) * 25, sol.z + math.sin(sol.yaw) * 25
        ban.y = W.height(ban.x, ban.z) ban.homeX, ban.homeZ = ban.x, ban.z
        H.shots = 0
        teleport(sol.x + math.cos(sol.yaw + 1.5) * 18, sol.z + math.sin(sol.yaw + 1.5) * 18, 0, 0)
        lookAt((sol.x + ban.x) / 2, sol.y + 1, (sol.z + ban.z) / 2)
        G.game.godMode = true
        log("faction fight: soldier", sol.name, "vs bandit at", math.floor(U.dist2(sol.x, sol.z, ban.x, ban.z)), "m")
    end)
    S(2.5, nil, "35_faction_fight")
    S(6.0, function() end)
    S(0.1, function() log("after 8.5s: shots", G.humans.shots, "soldier", A.sol.state, A.sol.hp, "bandit", A.ban.state, A.ban.hp) end)
    -- 12: squads walk their routes even while far away
    S(0.1, function()
        local sq = G.humans.squads[1]
        A.sq0 = { sq.x, sq.z, sq.wp }
        teleport(W.START.x, W.START.z + 10, 0, 0)
    end)
    S(4.0, function() end)
    S(0.1, function()
        local sq = G.humans.squads[1]
        log("squad 1 moved", math.floor(U.dist2(sq.x, sq.z, A.sq0[1], A.sq0[2]) * 10) / 10, "m in 4s, waypoint", sq.wp, "members", #sq.members)
    end)
    -- 13: weapons - magazine goes in when the hand seats it, shotgun loads shell by shell
    S(0.2, function()
        local Wp = G.weapons
        Wp.switch("smg") Wp.switchT = 0
        Wp.mag.smg = 0
        G.inventory.player:add("pistol_ammo", 60)
        Wp.reload()
        log("reload started", Wp.reloadT, "mag", Wp.mag.smg)
    end)
    S(0.8, nil, "36_reload_hand_on_mag")
    S(0.1, function() log("mag mid-reload", G.weapons.mag.smg) end)
    S(3.0, function() end)
    S(0.1, function()
        local Wp = G.weapons
        log("mag after reload", Wp.mag.smg)
        Wp.switch("shotgun") Wp.switchT = 0
        Wp.mag.shotgun = 2
        G.inventory.player:add("shotgun_ammo", 10)
        Wp.reload()
    end)
    S(1.0, nil, "37_shotgun_loading")
    S(0.1, function() log("shotgun shells after 1s", G.weapons.mag.shotgun) end)
    S(3.0, function() end)
    S(0.1, function() log("shotgun shells after 4s", G.weapons.mag.shotgun, "reloading", G.weapons.reloadT > 0) end)
    -- 14: UI screens and save/load roundtrip
    S(0.3, function() Game.state = "map" for _, l in ipairs(W.locations) do G.missions.discovered[l.id] = true end end, "38_map")
    S(0.2, function() Game.state = "play" G.environment.time = 23 teleport(T.x + 8, T.z + 3, 0) lookAt(T.x, T.y + 1, T.z) Pl.flashlight = true end)
    S(1.5, nil, "39_night_flashlight")
    S(0.2, function()
        Pl.flashlight = false G.environment.time = 14
        G.inventory.worn.torso = "greatcoat"
        local ok, err = G.save.save()
        log("save", ok, err)
        T.fuel = 3
        G.inventory.worn.torso = nil
        local ok2 = Game.loadGame()
        log("load", ok2, "fuel restored", T.fuel, "coat restored", G.inventory.worn.torso)
    end)
    -- 15: repair and refuel on the tank
    S(0.2, function()
        Game.state = "play"
        T.comp.trackR = 20
        G.inventory.player:add("repair_kit", 1)
        local x, y, z = T.frame:toWorld(0, 0, 3.4)
        teleport(x, z, 0, -0.3)
        local tx, ty, tz = T.frame:toWorld(0, 0.9, 2.15)
        lookAt(tx, ty, tz)
    end)
    S(0.4, function() log("repair prompt:", I.currentText) I.press() press("e") end)
    S(4.0, function() end)
    S(0.1, function() press() log("trackR after repair", T.comp.trackR) end)
    -- 16: bunker transition, keycard, control room, ending
    S(0.2, function()
        for _, d in ipairs(W.doors) do
            if not d.transition and not d.locked then
                Game.useDoor(d)
                log("door open", d.open, "collider enabled", d.box.enabled)
                break
            end
        end
        for _, d in ipairs(W.doors) do
            if d.transition and d.transition.inside then Game.useDoor(d) break end
        end
    end)
    S(1.5, function() end)
    S(0.1, function() log("bunker transition: underground", W.isUnderground(Pl.x, Pl.y + 1, Pl.z) ~= nil, "stage", G.missions.stage) end)
    S(0.2, function()
        G.inventory.player:add("keycard", 1)
        G.missions.event("picked", "keycard")
        for _, d in ipairs(W.doors) do
            if d.locked then Game.useDoor(d) log("control door unlocked", d.unlocked, "open", d.open) end
        end
        local cr = W.controlRoom
        Pl.placeWalking("world", cr.x0 + 6, cr.y + 0.05, cr.z0 + 4, 0)
    end)
    S(0.5, function() end, "40_control_room")
    S(0.1, function()
        log("control entered stage", G.missions.stage)
        local c = W.signalConsole
        Pl.placeWalking("world", c.x, W.controlRoom.y + 0.05, c.z + 1.4, -math.pi / 2)
        lookAt(c.x, c.y, c.z)
    end)
    S(0.5, function() end)
    S(0.2, function() log("console prompt:", I.currentText) I.press() end)
    S(3.0, function() log("game state", Game.state, "finished", G.missions.finished) end, "41_ending")
    S(0.2, function() Game.state = "play" end)
    S(0.2, function() G.game.godMode = false end)
    S(0.2, function() Game.state = "pause" end, "42_pause")
    S(0.2, function() Game.state = "settings" end, "43_settings")
    S(0.2, function() Game.state = "message" Game.message = { title = "TEST", body = "Body text" } end)
    S(0.2, function() Game.state = "dead" Game.deathCause = "cold" end, "44_dead")
    S(0.2, function() Game.state = "play" end)
    S(0.5, function() G.menu.open() G.menu.sub = "settings" end)
    S(0.3, function() G.menu.sub = "main" end)
    S(0.5, function() G.menu.open() end)
    S(2.5, nil, "45_main_menu")
    S(0.5, function() log("DONE", "frames", A.frames) love.event.quit() end)
    idx, stepT = 1, 0
    A.frames = 0
    local s = steps[1]
    if s.fn then s.fn() end
end

function A.update(dt)
    A.frames = A.frames + 1
    stepT = stepT + dt
    local s = steps[idx]
    if not s then return end
    if A.runNext then
        A.runNext = false
        local n = steps[idx]
        if n and n.fn then
            local ok, err = pcall(n.fn)
            if not ok then log("STEP ERROR", idx, err) end
        end
        return
    end
    if stepT >= s.dur then
        if s.shot then shotPending = s.shot end
        idx = idx + 1
        stepT = 0
        A.runNext = true
    end
end

function A.draw()
    if shotPending then
        local name = shotPending
        shotPending = nil
        love.graphics.captureScreenshot("autotest/" .. name .. ".png")
    end
end

return A
