-- Stylised field map generated from the terrain, under a fog of war: only the ground you have seen
-- yourself is drawn; places you have only read or heard about show as "NAME ?".
local U = require("src.utils")
local Map = {}
local G
local lg = love.graphics
local FOG = 96          -- fog cells across the map (about 40 m each)

function Map.init(game)
    G = game
    local W = G.world
    local size = 256
    local data = love.image.newImageData(size, size)
    local span = W.LIMIT * 2 + 40
    local function wp(px, py) return -span / 2 + (px + 0.5) / size * span, -span / 2 + (py + 0.5) / size * span end
    data:mapPixel(function(px, py)
        local x, z = wp(px, py)
        local h = W.height(x, z)
        local hx = W.height(x + 4, z) - h
        local hz = W.height(x, z + 4) - h
        local shade = U.clamp(0.5 - (hx + hz) * 0.12, 0, 1)
        local v = 0.16 + shade * 0.18 + U.clamp(h / 120, 0, 0.12)
        local r, g, b = v * 0.9, v * 0.93, v
        if W.isRiver(x, z) then r, g, b = 0.25, 0.3, 0.38 end
        if U.hash2(px, py, 3) > 0.985 then r, g, b = r + 0.05, g + 0.05, b + 0.05 end
        return r, g, b, 1
    end)
    Map.image = lg.newImage(data)
    Map.image:setFilter("nearest", "nearest")
    Map.span = span
    Map.fogData = love.image.newImageData(FOG, FOG)
    Map.fogImage = lg.newImage(Map.fogData)
    Map.fogImage:setFilter("linear", "linear")
    Map.reset()
end

---------------------------------------------------------------------------
-- fog of war
---------------------------------------------------------------------------
function Map.reset()
    Map.seen = {}
    Map.fogT = 0
    Map.fogData:mapPixel(function() return 0.07, 0.08, 0.09, 1 end)
    Map.fogDirty = true
end

-- clear the fog within r metres of (x, z)
function Map.reveal(x, z, r)
    local cell = Map.span / FOG
    local ci, cj = math.floor((x / Map.span + 0.5) * FOG), math.floor((z / Map.span + 0.5) * FOG)
    local n = math.ceil(r / cell)
    for i = ci - n, ci + n do
        for j = cj - n, cj + n do
            if i >= 0 and j >= 0 and i < FOG and j < FOG then
                local k = j * FOG + i
                if not Map.seen[k] then
                    local wx, wz = (i + 0.5) / FOG * Map.span - Map.span / 2, (j + 0.5) / FOG * Map.span - Map.span / 2
                    if (wx - x) ^ 2 + (wz - z) ^ 2 < r * r then
                        Map.seen[k] = true
                        Map.fogData:setPixel(i, j, 0.07, 0.08, 0.09, 0)
                        Map.fogDirty = true
                    end
                end
            end
        end
    end
end

function Map.update(dt)
    Map.fogT = Map.fogT - dt
    if Map.fogT > 0 then return end
    Map.fogT = 0.5
    local px, py, pz = G.player.feetWorld()
    -- you see further from up on the tank than from the snow
    local r = G.player.frameName == "tank" and 210 or 160
    if G.world.isUnderground(px, py, pz) then r = 25 end
    Map.reveal(px, pz, r)
end

