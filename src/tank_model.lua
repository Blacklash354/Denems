-- Low-poly geometry for the player's heavy tank. Tank-local axes: +x forward, +y up, +z right.
-- Exterior pieces only emit outward faces; the interior (tank_interior.lua) supplies inner faces.
local MB = require("src.engine.meshbuilder")

local TM = {}
local pi = math.pi

TM.TURRET_PIVOT = { 0.35, 2.35, 0 }
TM.TRUNNION = { 1.45, 0.6, 0 }          -- turret local
TM.CUPOLA = { -0.95, 1.1, -0.75 }       -- turret local (centre on roof)
TM.CUPOLA_R = 0.34
TM.HATCH_HINGE = { -0.95 - 0.36, 1.42, -0.75 } -- turret local
TM.MG_BALL = { 3.12, 1.95, 0.75 }       -- tank local
TM.SLIT = { 3.0, 2.0, -0.75 }
TM.TRACK_UV = 1.6                      -- tread texture repeats per metre of belt
TM.WHEEL_R = 0.43

local function only(...)
    local f = { top = false, bottom = false, front = false, back = false, left = false, right = false }
    for _, k in ipairs({ ... }) do f[k] = true end
    return f
end
TM.only = only

local function snowPatch(mb, x0, z0, x1, z1, y, rngf)
    mb:material("snow"):color(0.95, 0.97, 1.0)
    mb:box(x0, y, z0, x1, y + 0.04, z1, { bottom = false })
end

