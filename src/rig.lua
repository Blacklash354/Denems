-- Rigid-part human figures (the way PlayStation games built their people) and two-bone IK.
-- Each figure is a set of small models: torso (pivot at the hips), head (pivot at the neck),
-- upper arm / forearm (pivot at the joint, the limb runs along +x), thigh / shin (run along -y).
-- Outfits dress the same rig as soldiers, bandits or survivors; the player's own sleeves and
-- gloves for the first-person view come from here too.
local U = require("src.utils")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")

local Rig = {}

Rig.UPPER, Rig.FORE = 0.29, 0.27       -- arm segment lengths (m)
Rig.THIGH, Rig.SHIN = 0.44, 0.44
Rig.SHOULDER = { 0.0, 0.52, 0.215 }    -- right shoulder in torso space (left = -z)
Rig.HIP = 0.1                          -- hip joints at z = +-0.1

-- outfits: colours and pieces per faction look
Rig.OUTFITS = {
    military = { coat = { 0.42, 0.45, 0.32 }, coatMat = "quilt", long = true, pants = { 0.36, 0.38, 0.28 }, boots = { 0.16, 0.15, 0.14 },
                 belt = { 0.32, 0.22, 0.14 }, hat = "ushanka", hatCol = { 0.32, 0.3, 0.26 }, star = true, glove = { 0.22, 0.2, 0.17 },
                 pouches = true, mask = false },
    military_winter = { coat = { 0.82, 0.84, 0.86 }, coatMat = "cloth", long = true, pants = { 0.78, 0.8, 0.82 }, boots = { 0.5, 0.48, 0.45 },
                        belt = { 0.32, 0.22, 0.14 }, hat = "helmet", hatCol = { 0.82, 0.84, 0.86 }, glove = { 0.75, 0.75, 0.72 }, pouches = true },
    bandit = { coat = { 0.16, 0.15, 0.15 }, coatMat = "fur", long = false, pants = { 0.24, 0.26, 0.34 }, boots = { 0.12, 0.11, 0.1 },
               belt = { 0.1, 0.1, 0.1 }, hat = "balaclava", hatCol = { 0.12, 0.12, 0.13 }, glove = { 0.1, 0.1, 0.1 }, stripe = true },
    bandit2 = { coat = { 0.3, 0.22, 0.16 }, coatMat = "fur", long = false, pants = { 0.2, 0.2, 0.22 }, boots = { 0.12, 0.11, 0.1 },
                belt = { 0.1, 0.1, 0.1 }, hat = "cap", hatCol = { 0.2, 0.2, 0.22 }, glove = { 0.15, 0.12, 0.1 } },
    loner = { coat = { 0.4, 0.38, 0.3 }, coatMat = "quilt", long = false, pants = { 0.3, 0.3, 0.27 }, boots = { 0.35, 0.33, 0.3 },
              belt = { 0.25, 0.2, 0.15 }, hat = "hood", hatCol = { 0.36, 0.38, 0.3 }, glove = { 0.3, 0.27, 0.22 }, pack = true, scarf = { 0.5, 0.2, 0.15 } },
    loner2 = { coat = { 0.32, 0.36, 0.4 }, coatMat = "quilt", long = false, pants = { 0.3, 0.28, 0.24 }, boots = { 0.5, 0.48, 0.45 },
               belt = { 0.25, 0.2, 0.15 }, hat = "ushanka", hatCol = { 0.35, 0.28, 0.22 }, glove = { 0.4, 0.35, 0.28 }, pack = true },
    player = { coat = { 0.42, 0.45, 0.32 }, coatMat = "quilt", glove = { 0.26, 0.24, 0.2 } },
}

local function seg(mb, x0, x1, r0, r1, sides)
    -- a tapered limb along +x (8-sided by default)
    mb:cylinderX(x0, x1, 0, 0, r0, r1, sides or 6)
end

