-- The walkable interior of the tank: geometry (hull + rotating turret basket),
-- collision boxes, lamp positions and dynamic ammunition racks.
local MB = require("src.engine.meshbuilder")
local TM = require("src.tank_model")

local TI = {}
local pi = math.pi

TI.FLOOR = 0.62
TI.CEIL = 2.28

-- hull interior (tank-local) ---------------------------------------------------
function TI.buildHull()
    local mb = MB.new(101)
    mb.texScale = 1.0
    mb.maxEdge = 0.45
    mb.jitter = 0.05
    local I = "interior"
    -- floor
    mb:material("steel"):color(0.55, 0.52, 0.48)
    mb:room(-1.65, 0.62, -1.35, 3.0, 1.55, 1.35, TM.only("bottom"))
    -- lower walls
    mb:material(I):color(0.95, 0.92, 0.85)
    mb:room(-1.65, 0.62, -1.35, 3.0, 1.55, 1.35, TM.only("left", "right", "front", "back"))
    -- sponson ledges
    mb:quadN(-1.65, 1.55, 1.35, 3.0, 1.55, 1.35, 3.0, 1.55, 1.75, -1.65, 1.55, 1.75, 0, 1, 0)
    mb:quadN(-1.65, 1.55, -1.75, 3.0, 1.55, -1.75, 3.0, 1.55, -1.35, -1.65, 1.55, -1.35, 0, 1, 0)
    -- upper walls (sponson outer walls, firewall)
    mb:room(-1.65, 1.55, -1.75, 3.0, 2.28, 1.75, TM.only("left", "right", "back"))
    -- front upper plate with the driver's slit
    local x = 3.0
    mb:quadN(x, 1.55, -1.75, x, 1.55, 1.75, x, 1.95, 1.75, x, 1.95, -1.75, -1, 0, 0)
    mb:quadN(x, 2.05, -1.75, x, 2.05, 1.75, x, 2.28, 1.75, x, 2.28, -1.75, -1, 0, 0)
    mb:quadN(x, 1.95, -1.75, x, 1.95, -0.95, x, 2.05, -0.95, x, 2.05, -1.75, -1, 0, 0)
    mb:quadN(x, 1.95, -0.55, x, 1.95, 1.75, x, 2.05, 1.75, x, 2.05, -0.55, -1, 0, 0)
    -- ceiling with the turret ring opening
    mb.maxEdge = nil
    mb:plateHole(-1.65, -1.75, 3.0, 1.75, 2.28, TM.TURRET_PIVOT[1], 0, 1.5, 20, -1)
    mb.maxEdge = 0.45
    -- ring collar seen from inside
    mb:material("steel"):color(0.6, 0.58, 0.55)
    mb:cylinder(TM.TURRET_PIVOT[1], 2.16, 0, 1.52, 2.28, 1.52, 20, false)
    -- frame ribs
    mb:material(I):color(0.8, 0.77, 0.7)
    for rx = -1.2, 2.8, 0.8 do
        mb:box(rx, 0.62, -1.35, rx + 0.06, 1.55, -1.3)
        mb:box(rx, 0.62, 1.3, rx + 0.06, 1.55, 1.35)
        mb:box(rx, 1.55, -1.75, rx + 0.06, 2.28, -1.7)
        mb:box(rx, 1.55, 1.7, rx + 0.06, 2.28, 1.75)
    end
    -- floor plates / turret basket ring
    mb:material("steel"):color(0.42, 0.42, 0.4)
    mb:cylinder(TM.TURRET_PIVOT[1], 0.62, 0, 1.25, 0.64, 1.25, 16, "top")
    mb:material("hazard"):color(0.7, 0.7, 0.7)
    mb:cylinder(TM.TURRET_PIVOT[1], 0.62, 0, 1.3, 0.645, 1.3, 16, false)
    -- escape hatch on floor
    mb:material("steel"):color(0.5, 0.48, 0.45)
    mb:box(2.0, 0.62, -0.25, 2.5, 0.65, 0.25)

    ---------------------------------------------------------------- driver station
    mb:material("cloth"):color(0.45, 0.4, 0.35)
    mb:box(2.0, 0.95, -1.0, 2.45, 1.05, -0.5)        -- seat cushion
    mb:box(1.95, 1.05, -1.0, 2.02, 1.55, -0.5)       -- backrest
    mb:material("steel"):color(0.45, 0.45, 0.43)
    mb:box(2.15, 0.62, -0.8, 2.3, 0.95, -0.7)         -- seat post
    -- instrument panel (left front)
    mb:material(I):color(0.7, 0.68, 0.62)
    mb:box(2.55, 1.55, -1.72, 2.98, 1.95, -1.15)
    mb:material("gauge"):color(1, 1, 1)
    for i = 0, 2 do
        local z = -1.62 + i * 0.16
        mb:quadN(2.549, 1.68, z, 2.549, 1.68, z + 0.13, 2.549, 1.81, z + 0.13, 2.549, 1.81, z, -1, 0, 0)
    end
    mb:material("steel"):color(0.25, 0.25, 0.25)
    mb:box(2.6, 1.57, -1.6, 2.62, 1.62, -1.25)        -- switches
    mb:material("cloth_red"):color(1, 1, 1)
    mb:box(2.53, 1.6, -1.3, 2.56, 1.65, -1.25)        -- starter button
    -- vision block housing
    mb:material(I):color(0.75, 0.72, 0.65)
    mb:box(2.82, 1.88, -1.02, 3.0, 1.93, -0.48)
    mb:box(2.82, 2.07, -1.02, 3.0, 2.12, -0.48)
    mb:box(2.82, 1.93, -1.02, 3.0, 2.07, -0.97)
    mb:box(2.82, 1.93, -0.53, 3.0, 2.07, -0.48)
    mb:material("steel"):color(0.35, 0.35, 0.35)
    mb:box(2.9, 2.12, -0.95, 2.96, 2.2, -0.55)        -- visor handle
    -- pedals
    mb:material("steel"):color(0.4, 0.4, 0.4)
    mb:box(2.75, 0.62, -0.95, 2.85, 0.8, -0.85)
    mb:box(2.75, 0.62, -0.65, 2.85, 0.8, -0.55)
    -- transmission housing between the front seats
    mb:material(I):color(0.8, 0.77, 0.7)
    mb:box(2.3, 0.62, -0.32, 3.0, 1.2, 0.32)
    mb:material("steel"):color(0.4, 0.4, 0.4)
    mb:box(2.4, 1.2, -0.1, 2.46, 1.55, -0.04)          -- gear lever
    mb:box(2.38, 1.5, -0.12, 2.48, 1.58, -0.02)
    ---------------------------------------------------------------- radio operator / MG station
    mb:material("cloth"):color(0.45, 0.4, 0.35)
    mb:box(2.0, 0.95, 0.5, 2.45, 1.05, 1.0)
    mb:box(1.95, 1.05, 0.5, 2.02, 1.55, 1.0)
    mb:material("steel"):color(0.45, 0.45, 0.43)
    mb:box(2.15, 0.62, 0.7, 2.3, 0.95, 0.8)
    -- radio sets on the right sponson
    mb:material("steel"):color(0.42, 0.45, 0.4)
    mb:box(1.9, 1.56, 1.36, 2.7, 2.08, 1.74)
    mb:material("gauge"):color(1, 1, 1)
    mb:quadN(2.0, 1.75, 1.359, 2.18, 1.75, 1.359, 2.18, 1.93, 1.359, 2.0, 1.93, 1.359, 0, 0, -1)
    mb:material("steel"):color(0.2, 0.2, 0.2)
    mb:box(2.3, 1.7, 1.33, 2.4, 1.8, 1.36)
    mb:box(2.48, 1.7, 1.33, 2.58, 1.8, 1.36)
    mb:box(2.25, 1.6, 1.33, 2.6, 1.64, 1.36)
    -- headset hanging
    mb:material("cloth"):color(0.3, 0.28, 0.25)
    mb:box(1.85, 1.55, 1.3, 1.9, 1.75, 1.34)
    -- spare MG barrel tube
    mb:material("steel"):color(0.4, 0.42, 0.38)
    mb:cylinderX(1.0, 1.8, 1.65, 1.6, 0.06, 0.06, 6)
    ---------------------------------------------------------------- rear: firewall storage
    mb:material("wood"):color(0.65, 0.6, 0.55)
    mb:box(-1.65, 0.62, -1.3, -1.3, 0.66, 1.3)
    mb:box(-1.65, 1.2, -1.3, -1.3, 1.24, 1.3)
    mb:box(-1.65, 1.78, -1.3, -1.3, 1.82, 1.3)
    mb:box(-1.65, 0.62, -1.32, -1.3, 2.28, -1.28)
    mb:box(-1.65, 0.62, 1.28, -1.3, 2.28, 1.32)
    mb:box(-1.65, 0.62, -0.02, -1.3, 1.82, 0.02)
    mb:material("crate"):color(0.8, 0.8, 0.75)
    mb:box(-1.62, 0.66, -1.2, -1.32, 0.98, -0.75)
    mb:box(-1.62, 0.66, 0.2, -1.32, 1.0, 0.6)
    mb:box(-1.62, 1.24, -0.6, -1.36, 1.5, -0.15)
    mb:material("steel"):color(0.4, 0.45, 0.35)
    mb:box(-1.62, 0.66, 0.7, -1.33, 1.15, 0.95)       -- jerry can
    mb:material("cloth"):color(0.5, 0.5, 0.4)
    mb:box(-1.6, 1.24, 0.2, -1.35, 1.45, 0.9)         -- blanket roll
    mb:material("brass"):color(1, 1, 1)
    for i = 0, 3 do mb:cylinder(-1.47, 1.82, -1.15 + i * 0.12, 0.04, 2.02, 0.04, 5) end
    -- fire extinguisher, first aid kit
    mb:material("cloth_red"):color(1, 1, 1)
    mb:cylinder(-1.55, 1.9, 1.55, 0.08, 2.25, 0.08, 6)
    mb:material("plaster"):color(1, 1, 1)
    mb:box(1.2, 1.7, -1.74, 1.55, 1.98, -1.66)
    mb:material("cloth_red"):color(1, 1, 1)
    mb:box(1.32, 1.78, -1.661, 1.43, 1.9, -1.659)
    -- switch box & gauges on firewall upper
    mb:material("steel"):color(0.35, 0.37, 0.33)
    mb:box(-1.65, 1.85, 0.95, -1.55, 2.15, 1.3)
    mb:material("gauge"):color(1, 1, 1)
    mb:quadN(-1.549, 1.95, 1.0, -1.549, 1.95, 1.12, -1.549, 2.07, 1.12, -1.549, 2.07, 1.0, 1, 0, 0)
    -- cables along the ceiling edges
    mb:material("cloth"):color(0.25, 0.22, 0.2)
    mb:box(-1.6, 2.2, -1.72, 2.95, 2.24, -1.68)
    mb:box(-1.6, 2.2, 1.68, 2.95, 2.24, 1.72)
    mb:box(2.9, 1.0, -1.32, 2.94, 2.2, -1.28)
    -- pipes
    mb:material("steel"):color(0.5, 0.48, 0.42)
    mb:cylinderX(-1.6, 2.9, 0.75, -1.3, 0.03, 0.03, 5)
    mb:cylinderX(-1.6, 2.9, 0.82, 1.3, 0.03, 0.03, 5)
    -- lamp housings (bulbs are drawn emissive separately)
    mb:material("steel"):color(0.3, 0.3, 0.3)
    mb:box(2.45, 2.18, -0.12, 2.65, 2.28, 0.12)
    mb:box(-1.2, 2.15, -1.0, -1.0, 2.28, -0.75)
    return mb:build()
