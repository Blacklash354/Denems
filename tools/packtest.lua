-- User asset pack test: love . --packtest
-- Shows the pack guns, the character figures and the microdistrict, and saves screenshots.
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
    G.renderer.screenFilter = 1
    local W = G.world
    local L = W.camp
    local y = W.height(L.x, L.z)
    S(0.6, function() view(L.x - 6, L.z - 5, L.x, y + 0.9, L.z) G.weapons.switch("rifle") end, "pack_1_camp_rifle")
    S(0.5, function() view(L.x + 15.6, L.z + 1.5, L.x + 13, y + 1.1, L.z + 1) end, "pack_2_guard")
    S(0.7, function() G.weapons.switch("smg") view(L.x + 3, L.z - 4, L.x + 7.2, y + 1.2, L.z - 3) end, "pack_3_trader_ak")
    S(0.7, function() G.weapons.switch("pistol") end, "pack_4_makarov")
    S(0.7, function()
        local C = W.checkpoint
        for _, h in ipairs(G.humans.list) do
            if h.faction == "bandit" then
                view(h.x + math.cos(h.yaw) * 3, h.z + math.sin(h.yaw) * 3, h.x, h.y + 1.1, h.z) h.hostile = false
                break
            end
        end
    end, "pack_6_bandit")
    S(0.2, function()
        local D = W.district
        if D then view(D.x + 44, D.z + 30, D.x, W.height(D.x, D.z) + 9, D.z) end
    end)
    S(0.8, nil, "pack_7_district")
    S(0.2, function()
        local D = W.district
        if D then view(D.x + 6, D.z - 14, D.x - 8, W.height(D.x, D.z) + 1.5, D.z + 2) end
    end)
    S(0.8, nil, "pack_8_district_yard")
    S(0.3, function()
        print("[pack] draws", G.renderer.stats.draws, "tris", G.renderer.stats.tris, "fps", love.timer.getFPS())
        print("[pack] DONE  screenshots in " .. love.filesystem.getSaveDirectory())
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
