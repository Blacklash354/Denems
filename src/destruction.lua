-- Destructible world: objects take damage from bullets, shells, explosions and the tank's weight,
-- then break apart into flying debris, dust and smoke. Buildings collapse into rubble,
-- vehicles burn out, fuel tanks explode.
local U = require("src.utils")
local MB = require("src.engine.meshbuilder")

local D = {}
local G

-- damage multipliers per material class
local RES = {
    wood = { bullet = 1.0, explosion = 1.0, ram = 1.0 },
    cloth = { bullet = 1.0, explosion = 1.0, ram = 1.0 },
    metal = { bullet = 0.55, explosion = 1.0, ram = 0.8 },
    stone = { bullet = 0.3, explosion = 1.0, ram = 0.6 },
    vehicle = { bullet = 0.4, explosion = 1.0, ram = 0.7 },
    building = { bullet = 0.03, explosion = 1.0, ram = 0.5 },
}
local SOUND = { wood = "wood_break", cloth = "wood_break", metal = "clang", stone = "collapse", vehicle = "explosion", building = "collapse" }

function D.init(game) G = game end

local function dominantMat(obj)
    local best, bn = "rubble", 0
    for name, r in pairs(obj.raw or {}) do
        if r.n > bn and name ~= "window" and name ~= "snow" then best, bn = name, r.n end
    end
    return best
end
D.dominantMat = dominantMat

-- rubble mound + broken wall stubs where a building stood
local function buildRuin(obj, mat)
    local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
    for _, b in ipairs(obj.colliders) do
        x0, z0, x1, z1 = math.min(x0, b[1]), math.min(z0, b[3]), math.max(x1, b[4]), math.max(z1, b[6])
    end
    if x0 > x1 then return end
    local y = obj.baseY
    local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    local w, d = x1 - x0, z1 - z0
    local mb = MB.new(obj.id * 13 + 5)
    mb.texScale = 0.5
    local rng = U.rng(obj.id * 7 + 1)
    mb:material("rubble"):color(0.85, 0.83, 0.8)
    mb:sphere(cx, y - 0.2, cz, w * 0.48, 1.4, d * 0.48, 8, 4)
    for i = 1, 5 do
        mb:push() mb:translate(cx + rng:range(-w / 3, w / 3), y + 0.2, cz + rng:range(-d / 3, d / 3)) mb:rotateY(rng:range(0, 6))
        mb:sphere(0, 0, 0, rng:range(0.6, 1.4), rng:range(0.4, 0.9), rng:range(0.6, 1.2), 5, 3)
        mb:pop()
    end
    -- jagged wall stubs along the old outline
    mb:material(mat):color(0.75, 0.72, 0.68)
    for i = 1, 6 do
        local side = i % 4
        local t = rng:range(0.1, 0.8)
        local h = rng:range(0.4, 2.2)
        local len = rng:range(1.0, 2.6)
        if side == 0 then mb:box(x0 + t * w, y, z0 - 0.12, x0 + t * w + len, y + h, z0 + 0.12)
        elseif side == 1 then mb:box(x0 + t * w, y, z1 - 0.12, x0 + t * w + len, y + h, z1 + 0.12)
        elseif side == 2 then mb:box(x0 - 0.12, y, z0 + t * d, x0 + 0.12, y + h, z0 + t * d + len)
        else mb:box(x1 - 0.12, y, z0 + t * d, x1 + 0.12, y + h, z0 + t * d + len) end
    end
    mb:material("wood"):color(0.35, 0.3, 0.26)
    for i = 1, 3 do
        local ax, az = cx + rng:range(-w / 2, w / 2), cz + rng:range(-d / 2, d / 2)
        mb:push() mb:translate(ax, y + 0.6, az) mb:rotateY(rng:range(0, 6)) mb:rotateZ(rng:range(-0.5, 0.5))
        mb:box(-1.5, -0.08, -0.08, 1.5, 0.08, 0.08)
        mb:pop()
    end
    mb:material("snow"):color(0.95, 0.97, 1)
    mb:sphere(cx, y + 0.9, cz, w * 0.25, 0.25, d * 0.25, 6, 3)
    local raw, b = mb:buildRaw()
    local ruin = { ruin = true, alive = false, raw = raw, bounds = { b[1], b[2], b[3], b[4], b[5], b[6] },
                   cx = cx, cy = y, cz = cz, radius = math.max(w, d), colliders = {} }
    local box = { x0 + 0.5, y - 1, z0 + 0.5, x1 - 0.5, y + 0.6, z1 - 0.5, walk = true, noVehicle = true }
    G.world.colliders:add(box)
    G.world.addDObj(ruin)
end