end

-- turret interior (turret-local) --------------------------------------------------
function TI.buildTurret()
    local mb = MB.new(102)
    mb.texScale = 1.0
    mb.maxEdge = 0.45
    local I = "interior"
    mb:material(I):color(0.95, 0.92, 0.85)
    local c = {
        { -1.65, 0.0, -1.5 }, { 1.5, 0.0, -1.5 }, { 1.5, 0.0, 1.5 }, { -1.65, 0.0, 1.5 },
        { -1.5, 1.0, -1.25 }, { 1.25, 1.0, -1.25 }, { 1.25, 1.0, 1.25 }, { -1.5, 1.0, 1.25 },
    }
    mb:hexaIn(c, { top = true, bottom = true })
    mb.maxEdge = nil
    mb:plateHole(-1.5, -1.25, 1.25, 1.25, 1.0, TM.CUPOLA[1], TM.CUPOLA[3], TM.CUPOLA_R, 12, -1)
    mb:material("steel"):color(0.6, 0.58, 0.55)
    mb:plateHole(-1.65, -1.5, 1.5, 1.5, 0.02, 0, 0, 1.5, 20, 1)
    mb.maxEdge = 0.45
    -- cupola inner wall
    mb:material(I):color(0.85, 0.82, 0.75)
    local C = TM.CUPOLA
    for i = 0, 11 do
        local a0, a1 = i / 12 * 2 * pi, (i + 1) / 12 * 2 * pi
        local r = TM.CUPOLA_R
        mb:quadN(C[1] + math.cos(a0) * r, 1.0, C[3] + math.sin(a0) * r, C[1] + math.cos(a1) * r, 1.0, C[3] + math.sin(a1) * r,
                 C[1] + math.cos(a1) * r, 1.42, C[3] + math.sin(a1) * r, C[1] + math.cos(a0) * r, 1.42, C[3] + math.sin(a0) * r,
                 -math.cos(a0), 0, -math.sin(a0))
    end
    -- ladder under the hatch
    mb:material("steel"):color(0.5, 0.48, 0.45)
    local lx = C[1] - 0.32
    for _, dz in ipairs({ -0.22, 0.22 }) do
        mb:box(lx - 0.03, -1.73, C[3] + dz - 0.03, lx + 0.03, 1.0, C[3] + dz + 0.03)
    end
    for y = -1.5, 0.9, 0.3 do mb:box(lx - 0.025, y, C[3] - 0.22, lx + 0.025, y + 0.04, C[3] + 0.22) end
    -- gunner station (left of the gun)
    mb:material("cloth"):color(0.45, 0.4, 0.35)
    mb:box(0.4, -0.66, -0.88, 0.8, -0.58, -0.4)        -- seat
    mb:box(0.36, -0.58, -0.88, 0.42, -0.2, -0.4)       -- backrest
    mb:material("steel"):color(0.45, 0.45, 0.43)
    mb:box(0.55, -1.73, -0.7, 0.65, -0.66, -0.6)       -- post
    -- sight (TZF) housing and eyepiece
    mb:material(I):color(0.8, 0.77, 0.7)
    mb:box(0.95, 0.15, -0.5, 1.35, 0.36, -0.32)
    mb:material("steel"):color(0.25, 0.25, 0.25)
    mb:cylinderX(0.82, 0.95, 0.27, -0.41, 0.05, 0.06, 6)
    mb:material("cloth"):color(0.55, 0.5, 0.45)
    mb:cylinderX(0.8, 0.84, 0.27, -0.41, 0.065, 0.065, 6)
    -- traverse and elevation handwheels
    mb:material("steel"):color(0.4, 0.4, 0.38)
    mb:push() mb:translate(0.9, -0.15, -0.82) mb:rotateZ(pi / 2.6)
    mb:cylinder(0, -0.02, 0, 0.14, 0.02, 0.14, 8)
    mb:pop()
    mb:push() mb:translate(0.95, -0.05, -0.3) mb:rotateX(pi / 2)
    mb:cylinder(0, -0.02, 0, 0.12, 0.02, 0.12, 8)
    mb:pop()
    mb:material("cloth_red"):color(1, 1, 1)
    mb:box(0.88, 0.0, -0.78, 0.93, 0.05, -0.73)        -- trigger grip
    -- ready rack on the right turret wall
    mb:material(I):color(0.75, 0.72, 0.65)
    mb:box(-0.4, -0.2, 1.2, 0.9, -0.15, 1.45)
    mb:box(-0.4, 0.45, 1.2, 0.9, 0.5, 1.45)
    -- ventilator
    mb:material("steel"):color(0.4, 0.4, 0.4)
    mb:cylinder(0.6, 0.85, 0.0, 0.14, 1.0, 0.14, 8)
    -- loader periscope inner
    mb:box(0.2, 0.75, 0.75, 0.42, 1.0, 0.95)
    -- turret lamp housing
    mb:material("steel"):color(0.3, 0.3, 0.3)
    mb:box(-0.15, 0.9, 0.35, 0.15, 1.0, 0.6)
    -- pistol port
    mb:box(-1.6, 0.3, 0.6, -1.55, 0.5, 0.8)
    -- commander's backrest strap
    mb:material("cloth"):color(0.35, 0.3, 0.25)
    mb:box(-1.45, -0.35, -1.0, -1.4, -0.1, -0.5)
    return mb:build()