-- glove / hand at the end of a forearm, fingers curled round a grip (+x is along the arm)
local function hand(mb, x, col, open)
    mb:material("knit"):color(col[1], col[2], col[3])
    mb:box(x, -0.035, -0.045, x + 0.085, 0.028, 0.045)                    -- palm/back
    if open then
        mb:box(x + 0.085, -0.03, -0.042, x + 0.15, 0.015, 0.042)            -- straight fingers
    else
        mb:box(x + 0.07, -0.062, -0.042, x + 0.11, -0.012, 0.042)           -- curled fingers
        mb:box(x + 0.035, -0.07, -0.04, x + 0.08, -0.04, 0.04)
    end
    mb:box(x + 0.02, -0.02, 0.035, x + 0.075, 0.015, 0.06)                -- thumb
end

-- builds the part models for an outfit name
function Rig.build(outfitName, seed)
    local o = Rig.OUTFITS[outfitName] or Rig.OUTFITS.loner
    local m = {}
    local c = o.coat
    local mb = MB.new(seed or 601)
    mb.texScale = 2
    -- torso: hips + chest + coat skirt
    mb:material(o.coatMat):color(c[1], c[2], c[3])
    local skirt = o.long and -0.5 or -0.2
    mb:hexa({ { -0.13, skirt, -0.21 }, { 0.15, skirt, -0.21 }, { 0.15, skirt, 0.21 }, { -0.13, skirt, 0.21 },
              { -0.12, 0.02, -0.18 }, { 0.13, 0.02, -0.18 }, { 0.13, 0.02, 0.18 }, { -0.12, 0.02, 0.18 } })
    mb:hexa({ { -0.12, 0.0, -0.18 }, { 0.13, 0.0, -0.18 }, { 0.13, 0.0, 0.18 }, { -0.12, 0.0, 0.18 },
              { -0.13, 0.56, -0.24 }, { 0.14, 0.56, -0.24 }, { 0.14, 0.56, 0.24 }, { -0.13, 0.56, 0.24 } })
    mb:color(c[1] * 0.85, c[2] * 0.85, c[3] * 0.85)
    mb:box(-0.1, 0.52, -0.13, 0.12, 0.64, 0.13)                        -- collar
    mb:box(0.135, 0.04, -0.01, 0.15, 0.52, 0.01)                         -- button line
    local b = o.belt or { 0.2, 0.15, 0.1 }
    mb:material("cloth"):color(b[1], b[2], b[3])
    mb:box(-0.14, 0.08, -0.2, 0.155, 0.14, 0.2)                          -- belt
    if o.pouches then
        mb:box(0.13, 0.12, -0.17, 0.19, 0.24, -0.06)                     -- ammo pouches
        mb:box(0.13, 0.12, 0.06, 0.19, 0.24, 0.17)
        mb:box(-0.12, 0.3, -0.14, 0.14, 0.34, -0.1)                      -- strap across the chest
    end
    if o.stripe then
        mb:material("cloth"):color(0.75, 0.75, 0.75)
        mb:box(0.14, 0.2, -0.16, 0.145, 0.52, -0.13)
        mb:box(0.14, 0.2, 0.13, 0.145, 0.52, 0.16)
    end
    if o.scarf then
        mb:material("cloth"):color(o.scarf[1], o.scarf[2], o.scarf[3])
        mb:box(-0.09, 0.56, -0.14, 0.13, 0.66, 0.14)
        mb:box(0.12, 0.3, 0.02, 0.15, 0.6, 0.09)
    end
    if o.pack then
        mb:material("cloth"):color(0.38, 0.34, 0.24)
        mb:box(-0.34, 0.1, -0.17, -0.12, 0.52, 0.17)                     -- rucksack
        mb:material("cloth"):color(0.5, 0.46, 0.36)
        mb:cylinderZ(-0.2, 0.2, -0.24, 0.58, 0.07, 6)                    -- bedroll
    else
        mb:material("cloth"):color(0.3, 0.32, 0.24)
        mb:box(-0.22, 0.05, 0.12, -0.08, 0.25, 0.22)                     -- gas mask bag
    end
    m.torso = mb:build()
    -- head: neck, face, hat
    mb = MB.new((seed or 601) + 1)
    mb:material("flesh"):color(0.85, 0.7, 0.6)
    mb:cylinder(0, 0, 0, 0.055, 0.1, 0.055, 6)
    mb:material("flesh"):color(0.95, 0.8, 0.7)
    mb:box(-0.1, 0.08, -0.085, 0.09, 0.3, 0.085)                         -- skull
    mb:material("face"):color(1, 1, 1)
    mb:quadUV(0.091, 0.08, 0.085, 0, 1, 0.091, 0.08, -0.085, 1, 1, 0.091, 0.29, -0.085, 1, 0, 0.091, 0.29, 0.085, 0, 0)
    local h = o.hatCol or { 0.3, 0.3, 0.3 }
    if o.hat == "ushanka" then
        mb:material("fur"):color(h[1], h[2], h[3])
        mb:box(-0.12, 0.24, -0.11, 0.11, 0.36, 0.11)
        mb:box(-0.11, 0.1, -0.115, 0.06, 0.26, -0.085)                    -- ear flaps
        mb:box(-0.11, 0.1, 0.085, 0.06, 0.26, 0.115)
        mb:box(0.09, 0.25, -0.1, 0.125, 0.33, 0.1)                       -- front flap
        if o.star then
            mb:material("cloth_red"):color(1, 1, 1)
            mb:box(0.126, 0.27, -0.015, 0.13, 0.3, 0.015)
        end
    elseif o.hat == "helmet" then
        mb:material("steel"):color(h[1], h[2], h[3])
        mb:sphere(0.0, 0.25, 0, 0.13, 0.11, 0.12, 8, 4)
        mb:box(-0.13, 0.2, -0.125, 0.12, 0.23, 0.125)
    elseif o.hat == "balaclava" then
        mb:material("knit"):color(h[1], h[2], h[3])
        mb:box(-0.105, 0.075, -0.09, 0.095, 0.315, 0.09)
        mb:material("face"):color(1, 1, 1)
        mb:quadUV(0.096, 0.17, 0.07, 0.15, 0.62, 0.096, 0.17, -0.07, 0.85, 0.62, 0.096, 0.23, -0.07, 0.85, 0.3, 0.096, 0.23, 0.07, 0.15, 0.3)
    elseif o.hat == "cap" then
        mb:material("cloth"):color(h[1], h[2], h[3])
        mb:box(-0.105, 0.25, -0.095, 0.1, 0.32, 0.095)
        mb:box(0.08, 0.25, -0.08, 0.17, 0.27, 0.08)                      -- peak
    elseif o.hat == "hood" then
        mb:material("cloth"):color(h[1], h[2], h[3])
        mb:box(-0.13, 0.05, -0.115, 0.07, 0.35, -0.085)
        mb:box(-0.13, 0.05, 0.085, 0.07, 0.35, 0.115)
        mb:box(-0.13, 0.3, -0.115, 0.08, 0.36, 0.115)
        mb:box(-0.13, 0.05, -0.1, -0.1, 0.33, 0.1)
    end
    m.head = mb:build()
    -- arms: sleeve segments along +x
    mb = MB.new((seed or 601) + 2)
    mb:material(o.coatMat):color(c[1] * 0.95, c[2] * 0.95, c[3] * 0.95)
    seg(mb, -0.03, Rig.UPPER + 0.02, 0.068, 0.058, 6)
    m.upper = mb:build()
    mb = MB.new((seed or 601) + 3)
    mb:material(o.coatMat):color(c[1] * 0.92, c[2] * 0.92, c[3] * 0.92)
    seg(mb, -0.03, Rig.FORE - 0.01, 0.058, 0.05, 6)
    mb:color(c[1] * 0.75, c[2] * 0.75, c[3] * 0.75)
    seg(mb, Rig.FORE - 0.06, Rig.FORE, 0.056, 0.056, 6)                  -- cuff
    hand(mb, Rig.FORE - 0.005, o.glove or { 0.2, 0.2, 0.2 }, false)
    m.fore = mb:build()
    -- legs hang along -y
    mb = MB.new((seed or 601) + 4)
    local p = o.pants or { 0.3, 0.3, 0.3 }
    mb:material("cloth"):color(p[1], p[2], p[3])
    mb:hexa({ { -0.07, -Rig.THIGH, -0.07 }, { 0.07, -Rig.THIGH, -0.07 }, { 0.07, -Rig.THIGH, 0.07 }, { -0.07, -Rig.THIGH, 0.07 },
              { -0.09, 0, -0.09 }, { 0.09, 0, -0.09 }, { 0.09, 0, 0.09 }, { -0.09, 0, 0.09 } })
    m.thigh = mb:build()
    mb = MB.new((seed or 601) + 5)
    mb:material("cloth"):color(p[1] * 0.95, p[2] * 0.95, p[3] * 0.95)
    mb:box(-0.06, -0.3, -0.06, 0.06, 0.0, 0.06)
    local bt = o.boots or { 0.2, 0.18, 0.16 }
    mb:material((outfitName == "loner" or outfitName == "loner2") and "cloth" or "fur"):color(bt[1], bt[2], bt[3])
    mb:box(-0.068, -0.44, -0.066, 0.075, -0.24, 0.066)                  -- boot shaft (valenki / kirza)
    mb:box(-0.07, -0.46, -0.065, 0.16, -0.38, 0.065)                     -- foot
    m.shin = mb:build()
    return m
