-- Procedural audio: every sound is synthesised at load time (no asset files needed).
-- Handles 3D positioning, interior muffling, ambience loops and music.
local U = require("src.utils")

local A = { enabled = false, sources = {}, loops = {}, pending = {}, ringT = 0 }
local G
local SR = 22050
local sin, pi, random, exp, floor = math.sin, math.pi, math.random, math.exp, math.floor
local TAU = 2 * pi

---------------------------------------------------------------------------
-- synthesis helpers
---------------------------------------------------------------------------
local function gen(seconds, fn)
    local n = floor(seconds * SR)
    local sd = love.sound.newSoundData(n, SR, 16, 1)
    for i = 0, n - 1 do
        local v = fn(i / SR, i, n)
        if v > 1 then v = 1 elseif v < -1 then v = -1 end
        sd:setSample(i, v)
    end
    return sd
end

local function lowpass(cut)
    local y = 0
    local a = 1 - exp(-TAU * cut / SR)
    return function(x) y = y + (x - y) * a return y end
end
local function highpass(cut)
    local lp = lowpass(cut)
    return function(x) return x - lp(x) end
end
local function noise() return random() * 2 - 1 end
local function brown()
    local b = 0
    return function() b = (b + noise() * 0.08) * 0.995 return b * 3 end
end
local function env(t, a, d) if t < a then return t / a end return exp(-(t - a) / d) end

-- crossfade the end into the start so loops are seamless
local function looped(seconds, fn)
    local fade = 0.25
    local total = seconds + fade
    local raw = gen(total, fn)
    local n = floor(seconds * SR)
    local f = floor(fade * SR)
    local sd = love.sound.newSoundData(n, SR, 16, 1)
    for i = 0, n - 1 do
        local v = raw:getSample(i)
        if i < f then
            local k = i / f
            v = v * k + raw:getSample(n + i) * (1 - k)
        end
        sd:setSample(i, v)
    end
    return sd
end

local function ring(freqs, decay, amp)
    return function(t)
        local s = 0
        for i, f in ipairs(freqs) do s = s + sin(TAU * f * t) * exp(-t / (decay * (1 + i * 0.3))) end
        return s * amp / #freqs
    end
end

local function boom(dur, low, crack, lpCut)
    local lp = lowpass(lpCut or 900)
    local lp2 = lowpass(120)
    return gen(dur, function(t)
        local body = sin(TAU * (low * (1 + 1.5 * exp(-t * 8))) * t) * exp(-t * 2.2)
        local n = noise()
        local c = n * exp(-t * 35) * crack
        local rumble = lp2(n) * 4 * exp(-t * 1.2)
        return (lp(c + n * 0.5 * exp(-t * 4)) * 1.2 + body * 0.8 + rumble) * 0.9
    end)
end

local function crunch(dur, cut, grains)
    local lp = lowpass(cut)
    local hp = highpass(200)
    local times = {}
    for i = 1, grains do times[i] = random() * dur * 0.7 end
    return gen(dur, function(t)
        local e = 0
        for _, g in ipairs(times) do
            local d = t - g
            if d > 0 and d < 0.03 then e = e + exp(-d * 120) end
        end
        return hp(lp(noise() * e)) * 1.6 * env(t, 0.005, dur * 0.5)
    end)
end

local function growl(dur, base, rough, sweep)
    local lp = lowpass(900)
    local ph = 0
    return gen(dur, function(t)
        local f = base * (1 + (sweep or 0) * t / dur) * (1 + 0.15 * sin(TAU * 5 * t))
        ph = ph + f / SR
        local saw = (ph % 1) * 2 - 1
        local am = 0.6 + 0.4 * sin(TAU * (18 + 10 * sin(t * 3)) * t)
        return lp(saw * am + noise() * rough) * env(t, 0.08, dur * 0.4) * 0.9
    end)
end

