-- Modular low-poly prop and building generators. All functions take a world Ctx
-- (local transform already applied) and emit geometry + colliders.
local U = require("src.utils")
local W -- set lazily (world)

local Props = {}
local pi = math.pi

local function world() W = W or require("src.world") return W end

-- wall along local X (from x0 to x1 at z=zc) or along Z. Openings: { {at, width, bottom, top} }
function Props.wall(ctx, x0, z0, x1, z1, y0, y1, thick, openings, props)
    local alongX = math.abs(z1 - z0) < 1e-6
    local len = alongX and (x1 - x0) or (z1 - z0)
    local t = thick / 2
    local function seg(a, b, ya, yb)
        if b - a < 0.02 or yb - ya < 0.02 then return end
        if alongX then ctx:solid(x0 + a, ya, z0 - t, x0 + b, yb, z0 + t, props)
        else ctx:solid(x0 - t, ya, z0 + a, x0 + t, yb, z0 + b, props) end
    end
    openings = openings or {}
    table.sort(openings, function(p, q) return p[1] < q[1] end)
    local cur = 0
    for _, o in ipairs(openings) do
        local a, b = o[1] - o[2] / 2, o[1] + o[2] / 2
        seg(cur, a, y0, y1)
        seg(a, b, y0, y0 + (o[3] or 0))
        seg(a, b, y0 + (o[4] or 2.1), y1)
        cur = b
    end
    seg(cur, len, y0, y1)
end

-- gable roof over rectangle (local), ridge along X
function Props.gableRoof(ctx, x0, z0, x1, z1, y, rise, over, mat)
    local mb = ctx.mb
    ctx:mat(mat or "roof", 0.95, 0.95, 1)
    over = over or 0.4
    local zc = (z0 + z1) / 2
    local th = 0.18
    local a, b = x0 - over, x1 + over
    local za, zb = z0 - over, z1 + over
    local top = y + rise
    -- two slabs as hexas
    mb:hexa({ { a, y, za }, { b, y, za }, { b, top, zc }, { a, top, zc },
              { a, y + th, za }, { b, y + th, za }, { b, top + th, zc }, { a, top + th, zc } })
    mb:hexa({ { a, top, zc }, { b, top, zc }, { b, y, zb }, { a, y, zb },
              { a, top + th, zc }, { b, top + th, zc }, { b, y + th, zb }, { a, y + th, zb } })
    -- gables
    ctx:mat("plaster", 0.75, 0.72, 0.68)
    mb:tri(x0, y, z0, 0, 0, x0, top, zc, 0.5, 1, x0, y, z1, 1, 0)
    mb:tri(x0, y, z1, 1, 0, x0, top, zc, 0.5, 1, x0, y, z0, 0, 0)
    mb:tri(x1, y, z0, 0, 0, x1, y, z1, 1, 0, x1, top, zc, 0.5, 1)
    mb:tri(x1, y, z1, 1, 0, x1, y, z0, 0, 0, x1, top, zc, 0.5, 1)
end

function Props.window(ctx, x, y, z, w, h, facing)
    -- decorative dark window pane slightly proud of the wall; facing: "x+","x-","z+","z-"
    local mb = ctx.mb
    ctx:mat("window", 0.8, 0.8, 0.85)
    local e = 0.03
    if facing == "z-" then mb:quad(x - w / 2, y, z - e, x - w / 2, y + h, z - e, x + w / 2, y + h, z - e, x + w / 2, y, z - e)
    elseif facing == "z+" then mb:quad(x + w / 2, y, z + e, x + w / 2, y + h, z + e, x - w / 2, y + h, z + e, x - w / 2, y, z + e)
    elseif facing == "x+" then mb:quad(x + e, y, z - w / 2, x + e, y + h, z - w / 2, x + e, y + h, z + w / 2, x + e, y, z + w / 2)
    else mb:quad(x - e, y, z + w / 2, x - e, y + h, z + w / 2, x - e, y + h, z - w / 2, x - e, y, z - w / 2) end
end

-- furniture ---------------------------------------------------------------
function Props.table(ctx, x, z, rot)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    ctx:mat("wood", 0.8, 0.75, 0.7)
    mb:box(-0.6, 0.72, -0.4, 0.6, 0.78, 0.4)
    for _, p in ipairs({ { -0.52, -0.32 }, { 0.52, -0.32 }, { 0.52, 0.32 }, { -0.52, 0.32 } }) do
        mb:box(p[1] - 0.04, 0, p[2] - 0.04, p[1] + 0.04, 0.72, p[2] + 0.04)
    end
    mb:pop()
    ctx:collider(x - 0.6, 0, z - 0.6, x + 0.6, 0.78, z + 0.6)
end

function Props.bed(ctx, x, z, rot)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    ctx:mat("metal", 0.6, 0.6, 0.6)
    mb:box(-1, 0, -0.45, 1, 0.4, 0.45)
    ctx:mat("cloth", 0.8, 0.8, 0.7)
    mb:box(-0.95, 0.4, -0.42, 0.95, 0.52, 0.42)
    ctx:mat("metal", 0.6, 0.6, 0.6)
    mb:box(-1.05, 0, -0.45, -0.98, 0.9, 0.45)
    mb:pop()
    ctx:collider(x - 1, 0, z - 1, x + 1, 0.52, z + 1)
end

function Props.stove(ctx, x, z)
    ctx:mat("brick", 0.9, 0.85, 0.8)
    ctx:solid(x - 0.6, 0, z - 0.6, x + 0.6, 1.4, z + 0.6)
    ctx:mat("metal", 0.4, 0.4, 0.4)
    ctx.mb:cylinder(x, 1.4, z, 0.12, 3.6, 0.12, 6)
end

function Props.shelf(ctx, x, z, rot, w)
    local mb = ctx.mb
    w = w or 1.6
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    ctx:mat("wood", 0.7, 0.65, 0.6)
    mb:box(-w / 2, 0, -0.25, -w / 2 + 0.05, 1.9, 0.25)
    mb:box(w / 2 - 0.05, 0, -0.25, w / 2, 1.9, 0.25)
    for k = 0, 3 do mb:box(-w / 2, 0.1 + k * 0.6, -0.25, w / 2, 0.14 + k * 0.6, 0.25) end
    -- clutter
    ctx:mat("crate", 0.8, 0.8, 0.8)
    mb:box(-w / 2 + 0.15, 0.74, -0.15, -w / 2 + 0.5, 1.0, 0.15)
    ctx:mat("metal", 0.6, 0.5, 0.4)
    mb:cylinder(w / 2 - 0.3, 1.34, 0, 0.1, 1.55, 0.1, 6)
    mb:pop()
    if rot and math.abs(math.sin(rot)) > 0.5 then ctx:collider(x - 0.25, 0, z - w / 2, x + 0.25, 1.9, z + w / 2)
    else ctx:collider(x - w / 2, 0, z - 0.25, x + w / 2, 1.9, z + 0.25) end
end

