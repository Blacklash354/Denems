-- Life of the frozen land: crows circling over dead places, and distant gunfire, wolves and
-- artillery somewhere out in the snow.
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
    local spots = {}
    for _, id in ipairs({ "city", "industrial", "plant", "base", "tower", "checkpoint", "kolkhoz", "town", "airfield" }) do
        local l = G.world[id]
        if l then spots[#spots + 1] = { l.x, l.z, 35 + (l.r or 50) * 0.08 } end
    end
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

function A.update(dt)
    A.t = A.t + dt
    local pl = G.player
    local px, py, pz = pl.feetWorld()
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
