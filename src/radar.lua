-- Tank radar: a green phosphor scope rendered to a canvas every frame. The canvas is used both as
-- the texture of the physical radar screen inside the hull and as the HUD radar while crewing the tank.
local U = require("src.utils")
local MB = require("src.engine.meshbuilder")

local Rd = { RANGE = 200, sweep = 0, blips = {}, known = {} }
local G
local lg = love.graphics
local SIZE = 96

function Rd.init(game)
    G = game
    Rd.canvas = lg.newCanvas(SIZE, SIZE)
    Rd.canvas:setFilter("nearest", "nearest")
    -- physical console on the left sponson, screen facing into the hull
    local mb = MB.new(701)
    mb:material("steel"):color(0.5, 0.52, 0.48)
    mb:box(1.62, 1.56, -1.74, 2.18, 2.1, -1.52)
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:box(1.66, 2.04, -1.52, 1.72, 2.08, -1.48)
    mb:box(2.08, 2.04, -1.52, 2.14, 2.08, -1.48)
    Rd.console = mb:build()
    mb = MB.new(702)
    mb:material("white"):color(1, 1, 1)
    mb:quadUV(1.7, 1.62, -1.515, 0, 1, 2.1, 1.62, -1.515, 1, 1, 2.1, 2.02, -1.515, 1, 0, 1.7, 2.02, -1.515, 0, 0)
    Rd.screen = mb:build()
    Rd.screen.parts[1].mesh:setTexture(Rd.canvas)
    Rd.light = { 1.9, 1.82, -1.3 }
end

local function contacts()
    local list = {}
    for _, c in ipairs(G.creatures.list) do
        if c.state ~= "dead" and c.state ~= "buried" then
            list[#list + 1] = { x = c.x, z = c.z, kind = c.kind == "mutant" and "big" or "creature", hostile = true, id = c }
        end
    end
    for _, h in ipairs(G.humans.list) do
        if h.state ~= "dead" then list[#list + 1] = { x = h.x, z = h.z, kind = "human", hostile = h.hostile, id = h } end
    end
    for _, t in ipairs(G.enemies.tanks) do
        if t.alive then list[#list + 1] = { x = t.x, z = t.z, kind = "tank", hostile = true, id = t } end
    end
    return list
end

local DIRS = { "E", "SE", "S", "SW", "W", "NW", "N", "NE" }
local function compassDir(dx, dz)
    local a = math.deg(math.atan2(dz, dx)) % 360
    return DIRS[math.floor((a + 22.5) / 45) % 8 + 1]
end
Rd.compassDir = compassDir

function Rd.update(dt)
    local T = G.tank
    if T.destroyed then Rd.blips = {} return end
    local prev = Rd.sweep
    Rd.sweep = (Rd.sweep + dt * 2.2) % (2 * math.pi)
    local list = contacts()
    local inside = G.player.frameName == "tank"
    local newHostile, newKinds = 0, {}
    for _, c in ipairs(list) do
        local lx, ly, lz = T.frame:toLocal(c.x, T.y, c.z)
        local d = math.sqrt(lx * lx + lz * lz)
        if d < Rd.RANGE then
            local a = math.atan2(lz, lx) % (2 * math.pi)
            local passed = (prev <= Rd.sweep and a > prev and a <= Rd.sweep) or (prev > Rd.sweep and (a > prev or a <= Rd.sweep))
            if passed then Rd.blips[#Rd.blips + 1] = { x = lx / Rd.RANGE, z = lz / Rd.RANGE, kind = c.kind, hostile = c.hostile, life = 1 } end
            if c.hostile and not Rd.known[c.id] then
                Rd.known[c.id] = true
                newHostile = newHostile + 1
                newKinds[#newKinds + 1] = { kind = c.kind, d = d, dx = c.x - T.x, dz = c.z - T.z }
            end
        else
            Rd.known[c.id] = nil
        end
    end
    for i = #Rd.blips, 1, -1 do
        local b = Rd.blips[i]
        b.life = b.life - dt / 2.8
        if b.life <= 0 then table.remove(Rd.blips, i) end
    end
    -- warn the crew about fresh contacts
    if newHostile > 0 and inside then
        local k = newKinds[1]
        local names = { creature = "MOVEMENT", big = "LARGE CONTACT", human = "HOSTILES", tank = "ENEMY ARMOR" }
        if G.ui then G.ui.notify(string.format("RADAR: %s %s %dM%s", names[k.kind] or "CONTACT", compassDir(k.dx, k.dz), k.d,
            newHostile > 1 and (" (+" .. (newHostile - 1) .. ")") or "")) end
        if G.audio then G.audio.play("radar_ping", { tank = true }) end
    end
end

function Rd.render()
    lg.push("all")
    lg.setCanvas(Rd.canvas)
    lg.origin()
    lg.clear(0.02, 0.08, 0.03, 1)
    local c = SIZE / 2
    local R = SIZE / 2 - 3
    lg.setLineStyle("rough")
    lg.setColor(0.15, 0.55, 0.2, 0.7)
    for i = 1, 3 do lg.circle("line", c, c, R * i / 3, 32) end
    lg.line(c - R, c, c + R, c) lg.line(c, c - R, c, c + R)
    -- sweep wedge (tank forward is up on the scope)
    for k = 0, 10 do
        local a = Rd.sweep - k * 0.06
        lg.setColor(0.3, 1, 0.4, 0.5 * (1 - k / 11))
        lg.line(c, c, c + math.sin(a) * R, c - math.cos(a) * R)
    end
    for _, b in ipairs(Rd.blips) do
        local x, y = c + b.z * R, c - b.x * R
        local col = b.hostile and { 1, 0.35, 0.2 } or { 0.4, 1, 0.5 }
        lg.setColor(col[1], col[2], col[3], b.life)
        if b.kind == "tank" then lg.rectangle("fill", x - 2.5, y - 2.5, 5, 5)
        elseif b.kind == "big" then lg.circle("fill", x, y, 3, 8)
        else lg.rectangle("fill", x - 1, y - 1, 2.5, 2.5) end
    end
    -- own tank and north marker
    lg.setColor(0.6, 1, 0.6, 1)
    lg.polygon("fill", c, c - 3, c - 2, c + 2, c + 2, c + 2)
    local T = G.tank
    local nx, ny, nz = T.frame:dirToLocal(0, 0, -1)
    local na = math.atan2(nz, nx)
    lg.setColor(0.6, 1, 0.6, 0.9)
    lg.print("N", c + math.sin(na) * (R - 5) - 3, c - math.cos(na) * (R - 5) - 6)
    lg.setCanvas()
    lg.pop()
end

-- HUD scope for the crew stations
function Rd.drawHUD(UI, x, y, size)
    lg.setColor(1, 1, 1, 0.92)
    lg.draw(Rd.canvas, x, y, 0, size / SIZE, size / SIZE)
    lg.setColor(0.2, 0.6, 0.25, 0.9)
    lg.circle("line", x + size / 2, y + size / 2, size / 2, 32)
    UI.text("RADAR " .. Rd.RANGE .. "M", x, y + size + 1, { 0.4, 0.9, 0.45, 0.9 }, UI.fontS, "center", size)
end

return Rd
