-- Camera state shared by the renderer: position, orientation, fov, shake and smoothing.
local U = require("src.utils")

local C = {
    x = 0, y = 0, z = 0, fx = 1, fy = 0, fz = 0, ux = 0, uy = 1, uz = 0,
    fov = math.rad(70), baseFov = math.rad(70), near = 0.04, far = 1400,
    shakeAmt = 0, shakeT = 0, offX = 0, offY = 0, offZ = 0,
}

function C.shake(amount)
    C.shakeAmt = math.min(1.5, math.max(C.shakeAmt, amount))
end

-- call when the camera jumps between frames so the change is smoothed
function C.smoothFrom(x, y, z)
    C.offX, C.offY, C.offZ = x - C.x + C.offX, y - C.y + C.offY, z - C.z + C.offZ
    local l = U.len3(C.offX, C.offY, C.offZ)
    if l > 3 then C.offX, C.offY, C.offZ = 0, 0, 0 end
end

function C.update(dt)
    C.shakeT = C.shakeT + dt
    C.shakeAmt = math.max(0, C.shakeAmt - dt * 1.8)
    local k = math.exp(-8 * dt)
    C.offX, C.offY, C.offZ = C.offX * k, C.offY * k, C.offZ * k
end

-- set from position + forward/up, applying shake & smoothing
function C.set(x, y, z, fx, fy, fz, ux, uy, uz)
    local s = C.shakeAmt * C.shakeAmt * 0.08
    local t = C.shakeT
    local sx = (U.noise2(t * 25, 1, 3) - 0.5) * s
    local sy = (U.noise2(t * 25, 7, 3) - 0.5) * s
    local sz = (U.noise2(t * 25, 13, 3) - 0.5) * s
    C.x, C.y, C.z = x + C.offX + sx * 0.3, y + C.offY + sy * 0.3, z + C.offZ + sz * 0.3
    fx, fy, fz = U.norm3(fx + sx, fy + sy, fz + sz)
    C.fx, C.fy, C.fz = fx, fy, fz
    C.ux, C.uy, C.uz = ux, uy, uz
end

return C
