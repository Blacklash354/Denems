-- First-person arms: quilted army sleeves and knitted gloves on a two-bone IK rig. The right hand
-- stays on the grip, the left hand follows a keyframed track: on the handguard, to the magazine,
-- down to the pouch and back with a fresh one, over to the charging handle... so reloads are
-- actually performed by the hands instead of the gun just dipping out of view.
local U = require("src.utils")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")
local R = require("src.engine.renderer")
local Rig = require("src.rig")

local VM = {}

local UPPER, FORE = 0.42, 0.40          -- first-person arm segments (longer than the NPC rig: the camera sits in front of the shoulders)
local SHOULDER_R = { -0.05, -0.29, 0.2 }  -- camera space: forward, up, right
local SHOULDER_L = { -0.05, -0.29, -0.2 }

---------------------------------------------------------------------------
-- models
---------------------------------------------------------------------------
-- sleeves and gloves follow what the player wears
local SLEEVES = {
    telogreika = { "quilt", 0.42, 0.45, 0.38 }, greatcoat = { "quilt", 0.55, 0.57, 0.42 }, sheepskin = { "fur", 0.62, 0.48, 0.32 },
    sweater = { "knit", 0.58, 0.55, 0.5 }, none = { "flesh", 0.95, 0.75, 0.62 },
}
local GLOVES = { gloves = { "knit", 0.34, 0.29, 0.24 }, mittens = { "fur", 0.6, 0.46, 0.32 }, none = { "flesh", 0.95, 0.76, 0.64 } }

local function buildArms(torso, hands)
    local sl = SLEEVES[torso] or SLEEVES.none
    local gl = GLOVES[hands] or GLOVES.none
    local COAT, GLOVE = { sl[2], sl[3], sl[4] }, { gl[2], gl[3], gl[4] }
    local cm, gm = sl[1], gl[1]
    local m = {}
    local mb = MB.new(1701)
    mb.texScale = 3
    mb:material(cm):color(COAT[1], COAT[2], COAT[3])
    mb:cylinderX(-0.05, UPPER + 0.03, 0, 0, 0.062, 0.056, 7)
    m.upper = mb:build()
    mb = MB.new(1702)
    mb.texScale = 3
    mb:material(cm):color(COAT[1] * 0.95, COAT[2] * 0.95, COAT[3] * 0.95)
    mb:cylinderX(-0.04, FORE - 0.05, 0, 0, 0.056, 0.048, 7)
    mb:material(cm):color(COAT[1] * 0.78, COAT[2] * 0.78, COAT[3] * 0.78)
    mb:cylinderX(FORE - 0.07, FORE + 0.005, 0, 0, 0.053, 0.053, 7)     -- turned-back cuff
    mb:material(gm):color(GLOVE[1], GLOVE[2], GLOVE[3])
    mb:cylinderX(FORE - 0.01, FORE + 0.04, 0, 0, 0.045, 0.042, 6)    -- glove wrist
    m.fore = mb:build()
    -- hand frame: +x from the wrist towards the knuckles, +y = back of the hand, +z = thumb side for the right hand
    local function hand(seed, mirror)
        local h = MB.new(seed)
        h.texScale = 6
        local s = mirror and -1 or 1
        h:material(gm):color(GLOVE[1], GLOVE[2], GLOVE[3])
        h:box(-0.055, -0.022, -0.042, 0.035, 0.02, 0.042)                   -- palm
        h:box(0.03, -0.05, -0.04, 0.06, 0.012, 0.04)                         -- knuckles turning down
        h:color(GLOVE[1] * 0.85, GLOVE[2] * 0.85, GLOVE[3] * 0.85)
        h:box(0.0, -0.075, -0.039, 0.045, -0.04, 0.039)                      -- curled fingers
        h:color(GLOVE[1] * 0.95, GLOVE[2] * 0.95, GLOVE[3] * 0.95)
        local z0, z1 = 0.03 * s, 0.06 * s
        h:box(-0.03, -0.035, math.min(z0, z1), 0.03, 0.005, math.max(z0, z1)) -- thumb
        return h:build()
    end
    m.handR = hand(1703, false)
    m.handL = hand(1704, true)
    return m
end

---------------------------------------------------------------------------
-- per-weapon grip data (weapon space: +x muzzle, +y up, +z right) and reload tracks
---------------------------------------------------------------------------
-- hand pose = { position, along (wrist -> knuckles), back (back of the hand) }
local function pose(p, a, b) return { p = p, a = a, b = b } end

