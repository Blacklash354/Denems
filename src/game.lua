-- In-game state: wires every system together, registers interactables, renders the frame.
local U = require("src.utils")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")
local I = require("src.interaction")
local Inv = require("src.inventory")
local TM = require("src.tank_model")

local Game = { state = "play", playTime = 0, musicDuck = 1 }
local G
local lg = love.graphics

---------------------------------------------------------------------------
-- pickup / door models
---------------------------------------------------------------------------
local function buildPickupModels()
    local m = {}
    local mb = MB.new(501)
    mb:material("metal"):color(0.38, 0.45, 0.32)
    mb:box(-0.17, 0, -0.08, 0.17, 0.48, 0.08)
    mb:box(-0.1, 0.48, -0.03, 0.1, 0.53, 0.03)
    mb:material("metal"):color(0.6, 0.6, 0.55)
    mb:cylinder(0.12, 0.48, 0, 0.03, 0.56, 0.03, 5)
    m.jerrycan = mb:build()
    mb = MB.new(502)
    mb:material("crate"):color(0.8, 0.85, 0.7)
    mb:box(-0.5, 0, -0.22, 0.5, 0.3, 0.22)
    mb:material("brass"):color(1, 1, 1)
    mb:cylinderX(-0.4, 0.3, 0.38, -0.08, 0.06, 0.06, 6)
    mb:cylinderX(-0.4, 0.3, 0.38, 0.08, 0.06, 0.06, 6)
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:cylinderX(0.3, 0.42, 0.38, -0.08, 0.055, 0.015, 6)
    mb:cylinderX(0.3, 0.42, 0.38, 0.08, 0.055, 0.015, 6)
    m.shellcrate = mb:build()
    mb = MB.new(503)
    mb:material("metal"):color(0.4, 0.45, 0.35)
    mb:box(-0.15, 0, -0.06, 0.15, 0.18, 0.06)
    mb:material("metal"):color(0.25, 0.25, 0.25)
    mb:box(-0.04, 0.18, -0.01, 0.04, 0.22, 0.01)
    m.ammobox = mb:build()
    mb = MB.new(504)
    mb:material("metal"):color(0.35, 0.42, 0.3)
    mb:box(-0.2, 0, -0.1, 0.2, 0.25, 0.1)
    mb:box(-0.24, 0, 0.14, 0.16, 0.22, 0.32)
    mb:material("brass"):color(1, 1, 1)
    mb:box(-0.15, 0.25, -0.02, 0.15, 0.29, 0.02)
    m.mgbox = mb:build()
    mb = MB.new(505)
    mb:material("plaster"):color(0.95, 0.95, 0.9)
    mb:box(-0.15, 0, -0.1, 0.15, 0.14, 0.1)
    mb:material("cloth_red"):color(1, 1, 1)
    mb:box(-0.03, 0.14, -0.08, 0.03, 0.145, 0.08)
    mb:box(-0.08, 0.14, -0.03, 0.08, 0.145, 0.03)
    m.medkit = mb:build()
    mb = MB.new(506)
    mb:material("cloth_red"):color(0.8, 0.8, 0.8)
    mb:box(-0.22, 0, -0.1, 0.22, 0.18, 0.1)
    mb:material("metal"):color(0.4, 0.4, 0.4)
    mb:box(-0.1, 0.18, -0.02, 0.1, 0.25, 0.02)
    m.repairkit = mb:build()
    mb = MB.new(507)
    mb:material("crate"):color(0.7, 0.6, 0.45)
    mb:box(-0.18, 0, -0.14, 0.18, 0.2, 0.14)
    mb:material("metal"):color(0.6, 0.6, 0.55)
    mb:cylinder(0.25, 0, 0, 0.06, 0.1, 0.06, 6)
    m.foodbox = mb:build()
    mb = MB.new(508)
    mb:material("hazard"):color(1, 1, 1)
    mb:box(-0.06, 0.78, -0.04, 0.06, 0.785, 0.04)
    mb:material("metal"):color(0.4, 0.4, 0.4)
    mb:box(-0.3, 0, -0.3, 0.3, 0.78, 0.3)
    m.keycard = mb:build()
    mb = MB.new(509)
    mb:material("paper"):color(1, 1, 1)
    mb:box(-0.12, 0.78, -0.16, 0.12, 0.8, 0.16)
    m.documents = mb:build()
    return m
end

local doorModels = {}
local function doorModel(d)
    local key = string.format("%.2f_%.2f_%s", d.width, d.height, d.mat)
    if doorModels[key] then return doorModels[key] end
    local mb = MB.new(510)
    mb.texScale = 0.8
    mb:material(d.mat):color(d.mat == "metal" and 0.55 or 0.7, d.mat == "metal" and 0.6 or 0.6, d.mat == "metal" and 0.55 or 0.5)
    mb:box(0.02, 0, -0.05, d.width - 0.02, d.height, 0.05)
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:box(d.width - 0.2, d.height * 0.45, -0.1, d.width - 0.12, d.height * 0.5, 0.1)
    if d.heavy then
        mb:material("hazard"):color(1, 1, 1)
        mb:box(0.02, d.height * 0.1, -0.06, d.width - 0.02, d.height * 0.16, 0.06)
    end
    doorModels[key] = mb:build()
    return doorModels[key]
end

---------------------------------------------------------------------------
-- interactables
---------------------------------------------------------------------------
local function consumeRepairKit()
    local pinv, tinv = G.inventory.player, G.inventory.tank
    if pinv:count("repair_kit") > 0 then pinv:remove("repair_kit", 1) return true end
    if tinv:count("repair_kit") > 0 then tinv:remove("repair_kit", 1) return true end
    return false
end
local function hasRepairKit() return G.inventory.player:count("repair_kit") + G.inventory.tank:count("repair_kit") > 0 end

