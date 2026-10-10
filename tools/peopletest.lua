-- People lineup: love . --peopletest
-- Stands one of every figure in a row on open snow (idle, aiming, walking, sitting) and saves screenshots
-- from the front, the side and close up, to check the modelled people and how they hold their rifles.
local A = {}
local G
love.keyboard.isDown = function() return false end
love.mouse.isDown = function() return false end

local steps, idx, stepT = {}, 1, 0
local function S(dur, fn, shot) steps[#steps + 1] = { dur = dur, fn = fn, shot = shot } end

local LOOKS = { "soldier", "soldier_mask", "soldier_winter", "sergeant", "bandit", "bandit_leather", "loner", "loner_farmer", "loner_woman" }
local POSES = { "idle", "aim", "walk", "idle", "aim", "walk", "idle", "aim", "sit" }
local ox, oz, oy

local function look(x, y, z, tx, ty, tz)
    local Pl = G.player
    Pl.placeWalking("world", x, y, z, math.atan2(tz - z, tx - x))
    Pl.pitch = math.atan2(ty - (y + 1.6), math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2))
    G.camera.offX, G.camera.offY, G.camera.offZ = 0, 0, 0
end

function A.start(game)
    G = game
    G.startNewGame()
    G.game.godMode = true
    G.environment.time = 12
    G.weather.intensity, G.weather.target = 0.05, 0.05
    local W = G.world
    G.humans.update = function() end          -- frozen in their poses
    ox, oz = W.START.x + 40, W.START.z - 40
    oy = W.groundHeight(ox, oz)
    local list = G.humans.list
    for i, name in ipairs(LOOKS) do
        local h = list[i]
        h.look = name
        h.x, h.z = ox, oz + (i - 5) * 1.6
        h.y = W.groundHeight(h.x, h.z)
        h.yaw = math.pi                      -- facing -x, towards the camera
        h.state = POSES[i] == "sit" and "sit" or "idle"
        h.aim = POSES[i] == "aim" and 1 or 0
        h.aimPitch = 0
        h.lookYaw = 0
        h.speed = POSES[i] == "walk" and 1.5 or 0
        h.phase = 0.8
        h.hp = 100
    end
    -- everyone else out of the way
    for i = #LOOKS + 1, #list do list[i].x, list[i].z = ox + 500, oz + 500 end
    S(0.8, function() look(ox - 9, oy, oz, ox, oy + 1, oz) end, "people_front")
    S(0.8, function() look(ox - 3, oy, oz - 5.5, ox, oy + 1.2, oz - 5.5) end, "people_close_soldiers")
    S(0.8, function() look(ox - 3, oy, oz + 2.5, ox, oy + 1.2, oz + 2.5) end, "people_close_others")
    S(0.8, function() look(ox - 2.2, oy, oz - 1.3, ox, oy + 1.2, oz - 3) end, "people_close_aim")
    S(0.8, function() look(ox + 0.5, oy, oz - 9, ox, oy + 1, oz) end, "people_side")
    S(0.8, function() look(ox + 6, oy, oz + 1, ox, oy + 1, oz) end, "people_back")
    S(0.3, function()
        print("[people] DONE  screenshots in " .. love.filesystem.getSaveDirectory())
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
