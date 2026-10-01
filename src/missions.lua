-- Objective system: a main story chain plus optional objectives, driven by game events.
local U = require("src.utils")
local M = {}
local G

M.MAIN = {
    { id = "supplies", text = "Check the tank's supplies" },
    { id = "engine", text = "Start the engine (driver's seat)" },
    { id = "tower", text = "Reach the Radio Tower" },
    { id = "transmitter", text = "Use the transmitter at the tower" },
    { id = "bunker", text = "Investigate the underground bunker" },
    { id = "keycard", text = "Find the reactor access keycard" },
    { id = "plant", text = "Reach the Nuclear Plant" },
    { id = "control", text = "Enter the plant control block" },
    { id = "signal", text = "Find the source of the signal" },
}

function M.init(game)
    G = game
    M.reset()
end

function M.reset()
    M.stage = 1
    M.optional = {
        { id = "village", text = "Search the abandoned village", done = false, shown = true, n = 0, need = 2 },
        { id = "fuel", text = "Find fuel", done = false, shown = true, n = 0, need = 2 },
        { id = "ammo", text = "Find ammunition", done = false, shown = true, n = 0, need = 3 },
        { id = "repair", text = "Repair the tank", done = false, shown = true },
        { id = "bunker_opt", text = "Investigate bunker", done = false, shown = false },
        { id = "checkpoint", text = "Investigate the checkpoint", done = false, shown = false },
        { id = "enemy", text = "Destroy the enemy tank", done = false, shown = false },
        { id = "cabin", text = "Find the hunter's cabin", done = false, shown = false },
    }
    M.discovered = {}
    M.revealed = { tower = true }
    M.flags = {}
    M.flash = 8
    M.finished = false
end

function M.serialize()
    local opt = {}
    for _, o in ipairs(M.optional) do opt[o.id] = { done = o.done, shown = o.shown, n = o.n } end
    return { stage = M.stage, optional = opt, discovered = M.discovered, revealed = M.revealed, flags = M.flags }
end

function M.load(s)
    M.reset()
    if not s then return end
    M.stage = s.stage or 1
    for _, o in ipairs(M.optional) do
        local v = s.optional and s.optional[o.id]
        if v then o.done, o.shown, o.n = v.done, v.shown, v.n end
    end
    M.discovered = s.discovered or {}
    M.revealed = s.revealed or { tower = true }
    M.flags = s.flags or {}
end

function M.current() return M.MAIN[M.stage] end

local function opt(id) for _, o in ipairs(M.optional) do if o.id == id then return o end end end
M.opt = opt

function M.optText(o)
    if o.need then return string.format("%s (%d/%d)", o.text, math.min(o.n, o.need), o.need) end
    return o.text
end

local function complete(id)
    local cur = M.MAIN[M.stage]
    if cur and cur.id == id then
        M.stage = M.stage + 1
        M.flash = 8
        if G.audio then G.audio.play("notify", {}) end
        local nxt = M.MAIN[M.stage]
        if nxt and G.ui then G.ui.objective("NEW OBJECTIVE", nxt.text) end
        if G.save and G.game and G.game.autosave then G.game.autosave() end
        return true
    end
end
M.complete = complete

local function progressOpt(id, amount)
    local o = opt(id)
    if not o or o.done then return end
    o.shown = true
    if o.need then
        o.n = o.n + (amount or 1)
        if o.n >= o.need then o.done = true end
    else
        o.done = true
    end
    M.flash = 8
    if o.done and G.ui then G.ui.objective("OBJECTIVE COMPLETE", o.text) end
    if G.audio then G.audio.play("notify", {}) end
end
M.progressOpt = progressOpt

function M.reveal(id)
    if not M.revealed[id] then
        M.revealed[id] = true
        local l = G.world[id]
        if l and G.ui then G.ui.notify("MAP UPDATED: " .. l.name) end
    end
end

function M.event(name, data)
    if name == "storage_opened" then complete("supplies")
    elseif name == "engine_started" then
        if M.stage == 1 then M.stage = 2 end
        complete("engine")
    elseif name == "transmitter_used" then
        if M.stage < 4 then M.stage = 4 end
        complete("transmitter")
        M.reveal("bunker")
        local b = opt("bunker_opt")
        b.shown = true
    elseif name == "entered_bunker" then
        if M.stage <= 5 then M.stage = math.max(M.stage, 5) complete("bunker") end
        progressOpt("bunker_opt")
    elseif name == "picked" then
        if data == "keycard" then
            if M.stage < 6 then M.stage = 6 end
            complete("keycard")
            M.reveal("plant")
        elseif data == "fuel" then progressOpt("fuel")
        elseif data == "ap_shell" or data == "he_shell" or data == "mg_ammo" then progressOpt("ammo")
        end
    elseif name == "searched" then
        if data and data.village then progressOpt("village") end
    elseif name == "repaired" then progressOpt("repair")
    elseif name == "enemy_spotted" then opt("enemy").shown = true
    elseif name == "enemy_destroyed" then progressOpt("enemy")
    elseif name == "control_entered" then
        if M.stage < 8 then M.stage = 8 end
        complete("control")
    elseif name == "signal_found" then
        complete("signal")
        M.finished = true
    elseif name == "discovered" then
        if data == "tower" then complete("tower") end
        if data == "checkpoint" then progressOpt("checkpoint") end
        if data == "plant" then
            if M.stage == 7 then complete("plant") end
        end
        if data == "forest" then end
    elseif name == "cabin_found" then progressOpt("cabin")
    end
end

function M.update(dt)
    M.flash = math.max(0, M.flash - dt)
    local px, py, pz = G.player.feetWorld()
    for _, l in ipairs(G.world.locations) do
        if not M.discovered[l.id] and U.dist2(px, pz, l.x, l.z) < l.r * 0.75 then
            M.discovered[l.id] = true
            M.revealed[l.id] = true
            if G.ui then G.ui.areaTitle(l.area) end
            M.event("discovered", l.id)
            if l.id == "checkpoint" then opt("checkpoint").shown = true end
        end
    end
    local cur = M.MAIN[M.stage]
    if cur and cur.id == "tower" and M.discovered.tower then complete("tower") end
    if cur and cur.id == "plant" and M.discovered.plant then complete("plant") end
    if not M.flags.cabin and U.dist2(px, pz, 338, 222) < 14 then
        M.flags.cabin = true
        M.event("cabin_found")
    end
    -- the tank needs repair -> keep the optional objective relevant
    local o = opt("repair")
    if o.done then
        local worst, v = G.tank.worstComponent()
        if v < 40 then o.done = false o.text = "Repair the tank" end
    end
end

return M
