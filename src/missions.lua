-- Story state without on-screen objectives: places you have found, places the radio and the
-- documents told you about, and the quiet thread from the radio tower to the plant's control block.
local U = require("src.utils")
local M = {}
local G

M.MAIN = {
    { id = "tower" }, { id = "transmitter" }, { id = "bunker" }, { id = "keycard" },
    { id = "plant" }, { id = "control" }, { id = "signal" },
}

function M.init(game)
    G = game
    M.reset()
end

function M.reset()
    M.stage = 1
    M.discovered = {}
    M.revealed = { camp = true, kolkhoz = true }
    M.flags = {}
    M.finished = false
end

function M.serialize()
    return { stage = M.stage, discovered = M.discovered, revealed = M.revealed, flags = M.flags, finishedHome = M.discovered.outpost }
end

function M.load(s)
    M.reset()
    if not s then return end
    M.stage = s.stage or 1
    M.discovered = s.discovered or {}
    M.revealed = s.revealed or M.revealed
    M.flags = s.flags or {}
end

function M.current() return M.MAIN[M.stage] end

local function complete(id)
    local cur = M.MAIN[M.stage]
    if cur and cur.id == id then
        M.stage = M.stage + 1
        if G.save and G.game and G.game.autosave then G.game.autosave() end
        return true
    end
end
M.complete = complete

function M.reveal(id)
    if not M.revealed[id] then
        M.revealed[id] = true
        local l = G.world[id]
        if l and G.ui then G.ui.notify("MARKED ON MAP: " .. l.name) end
    end
end

local function advanceTo(n) if M.stage < n then M.stage = n end end

function M.event(name, data)
    if name == "transmitter_used" then
        advanceTo(2) complete("transmitter")
        M.reveal("bunker")
    elseif name == "entered_bunker" then
        advanceTo(3) complete("bunker")
    elseif name == "picked" then
        if data == "keycard" then
            advanceTo(4) complete("keycard")
            M.reveal("plant")
        end
    elseif name == "control_entered" then
        advanceTo(6) complete("control")
    elseif name == "signal_found" then
        complete("signal")
        M.finished = true
    elseif name == "discovered" then
        if data == "tower" then complete("tower") end
        if data == "plant" and M.stage == 5 then complete("plant") end
        -- home: our outpost in the north
        if data == "outpost" then
            M.finished = true
            if G.game and G.game.homecoming then G.game.homecoming() end
        end
    end
end

function M.update(dt)
    local px, py, pz = G.player.feetWorld()
    for _, l in ipairs(G.world.locations) do
        if not M.discovered[l.id] and U.dist2(px, pz, l.x, l.z) < l.r * 0.75 then
            M.discovered[l.id] = true
            M.revealed[l.id] = true
            if G.ui then G.ui.areaTitle(l.area) end
            M.event("discovered", l.id)
        end
    end
end

return M
