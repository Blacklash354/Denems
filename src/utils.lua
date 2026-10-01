-- General helpers shared by every module.
local U = {}

local sqrt, floor, abs, min, max = math.sqrt, math.floor, math.abs, math.min, math.max

function U.clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
function U.lerp(a, b, t) return a + (b - a) * t end
function U.sign(v) if v > 0 then return 1 elseif v < 0 then return -1 end return 0 end
function U.smoothstep(a, b, x)
    local t = U.clamp((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
end
-- frame-rate independent exponential approach
function U.damp(a, b, rate, dt) return b + (a - b) * math.exp(-rate * dt) end
function U.approach(v, target, step)
    if v < target then return min(v + step, target) end
    return max(v - step, target)
end
function U.wrapAngle(a)
    a = a % (2 * math.pi)
    if a > math.pi then a = a - 2 * math.pi end
    return a
end
function U.angleTo(a, b) return U.wrapAngle(b - a) end
function U.dampAngle(a, b, rate, dt) return a + U.angleTo(a, b) * (1 - math.exp(-rate * dt)) end

function U.len3(x, y, z) return sqrt(x * x + y * y + z * z) end
function U.len2(x, z) return sqrt(x * x + z * z) end
function U.dist3(ax, ay, az, bx, by, bz) local dx, dy, dz = ax - bx, ay - by, az - bz return sqrt(dx * dx + dy * dy + dz * dz) end
function U.dist2(ax, az, bx, bz) local dx, dz = ax - bx, az - bz return sqrt(dx * dx + dz * dz) end
function U.norm3(x, y, z)
    local l = sqrt(x * x + y * y + z * z)
    if l < 1e-9 then return 0, 0, 0, 0 end
    return x / l, y / l, z / l, l
end
function U.cross(ax, ay, az, bx, by, bz) return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx end
function U.dot(ax, ay, az, bx, by, bz) return ax * bx + ay * by + az * bz end

-- deterministic random
local Rng = {}
Rng.__index = Rng
function U.rng(seed)
    return setmetatable({ s = (seed or 1) % 2147483647 }, Rng)
end
function Rng:next()
    self.s = (self.s * 16807) % 2147483647
    return self.s / 2147483647
end
function Rng:range(a, b) return a + (b - a) * self:next() end
function Rng:int(a, b) return a + floor(self:next() * (b - a + 1)) end
function Rng:pick(t) return t[self:int(1, #t)] end

-- value noise
local function hash2(ix, iz, seed)
    local n = ix * 374761393 + iz * 668265263 + (seed or 0) * 1442695041
    n = bit.bxor(n, bit.rshift(n, 13)) * 1274126177
    n = bit.bxor(n, bit.rshift(n, 16))
    return (n % 65536) / 65535
end
U.hash2 = hash2
function U.noise2(x, z, seed)
    local ix, iz = floor(x), floor(z)
    local fx, fz = x - ix, z - iz
    fx = fx * fx * (3 - 2 * fx)
    fz = fz * fz * (3 - 2 * fz)
    local a = hash2(ix, iz, seed)
    local b = hash2(ix + 1, iz, seed)
    local c = hash2(ix, iz + 1, seed)
    local d = hash2(ix + 1, iz + 1, seed)
    return (a + (b - a) * fx) * (1 - fz) + (c + (d - c) * fx) * fz
end
function U.fbm(x, z, oct, seed)
    local v, amp, f, tot = 0, 1, 1, 0
    for i = 1, oct do
        v = v + U.noise2(x * f, z * f, (seed or 0) + i * 17) * amp
        tot = tot + amp
        amp = amp * 0.5
        f = f * 2.03
    end
    return v / tot
end

-- distance from point to segment (2D)
function U.distToSegment(px, pz, ax, az, bx, bz)
    local dx, dz = bx - ax, bz - az
    local l2 = dx * dx + dz * dz
    local t = 0
    if l2 > 0 then t = U.clamp(((px - ax) * dx + (pz - az) * dz) / l2, 0, 1) end
    local cx, cz = ax + dx * t, az + dz * t
    return U.dist2(px, pz, cx, cz), t
end

function U.copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = U.copy(v) end
    return o
end

function U.formatTime(s)
    return string.format("%02d:%02d", floor(s / 60), floor(s % 60))
end

-- simple object pool
function U.pool(factory)
    local p = { free = {}, factory = factory }
    function p:get()
        local o = table.remove(self.free)
        if not o then o = self.factory() end
        return o
    end
    function p:put(o) self.free[#self.free + 1] = o end
    return p
end

return U
