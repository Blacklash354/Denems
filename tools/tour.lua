-- World tour: love . --tour
-- Starts a new game and saves screenshots of every place in the open world (and a few interiors).
local A = {}
local G
love.keyboard.isDown = function() return false end
love.mouse.isDown = function() return false end

local steps, idx, stepT = {}, 1, 0
local function S(dur, fn, shot) steps[#steps + 1] = { dur = dur, fn = fn, shot = shot } end

local function view(x, z, tx, ty, tz, up)
    local Pl = G.player
    local y = G.world.height(x, z)
    Pl.placeWalking("world", x, y + 0.1 + (up or 0), z, 0)
    G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
    local ex, ey, ez = Pl.eyeWorld()
    local dx, dy, dz = tx - ex, (ty or ey) - ey, tz - ez
    Pl.yaw = math.atan2(dz, dx)
    Pl.pitch = math.atan2(dy, math.sqrt(dx * dx + dz * dz))
end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 12
    if G.weather then G.weather.intensity = 0.15 G.weather.target = 0.15 end
    local W = G.world
    S(0.8, nil, "tour_00_start_tank")
    S(0.6, function() G.player.placeWalking("world", W.START.x + 8, W.height(W.START.x + 8, W.START.z + 6) + 0.1, W.START.z + 6, -2.4) end, "tour_01_start_outside")
    for i, l in ipairs(W.locations) do
        local a = i * 0.9
        local d = math.min(l.r * 0.7, 120)
        S(0.9, function()
            local x, z = l.x + math.cos(a) * d, l.z + math.sin(a) * d
            view(x, z, l.x, W.height(l.x, l.z) + 3, l.z, 0)
        end, string.format("tour_%02d_%s", i + 1, l.id))
    end
    -- standing on the highway, looking along it
    S(0.8, function()
        local path = W.roadPaths[1]
        local a, b = path[120], path[135]
        G.player.placeWalking("world", a.x, a.h + 0.2, a.z, math.atan2(b.z - a.z, b.x - a.x))
        G.player.pitch = -0.12
    end, "tour_20_road")
    S(0.8, function()
        local path = W.roadPaths[3]
        local a, b = path[40], path[52]
        G.player.placeWalking("world", a.x, a.h + 0.2, a.z, math.atan2(b.z - a.z, b.x - a.x))
        G.player.pitch = -0.12
    end, "tour_21_track")
    -- people: the first soldier, bandit and survivor up close
    -- a few of the character-pack figures too
    S(0.8, function()
        for _, h in ipairs(G.humans.list) do
            if h.look == "Character_28_HM" then
                h.hostile = false
                local c, s2 = math.cos(h.yaw), math.sin(h.yaw)
                view(h.x + c * 3.2 + s2 * 0.6, h.z + s2 * 3.2 - c * 0.6, h.x, h.y + 1.1, h.z)
                break
            end
        end
    end, "tour_26_nbc_soldier")
    S(0.8, function()
        for _, h in ipairs(G.humans.list) do
            if h.look == "Character_21_Police" or h.look == "Character_22_Police" then
                h.hostile = false
                local c, s2 = math.cos(h.yaw), math.sin(h.yaw)
                view(h.x + c * 3.2 + s2 * 0.6, h.z + s2 * 3.2 - c * 0.6, h.x, h.y + 1.1, h.z)
                break
            end
        end
    end, "tour_27_raider")
    for k, f in ipairs({ "military", "bandit", "loner" }) do
        S(0.8, function()
            for _, h in ipairs(G.humans.list) do
                if h.faction == f and not h.squad then
                    h.hostile = false
                    local c, s2 = math.cos(h.yaw), math.sin(h.yaw)
                    view(h.x + c * 3.2 + s2 * 0.6, h.z + s2 * 3.2 - c * 0.6, h.x, h.y + 1.1, h.z)
                    break
                end
            end
        end, "tour_2" .. (1 + k) .. "_" .. f)
    end
    S(0.8, function() G.game.state = "map" end, "tour_25_map")
    S(0.2, function() G.game.state = "play" end)
    -- a panel block: outside, the podyezd, the stairs, a flat upstairs
    local blk
    S(0.1, function()
        for _, b in ipairs(W.blocks) do if b.sections >= 2 and b.floors >= 4 and math.abs(b.x - W.city.x) < 330 then blk = b break end end
        blk = blk or W.blocks[1]
        print("[tour] block", blk.x, blk.z, blk.sections, blk.floors)
    end)
    local function at(lx, ly, lz, tx, ty, tz)
        local c = blk.ctx
        local x, y, z = c:toWorld(lx, ly, lz)
        local ax, ay, az = c:toWorld(tx, ty, tz)
        G.player.placeWalking("world", x, y, z, math.atan2(az - z, ax - x))
        G.player.pitch = math.atan2(ay - (y + 1.6), math.sqrt((ax - x) ^ 2 + (az - z) ^ 2))
        G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
    end
    local function sx() return -blk.sections * 12 / 2 end
    S(0.9, function() at(sx() + 2, 0, -24, sx() + 10, 6, 0) end, "tour_30_block_outside")
    S(0.9, function() at(sx() + 6, 0.4, -7.5, sx() + 6, 1.5, 0) end, "tour_31_podyezd")
    S(0.9, function() at(sx() + 5.2, 0.4, -3.6, sx() + 5.2, 2.0, 1) end, "tour_32_stairs")
    S(0.9, function() at(sx() + 6.5, 0.4 + 2.8, -4.4, sx() + 4.5, 3.6, -4.6) end, "tour_33_landing")
    S(0.9, function() at(sx() + 3.5, 0.4 + 2.8, -3, sx() + 1, 3.6, -5) end, "tour_34_flat")
    S(0.3, function()
        print(string.format("[tour] draws %d tris %d  fps %d", G.renderer.stats.draws, G.renderer.stats.tris, love.timer.getFPS()))
        print(string.format("[tour] containers %d pickups %d doors %d npcs %d colliders %d", #W.containers, #W.pickups, #W.doors, #G.humans.list, #W.colliders.all))
        print(string.format("[tour] lua mem %.1f MB", collectgarbage("count") / 1024))
        print("[tour] DONE  screenshots in " .. love.filesystem.getSaveDirectory())
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
