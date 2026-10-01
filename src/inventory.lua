-- Item definitions and simple count-based containers (player pack and tank storage).
local Inv = {}

Inv.ITEMS = {
    ap_shell = { name = "AP SHELL", carry = 4, icon = "shell", desc = "Armour piercing round for the main gun." },
    he_shell = { name = "HE SHELL", carry = 4, icon = "shell", desc = "High explosive round. Devastating against creatures." },
    mg_ammo = { name = "MG AMMO", carry = 600, icon = "ammo", desc = "Belted 7.92mm for the bow machine gun." },
    rifle_ammo = { name = "RIFLE AMMO", carry = 60, icon = "ammo", desc = "Stripper clips for the Karabiner." },
    pistol_ammo = { name = "PISTOL AMMO", carry = 48, icon = "ammo", desc = "9mm rounds for the pistol." },
    fuel = { name = "FUEL CAN", carry = 2, icon = "fuel", desc = "20 litres. Pour into the tank to refuel (+18%)." },
    food = { name = "FOOD", carry = 10, icon = "food", desc = "Tinned rations. Restores health and warmth.", use = true },
    water = { name = "WATER", carry = 10, icon = "water", desc = "Melted snow in a canteen. Restores stamina.", use = true },
    medkit = { name = "MEDKIT", carry = 5, icon = "medkit", desc = "Bandages and morphine. Restores health.", use = true },
    repair_kit = { name = "REPAIR KIT", carry = 3, icon = "repair", desc = "Spare parts and tools to fix tank components." },
    battery = { name = "BATTERY", carry = 4, icon = "battery", desc = "Recharges the flashlight.", use = true },
    tools = { name = "SPARE PARTS", carry = 6, icon = "repair", desc = "Bolts, links and wire. Three make a repair kit.", use = true },
    antirad = { name = "ANTI-RAD", carry = 5, icon = "medkit", desc = "Potassium iodide. Lowers radiation dose.", use = true },
    keycard = { name = "REACTOR KEYCARD", carry = 1, icon = "key", desc = "Access card for the plant control block.", quest = true },
    documents = { name = "DOCUMENTS", carry = 5, icon = "paper", desc = "Orders and logs from the garrison.", quest = true },
}
Inv.ORDER = { "ap_shell", "he_shell", "mg_ammo", "rifle_ammo", "pistol_ammo", "fuel", "food", "water", "medkit",
              "repair_kit", "battery", "tools", "antirad", "keycard", "documents" }

local C = {}
C.__index = C

function Inv.new(limited)
    return setmetatable({ items = {}, limited = limited }, C)
end

function C:count(id) return self.items[id] or 0 end

function C:space(id)
    if not self.limited then return math.huge end
    local def = Inv.ITEMS[id]
    return math.max(0, (def and def.carry or 99) - self:count(id))
end

-- adds as much as fits, returns amount added
function C:add(id, n)
    n = math.min(n, self:space(id))
    if n <= 0 then return 0 end
    self.items[id] = self:count(id) + n
    return n
end

function C:remove(id, n)
    local have = self:count(id)
    n = math.min(n, have)
    self.items[id] = have - n
    if self.items[id] <= 0 then self.items[id] = nil end
    return n
end

function C:list()
    local out = {}
    for _, id in ipairs(Inv.ORDER) do
        if self:count(id) > 0 then out[#out + 1] = id end
    end
    return out
end

function C:serialize()
    local t = {}
    for k, v in pairs(self.items) do t[k] = v end
    return t
end

function C:load(t)
    self.items = {}
    for k, v in pairs(t or {}) do self.items[k] = v end
end

function Inv.init(game)
    Inv.G = game
    Inv.player = Inv.new(true)
    Inv.tank = Inv.new(false)
    Inv.reset()
end

function Inv.reset()
    Inv.player:load({ rifle_ammo = 20, pistol_ammo = 16, food = 1, medkit = 1, battery = 1 })
    Inv.tank:load({ ap_shell = 6, he_shell = 4, mg_ammo = 450, food = 3, water = 4, medkit = 1, repair_kit = 1, battery = 1, tools = 1 })
end

-- move from one container to another
function Inv.transfer(from, to, id, n)
    local moved = to:add(id, math.min(n, from:count(id)))
    from:remove(id, moved)
    return moved
end

-- consume an item from the player's pack
function Inv.use(id)
    local G = Inv.G
    local pl = G.player
    local inv = Inv.player
    if inv:count(id) <= 0 then return false end
    local msg
    if id == "food" then
        if pl.health >= 100 and pl.warmth >= 100 then return false end
        pl.health = math.min(100, pl.health + 15)
        pl.warmth = math.min(100, pl.warmth + 10)
        msg = "ATE RATIONS"
    elseif id == "water" then
        pl.stamina = 100
        pl.health = math.min(100, pl.health + 4)
        msg = "DRANK WATER"
    elseif id == "medkit" then
        if pl.health >= 100 then return false end
        pl.health = math.min(100, pl.health + 50)
        msg = "USED MEDKIT"
    elseif id == "antirad" then
        pl.radiation = math.max(0, pl.radiation - 40)
        msg = "TOOK ANTI-RAD PILLS"
    elseif id == "battery" then
        if pl.battery >= 99 then return false end
        pl.battery = 100
        msg = "FLASHLIGHT RECHARGED"
    elseif id == "tools" then
        if inv:count("tools") < 3 then
            if G.ui then G.ui.notify("NEED 3 SPARE PARTS FOR A REPAIR KIT") end
            return false
        end
        if inv:space("repair_kit") <= 0 then return false end
        inv:remove("tools", 2)
        inv:add("repair_kit", 1)
        msg = "ASSEMBLED A REPAIR KIT"
    else
        return false
    end
    inv:remove(id, 1)
    if G.ui and msg then G.ui.notify(msg) end
    if G.audio then G.audio.play("pickup", {}) end
    return true
end

return Inv