VM.RIGS = {
    smg = {   -- AK-74
        grip = pose({ -0.165, -0.065, 0.0 }, { 0.55, -0.6, -0.25 }, { 0.15, 0.3, 1 }),
        guard = pose({ 0.14, -0.045, -0.005 }, { 0.35, 0.35, 0.85 }, { 0.1, -0.8, -0.6 }),
        magTop = { 0.035, -0.02, 0 }, magGrab = pose({ 0.06, -0.12, -0.035 }, { 0.15, 0.3, 1 }, { -0.25, -0.4, -0.85 }),
        charge = pose({ 0.07, 0.045, 0.04 }, { 0.2, -0.4, 1 }, { 0, 1, 0.3 }), chargeTravel = 0.09,
        track = "rifle",
    },
    rifle = { -- M14
        grip = pose({ -0.075, -0.055, 0.0 }, { 0.7, -0.45, -0.25 }, { 0.15, 0.3, 1 }),
        guard = pose({ 0.27, -0.03, -0.005 }, { 0.35, 0.35, 0.85 }, { 0.1, -0.8, -0.6 }),
        magTop = { 0.11, -0.005, 0 }, magGrab = pose({ 0.12, -0.085, -0.035 }, { 0.15, 0.3, 1 }, { -0.25, -0.4, -0.85 }),
        charge = pose({ 0.16, 0.025, 0.035 }, { 0.2, -0.4, 1 }, { 0, 1, 0.3 }), chargeTravel = 0.08,
        track = "rifle",
    },
    pistol = { -- Makarov
        -- held in the right hand; the left one rests out of view and only comes up to reload
        grip = pose({ -0.02, -0.045, 0.0 }, { 0.5, -0.85, -0.2 }, { 0.2, 0.2, 1 }),
        guard = pose({ -0.2, -0.32, -0.22 }, { 0.6, 0.3, 0.3 }, { -0.2, 0.3, -1 }),
        magTop = { 0.0, 0.03, 0 }, magGrab = pose({ -0.005, -0.03, -0.03 }, { 0.2, 0.2, 1 }, { -0.3, -0.5, -0.8 }),
        charge = pose({ -0.035, 0.05, -0.02 }, { 0.6, 0.0, 0.8 }, { 0, 1, -0.2 }), chargeTravel = 0.03,
        track = "pistol",
    },
    shotgun = {
        grip = pose({ -0.095, -0.05, 0.0 }, { 0.7, -0.45, -0.25 }, { 0.15, 0.3, 1 }),
        guard = pose({ 0.36, -0.04, -0.005 }, { 0.35, 0.35, 0.85 }, { 0.1, -0.8, -0.6 }),
        port = pose({ 0.07, -0.07, -0.01 }, { 0.6, 0.6, 0.5 }, { -0.2, -0.6, -0.8 }),
        pumpTravel = 0.09,
        track = "shells",
    },
}

-- keyframes: t (0..1 of the reload), hand anchor, magazine offset/tilt, weapon roll/pitch/drop, bolt
local POUCH = { -0.06, -0.5, -0.16 }
VM.TRACKS = {
    rifle = {
        { t = 0.00, hand = "guard" },
        { t = 0.12, hand = "mag", roll = 0.45, pitch = 0.1, drop = 0.03 },
        { t = 0.20, hand = "mag", mag = { 0.02, -0.05, 0 }, tilt = -0.3, roll = 0.5, pitch = 0.1, drop = 0.03 },
        { t = 0.33, hand = "mag", mag = POUCH, tilt = -0.6, roll = 0.5, pitch = 0.08, drop = 0.03 },
        { t = 0.48, hand = "mag", mag = POUCH, tilt = -0.6, roll = 0.45, pitch = 0.08, drop = 0.03 },
        { t = 0.62, hand = "mag", mag = { 0.03, -0.07, 0 }, tilt = -0.3, roll = 0.45, pitch = 0.1, drop = 0.03 },
        { t = 0.70, hand = "mag", roll = 0.42, pitch = 0.1, drop = 0.05 },
        { t = 0.78, hand = "charge", roll = 0.3, pitch = 0.06, drop = 0.02, empty = true },
        { t = 0.86, hand = "charge", pull = 1, roll = 0.3, pitch = 0.06, drop = 0.02, empty = true },
        { t = 0.90, hand = "charge", roll = 0.28, pitch = 0.06, drop = 0.03, empty = true },
        { t = 1.00, hand = "guard" },
    },
    pistol = {
        { t = 0.00, hand = "guard" },
        { t = 0.14, hand = "mag", roll = 0.35, pitch = 0.2, drop = 0.02 },
        { t = 0.26, hand = "mag", mag = { 0, -0.14, 0 }, roll = 0.35, pitch = 0.2, drop = 0.02 },
        { t = 0.40, hand = "mag", mag = POUCH, tilt = -0.4, roll = 0.35, pitch = 0.15, drop = 0.02 },
        { t = 0.54, hand = "mag", mag = POUCH, tilt = -0.4, roll = 0.35, pitch = 0.15, drop = 0.02 },
        { t = 0.70, hand = "mag", mag = { 0, -0.1, 0 }, roll = 0.35, pitch = 0.2, drop = 0.02 },
        { t = 0.78, hand = "mag", roll = 0.3, pitch = 0.2, drop = 0.04 },
        { t = 0.86, hand = "charge", roll = 0.15, pitch = 0.1, drop = 0.02, empty = true },
        { t = 0.92, hand = "charge", pull = 1, roll = 0.15, pitch = 0.1, drop = 0.02, empty = true },
        { t = 1.00, hand = "guard" },
    },
}

