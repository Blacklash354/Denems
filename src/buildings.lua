-- Enterable Soviet buildings: prefab panel blocks (khrushchyovka) with stairwells, landings and
-- apartments on every floor, garage cooperatives, shops and small single-storey buildings.
-- All geometry is axis-aligned in the building's local frame (place them at 90 degree steps
-- so the box colliders fit exactly).
local U = require("src.utils")
local Props = require("src.props")

local B = {}
local pi = math.pi
local function world() return require("src.world") end

local FACES = { "top", "bottom", "front", "back", "right", "left" }   -- front +x, back -x, right +z, left -z

-- box with its own material per face. mats.default plus optional per-face entries {mat, r, g, b};
-- false hides a face. Returns the collider unless collide == false.
function B.mbox(ctx, x0, y0, z0, x1, y1, z1, mats, collide, props)
    if x1 - x0 < 0.01 or y1 - y0 < 0.01 or z1 - z0 < 0.01 then return end
    local groups, order = {}, {}
    for _, f in ipairs(FACES) do
        local m = mats[f]
        if m == nil then m = mats.default end
        if m then
            if not groups[m] then groups[m] = {} order[#order + 1] = m end
            groups[m][f] = true
        end
    end
    for _, m in ipairs(order) do
        local set, faces = groups[m], {}
        for _, f in ipairs(FACES) do faces[f] = set[f] or false end
        ctx:mat(m[1], m[2], m[3], m[4])
        ctx.mb:box(x0, y0, z0, x1, y1, z1, faces)
    end
    if collide ~= false then return ctx:collider(x0, y0, z0, x1, y1, z1, props) end
end

-- wall along local x (z0 == z1) or along local z (x0 == x1) with openings { at, width, bottom, top }.
-- sideA / sideB: materials of the -z / +z faces (along x) or the -x / +x faces (along z); edge: reveals.
function B.wall(ctx, x0, z0, x1, z1, y0, y1, thick, openings, sideA, sideB, edge, props)
    local alongX = math.abs(z1 - z0) < 1e-6
    local len = alongX and (x1 - x0) or (z1 - z0)
    local t = thick / 2
    local mats
    if alongX then mats = { default = edge, left = sideA, right = sideB }
    else mats = { default = edge, back = sideA, front = sideB } end
    local function seg(a, b, ya, yb)
        if b - a < 0.02 or yb - ya < 0.02 then return end
        if alongX then B.mbox(ctx, x0 + a, ya, z0 - t, x0 + b, yb, z0 + t, mats, true, props)
        else B.mbox(ctx, x0 - t, ya, z0 + a, x0 + t, yb, z0 + b, mats, true, props) end
    end
    openings = openings or {}
    table.sort(openings, function(p, q) return p[1] < q[1] end)
    local cur = 0
    for _, o in ipairs(openings) do
        local a, b = math.max(cur, o[1] - o[2] / 2), o[1] + o[2] / 2
        seg(cur, a, y0, y1)
        seg(a, b, y0, y0 + (o[3] or 0))
        seg(a, b, y0 + (o[4] or 2.1), y1)
        cur = b
    end
    seg(cur, len, y0, y1)
end

local function M(name, r, g, b) return { name, r or 1, g or 1, b or 1 } end
B.M = M

local function shelter(ctx, x0, y0, z0, x1, y1, z1)
    local a, b, c, d, e, f = ctx:worldBox(x0, y0, z0, x1, y1, z1)
    local W = world()
    W.shelters[#W.shelters + 1] = { a, b, c, d, e, f }
end
B.shelter = shelter

---------------------------------------------------------------------------
-- furniture
---------------------------------------------------------------------------
local function wardrobe(ctx, x, z, rot, Gen, kind)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot)
    ctx:mat("wood", 0.55, 0.42, 0.32)
    mb:box(-0.5, 0, -0.28, 0.5, 1.95, 0.28)
    ctx:mat("wood", 0.45, 0.34, 0.26)
    mb:box(-0.48, 0.1, -0.3, -0.01, 1.85, -0.28)
    mb:box(0.01, 0.1, -0.3, 0.48, 1.85, -0.28)
    mb:pop()
    ctx:collider(x - 0.5, 0, z - 0.5, x + 0.5, 1.95, z + 0.5, { walk = false })
    if Gen then
        local lx, lz = x - math.sin(rot) * 0.0 + math.cos(rot - pi / 2) * 0, z
        Gen.container(ctx, x + math.sin(rot) * -0.45, ctx.floorY or 0, z + math.cos(rot) * 0.45, kind or "wardrobe", "WARDROBE")
    end
end

local function sofa(ctx, x, z, rot, col)
    local mb = ctx.mb
    mb:push() mb:translate(x, 0, z) mb:rotateY(rot)
    ctx:mat("cloth", col[1], col[2], col[3])
    mb:box(-0.95, 0, -0.4, 0.95, 0.42, 0.4)
    mb:box(-0.95, 0.42, 0.22, 0.95, 0.9, 0.4)
    mb:box(-0.95, 0.42, -0.4, -0.78, 0.62, 0.22)
    mb:box(0.78, 0.42, -0.4, 0.95, 0.62, 0.22)
    mb:pop()
    ctx:collider(x - 0.95, 0, z - 0.95, x + 0.95, 0.45, z + 0.95)
end

local function kitchenStove(ctx, x, z)
    ctx:mat("steel", 0.85, 0.85, 0.82)
    ctx:solid(x - 0.3, 0, z - 0.3, x + 0.3, 0.85, z + 0.3, { walk = false })
    ctx:mat("metal", 0.25, 0.25, 0.25)
    ctx.mb:box(x - 0.25, 0.86, z - 0.25, x + 0.25, 0.88, z + 0.25)
end

local function rubblePile(ctx, x, y, z, s, rng)
    ctx:mat("rubble", 0.8, 0.8, 0.82)
    local mb = ctx.mb
    for k = 1, 3 do
        mb:push() mb:translate(x + rng:range(-s, s) * 0.5, y, z + rng:range(-s, s) * 0.5) mb:rotateY(rng:range(0, 3))
        mb:sphere(0, 0, 0, s * rng:range(0.5, 0.9), s * 0.45, s * rng:range(0.4, 0.8), 5, 3)
        mb:pop()
    end
end
B.rubblePile = rubblePile

---------------------------------------------------------------------------
-- prefab panel block (khrushchyovka): N sections ("podyezd") x F floors
---------------------------------------------------------------------------
-- local frame: x along the block, z across; front facade (entrances) faces local -z.
-- opts: sections, floors, tint {r,g,b}, collapse = { [section] = floors left }, Gen (world_gen helpers),
--       loot = chance of furnished/looted apartments, doors = chance of apartment doors
local SW, D, FH, G0 = 12, 11, 2.8, 0.35
B.BLOCK_DEPTH, B.SECTION_W = D, SW

function B.panelBlock(ctx, opts, rng)
    opts = opts or {}
    local S, F = opts.sections or 3, opts.floors or 5
    local Gen = opts.Gen
    local L = S * SW
    local tint = opts.tint or { 0.82, 0.8, 0.76 }
    local outer = M("panel", tint[1], tint[2], tint[3])
    local edge = M("concrete", 0.62, 0.62, 0.6)
    local stairWall = M("plaster", 0.52, 0.6, 0.56)     -- the classic green-painted podyezd
    local ceiling = M("plaster", 0.62, 0.62, 0.6)
    local x0, x1, zf, zb = -L / 2, L / 2, -D / 2, D / 2
    local zi0, zi1 = zf + 0.3, zb - 0.3
    local zs = zi0 + 5.2
    ctx:flatten(x0 - 1, zf - 2, x1 + 1, zb + 1, 0)
    -- foundation and plinth
    B.mbox(ctx, x0, -1.2, zf, x1, G0, zb, { default = M("concrete", 0.5, 0.5, 0.5), top = M("tile", 0.55, 0.55, 0.52) })
    local collapse = opts.collapse or {}
    local Wd = world()
    for s = 0, S - 1 do
        local sx = x0 + s * SW
        local xl0, xm, xr1 = sx + 4.5, sx + 6.0, sx + 7.5
        local floors = collapse[s + 1] or F
        local wp = { rng:range(0.85, 1.05), rng:range(0.8, 1.0), rng:range(0.7, 0.95) }
        local paper = M("wallpaper", wp[1], wp[2], wp[3])
        local paper2 = M("wallpaper", wp[3] + 0.1, wp[2], wp[1] - 0.1)
        for f = 0, floors - 1 do
            local fy = G0 + f * FH
            local top = fy + FH - 0.2
            local broken = (f == floors - 1 and floors < F)
            local function wy() return broken and fy + rng:range(0.6, 2.2) or top end
            -- floor slab (not over the stair flights)
            if f > 0 then
                local floorM = { default = edge, top = M("linoleum", 0.85, 0.8, 0.75), bottom = ceiling }
                B.mbox(ctx, sx, fy - 0.2, zf, xl0, fy, zb, floorM)
                B.mbox(ctx, xr1, fy - 0.2, zf, sx + SW, fy, zb, floorM)
                B.mbox(ctx, xl0, fy - 0.2, zf, xr1, fy, zi0 + 1.7, { default = edge, top = M("tile", 0.6, 0.6, 0.58), bottom = ceiling })
                B.mbox(ctx, xl0, fy - 0.2, zs - 0.06, xr1, fy, zb, floorM)
            end
            -- front facade: windows, the entrance on the ground floor, the landing window above
            local fo = {
                { 2.2, 1.5, 0.85, 2.25 },
                f == 0 and { 6.0, 1.3, 0, 2.2 } or { 6.0, 1.0, 1.0, 2.0 },
                { 9.8, 1.5, 0.85, 2.25 },
            }
            local balcony = f > 0 and rng:next() < 0.45 and not broken
            if balcony then fo[3] = { 9.8, 1.6, 0, 2.25 } end
            if rng:next() < 0.08 then fo[1] = { 2.2, 2.6, 0.2, 2.4 } end   -- shell hole
            B.wall(ctx, sx, zf + 0.15, sx + SW, zf + 0.15, fy, broken and wy() or top, 0.3, fo, outer, f == 0 and stairWall or paper, edge)
            if balcony then
                B.mbox(ctx, sx + 8.6, fy - 0.15, zf - 1.1, sx + 11.0, fy + 0.02, zf, { default = edge, top = M("concrete", 0.6, 0.6, 0.6) })
                B.mbox(ctx, sx + 8.6, fy + 0.02, zf - 1.1, sx + 11.0, fy + 1.0, zf - 1.0, { default = M("metal", 0.4, 0.42, 0.4) })
                B.mbox(ctx, sx + 8.6, fy + 0.02, zf - 1.1, sx + 8.66, fy + 1.0, zf, { default = M("metal", 0.4, 0.42, 0.4) })
                B.mbox(ctx, sx + 10.94, fy + 0.02, zf - 1.1, sx + 11.0, fy + 1.0, zf, { default = M("metal", 0.4, 0.42, 0.4) })
            end
            -- back facade
            B.wall(ctx, sx, zb - 0.15, sx + SW, zb - 0.15, fy, broken and wy() or top, 0.3,
                { { 2.2, 1.5, 0.85, 2.25 }, { 6.0, 1.1, 1.0, 2.2 }, { 9.8, 1.5, 0.85, 2.25 } }, paper, outer, edge)
            -- end walls / section walls
            if s == 0 then
                B.wall(ctx, x0 + 0.15, zf + 0.3, x0 + 0.15, zb - 0.3, fy, broken and wy() or top, 0.3,
                    { { 2.4, 1.2, 0.9, 2.2 }, { 8.0, 1.2, 0.9, 2.2 } }, outer, paper, edge)
            else
                B.wall(ctx, sx, zf + 0.3, sx, zb - 0.3, fy, broken and wy() or top, 0.2, {}, paper2, paper, edge)
            end
            if s == S - 1 then
                B.wall(ctx, x1 - 0.15, zf + 0.3, x1 - 0.15, zb - 0.3, fy, broken and wy() or top, 0.3,
                    { { 2.4, 1.2, 0.9, 2.2 }, { 8.0, 1.2, 0.9, 2.2 } }, paper2, outer, edge)
            end
            -- stairwell side walls with the apartment doors on the landing, kitchen behind
            local dzc = zi0 + 0.85
            B.wall(ctx, xl0, zi0, xl0, zs, fy, top, 0.15, { { dzc - zi0, 1.0, 0, 2.05 } }, paper, stairWall, edge)
            B.wall(ctx, xr1, zi0, xr1, zs, fy, top, 0.15, { { dzc - zi0, 1.0, 0, 2.05 } }, stairWall, paper2, edge)
            B.wall(ctx, xl0, zs, xl0, zi1, fy, top, 0.15, { { (zi1 - zs) / 2, 0.9, 0, 2.05 } }, paper, M("tile", 0.75, 0.8, 0.78), edge)
            B.wall(ctx, xr1, zs, xr1, zi1, fy, top, 0.15, {}, M("tile", 0.75, 0.8, 0.78), paper2, edge)
            B.wall(ctx, xl0, zs, xr1, zs, fy, top, 0.15, {}, stairWall, M("tile", 0.75, 0.8, 0.78), edge)
            -- room partitions inside both apartments
            B.wall(ctx, sx + 0.15, 0.4, xl0, 0.4, fy, top, 0.12, { { 2.9, 0.9, 0, 2.05 } }, paper, paper, edge)
            B.wall(ctx, xr1, 0.4, sx + SW - 0.15, 0.4, fy, top, 0.12, { { 1.4, 0.9, 0, 2.05 } }, paper2, paper2, edge)
            -- stairs: flight up along +z in the left lane, half landing at the back, flight back along -z
            if f < F - 1 and f < floors - 1 then
                local stair = { default = M("concrete", 0.6, 0.6, 0.58) }
                for i = 0, 4 do
                    local za = zi0 + 1.7 + i * 0.5
                    B.mbox(ctx, xl0 + 0.08, fy + i * 0.28 - 0.04, za, xm - 0.05, fy + (i + 1) * 0.28, za + 0.5, stair)
                    local zb2 = zi0 + 4.2 - (i + 1) * 0.5
                    B.mbox(ctx, xm + 0.05, fy + 1.4 + i * 0.28 - 0.04, zb2, xr1 - 0.08, fy + 1.4 + (i + 1) * 0.28, zb2 + 0.5, stair)
                end
                B.mbox(ctx, xl0 + 0.08, fy + 1.2, zi0 + 4.2, xr1 - 0.08, fy + 1.4, zs - 0.08, { default = edge, top = M("tile", 0.6, 0.6, 0.58), bottom = ceiling })
                B.mbox(ctx, xm - 0.05, fy, zi0 + 1.7, xm + 0.05, fy + 2.5, zi0 + 4.2, { default = stairWall })
                -- handrail
                B.mbox(ctx, xm - 0.06, fy + 2.5, zi0 + 1.7, xm + 0.06, fy + 2.56, zi0 + 4.2, { default = M("wood", 0.4, 0.3, 0.22) }, false)
            end
            -- snow blows in through the broken top floor
            if broken then
                ctx:mat("snow", 0.95, 0.97, 1)
                ctx.mb:box(sx + 0.3, fy, zi0, xl0 - 0.1, fy + 0.08, zi1, { bottom = false })
                rubblePile(ctx, sx + 2.5, fy, 2, 1.2, rng)
            end
            shelter(ctx, sx, fy - 0.1, zf, sx + SW, fy + FH - 0.1, zb)
            -- furnishing and loot
            if Gen then
                ctx.floorY = fy
                for side = 0, 1 do
                    if rng:next() < (opts.loot or 0.55) then
                        local ax0 = side == 0 and sx + 0.3 or xr1 + 0.1
                        local ax1 = side == 0 and xl0 - 0.1 or sx + SW - 0.3
                        local mb = ctx.mb
                        mb:push() mb:translate(0, fy, 0)
                        local sub = setmetatable({ mb = mb, obj = ctx.obj, floorY = 0 }, { __index = ctx })
                        -- front room: sofa against the partition, wardrobe in the corner
                        sofa(sub, (ax0 + ax1) / 2, 0.4 - 0.55, pi, { rng:range(0.4, 0.7), rng:range(0.3, 0.5), rng:range(0.25, 0.4) })
                        if rng:next() < 0.7 then wardrobe(sub, side == 0 and ax0 + 0.55 or ax1 - 0.55, zi0 + 2.6, side == 0 and pi / 2 or -pi / 2, nil) end
                        -- back room: bed and table
                        Props.bed(sub, (ax0 + ax1) / 2 - 0.4, zi1 - 0.8, 0)
                        if rng:next() < 0.5 then Props.table(sub, (ax0 + ax1) / 2 + 0.6, 2.4, 0) end
                        mb:pop()
                        local wx = side == 0 and ax0 + 1.1 or ax1 - 1.1
                        if rng:next() < 0.7 then Gen.container(ctx, wx, fy + 0.4, zi0 + 2.6, "wardrobe", "WARDROBE") end
                        if rng:next() < 0.5 then Gen.container(ctx, (ax0 + ax1) / 2, fy + 0.3, zi1 - 1.4, "apartment", "BEDSIDE TABLE") end
                    end
                    -- apartment door on the landing
                    if rng:next() < (opts.doors or 0.45) and not broken then
                        local dx = side == 0 and xl0 or xr1
                        Gen.door(ctx, dx, fy, dzc - 0.5, pi / 2, 1.0, 2.05, { mat = "wood" })
                    end
                end
                -- kitchen
                if rng:next() < 0.6 then
                    local mb = ctx.mb
                    mb:push() mb:translate(0, fy, 0)
                    local sub = setmetatable({ mb = mb, obj = ctx.obj }, { __index = ctx })
                    kitchenStove(sub, xr1 - 0.45, zi1 - 0.45)
                    sub:mat("wood", 0.75, 0.72, 0.65)
                    sub:solid(xl0 + 1.0, 0, zi1 - 0.6, xl0 + 2.2, 0.85, zi1 - 0.05, { walk = false })
                    mb:pop()
                    Gen.container(ctx, xl0 + 1.6, fy + 0.9, zi1 - 0.4, "kitchen", "KITCHEN CUPBOARD")
                end
                ctx.floorY = nil
            end
        end
        -- roof / entrance
        local roofY = G0 + floors * FH - 0.2
        if floors == F then
            B.mbox(ctx, sx, roofY, zf, sx + SW, roofY + 0.25, zb, { default = edge, bottom = ceiling, top = M("roof", 0.5, 0.5, 0.52) })
            ctx:mat("snow", 0.96, 0.97, 1)
            ctx.mb:box(sx, roofY + 0.25, zf, sx + SW, roofY + 0.45, zb, { bottom = false })
            B.mbox(ctx, sx, roofY + 0.25, zf, sx + SW, roofY + 0.9, zf + 0.2, { default = edge, top = M("snow", 0.95, 0.97, 1) })
            B.mbox(ctx, sx, roofY + 0.25, zb - 0.2, sx + SW, roofY + 0.9, zb, { default = edge, top = M("snow", 0.95, 0.97, 1) })
        else
            rubblePile(ctx, sx + SW / 2, 0, zb + 3.5, 4.5, rng)
            ctx:collider(sx + 1, 0, zb + 1, sx + SW - 1, 1.6, zb + 6)
        end
        -- entrance: canopy, step, podyezd door
        B.mbox(ctx, sx + 4.8, G0 + 2.45, zf - 1.4, sx + 7.2, G0 + 2.6, zf, { default = edge, top = M("snow", 0.95, 0.97, 1) })
        B.mbox(ctx, sx + 5.0, 0, zf - 1.0, sx + 7.0, G0, zf, { default = M("concrete", 0.55, 0.55, 0.55) })
        if Gen and rng:next() < 0.55 then
            Gen.door(ctx, sx + 5.35, G0, zf + 0.15, 0, 1.3, 2.2, { mat = "metal", label = "PODYEZD DOOR" })
        end
    end
    return { L = L, D = D, h = G0 + F * FH }
end

---------------------------------------------------------------------------
-- garage cooperative: a row of brick boxes, gates facing local -z
---------------------------------------------------------------------------
function B.garageRow(ctx, n, rng, Gen, opts)
    opts = opts or {}
    local GW, GD, GH = 3.6, 6.5, 2.7
    local L = n * GW
    local x0 = -L / 2
    ctx:flatten(x0 - 1, -GD / 2 - 5, -x0 + 1, GD / 2 + 1, 0)
    local brick = M("brick", 0.72, 0.62, 0.55)
    local inner = M("brick", 0.48, 0.42, 0.38)
    local edge = M("concrete", 0.6, 0.6, 0.58)
    B.mbox(ctx, x0, -0.8, -GD / 2, -x0, 0.1, GD / 2, { default = M("concrete", 0.5, 0.5, 0.5), top = M("concrete", 0.42, 0.41, 0.4) })
    B.mbox(ctx, x0, 0.1, GD / 2 - 0.25, -x0, GH, GD / 2, { default = brick, left = inner })
    for i = 0, n do
        local wx = x0 + i * GW
        B.mbox(ctx, wx - 0.12, 0.1, -GD / 2, wx + 0.12, GH, GD / 2 - 0.25,
            { default = brick, front = i < n and inner or brick, back = i > 0 and inner or brick })
    end
    B.mbox(ctx, x0 - 0.2, GH, -GD / 2 - 0.4, -x0 + 0.2, GH + 0.22, GD / 2 + 0.2, { default = edge, bottom = M("concrete", 0.4, 0.4, 0.4), top = M("roof", 0.45, 0.45, 0.47) })
    ctx:mat("snow", 0.96, 0.97, 1)
    ctx.mb:box(x0 - 0.2, GH + 0.22, -GD / 2 - 0.4, -x0 + 0.2, GH + 0.42, GD / 2 + 0.2, { bottom = false })
    for i = 0, n - 1 do
        local gx = x0 + i * GW
        B.mbox(ctx, gx + 0.12, 2.25, -GD / 2 - 0.05, gx + GW - 0.12, GH, -GD / 2 + 0.2, { default = brick, right = inner })
        local r = rng:next()
        local gate = M("metal", rng:range(0.3, 0.45), rng:range(0.35, 0.5), rng:range(0.3, 0.42))
        if r < 0.4 and Gen then
            Gen.door(ctx, gx + 0.4, 0.1, -GD / 2 + 0.05, 0, GW - 0.8, 2.15, { mat = "metal", label = "GARAGE GATE", heavy = true })
        elseif r < 0.75 then
            -- leaves hanging open
            ctx:mat("metal", gate[2], gate[3], gate[4])
            ctx.mb:push() ctx.mb:translate(gx + 0.35, 0.1, -GD / 2) ctx.mb:rotateY(-1.9)
            ctx.mb:box(0, 0, -0.03, 1.4, 2.1, 0.03)
            ctx.mb:pop()
            ctx.mb:push() ctx.mb:translate(gx + GW - 0.35, 0.1, -GD / 2) ctx.mb:rotateY(pi + 1.7)
            ctx.mb:box(0, 0, -0.03, 1.4, 2.1, 0.03)
            ctx.mb:pop()
        end
        -- what was left inside
        local cx = gx + GW / 2
        local k = rng:next()
        if k < 0.25 then
            Props.car(ctx, cx, 0.4, pi / 2, nil)
            ctx:collider(cx - 0.9, 0.1, -1.8, cx + 0.9, 1.4, 2.6)
        elseif k < 0.55 then
            Props.shelf(ctx, cx, GD / 2 - 0.6, 0, 2.4)
            if Gen then Gen.container(ctx, cx, 1.0, GD / 2 - 0.9, "garage", "GARAGE SHELF") end
        elseif k < 0.75 then
            Props.crate(ctx, cx - 0.6, 0.1, 1.5, 0.8)
            Props.barrel(ctx, cx + 0.8, 0.1, 2.2, true)
            if Gen then Gen.container(ctx, cx - 0.6, 0.9, 1.2, "garage", "TOOL CHEST") end
        else
            ctx:mat("wood", 0.5, 0.42, 0.34)
            ctx:solid(cx - 1.2, 0.1, GD / 2 - 1.0, cx + 1.2, 0.95, GD / 2 - 0.3, { walk = false })
            if Gen then Gen.container(ctx, cx, 1.0, GD / 2 - 0.65, "garage", "WORKBENCH") end
        end
        shelter(ctx, gx, 0, -GD / 2, gx + GW, GH, GD / 2)
    end
    return { L = L, D = GD }
end

---------------------------------------------------------------------------
-- single storey building with big windows: shops, stores, offices, guard houses
---------------------------------------------------------------------------
-- opts: h, tint, label (container), loot (kind), windows (count front), door chance
function B.shop(ctx, w, d, rng, Gen, opts)
    opts = opts or {}
    local h = opts.h or 3.4
    local tint = opts.tint or { 0.75, 0.72, 0.66 }
    local outer = M(opts.mat or "plaster", tint[1], tint[2], tint[3])
    local inner = M("plaster", 0.6, 0.62, 0.58)
    local edge = M("concrete", 0.6, 0.6, 0.58)
    local x0, x1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2
    ctx:flatten(x0 - 1, z0 - 2, x1 + 1, z1 + 1, 0)
    B.mbox(ctx, x0, -1, z0, x1, 0.25, z1, { default = M("concrete", 0.5, 0.5, 0.5), top = M("tile", 0.55, 0.55, 0.5) })
    local fo = { { w / 2, 1.6, 0, 2.3 } }
    local nwin = math.max(1, math.floor((w - 4) / 4))
    for i = 1, nwin do
        local at = (i - 0.5) / nwin * (w / 2 - 1.5)
        fo[#fo + 1] = { at + 0.4, 2.2, 0.7, 2.6 }
        fo[#fo + 1] = { w - at - 0.4, 2.2, 0.7, 2.6 }
    end
    local top = 0.25 + h
    B.wall(ctx, x0, z0 + 0.15, x1, z0 + 0.15, 0.25, top, 0.3, fo, outer, inner, edge)
    B.wall(ctx, x0, z1 - 0.15, x1, z1 - 0.15, 0.25, top, 0.3, { { w * 0.25, 1.2, 1.0, 2.2 } }, inner, outer, edge)
    B.wall(ctx, x0 + 0.15, z0 + 0.3, x0 + 0.15, z1 - 0.3, 0.25, top, 0.3, { { d / 2, 1.2, 1.0, 2.2 } }, outer, inner, edge)
    B.wall(ctx, x1 - 0.15, z0 + 0.3, x1 - 0.15, z1 - 0.3, 0.25, top, 0.3, {}, inner, outer, edge)
    B.mbox(ctx, x0 - 0.2, top, z0 - 0.3, x1 + 0.2, top + 0.3, z1 + 0.2, { default = edge, bottom = M("plaster", 0.55, 0.55, 0.52), top = M("roof", 0.45, 0.45, 0.47) })
    ctx:mat("snow", 0.96, 0.97, 1)
    ctx.mb:box(x0 - 0.2, top + 0.3, z0 - 0.3, x1 + 0.2, top + 0.5, z1 + 0.2, { bottom = false })
    -- sign board over the door
    if opts.sign then
        B.mbox(ctx, -w * 0.3, top - 0.9, z0 - 0.08, w * 0.3, top - 0.2, z0, { default = M(opts.sign, 1, 1, 1) }, false)
    end
    -- fittings
    if opts.shelves ~= false then
        for i = -1, 1 do Props.shelf(ctx, i * (w / 3.5), z1 - 0.9, 0, math.min(2.6, w / 4)) end
        ctx:mat("wood", 0.55, 0.45, 0.35)
        ctx:solid(-w / 2 + 1.0, 0.25, -0.4, -w / 2 + 1.6, 1.25, d / 2 - 2.2, { walk = false })
    end
    if Gen then
        Gen.container(ctx, 0, 1.0, z1 - 1.2, opts.loot or "shop", opts.label or "SHELVES")
        if rng:next() < 0.6 then Gen.container(ctx, -w / 2 + 1.3, 1.3, 0.5, opts.loot or "shop", "COUNTER") end
        if rng:next() < 0.5 then Gen.door(ctx, -0.8, 0.25, z0 + 0.15, 0, 1.6, 2.25, { mat = "wood" }) end
    end
    shelter(ctx, x0, 0, z0, x1, top, z1)
    return { top = top }
end

---------------------------------------------------------------------------
-- ruins: wall stubs around a rubble mound (bombed-out buildings)
---------------------------------------------------------------------------
function B.ruin(ctx, w, d, rng)
    local x0, x1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2
    ctx:flatten(x0, z0, x1, z1, 0)
    local mat = rng:next() > 0.5 and "brick" or "panel"
    local outer = M(mat, 0.75, 0.72, 0.68)
    local edge = M("concrete", 0.55, 0.55, 0.53)
    local function stubs(ax, az, bx, bz)
        local len = U.dist2(ax, az, bx, bz)
        local n = math.max(1, math.floor(len / 3))
        for i = 0, n - 1 do
            if rng:next() > 0.25 then
                local t0, t1 = i / n, (i + 1) / n
                local h = rng:range(0.8, 7)
                local sx0, sz0 = ax + (bx - ax) * t0, az + (bz - az) * t0
                local sx1, sz1 = ax + (bx - ax) * t1, az + (bz - az) * t1
                B.mbox(ctx, math.min(sx0, sx1) - 0.15, 0, math.min(sz0, sz1) - 0.15, math.max(sx0, sx1) + 0.15, h, math.max(sz0, sz1) + 0.15,
                    { default = outer, top = edge })
            end
        end
    end
    stubs(x0, z0, x1, z0) stubs(x1, z0, x1, z1) stubs(x1, z1, x0, z1) stubs(x0, z1, x0, z0)
    rubblePile(ctx, 0, 0, 0, math.min(w, d) * 0.45, rng)
    ctx:collider(x0 + 1.5, 0, z0 + 1.5, x1 - 1.5, 1.3, z1 - 1.5)
    ctx:mat("rust", 0.5, 0.45, 0.4)
    for i = 1, 3 do ctx:beam(rng:range(x0, x1), rng:range(0, 2), rng:range(z0, z1), rng:range(x0, x1), rng:range(1, 4), rng:range(z0, z1), 0.12) end
end

---------------------------------------------------------------------------
-- monument: a figure on a pedestal for the town squares
---------------------------------------------------------------------------
function B.monument(ctx)
    local edge = M("concrete", 0.55, 0.55, 0.55)
    B.mbox(ctx, -2.5, 0, -2.5, 2.5, 0.5, 2.5, { default = edge })
    B.mbox(ctx, -1.2, 0.5, -1.2, 1.2, 3.4, 1.2, { default = M("concrete", 0.45, 0.45, 0.47) })
    local mb = ctx.mb
    ctx:mat("metal", 0.32, 0.34, 0.32)
    mb:box(-0.35, 3.4, -0.45, 0.35, 4.6, 0.45)        -- legs and coat
    mb:box(-0.4, 4.6, -0.55, 0.4, 5.9, 0.55)          -- torso
    mb:sphere(0, 6.2, 0, 0.3, 0.33, 0.3, 6, 4)        -- head
    ctx:beam(0, 5.7, 0.5, 0.9, 6.4, 1.3, 0.2)         -- the outstretched arm
    ctx:beam(0, 5.7, -0.5, 0.1, 4.8, -0.7, 0.2)
    ctx:mat("snow", 0.96, 0.97, 1)
    mb:box(-1.25, 3.4, -1.25, 1.25, 3.5, 1.25, { bottom = false })
    mb:box(-0.4, 6.45, -0.25, 0.3, 6.55, 0.25, { bottom = false })
end

return B
