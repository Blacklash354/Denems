-- Simple collision: axis-aligned boxes inside (optionally transformed) collider sets,
-- cylinder-vs-box character movement, and ray casting.
local P = {}
local abs, min, max, sqrt, floor = math.abs, math.min, math.max, math.sqrt, math.floor

-- spatial hash grid of boxes ----------------------------------------------------
local Grid = {}
Grid.__index = Grid

function P.newGrid(cell)
    return setmetatable({ cell = cell or 16, cells = {}, all = {}, stamp = 0 }, Grid)
end

local function key(ix, iz) return ix * 100003 + iz end

function Grid:add(b)
    local c = self.cell
    b.enabled = (b.enabled ~= false)
    b._stamp = 0
    self.all[#self.all + 1] = b
    for ix = floor(b[1] / c), floor(b[4] / c) do
        for iz = floor(b[3] / c), floor(b[6] / c) do
            local k = key(ix, iz)
            local list = self.cells[k]
            if not list then list = {} self.cells[k] = list end
            list[#list + 1] = b
        end
    end
    return b
end

function Grid:query(x0, z0, x1, z1, out)
    out = out or {}
    local n = 0
    local c = self.cell
    self.stamp = self.stamp + 1
    local st = self.stamp
    for ix = floor(x0 / c), floor(x1 / c) do
        for iz = floor(z0 / c), floor(z1 / c) do
            local list = self.cells[key(ix, iz)]
            if list then
                for i = 1, #list do
                    local b = list[i]
                    if b._stamp ~= st and b.enabled then
                        b._stamp = st
                        if b[4] >= x0 and b[1] <= x1 and b[6] >= z0 and b[3] <= z1 then
                            n = n + 1
                            out[n] = b
                        end
                    end
                end
            end
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return out, n
end

-- A collider set: boxes in local space + a frame (nil = identity in the caller's space).
-- set = { frame = Frame|nil, boxes = {...} | grid = Grid, enabled = bool }
P.Grid = Grid

local tmp = {}
local function setBoxes(set, lx, lz, r)
    if set.grid then
        return set.grid:query(lx - r, lz - r, lx + r, lz + r, tmp)
    end
    return set.boxes, #set.boxes
end

local function toLocal(set, x, y, z)
    local f = set.frame
    if not f then return x, y, z end
    return f:toLocal(x, y, z)
end
local function dirToParent(set, x, y, z)
    local f = set.frame
    if not f then return x, y, z end
    return f:dirToWorld(x, y, z)
end
local function toParent(set, x, y, z)
    local f = set.frame
    if not f then return x, y, z end
    return f:toWorld(x, y, z)
end
P.toLocal, P.toParent = toLocal, toParent

-- push a vertical cylinder out of boxes (horizontal only). Returns new x,z and whether it hit.
function P.pushOut(sets, x, feet, z, radius, height, step)
    local hit = false
    for iter = 1, 3 do
        local moved = false
        for si = 1, #sets do
            local set = sets[si]
            if set.enabled ~= false then
                local lx, ly, lz = toLocal(set, x, feet, z)
                local boxes, n = setBoxes(set, lx, lz, radius + 1)
                for i = 1, n do
                    local b = boxes[i]
                    if b.enabled ~= false and not b.noPlayer and b[5] > ly + step and b[2] < ly + height then
                        -- closest point on box rect to circle center
                        local cx = lx < b[1] and b[1] or (lx > b[4] and b[4] or lx)
                        local cz = lz < b[3] and b[3] or (lz > b[6] and b[6] or lz)
                        local dx, dz = lx - cx, lz - cz
                        local d2 = dx * dx + dz * dz
                        if d2 < radius * radius then
                            local px, pz
                            if d2 > 1e-8 then
                                local d = sqrt(d2)
                                local pen = radius - d
                                px, pz = dx / d * pen, dz / d * pen
                            else
                                -- center inside: push along smallest axis
                                local l, r, f, k = lx - b[1], b[4] - lx, lz - b[3], b[6] - lz
                                local m = min(l, r, f, k)
                                if m == l then px, pz = -(l + radius), 0
                                elseif m == r then px, pz = r + radius, 0
                                elseif m == f then px, pz = 0, -(f + radius)
                                else px, pz = 0, k + radius end
                            end
                            lx, lz = lx + px, lz + pz
                            local wx, wy, wz = dirToParent(set, px, 0, pz)
                            x, z = x + wx, z + wz
                            hit, moved = true, true
                            if b.onTouch then b.onTouch(b) end
                        end
                    end
                end
            end
        end
        if not moved then break end
    end
    return x, z, hit
end

-- highest walkable surface under the cylinder (in parent space y), not above feet+step
function P.groundHeight(sets, x, feet, z, radius, step)
    local best = -math.huge
    local bestBox
    for si = 1, #sets do
        local set = sets[si]
        if set.enabled ~= false then
            local lx, ly, lz = toLocal(set, x, feet, z)
            local boxes, n = setBoxes(set, lx, lz, radius)
            local r = radius * 0.7
            for i = 1, n do
                local b = boxes[i]
                if b.enabled ~= false and not b.noPlayer and lx + r > b[1] and lx - r < b[4] and lz + r > b[3] and lz - r < b[6] then
                    if b[5] <= ly + step then
                        local wx, wy, wz = toParent(set, lx, b[5], lz)
                        if wy > best then best, bestBox = wy, b end
                    end
                end
            end
        end
    end
    return best, bestBox
end

-- lowest ceiling above the feet (parent y)
function P.ceilingHeight(sets, x, feet, z, radius)
    local best = math.huge
    for si = 1, #sets do
        local set = sets[si]
        if set.enabled ~= false then
            local lx, ly, lz = toLocal(set, x, feet, z)
            local boxes, n = setBoxes(set, lx, lz, radius)
            local r = radius * 0.8
            for i = 1, n do
                local b = boxes[i]
                if b.enabled ~= false and not b.noPlayer and lx + r > b[1] and lx - r < b[4] and lz + r > b[3] and lz - r < b[6] then
                    if b[2] > ly + 0.5 then
                        local wx, wy, wz = toParent(set, lx, b[2], lz)
                        if wy < best then best = wy end
                    end
                end
            end
        end
    end
    return best
end

-- ray vs AABB (slab). returns t, normal axis
local function rayBox(ox, oy, oz, dx, dy, dz, b, maxT)
    local tmin, tmax = 0, maxT
    local nx, ny, nz = 0, 0, 0
    -- x
    if abs(dx) < 1e-9 then
        if ox < b[1] or ox > b[4] then return nil end
    else
        local inv = 1 / dx
        local t1, t2 = (b[1] - ox) * inv, (b[4] - ox) * inv
        local n = -1
        if t1 > t2 then t1, t2 = t2, t1 n = 1 end
        if t1 > tmin then tmin = t1 nx, ny, nz = n, 0, 0 end
        if t2 < tmax then tmax = t2 end
        if tmin > tmax then return nil end
    end
    if abs(dy) < 1e-9 then
        if oy < b[2] or oy > b[5] then return nil end
    else
        local inv = 1 / dy
        local t1, t2 = (b[2] - oy) * inv, (b[5] - oy) * inv
        local n = -1
        if t1 > t2 then t1, t2 = t2, t1 n = 1 end
        if t1 > tmin then tmin = t1 nx, ny, nz = 0, n, 0 end
        if t2 < tmax then tmax = t2 end
        if tmin > tmax then return nil end
    end
    if abs(dz) < 1e-9 then
        if oz < b[3] or oz > b[6] then return nil end
    else
        local inv = 1 / dz
        local t1, t2 = (b[3] - oz) * inv, (b[6] - oz) * inv
        local n = -1
        if t1 > t2 then t1, t2 = t2, t1 n = 1 end
        if t1 > tmin then tmin = t1 nx, ny, nz = 0, 0, n end
        if t2 < tmax then tmax = t2 end
        if tmin > tmax then return nil end
    end
    return tmin, nx, ny, nz
end
P.rayBox = rayBox

local rtmp = {}
-- cast a ray through collider sets; returns t, nx,ny,nz (parent space), box, set
function P.raycast(sets, ox, oy, oz, dx, dy, dz, maxT, filter)
    local bestT, bnx, bny, bnz, bestBox, bestSet = maxT, 0, 0, 0, nil, nil
    for si = 1, #sets do
        local set = sets[si]
        if set.enabled ~= false then
            local lox, loy, loz = toLocal(set, ox, oy, oz)
            local ldx, ldy, ldz = dx, dy, dz
            if set.frame then ldx, ldy, ldz = set.frame:dirToLocal(dx, dy, dz) end
            local boxes, n
            if set.grid then
                local ex, ez = lox + ldx * bestT, loz + ldz * bestT
                boxes, n = set.grid:query(min(lox, ex), min(loz, ez), max(lox, ex), max(loz, ez), rtmp)
            else
                boxes, n = set.boxes, #set.boxes
            end
            for i = 1, n do
                local b = boxes[i]
                if b.enabled ~= false and not b.noRay and (not filter or filter(b)) then
                    local t, nx, ny, nz = rayBox(lox, loy, loz, ldx, ldy, ldz, b, bestT)
                    if t and t < bestT and t > 0 then
                        bestT, bestBox, bestSet = t, b, set
                        bnx, bny, bnz = dirToParent(set, nx, ny, nz)
                    end
                end
            end
        end
    end
    if bestBox then return bestT, bnx, bny, bnz, bestBox, bestSet end
    return nil
end

-- ray vs sphere
function P.raySphere(ox, oy, oz, dx, dy, dz, cx, cy, cz, r)
    local lx, ly, lz = ox - cx, oy - cy, oz - cz
    local b = lx * dx + ly * dy + lz * dz
    local c = lx * lx + ly * ly + lz * lz - r * r
    local h = b * b - c
    if h < 0 then return nil end
    h = sqrt(h)
    local t = -b - h
    if t < 0 then t = -b + h end
    if t < 0 then return nil end
    return t
end

-- circle (x,z,r) against set boxes, for vehicles: returns accumulated push and contact flag
function P.circlePush(sets, x, y, z, r, yMin, yMax)
    local pxs, pzs, hit = 0, 0, false
    local hitBox
    for si = 1, #sets do
        local set = sets[si]
        if set.enabled ~= false then
            local lx, ly, lz = toLocal(set, x, y, z)
            local boxes, n = setBoxes(set, lx, lz, r + 1)
            for i = 1, n do
                local b = boxes[i]
                if b.enabled ~= false and not b.noVehicle and b[5] > ly + (yMin or 0.6) and b[2] < ly + (yMax or 3) then
                    local cx = lx < b[1] and b[1] or (lx > b[4] and b[4] or lx)
                    local cz = lz < b[3] and b[3] or (lz > b[6] and b[6] or lz)
                    local dx, dz = lx - cx, lz - cz
                    local d2 = dx * dx + dz * dz
                    if d2 < r * r then
                        local px, pz
                        if d2 > 1e-8 then
                            local d = sqrt(d2)
                            px, pz = dx / d * (r - d), dz / d * (r - d)
                        else
                            local l, rr, f, k = lx - b[1], b[4] - lx, lz - b[3], b[6] - lz
                            local m = min(l, rr, f, k)
                            if m == l then px, pz = -(l + r), 0
                            elseif m == rr then px, pz = rr + r, 0
                            elseif m == f then px, pz = 0, -(f + r)
                            else px, pz = 0, k + r end
                        end
                        local wx, wy, wz = dirToParent(set, px, 0, pz)
                        pxs, pzs = pxs + wx, pzs + wz
                        hit = true
                        hitBox = b
                    end
                end
            end
        end
    end
    return pxs, pzs, hit, hitBox
end

return P