function VM.init()
    VM.armSets = {}
    VM.arms = buildArms("telogreika", "gloves")
    VM.frames = {}
    VM.mats = {}
end

---------------------------------------------------------------------------
-- evaluation helpers
---------------------------------------------------------------------------
local function ease(t) return t * t * (3 - 2 * t) end
local function lerp3(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local ZERO = { 0, 0, 0 }

-- sample a track at t; keys flagged "empty" are skipped on a tactical reload (rounds still in the gun)
local function sample(track, t, empty)
    local keys = {}
    for _, k in ipairs(track) do if empty or not k.empty then keys[#keys + 1] = k end end
    local a, b = keys[1], keys[#keys]
    for i = 1, #keys - 1 do
        if t >= keys[i].t and t <= keys[i + 1].t then a, b = keys[i], keys[i + 1] break end
    end
    local f = b.t > a.t and ease(U.clamp((t - a.t) / (b.t - a.t), 0, 1)) or 1
    local function num(k, name) return k[name] or 0 end
    return {
        handA = a.hand, handB = b.hand, handF = f,
        mag = lerp3(a.mag or ZERO, b.mag or ZERO, f), tilt = U.lerp(num(a, "tilt"), num(b, "tilt"), f),
        roll = U.lerp(num(a, "roll"), num(b, "roll"), f), pitch = U.lerp(num(a, "pitch"), num(b, "pitch"), f),
        drop = U.lerp(num(a, "drop"), num(b, "drop"), f), pull = U.lerp(num(a, "pull"), num(b, "pull"), f),
    }
end
VM.sample = sample

-- hand pose in weapon space for an anchor name
local function anchorPose(rig, name, s)
    if name == "mag" then
        local g = rig.magGrab
        return { p = { g.p[1] + s.mag[1], g.p[2] + s.mag[2], g.p[3] + s.mag[3] }, a = g.a, b = g.b }
    elseif name == "charge" then
        local c = rig.charge
        return { p = { c.p[1] - (rig.chargeTravel or 0.06) * s.pull, c.p[2], c.p[3] }, a = c.a, b = c.b }
    end
    return rig[name] or rig.guard
end

local function blendPose(pa, pb, f)
    return { p = lerp3(pa.p, pb.p, f), a = lerp3(pa.a, pb.a, f), b = lerp3(pa.b, pb.b, f) }
end

-- frame for a hand pose given in weapon space
local function handFrame(wf, ps, out)
    out = out or M3.frame()
    local ax, ay, az = wf:dirToWorld(ps.a[1], ps.a[2], ps.a[3])
    local bx, by, bz = wf:dirToWorld(ps.b[1], ps.b[2], ps.b[3])
    ax, ay, az = U.norm3(ax, ay, az)
    -- make "back" orthogonal to "along"
    local d = ax * bx + ay * by + az * bz
    bx, by, bz = U.norm3(bx - ax * d, by - ay * d, bz - az * d)
    local rx, ry, rz = U.cross(ax, ay, az, bx, by, bz)
    out.fx, out.fy, out.fz = ax, ay, az
    out.ux, out.uy, out.uz = bx, by, bz
    out.rx, out.ry, out.rz = rx, ry, rz
    out.px, out.py, out.pz = wf:toWorld(ps.p[1], ps.p[2], ps.p[3])
    return out
end

local mi = 0
local function mat()
    mi = mi + 1
    VM.mats[mi] = VM.mats[mi] or {}
    return VM.mats[mi]
end
local fi = 0
local function frame()
    fi = fi + 1
    VM.frames[fi] = VM.frames[fi] or M3.frame()
    return VM.frames[fi]
end

-- one arm from a camera-space shoulder to a hand frame
local function drawArm(cam, shoulder, hf, side, params)
    local A = VM.arms
    local rx, ry, rz = R.camRight[1], R.camRight[2], R.camRight[3]
    local sx = cam.x + cam.fx * shoulder[1] + cam.ux * shoulder[2] + rx * shoulder[3]
    local sy = cam.y + cam.fy * shoulder[1] + cam.uy * shoulder[2] + ry * shoulder[3]
    local sz = cam.z + cam.fz * shoulder[1] + cam.uz * shoulder[2] + rz * shoulder[3]
    -- wrist sits behind the palm along the hand
    local wx, wy, wz = hf:toWorld(-0.06, 0, 0)
    -- elbows hang down and out
    local px, py, pz = -cam.ux + rx * side * 0.7, -cam.uy + ry * side * 0.7, -cam.uz + rz * side * 0.7
    local ex, ey, ez, tx, ty, tz = Rig.ik(sx, sy, sz, wx, wy, wz, UPPER, FORE, px, py, pz)
    local uf = Rig.segFrame(sx, sy, sz, ex, ey, ez, cam.ux, cam.uy, cam.uz, frame())
    local ff = Rig.segFrame(ex, ey, ez, tx, ty, tz, hf.ux, hf.uy, hf.uz, frame())
    R.drawModel(A.upper, uf:matrix(mat()), params)
    R.drawModel(A.fore, ff:matrix(mat()), params)
    -- if the arm could not reach, the hand follows the wrist instead of floating
    local gap = U.dist3(tx, ty, tz, wx, wy, wz)
    if gap > 0.002 then
        hf.px, hf.py, hf.pz = hf.px + tx - wx, hf.py + ty - wy, hf.pz + tz - wz
    end
    R.drawModel(side > 0 and A.handR or A.handL, hf:matrix(mat()), params)
end

-- draws both arms for weapon `name` held in frame wf. st: { reload = 0..1 or nil, empty = bool, pump = 0..1, shellPhase = 0..1 }
function VM.drawArms(name, wf, st, params)
    mi, fi = 0, 0
    local key = (st.torso or "none") .. "/" .. (st.hands or "none")
    if not VM.armSets[key] then VM.armSets[key] = buildArms(st.torso or "none", st.hands or "none") end
    VM.arms = VM.armSets[key]
    local rig = VM.RIGS[name]
    if not rig then return end
    local cam = R.cam
    -- right hand on the grip
    local hr = handFrame(wf, rig.grip, frame())
    drawArm(cam, SHOULDER_R, hr, 1, params)
    -- left hand
    local ps
    if rig.track == "shells" then
        local g = rig.guard
        if st.shellPhase then
            -- down to the shell pouch, up into the loading port, push the shell home
            local p = st.shellPhase
            local pouch = { p = { POUCH[1] + 0.12, POUCH[2] + 0.1, POUCH[3] }, a = rig.port.a, b = rig.port.b }
            local push = { p = { rig.port.p[1] + 0.04, rig.port.p[2] + 0.02, rig.port.p[3] }, a = rig.port.a, b = rig.port.b }
            if p < 0.4 then ps = blendPose(rig.port, pouch, ease(p / 0.4))
            elseif p < 0.75 then ps = blendPose(pouch, rig.port, ease((p - 0.4) / 0.35))
            else ps = blendPose(rig.port, push, math.sin((p - 0.75) / 0.25 * math.pi)) end
        else
            ps = { p = { g.p[1] - (rig.pumpTravel or 0.08) * (st.pump or 0), g.p[2], g.p[3] }, a = g.a, b = g.b }
        end
    elseif st.reload then
        local s = st.sample
        ps = blendPose(anchorPose(rig, s.handA, s), anchorPose(rig, s.handB, s), s.handF)
    else
        ps = rig.guard
    end
    local hl = handFrame(wf, ps, frame())
    drawArm(cam, SHOULDER_L, hl, -1, params)
end

-- world frame of the magazine during a reload (rotating about the top of the magazine)
function VM.magFrame(name, wf, s, out)
    local rig = VM.RIGS[name]
    out = out or M3.frame()
    local t = rig.magTop
    local c, sn = math.cos(s.tilt), math.sin(s.tilt)
    local local_ = M3.frame()
    -- rotation about the weapon's z axis (rocking the magazine out of the well)
    local_.fx, local_.fy, local_.fz = c, sn, 0
    local_.ux, local_.uy, local_.uz = -sn, c, 0
    local_.rx, local_.ry, local_.rz = 0, 0, 1
    -- translate so the pivot (mag top) stays put, then add the animated offset
    local px, py = t[1] - (c * t[1] - sn * t[2]), t[2] - (sn * t[1] + c * t[2])
    local_.px, local_.py, local_.pz = px + s.mag[1], py + s.mag[2], s.mag[3]
    return wf:compose(local_, out)
end

return VM