local function registerTank()
    local T, Pl, St = G.tank, G.player, G.stations
    local tankF, turF, gunF = T.getFrame, T.getTurretFrame, T.getGunFrame
    -- interior ------------------------------------------------------------
    I.add({ space = "interior", frame = turF, pos = { 0.6, -0.95, -0.62 }, radius = 0.45, prompt = "SIT AT CANNON",
            use = function() Pl.enterSeat(St.gunner) end })
    I.add({ space = "interior", frame = tankF, pos = { 2.25, 1.2, 0.75 }, radius = 0.4, prompt = "USE MG",
            use = function() Pl.enterSeat(St.mg) end })
    I.add({ space = "interior", frame = tankF, pos = { 2.25, 1.2, -0.75 }, radius = 0.4, prompt = "TAKE DRIVER SEAT",
            use = function() Pl.enterSeat(St.driver) end })
    I.add({ space = "interior", frame = tankF, pos = { 2.54, 1.62, -1.28 }, radius = 0.14,
            prompt = function() return T.engineOn and "STOP ENGINE" or "START ENGINE" end,
            use = function() if T.engineOn then T.stopEngine() else T.startEngine() end end })
    I.add({ space = "interior", frame = tankF, pos = { -1.45, 1.4, 0 }, radius = 0.9, prompt = "OPEN STORAGE",
            use = function() Game.openStorage() end })
    I.add({ space = "interior", frame = tankF, pos = { 2.3, 1.85, 1.45 }, radius = 0.35,
            prompt = function()
                if not T.radioOn then return "TURN RADIO ON" end
                return "TUNE RADIO (" .. (G.radio.active and G.radio.active.freq or "") .. ")"
            end, use = function() G.radio.tune() end })
    I.add({ space = "interior", frame = turF, pos = { TM.CUPOLA[1], -0.7, TM.CUPOLA[3] }, radius = 0.55, prompt = "CLIMB LADDER",
            enabled = function() return Pl.mode == "walk" end,
            use = function() Pl.startLadder("interior", 0.05) end })
    I.add({ space = "interior", frame = turF, pos = { TM.CUPOLA[1], 1.15, TM.CUPOLA[3] }, radius = 0.5, range = 2.0,
            enabled = function() return Pl.mode == "ladder" end,
            prompt = function() return T.hatchOpen and "CLOSE HATCH" or "OPEN HATCH" end,
            use = function() Game.toggleHatch() end })
    I.add({ space = "interior", frame = tankF, pos = { -1.6, 2.0, 1.12 }, radius = 0.2, prompt = "TOGGLE LIGHTS",
            use = function() T.lightsOn = not T.lightsOn G.audio.play("switch", { tank = true }) end })
    I.add({ space = "interior", frame = turF, pos = { 0.6, 0.45, 0.2 }, radius = 0.35,
            prompt = function()
                if T.loaded then return nil end
                if T.reloadT > 0 then return nil end
                return "LOAD " .. T.ammoSelect .. " SHELL"
            end, use = function() T.startReload() end })
    -- exterior -------------------------------------------------------------
    I.add({ space = "exterior", frame = tankF, pos = { -4.3, 1.1, -1.2 }, radius = 0.7, prompt = "CLIMB UP",
            enabled = function() return Pl.y < T.y + 1.5 end,
            use = function() Pl.startLadder("rear", 0.02) end })
    I.add({ space = "exterior", frame = tankF, pos = { -3.85, 2.5, -1.2 }, radius = 0.5, prompt = "CLIMB DOWN",
            enabled = function() return Pl.y > T.y + 1.5 end,
            use = function() Pl.startLadder("rear", 0.97) end })
    I.add({ space = "exterior", frame = turF, pos = { TM.CUPOLA[1], 1.45, TM.CUPOLA[3] }, radius = 0.6, range = 2.8,
            prompt = function() return T.hatchOpen and "ENTER TANK" or "OPEN HATCH" end,
            use = function()
                if T.hatchOpen then Pl.startLadder("interior", 0.98)
                else Game.toggleHatch() end
            end })
    I.add({ space = "exterior", frame = turF, pos = { -2.38, 0.45, 0 }, radius = 0.7, prompt = "OPEN STORAGE",
            use = function() Game.openStorage() end })
    I.add({ space = "exterior", frame = tankF, pos = { -3.0, 2.45, 0 }, radius = 0.5, range = 2.6, hold = 2.5,
            prompt = function()
                if T.fuel >= 98 then return nil end
                local cans = G.inventory.player:count("fuel") + G.inventory.tank:count("fuel")
                if cans == 0 then return "REFUEL TANK - NO FUEL CANS" end
                return string.format("REFUEL TANK (%d%%)", T.fuel)
            end,
            hold = function()
                local cans = G.inventory.player:count("fuel") + G.inventory.tank:count("fuel")
                return cans > 0 and 2.5 or nil
            end,
            onHoldStart = function() G.audio.play("refuel", { x = T.x, y = T.y + 2, z = T.z }) end,
            use = function()
                local inv = G.inventory.player:count("fuel") > 0 and G.inventory.player or G.inventory.tank
                if inv:count("fuel") == 0 then G.ui.notify("FIND FUEL CANS") return end
                inv:remove("fuel", 1)
                T.fuel = math.min(100, T.fuel + 18)
                G.ui.notify(string.format("TANK REFUELLED: %d%%", T.fuel))
            end })
    local repairs = {
        { comp = "trackL", frame = tankF, pos = { 0, 0.9, -2.15 }, label = "REPAIR LEFT TRACK", kneel = true },
        { comp = "trackR", frame = tankF, pos = { 0, 0.9, 2.15 }, label = "REPAIR RIGHT TRACK", kneel = true },
        { comp = "engine", frame = tankF, pos = { -2.8, 2.45, 0.95 }, label = "REPAIR ENGINE" },
        { comp = "hull", frame = tankF, pos = { 1.6, 1.9, -1.95 }, label = "REPAIR HULL" },
        { comp = "hull", frame = tankF, pos = { 1.6, 1.9, 1.95 }, label = "REPAIR HULL" },
        { comp = "turret", frame = turF, pos = { 0, 0.6, -1.62 }, label = "REPAIR TURRET" },
        { comp = "cannon", frame = gunF, pos = { 1.2, 0, 0 }, label = "REPAIR CANNON" },
    }
    for _, r in ipairs(repairs) do
        I.add({ space = "exterior", frame = r.frame, pos = r.pos, radius = 0.85, range = 2.9, kneel = r.kneel,
                prompt = function()
                    local v = T.comp[r.comp]
                    if v >= 99.5 then return nil end
                    if not hasRepairKit() then return string.format("%s (%d%%) - NEED REPAIR KIT", r.label, v) end
                    return string.format("%s (%d%%)", r.label, v)
                end,
                hold = function() return hasRepairKit() and 3.5 or nil end,
                onHoldStart = function() G.audio.play("repair", {}) end,
                whileHolding = function(self, dt)
                    self.sndT = (self.sndT or 0) - dt
                    if self.sndT <= 0 then self.sndT = 1.0 G.audio.play("repair", {}) end
                end,
                use = function()
                    if not consumeRepairKit() then G.ui.notify("YOU NEED A REPAIR KIT") return end
                    T.repair(r.comp, 55)
                    if r.comp == "hull" then T.repair("hull", 0) end
                    G.ui.notify(string.format("%s REPAIRED: %d%%", T.COMP_NAMES[r.comp], T.comp[r.comp]))
                    G.missions.event("repaired")
                end })
    end