end

---------------------------------------------------------------------------
-- IK and frames
---------------------------------------------------------------------------
-- elbow position for a shoulder S, hand target T, segment lengths a, b, and a pole direction
function Rig.ik(sx, sy, sz, tx, ty, tz, a, b, px, py, pz)
    local dx, dy, dz = tx - sx, ty - sy, tz - sz
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    local maxD = a + b - 0.002
    if d > maxD then
        -- out of reach: straighten the arm and pull the hand back onto the reachable sphere
        local k = maxD / d
        dx, dy, dz, d = dx * k, dy * k, dz * k, maxD
    end
    d = math.max(d, math.abs(a - b) + 0.01)
    local nx, ny, nz = dx / d, dy / d, dz / d
    local along = (a * a - b * b + d * d) / (2 * d)
    local h = math.sqrt(math.max(0, a * a - along * along))
    -- pole perpendicular to the shoulder-hand axis
    local pd = px * nx + py * ny + pz * nz
    local qx, qy, qz = px - nx * pd, py - ny * pd, pz - nz * pd
    local ql = math.sqrt(qx * qx + qy * qy + qz * qz)
    if ql < 1e-6 then qx, qy, qz, ql = 0, -1, 0, 1 end
    qx, qy, qz = qx / ql, qy / ql, qz / ql
    return sx + nx * along + qx * h, sy + ny * along + qy * h, sz + nz * along + qz * h,
           sx + nx * d, sy + ny * d, sz + nz * d
