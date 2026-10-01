-- Automated playtest: drives the game with simulated input and captures screenshots.
-- Run: love . --autotest   (screenshots land in the LÖVE save directory under autotest/)
local A = { keys = {}, mouse = {} }
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
    -- 8: locations
    local function visit(name, x, z, yaw, pitch, wait)
        S(0.2, function() teleport(x, z, yaw, pitch) end)
        S(wait or 2.0, nil, name)
    end
    visit("19_village", -150, 300, math.pi, 0.05)
    visit("20_village_church", -196, 285, -math.pi / 2, 0.2)
    visit("21_industrial", -250, -20, math.pi + 0.3, 0.1)
    visit("22_factory_inside", -320, -62, 0, 0.05)
    visit("23_checkpoint", 20, 130, -math.pi / 2, 0.0)
    visit("24_forest", 300, 200, 0.5, 0.05)
    visit("25_military_base", -180, -250, math.pi * 0.8, 0.05)
    visit("26_radio_tower", 250, -230, -0.3, 0.35)
    visit("27_nuclear_plant", 130, -400, -math.pi / 2, 0.15)
    visit("28_control_block_door", 160, -458, 0, 0.0)
    S(0.2, function()
        local b = W.bunkerInfo
        Pl.placeWalking("world", b.ox + 2.5 * 2.5, b.oy + 0.05, b.oz + 2.5 * 8.5, 0)
        Pl.flashlight = true
    end)
    S(2.0, function() end, "29_bunker_interior")
    S(0.1, function() log("underground", G.environment.underground, "cam", G.camera.x, G.camera.y, G.camera.z) end)
    S(0.2, function() Pl.flashlight = false teleport(W.bunker.x + 6, W.bunker.z + 6, -2.4, 0.05) end)
    S(1.5, nil, "30_bunker_entrance")
    -- 9: creatures
    S(0.2, function()
        teleport(-195, 300, 0, 0)
        local g = G.creatures.groups[1]
        log("creature groups", #G.creatures.groups, "list", #G.creatures.list)
    end)
    S(3.0, function() end)
    S(0.1, function()
        local c = G.creatures.list[1]
        if c then
            log("first creature", c.kind, c.state, c.x, c.z)
            local px, pz = Pl.x, Pl.z
            c.x, c.z = px + 7, pz
            c.y = W.height(c.x, c.z)
            lookAt(c.x, c.y + 0.6, c.z)
        end
    end)
    S(0.6, nil, "31_creature")
    S(2.0, function()
        local c = G.creatures.list[1]
        if c then lookAt(c.x, c.y + 0.6, c.z) end
    end)
    S(0.1, function()
        local c = G.creatures.list[1]
        if c then log("creature state after", c.state, "player hp", Pl.health) end
        G.weapons.mag.rifle = 5
        A.mouse[1] = true
    end, "32_creature_attack")
    S(0.1, function() A.mouse[1] = false end)
    S(1.3, function() A.mouse[1] = true end)
    S(0.1, function() A.mouse[1] = false local c = G.creatures.list[1] if c then log("creature hp", c.hp, c.state) end end)
    -- 10: enemy tank
    S(0.2, function()
        Pl.health = 100
        local e = G.enemies.tanks[1]
        log("enemy tank 1 at", e.x, e.z, e.state)
        teleport(e.x + 40, e.z + 25, 0, 0.05)
        lookAt(e.x, e.y + 1.5, e.z)
    end)
    S(2.0, nil, "33_enemy_tank")
    -- 11: UI screens
    S(0.3, function() Game.state = "map" G.missions.discovered.village = true end, "34_map")
    S(0.3, function() Game.state = "inventory" end, "35_inventory")
    S(0.3, function() Game.state = "play" G.environment.time = 23 teleport(T.x + 8, T.z + 3, 0) lookAt(T.x, T.y + 1, T.z) Pl.flashlight = true end)
    S(1.5, nil, "36_night_flashlight")
    S(0.3, function() Pl.flashlight = false G.environment.time = 14 G.weather.intensity = 1 G.weather.target = 1 end)
    S(1.5, nil, "37_blizzard")
    -- 12: save/load roundtrip
    S(0.2, function()
        G.weather.intensity = 0.3 G.weather.target = 0.3
        local ok, err = G.save.save()
        log("save", ok, err)
        T.fuel = 3
        local ok2 = Game.loadGame()
        log("load", ok2, "fuel restored", T.fuel)
    end)
    -- 13: gameplay flow checks ------------------------------------------------
    local I = require("src.interaction")
    local R = require("src.engine.renderer")
    for _, spot in ipairs({ { "village", -170, 300 }, { "industrial", -270, -30 }, { "forest", 300, 180 }, { "plant", 120, -420 }, { "base", -230, -330 } }) do
        S(0.2, function() teleport(spot[2], spot[3], 0, 0) end)
        S(0.5, function() log("perf", spot[1], "draws", R.stats.draws, "tris", math.floor(R.stats.tris)) end)
    end
    S(0.2, function() log("audio enabled", G.audio.enabled) end)
    -- headroom in the front compartment
    S(0.2, function() Pl.placeWalking("tank", 1.2, 0.62, 0.0, 0) T.speed = 0 press("w") end)
    S(1.2, function() end)
    S(0.1, function() press() log("front compartment: x", Pl.x, "height", Pl.height) end)
    -- exterior collision with the hull
    S(0.2, function()
        local x, y, z = T.frame:toWorld(0, 0, 5)
        teleport(x, z, T.yaw + math.pi / 2 + math.pi, 0)
        Pl.yaw = math.atan2(T.z - z, T.x - x)
        press("w")
    end)
    S(2.0, function() end)
    S(0.1, function()
        press()
        local lx, ly, lz = T.frame:toLocal(Pl.x, Pl.y, Pl.z)
        log("pushing into hull: local z", lz, "(should stay > 2.2)")
    end)
    -- climb in through the hatch from the turret roof
    S(0.2, function()
        T.hatchOpen = true T.hatchAnim = 1
        local x, y, z = T.turretWorld:toWorld(-0.2, 1.12, -0.5)
        Pl.placeWalking("world", x, y + 0.05, z, 0)
    end)
    S(0.5, function()
        local hx, hy, hz = T.turretWorld:toWorld(-0.95, 1.45, -0.75)
        lookAt(hx, hy, hz)
    end)
    S(0.3, function() log("hatch prompt:", I.currentText) I.press() press("s") end)
    S(3.5, function() end)
    S(0.2, function() press() log("after climbing in: frame", Pl.frameName, "mode", Pl.mode, "pos", Pl.x, Pl.y, Pl.z) end)
    -- creatures attack the tank while the player is inside
    S(0.2, function()
        Pl.placeWalking("tank", 0.5, 0.62, 0.5, 0)
        local hull = T.comp.hull
        A.hullBefore = T.comp.trackL + T.comp.trackR + T.comp.hull
        local g = G.creatures.groups[1]
        local C = G.creatures
        local c = { kind = "hound", def = C.KINDS.hound, x = T.x + 6, y = T.y, z = T.z + 6, yaw = 0, hp = 90, state = "chase", timer = 0,
                    homeX = T.x, homeZ = T.z, homeR = 10, group = g, phase = 0, speed = 0, attackT = 0, jaw = 0, hurtT = 0, alertT = 0,
                    deathT = 0, lastSeenT = 0, pain = 0 }
        table.insert(C.list, c)
        A.testHound = c
    end)
    S(6.0, function() end)
    S(0.1, function() log("hound vs tank: state", A.testHound.state, "tank damage taken", A.hullBefore - (T.comp.trackL + T.comp.trackR + T.comp.hull)) A.testHound.remove = true end)
    -- enemy tank engages the player's tank
    S(0.2, function()
        local e = G.enemies.tanks[1]
        e.x, e.z = T.x + 120, T.z
        e.y = W.height(e.x, e.z)
        e.state = "patrol"
        A.compBefore = T.comp.hull
        G.weapons.debug = true
        log("enemy placed 120m away", "tank at", T.x, T.y, T.z, "enemy y", e.y)
    end)
    S(25, function() end)
    S(0.1, function()
        local e = G.enemies.tanks[1]
        log("enemy state", e.state, "want", e.dbgWant, "diff", e.dbgDiff, "pitch", e.gunPitch, "aimT", e.aimT, "reload", e.reload, "player tank hull", T.comp.hull, "before", A.compBefore)
        G.weapons.debug = false
        G.enemies.hit(e, 200, e.x, e.y + 1, e.z, 1, 0, "AP")
        log("enemy alive after hit", e.alive)
    end)
    S(2.0, function() end)
    -- repair
    S(0.2, function()
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
    -- refuel
    S(0.2, function()
        G.inventory.player:add("fuel", 1)
        T.fuel = 30
        local x, y, z = T.frame:toWorld(-3.0, 2.4, 0)
        Pl.placeWalking("world", x, y + 0.1, z, T.yaw)
        local fx, fy, fz = T.frame:toWorld(-3.0, 2.45, 0)
    end)
    S(0.5, function()
        local x, y, z = T.frame:toWorld(-2.6, 2.4, 0.0)
        Pl.placeWalking("world", x, y + 0.05, z, T.yaw + math.pi)
        local fx, fy, fz = T.frame:toWorld(-3.0, 2.45, 0)
        lookAt(fx, fy, fz)
    end)
    S(0.4, function() log("refuel prompt:", I.currentText) I.press() press("e") end)
    S(3.0, function() end)
    S(0.1, function() press() log("fuel after refuel", T.fuel) end)
    -- doors, bunker transition, keycard, control room, ending
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
    S(0.5, function() end, "39_control_room")
    S(0.1, function()
        log("control entered stage", G.missions.stage, G.missions.current() and G.missions.current().id)
        local c = W.signalConsole
        lookAt(c.x, c.y, c.z)
    end)
    S(0.5, function() end)
    S(0.2, function()
        local c = W.signalConsole
        Pl.placeWalking("world", c.x, cr and cr.y or W.controlRoom.y + 0.05, c.z + 1.6, -math.pi / 2)
        lookAt(c.x, c.y, c.z)
    end)
    S(0.4, function() log("console prompt:", I.currentText) I.press() end)
    S(3.0, function() log("game state", Game.state, "finished", G.missions.finished) end, "40_ending")
    S(0.2, function() Game.state = "play" end)
    -- cold exposure
    S(0.2, function() teleport(0, 200, 0, 0) G.weather.intensity = 1 G.environment.time = 2 Pl.warmth = 100 A.w0 = Pl.warmth end)
    S(10, function() end)
    S(0.1, function() log("warmth after 10s in a night blizzard", Pl.warmth, "from", A.w0) G.weather.intensity = 0.3 G.environment.time = 15 end)
    S(0.2, function() Game.state = "pause" end, "41_pause")
    S(0.2, function() Game.state = "settings" end, "42_settings")
    S(0.2, function() Game.state = "message" Game.message = { title = "TEST", body = "Body text" } end)
    S(0.2, function() Game.state = "dead" Game.deathCause = "cold" end, "43_dead")
    S(0.2, function() Game.state = "play" end)
    S(0.5, function() G.menu.open() G.menu.sub = "settings" end)
    S(0.3, function() G.menu.sub = "main" end)
    S(0.5, function() G.menu.open() end)
    S(2.5, nil, "38_main_menu")
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