function Props.crate(ctx, x, y, z, s, mat)
    ctx:mat(mat or "crate", 0.9, 0.9, 0.85)
    s = s or 0.8
    return ctx:solid(x - s / 2, y, z - s / 2, x + s / 2, y + s, z + s / 2)
end

function Props.barrel(ctx, x, y, z, rusty)
    ctx:mat(rusty and "rust" or "metal", 0.8, 0.75, 0.7)
    ctx.mb:cylinder(x, y, z, 0.32, y + 0.9, 0.32, 7)
    ctx:collider(x - 0.32, y, z - 0.32, x + 0.32, y + 0.9, z + 0.32)
end

function Props.sandbags(ctx, x0, z0, x1, z1, h)
    local mb = ctx.mb
    ctx:mat("cloth", 0.85, 0.82, 0.7)
    h = h or 1.1
    local dx, dz = x1 - x0, z1 - z0
    local len = math.sqrt(dx * dx + dz * dz)
    local n = math.max(1, math.floor(len / 0.6))
    local rows = math.floor(h / 0.22)
    for r = 0, rows - 1 do
        for i = 0, n - 1 do
            local t = (i + 0.5 + (r % 2) * 0.25) / n
            if t <= 1 then
                local cx, cz = x0 + dx * t, z0 + dz * t
                mb:push() mb:translate(cx, r * 0.22, cz) mb:rotateY(math.atan2(dz, dx))
                mb:box(-0.3, 0, -0.22, 0.3, 0.22, 0.22)
                mb:pop()
            end
        end
    end
    local t = 0.3
    ctx:collider(math.min(x0, x1) - t, 0, math.min(z0, z1) - t, math.max(x0, x1) + t, rows * 0.22, math.max(z0, z1) + t)
end

-- vegetation ----------------------------------------------------------------
function Props.pine(ctx, x, y, z, s, rng)
    local mb = ctx.mb
    s = s or 1
    ctx:mat("bark", 0.9, 0.85, 0.8)
    mb:cylinder(x, y - 0.5, z, 0.22 * s, y + 3 * s, 0.12 * s, 5, false)
    ctx:mat("pine", 0.8, 0.9, 0.85)
    local tiers = 3
    for k = 0, tiers - 1 do
        local by = y + (1.4 + k * 2.1) * s
        local r = (2.4 - k * 0.6) * s
        local top = by + (3.2 - k * 0.4) * s
        mb:cylinder(x, by, z, r, top, 0, 6, "top")
        -- snow on tier
        ctx:mat("snow", 0.95, 0.97, 1)
        mb:cylinder(x, top - (1.0 - k * 0.1) * s, z, r * 0.36, top + 0.05, 0, 6, false)
        ctx:mat("pine", 0.8, 0.9, 0.85)
    end
    ctx:collider(x - 0.35 * s, y - 1, z - 0.35 * s, x + 0.35 * s, y + 6 * s, z + 0.35 * s, { tree = true })
end

function Props.deadTree(ctx, x, y, z, s, rng)
    s = s or 1
    ctx:mat("bark", 0.75, 0.72, 0.7)
    local h = 6 * s
    ctx.mb:cylinder(x, y - 0.5, z, 0.2 * s, y + h, 0.05 * s, 5, false)
    for k = 1, 5 do
        local by = y + h * (0.35 + k * 0.11)
        local a = rng:range(0, 2 * pi)
        local l = (2.2 - k * 0.3) * s
        ctx:beam(x, by, z, x + math.cos(a) * l, by + l * 0.6, z + math.sin(a) * l, 0.08 * s)
    end
    ctx:collider(x - 0.25 * s, y - 1, z - 0.25 * s, x + 0.25 * s, y + h, z + 0.25 * s, { tree = true })
end

function Props.rock(ctx, x, y, z, s, rng)
    ctx:mat("rubble", 0.75, 0.75, 0.78)
    local mb = ctx.mb
    mb:push() mb:translate(x, y, z) mb:rotateY(rng:range(0, 6))
    mb:sphere(0, s * 0.3, 0, s, s * 0.7, s * 0.85, 6, 4)
    mb:pop()
    ctx:collider(x - s * 0.8, y - 1, z - s * 0.8, x + s * 0.8, y + s * 0.9, z + s * 0.8)
end

-- infrastructure ------------------------------------------------------------
function Props.pole(ctx, x, y, z)
    ctx:mat("wood", 0.55, 0.5, 0.45)
    ctx.mb:cylinder(x, y - 0.5, z, 0.14, y + 8, 0.11, 5)
    ctx:beam(x - 0.9, y + 7.4, z, x + 0.9, y + 7.4, z, 0.1)
    ctx:collider(x - 0.15, y, z - 0.15, x + 0.15, y + 8, z + 0.15, { noVehicle = true })
end

function Props.sign(ctx, x, z, rot, tex)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    ctx:mat("metal", 0.5, 0.5, 0.5)
    mb:box(-0.05, 0, -0.05, 0.05, 2.0, 0.05)
    ctx:mat(tex or "sign", 1, 1, 1)
    mb:panel(0.06, 1.4, -0.6, 0.06, 1.4, 0.6, 0.06, 2.2, 0.6, 0.06, 2.2, -0.6)
    mb:pop()
end

function Props.billboard(ctx, x, z, rot, tex, w, h)
    local mb = ctx.mb
    w, h = w or 6, h or 3.5
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    ctx:mat("rust", 0.7, 0.7, 0.7)
    mb:box(-0.1, 0, -w / 2 + 0.3, 0.1, 3, -w / 2 + 0.5)
    mb:box(-0.1, 0, w / 2 - 0.5, 0.1, 3, w / 2 - 0.3)
    ctx:mat(tex or "cloth_red", 1, 1, 1)
    mb:panel(0.12, 2.6, -w / 2, 0.12, 2.6, w / 2, 0.12, 2.6 + h, w / 2, 0.12, 2.6 + h, -w / 2)
    mb:pop()
end

function Props.banner(ctx, x, y, z, facing, w, h)
    -- red banner with star hanging on a facade
    local mb = ctx.mb
    w, h = w or 2.2, h or 4
    mb:push() mb:translate(x, y, z) mb:rotateY(facing or 0)
    ctx:mat("cloth_red", 1, 1, 1)
    mb:panel(0.05, -h, -w / 2, 0.05, -h, w / 2, 0.05, 0, w / 2, 0.05, 0, -w / 2)
    ctx:mat("star", 1, 1, 1)
    mb:panel(0.07, -1.6, -0.6, 0.07, -1.6, 0.6, 0.07, -0.4, 0.6, 0.07, -0.4, -0.6)
    mb:pop()
end

function Props.fence(ctx, x0, z0, x1, z1, h, mat)
    local dx, dz = x1 - x0, z1 - z0
    local len = math.sqrt(dx * dx + dz * dz)
    local n = math.max(1, math.floor(len / 2.5))
    ctx:mat(mat or "wood", 0.6, 0.55, 0.5)
    h = h or 1.3
    for i = 0, n do
        local t = i / n
        local px, pz = x0 + dx * t, z0 + dz * t
        ctx.mb:box(px - 0.06, 0, pz - 0.06, px + 0.06, h, pz + 0.06)
    end
    ctx:beam(x0, h * 0.4, z0, x1, h * 0.4, z1, 0.05, 0.12)
    ctx:beam(x0, h * 0.85, z0, x1, h * 0.85, z1, 0.05, 0.12)
    ctx:collider(math.min(x0, x1) - 0.08, 0, math.min(z0, z1) - 0.08, math.max(x0, x1) + 0.08, h, math.max(z0, z1) + 0.08, { noVehicle = true })
