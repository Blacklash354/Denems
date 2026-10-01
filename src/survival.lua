-- Health, stamina, body temperature and radiation. The tank is shelter from the cold.
local U = require("src.utils")
local S = { radLevel = 0, coldLevel = 0 }
local G

function S.init(game) G = game end

function S.update(dt)
    local pl = G.player
    if pl.mode == "dead" then return end
    local T = G.tank
    local W = G.world
    local w = G.weather.intensity
    local night = 1 - G.environment.daylight
    local x, y, z = pl.feetWorld()
    -- warmth: drains outside, recovers inside the tank (faster with the engine running)
    local rate
    if pl.frameName == "tank" then
        rate = 1.2 + (T.engineOn and 1.4 or 0) - T.hatchAnim * 0.6
        S.shelter = "TANK"
    elseif G.environment.underground or W.inShelter(x, y + 1, z) then
        rate = -0.05
        S.shelter = "BUILDING"
    else
        rate = -(0.14 + w * 0.36 + night * 0.14)
        S.shelter = nil
    end
    -- standing near fires warms
    for _, f in ipairs(W.fires) do
        local d = U.dist3(x, y, z, f.x, f.y, f.z)
        if d < f.r then rate = math.max(rate, 1.6 * (1 - d / f.r) + 0.2) end
    end
    pl.warmth = U.clamp(pl.warmth + rate * dt, 0, 100)
    S.coldLevel = U.clamp((40 - pl.warmth) / 40, 0, 1)
    if pl.warmth <= 15 then pl.hurt(dt * (1.2 - pl.warmth / 15), "cold") end
    -- radiation: the hull blocks most of it
    local rad = W.radiationAt(x, y, z)
    if pl.frameName == "tank" then rad = rad * 0.15 end
    S.radLevel = rad
    pl.radiation = U.clamp(pl.radiation + rad * dt * 0.9 - dt * 0.01, 0, 100)
    if pl.radiation > 60 then pl.hurt(dt * (pl.radiation - 60) / 25, "radiation") end
    -- slow natural healing when warm and not irradiated
    if pl.warmth > 60 and pl.radiation < 30 and pl.health < 100 and pl.health > 0 then
        pl.health = math.min(100, pl.health + dt * 0.15)
    end
end

return S