function D.destroy(obj, hx, hy, hz)
    if not obj.alive then return end
    obj.alive = false
    local W = G.world
    local E = G.effects
    local cx, cy, cz = obj.cx, obj.cy, obj.cz
    local mat = dominantMat(obj)
    local size = obj.radius or 2
    if obj.kind == "vehicle" then
        -- burns out: keep the hulk, charred black, on fire for a while
        obj.ruin = true
        MB.tintRaw(obj.raw, 0.25)
        G.weapons.explode(cx, cy, cz, 6, 90, "world")
        W.emitters[#W.emitters + 1] = { x = cx, y = cy + 0.6, z = cz, kind = "fire", rate = 1, acc = 0, life = 90 }
        W.emitters[#W.emitters + 1] = { x = cx, y = cy + 1.2, z = cz, kind = "blacksmoke", rate = 1, acc = 0, life = 120 }
        W.staticLights[#W.staticLights + 1] = { x = cx, y = cy + 1.5, z = cz, r = 1, g = 0.5, b = 0.2, radius = 10, intensity = 1.4, flicker = true, life = 90 }
        W.fires[#W.fires + 1] = { x = cx, y = cy, z = cz, r = 5 }
        E.debris(cx, cy + 1, cz, mat, 10, 7, 0.35)
    else
        for _, b in ipairs(obj.colliders) do b.enabled = false end
        for _, d in ipairs(W.doors) do if d.obj == obj then d.box.enabled = false end end
        if obj.shelter then
            for i, s in ipairs(W.shelters) do if s == obj.shelter then table.remove(W.shelters, i) break end end
        end
        local n = math.floor(U.clamp(size * 4, 6, 40))
        E.debris(cx, cy, cz, mat, n, 4 + size, obj.kind == "building" and 0.7 or 0.4)
        -- dust cloud, bigger for buildings
        local dust = obj.kind == "building" and 30 or 8
        for i = 1, dust do
            E.spawn(cx + (math.random() - 0.5) * size, cy + math.random() * size * 0.5, cz + (math.random() - 0.5) * size,
                (math.random() - 0.5) * 3, 0.5 + math.random() * 2, (math.random() - 0.5) * 3, 3 + math.random() * 4,
                0.8 + size * 0.15, 1.5 + size * 0.2, 0.62, 0.6, 0.57, 0.6, false, 0.8, -0.1)
        end
        for i = 1, 6 do E.snowPuff(cx + (math.random() - 0.5) * size, W.height(cx, cz), cz + (math.random() - 0.5) * size, 2) end
        if obj.kind == "building" then buildRuin(obj, mat) end
        if obj.explode then
            G.weapons.explode(cx, cy, cz, 14, 320, "world")
            W.emitters[#W.emitters + 1] = { x = cx, y = cy, z = cz, kind = "fire", rate = 1, acc = 0, life = 120 }
            W.emitters[#W.emitters + 1] = { x = cx, y = cy + 1, z = cz, kind = "blacksmoke", rate = 1, acc = 0, life = 150 }
            W.staticLights[#W.staticLights + 1] = { x = cx, y = cy + 2, z = cz, r = 1, g = 0.5, b = 0.2, radius = 16, intensity = 2, flicker = true, life = 120 }
        end
    end
    if G.audio then G.audio.play(SOUND[obj.kind] or "wood_break", { x = cx, y = cy, z = cz, big = obj.kind == "building" or obj.kind == "vehicle" }) end
    if G.camera and obj.kind == "building" then
        local px, py, pz = G.player.feetWorld()
        local d = U.dist3(px, py, pz, cx, cy, cz)
        if d < 60 then G.camera.shake(0.6 * (1 - d / 60)) end
    end
    if G.humans then G.humans.noise(cx, cy, cz, obj.kind == "building" and 150 or 50) end
    W.rebuildChunkD(obj.chunk)
end

function D.damage(obj, amount, kind, hx, hy, hz)
    if not obj or not obj.alive then return false end
    local res = RES[obj.kind] or RES.wood
    local dmg = amount * (res[kind] or 1)
    obj.hp = obj.hp - dmg
    -- chips fly off on every hit
    if hx and dmg > 1 and kind ~= "ram" then
        G.effects.debris(hx, hy, hz, dominantMat(obj), kind == "bullet" and 2 or 6, kind == "bullet" and 3 or 6, kind == "bullet" and 0.12 or 0.25)
        G.effects.dust(hx, hy, hz)
    end
    if obj.hp <= 0 then
        D.destroy(obj, hx, hy, hz)
        return true
    end
    return false
end

function D.splash(x, y, z, radius, damage)
    for _, o in ipairs(G.world.dobjs) do
        if o.alive and o.cx then
            local d = U.dist3(x, y, z, o.cx, o.cy, o.cz) - (o.radius or 1) * 0.6
            if d < radius then D.damage(o, damage * U.clamp(1 - d / radius, 0.2, 1), "explosion", o.cx, o.cy, o.cz) end
        end
    end
end

-- the tank driving into something
function D.ram(obj, speed)
    if not obj.alive then return false end
    if obj.crush then
        if speed > 0.8 then D.destroy(obj) return true end
        return false
    end
    if speed > 4 then return D.damage(obj, speed * 30, "ram") end
    return false
end

return D