end

function Props.concreteWall(ctx, x0, z0, x1, z1, h)
    ctx:mat("concrete", 0.8, 0.8, 0.8)
    local t = 0.15
    ctx:solid(math.min(x0, x1) - t, 0, math.min(z0, z1) - t, math.max(x0, x1) + t, h or 3, math.max(z0, z1) + t)
end

function Props.hedgehog(ctx, x, z)
    ctx:mat("rust", 0.6, 0.55, 0.5)
    local s = 0.9
    ctx:beam(x - s, 0, z - s, x + s, 1.5, z + s, 0.15)
    ctx:beam(x + s, 0, z - s, x - s, 1.5, z + s, 0.15)
    ctx:beam(x, 0, z + s * 1.2, x, 1.6, z - s * 1.2, 0.15)
    ctx:collider(x - 0.9, 0, z - 0.9, x + 0.9, 1.4, z + 0.9)
end

-- vehicles -----------------------------------------------------------------
local PAINTS = { { 0.42, 0.52, 0.62 }, { 0.72, 0.66, 0.5 }, { 0.45, 0.55, 0.4 }, { 0.62, 0.3, 0.26 }, { 0.75, 0.75, 0.72 } }

local function wheel(mb, x, y, z, r, w, side, burned)
    mb:material("tread"):color(burned and 0.25 or 0.45, burned and 0.22 or 0.45, burned and 0.2 or 0.45)
    mb:cylinderZ(z - w / 2, z + w / 2, x, y, r, 10)
    mb:material(burned and "rust" or "steel"):color(0.55, 0.55, 0.55)
    local hz = z + side * (w / 2 + 0.005)
    mb:cylinderZ(math.min(hz, hz - side * 0.01), math.max(hz, hz - side * 0.01), x, y, r * 0.55, 8)
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:cylinderZ(math.min(hz, hz + side * 0.03), math.max(hz, hz + side * 0.03), x, y, r * 0.15, 6)
end

-- Soviet military truck (ZIL style): rounded nose, cab, canvas-covered or open bed, dual rear wheels
function Props.truck(ctx, x, z, rot, burned)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    local body = burned and "rust" or "tank"
    local br, bg, bb = 0.55, 0.62, 0.48
    if burned then br, bg, bb = 0.45, 0.38, 0.33 end
    -- chassis rails
    mb:material("metal"):color(0.25, 0.25, 0.25)
    mb:box(-3.3, 0.55, -0.55, 3.6, 0.75, -0.4)
    mb:box(-3.3, 0.55, 0.4, 3.6, 0.75, 0.55)
    -- engine hood (sloped nose) and grille
    mb:material(body):color(br, bg, bb)
    mb:hexa({ { 2.3, 0.85, -0.85 }, { 4.05, 0.85, -0.7 }, { 4.05, 0.85, 0.7 }, { 2.3, 0.85, 0.85 },
              { 2.3, 1.75, -0.8 }, { 3.85, 1.55, -0.6 }, { 3.85, 1.55, 0.6 }, { 2.3, 1.75, 0.8 } })
    mb:material("grille"):color(0.7, 0.7, 0.7)
    mb:quad(4.06, 0.95, 0.55, 4.06, 0.95, -0.55, 3.9, 1.5, -0.5, 3.9, 1.5, 0.5)
    -- front fenders over the wheels
    mb:material(body):color(br * 0.9, bg * 0.9, bb * 0.9)
    for _, sd in ipairs({ -1, 1 }) do
        local z0, z1 = sd * 0.85, sd * 1.25
        if sd < 0 then z0, z1 = z1, z0 end
        mb:hexa({ { 2.6, 0.95, z0 }, { 4.0, 0.95, z0 }, { 4.0, 0.95, z1 }, { 2.6, 0.95, z1 },
                  { 2.75, 1.3, z0 }, { 3.85, 1.25, z0 }, { 3.85, 1.25, z1 }, { 2.75, 1.3, z1 } })
    end
    -- bumper and headlights
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:box(4.0, 0.6, -1.15, 4.2, 0.82, 1.15)
    mb:material(burned and "rust" or "white"):color(burned and 0.3 or 0.9, burned and 0.3 or 0.9, burned and 0.3 or 0.75)
    mb:cylinderX(3.95, 4.1, 1.2, -0.95, 0.11, 0.12, 7)
    mb:cylinderX(3.95, 4.1, 1.2, 0.95, 0.11, 0.12, 7)
    -- cab with sloped windshield
    mb:material(body):color(br, bg, bb)
    mb:hexa({ { 1.0, 0.85, -1.15 }, { 2.35, 0.85, -1.15 }, { 2.35, 0.85, 1.15 }, { 1.0, 0.85, 1.15 },
              { 1.0, 2.75, -1.1 }, { 2.05, 2.75, -1.05 }, { 2.05, 2.75, 1.05 }, { 1.0, 2.75, 1.1 } })
    mb:material("window"):color(0.7, 0.75, 0.8)
    mb:quad(2.36, 1.8, 1.0, 2.36, 1.8, -1.0, 2.07, 2.65, -0.98, 2.07, 2.65, 0.98)
    mb:quad(1.25, 1.75, -1.16, 2.1, 1.75, -1.16, 2.0, 2.55, -1.11, 1.25, 2.55, -1.11)
    mb:quad(2.1, 1.75, 1.16, 1.25, 1.75, 1.16, 1.25, 2.55, 1.11, 2.0, 2.55, 1.11)
    -- mirrors
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:box(2.25, 1.9, -1.45, 2.3, 2.3, -1.3)
    mb:box(2.25, 1.9, 1.3, 2.3, 2.3, 1.45)
    -- cargo bed
    mb:material(burned and "rust" or "wood"):color(0.6, 0.52, 0.42)
    mb:box(-3.4, 0.8, -1.25, 0.9, 0.95, 1.25)
    for _, sd in ipairs({ -1, 1 }) do
        for k = 0, 2 do mb:box(-3.4, 1.0 + k * 0.28, sd * 1.25 - 0.04, 0.9, 1.2 + k * 0.28, sd * 1.25 + 0.04) end
    end
    mb:box(-3.45, 0.95, -1.25, -3.35, 1.85, 1.25)
    mb:box(0.82, 0.95, -1.25, 0.92, 2.0, 1.25)
    if not burned then
        -- canvas cover on ribs
        mb:material("cloth"):color(0.45, 0.5, 0.36)
        local prev
        for k = 0, 6 do
            local a = k / 6 * math.pi
            local zz, yy = -math.cos(a) * 1.25, 1.85 + math.sin(a) * 0.65
            if prev then
                mb:quadN(-3.4, prev[2], prev[1], 0.9, prev[2], prev[1], 0.9, yy, zz, -3.4, yy, zz, 0, 1, 0)
            end
            prev = { zz, yy }
        end
        mb:box(-3.4, 1.85, -1.27, 0.9, 1.9, -1.2)
        mb:box(-3.4, 1.85, 1.2, 0.9, 1.9, 1.27)
        mb:material("snow"):color(0.95, 0.97, 1)
        mb:box(-3.2, 2.45, -0.5, 0.7, 2.55, 0.5)
    end
    -- side fuel tank & spare wheel
    mb:material("metal"):color(0.35, 0.38, 0.32)
    mb:cylinderX(-0.2, 0.6, 0.75, -1.05, 0.22, 0.22, 7)
    wheel(mb, 0.4, 1.35, -1.32, 0.42, 0.25, -1, burned)
    -- wheels: single front, dual rear
    for _, sd in ipairs({ -1, 1 }) do
        wheel(mb, 3.3, 0.52, sd * 1.0, 0.52, 0.32, sd, burned)
        wheel(mb, -1.2, 0.52, sd * 0.95, 0.52, 0.3, sd, burned)
        wheel(mb, -2.6, 0.52, sd * 0.95, 0.52, 0.3, sd, burned)
    end
    mb:material("snow"):color(0.95, 0.97, 1)
    mb:box(1.1, 2.75, -1.0, 2.0, 2.82, 1.0)
    mb:box(2.4, 1.72, -0.7, 3.6, 1.76, 0.7)
    ctx:collider(-3.45, 0, -1.3, 4.2, 2.7, 1.3)
    mb:pop()