end

local function itemPrompt(p)
    local def = Inv.ITEMS[p.item]
    if p.item == "ap_shell" or p.item == "he_shell" or p.item == "mg_ammo" or p.item == "rifle_ammo" then
        return "TAKE AMMO (" .. def.name .. (p.count > 1 and (" x" .. p.count) or "") .. ")"
    end
    return "PICK UP " .. def.name .. (p.count > 1 and (" x" .. p.count) or "")
end

local function registerWorld()
    local W = G.world
    for _, c in ipairs(W.containers) do
        c.initialLoot = U.copy(c.loot)
        c.village = U.dist2(c.x, c.z, W.village.x, W.village.z) < W.village.r
        I.add({ space = "exterior", pos = { c.x, c.y + 0.6, c.z }, radius = 0.6, range = 2.4, hold = 1.1,
                enabled = function() return not c.searched end,
                prompt = function() return "SEARCH " .. c.label end,
                onHoldStart = function() G.audio.play("pickup", { x = c.x, y = c.y, z = c.z }) end,
                use = function() Game.searchContainer(c) end })
    end
    for _, p in ipairs(W.pickups) do
        p.initialCount = p.count
        I.add({ space = "exterior", pos = { p.x, p.y + 0.3, p.z }, radius = 0.45, range = 2.4,
                enabled = function() return not p.taken end,
                prompt = function() return itemPrompt(p) end,
                use = function() Game.takePickup(p) end })
    end
    for _, d in ipairs(W.doors) do
        d.angle = 0
        local cx, cz = d.x + math.cos(d.yaw) * d.width / 2, d.z + math.sin(d.yaw) * d.width / 2
        d.box.door = true
        I.add({ space = "exterior", pos = { cx, d.y + 1.1, cz }, radius = math.max(0.7, d.width / 2), range = 2.6,
                hold = function() return d.transition and 0.6 or nil end,
                prompt = function()
                    if d.transition then return d.transition.inside and "ENTER BUNKER" or "EXIT BUNKER" end
                    if d.locked and not d.unlocked then
                        if G.inventory.player:count("keycard") > 0 then return "UNLOCK DOOR (KEYCARD)" end
                        return "LOCKED - KEYCARD REQUIRED"
                    end
                    return d.open and "CLOSE DOOR" or "OPEN DOOR"
                end,
                use = function() Game.useDoor(d) end })
    end
    if W.transmitter then
        local t = W.transmitter
        I.add({ space = "exterior", pos = { t.x, t.y, t.z }, radius = 0.7, range = 2.4, prompt = "USE TRANSMITTER",
                use = function()
                    Game.showMessage("TRANSMITTER LOG - TOWER SEVEN",
                        "The transmitter is still warm. A looping message is queued on the reel:\n\n" ..
                        "'...Object 12 has gone silent. The bunker beneath the hill south-west of the military base holds the reactor access cards. " ..
                        "Whoever finds this: the signal is coming from the plant control block. Someone is still alive in there.'\n\n" ..
                        "You copy the coordinates onto your map.")
                    G.missions.event("transmitter_used")
                end })
    end
    if W.bunkerRadio then
        local t = W.bunkerRadio
        I.add({ space = "exterior", pos = { t.x, t.y, t.z }, radius = 0.6, range = 2.4, prompt = "PLAY RADIO LOG",
                use = function()
                    Game.showMessage("OBJECT 12 - COMMAND LOG",
                        "'Day 41. The reactor crew sealed themselves in the control block. They broadcast on 57 MHz every night. " ..
                        "We kept the spare access card here in the command room. The garrison is gone - the crawlers came up through the generator shaft.'\n\n" ..
                        "The last entry is only static.")
                    G.missions.reveal("plant")
                end })
    end
    if W.signalConsole then
        local t = W.signalConsole
        I.add({ space = "exterior", pos = { t.x, t.y, t.z }, radius = 0.8, range = 2.6, prompt = "ACTIVATE SIGNAL CONSOLE",
                enabled = function() return G.missions.stage >= 8 end,
                use = function() Game.ending() end })
    end
    for i in ipairs(G.humans.list) do
        local function hu() return G.humans.list[i] end
        local function headPos() local h = hu() return { h.x, h.y + (h.state == "sit" and 1.0 or 1.45), h.z } end
        I.add({ space = "exterior", pos = { 0, 0, 0 }, radius = 0.6, range = 2.8,
                frame = function()
                    local h = hu()
                    local f = Game.npcFrame or require("src.engine.math3d").frame()
                    Game.npcFrame = f
                    f:setYaw(0)
                    f.px, f.py, f.pz = h.x, h.y + (h.state == "sit" and 1.0 or 1.4), h.z
                    return f
                end,
                prompt = function()
                    local h = hu()
                    if h.state == "dead" then return not h.looted and "SEARCH BODY" or nil end
                    if h.hostile then return nil end
                    if h.key == "petro" then return "TRADE WITH " .. h.name end
                    return "TALK TO " .. h.name
                end,
                hold = function() local h = hu() return h.state == "dead" and 1.0 or nil end,
                use = function()
                    local h = hu()
                    if h.state == "dead" then
                        h.looted = true
                        local got = {}
                        for _, e in ipairs(h.loot) do
                            local n = G.inventory.player:add(e[1], e[2])
                            if n > 0 then got[#got + 1] = Inv.ITEMS[e[1]].name .. " x" .. n end
                        end
                        G.ui.notify(#got > 0 and ("FOUND: " .. table.concat(got, ", ")) or "NOTHING USEFUL")
                        G.audio.play("pickup", {})
                        return
                    end
                    Game.talk(h)
                end })
    end
    for i in ipairs(G.enemies.tanks) do
        -- look the tank up by index: enemy tank tables are recreated on new game / load
        local function tank() return G.enemies.tanks[i] end
        I.add({ space = "exterior", frame = function() return tank() and tank().frame end, pos = { 0, 1.8, 1.7 }, radius = 1.2, range = 3.2, hold = 1.5,
                enabled = function() local t = tank() return t and not t.alive and not t.looted end,
                prompt = "SEARCH WRECK",
                use = function()
                    local t = tank()
                    t.looted = true
                    local got = {}
                    for _, e in ipairs({ { "ap_shell", 3 }, { "mg_ammo", 120 }, { "repair_kit", 1 } }) do
                        local n = G.inventory.player:add(e[1], e[2])
                        if n > 0 then got[#got + 1] = Inv.ITEMS[e[1]].name .. " x" .. n G.missions.event("picked", e[1]) end
                    end
                    G.ui.notify(#got > 0 and ("FOUND: " .. table.concat(got, ", ")) or "NOTHING YOU CAN CARRY")
                end })
    end
end

---------------------------------------------------------------------------
-- actions
---------------------------------------------------------------------------
function Game.toggleHatch()
    local T = G.tank
    T.hatchOpen = not T.hatchOpen
    G.audio.play("hatch", { tank = true })
    if T.hatchOpen then G.audio.play("wind_gust", { volume = 0.6 }) end
end

function Game.openStorage()
    Game.state = "storage"
    love.mouse.setRelativeMode(false)
    G.missions.event("storage_opened")
    G.audio.play("door", { tank = true, volume = 0.5 })
end

function Game.searchContainer(c)
    local got, left = {}, {}
    for _, e in ipairs(c.loot) do
        local n = G.inventory.player:add(e[1], e[2])
        if n > 0 then
            got[#got + 1] = Inv.ITEMS[e[1]].name .. (n > 1 and (" x" .. n) or "")
            G.missions.event("picked", e[1])
        end
        if e[2] - n > 0 then left[#left + 1] = { e[1], e[2] - n } end
    end
    c.loot = left
    c.dirty = true
    if #left == 0 then c.searched = true end
    if #got > 0 then G.ui.notify("FOUND: " .. table.concat(got, ", ")) else G.ui.notify("NOTHING YOU CAN CARRY") end
    if #left > 0 then G.ui.notify("NO ROOM - SOME ITEMS LEFT BEHIND") end
    if c.village and not c.countedVillage then
        c.countedVillage = true
        G.missions.event("searched", { village = true })
    end
    G.audio.play("pickup", {})
end

function Game.takePickup(p)
    local n = G.inventory.player:add(p.item, p.count)
    if n <= 0 then G.ui.notify("CAN'T CARRY MORE " .. Inv.ITEMS[p.item].name) return end
    p.count = p.count - n
    if p.count <= 0 then p.taken = true end
    G.ui.notify("+" .. n .. " " .. Inv.ITEMS[p.item].name)
    G.audio.play("pickup", {})
    G.missions.event("picked", p.item)
end

function Game.useDoor(d)
    if d.transition then
        local tr = d.transition
        Game.fade(function()
            local Pl = G.player
            Pl.placeWalking("world", tr.x, tr.y + 0.05, tr.z, tr.yaw)
            Pl.platform = nil
            G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
            if tr.inside then G.missions.event("entered_bunker") G.ui.areaTitle("OBJECT 12") end
        end)
        G.audio.play("door_metal", {})
        return
    end
    if d.locked and not d.unlocked then
        if G.inventory.player:count("keycard") > 0 then
            d.unlocked = true
            G.ui.notify("KEYCARD ACCEPTED")
            G.audio.play("switch", {})
        else
            G.ui.notify("THE DOOR IS LOCKED. A KEYCARD READER BLINKS RED.")
            G.audio.play("click", {})
            return
        end
    end
    d.open = not d.open
    d.box.enabled = not d.open
    G.audio.play(d.heavy and "door_metal" or "door", { x = d.x, y = d.y + 1, z = d.z })
end

function Game.fade(cb)
    Game.fading = { t = 0, cb = cb, done = false }
end

function Game.showMessage(title, body)
    Game.message = { title = title, body = body }
    Game.state = "message"
    love.mouse.setRelativeMode(false)
    G.audio.play("notify", {})
end

function Game.talk(h)
    local H = G.humans
    local lines = (h.key and H.LINES[h.key]) or { "Good hunting, stalker. Stay warm.", "The Zone gives, the Zone takes." }
    h.talkIdx = ((h.talkIdx or 0) % #lines) + 1
    local body = lines[h.talkIdx]
    if not h.talked and h.key and H.GIFTS[h.key] then
        local got = {}
        for _, e in ipairs(H.GIFTS[h.key]) do
            local n = G.inventory.player:add(e[1], e[2])
            if n > 0 then got[#got + 1] = Inv.ITEMS[e[1]].name .. " x" .. n end
        end
        if #got > 0 then body = body .. "\n\nHere, take this: " .. table.concat(got, ", ") .. "." end
    end
    h.talked = true
    G.missions.event("talked", h.key)
    if h.key == "petro" then
        Game.trader = h
        Game.state = "trade"
        Game.tradeLine = body
        love.mouse.setRelativeMode(false)
        G.audio.play("voice", { volume = 0.5 })
        return
    end
    Game.showMessage(h.name, body)
    G.audio.play("voice", { volume = 0.5 })
end

function Game.drawTrade()
    local UI = G.ui
    local inv = G.inventory.player
    local H = G.humans
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    local x, y, w, h = 80, 30, 480, 300
    UI.panel(x, y, w, h)
    UI.text("OLD PETRO - TRADER", x + 10, y + 8, UI.COL.amber, UI.fontM)
    UI.text(Game.tradeLine or "", x + 10, y + 26, UI.COL.text, UI.fontS, "left", w - 20)
    local function list(items)
        local t = {}
        for _, e in ipairs(items) do t[#t + 1] = e[2] .. " " .. Inv.ITEMS[e[1]].name end
        return table.concat(t, " + ")
    end
    for i, tr in ipairs(H.TRADES) do
        local ry = y + 58 + (i - 1) * 26
        local ok = true
        for _, e in ipairs(tr.give) do if inv:count(e[1]) < e[2] then ok = false end end
        UI.text("GIVE " .. list(tr.give), x + 12, ry + 2, ok and UI.COL.text or UI.COL.dim, UI.fontS)
        UI.text("GET  " .. list(tr.get), x + 12, ry + 11, ok and UI.COL.good or UI.COL.dim, UI.fontS)
        if UI.button("TRADE", x + w - 90, ry + 2, 76, 18, ok) then
            for _, e in ipairs(tr.give) do inv:remove(e[1], e[2]) end
            for _, e in ipairs(tr.get) do
                local n = inv:add(e[1], e[2])
                if n < e[2] then G.inventory.tank:add(e[1], e[2] - n) G.ui.notify("NO ROOM - SENT TO TANK STORAGE ON RETURN") end
            end
            G.ui.notify("TRADED FOR " .. list(tr.get))
            G.audio.play("pickup", {})
        end
    end
    UI.text("[E/ESC] LEAVE", x + 10, y + h - 14, UI.COL.dim, UI.fontS)
end

function Game.ending()
    G.missions.event("signal_found")
    Game.state = "ending"
    Game.endT = 0
    love.mouse.setRelativeMode(false)
    G.audio.play("sting", {})
end

function Game.playerDied(cause)
    Game.deathCause = cause
    Game.deadT = 0
end

function Game.tankDestroyed()
    local Pl = G.player
    if Pl.frameName == "tank" then Pl.die("tank") else
        G.ui.warning("YOUR TANK HAS BEEN DESTROYED")
        Game.deathCause = "tank_lost"
        Game.deadT = -4
        Game.tankLost = true
    end
end

function Game.autosave()
    if Game.state ~= "play" and Game.state ~= "message" then return end
    if G.player.mode == "dead" then return end
    local ok = G.save.save()
    if ok then G.ui.notify("GAME SAVED") end
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------
function Game.init(game)
    G = game
    Game.pickupModels = buildPickupModels()
    Game.mats = {}
    registerTank()
    registerWorld()
end

function Game.newGame()
    local W = G.world
    G.tank.reset()
    G.player.reset()
    G.inventory.reset()
    G.weapons.reset()
    G.missions.reset()
    G.environment.time = 15.5
    G.weather.load({ intensity = 0.3, target = 0.3, phaseT = 120 })
    G.creatures.load(nil)
    G.enemies.reset()
    G.humans.reset()
    G.effects.clear()
    for _, c in ipairs(W.containers) do c.loot = U.copy(c.initialLoot) c.searched = false c.dirty = false c.countedVillage = false end
    for _, p in ipairs(W.pickups) do p.taken = false p.count = p.initialCount end
    for _, d in ipairs(W.doors) do d.open = false d.unlocked = false d.angle = 0 d.box.enabled = true end
    Game.playTime = 0
    Game.start()
    G.ui.objective("MAIN OBJECTIVE", G.missions.current().text)
    Game.helpT = 18
end

function Game.loadGame()
    local data = G.save.read()
    if not data then return false end
    G.effects.clear()
    G.save.apply(data)
    Game.start()
    G.ui.notify("GAME LOADED")
    return true
end

function Game.start()
    Game.state = "play"
    Game.deadT = nil
    Game.tankLost = false
    Game.fading = nil
    Game.message = nil
    Game.inControl = false
    love.mouse.setRelativeMode(true)
    G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
    G.renderer.fx.optic = 0
end

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------
local function updateEmitters(dt)
    local W = G.world
    local cam = G.camera
    for _, e in ipairs(W.emitters) do
        local d = U.dist2(cam.x, cam.z, e.x, e.z)
        if d < 300 then
            e.acc = e.acc + dt * (e.kind == "fire" and 14 or 3)
            while e.acc > 1 do
                e.acc = e.acc - 1
                if e.kind == "fire" then G.effects.fire(e.x, e.y, e.z, 0.7)
                elseif e.kind == "chimney" then G.effects.smoke(e.x, e.y, e.z, 3, 0.18, 0.18, 0.2, 14)
                elseif e.kind == "steam" then G.effects.smoke(e.x + (math.random() - 0.5) * 20, e.y, e.z + (math.random() - 0.5) * 20, 8, 0.7, 0.72, 0.75, 12)
                end
            end
        end
    end
end

local function updateDoors(dt)
    for _, d in ipairs(G.world.doors) do
        d.angle = U.approach(d.angle, d.open and 1 or 0, dt * (d.heavy and 0.8 or 2))
    end
end

function Game.collectLights()
    local list = {}
    G.tank.addLights(list)
    G.effects.addLights(list)
    G.enemies.addLights(list)
    local cam = G.camera
    local t = love.timer.getTime()
    -- soft fill light so the weapon in your hands is readable against the bright sky
    if G.player.mode == "walk" and G.player.frameName == "world" then
        list[#list + 1] = { cam.x + cam.ux * 0.35 + cam.fx * 0.15, cam.y + cam.uy * 0.35 + cam.fy * 0.15, cam.z + cam.uz * 0.35 + cam.fz * 0.15,
                            1.3, 0.8, 0.8, 0.85, 0.9 }
    end
    for _, l in ipairs(G.world.staticLights) do
        local d = U.dist3(cam.x, cam.y, cam.z, l.x, l.y, l.z)
        if d < 140 + l.radius then
            local k = 1
            if l.flicker == "blink" then k = (t % 1.6 < 0.5) and 1 or 0.05
            elseif l.flicker then k = 0.8 + U.noise2(t * 8, l.x, 2) * 0.4 end
            list[#list + 1] = { l.x, l.y, l.z, l.radius, l.r, l.g, l.b, l.intensity * k }
        end
    end
    return list
end

function Game.update(dt)
    local Pl = G.player
    if Game.fading then
        local f = Game.fading
        f.t = f.t + dt
        if f.t >= 0.6 and not f.done then f.done = true f.cb() end
        if f.t >= 1.3 then Game.fading = nil end
    end
    local paused = Game.state ~= "play"
    if not paused or Game.state == "dead" then
        Game.playTime = Game.playTime + dt
        G.weather.update(dt)
        G.environment.update(dt)
        G.tank.update(dt)
        Pl.update(dt)
        G.weapons.update(dt)
        G.creatures.update(dt)
        G.enemies.update(dt)
        G.humans.update(dt)
        G.radar.update(dt)
        G.ambience.update(dt)
        G.survival.update(dt)
        G.missions.update(dt)
        G.radio.update(dt)
        updateEmitters(dt)
        updateDoors(dt)
        G.effects.update(dt)
    end
    G.camera.update(dt)
    G.ui.update(dt)
    if Game.helpT then Game.helpT = Game.helpT - dt if Game.helpT <= 0 then Game.helpT = nil end end
    -- entering the control block
    local cr = G.world.controlRoom
    if cr and not Game.inControl and Pl.frameName == "world" and Pl.x > cr.x0 + 1 and Pl.x < cr.x1 and Pl.z > cr.z0 and Pl.z < cr.z1 and math.abs(Pl.y - cr.y) < 3 then
        Game.inControl = true
        G.missions.event("control_entered")
    end
    -- death handling
    if Pl.mode == "dead" or Game.tankLost then
        Game.deadT = (Game.deadT or 0) + dt
        if Game.deadT > 2.5 and Game.state ~= "dead" then
            Game.state = "dead"
            love.mouse.setRelativeMode(false)
        end
    end
    -- post-process feedback
    local fx = G.renderer.fx
    fx.frost = U.clamp((60 - Pl.warmth) / 60, 0, 1) * (Pl.frameName == "tank" and 0.5 or 1)
    fx.radiation = U.clamp(G.survival.radLevel / 2, 0, 1)
    local hurt = Pl.hurtFlash
    fx.tint = { 0.6, 0.05, 0.03, hurt * 0.45 }
    if Pl.health < 25 and Pl.mode ~= "dead" then fx.tint = { 0.5, 0.0, 0.0, math.max(hurt * 0.45, (25 - Pl.health) / 25 * 0.25 * (0.6 + 0.4 * math.sin(love.timer.getTime() * 5))) } end
    if Pl.mode == "dead" then fx.tint = { 0.15, 0.0, 0.0, math.min(0.7, (Game.deadT or 0) * 0.3) } end
    if Game.fading then
        local f = Game.fading.t
        local a = f < 0.6 and f / 0.6 or math.max(0, 1 - (f - 0.6) / 0.7)
        fx.tint = { 0, 0, 0, a }
    end
    fx.blur = U.clamp(G.camera.shakeAmt * 0.5, 0, 0.6)
    fx.brightness = 1
    if Pl.mode == "seat" and Pl.station and Pl.station.name == "gunner" and G.stations.gunner.optic then
        fx.brightness = 1.15
    end
    Game.musicDuck = (G.creatures.nearestThreat(Pl.x, Pl.z, 40) and 0.3 or 1)
end

---------------------------------------------------------------------------
-- draw
---------------------------------------------------------------------------
local pickupMat = {}
local doorMat = {}
function Game.drawWorld()
    local W = G.world
    local cam = G.camera
    local under = G.environment.underground
    R.setLights(Game.collectLights())
    R.beginFrame()
    W.draw(under)
    G.effects.drawDecals()
    -- doors
    for i, d in ipairs(W.doors) do
        if R.visible(d.x, d.y + 1, d.z, 3) then
            local m = M3.trsYaw(d.x, d.y, d.z, d.yaw - d.angle * 1.65, 1, doorMat[i] or {})
            doorMat[i] = m
            R.drawModel(doorModel(d), m, { interior = (d.interior or W.isUnderground(d.x, d.y + 1, d.z)) and 1 or 0 })
        end
    end
    -- pickups
    for i, p in ipairs(W.pickups) do
        if not p.taken and R.visible(p.x, p.y, p.z, 1) and U.dist3(cam.x, cam.y, cam.z, p.x, p.y, p.z) < 90 then
            local m = M3.trsYaw(p.x, p.y, p.z, p.yaw, 1, pickupMat[i] or {})
            pickupMat[i] = m
            local hl = I.current and I.current.pos and I.current.pos[1] == p.x and I.current.pos[3] == p.z
            local model = Game.pickupModels[p.model] or Game.pickupModels.ammobox
            R.drawModel(model, m, { interior = W.isUnderground(p.x, p.y + 0.5, p.z) and 1 or 0, tint = hl and { 1.5, 1.4, 1.2, 1 } or nil })
        end
    end
    -- blob shadows
    local shadows = {}
    local T = G.tank
    if not under then
        shadows[#shadows + 1] = { x = T.x, z = T.z, yaw = T.yaw, l = 5.2, w = 3.0, a = 0.75 }
        for _, e in ipairs(G.enemies.tanks) do
            if U.dist2(cam.x, cam.z, e.x, e.z) < 150 then shadows[#shadows + 1] = { x = e.x, z = e.z, yaw = e.yaw, l = 4.3, w = 2.5, a = 0.75 } end
        end
    end
    for _, c in ipairs(G.creatures.list) do
        if c.state ~= "buried" and c.state ~= "dead" and U.dist2(cam.x, cam.z, c.x, c.z) < 80 then
            local r = c.def.radius * 1.6
            shadows[#shadows + 1] = { x = c.x, z = c.z, y = c.underground and c.y or nil, yaw = c.yaw, l = r * 1.4, w = r, a = 0.6 }
        end
    end
    for _, h in ipairs(G.humans.list) do
        if U.dist2(cam.x, cam.z, h.x, h.z) < 70 then
            local dead = h.state == "dead"
            shadows[#shadows + 1] = { x = h.x, z = h.z, yaw = h.yaw, l = dead and 1.0 or 0.45, w = 0.4, a = 0.55 }
        end
    end
    G.effects.drawShadows(shadows)
    G.tank.draw(cam)
    G.enemies.draw()
    G.creatures.draw()
    G.humans.draw()
    if not G.environment.underground then G.ambience.draw() end
    G.effects.drawCasings()
    G.effects.drawParticles()
    G.weather.draw()
    if G.player.mode ~= "dead" and not Game.menuMode then G.weapons.drawViewmodel() end
end

function Game.draw()
    local sw, sh = lg.getDimensions()
    G.player.updateCamera(G.camera)
    if U.dist3(G.camera.x, G.camera.y, G.camera.z, G.tank.x, G.tank.y, G.tank.z) < 25 then G.radar.render() end
    R.setCamera(G.camera)
    Game.drawWorld()
    R.endFrame(sw, sh)
    local UI = G.ui
    UI.beginDraw()
    if Game.state == "play" or Game.state == "dead" then UI.drawHUD() end
    if Game.state == "play" and Game.helpT and G.player.mode == "walk" then Game.drawHelp(math.min(1, Game.helpT)) end
    if Game.state == "inventory" then UI.drawInventory()
    elseif Game.state == "storage" then UI.drawStorage()
    elseif Game.state == "map" then G.map.draw(UI)
    elseif Game.state == "message" then Game.drawMessage()
    elseif Game.state == "trade" then Game.drawTrade()
    elseif Game.state == "pause" then G.menu.drawPause()
    elseif Game.state == "settings" then G.menu.drawSettings(function() Game.state = "pause" end)
    elseif Game.state == "dead" then Game.drawDead()
    elseif Game.state == "ending" then Game.drawEnding()
    end
    UI.endDraw()
end

function Game.drawHelp(a)
    local UI = G.ui
    local lines = {
        "WASD MOVE   SHIFT SPRINT   C CROUCH   SPACE JUMP   E INTERACT / LEAVE SEAT",
        "F FLASHLIGHT   LMB FIRE   RMB AIM   R RELOAD   1/2/3 OR WHEEL WEAPONS   TAB INVENTORY   M MAP",
        "J OBJECTIVES   F5 QUICKSAVE   F9 QUICKLOAD   ESC PAUSE",
    }
    for i, l in ipairs(lines) do UI.text(l, 0, 250 + i * 10, { 0.85, 0.85, 0.8, a * 0.9 }, UI.fontS, "center", UI.VW) end
end

function Game.drawMessage()
    local UI = G.ui
    local m = Game.message
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    UI.panel(110, 70, 420, 200)
    UI.text(m.title, 120, 80, UI.COL.amber, UI.fontM)
    UI.text(m.body, 120, 102, UI.COL.text, UI.fontS, "left", 400)
    if UI.button("CONTINUE", 270, 244, 100, 18) then
        Game.state = "play"
        love.mouse.setRelativeMode(true)
    end
end

function Game.drawDead()
    local UI = G.ui
    local causes = { cold = "YOU FROZE TO DEATH", radiation = "RADIATION SICKNESS TOOK YOU", fall = "YOU FELL",
                     tank = "YOUR TANK WAS DESTROYED WITH YOU INSIDE", tank_lost = "WITHOUT THE TANK, THE WINTER TAKES YOU",
                     hound = "TORN APART BY FROST HOUNDS", crawler = "THE CRAWLERS GOT YOU", burrower = "DRAGGED BENEATH THE SNOW",
                     mutant = "CRUSHED BY THE MUTANT", explosion = "KILLED BY AN EXPLOSION", shot = "SHOT DEAD",
                     anomaly = "THE ANOMALY TORE YOU APART" }
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    UI.text("YOU ARE DEAD", 0, 110, UI.COL.warn, UI.fontXL, "center", UI.VW)
    UI.text(causes[Game.deathCause] or "", 0, 160, UI.COL.text, UI.font, "center", UI.VW)
    if UI.button("LOAD LAST SAVE", 230, 200, 180, 20, G.save.exists()) then
        Game.loadGame()
    end
    if UI.button("MAIN MENU", 230, 226, 180, 20) then G.menu.open() end
end

function Game.drawEnding()
    local UI = G.ui
    Game.endT = (Game.endT or 0) + love.timer.getDelta()
    local a = math.min(1, Game.endT / 3)
    lg.setColor(0, 0, 0, 0.85 * a)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    UI.text("THE SIGNAL", 0, 50, { 0.95, 0.72, 0.3, a }, UI.fontL, "center", UI.VW)
    local body = "The console hums. Behind the reinforced glass of the reactor hall, a dozen frost-bitten faces turn toward you. " ..
        "They kept the transmitter alive for forty days, hoping someone - anyone - would answer.\n\n" ..
        "Somebody did. Out there the tank waits in the snow, engine ticking as it cools. There is fuel enough for one more journey south, " ..
        "and room inside the steel for everyone who can still walk.\n\n" ..
        "END OF THE VERTICAL SLICE.  Thank you for playing STEEL HEARTH."
    UI.text(body, 120, 90, { 0.88, 0.88, 0.84, a }, UI.fontS, "left", 400)
    UI.text(string.format("TIME PLAYED %s", U.formatTime(Game.playTime)), 0, 230, { 0.6, 0.6, 0.6, a }, UI.fontS, "center", UI.VW)
    if Game.endT > 2 then
        if UI.button("CONTINUE EXPLORING", 220, 250, 200, 20) then Game.state = "play" love.mouse.setRelativeMode(true) end
        if UI.button("MAIN MENU", 220, 276, 200, 20) then G.menu.open() end
    end
end

---------------------------------------------------------------------------
-- input
---------------------------------------------------------------------------
function Game.keypressed(key)
    local Pl = G.player
    if Game.state == "play" then
        if Pl.mode == "dead" then return end
        if key == "escape" then
            Game.state = "pause"
            love.mouse.setRelativeMode(false)
            return
        end
        if key == "f5" then G.save.save() G.ui.notify("QUICKSAVED") return end
        if key == "f9" then if not Game.loadGame() then G.ui.notify("NO SAVE FOUND") end return end
        if key == "tab" or key == "i" then Game.state = "inventory" love.mouse.setRelativeMode(false) return end
        if key == "m" then Game.state = "map" love.mouse.setRelativeMode(false) return end
        if key == "h" then Game.helpT = 10 return end
        if Pl.mode == "seat" then
            if key == "e" then Pl.leaveSeat() return end
            if Pl.station.keypressed then Pl.station.keypressed(key) end
            return
        end
        if key == "e" then
            if not I.press() and Pl.mode == "ladder" then
                local L = Pl.LADDERS.interior
                if Pl.ladderName == "interior" and Pl.ladderT >= L.blockT - 0.05 then
                    Game.toggleHatch()          -- reach up and work the hatch
                elseif Pl.ladderT < 0.5 then
                    Pl.ladderT = -0.01          -- step off at the bottom
                end
            end
            return
        end
        if key == "f" then
            if Pl.battery > 0 then
                Pl.flashlight = not Pl.flashlight
                G.audio.play("switch", { volume = 0.5 })
            else G.ui.notify("FLASHLIGHT BATTERY DEAD") end
            return
        end
        if key == "r" then G.weapons.reload() return end
        if key == "1" then G.weapons.switch("rifle") return end
        if key == "2" then G.weapons.switch("smg") return end
        if key == "3" then G.weapons.switch("pistol") return end
    elseif Game.state == "inventory" then
        if key == "tab" or key == "i" or key == "escape" then Game.state = "play" love.mouse.setRelativeMode(true) end
        if key == "m" then Game.state = "map" end
    elseif Game.state == "storage" then
        if key == "e" or key == "escape" or key == "tab" then Game.state = "play" love.mouse.setRelativeMode(true) end
    elseif Game.state == "map" then
        if key == "m" or key == "escape" or key == "tab" then Game.state = "play" love.mouse.setRelativeMode(true) end
    elseif Game.state == "trade" then
        if key == "e" or key == "escape" or key == "tab" then Game.state = "play" love.mouse.setRelativeMode(true) end
    elseif Game.state == "message" then
        if key == "escape" or key == "e" or key == "return" then Game.state = "play" love.mouse.setRelativeMode(true) end
    elseif Game.state == "pause" then
        if key == "escape" then Game.state = "play" love.mouse.setRelativeMode(true) end
    elseif Game.state == "settings" then
        if key == "escape" then Game.state = "pause" end
    end
end

function Game.mousepressed(x, y, b)
    if Game.state == "play" then
        local Pl = G.player
        if Pl.mode == "seat" and Pl.station.mousepressed then Pl.station.mousepressed(b) end
    else
        if b == 1 then G.ui.clicked = true end
    end
end

function Game.wheelmoved(x, y)
    local Pl = G.player
    if Game.state == "play" and Pl.mode == "seat" and Pl.station.wheelmoved then Pl.station.wheelmoved(y) end
    if Game.state == "play" and Pl.mode == "walk" and y ~= 0 then G.weapons.cycle(y > 0 and -1 or 1) end
end

function Game.mousemoved(x, y, dx, dy)
    if Game.state == "play" then
        G.player.mousemoved(dx, dy, G.settings.sensitivity())
    end
end

return Game
