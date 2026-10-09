-- Item definitions and simple count-based containers (player pack and tank storage).
local Inv = {}

Inv.ITEMS = {
    ap_shell = { name = "AP SHELL", carry = 4, icon = "shell", desc = "Armour piercing round for the main gun." },
    he_shell = { name = "HE SHELL", carry = 4, icon = "shell", desc = "High explosive round for soft targets and buildings." },
    mg_ammo = { name = "MG AMMO", carry = 600, icon = "ammo", desc = "Belted 7.92mm for the bow machine gun." },
    rifle_ammo = { name = "RIFLE AMMO", carry = 60, icon = "ammo", desc = "Stripper clips for the Karabiner." },
    shotgun_ammo = { name = "12G SHELLS", carry = 48, icon = "ammo", desc = "Buckshot for the pump shotgun." },
    pistol_ammo = { name = "LIGHT AMMO", carry = 213, icon = "ammo", desc = "Rounds for the submachine gun / AK and the pistol." },
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
    -- clothing: worn in five slots, warmth adds up (see Inv.insulation)
    wool_cap = { name = "WOOL CAP", carry = 2, wear = "head", warmth = 6, use = true, desc = "A knitted cap. Better than nothing." },
    ushanka = { name = "USHANKA", carry = 2, wear = "head", warmth = 12, use = true, desc = "Fur hat with ear flaps. Army issue." },
    sweater = { name = "WOOL SWEATER", carry = 2, wear = "torso", warmth = 10, use = true, desc = "Thick, itchy and warm." },
    telogreika = { name = "TELOGREIKA", carry = 2, wear = "torso", warmth = 22, use = true, desc = "Quilted cotton jacket, the winter coat of every worker." },
    greatcoat = { name = "ARMY GREATCOAT", carry = 2, wear = "torso", warmth = 28, use = true, desc = "Heavy wool shinel down to the knees." },
    sheepskin = { name = "SHEEPSKIN COAT", carry = 2, wear = "torso", warmth = 34, use = true, desc = "Tulup. The warmest thing you will find out here." },
    trousers = { name = "WOOL TROUSERS", carry = 2, wear = "legs", warmth = 6, use = true, desc = "Plain wool trousers." },
    quilted_pants = { name = "QUILTED TROUSERS", carry = 2, wear = "legs", warmth = 14, use = true, desc = "Padded trousers to go with a telogreika." },
    gloves = { name = "LEATHER GLOVES", carry = 2, wear = "hands", warmth = 4, use = true, desc = "Thin, but you can still work a trigger." },
    mittens = { name = "FUR MITTENS", carry = 2, wear = "hands", warmth = 8, use = true, desc = "Sheepskin mittens with a trigger finger." },
    boots = { name = "ARMY BOOTS", carry = 2, wear = "feet", warmth = 6, use = true, desc = "Kirza boots with foot wraps." },
    valenki = { name = "VALENKI", carry = 2, wear = "feet", warmth = 14, use = true, desc = "Felt boots. Nothing keeps feet warmer in dry snow." },
}
Inv.SLOTS = { "head", "torso", "legs", "hands", "feet" }
Inv.SLOT_NAMES = { head = "HEAD", torso = "BODY", legs = "LEGS", hands = "HANDS", feet = "FEET" }
Inv.ORDER = { "ap_shell", "he_shell", "mg_ammo", "rifle_ammo", "pistol_ammo", "shotgun_ammo", "fuel", "food", "water", "medkit",
              "repair_kit", "battery", "tools", "antirad", "keycard", "documents",
              "wool_cap", "ushanka", "sweater", "telogreika", "greatcoat", "sheepskin", "trousers", "quilted_pants",
              "gloves", "mittens", "boots", "valenki" }

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
    Inv.player:load({ rifle_ammo = 20, pistol_ammo = 90, shotgun_ammo = 12, food = 1, medkit = 1, battery = 1 })
    Inv.tank:load({ ap_shell = 6, he_shell = 4, mg_ammo = 450, food = 3, water = 4, medkit = 1, repair_kit = 1, battery = 1, tools = 1 })
    -- what you were wearing when the war ended
    Inv.worn = { head = "wool_cap", torso = "telogreika", legs = "trousers", hands = "gloves", feet = "boots" }
end

-- total warmth of the clothes worn (0..~90)
function Inv.insulation()
    local n = 0
    for _, slot in ipairs(Inv.SLOTS) do
        local id = Inv.worn[slot]
        if id and Inv.ITEMS[id] then n = n + Inv.ITEMS[id].warmth end
    end
    return n
end

-- put on a piece of clothing from the pack; whatever was in that slot goes back into the pack
function Inv.wear(id)
    local def = Inv.ITEMS[id]
    if not def or not def.wear or Inv.player:count(id) <= 0 then return false end
    local old = Inv.worn[def.wear]
    Inv.player:remove(id, 1)
    Inv.worn[def.wear] = id
    if old then
        if Inv.player:add(old, 1) == 0 then Inv.tank:add(old, 1) end
    end
    local G = Inv.G
    if G.ui then G.ui.notify("PUT ON " .. def.name) end
    if G.audio then G.audio.play("pickup", { volume = 0.6, pitch = 0.8 }) end
    return true
end

function Inv.takeOff(slot)
    local id = Inv.worn[slot]
    if not id then return false end
    if Inv.player:add(id, 1) == 0 then
        if Inv.G.ui then Inv.G.ui.notify("NO ROOM IN THE PACK") end
        return false
    end
    Inv.worn[slot] = nil
    return true
end

function Inv.serializeWorn()
    local t = {}
    for k, v in pairs(Inv.worn) do t[k] = v end
    return t
end

function Inv.loadWorn(t)
    Inv.worn = {}
    for k, v in pairs(t or {}) do if Inv.ITEMS[v] then Inv.worn[k] = v end end
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
    if Inv.ITEMS[id] and Inv.ITEMS[id].wear then return Inv.wear(id) end
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