-- track belt loop path (x,y) points
local function trackPath()
    local pts = {}
    local function arc(cx, cy, r, a0, a1, n)
        for i = 0, n do
            local a = a0 + (a1 - a0) * i / n
            pts[#pts + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r }
        end
    end
    -- bottom run front->rear handled by closing; build: front sprocket, top run, idler, bottom run
    arc(3.32, 0.72, 0.44, -pi / 2, pi / 2, 6)         -- front sprocket (bottom->top)
    for i = 1, 7 do                                      -- top run with sag
        local t = i / 8
        local x = 3.32 + (-3.55 - 3.32) * t
        pts[#pts + 1] = { x, 1.16 - math.sin(t * pi * 4) * 0.03 }
    end
    arc(-3.55, 0.66, 0.42, pi / 2, 3 * pi / 2, 6)      -- rear idler (top->bottom)
    pts[#pts + 1] = { -2.9, 0.05 }
    for i = 1, 6 do pts[#pts + 1] = { -2.9 + i * (5.8 / 6), 0.05 } end
    pts[#pts + 1] = { 3.32, 0.28 }
    return pts
end

-- closed track belt along a loop of (x,y) points; u runs along the belt so uvOffset scrolls it
function TM.buildBelt(pts, zIn, zOut, side, seed)
    local mb = MB.new(seed)
    mb.jitter = 0.04
    mb:material("tread"):color(0.85, 0.82, 0.8)
    local z0, z1 = zIn, zOut
    if side < 0 then z0, z1 = z1, z0 end
    local u = 0
    for i = 1, #pts do
        local a, b = pts[i], pts[i % #pts + 1]
        local l = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        local u1 = u + l * TM.TRACK_UV
        mb:quadUV(a[1], a[2], z0, u, 0, b[1], b[2], z0, u1, 0, b[1], b[2], z1, u1, 1, a[1], a[2], z1, u, 1)
        u = u1
    end
    return mb:build()
end

-- the driver's compass on the front wall right of the vision slit (dial faces back at him, up on the dial
-- is the hull's nose) and the note the crew left taped to the instrument panel
TM.COMPASS = { 2.955, 1.95, -0.2 }
function TM.buildCompass()
    local cx, cy, cz = TM.COMPASS[1], TM.COMPASS[2], TM.COMPASS[3]
    local mb = MB.new(51)
    mb:material("metal"):color(0.28, 0.27, 0.25)
    mb:cylinderX(cx, cx + 0.05, cy, cz, 0.085, 0.085, 12)               -- bezel
    mb:box(cx + 0.02, cy - 0.13, cz - 0.03, cx + 0.05, cy - 0.08, cz + 0.03) -- bracket
    mb:material("white"):color(0.86, 0.84, 0.76)
    mb:cylinderX(cx - 0.003, cx, cy, cz, 0.074, 0.074, 14)                 -- card
    mb:material("metal"):color(0.15, 0.15, 0.15)
    for i = 0, 7 do                                                        -- ticks round the card
        local a = i / 8 * 2 * math.pi
        local y, z = cy + math.cos(a) * 0.06, cz + math.sin(a) * 0.06
        local s = i == 0 and 0.012 or 0.006
        mb:box(cx - 0.006, y - s, z - s, cx - 0.003, y + s, z + s)
    end
    mb:material("cloth_red"):color(1, 1, 1)
    mb:box(cx - 0.006, cy + 0.072, cz - 0.01, cx - 0.003, cy + 0.085, cz + 0.01) -- lubber line: the nose
    local compass = mb:build()
    -- needle (dial-local: points along +y, turned about +x by the bearing of north)
    mb = MB.new(52)
    mb:material("cloth_red"):color(1, 1, 1)
    mb:hexa({ { -0.012, 0, -0.008 }, { -0.009, 0, -0.008 }, { -0.009, 0, 0.008 }, { -0.012, 0, 0.008 },
              { -0.012, 0.062, -0.001 }, { -0.009, 0.062, -0.001 }, { -0.009, 0.062, 0.001 }, { -0.012, 0.062, 0.001 } })
    mb:material("white"):color(0.95, 0.95, 0.92)
    mb:hexa({ { -0.012, -0.045, -0.001 }, { -0.009, -0.045, -0.001 }, { -0.009, -0.045, 0.001 }, { -0.012, -0.045, 0.001 },
              { -0.012, 0, -0.008 }, { -0.009, 0, -0.008 }, { -0.009, 0, 0.008 }, { -0.012, 0, 0.008 } })
    mb:material("metal"):color(0.2, 0.2, 0.2)
    mb:cylinderX(-0.014, -0.008, 0, 0, 0.01, 0.01, 6)
    local needle = mb:build()
    -- a folded sheet taped to the panel's inner face, by the driver's left knee
    mb = MB.new(53)
    mb:material("paper"):color(0.92, 0.9, 0.82)
    mb:quadN(2.62, 1.66, -1.148, 2.9, 1.66, -1.148, 2.9, 1.9, -1.148, 2.62, 1.9, -1.148, 0, 0, 1)
    mb:material("cloth"):color(0.75, 0.7, 0.55)
    mb:box(2.72, 1.88, -1.15, 2.8, 1.93, -1.146)
    local note = mb:build()
    return compass, needle, note
end

-- a thrown track: the belt unrolled flat on the ground, links running back from the origin along -x
function TM.buildLyingTrack(width, length, seed)
    local mb = MB.new(seed or 9)
    mb.jitter = 0.06
    mb:material("tread"):color(0.8, 0.78, 0.76)
    local link, gap = 0.17, 0.02
    local n = math.floor(length / (link + gap))
    for i = 0, n - 1 do
        local x0 = -i * (link + gap)
        -- a slight wave where the belt buckled as it came off
        local y = 0.02 + math.max(0, math.sin(i * 0.37)) * 0.05 * (i < 8 and 1 or 0.3)
        mb:box(x0 - link, y - 0.03, -width / 2, x0, y + 0.03, width / 2)
        mb:box(x0 - link * 0.6, y + 0.03, -0.04, x0 - link * 0.4, y + 0.07, 0.04)       -- guide horn
    end
    return mb:build()
end

function TM.buildTrack(side)
    return TM.buildBelt(trackPath(), side * 1.45, side * 1.97, side, side > 0 and 3 or 4)
end

function TM.buildHull()
    local mb = MB.new(11)
    mb.texScale = 0.45
    mb.maxEdge = 0.9
    mb.jitter = 0.05
    local T = "tank"
    mb:material(T):color(0.92, 0.92, 0.9)
    -- belly & lower hull
    mb:box(-3.9, 0.5, -1.45, 2.9, 1.55, 1.45, only("bottom", "back"))
    mb:box(-3.9, 0.5, 1.35, 2.9, 1.55, 1.45, only("right"))
    mb:box(-3.9, 0.5, -1.45, 2.9, 1.55, -1.35, only("left"))
    -- lower nose / glacis
    mb:hexa({ { 2.9, 0.5, -1.45 }, { 3.35, 0.62, -1.45 }, { 3.35, 0.62, 1.45 }, { 2.9, 0.5, 1.45 },
              { 2.9, 1.55, -1.45 }, { 3.15, 1.55, -1.45 }, { 3.15, 1.55, 1.45 }, { 2.9, 1.55, 1.45 } })
    -- sponson undersides
    mb:box(-3.9, 1.5, 1.45, 3.15, 1.55, 1.85, only("bottom", "front", "back"))
    mb:box(-3.9, 1.5, -1.85, 3.15, 1.55, -1.45, only("bottom", "front", "back"))
    -- superstructure sides
    mb:box(-3.9, 1.55, 1.75, 3.15, 2.35, 1.85, only("right", "back"))
    mb:box(-3.9, 1.55, -1.85, 3.15, 2.35, -1.75, only("left", "back"))
    -- front plate with vision slit
    mb:box(3.0, 1.55, -1.85, 3.15, 1.95, 1.85, only("front", "top"))
    mb:box(3.0, 2.05, -1.85, 3.15, 2.35, 1.85, only("front", "bottom"))
    mb:box(3.0, 1.95, -1.85, 3.15, 2.05, -0.95, only("front", "right"))
    mb:box(3.0, 1.95, -0.55, 3.15, 2.05, 1.85, only("front", "left"))
    -- rear plate
    mb:box(-3.95, 0.5, -1.85, -3.9, 2.35, 1.85, only("back", "left", "right"))
    -- roof with turret ring hole
    mb.maxEdge = nil
    mb:material(T):color(0.9, 0.9, 0.88)
    mb:plateHole(-3.9, -1.85, 3.15, 1.85, 2.35, TM.TURRET_PIVOT[1], 0, 1.5, 20, 1)
    -- turret ring collar
    mb:material("metal"):color(0.5, 0.5, 0.48)
    mb:cylinder(TM.TURRET_PIVOT[1], 2.28, 0, 1.5, 2.35, 1.5, 20, false)
    -- visor housing (armoured block around slit)
    mb:material(T):color(0.85, 0.85, 0.83)
    mb:box(3.15, 1.9, -1.05, 3.24, 1.95, -0.45)
    mb:box(3.15, 2.05, -1.05, 3.24, 2.12, -0.45)
    mb:box(3.15, 1.95, -1.05, 3.24, 2.05, -0.95)
    mb:box(3.15, 1.95, -0.55, 3.24, 2.05, -0.45)
    -- MG ball mount
    mb:material("metal"):color(0.45, 0.45, 0.42)
    mb:sphere(3.15, 1.95, 0.75, 0.2, 0.2, 0.2, 8, 5)
    -- fenders
    mb:material(T):color(0.85, 0.85, 0.82)
    for _, s in ipairs({ -1, 1 }) do
        local za, zb = s > 0 and 1.45 or -1.98, s > 0 and 1.98 or -1.45
        mb:box(3.15, 1.5, za, 3.85, 1.54, zb)
        mb:box(-4.15, 1.5, za, -3.9, 1.54, zb)
        mb:box(1.85, 1.55, za, 1.88, 1.58, zb)
    end
    -- headlights
    mb:material("metal"):color(0.4, 0.4, 0.4)
    mb:cylinderX(3.15, 3.4, 2.45, -1.35, 0.11, 0.13, 7)
    mb:cylinderX(3.15, 3.4, 2.45, 1.35, 0.11, 0.13, 7)
    mb:box(3.12, 2.35, -1.4, 3.2, 2.45, -1.3)
    mb:box(3.12, 2.35, 1.3, 3.2, 2.45, 1.4)
    -- tow hooks
    mb:material("rust"):color(0.6, 0.55, 0.5)
    mb:box(3.25, 0.7, -1.2, 3.55, 0.85, -0.95)
    mb:box(3.25, 0.7, 0.95, 3.55, 0.85, 1.2)
    -- spare track links on the glacis
    mb:material("tread"):color(0.8, 0.78, 0.75)
    for i = -3, 3 do mb:box(3.17, 0.95, i * 0.36 - 0.16, 3.25, 1.45, i * 0.36 + 0.16) end
    -- engine deck grilles & hatches
    mb:material("grille"):color(0.9, 0.9, 0.9)
    mb:box(-3.6, 2.35, -1.5, -2.2, 2.4, -0.4, { bottom = false })
    mb:box(-3.6, 2.35, 0.4, -2.2, 2.4, 1.5, { bottom = false })
    mb:material(T):color(0.8, 0.8, 0.78)
    mb:box(-2.0, 2.35, -0.6, -1.3, 2.39, 0.6, { bottom = false })
    -- fuel filler caps
    mb:material("metal"):color(0.55, 0.5, 0.4)
    mb:cylinder(-3.0, 2.35, 0.0, 0.12, 2.43, 0.12, 6)
    -- exhaust pipes with guards
    mb:material("rust"):color(0.8, 0.6, 0.5)
    for _, z in ipairs({ -0.75, 0.75 }) do
        mb:cylinder(-4.08, 1.3, z, 0.11, 2.75, 0.1, 6)
        mb:material("metal"):color(0.5, 0.48, 0.45)
        mb:box(-4.22, 1.4, z - 0.17, -4.0, 2.6, z - 0.13)
        mb:box(-4.22, 1.4, z + 0.13, -4.0, 2.6, z + 0.17)
        mb:material("rust"):color(0.8, 0.6, 0.5)
    end
    -- jerry cans on rear deck
    mb:material("metal"):color(0.4, 0.45, 0.35)
    for i = 0, 2 do mb:box(-3.88, 2.35, -1.75 + i * 0.32, -3.4, 2.82, -1.5 + i * 0.32) end
    -- rear ladder (left side of the rear plate) for climbing onto the deck
    mb:material("metal"):color(0.55, 0.52, 0.48)
    for _, z in ipairs({ -1.45, -0.95 }) do mb:box(-4.12, 0.1, z - 0.03, -4.06, 2.4, z + 0.03) end
    for y = 0.3, 2.3, 0.33 do mb:box(-4.12, y, -1.45, -4.06, y + 0.04, -0.95) end
    -- tools: shovel, axe, crowbar, tow cable on the sides
    for _, s in ipairs({ -1, 1 }) do
        local z = s * 1.87
        mb:material("wood"):color(0.75, 0.65, 0.55)
        mb:box(-1.0, 1.75, z - 0.03, 0.6, 1.8, z + 0.03)
        mb:material("metal"):color(0.5, 0.5, 0.5)
        mb:box(0.6, 1.68, z - 0.03, 0.95, 1.9, z + 0.03)
        mb:material("wood"):color(0.75, 0.65, 0.55)
        mb:box(-2.6, 2.0, z - 0.03, -1.6, 2.05, z + 0.03)
        mb:material("metal"):color(0.5, 0.5, 0.5)
        mb:box(-1.75, 1.95, z - 0.03, -1.6, 2.12, z + 0.03)
        mb:material("rust"):color(0.7, 0.6, 0.5)
        mb:box(-3.6, 1.62, z - 0.04, 1.2, 1.67, z + 0.04)
        mb:box(-3.6, 2.2, z - 0.04, 1.2, 2.25, z + 0.04)
        -- spare links on the sides
        mb:material("tread"):color(0.8, 0.78, 0.75)
        for i = 0, 4 do mb:box(1.4 + i * 0.3, 1.62, z, 1.66 + i * 0.3, 2.25, z + s * 0.06) end
    end
    -- antenna mount + antenna
    mb:material("metal"):color(0.35, 0.35, 0.35)
    mb:cylinder(-3.4, 2.35, 1.5, 0.05, 4.7, 0.015, 4)
    -- insignia (white cross)
    mb:material("cross"):color(1, 1, 1)
    mb:quad(-1.2, 1.75, 1.86, -0.5, 1.75, 1.86, -0.5, 2.25, 1.86, -1.2, 2.25, 1.86)
    mb:quad(-0.5, 1.75, -1.86, -1.2, 1.75, -1.86, -1.2, 2.25, -1.86, -0.5, 2.25, -1.86)
    mb:quad(-3.96, 1.7, 0.3, -3.96, 1.7, -0.3, -3.96, 2.2, -0.3, -3.96, 2.2, 0.3)
    -- battle damage: scorch & gouges
    mb:material("rust"):color(0.35, 0.3, 0.28)
    mb:quad(3.16, 1.6, 0.9, 3.16, 1.6, 1.3, 3.16, 1.85, 1.3, 3.16, 1.85, 0.9)
    mb:quad(-2.0, 1.6, 1.86, -1.6, 1.6, 1.86, -1.6, 1.9, 1.86, -2.0, 1.9, 1.86)
    -- snow accumulation on deck and fenders
    snowPatch(mb, -3.8, -1.7, -3.1, -0.3, 2.42)
    snowPatch(mb, 2.0, -1.7, 2.95, -0.8, 2.35)
    snowPatch(mb, 2.2, 0.9, 3.05, 1.75, 2.35)
    snowPatch(mb, -1.4, 1.55, 0.3, 1.8, 2.35)
    snowPatch(mb, 3.2, -1.95, 3.8, -1.5, 1.54)
    snowPatch(mb, 3.2, 1.5, 3.8, 1.95, 1.54)
    snowPatch(mb, -1.2, -1.82, 1.5, -1.6, 2.35)
    return mb:build()
end

-- road wheel layout per side: { x, y, z } hub positions in tank-local space (interleaved)
function TM.wheelLayout(side)
    local out = {}
    for i = 0, 7 do
        local outer = (i % 2 == 0)
        out[#out + 1] = { -2.75 + i * 0.75, 0.5, side * 1.7 + side * (outer and 0.16 or -0.1) }
    end
    out[#out + 1] = { -3.55, 0.66, side * 1.72 } -- rear idler
    return out
end

-- a single wheel (wheel-local: axle along z, origin at the hub); drawn once per wheel so it can spin
function TM.buildWheel(r, halfW, seg)
    local mb = MB.new(21)
    mb.jitter = 0.03
    mb:material("wheel"):color(0.95, 0.95, 0.92)
    mb:cylinderZ(-halfW, halfW, 0, 0, r, seg or 10)
    return mb:build()
end

function TM.buildSprocket()
    local mb = MB.new(22)
    mb:material("tank"):color(0.7, 0.7, 0.68)
    mb:cylinderZ(-0.2, 0.2, 0, 0, 0.4, 10)
    mb:material("metal"):color(0.4, 0.4, 0.4)
    for i = 0, 9 do
        local a = i / 10 * 2 * pi
        mb:boxC(math.cos(a) * 0.42, math.sin(a) * 0.42, 0, 0.1, 0.1, 0.36)
    end
    mb:cylinderZ(-0.24, 0.24, 0, 0, 0.14, 6)
    return mb:build()
end

-- turret exterior (turret-local, origin on the hull roof at the pivot)
function TM.buildTurret()
    local mb = MB.new(31)
    mb.texScale = 0.45
    mb.maxEdge = 0.9
    local T = "tank"
    mb:material(T):color(0.92, 0.92, 0.9)
    local b = { { -1.75, 0, -1.6 }, { 1.6, 0, -1.6 }, { 1.6, 0, 1.6 }, { -1.75, 0, 1.6 } }
    local t = { { -1.6, 1.1, -1.35 }, { 1.35, 1.1, -1.35 }, { 1.35, 1.1, 1.35 }, { -1.6, 1.1, 1.35 } }
    local function Q(a, bb, c, d) mb:quad(a[1], a[2], a[3], bb[1], bb[2], bb[3], c[1], c[2], c[3], d[1], d[2], d[3]) end
    Q(b[2], t[2], t[3], b[3]) -- front
    Q(b[4], t[4], t[1], b[1]) -- back
    Q(b[3], t[3], t[4], b[4]) -- right
    Q(b[1], t[1], t[2], b[2]) -- left
    mb.maxEdge = nil
    -- roof with cupola hole
    local C = TM.CUPOLA
    mb:plateHole(-1.6, -1.35, 1.35, 1.35, 1.1, C[1], C[3], TM.CUPOLA_R, 12, 1)
    -- bottom annulus (outside the ring)
    mb:plateHole(-1.75, -1.6, 1.6, 1.6, 0.0, 0, 0, 1.5, 20, -1)
    -- cupola ring with vision blocks
    mb:material(T):color(0.85, 0.85, 0.83)
    mb:cylinder(C[1], 1.1, C[3], 0.46, 1.42, 0.44, 12, false)
    mb:material("metal"):color(0.4, 0.4, 0.4)
    mb:cylinder(C[1], 1.38, C[3], 0.36, 1.42, 0.36, 12, false)
    -- ring top (annulus)
    for i = 0, 11 do
        local a0, a1 = i / 12 * 2 * pi, (i + 1) / 12 * 2 * pi
        mb:quadN(C[1] + math.cos(a0) * 0.36, 1.42, C[3] + math.sin(a0) * 0.36, C[1] + math.cos(a0) * 0.44, 1.42, C[3] + math.sin(a0) * 0.44,
                 C[1] + math.cos(a1) * 0.44, 1.42, C[3] + math.sin(a1) * 0.44, C[1] + math.cos(a1) * 0.36, 1.42, C[3] + math.sin(a1) * 0.36, 0, 1, 0)
    end
    mb:material("window"):color(0.6, 0.7, 0.8)
    for i = 0, 6 do
        local a = i / 7 * 2 * pi
        local x, z = C[1] + math.cos(a) * 0.465, C[3] + math.sin(a) * 0.465
        local tx, tz = -math.sin(a) * 0.07, math.cos(a) * 0.07
        mb:quad(x - tx, 1.22, z - tz, x + tx, 1.22, z + tz, x + tx, 1.32, z + tz, x - tx, 1.32, z - tz)
    end
    -- bustle storage box (also a step onto the turret roof)
    mb:material(T):color(0.82, 0.82, 0.8)
    mb:box(-2.35, 0.1, -1.1, -1.72, 0.75, 1.1)
    mb:material("metal"):color(0.45, 0.45, 0.43)
    mb:box(-2.37, 0.55, -0.15, -2.35, 0.65, 0.15)
    snowPatch(mb, -2.3, -1.05, -1.75, 1.05, 0.75)
    -- smoke dischargers
    mb:material("metal"):color(0.45, 0.45, 0.42)
    for _, s in ipairs({ -1, 1 }) do
        for i = 0, 2 do
            mb:push()
            mb:translate(0.9 - i * 0.2, 0.85, s * 1.37)
            mb:rotateX(s * 0.6)
            mb:cylinder(0, 0, 0, 0.05, 0.28, 0.05, 5)
            mb:pop()
        end
        -- spare track links on turret sides
        mb:material("tread"):color(0.8, 0.78, 0.75)
        for i = 0, 3 do
            local x = -1.3 + i * 0.32
            mb:box(x, 0.2, s * 1.58, x + 0.26, 0.85, s * 1.58 + s * 0.05)
        end
        mb:material("metal"):color(0.45, 0.45, 0.42)
    end
    -- lifting hooks / periscope
    mb:box(0.6, 1.1, 0.6, 0.85, 1.25, 0.75)
    mb:box(-1.2, 1.1, 0.9, -1.0, 1.2, 1.05)
    -- loader periscope
    mb:material("metal"):color(0.35, 0.35, 0.35)
    mb:box(0.2, 1.1, 0.75, 0.42, 1.28, 0.95)
    -- scorch marks and snow
    mb:material("rust"):color(0.3, 0.26, 0.25)
    mb:quad(1.45, 0.3, 0.9, 1.45, 0.3, 1.3, 1.4, 0.7, 1.3, 1.4, 0.7, 0.9)
    snowPatch(mb, -1.5, 0.1, 1.2, 1.25, 1.1)
    snowPatch(mb, 0.2, -1.25, 1.2, -0.6, 1.1)
    return mb:build()
end

-- gun (gun-local, origin at trunnion): exterior part
function TM.buildGun()
    local mb = MB.new(41)
    mb.texScale = 0.5
    local T = "tank"
    mb:material(T):color(0.9, 0.9, 0.88)
    -- mantlet
    mb:hexa({ { 0.08, -0.34, -0.62 }, { 0.4, -0.3, -0.58 }, { 0.4, -0.3, 0.58 }, { 0.08, -0.34, 0.62 },
              { 0.08, 0.34, -0.62 }, { 0.4, 0.3, -0.58 }, { 0.4, 0.3, 0.58 }, { 0.08, 0.34, 0.62 } })
    mb:cylinderX(0.38, 0.8, 0, 0, 0.2, 0.16, 8)
    -- barrel
    mb:material(T):color(0.88, 0.88, 0.86)
    mb:cylinderX(0.75, 5.6, 0, 0, 0.12, 0.095, 8)
    -- muzzle brake
    mb:material("metal"):color(0.5, 0.5, 0.48)
    mb:cylinderX(5.6, 6.05, 0, 0, 0.17, 0.17, 8)
    mb:material("rust"):color(0.25, 0.2, 0.2)
    mb:box(5.7, -0.18, -0.08, 5.9, 0.18, 0.08)
    -- sight aperture & coax MG
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:cylinderX(0.38, 0.46, 0.1, -0.38, 0.07, 0.07, 6)
    mb:cylinderX(0.38, 0.58, -0.05, 0.38, 0.04, 0.04, 5)
    -- snow on top of the mantlet
    mb:material("snow"):color(0.95, 0.97, 1)
    mb:box(0.1, 0.34, -0.55, 0.38, 0.37, 0.4)
    return mb:build()
end

-- gun breech (gun-local, inside the turret)
function TM.buildBreech()
    local mb = MB.new(42)
    mb.texScale = 1.0
    mb.maxEdge = 0.4
    mb:material("interior"):color(0.62, 0.6, 0.55)
    mb:box(-1.05, -0.24, -0.25, -0.1, 0.24, 0.25)
    mb:material("steel"):color(1.4, 1.4, 1.35)
    mb:box(-1.07, -0.2, -0.2, -1.05, 0.2, 0.2)
    mb:material("interior"):color(0.85, 0.82, 0.75)
    mb:cylinderX(-0.95, -0.1, 0.33, 0, 0.08, 0.08, 6)
    mb:cylinderX(-0.95, -0.1, -0.33, 0, 0.08, 0.08, 6)
    mb:material("steel"):color(0.45, 0.45, 0.43)
    -- breech block handle
    mb:box(-1.1, 0.0, 0.25, -0.9, 0.06, 0.45)
    -- recoil guard frame
    mb:material("interior"):color(0.8, 0.78, 0.7)
    mb:box(-1.75, -0.32, 0.32, -0.6, -0.27, 0.37)
    mb:box(-1.75, -0.32, -0.37, -0.6, -0.27, -0.32)
    mb:box(-1.78, -0.32, -0.37, -1.73, -0.0, 0.37)
    -- spent case bag
    mb:material("cloth"):color(0.6, 0.6, 0.5)
    mb:box(-1.7, -0.55, -0.25, -1.2, -0.32, 0.25)
    -- inner mantlet plate
    mb:material("interior"):color(0.85, 0.82, 0.75)
    mb:box(-0.12, -0.32, -0.45, -0.08, 0.32, 0.45)
    return mb:build()
end

-- commander cupola hatch lid (hinge-local: lid extends along +x from hinge)
function TM.buildHatch()
    local mb = MB.new(51)
    mb:material("tank"):color(0.88, 0.88, 0.85)
    mb:cylinder(0.36, 0.0, 0, 0.37, 0.06, 0.36, 10)
    mb:material("interior"):color(0.85, 0.8, 0.7)
    mb:cylinder(0.36, -0.01, 0, 0.33, 0.0, 0.33, 10)
    mb:material("metal"):color(0.4, 0.4, 0.4)
    mb:box(0.25, -0.12, -0.05, 0.45, -0.01, 0.05)
    mb:box(-0.05, -0.04, -0.15, 0.05, 0.06, 0.15)
    mb:material("snow"):color(0.95, 0.97, 1)
    mb:cylinder(0.4, 0.06, 0.02, 0.24, 0.09, 0.2, 8)
    return mb:build()
end

-- bow MG (MG-local: origin at the ball centre, +x out of the hull)
function TM.buildMGExterior()
    local mb = MB.new(61)
    mb:material("metal"):color(0.3, 0.3, 0.3)
    mb:cylinderX(0.1, 0.62, 0, 0, 0.045, 0.035, 6)
    mb:cylinderX(0.15, 0.4, 0, 0, 0.065, 0.065, 6)
    return mb:build()
end

function TM.buildMGInterior()
    local mb = MB.new(62)
    mb:material("steel"):color(0.32, 0.32, 0.3)
    mb:box(-0.75, -0.07, -0.05, -0.05, 0.07, 0.05)
    mb:box(-1.0, -0.1, -0.04, -0.75, 0.03, 0.04)     -- stock
    mb:box(-0.55, -0.22, -0.03, -0.48, -0.07, 0.03)  -- grip
    mb:box(-0.35, 0.07, -0.02, -0.2, 0.12, 0.02)
    -- KZ sight
    mb:box(-0.6, 0.07, -0.13, -0.15, 0.15, -0.07)
    mb:material("cloth"):color(0.55, 0.5, 0.4)
    mb:box(-0.4, -0.3, 0.05, -0.15, -0.05, 0.2)       -- belt bag
    mb:material("brass"):color(1, 1, 1)
    mb:box(-0.32, -0.12, 0.05, -0.28, -0.04, 0.1)
    mb:material("interior"):color(0.85, 0.8, 0.7)
    mb:sphere(0, 0, 0, 0.17, 0.17, 0.17, 7, 4)
    return mb:build()
end

function TM.buildLever()
    local mb = MB.new(71)
    mb:material("steel"):color(0.4, 0.4, 0.38)
    mb:box(-0.025, 0, -0.025, 0.025, 0.6, 0.025)
    mb:material("cloth"):color(0.5, 0.4, 0.3)
    mb:box(-0.035, 0.5, -0.035, 0.035, 0.65, 0.035)
    return mb:build()
end

return TM
