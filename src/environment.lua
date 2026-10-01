-- Time of day, sun, sky and fog colours. Feeds the renderer's environment each frame.
local U = require("src.utils")
local R = require("src.engine.renderer")

local Env = { time = 16.4, daySpeed = 1 / 75, daylight = 1 }
local G

function Env.init(game) G = game end

local function mix3(a, b, t) return { U.lerp(a[1], b[1], t), U.lerp(a[2], b[2], t), U.lerp(a[3], b[3], t) } end

local DAY = { amb = { 0.46, 0.5, 0.6 }, sun = { 0.42, 0.4, 0.38 }, fog = { 0.52, 0.54, 0.6 }, hor = { 0.58, 0.58, 0.62 }, zen = { 0.3, 0.32, 0.38 } }
local DUSK = { amb = { 0.4, 0.36, 0.42 }, sun = { 0.75, 0.42, 0.2 }, fog = { 0.5, 0.43, 0.45 }, hor = { 0.72, 0.48, 0.36 }, zen = { 0.24, 0.22, 0.3 } }
local NIGHT = { amb = { 0.09, 0.1, 0.16 }, sun = { 0.05, 0.06, 0.1 }, fog = { 0.07, 0.08, 0.12 }, hor = { 0.08, 0.09, 0.14 }, zen = { 0.02, 0.025, 0.05 } }

function Env.serialize() return { time = Env.time } end
function Env.load(s) if s and s.time then Env.time = s.time end end

function Env.update(dt)
    -- days are long, nights pass about three times faster
    local h0 = Env.time
    local night = h0 < 6 or h0 > 19
    Env.time = (Env.time + dt * (night and 1 / 40 or 1 / 120)) % 24
    local h = Env.time
    -- sun path: rises ~6, sets ~18.5, low in the sky (nuclear winter)
    local a = (h - 6.2) / 12.3 * math.pi
    local elev = math.sin(a) * 0.55
    local az = -math.cos(a) * 1.3 + math.pi * 0.5
    local sx, sy, sz = math.cos(az) * math.cos(elev), math.sin(elev), -math.sin(az) * math.cos(elev)
    Env.sunElev = elev
    local daylight = U.smoothstep(-0.12, 0.2, elev)
    local dusk = (1 - U.smoothstep(0.08, 0.35, math.abs(elev))) * U.smoothstep(-0.15, 0.0, elev)
    Env.daylight = daylight
    local base = {}
    for k, v in pairs(DAY) do base[k] = mix3(NIGHT[k], v, daylight) end
    for k, v in pairs(DUSK) do base[k] = mix3(base[k], v, dusk * 0.85) end
    local w = G.weather and G.weather.intensity or 0.3
    -- blizzard washes everything into grey
    local grey = { 0.55, 0.57, 0.62 }
    local gk = w * 0.55 * daylight
    base.fog = mix3(base.fog, grey, gk)
    base.hor = mix3(base.hor, base.fog, 0.4 + w * 0.5)
    base.zen = mix3(base.zen, base.fog, w * 0.6)
    local e = R.env
    e.sunDir = { sx, math.max(sy, 0.05), sz }
    e.sunColor = mix3(base.sun, { 0, 0, 0 }, w * 0.5)
    e.ambient = base.amb
    e.fogColor = base.fog
    e.horizon = base.hor
    e.zenith = base.zen
    e.sunGlow = mix3({ 0.15, 0.15, 0.25 }, { 0.95, 0.5, 0.22 }, math.max(dusk, daylight * 0.35) * (1 - w * 0.7))
    local fogEnd = U.lerp(R.drawDist * 0.85, 70, w) * U.lerp(0.65, 1, daylight)
    e.fogStart = U.lerp(16, 4, w)
    e.fogEnd = fogEnd
    e.interiorAmbient = { 0.3, 0.22, 0.15 }
    -- underground / inside overrides
    local pl = G.player
    if pl then
        local cx, cy, cz = G.camera.x, G.camera.y, G.camera.z
        if G.world.isUnderground(cx, cy, cz) then
            e.fogColor = { 0.02, 0.02, 0.025 }
            e.fogStart, e.fogEnd = 3, 34
            e.horizon, e.zenith = e.fogColor, e.fogColor
            e.interiorAmbient = { 0.07, 0.075, 0.08 }
            Env.underground = true
        else
            Env.underground = false
        end
    end
    -- flashlight
    if pl and pl.flashlight and pl.mode ~= "dead" and pl.mode ~= "seat" then
        local c = G.camera
        R.spot = { c.x - c.fx * 0.2 + R.camRight[1] * 0.15, c.y - 0.15, c.z - c.fz * 0.2 + R.camRight[3] * 0.15, 1.6 }
        R.spotDir = { c.fx, c.fy, c.fz, math.cos(0.38) }
    else
        R.spot = { 0, 0, 0, 0 }
    end
end

function Env.clockString()
    local h = math.floor(Env.time)
    local m = math.floor((Env.time - h) * 60)
    return string.format("%02d:%02d", h, m)
end

return Env