local function build()
    local S = {}
    -- ambience loops
    do
        local b1, lp, lp2 = brown(), lowpass(500), lowpass(1500)
        S.wind = looped(6, function(t)
            local g = 0.55 + 0.45 * sin(TAU * t / 6) * sin(TAU * t / 2.3 + 1)
            return lp(b1() * 0.6 + noise() * 0.15) * g * 1.4
        end)
        local hp = highpass(400)
        S.blizzard = looped(5, function(t)
            local g = 0.6 + 0.4 * sin(TAU * t / 5 * 2) * sin(TAU * t / 1.7)
            return lp2(hp(noise())) * g * 1.3
        end)
    end
    do
        local lp = lowpass(500)
        local ph = 0
        S.engine = looped(1, function(t)
            local f = 46
            ph = ph + f / SR
            local saw = (ph % 1) * 2 - 1
            local fire = 0.55 + 0.45 * sin(TAU * f * 3 * t) ^ 2
            local s = saw * 0.5 + sin(TAU * f * 2 * t) * 0.3 + sin(TAU * f * 0.5 * t) * 0.4
            return lp(s * fire + noise() * 0.25) * 0.9
        end)
        local lp2 = lowpass(2500)
        S.tracks = looped(1, function(t)
            local k = (t * 9) % 1
            local clank = exp(-k * 30) * (sin(TAU * 900 * t) * 0.5 + noise() * 0.7)
            return lp2(clank + noise() * 0.08) * 0.8
        end)
        S.turret = looped(1, function(t)
            return (sin(TAU * 190 * t) * 0.4 + sin(TAU * 380 * t) * 0.2 + sin(TAU * 571 * t) * 0.1 + noise() * 0.1) * 0.6
        end)
        local bp, hp = lowpass(3000), highpass(800)
        S.static = looped(3, function(t)
            local crackle = random() < 0.002 and noise() * 3 or 0
            return bp(hp(noise())) * (0.5 + 0.3 * sin(TAU * 0.7 * t)) + crackle * 0.3
        end)
        local lp3 = lowpass(1200)
        S.breath = looped(3.2, function(t)
            local p = (t % 1.6) / 1.6
            local e = p < 0.4 and sin(p / 0.4 * pi) or (sin((p - 0.4) / 0.6 * pi) * 0.7)
            return lp3(noise()) * e * 0.5
        end)
    end
    -- weapons
    S.cannon = boom(3.0, 38, 2.0, 1400)
    S.cannon_far = boom(2.5, 32, 0.6, 500)
    S.explosion = boom(3.2, 30, 1.4, 900)
    do
        local lp = lowpass(3500)
        S.mg = gen(0.16, function(t) return (lp(noise()) * exp(-t * 45) * 1.6 + sin(TAU * 90 * t) * exp(-t * 30) * 0.6) end)
        local lp2 = lowpass(2500)
        S.rifle = gen(0.9, function(t) return lp2(noise()) * (exp(-t * 30) * 1.7 + exp(-t * 4) * 0.25) + sin(TAU * 70 * t) * exp(-t * 20) * 0.7 end)
        local lp4 = lowpass(4200)
        S.smg = gen(0.22, function(t) return lp4(noise()) * exp(-t * 38) * 1.3 + sin(TAU * 140 * t) * exp(-t * 35) * 0.5 end)
        local lp3 = lowpass(3000)
        S.pistol = gen(0.5, function(t) return lp3(noise()) * (exp(-t * 40) * 1.4 + exp(-t * 6) * 0.15) end)
    end
    local function clicks(times, freq, dur)
        local lp = lowpass(4000)
        return gen(dur, function(t)
            local s = 0
            for _, c in ipairs(times) do
                local d = t - c
                if d > 0 then s = s + (noise() * 0.6 + sin(TAU * freq * d)) * exp(-d * 60) end
            end
            return lp(s) * 0.8
        end)
    end
    S.bolt = clicks({ 0, 0.12, 0.3, 0.42 }, 1800, 0.6)
    S.reload = clicks({ 0, 0.35, 0.5, 0.9, 1.3 }, 1500, 1.5)
    S.mg_reload = clicks({ 0, 0.3, 0.9, 1.6, 2.2, 2.5 }, 1200, 2.8)
    S.click = clicks({ 0 }, 2500, 0.1)
    S.switch = clicks({ 0, 0.04 }, 1900, 0.15)
    S.ui = clicks({ 0 }, 3000, 0.06)
    -- footsteps & impacts
    S.step_snow = crunch(0.22, 2600, 8)
    S.step_snow2 = crunch(0.2, 2200, 7)
    S.step_hard = gen(0.15, function(t) return (noise() * 0.5 + sin(TAU * 120 * t)) * exp(-t * 40) * 0.8 end)
    S.step_metal = gen(0.35, ring({ 620, 1310, 2150, 2900 }, 0.08, 1.2))
    S.clang = gen(1.6, function(t) return ring({ 180, 433, 721, 1210 }, 0.35, 1.4)(t) + noise() * exp(-t * 25) * 0.6 end)
    S.armor_hit = gen(2.2, function(t) return ring({ 120, 287, 509, 870, 1430 }, 0.5, 1.4)(t) + noise() * exp(-t * 12) * 0.9 + sin(TAU * 50 * t) * exp(-t * 3) * 0.6 end)
    S.ricochet = gen(0.7, function(t) return sin(TAU * (3200 - t * 3500) * t) * env(t, 0.01, 0.25) * 0.5 + noise() * exp(-t * 50) * 0.5 end)
    do
        local lp = lowpass(800)
        S.impact_snow = gen(0.3, function(t) return lp(noise()) * exp(-t * 18) * 1.4 end)
        local lp2 = lowpass(2000)
        S.impact_hard = gen(0.3, function(t) return lp2(noise()) * exp(-t * 30) * 1.3 + sin(TAU * 300 * t) * exp(-t * 40) * 0.3 end)
        local lp3 = lowpass(600)
        S.flesh = gen(0.3, function(t) return lp3(noise()) * exp(-t * 15) * 1.4 end)
    end
    S.casing = gen(0.4, ring({ 3100, 4500, 6100 }, 0.06, 0.6))
    S.casing_big = gen(1.2, ring({ 520, 1260, 2400 }, 0.25, 1.0))
    -- tank mechanics
    do
        local lp = lowpass(600)
        S.hatch = gen(1.4, function(t)
            local creak = sin(TAU * (210 + 40 * sin(t * 9)) * t + sin(TAU * 31 * t) * 3) * 0.3 * (t < 0.9 and 1 or 0) * env(t, 0.1, 0.6)
            local clunk = t > 0.9 and (lp(noise()) * 2 + sin(TAU * 90 * (t - 0.9))) * exp(-(t - 0.9) * 14) or 0
            return creak + clunk
        end)
        S.ladder = gen(0.3, ring({ 800, 1700, 2600 }, 0.05, 0.8))
        S.seat = gen(0.3, function(t) return lp(noise()) * exp(-t * 20) * 1.5 end)
        local lp2 = lowpass(900)
        local ph = 0
        S.engine_start = gen(2.2, function(t)
            local f = t < 1.3 and (110 + t * 80) or 46
            ph = ph + f / SR
            local saw = (ph % 1) * 2 - 1
            local cough = t > 1.2 and t < 1.6 and noise() * 1.5 * exp(-(t - 1.2) * 6) or 0
            local starter = t < 1.3 and sin(TAU * f * 3 * t) * 0.3 * (0.6 + 0.4 * sin(TAU * 7 * t)) or 0
            return lp2(saw * (t > 1.2 and 0.8 or 0.3) + cough) + starter
        end)
        local ph2 = 0
        S.engine_stop = gen(2.0, function(t)
            local f = 46 * (1 - t / 2.4)
            ph2 = ph2 + f / SR
            return lp2(((ph2 % 1) * 2 - 1) * (1 - t / 2) + noise() * 0.1 * exp(-t * 2))
        end)
        S.shell_load = gen(3.0, function(t)
            local s = 0
            for _, c in ipairs({ 0.2, 0.9, 1.3, 2.6 }) do
                local d = t - c
                if d > 0 then s = s + (ring({ 340, 820, 1500 }, 0.12, 1)(d) + noise() * exp(-d * 40) * 0.6) end
            end
            local slide = (t > 1.3 and t < 2.4) and lp(noise()) * 0.4 or 0
            return s * 0.8 + slide
        end)
        S.breech_close = gen(1.0, function(t) return ring({ 160, 410, 980 }, 0.2, 1.4)(t) + lp(noise()) * exp(-t * 20) * 1.5 end)
        local hp = highpass(1500)
        S.steam = gen(1.5, function(t) return hp(noise()) * env(t, 0.05, 0.6) * 0.6 end)
        S.repair = gen(1.0, function(t)
            local k = (t * 7) % 1
            return (ring({ 1400, 2900 }, 0.03, 1)(k / 7) + noise() * exp(-k * 50) * 0.4) * 0.8
        end)
        S.refuel = gen(1.2, function(t)
            local k = (t * 4) % 1
            return sin(TAU * (180 + k * 200) * t) * exp(-k * 8) * 0.6 + lp(noise()) * 0.15
        end)
        S.door = gen(1.0, function(t)
            local creak = sin(TAU * (330 + 60 * sin(t * 12)) * t + sin(TAU * 47 * t) * 4) * 0.25 * env(t, 0.05, 0.4)
            return creak + (t > 0.7 and lp(noise()) * exp(-(t - 0.7) * 18) * 1.5 or 0)
        end)
        S.door_metal = gen(2.0, function(t)
            local screech = sin(TAU * (140 + 30 * sin(t * 5)) * t + sin(TAU * 23 * t) * 6) * 0.35 * (t < 1.5 and 1 or 0)
            return screech + (t > 1.5 and ring({ 110, 260, 600 }, 0.25, 1.4)(t - 1.5) or 0)
        end)
        S.pickup = gen(0.3, function(t) return lp(noise()) * exp(-t * 15) * 0.8 + sin(TAU * 600 * t) * exp(-t * 30) * 0.3 end)
        local lpw = lowpass(700)
        S.wind_gust = gen(2.5, function(t) return lpw(noise()) * sin(t / 2.5 * pi) * 1.4 end)
        S.creak = gen(2.0, function(t) return sin(TAU * (90 + 25 * sin(t * 2)) * t + sin(TAU * 13 * t) * 5) * sin(t / 2 * pi) * 0.3 end)
    end
    -- creatures
    S.growl = growl(1.2, 75, 0.5, -0.2)
    S.roar = growl(2.4, 48, 0.8, -0.3)
    S.yelp = growl(0.35, 420, 0.2, -0.5)
    S.creature_die = growl(1.5, 120, 0.5, -0.7)
    S.bite = gen(0.4, function(t) return noise() * exp(-t * 30) * 1.2 + sin(TAU * 140 * t) * exp(-t * 10) * 0.5 end)
    S.howl = gen(3.0, function(t)
        local f = 320 + 140 * sin(t / 3 * pi) + 8 * sin(TAU * 6 * t)
        return (sin(TAU * f * t) * 0.6 + sin(TAU * f * 1.51 * t) * 0.2) * sin(t / 3 * pi) * 0.7
    end)
    do
        local hp = highpass(900)
        S.claw_metal = gen(0.8, function(t) return hp(noise()) * env(t, 0.02, 0.2) * 0.9 + ring({ 410, 980 }, 0.15, 0.6)(t) end)
        local lp = lowpass(300)
        S.burrow = gen(1.5, function(t) return lp(noise()) * 3 * env(t, 0.1, 0.5) + noise() * 0.3 * exp(-t * 4) end)
    end
    -- player
    S.hurt = growl(0.35, 140, 0.3, -0.3)
    S.heartbeat = gen(1.0, function(t)
        local a = sin(TAU * 50 * t) * exp(-t * 25)
        local b = t > 0.25 and sin(TAU * 45 * (t - 0.25)) * exp(-(t - 0.25) * 25) * 0.7 or 0
        return (a + b) * 1.2
    end)
    S.geiger = gen(0.02, function(t) return noise() * exp(-t * 400) * 1.5 end)
    S.ring = gen(4.0, function(t) return sin(TAU * 3300 * t) * exp(-t * 0.9) * 0.25 end)
    -- stingers
    S.sting = gen(3.5, function(t)
        local s = sin(TAU * 55 * t) + sin(TAU * 58.3 * t) * 0.8 + sin(TAU * 82.4 * t) * 0.5 + sin(TAU * 116.5 * t) * 0.3
        return s * env(t, 0.05, 1.4) * 0.45 + noise() * exp(-t * 20) * 0.5
    end)
    S.enemy_alert = gen(1.0, ring({ 900, 1350 }, 0.3, 0.4))
    do
        local hp = highpass(1200)
        S.zap = gen(0.9, function(t)
            local crack = (random() < 0.4 and noise() or 0) * exp(-t * 6)
            return hp(crack * 1.5 + noise() * exp(-t * 30)) + sin(TAU * 60 * t) * exp(-t * 5) * 0.4
        end)
        S.detector = gen(0.07, function(t) return sin(TAU * 2600 * t) * exp(-t * 40) * 0.5 end)
        local lp = lowpass(2200)
        S.crow = gen(1.2, function(t)
            local k = (t * 2.5) % 1
            local f = 700 + 300 * sin(t * 20)
            return lp(((t * f) % 1 - 0.5) * 1.5 + noise() * 0.3) * (k < 0.35 and sin(k / 0.35 * pi) or 0) * 0.7
        end)
    end
    -- campfire guitar: Karplus-Strong plucked strings playing a slow minor progression
    do
        local chords = { { 110.0, 164.8, 220.0, 261.6, 329.6 }, { 146.8, 220.0, 293.7, 349.2 },
                         { 82.4, 164.8, 207.7, 246.9, 329.6 }, { 110.0, 164.8, 220.0, 261.6, 329.6 } }
        local dur = 16
        local n = floor(dur * SR)
        local buf = {}
        for i = 0, n - 1 do buf[i] = 0 end
        local function pluck(start, f, amp)
            local period = floor(SR / f)
            local line = {}
            for i = 0, period - 1 do line[i] = (random() * 2 - 1) * amp end
            local idx = 0
            local len = math.min(n - start, floor(SR * 2.5))
            for i = 0, len - 1 do
                local a = line[idx]
                local b = line[(idx + 1) % period]
                local v = (a + b) * 0.5 * 0.996
                line[idx] = v
                idx = (idx + 1) % period
                buf[start + i] = buf[start + i] + a
            end
        end
        local beat = dur / 16
        for bar = 0, 3 do
            local ch = chords[bar + 1]
            for k = 0, 3 do
                local t0 = (bar * 4 + k) * beat
                local note = ch[(k % #ch) + 1]
                pluck(floor(t0 * SR), note, 0.5)
                if k == 0 then pluck(floor(t0 * SR), ch[1] / 2, 0.4) end
                if k == 2 then pluck(floor((t0 + beat * 0.5) * SR), ch[#ch], 0.25) end
            end
        end
        local sd = love.sound.newSoundData(n, SR, 16, 1)
        for i = 0, n - 1 do sd:setSample(i, U.clamp(buf[i] * 0.6, -1, 1)) end
        S.guitar = sd
    end
    S.radar_ping = gen(0.6, function(t) return sin(TAU * 1250 * t) * exp(-t * 7) * 0.35 + sin(TAU * 1250 * (t - 0.15)) * (t > 0.15 and exp(-(t - 0.15) * 7) or 0) * 0.25 end)
    S.notify = gen(0.25, function(t) return sin(TAU * 880 * t) * exp(-t * 18) * 0.3 end)
    -- radio voice syllables
    do
        local lp, hp = lowpass(2600), highpass(300)
        S.voice = gen(2.4, function(t)
            local syl = floor(t * 5)
            local k = (t * 5) % 1
            local f0 = 110 + U.hash2(syl, 1, 4) * 60
            local f1 = 500 + U.hash2(syl, 2, 4) * 900
            local buzz = ((t * f0) % 1) * 2 - 1
            local formant = sin(TAU * f1 * t) * 0.5 + 1
            local gate = (k < 0.75 and U.hash2(syl, 3, 4) > 0.15) and sin(k / 0.75 * pi) or 0
            return hp(lp(buzz * formant * gate + noise() * 0.15)) * 0.9
        end)
    end
    -- ambient music: slow dissonant drone
    do
        local lp = lowpass(400)
        S.music = looped(24, function(t)
            local s = sin(TAU * 36.7 * t) * 0.35 + sin(TAU * 55 * t) * 0.25 * (0.6 + 0.4 * sin(TAU * t / 12))
                + sin(TAU * 87.3 * t) * 0.12 * (0.5 + 0.5 * sin(TAU * t / 8 + 1)) + sin(TAU * 130.8 * t) * 0.06 * (0.5 + 0.5 * sin(TAU * t / 6))
                + sin(TAU * 164.8 * t + sin(TAU * 0.25 * t) * 2) * 0.04
            return (s + lp(noise()) * 0.25) * 0.8
        end)
    end
    return S
end

---------------------------------------------------------------------------
-- runtime
---------------------------------------------------------------------------
local LOOPS = { "wind", "blizzard", "engine", "tracks", "turret", "static", "breath", "music", "guitar" }

function A.init(game, settings)
    G = game
    A.settings = settings
    local ok, err = pcall(function()
        A.data = build()
        -- drop-in replacements: assets/sounds/<name>.ogg|.wav override the synthesised sound
        for name in pairs(A.data) do
            for _, ext in ipairs({ ".ogg", ".wav" }) do
                local path = "assets/sounds/" .. name .. ext
                if love.filesystem.getInfo(path) then
                    local ok, sd = pcall(love.sound.newSoundData, path)
                    if ok then A.data[name] = sd end
                    break
                end
            end
        end
        for name, sd in pairs(A.data) do
            local src = love.audio.newSource(sd, "static")
            A.sources[name] = { src }
        end
        for _, name in ipairs(LOOPS) do
            local s = love.audio.newSource(A.data[name], "static")
            s:setLooping(true)
            s:setVolume(0)
            s:setRelative(true)
            A.loops[name] = { src = s, vol = 0, playing = false }
        end
        love.audio.setDistanceModel("inverseclamped")
    end)
    A.enabled = ok
    if not ok then print("audio disabled: " .. tostring(err)) end
    A.turretLevel = 0
    A.applyVolume()
end

function A.applyVolume()
    if not A.enabled then return end
    pcall(love.audio.setVolume, A.settings.master or 1)
end

local function getSource(name)
    local pool = A.sources[name]
    if not pool then return nil end
    for _, s in ipairs(pool) do
        if not s:isPlaying() then return s end
    end
    if #pool < 8 then
        local s = pool[1]:clone()
        pool[#pool + 1] = s
        return s
    end
    return pool[1]
end

local function playerInside()
    return G.player and G.player.frameName == "tank"
end

-- opts: x,y,z (world position), volume, tank (originates inside the tank), big, delay, pitch
function A.play(name, opts)
    if not A.enabled then return end
    opts = opts or {}
    if opts.delay then
        A.pending[#A.pending + 1] = { t = opts.delay, name = name, opts = { x = opts.x, y = opts.y, z = opts.z, volume = opts.volume, tank = opts.tank, big = opts.big } }
        return
    end
    if name == "step_snow" and random() < 0.5 then name = "step_snow2" end
    local s = getSource(name)
    if not s then return end
    s:stop()
    local vol = (opts.volume or 1) * (A.settings.sfx or 1)
    local inside = playerInside()
    local muffle = false
    if opts.tank then
        -- sound made inside the tank
        if not inside then
            local hatch = G.tank and G.tank.hatchAnim or 0
            vol = vol * (0.25 + 0.5 * hatch)
            muffle = hatch < 0.5
        end
        s:setRelative(true)
        s:setPosition(0, 0, 0)
    elseif opts.x then
        s:setRelative(false)
        s:setPosition(opts.x, opts.y or 0, opts.z)
        s:setAttenuationDistances(opts.big and 25 or 4, opts.big and 1500 or 300)
        if inside and not opts.big then
            vol = vol * 0.45
            muffle = true
        elseif inside then
            vol = vol * 0.9
            muffle = not opts.tankHit
        end
    else
        s:setRelative(true)
        s:setPosition(0, 0, 0)
    end
    pcall(function()
        if muffle then s:setFilter({ type = "lowpass", volume = 1, highgain = 0.12 }) else s:setFilter() end
    end)
    s:setVolume(math.min(1, vol))
    s:setPitch((opts.pitch or 1) * (0.94 + random() * 0.12))
    s:play()
end

-- ear ringing after a cannon shot inside the hull
function A.ring(amount)
    A.ringT = 3
    A.play("ring", { volume = 0.5 * amount })
end

function A.turretMotor(level) A.turretLevel = math.max(A.turretLevel, level) end

local function setLoop(name, vol, pitch, muffle)
    local l = A.loops[name]
    if not l then return end
    vol = U.clamp(vol, 0, 1)
    l.vol = U.damp(l.vol, vol, 6, love.timer.getDelta())
    if l.vol > 0.005 then
        if not l.playing then l.src:play() l.playing = true end
        l.src:setVolume(l.vol)
        if pitch then l.src:setPitch(U.clamp(pitch, 0.2, 4)) end
        if muffle ~= l.muffled then
            l.muffled = muffle
            pcall(function()
                if muffle then l.src:setFilter({ type = "lowpass", volume = 1, highgain = 0.15 }) else l.src:setFilter() end
            end)
        end
    elseif l.playing then
        l.src:stop()
        l.playing = false
    end
end

function A.update(dt, inGame)
    if not A.enabled then return end
    for i = #A.pending, 1, -1 do
        local p = A.pending[i]
        p.t = p.t - dt
        if p.t <= 0 then table.remove(A.pending, i) A.play(p.name, p.opts) end
    end
    local sfx = A.settings.sfx or 1
    local mus = A.settings.music or 0.6
    if not inGame then
        setLoop("wind", 0.35 * sfx, 1, false)
        setLoop("blizzard", 0.12 * sfx, 1, false)
        setLoop("music", 0.5 * mus, 1, false)
        for _, n in ipairs({ "engine", "tracks", "turret", "static", "breath", "guitar" }) do setLoop(n, 0) end
        return
    end
    local cam = G.camera
    love.audio.setPosition(cam.x, cam.y, cam.z)
    love.audio.setOrientation(cam.fx, cam.fy, cam.fz, cam.ux, cam.uy, cam.uz)
    local inside = playerInside()
    local under = G.environment.underground
    local w = G.weather.intensity
    local hatch = G.tank.hatchAnim
    local shelter = inside and (0.3 + 0.4 * hatch) or 1
    if under then shelter = 0.05 end
    setLoop("wind", (0.25 + 0.35 * w) * shelter * sfx, 1 + w * 0.15, inside and hatch < 0.5)
    setLoop("blizzard", math.max(0, w - 0.4) * 0.9 * shelter * sfx, 1, inside and hatch < 0.5)
    local T = G.tank
    -- engine: loud and boomy inside, muffled by distance outside
    local dist = U.dist3(cam.x, cam.y, cam.z, T.x, T.y + 1, T.z)
    local distF = inside and 1 or U.clamp(1 - dist / 140, 0, 1) ^ 1.5
    local engVol = T.engineOn and (0.35 + T.rpm / 3000 * 0.5) or (T.engineStarting > 0 and 0.2 or 0)
    setLoop("engine", engVol * distF * sfx * (inside and 0.9 or 1), 0.55 + T.rpm / 1800, not inside and dist > 25)
    local sp = math.abs(T.speed)
    setLoop("tracks", U.clamp(sp / 6, 0, 1) * 0.6 * distF * sfx, 0.6 + sp / 9, inside)
    A.turretLevel = U.damp(A.turretLevel, 0, 8, dt)
    setLoop("turret", U.clamp(A.turretLevel * 3, 0, 0.6) * sfx * (inside and 1 or 0.3), 0.8 + A.turretLevel, false)
    local radioD = inside and 1 or U.clamp(1 - dist / 12, 0, 1) * (0.2 + hatch * 0.5)
    setLoop("static", (T.radioOn and (G.radio and G.radio.staticLevel or 0.4) or 0) * radioD * sfx, 1, false)
    local pl = G.player
    setLoop("breath", (pl.stamina < 35 and (35 - pl.stamina) / 35 * 0.5 or 0) * sfx + (pl.warmth < 25 and 0.15 or 0), 1, false)
    -- campfire guitar fades with distance to the nearest camp
    local gd = 1e9
    for _, gpos in ipairs(G.world.guitars or {}) do gd = math.min(gd, U.dist3(cam.x, cam.y, cam.z, gpos.x, gpos.y, gpos.z)) end
    setLoop("guitar", U.clamp(1 - gd / 45, 0, 1) ^ 1.5 * 0.7 * mus * (inside and 0.3 or 1), 1, inside)
    local musicVol = (G.game and G.game.musicDuck or 1) * 0.35 * mus * U.clamp(gd / 45, 0, 1)
    setLoop("music", musicVol, 1, false)
    -- geiger counter
    A.geigerT = (A.geigerT or 0) - dt
    local rad = G.survival and G.survival.radLevel or 0
    if rad > 0.05 and A.geigerT <= 0 then
        A.play("geiger", { volume = 0.6 })
        A.geigerT = (0.05 + random() * 0.6) / (0.2 + rad)
    end
    -- heartbeat at low health
    A.heartT = (A.heartT or 0) - dt
    if pl.health < 30 and pl.mode ~= "dead" and A.heartT <= 0 then
        A.play("heartbeat", { volume = 0.8 })
        A.heartT = 0.6 + pl.health / 60
    end
    -- metal creaks inside the hull in the cold
    A.creakT = (A.creakT or 8) - dt
    if A.creakT <= 0 then
        A.creakT = 10 + random() * 25
        if inside then A.play("creak", { tank = true, volume = 0.5 }) end
    end
end

function A.stopAll()
    if not A.enabled then return end
    for _, l in pairs(A.loops) do l.src:stop() l.playing = false l.vol = 0 end
end

return A