-- run-length string of the seen cells for the save file
function Map.serialize()
    local out, run, cur = {}, 0, false
    for k = 0, FOG * FOG - 1 do
        local v = Map.seen[k] == true
        if v ~= cur then out[#out + 1] = run run, cur = 0, v end
        run = run + 1
    end
    out[#out + 1] = run
    return table.concat(out, ",")
end

function Map.load(s)
    Map.reset()
    if type(s) ~= "string" then return end
    local k, v = 0, false
    for n in s:gmatch("%d+") do
        n = tonumber(n)
        if v then
            for q = k, k + n - 1 do
                Map.seen[q] = true
                Map.fogData:setPixel(q % FOG, math.floor(q / FOG), 0.07, 0.08, 0.09, 0)
            end
        end
        k, v = k + n, not v
    end
    Map.fogDirty = true
end

local function icon(kind, x, y, s, a)
    lg.setColor(0.9, 0.9, 0.85, a)
    lg.setLineWidth(1)
    if kind == "town" then
        for i = -1, 1 do
            lg.rectangle("line", x + i * 5 - 2, y - 1, 4, 5)
            lg.line(x + i * 5 - 3, y - 1, x + i * 5, y - 4, x + i * 5 + 3, y - 1)
        end
    elseif kind == "tower" then
        lg.line(x - 4, y + 6, x, y - 8, x + 4, y + 6)
        lg.line(x - 2.5, y + 1, x + 2.5, y + 1) lg.line(x - 1.5, y - 3, x + 1.5, y - 3)
    elseif kind == "plant" then
        lg.polygon("line", x - 7, y + 5, x - 5, y - 5, x - 1, y - 5, x - 3, y + 5)
        lg.polygon("line", x + 1, y + 5, x + 3, y - 5, x + 7, y - 5, x + 5, y + 5)
    elseif kind == "base" then
        lg.rectangle("line", x - 6, y - 2, 5, 6) lg.rectangle("line", x + 1, y - 2, 5, 6)
        lg.line(x, y - 2, x, y - 9) lg.rectangle("fill", x, y - 9, 4, 2)
    elseif kind == "bunker" then
        lg.arc("line", "open", x, y + 3, 6, math.pi, 2 * math.pi, 8)
        lg.line(x - 6, y + 3, x + 6, y + 3) lg.rectangle("fill", x - 1.5, y - 1, 3, 4)
    elseif kind == "factory" then
        lg.polygon("line", x - 6, y + 5, x - 6, y - 1, x - 2, y + 1, x - 2, y - 1, x + 2, y + 1, x + 2, y - 7, x + 5, y - 7, x + 5, y + 5)
    elseif kind == "forest" then
        for i = -1, 1 do lg.polygon("line", x + i * 5, y - 5 + (i % 2) * 2, x + i * 5 - 3, y + 3, x + i * 5 + 3, y + 3) end
    elseif kind == "camp" then
        lg.polygon("line", x - 6, y + 4, x, y - 5, x + 6, y + 4)
        lg.line(x, y - 5, x, y + 4)
        lg.setColor(1, 0.6, 0.25, a) lg.circle("fill", x + 7, y + 3, 1.5, 6)
    elseif kind == "station" then
        lg.rectangle("line", x - 6, y - 5, 12, 3)
        lg.line(x - 4, y - 2, x - 4, y + 5) lg.line(x + 4, y - 2, x + 4, y + 5)
        lg.rectangle("fill", x - 1, y, 2, 5)
    elseif kind == "checkpoint" then
        lg.line(x - 6, y + 3, x + 6, y - 2) lg.rectangle("line", x - 7, y + 3, 3, 3)
    elseif kind == "city" then
        lg.rectangle("line", x - 7, y - 6, 4, 11) lg.rectangle("line", x - 2, y - 9, 4, 14) lg.rectangle("line", x + 3, y - 4, 4, 9)
    elseif kind == "farm" then
        lg.polygon("line", x - 6, y + 4, x - 6, y - 1, x - 2, y - 5, x + 2, y - 1, x + 2, y + 4)
        lg.rectangle("line", x + 3, y - 6, 3, 10)
    elseif kind == "garage" then
        for i = -1, 1 do lg.rectangle("line", x + i * 5 - 2, y - 2, 4, 5) end
        lg.line(x - 8, y - 3, x + 8, y - 3)
    elseif kind == "airfield" then
        lg.line(x - 7, y, x + 7, y) lg.line(x, y - 3, x, y + 5) lg.line(x - 3, y + 4, x + 3, y + 4)
        lg.line(x - 2, y - 3, x + 2, y - 3)
    end
end

function Map.draw(UI)
    local W = G.world
    local M = G.missions
    lg.setColor(0, 0, 0, 0.8)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    local size = 320
    local x0, y0 = (UI.VW - size) / 2, 22
    UI.panel(x0 - 6, y0 - 16, size + 12, size + 30)
    UI.text("MAP", x0, y0 - 13, UI.COL.amber, UI.fontS)
    UI.text("N", x0 + size - 10, y0 - 13, UI.COL.text, UI.fontS)
    lg.setColor(1, 1, 1, 1)
    lg.draw(Map.image, x0, y0, 0, size / Map.image:getWidth(), size / Map.image:getHeight())
    local function toMap(x, z) return x0 + (x / Map.span + 0.5) * size, y0 + (z / Map.span + 0.5) * size end
    -- roads
    lg.setLineWidth(1)
    for _, path in ipairs(W.roadPaths) do
        local pts = {}
        for i = 1, #path, 4 do
            local mx, my = toMap(path[i].x, path[i].z)
            pts[#pts + 1], pts[#pts + 2] = mx, my
        end
        local mx, my = toMap(path[#path].x, path[#path].z)
        pts[#pts + 1], pts[#pts + 2] = mx, my
        if path.road.mat == "track" then lg.setColor(0.62, 0.58, 0.52, 0.6) else lg.setColor(0.72, 0.7, 0.66, 0.85) end
        if #pts >= 4 then lg.line(pts) end
    end
    -- the ground you have not seen yet
    if Map.fogDirty then Map.fogImage:replacePixels(Map.fogData) Map.fogDirty = false end
    lg.setColor(1, 1, 1, 1)
    lg.draw(Map.fogImage, x0, y0, 0, size / FOG, size / FOG)
    -- grid
    lg.setColor(1, 1, 1, 0.06)
    for i = 1, 7 do
        lg.line(x0 + i * size / 8, y0, x0 + i * size / 8, y0 + size)
        lg.line(x0, y0 + i * size / 8, x0 + size, y0 + i * size / 8)
    end
    for _, l in ipairs(W.locations) do
        local mx, my = toMap(l.x, l.z)
        if M.discovered[l.id] then
            icon(l.icon, mx, my, 1, 1)
            UI.text(l.name, mx + 9, my - 5, UI.COL.text, UI.fontS)
        elseif M.revealed[l.id] then
            -- heard of, not seen: a rough guess in the fog
            icon(l.icon, mx, my, 1, 0.45)
            UI.text(l.name .. " ?", mx + 9, my - 5, UI.COL.amber, UI.fontS)
        end
    end
    -- objective marker
    local tx, tz = UI.objectiveTarget()
    if tx then
        local mx, my = toMap(tx, tz)
        local p = 4 + math.sin(love.timer.getTime() * 5) * 1.5
        lg.setColor(0.95, 0.72, 0.3, 0.9)
        lg.circle("line", mx, my, p + 4, 12)
    end
    -- tank and player
    local T = G.tank
    local tx2, ty2 = toMap(T.x, T.z)
    lg.setColor(0.6, 0.8, 0.55, 1)
    lg.push() lg.translate(tx2, ty2) lg.rotate(T.yaw)
    lg.rectangle("line", -4, -2.5, 8, 5) lg.line(0, 0, 6, 0)
    lg.pop()
    local px, py, pz = G.player.feetWorld()
    local cam = G.camera
    local mx, my = toMap(px, pz)
    local a = math.atan2(cam.fz, cam.fx)
    lg.setColor(0.95, 0.3, 0.2, 1)
    lg.polygon("fill", mx + math.cos(a) * 6, my + math.sin(a) * 6, mx + math.cos(a + 2.5) * 4, my + math.sin(a + 2.5) * 4,
        mx + math.cos(a - 2.5) * 4, my + math.sin(a - 2.5) * 4)
    UI.text("TANK", x0 + size + 14, y0 + 10, { 0.6, 0.8, 0.55 }, UI.fontS)
    UI.text("YOU", x0 + size + 14, y0 + 20, { 0.95, 0.3, 0.2 }, UI.fontS)
    UI.text(G.environment.clockString(), x0 + size + 14, y0 + 46, UI.COL.dim, UI.fontS)
    UI.text("[M] CLOSE", x0 + size + 14, y0 + size - 8, UI.COL.dim, UI.fontS)
end

return Map