end

-- Soviet sedan (Lada / Moskvich style)
function Props.car(ctx, x, z, rot, paint)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    local col = paint or PAINTS[(math.floor(math.abs(x * 7 + z * 3)) % #PAINTS) + 1]
    local pr, pg, pb = col[1], col[2], col[3]
    -- lower body with tapered nose and tail
    mb:material("metal"):color(pr * 1.6, pg * 1.6, pb * 1.6)
    mb:hexa({ { -2.15, 0.32, -0.8 }, { 2.15, 0.32, -0.8 }, { 2.15, 0.32, 0.8 }, { -2.15, 0.32, 0.8 },
              { -2.1, 0.92, -0.82 }, { 2.1, 0.88, -0.82 }, { 2.1, 0.88, 0.82 }, { -2.1, 0.92, 0.82 } })
    -- hood / trunk tops slightly lower
    mb:hexa({ { 0.8, 0.88, -0.78 }, { 2.1, 0.86, -0.78 }, { 2.1, 0.86, 0.78 }, { 0.8, 0.88, 0.78 },
              { 0.8, 0.98, -0.76 }, { 2.05, 0.93, -0.74 }, { 2.05, 0.93, 0.74 }, { 0.8, 0.98, 0.76 } })
    -- greenhouse: sloped windshield & rear window
    mb:hexa({ { -1.35, 0.92, -0.78 }, { 0.85, 0.92, -0.78 }, { 0.85, 0.92, 0.78 }, { -1.35, 0.92, 0.78 },
              { -0.95, 1.45, -0.68 }, { 0.25, 1.45, -0.68 }, { 0.25, 1.45, 0.68 }, { -0.95, 1.45, 0.68 } })
    mb:material("window"):color(0.65, 0.72, 0.8)
    mb:quad(0.86, 0.95, 0.72, 0.86, 0.95, -0.72, 0.27, 1.42, -0.64, 0.27, 1.42, 0.64)
    mb:quad(-1.36, 0.95, -0.72, -1.36, 0.95, 0.72, -0.97, 1.42, 0.64, -0.97, 1.42, -0.64)
    for _, sd in ipairs({ -1, 1 }) do
        local zz = sd * 0.785
        if sd < 0 then mb:quad(-1.15, 0.97, zz, 0.7, 0.97, zz, 0.2, 1.4, zz + 0.09, -0.85, 1.4, zz + 0.09)
        else mb:quad(0.7, 0.97, zz, -1.15, 0.97, zz, -0.85, 1.4, zz - 0.09, 0.2, 1.4, zz - 0.09) end
    end
    -- bumpers, lights, rust
    mb:material("steel"):color(0.8, 0.8, 0.8)
    mb:box(2.1, 0.38, -0.85, 2.25, 0.5, 0.85)
    mb:box(-2.25, 0.38, -0.85, -2.1, 0.5, 0.85)
    mb:material("white"):color(0.9, 0.9, 0.75)
    mb:cylinderX(2.1, 2.16, 0.72, -0.6, 0.09, 0.09, 7)
    mb:cylinderX(2.1, 2.16, 0.72, 0.6, 0.09, 0.09, 7)
    mb:material("cloth_red"):color(1, 0.6, 0.6)
    mb:box(-2.13, 0.65, -0.75, -2.1, 0.78, -0.5)
    mb:box(-2.13, 0.65, 0.5, -2.1, 0.78, 0.75)
    mb:material("rust"):color(0.7, 0.5, 0.4)
    mb:quad(-1.6, 0.35, 0.805, -0.6, 0.35, 0.805, -0.7, 0.6, 0.805, -1.5, 0.55, 0.805)
    mb:quad(1.6, 0.35, -0.805, 0.8, 0.35, -0.805, 0.9, 0.55, -0.805, 1.5, 0.62, -0.805)
    -- wheels in dark arches
    mb:material("metal"):color(0.12, 0.12, 0.12)
    for _, wx in ipairs({ 1.35, -1.35 }) do
        mb:box(wx - 0.42, 0.3, -0.81, wx + 0.42, 0.72, -0.79)
        mb:box(wx - 0.42, 0.3, 0.79, wx + 0.42, 0.72, 0.81)
    end
    for _, wx in ipairs({ 1.35, -1.35 }) do
        wheel(mb, wx, 0.32, -0.72, 0.32, 0.2, -1, false)
        wheel(mb, wx, 0.32, 0.72, 0.32, 0.2, 1, false)
    end
    mb:material("snow"):color(0.95, 0.97, 1)
    mb:box(-0.9, 1.45, -0.62, 0.2, 1.52, 0.62)
    mb:box(1.0, 0.97, -0.6, 1.9, 1.0, 0.6)
    ctx:collider(-2.2, 0, -0.85, 2.2, 1.45, 0.85)
    mb:pop()
end

-- knocked-out Soviet medium tank
function Props.tankWreck(ctx, x, z, rot, turretOff)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    mb.maxEdge = 1.2
    mb:material("rust"):color(0.55, 0.5, 0.46)
    mb:hexa({ { -3.0, 0.45, -1.35 }, { 2.4, 0.45, -1.35 }, { 2.4, 0.45, 1.35 }, { -3.0, 0.45, 1.35 },
              { -2.9, 1.65, -1.5 }, { 1.4, 1.65, -1.5 }, { 1.4, 1.65, 1.5 }, { -2.9, 1.65, 1.5 } })
    mb:hexa({ { 2.4, 0.45, -1.35 }, { 3.1, 0.9, -1.35 }, { 3.1, 0.9, 1.35 }, { 2.4, 0.45, 1.35 },
              { 1.4, 1.65, -1.5 }, { 1.45, 1.65, -1.5 }, { 1.45, 1.65, 1.5 }, { 1.4, 1.65, 1.5 } })
    mb.maxEdge = nil
    mb:material("tread"):color(0.4, 0.37, 0.35)
    for _, sd in ipairs({ -1, 1 }) do
        local z0, z1 = sd * 1.35, sd * 1.62
        if sd < 0 then z0, z1 = z1, z0 end
        mb:box(-3.2, 0.0, z0, 3.1, 0.12, z1)
        if sd > 0 then mb:box(-3.2, 1.05, z0, 3.1, 1.15, z1) end
        mb:material("rust"):color(0.45, 0.4, 0.37)
        for i = 0, 4 do mb:cylinderZ(z0 + 0.03, z1 - 0.03, -2.4 + i * 1.2, 0.55, 0.52, 9) end
        mb:material("tread"):color(0.4, 0.37, 0.35)
    end
    -- thrown track lying beside the hull
    mb:box(-3.0, 0.0, -2.6, 2.5, 0.08, -2.05)
    mb:material("rust"):color(0.32, 0.27, 0.24)
    mb:quad(1.0, 1.66, -0.4, 1.4, 1.66, -0.4, 1.4, 1.66, 0.2, 1.0, 1.66, 0.2)
    if not turretOff then
        mb:material("rust"):color(0.5, 0.45, 0.42)
        mb:push() mb:translate(-0.2, 1.65, 0) mb:rotateY(0.6)
        mb:cylinder(0, 0, 0, 1.35, 0.85, 1.05, 10)
        mb:cylinder(-0.4, 0.85, -0.5, 0.35, 1.05, 0.33, 8)
        mb:cylinderX(1.1, 4.6, 0.45, 0, 0.1, 0.085, 7)
        mb:pop()
    else
        mb:material("rust"):color(0.5, 0.45, 0.42)
        mb:push() mb:translate(3.8, 0.5, 2.6) mb:rotateZ(2.5) mb:rotateY(0.4)
        mb:cylinder(0, 0, 0, 1.35, 0.85, 1.05, 10)
        mb:cylinderX(1.0, 3.6, 0.45, 0, 0.1, 0.085, 7)
        mb:pop()
        mb:material("metal"):color(0.15, 0.13, 0.12)
        mb:cylinder(-0.2, 1.64, 0, 1.0, 1.66, 1.0, 10)
    end
    mb:material("snow"):color(0.95, 0.97, 1)
    mb:box(-2.8, 1.65, -1.3, -1.5, 1.72, 1.3)
    mb:box(1.42, 1.0, -1.2, 2.6, 1.05, 1.2)
    ctx:collider(-3.2, 0, -1.65, 3.1, 1.8, 1.65)
    mb:pop()
end

-- buildings -----------------------------------------------------------------
-- small rural house; door on -z side. returns interior info
function Props.house(ctx, w, d, opts, rng)
    opts = opts or {}
    local mb = ctx.mb
    local h = opts.h or 2.9
    local x0, x1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2
    local ruined = opts.ruined
    local wallMat = opts.mat or (rng:next() > 0.5 and "plaster" or "wood")
    local tint = { rng:range(0.75, 0.95), rng:range(0.7, 0.9), rng:range(0.65, 0.85) }
    -- foundation/floor
    ctx:flatten(x0, z0, x1, z1, 0.25)
    ctx:mat("concrete", 0.6, 0.6, 0.6)
    ctx:solid(x0 - 0.2, -1.5, z0 - 0.2, x1 + 0.2, 0.25, z1 + 0.2)
    ctx:mat("wood", 0.6, 0.55, 0.5)
    mb:box(x0, 0.25, z0, x1, 0.28, z1, { bottom = false })
    ctx:mat(wallMat, tint[1], tint[2], tint[3])
    local top = 0.25 + h
    local function wh() return ruined and top - rng:range(0.5, h * 0.8) or top end
    local door = { w * (opts.doorAt or 0.5), 1.1, 0, 2.2 }
    Props.wall(ctx, x0, z0, x1, z0, 0.25, wh(), 0.24, { door, { w * 0.18, 1.0, 1.0, 2.0 }, { w * 0.82, 1.0, 1.0, 2.0 } })
    ctx:mat(wallMat, tint[1], tint[2], tint[3])
    Props.wall(ctx, x0, z1, x1, z1, 0.25, wh(), 0.24, { { w * 0.3, 1.0, 1.0, 2.0 }, { w * 0.7, 1.0, 1.0, 2.0 } })
    ctx:mat(wallMat, tint[1], tint[2], tint[3])
    Props.wall(ctx, x0, z0, x0, z1, 0.25, wh(), 0.24, { { d * 0.5, 1.0, 1.0, 2.0 } })
    ctx:mat(wallMat, tint[1], tint[2], tint[3])
    Props.wall(ctx, x1, z0, x1, z1, 0.25, wh(), 0.24, { { d * 0.5, 1.0, 1.0, 2.0 } })
    -- window frames / shutters
    ctx:mat("wood", 0.45, 0.55, 0.6)
    for _, fx in ipairs({ w * 0.18, w * 0.82 }) do
        mb:box(x0 + fx - 0.65, 1.2, z0 - 0.16, x0 + fx - 0.5, 2.3, z0 - 0.12)
        mb:box(x0 + fx + 0.5, 1.2, z0 - 0.16, x0 + fx + 0.65, 2.3, z0 - 0.12)
    end
    if not ruined then
        Props.gableRoof(ctx, x0 - 0.12, z0 - 0.12, x1 + 0.12, z1 + 0.12, top, 1.6, 0.5, "roof")
        ctx:mat("wood", 0.5, 0.45, 0.4)
        mb:box(x0, top - 0.05, z0, x1, top, z1, { top = false }) -- ceiling
        -- chimney
        ctx:mat("brick", 0.8, 0.7, 0.65)
        mb:box(x1 - 1.4, top, z1 - 1.6, x1 - 0.9, top + 2.3, z1 - 1.1)
        local wx0, wy0, wz0 = ctx:worldBox(x0, 0, z0, x1, top, z1)
        local wa, wb, wc, wd, we, wf = ctx:worldBox(x0, 0, z0, x1, top, z1)
        local entry = { wa, wb, wc, wd, we, wf }
        world().shelters[#world().shelters + 1] = entry
        if ctx.obj then ctx.obj.shelter = entry end
    else
        -- rubble inside
        ctx:mat("rubble", 0.8, 0.8, 0.8)
        for k = 1, 3 do
            local rx, rz = rng:range(x0 + 1, x1 - 1), rng:range(z0 + 1, z1 - 1)
            mb:push() mb:translate(rx, 0.2, rz) mb:rotateY(rng:range(0, 3))
            mb:sphere(0, 0, 0, rng:range(0.6, 1.2), 0.5, 0.8, 5, 3)
            mb:pop()
        end
        -- fallen roof beams
        ctx:mat("wood", 0.35, 0.3, 0.28)
        ctx:beam(x0 + 0.5, 0.3, z0 + 1, x1 - 0.5, 2.2, z1 - 1, 0.18)
    end
    -- furniture
    if not opts.empty then
        Props.table(ctx, x0 + w * 0.65, z0 + d * 0.6, 0)
        if rng:next() > 0.4 then Props.bed(ctx, x0 + 1.3, z1 - 0.8, 0) end
        if not ruined then Props.stove(ctx, x1 - 1.15, z1 - 1.35) end
        Props.shelf(ctx, x0 + 0.4, z0 + d * 0.3, pi / 2, 1.4)
    end
    return { top = top, x0 = x0, x1 = x1, z0 = z0, z1 = z1 }
end

-- Khrushchyovka apartment block (solid shell with window grid, optionally damaged)
function Props.apartment(ctx, w, d, floors, rng, damaged)
    local mb = ctx.mb
    local fh = 2.9
    local h = floors * fh
    ctx:mat("concrete", 0.78, 0.76, 0.74)
    ctx:mat("concrete", 0.72, 0.72, 0.7)
    local x0, x1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2
    local cut = damaged and rng:range(0.15, 0.3) * w or 0
    mb:box(x0 + cut, -2, z0, x1, h, z1)
    ctx:collider(x0 + cut, -2, z0, x1, h, z1)
    if damaged then
        -- collapsed end: stepped broken floors
        for f = 0, floors - 1 do
            local hh = (f + 1) * fh
            local lost = rng:range(0.2, 1) * cut
            if f < floors - 2 then
                ctx:mat("concrete", 0.6, 0.6, 0.6)
                mb:box(x0 + lost, f * fh - 2 * (f == 0 and 1 or 0), z0 + 0.5, x0 + cut, f * fh + 0.25, z1 - 0.5)
                ctx:collider(x0 + lost, f * fh - 2 * (f == 0 and 1 or 0), z0 + 0.5, x0 + cut, f * fh + 0.25, z1 - 0.5)
            end
        end
        ctx:mat("rubble", 0.85, 0.85, 0.85)
        mb:push() mb:translate(x0 + cut * 0.4, 0, 0) mb:sphere(0, 0, 0, cut * 0.8, 2.5, d * 0.6, 6, 4) mb:pop()
        ctx:collider(x0 - cut * 0.3, -1, z0, x0 + cut, 1.5, z1)
    end
    -- windows grid
    for f = 0, floors - 1 do
        local y = f * fh + 1.0
        local nx = math.floor((w - cut) / 3.2)
        for i = 0, nx - 1 do
            local x = x0 + cut + 1.6 + i * 3.2
            if rng:next() > 0.06 then
                Props.window(ctx, x, y, z0, 1.4, 1.4, "z-")
                Props.window(ctx, x, y, z1, 1.4, 1.4, "z+")
            end
        end
    end
    ctx:mat("snow", 0.95, 0.97, 1)
    mb:box(x0 + cut, h, z0, x1, h + 0.2, z1)
    -- entrance canopies
    ctx:mat("concrete", 0.6, 0.6, 0.6)
    for i = 1, 3 do
        local ex = x0 + cut + (w - cut) * i / 4
        mb:box(ex - 1, 2.4, z0 - 1.2, ex + 1, 2.6, z0)
        ctx:mat("window", 0.5, 0.5, 0.5)
        mb:quad(ex - 0.6, 0, z0 - 0.02, ex - 0.6, 2.2, z0 - 0.02, ex + 0.6, 2.2, z0 - 0.02, ex + 0.6, 0, z0 - 0.02)
        ctx:mat("concrete", 0.6, 0.6, 0.6)
    end
end

-- Orthodox church with onion domes (solid)
function Props.church(ctx, rng)
    local mb = ctx.mb
    ctx:mat("plaster", 0.82, 0.8, 0.78)
    ctx:solid(-7, -1, -5, 7, 9, 5)
    ctx:solid(-11, -1, -3.5, -7, 6.5, 3.5)
    ctx:mat("roof", 0.8, 0.8, 0.85)
    Props.gableRoof(ctx, -7, -5, 7, 5, 9, 3, 0.3, "roof")
    ctx:mat("plaster", 0.82, 0.8, 0.78)
    mb:cylinder(0, 9, 0, 3, 15, 3, 8)
    ctx:mat("metal", 0.35, 0.4, 0.38)
    mb:sphere(0, 17.2, 0, 3.4, 3.4, 3.4, 8, 6)
    mb:cylinder(0, 20.2, 0, 0.6, 23, 0, 6)
    ctx:mat("rust", 0.7, 0.6, 0.4)
    ctx:beam(0, 23, 0, 0, 25.5, 0, 0.12)
    ctx:beam(0, 24.6, -0.7, 0, 24.6, 0.7, 0.1)
    -- bell tower
    ctx:mat("plaster", 0.82, 0.8, 0.78)
    ctx:solid(10, -1, -2.5, 15, 14, 2.5)
    ctx:mat("window", 0.6, 0.6, 0.6)
    mb:quad(9.98, 10, 1, 9.98, 13, 1, 9.98, 13, -1, 9.98, 10, -1)
    ctx:mat("metal", 0.35, 0.4, 0.38)
    mb:sphere(12.5, 15.6, 0, 1.9, 2.0, 1.9, 7, 5)
    mb:cylinder(12.5, 17.3, 0, 0.35, 19.5, 0, 6)
    ctx:mat("plaster", 0.82, 0.8, 0.78)
    mb:cylinder(-9, 6.5, 0, 2, 9, 2, 8)
    ctx:mat("metal", 0.35, 0.4, 0.38)
    mb:sphere(-9, 10, 0, 2.1, 2.1, 2.1, 7, 5)
    ctx:mat("window", 0.7, 0.7, 0.7)
    for i = -1, 1 do
        Props.window(ctx, i * 3.5, 3, -5, 1.2, 2.6, "z-")
        Props.window(ctx, i * 3.5, 3, 5, 1.2, 2.6, "z+")
    end
    ctx:mat("wood", 0.4, 0.35, 0.3)
    mb:box(-1, 0, -5.12, 1, 3, -5.0)
end

-- large enterable shed (factory hall / warehouse / hangar style). door openings on both ends (x)
function Props.hall(ctx, w, d, h, rng, opts)
    opts = opts or {}
    local mb = ctx.mb
    local x0, x1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2
    local wallMat = opts.mat or "metal"
    ctx:flatten(x0, z0, x1, z1, 0.1)
    ctx:mat("concrete", 0.55, 0.55, 0.55)
    ctx:solid(x0, -1.5, z0, x1, 0.1, z1)
    local doorW = opts.doorW or 7
    ctx:mat(wallMat, 0.75, 0.72, 0.68)
    Props.wall(ctx, x0, z0, x0, z1, 0.1, h, 0.4, { { d / 2, doorW, 0, 6 } })
    ctx:mat(wallMat, 0.75, 0.72, 0.68)
    Props.wall(ctx, x1, z0, x1, z1, 0.1, h, 0.4, opts.closedEnd and {} or { { d / 2, doorW, 0, 6 } })
    ctx:mat(wallMat, 0.75, 0.72, 0.68)
    local ow = {}
    for i = 1, math.floor(w / 8) do ow[#ow + 1] = { i * 8 - 2, 3, h - 4, h - 1.2 } end
    if opts.sideDoor then ow[#ow + 1] = { w * 0.3, 2.0, 0, 2.4 } end
    Props.wall(ctx, x0, z0, x1, z0, 0.1, h, 0.4, ow)
    ctx:mat(wallMat, 0.75, 0.72, 0.68)
    Props.wall(ctx, x0, z1, x1, z1, 0.1, h, 0.4, ow)
    -- roof panels with holes
    for i = 0, math.floor(w / 6) - 1 do
        local a, b = x0 + i * 6, math.min(x1, x0 + (i + 1) * 6)
        if rng:next() > (opts.holes or 0.2) then
            ctx:mat("roof", 0.8, 0.8, 0.85)
            mb:hexa({ { a, h, z0 - 0.3 }, { b, h, z0 - 0.3 }, { b, h + 2.5, 0 }, { a, h + 2.5, 0 },
                      { a, h + 0.15, z0 - 0.3 }, { b, h + 0.15, z0 - 0.3 }, { b, h + 2.65, 0 }, { a, h + 2.65, 0 } })
        end
        if rng:next() > (opts.holes or 0.2) then
            ctx:mat("roof", 0.8, 0.8, 0.85)
            mb:hexa({ { a, h + 2.5, 0 }, { b, h + 2.5, 0 }, { b, h, z1 + 0.3 }, { a, h, z1 + 0.3 },
                      { a, h + 2.65, 0 }, { b, h + 2.65, 0 }, { b, h + 0.15, z1 + 0.3 }, { a, h + 0.15, z1 + 0.3 } })
        end
        -- truss
        ctx:mat("rust", 0.5, 0.45, 0.4)
        ctx:beam(a, h - 0.2, z0, a, h - 0.2, z1, 0.2)
        ctx:beam(a, h - 0.2, z0, a, h + 2.3, 0, 0.15)
        ctx:beam(a, h + 2.3, 0, a, h - 0.2, z1, 0.15)
    end
    -- columns
    ctx:mat("concrete", 0.6, 0.6, 0.6)
    for i = 1, math.floor(w / 12) do
        local cx = x0 + i * 12
        if cx < x1 - 2 then
            ctx:solid(cx - 0.3, 0, z0 + d * 0.3 - 0.3, cx + 0.3, h, z0 + d * 0.3 + 0.3)
            ctx:solid(cx - 0.3, 0, z1 - d * 0.3 - 0.3, cx + 0.3, h, z1 - d * 0.3 + 0.3)
        end
    end
    local wa, wb, wc, wd, we, wf = ctx:worldBox(x0, 0, z0, x1, h, z1)
    world().shelters[#world().shelters + 1] = { wa, wb, wc, wd, we, wf }
end

-- quonset hangar (arched roof)
function Props.hangar(ctx, w, d, rng)
    local mb = ctx.mb
    local r = d / 2
    ctx:flatten(-w / 2, -r, w / 2, r, 0.1)
    ctx:mat("concrete", 0.55, 0.55, 0.55)
    ctx:solid(-w / 2, -1.5, -r, w / 2, 0.1, r)
    local seg = 8
    for i = 0, seg - 1 do
        local a0, a1 = i / seg * pi, (i + 1) / seg * pi
        local z0, y0 = -math.cos(a0) * r, math.sin(a0) * r * 0.75
        local z1, y1 = -math.cos(a1) * r, math.sin(a1) * r * 0.75
        ctx:mat(i % 2 == 0 and "metal" or "rust", 0.7, 0.72, 0.7)
        local t = 0.15
        mb:hexa({ { -w / 2, y0, z0 }, { w / 2, y0, z0 }, { w / 2, y1, z1 }, { -w / 2, y1, z1 },
                  { -w / 2, y0 + t, z0 * 1.01 }, { w / 2, y0 + t, z0 * 1.01 }, { w / 2, y1 + t, z1 * 1.01 }, { -w / 2, y1 + t, z1 * 1.01 } })
        -- snow on upper segments
        if i >= 2 and i <= 5 then
            ctx:mat("snow", 1, 1, 1)
            mb:quad(-w / 2, y0 + t + 0.05, z0, -w / 2, y1 + t + 0.05, z1, w / 2, y1 + t + 0.05, z1, w / 2, y0 + t + 0.05, z0)
        end
        -- side colliders
        local zz = math.min(z0, z1)
        ctx:collider(-w / 2, 0, zz - 0.3, w / 2, math.max(y0, y1), zz + 0.3, { noRay = (i > 0 and i < seg - 1) })
        ctx:collider(-w / 2, 0, -zz - 0.3, w / 2, math.max(y0, y1), -zz + 0.3, { noRay = (i > 0 and i < seg - 1) })
    end
    -- closed back wall
    ctx:mat("metal", 0.6, 0.6, 0.6)
    local pts = {}
    for i = 0, seg do
        local a = i / seg * pi
        pts[#pts + 1] = { -math.cos(a) * r, math.sin(a) * r * 0.75 }
    end
    for i = 1, seg do
        local p, q = pts[i], pts[i + 1]
        mb:tri(-w / 2, 0, 0, 0, 0, -w / 2, p[2], p[1], 0, 1, -w / 2, q[2], q[1], 1, 1)
        mb:tri(-w / 2, 0, 0, 0, 0, -w / 2, q[2], q[1], 1, 1, -w / 2, p[2], p[1], 0, 1)
    end
    ctx:collider(-w / 2 - 0.3, 0, -r, -w / 2, r * 0.75, r)
    local wa, wb, wc, wd, we, wf = ctx:worldBox(-w / 2, 0, -r, w / 2, r * 0.75, r)
    world().shelters[#world().shelters + 1] = { wa, wb, wc, wd, we, wf }
end

function Props.watchtower(ctx, x, z)
    local mb = ctx.mb
    ctx:mat("wood", 0.55, 0.5, 0.45)
    local h = 6
    for _, p in ipairs({ { -1.2, -1.2 }, { 1.2, -1.2 }, { 1.2, 1.2 }, { -1.2, 1.2 } }) do
        ctx:beam(x + p[1] * 1.3, 0, z + p[2] * 1.3, x + p[1], h, z + p[2], 0.2)
    end
    ctx:beam(x - 1.4, 2.5, z - 1.4, x + 1.4, 4.5, z - 1.4, 0.12)
    ctx:beam(x - 1.4, 2.5, z + 1.4, x + 1.4, 4.5, z + 1.4, 0.12)
    mb:box(x - 1.5, h, z - 1.5, x + 1.5, h + 0.2, z + 1.5)
    mb:box(x - 1.5, h + 0.2, z - 1.5, x + 1.5, h + 1.1, z - 1.4)
    mb:box(x - 1.5, h + 0.2, z + 1.4, x + 1.5, h + 1.1, z + 1.5)
    mb:box(x - 1.5, h + 0.2, z - 1.5, x - 1.4, h + 1.1, z + 1.5)
    mb:box(x + 1.4, h + 0.2, z - 1.5, x + 1.5, h + 1.1, z + 1.5)
    for _, p in ipairs({ { -1.45, -1.45 }, { 1.45, -1.45 }, { 1.45, 1.45 }, { -1.45, 1.45 } }) do
        mb:box(x + p[1] - 0.06, h, z + p[2] - 0.06, x + p[1] + 0.06, h + 2.4, z + p[2] + 0.06)
    end
    ctx:mat("roof", 0.8, 0.8, 0.8)
    mb:hexa({ { x - 1.8, h + 2.4, z - 1.8 }, { x + 1.8, h + 2.4, z - 1.8 }, { x + 1.8, h + 2.4, z + 1.8 }, { x - 1.8, h + 2.4, z + 1.8 },
              { x - 0.1, h + 3.3, z - 0.1 }, { x + 0.1, h + 3.3, z - 0.1 }, { x + 0.1, h + 3.3, z + 0.1 }, { x - 0.1, h + 3.3, z + 0.1 } })
    ctx:collider(x - 1.6, 0, z - 1.6, x + 1.6, h + 3, z + 1.6, { noPlayer = true })
    ctx:collider(x - 1.4, 0, z - 1.4, x + 1.4, h, z + 1.4)
end

function Props.chimney(ctx, x, z, h, r)
    local mb = ctx.mb
    ctx:mat("brick", 0.8, 0.7, 0.65)
    mb:cylinder(x, -1, z, r, h, r * 0.6, 8, false)
    ctx:mat("plaster", 0.85, 0.3, 0.25)
    mb:cylinder(x, h - 8, z, r * 0.66, h - 5, r * 0.63, 8, false)
    ctx:mat("plaster", 0.9, 0.9, 0.88)
    mb:cylinder(x, h - 5, z, r * 0.63, h - 2.5, r * 0.61, 8, false)
    ctx:collider(x - r, -1, z - r, x + r, h, z + r)
end

function Props.fuelTank(ctx, x, z, rot, l, r)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot or 0)
    ctx:mat("metal", 0.7, 0.75, 0.68)
    mb:cylinderX(-l / 2, l / 2, r + 0.6, 0, r, r, 9)
    ctx:mat("concrete", 0.6, 0.6, 0.6)
    mb:box(-l / 2 + 0.5, 0, -r * 0.7, -l / 2 + 1.0, r + 0.2, r * 0.7)
    mb:box(l / 2 - 1.0, 0, -r * 0.7, l / 2 - 0.5, r + 0.2, r * 0.7)
    ctx:mat("snow", 1, 1, 1)
    mb:box(-l / 2, 2 * r + 0.55, -r * 0.5, l / 2, 2 * r + 0.65, r * 0.5)
    ctx:collider(-l / 2, 0, -r, l / 2, 2 * r + 0.6, r)
    mb:pop()
end

-- lattice radio mast (landmark builder)
function Props.radioMast(ctx, h, base)
    local mb = ctx.mb
    local legs = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
    local function wAt(y) return base * (1 - y / h) + 0.5 * (y / h) end
    for i, l in ipairs(legs) do
        ctx:mat(i % 2 == 0 and "plaster" or "rust", 0.85, 0.35, 0.3)
        local steps = 8
        for k = 0, steps - 1 do
            local ya, yb = h * k / steps, h * (k + 1) / steps
            ctx:mat(k % 2 == 0 and "cloth_red" or "plaster", 1, 1, 1)
            ctx:beam(l[1] * wAt(ya), ya, l[2] * wAt(ya), l[1] * wAt(yb), yb, l[2] * wAt(yb), 0.35)
        end
    end
    ctx:mat("rust", 0.6, 0.5, 0.45)
    local y = 0
    local k = 0
    while y < h - 4 do
        local y2 = y + 5
        for i = 1, 4 do
            local a, b = legs[i], legs[i % 4 + 1]
            local wa, wb = wAt(y), wAt(y2)
            ctx:beam(a[1] * wb, y2, a[2] * wb, b[1] * wb, y2, b[2] * wb, 0.12)
            if k % 2 == 0 then ctx:beam(a[1] * wa, y, a[2] * wa, b[1] * wb, y2, b[2] * wb, 0.1)
            else ctx:beam(b[1] * wa, y, b[2] * wa, a[1] * wb, y2, a[2] * wb, 0.1) end
        end
        y = y2
        k = k + 1
    end
    -- antennas & dishes at top
    ctx:mat("metal", 0.6, 0.6, 0.6)
    ctx:beam(0, h - 2, 0, 0, h + 8, 0, 0.2)
    mb:push() mb:translate(0.8, h - 8, 0.8) mb:rotateY(0.7)
    mb:cylinderX(0, 0.4, 0, 0, 1.6, 0.2, 8)
    mb:pop()
    ctx:mat("concrete", 0.6, 0.6, 0.6)
    for _, l in ipairs(legs) do ctx:solid(l[1] * base - 0.8, -1, l[2] * base - 0.8, l[1] * base + 0.8, 0.6, l[2] * base + 0.8) end
end

-- hyperboloid cooling tower (landmark)
function Props.coolingTower(ctx, h, rBase, rWaist, rTop)
    local mb = ctx.mb
    local seg = 14
    local rings = 7
    local function rad(t)
        local waistT = 0.72
        if t < waistT then return U.lerp(rBase, rWaist, 1 - (1 - t / waistT) ^ 2)
        else return U.lerp(rWaist, rTop, ((t - waistT) / (1 - waistT)) ^ 2) end
    end
    for k = 0, rings - 1 do
        local t0, t1 = k / rings, (k + 1) / rings
        local stain = k < 2 and 0.62 or 0.78
        ctx:mat("concrete", stain, stain, stain * 0.98)
        mb:cylinder(0, t0 * h, 0, rad(t0), t1 * h, rad(t1), seg, false)
        -- inner surface
        mb:push()
        local r0, r1 = rad(t0) - 0.6, rad(t1) - 0.6
        for i = 0, seg - 1 do
            local a0, a1 = i / seg * 2 * pi, (i + 1) / seg * 2 * pi
            mb:quad(math.cos(a1) * r0, t0 * h, math.sin(a1) * r0, math.cos(a1) * r1, t1 * h, math.sin(a1) * r1,
                    math.cos(a0) * r1, t1 * h, math.sin(a0) * r1, math.cos(a0) * r0, t0 * h, math.sin(a0) * r0)
        end
        mb:pop()
    end
    -- support legs at bottom (open ring)
    for i = 0, seg - 1 do
        local a = i / seg * 2 * pi
        ctx:collider(math.cos(a) * rBase - 1.5, -1, math.sin(a) * rBase - 1.5, math.cos(a) * rBase + 1.5, h * 0.3, math.sin(a) * rBase + 1.5)
    end
end

return Props
