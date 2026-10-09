-- Imported PSX asset test: love . --psxtest
-- Visits the fuel station, the roadside wrecks and the new creatures and saves screenshots.
local A = {}
local G
love.keyboard.isDown = function() return false end
love.mouse.isDown = function() return false end

local steps, idx, stepT = {}, 1, 0
local function S(dur, fn, shot) steps[#steps + 1] = { dur = dur, fn = fn, shot = shot } end

local function view(x, z, tx, ty, tz, up)
    local Pl = G.player
    Pl.placeWalking("world", x, G.world.height(x, z) + 0.1 + (up or 0), z, 0)
    G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
    local ex, ey, ez = Pl.eyeWorld()
    local dx, dy, dz = tx - ex, ty - ey, tz - ez
    Pl.yaw = math.atan2(dz, dx)
    Pl.pitch = math.atan2(dy, math.sqrt(dx * dx + dz * dz))
end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.helpT = nil
    G.game.godMode = true
    G.environment.time = 12
    if G.weather then G.weather.intensity = 0 end
    local W, C = G.world, G.creatures
    local L = W.station
    local y = W.height(L.x, L.z)
    S(0.6, function() view(L.x - 22, L.z - 14, L.x, y + 2, L.z) end, "psx_1_station")
    S(0.4, function() view(L.x - 9, L.z + 1, L.x + 9, y + 1.5, L.z) end, "psx_2_shopfront")
    S(0.4, function() view(L.x + 12, L.z, L.x + 9, y + 1.4, L.z - 3) end, "psx_3_shop_inside")
    S(0.4, function() view(L.x - 12, L.z + 9, L.x - 3, y + 1, L.z + 4) end, "psx_4_pumps")
    S(1.2, function()
        view(L.x - 20, L.z + 20, L.x - 20, y + 1, L.z + 26)
        for _, c in ipairs(C.list) do
            if c.kind == "zombie" then c.x, c.z, c.y = L.x - 21 + #c.kind * 0, L.z + 24.5, W.height(L.x - 21, L.z + 24.5) break end
        end
    end)
    S(1.0, function() end, "psx_5_walker")
    S(0.3, function()
        local n, zc, sp = 0, 0, 0
        for _, c in ipairs(C.list) do if c.kind == "zombie" then zc = zc + 1 elseif c.kind == "spider" then sp = sp + 1 end end
        print("[psx] creatures near station: walkers", zc, "spiders", sp, "total", #C.list)
        local F = W.forest
        view(F.x + 62 - 9, F.z - 58, F.x + 62, W.height(F.x + 62, F.z - 58) + 0.6, F.z - 58)
    end)
    S(2.5, function() end, "psx_6_spider_nest")
    S(0.5, function() view(30, 160, 36, W.height(36, 168) + 0.7, 168) end, "psx_7_road_wreck")
    S(0.8, function() view(L.x - 14, L.z + 2, L.x, y + 1.6, L.z + 2) G.weapons.switch("shotgun") end, "psx_8_shotgun")
    S(0.12, function() G.weapons.fire() end, "psx_9_shotgun_fire")
    S(0.3, function() print("[psx] shotgun mag", G.weapons.mag.shotgun, "shells", G.inventory.player:count("shotgun_ammo")) end, "psx_10_shotgun_pump")
    S(0.8, function() G.weapons.switch("pistol") end, "psx_11_pistol")
    S(0.1, function() G.weapons.fire() end, "psx_12_pistol_fire")
    S(0.4, function() G.environment.time = 5.6 end)
    S(0.6, function() view(L.x - 30, L.z - 30, L.x, y + 3, L.z) end, "psx_13_dawn_mist")
    S(0.3, function()
        local s = 0
        for _, c in ipairs(C.list) do if c.kind == "spider" then s = s + 1 end end
        print("[psx] spiders spawned", s, " draws", G.renderer.stats.draws, "tris", G.renderer.stats.tris)
        print("[psx] DONE  screenshots in " .. love.filesystem.getSaveDirectory())
        love.event.quit()
    end)
end

function A.update(dt)
    local st = steps[idx]
    if not st then return end
    if stepT == 0 and st.fn then st.fn() end
    stepT = stepT + dt
    if stepT >= st.dur then
        if st.shot then love.graphics.captureScreenshot(st.shot .. ".png") end
        idx, stepT = idx + 1, 0
    end
end

function A.draw() end
return A
