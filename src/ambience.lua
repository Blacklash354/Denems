-- Life of the Zone: anomalies (electro discharges, gravitational vortexes) with a beeping detector,
-- crows circling over dead places, and distant gunfire / howls / explosions.
local U = require("src.utils")
local R = require("src.engine.renderer")
local MB = require("src.engine.meshbuilder")
local M3 = require("src.engine.math3d")

local A = { crows = {}, t = 0 }
local G

function A.init(game)
    G = game
    local mb = MB.new(801)
    mb:material("white"):color(0.06, 0.06, 0.07)
    mb:quadUV(-0.12, 0, -0.02, 0, 0, 0.18, 0, -0.02, 1, 0, 0.18, 0, 0.02, 1, 1, -0.12, 0, 0.02, 0, 1)   -- body
    A.crowBody = mb:build()
    mb = MB.new(802)
    mb:material("white"):color(0.08, 0.08, 0.09)
    mb:quadUV(-0.05, 0, 0, 0, 0, 0.1, 0, 0, 1, 0, 0.06, 0, 0.42, 1, 1, -0.08, 0, 0.38, 0, 1)            -- wing (along +z)
    A.crowWing = mb:build()
    A.mats = {}
    -- flocks over the dead places
    local spots = { { -196, 260, 30 }, { -300, -60, 45 }, { 120, -480, 55 }, { -255, -335, 30 }, { 305, -250, 70 }, { 20, 95, 25 } }
    local rng = U.rng(5)
    for _, s in ipairs(spots) do
        for i = 1, 4 do
            A.crows[#A.crows + 1] = { cx = s[1], cz = s[2], h = s[3] + rng:range(-4, 8), r = rng:range(10, 24), a = rng:range(0, 6.28),
                                      sp = rng:range(0.25, 0.45) * (rng:next() > 0.5 and 1 or -1), flap = rng:range(0, 6) }
        end
    end
    A.distantT = 25
    A.detectorT = 0
end

local function hurtPlayer(amount, kind)
    local pl = G.player
    if pl.frameName == "world" and pl.mode ~= "dead" then pl.hurt(amount, kind) end
end

