-- JSON save/load of the whole game state.
local json = require("src.lib.json")
local S = {}
local G
local FILE = "save.json"

function S.init(game) G = game end

function S.exists() return love.filesystem.getInfo(FILE) ~= nil end

function S.save()
    local W = G.world
    local searched, taken, doors = {}, {}, {}
    for _, c in ipairs(W.containers) do if c.searched or c.dirty then searched[c.id] = c.loot end end
    for _, p in ipairs(W.pickups) do if p.taken then taken[#taken + 1] = p.id end end
    for _, d in ipairs(W.doors) do if d.open or d.unlocked then doors[d.id] = { open = d.open, unlocked = d.unlocked } end end
    local data = {
        version = 1,
        player = G.player.serialize(),
        tank = G.tank.serialize(),
        invPlayer = G.inventory.player:serialize(),
        invTank = G.inventory.tank:serialize(),
        weapons = G.weapons.serialize(),
        missions = G.missions.serialize(),
        environment = G.environment.serialize(),
        weather = G.weather.serialize(),
        creatures = G.creatures.serialize(),
        enemies = G.enemies.serialize(),
        humans = G.humans.serialize(),
        containers = searched,
        pickups = taken,
        doors = doors,
        playTime = G.game.playTime,
    }
    local ok, err = love.filesystem.write(FILE, json.encode(data))
    return ok, err
end

function S.read()
    local s = love.filesystem.read(FILE)
    if not s then return nil end
    return json.decode(s)
end

function S.apply(data)
    local W = G.world
    G.tank.reset(data.tank)
    G.player.load(data.player)
    G.inventory.player:load(data.invPlayer)
    G.inventory.tank:load(data.invTank)
    G.weapons.reset()
    G.weapons.load(data.weapons)
    G.missions.load(data.missions)
    G.environment.load(data.environment)
    G.weather.load(data.weather)
    G.creatures.load(data.creatures)
    G.enemies.reset(data.enemies)
    G.humans.reset(data.humans)
    local taken = {}
    for _, id in ipairs(data.pickups or {}) do taken[id] = true end
    for _, p in ipairs(W.pickups) do p.taken = taken[p.id] or false end
    for _, c in ipairs(W.containers) do
        local saved = data.containers and data.containers[c.id]
        if saved then
            c.loot = saved
            c.searched = #saved == 0
            c.dirty = true
        end
    end
    for _, d in ipairs(W.doors) do
        local s = data.doors and data.doors[d.id]
        d.open = s and s.open or false
        d.unlocked = s and s.unlocked or false
        d.angle = d.open and 1 or 0
        d.box.enabled = not d.open
    end
    G.game.playTime = data.playTime or 0
end

return S