end

-- frame at A with its forward (+x) pointing at B; up stays close to the hint
function Rig.segFrame(ax, ay, az, bx, by, bz, hx, hy, hz, out)
    out = out or M3.frame()
    local fx, fy, fz = U.norm3(bx - ax, by - ay, bz - az)
    local rx, ry, rz = U.cross(fx, fy, fz, hx, hy, hz)
    local rl = math.sqrt(rx * rx + ry * ry + rz * rz)
    if rl < 1e-5 then rx, ry, rz = U.cross(fx, fy, fz, 0, 0, 1) rl = math.sqrt(rx * rx + ry * ry + rz * rz) end
    rx, ry, rz = rx / rl, ry / rl, rz / rl
    local ux, uy, uz = U.cross(rx, ry, rz, fx, fy, fz)
    out.px, out.py, out.pz = ax, ay, az
    out.fx, out.fy, out.fz = fx, fy, fz
    out.ux, out.uy, out.uz = ux, uy, uz
    out.rx, out.ry, out.rz = rx, ry, rz
    return out
end

-- forearm frame from the elbow to the wrist, with the hand rolled to the given up hint
function Rig.armFrames(sx, sy, sz, tx, ty, tz, px, py, pz, hux, huy, huz, upperOut, foreOut, upper, fore)
    local ex, ey, ez, wx, wy, wz = Rig.ik(sx, sy, sz, tx, ty, tz, upper or Rig.UPPER, fore or Rig.FORE, px, py, pz)
    Rig.segFrame(sx, sy, sz, ex, ey, ez, hux, huy, huz, upperOut)
    Rig.segFrame(ex, ey, ez, wx, wy, wz, hux, huy, huz, foreOut)
    return ex, ey, ez
end

return Rig