end

-- shells lying in the sponson racks: rebuilt whenever the stored ammo changes
function TI.buildRacks(ap, he)
    local mb = MB.new(103)
    mb.jitter = 0.03
    local slots = {}
    for side = -1, 1, 2 do
        for row = 0, 1 do
            for i = 0, 7 do
                slots[#slots + 1] = { side = side, x = -1.25 + i * 0.36, y = 1.62 + row * 0.2, z = side * 1.56 }
            end
        end
    end
    -- rack frames
    mb:material("interior"):color(0.75, 0.72, 0.65)
    for side = -1, 1, 2 do
        mb:box(-1.4, 1.58, side * 1.4 - 0.02, 1.6, 1.6, side * 1.4 + 0.02)
        mb:box(-1.4, 1.98, side * 1.4 - 0.02, 1.6, 2.0, side * 1.4 + 0.02)
    end
    local function shell(s, he)
        local z0, z1 = s.z - s.side * 0.2, s.z + s.side * 0.18
        mb:push()
        mb:translate(s.x, s.y, 0)
        mb:rotateY(-pi / 2)
        -- now local +x points along -z world ... place shell along z
        mb:pop()
        mb:material("brass"):color(1, 1, 1)
        mb:push() mb:translate(s.x, s.y, 0) mb:rotateX(pi / 2)
        -- cylinder along local y which maps to +z
        local zs = math.min(z0, z1)
        mb:cylinder(0, zs, 0, 0.075, zs + 0.3, 0.075, 6, true)
        mb:material(he and "hazard" or "metal"):color(he and 1 or 0.35, he and 1 or 0.35, he and 1 or 0.35)
        mb:cylinder(0, zs + 0.3, 0, 0.065, zs + 0.42, 0.02, 6, true)
        mb:pop()
    end
    -- AP in the left sponson, HE in the right one (overflow to the other side)
    local leftSlots, rightSlots = {}, {}
    for _, s in ipairs(slots) do
        if s.side < 0 then leftSlots[#leftSlots + 1] = s else rightSlots[#rightSlots + 1] = s end
    end
    local used = {}
    local function place(list, n, isHE)
        for _, s in ipairs(list) do
            if n <= 0 then break end
            if not used[s] then used[s] = true shell(s, isHE) n = n - 1 end
        end
        return n
    end
    local restAP = place(leftSlots, ap, false)
    local restHE = place(rightSlots, he, true)
    place(rightSlots, restAP, false)
    place(leftSlots, restHE, true)
    return mb:build()
end

function TI.buildLampBulbs()
    local mb = MB.new(104)
    mb:material("white"):color(1, 0.85, 0.55)
    mb:boxC(2.55, 2.15, 0, 0.1, 0.06, 0.1)
    mb:boxC(-1.1, 2.12, -0.88, 0.08, 0.06, 0.08)
    return mb:build()
end

function TI.buildTurretBulb()
    local mb = MB.new(105)
    mb:material("white"):color(1, 0.85, 0.55)
    mb:boxC(0, 0.86, 0.47, 0.1, 0.06, 0.1)
    return mb:build()
end

function TI.buildRadioDial()
    local mb = MB.new(106)
    mb:material("white"):color(0.9, 0.7, 0.3)
    mb:quadN(2.2, 1.7, 1.355, 2.62, 1.7, 1.355, 2.62, 1.86, 1.355, 2.2, 1.86, 1.355, 0, 0, -1)
    return mb:build()
end

-- lamp positions (tank-local / turret-local)
TI.LAMPS = {
    { frame = "tank", 2.55, 2.1, 0, radius = 3.6, r = 1.0, g = 0.7, b = 0.36, i = 1.7 },
    { frame = "tank", -1.1, 2.05, -0.88, radius = 3.4, r = 1.0, g = 0.64, b = 0.3, i = 1.5 },
    { frame = "turret", 0, 0.8, 0.47, radius = 3.8, r = 1.0, g = 0.68, b = 0.34, i = 1.7 },
}

-- collision ------------------------------------------------------------------
function TI.hullColliders()
    local F, C = TI.FLOOR, TI.CEIL
    local b = {
        { -1.9, 0.3, -2.0, 3.3, F, 2.0 },                 -- floor
        { -1.9, F, 1.35, 3.3, C + 0.3, 2.1 },             -- right walls+sponson
        { -1.9, F, -2.1, 3.3, C + 0.3, -1.35 },           -- left
        { 3.0, F, -2.0, 3.4, C + 0.3, 2.0 },              -- front
        { -2.2, F, -2.0, -1.62, C + 0.3, 2.0 },           -- firewall + shelves
        { -1.65, F, -1.35, -1.3, C, 1.35 },               -- shelves
        { 1.85, C, -2.0, 3.3, C + 0.4, 2.0 },             -- ceiling front
        { -1.9, C, -2.0, -1.15, C + 0.4, 2.0 },           -- ceiling rear
        { 1.95, F, -1.05, 2.48, 1.05, -0.45 },            -- driver seat
        { 1.95, F, 0.45, 2.48, 1.05, 1.05 },              -- MG seat
        { 2.3, F, -0.32, 3.0, 1.2, 0.32 },                -- transmission
    }
    for _, x in ipairs(b) do x.walk = true end
    return b
end

function TI.turretColliders()
    -- turret-local; the floor is at -1.73
    local b = {
        { -0.7, 0.05, -0.45, 1.5, 0.75, 0.45 },          -- breech & guard (overhead)
        { 0.36, -1.73, -0.9, 0.82, -0.58, -0.38 },       -- gunner seat
        { -1.4, -1.73, -1.05, -1.18, 1.0, -0.45 },       -- ladder
        { 0.8, -0.3, -0.95, 1.5, 0.5, -0.25 },           -- gunner controls
        { -1.8, 1.0, -1.6, 1.6, 1.4, 1.6 },              -- turret roof
    }
    for _, x in ipairs(b) do x.walk = false end
    return b
end

return TI
