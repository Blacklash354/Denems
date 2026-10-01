-- Snowfall (GPU particles), blizzard cycles and wind.
local U = require("src.utils")
local R = require("src.engine.renderer")

local Wt = { intensity = 0.35, target = 0.35, windX = 2, windZ = 1, phaseT = 90 }
local G
local lg = love.graphics

function Wt.init(game)
    G = game
    local n = 3200
    local verts = {}
    local rng = U.rng(7)
    local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } }
    for i = 1, n do
        local x, y, z, s = rng:next(), rng:next(), rng:next(), rng:next()
        for _, c in ipairs(corners) do verts[#verts + 1] = { c[1], c[2], x, y, z, s } end
    end
    Wt.mesh = lg.newMesh({ { "VertexPosition", "float", 2 }, { "FlakeData", "float", 4 } }, verts, "triangles", "static")
    Wt.time = 0
end

function Wt.serialize() return { intensity = Wt.intensity, target = Wt.target, phaseT = Wt.phaseT } end
function Wt.load(s) if s then Wt.intensity, Wt.target, Wt.phaseT = s.intensity or 0.35, s.target or 0.35, s.phaseT or 90 end end

function Wt.update(dt)
    Wt.time = Wt.time + dt
    Wt.phaseT = Wt.phaseT - dt
    if Wt.phaseT <= 0 then
        if Wt.target < 0.6 then
            Wt.target = 0.8 + math.random() * 0.2
            Wt.phaseT = 70 + math.random() * 80
            if G.ui then G.ui.notify("THE WIND IS PICKING UP...") end
        else
            Wt.target = 0.2 + math.random() * 0.3
            Wt.phaseT = 150 + math.random() * 150
        end
    end
    Wt.intensity = U.approach(Wt.intensity, Wt.target, dt * 0.02)
    local a = Wt.time * 0.02
    local speed = 1.5 + Wt.intensity * 9
    Wt.windX, Wt.windZ = math.cos(a) * speed, math.sin(a * 0.7 + 1) * speed
    Wt.gust = U.noise2(Wt.time * 0.3, 0, 9)
end

function Wt.draw()
    local pl = G.player
    if G.environment.underground then return end
    local sh = R.snowShader
    local cam = R.cam
    lg.setShader(sh)
    R.send(sh, "viewProj", "row", R.viewProj)
    R.send(sh, "camPos", { cam.x, cam.y, cam.z })
    R.send(sh, "camRight", R.camRight)
    R.send(sh, "camUp", R.camUp)
    R.send(sh, "time", Wt.time)
    local gust = 1 + (Wt.gust or 0.5) * 0.6
    R.send(sh, "wind", { Wt.windX * gust, 1.2 + Wt.intensity * 1.8, Wt.windZ * gust })
    R.send(sh, "boxSize", 24)
    R.send(sh, "density", 0.3 + Wt.intensity * 0.7)
    R.send(sh, "flipY", -1)
    local cx, cy, cz = cam.x, cam.y, cam.z
    local inTank = pl.frameName == "tank"
    local inBuilding = not inTank and G.world.inShelter(cx, cy, cz)
    R.send(sh, "shelter", (inTank or inBuilding) and 1 or 0)
    R.send(sh, "shelterRadius", inBuilding and 9 or 2.5)
    local d = G.environment.daylight
    lg.setColor(0.75 + 0.25 * d, 0.78 + 0.22 * d, 0.85 + 0.15 * d, 0.85)
    lg.setDepthMode("lequal", false)
    lg.draw(Wt.mesh)
    lg.setDepthMode("lequal", true)
    lg.setColor(1, 1, 1, 1)
    lg.setShader(R.world)
end

return Wt