function A.update(dt)
    A.t = A.t + dt
    local pl = G.player
    local px, py, pz = pl.feetWorld()
    local E = G.effects
    local nearest = 1e9
    for _, an in ipairs(G.world.anomalies) do
        local d = U.dist2(px, pz, an.x, an.z)
        nearest = math.min(nearest, d - an.r)
        an.cool = math.max(0, an.cool - dt)
        if d < 120 then
            if an.kind == "electro" then
                -- idle crackle: rising sparks, a pulsing core and jumping arcs
                for k = 1, 3 do
                    if math.random() < dt * 10 then
                        local a, r = math.random() * 6.28, math.random() * an.r
                        E.spawn(an.x + math.cos(a) * r, an.y + 0.1, an.z + math.sin(a) * r, 0, 1.5 + math.random(), 0, 0.5, 0.06, 0, 0.5, 0.75, 1, 1, true)
                    end
                end
                if math.random() < dt * 4 then
                    E.spawn(an.x, an.y + 1.0, an.z, 0, 0, 0, 0.25, 0.6 + math.random() * 0.5, 2, 0.35, 0.55, 1, 0.5, true)
                end
                if math.random() < dt * 3 then
                    -- a crooked arc between two points of the field
                    local a1, a2 = math.random() * 6.28, math.random() * 6.28
                    local x1, z1 = an.x + math.cos(a1) * an.r * 0.8, an.z + math.sin(a1) * an.r * 0.8
                    local x2, z2 = an.x + math.cos(a2) * 0.4, an.z + math.sin(a2) * 0.4
                    local segs = 6
                    for k = 0, segs - 1 do
                        local t0 = k / segs
                        local px = U.lerp(x1, x2, t0) + (math.random() - 0.5) * 0.6
                        local pz = U.lerp(z1, z2, t0) + (math.random() - 0.5) * 0.6
                        local py = an.y + 0.2 + math.sin(t0 * math.pi) * 1.4 + (math.random() - 0.5) * 0.3
                        E.spawn(px, py, pz, 0, 0, 0, 0.1, 0.14, 0, 0.75, 0.88, 1, 1, true)
                    end
                    E.flash(an.x, an.y + 1, an.z, 6, 0.4, 0.6, 1, 0.8, 0.08)
                end
                if math.random() < dt * 0.25 then
                    E.flash(an.x, an.y + 1, an.z, 8, 0.4, 0.6, 1, 1.5, 0.12)
                    if G.audio then G.audio.play("zap", { x = an.x, y = an.y + 1, z = an.z, volume = 0.5 }) end
                end
                -- discharge on anything that steps in
                local inside = d < an.r and pl.frameName == "world" and math.abs(py - an.y) < 3
                local tankIn = U.dist2(G.tank.x, G.tank.z, an.x, an.z) < an.r + 2
                if (inside or tankIn) and an.cool <= 0 then
                    an.cool = 2.2
                    for i = 1, 18 do
                        E.spawn(an.x, an.y + 1, an.z, (math.random() - 0.5) * 10, math.random() * 8, (math.random() - 0.5) * 10, 0.3, 0.08, 0, 0.6, 0.8, 1, 1, true, 0.5, 4)
                    end
                    E.flash(an.x, an.y + 1.5, an.z, 18, 0.5, 0.7, 1, 4, 0.25)
                    if G.audio then G.audio.play("zap", { x = an.x, y = an.y + 1, z = an.z, big = true }) end
                    if inside then hurtPlayer(28, "anomaly") end
                    if tankIn then G.tank.damage(4, "anomaly") end
                    if G.camera then G.camera.shake(0.5) end
                end
            else
                -- vortex: swirling snow, pulls things in, crushes at the centre
                for i = 1, 4 do
                    if math.random() < dt * 25 then
                        local a, r = A.t * 3 + math.random() * 6.28, an.r * (0.3 + math.random() * 0.7)
                        local p = E.spawn(an.x + math.cos(a) * r, an.y + math.random() * 3, an.z + math.sin(a) * r,
                            -math.sin(a) * 5, 0.5, math.cos(a) * 5, 0.8, 0.15, 0.1, 0.85, 0.88, 0.95, 0.5, false, 1, -0.5)
                    end
                end
                if d < an.r * 2 and pl.frameName == "world" and pl.mode == "walk" then
                    local pull = (1 - d / (an.r * 2)) * 3.5
                    pl.vx = pl.vx + (an.x - px) / math.max(d, 0.1) * pull * dt * 4
                    pl.vz = pl.vz + (an.z - pz) / math.max(d, 0.1) * pull * dt * 4
                    if d < 1.4 and an.cool <= 0 then
                        an.cool = 1.5
                        hurtPlayer(25, "anomaly")
                        for i = 1, 10 do E.snowPuff(an.x, an.y, an.z, 2) end
                        if G.audio then G.audio.play("burrow", { x = an.x, y = an.y, z = an.z }) end
                    end
                end
            end
        end
    end
    -- detector: beeps faster the closer an anomaly is
    A.detectorT = A.detectorT - dt
    A.nearAnomaly = nearest
    if nearest < 18 and pl.frameName == "world" and A.detectorT <= 0 then
        A.detectorT = U.clamp(nearest / 12, 0.08, 1.2)
        if G.audio then G.audio.play("detector", { volume = 0.5 }) end
    end
    -- crows
    for _, c in ipairs(A.crows) do
        c.a = c.a + dt * c.sp
        c.flap = c.flap + dt * 9
    end
    -- the Zone is alive: distant sounds
    A.distantT = A.distantT - dt
    if A.distantT <= 0 then
        A.distantT = 30 + math.random() * 60
        if G.audio and not G.environment.underground then
            local a = math.random() * 6.28
            local x, z = px + math.cos(a) * 400, pz + math.sin(a) * 400
            local r = math.random()
            if r < 0.4 then
                for i = 0, math.random(3, 7) do G.audio.play("smg", { x = x, y = py + 20, z = z, volume = 0.35, delay = i * (0.1 + math.random() * 0.1) }) end
            elseif r < 0.7 then G.audio.play("howl", { x = x, y = py, z = z, volume = 0.6 })
            elseif r < 0.85 then G.audio.play("cannon_far", { x = x, y = py, z = z, volume = 0.5 })
            else G.audio.play("crow", { x = px + math.cos(a) * 40, y = py + 15, z = pz + math.sin(a) * 40 }) end
        end
    end
end

function A.draw()
    local i = 0
    local f, w = M3.frame(), M3.frame()
    for _, c in ipairs(A.crows) do
        local x, z = c.cx + math.cos(c.a) * c.r, c.cz + math.sin(c.a) * c.r
        local y = G.world.height(c.cx, c.cz) + c.h + math.sin(c.a * 3) * 1.5
        if R.visible(x, y, z, 1) then
            local yaw = c.a + (c.sp > 0 and math.pi / 2 or -math.pi / 2)
            f:setYawPitchRoll(yaw, 0, c.sp > 0 and 0.3 or -0.3)
            f.px, f.py, f.pz = x, y, z
            i = i + 1
            A.mats[i] = A.mats[i] or {}
            R.drawModel(A.crowBody, f:matrix(A.mats[i]), { emissive = 0 })
            local fl = math.sin(c.flap) * 0.6
            for side = -1, 1, 2 do
                local wf = M3.frame()
                wf:setYawPitchRoll(side < 0 and math.pi or 0, 0, fl * side)
                wf.px, wf.py, wf.pz = 0.02, 0, 0
                if side < 0 then wf:setYawPitchRoll(math.pi, 0, -fl) wf.px = 0.06 end
                local cf = f:compose(wf, w)
                i = i + 1
                A.mats[i] = A.mats[i] or {}
                R.drawModel(A.crowWing, cf:matrix(A.mats[i]), { emissive = 0 })
            end
        end
    end
end

return A
