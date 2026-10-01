-- Row-major 4x4 matrices stored as flat tables (sent to shaders with "row" layout).
-- Local frames use the convention: +x forward, +y up, +z right.
local M = {}
local cos, sin, tan, sqrt = math.cos, math.sin, math.tan, math.sqrt

function M.identity()
    return { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
end

function M.perspective(fovy, aspect, near, far, out)
    out = out or {}
    local f = 1 / tan(fovy / 2)
    out[1], out[2], out[3], out[4] = f / aspect, 0, 0, 0
    out[5], out[6], out[7], out[8] = 0, f, 0, 0
    out[9], out[10], out[11], out[12] = 0, 0, (far + near) / (near - far), 2 * far * near / (near - far)
    out[13], out[14], out[15], out[16] = 0, 0, -1, 0
    return out
end

function M.lookAt(ex, ey, ez, fx, fy, fz, ux, uy, uz, out)
    out = out or {}
    -- f must be normalized forward
    local sx, sy, sz = fy * uz - fz * uy, fz * ux - fx * uz, fx * uy - fy * ux
    local sl = sqrt(sx * sx + sy * sy + sz * sz)
    sx, sy, sz = sx / sl, sy / sl, sz / sl
    local vx, vy, vz = sy * fz - sz * fy, sz * fx - sx * fz, sx * fy - sy * fx
    out[1], out[2], out[3], out[4] = sx, sy, sz, -(sx * ex + sy * ey + sz * ez)
    out[5], out[6], out[7], out[8] = vx, vy, vz, -(vx * ex + vy * ey + vz * ez)
    out[9], out[10], out[11], out[12] = -fx, -fy, -fz, fx * ex + fy * ey + fz * ez
    out[13], out[14], out[15], out[16] = 0, 0, 0, 1
    return out
end

function M.mul(a, b, out)
    out = out or {}
    for r = 0, 3 do
        local a1, a2, a3, a4 = a[r * 4 + 1], a[r * 4 + 2], a[r * 4 + 3], a[r * 4 + 4]
        for c = 1, 4 do
            out[r * 4 + c] = a1 * b[c] + a2 * b[4 + c] + a3 * b[8 + c] + a4 * b[12 + c]
        end
    end
    return out
end

-- A Frame is a position plus orthonormal basis (fwd, up, right) = local x, y, z axes in parent space.
local Frame = {}
Frame.__index = Frame
M.Frame = Frame

function M.frame(px, py, pz)
    return setmetatable({ px = px or 0, py = py or 0, pz = pz or 0,
        fx = 1, fy = 0, fz = 0, ux = 0, uy = 1, uz = 0, rx = 0, ry = 0, rz = 1 }, Frame)
end

function Frame:setYaw(yaw)
    local c, s = cos(yaw), sin(yaw)
    self.fx, self.fy, self.fz = c, 0, s
    self.ux, self.uy, self.uz = 0, 1, 0
    self.rx, self.ry, self.rz = -s, 0, c
    return self
end

-- yaw then pitch (around local right) then roll (around local forward)
function Frame:setYawPitchRoll(yaw, pitch, roll)
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)
    local cr, sr = cos(roll or 0), sin(roll or 0)
    -- forward pitched up
    local fx, fy, fz = cy * cp, sp, sy * cp
    -- right is horizontal
    local rx, ry, rz = -sy, 0, cy
    -- up = right x forward
    local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
    -- roll around forward
    self.fx, self.fy, self.fz = fx, fy, fz
    self.ux, self.uy, self.uz = ux * cr + rx * sr, uy * cr + ry * sr, uz * cr + rz * sr
    self.rx, self.ry, self.rz = rx * cr - ux * sr, ry * cr - uy * sr, rz * cr - uz * sr
    return self
end

-- build a frame from yaw and a ground normal
function Frame:setYawNormal(yaw, nx, ny, nz)
    local c, s = cos(yaw), sin(yaw)
    local fx, fy, fz = c, 0, s
    -- right = f x n
    local rx, ry, rz = fy * nz - fz * ny, fz * nx - fx * nz, fx * ny - fy * nx
    local l = sqrt(rx * rx + ry * ry + rz * rz)
    rx, ry, rz = rx / l, ry / l, rz / l
    -- forward = n x right
    fx, fy, fz = ny * rz - nz * ry, nz * rx - nx * rz, nx * ry - ny * rx
    self.fx, self.fy, self.fz = fx, fy, fz
    self.ux, self.uy, self.uz = nx, ny, nz
    self.rx, self.ry, self.rz = rx, ry, rz
    return self
end

function Frame:toWorld(x, y, z)
    return self.px + self.fx * x + self.ux * y + self.rx * z,
           self.py + self.fy * x + self.uy * y + self.ry * z,
           self.pz + self.fz * x + self.uz * y + self.rz * z
end

function Frame:dirToWorld(x, y, z)
    return self.fx * x + self.ux * y + self.rx * z,
           self.fy * x + self.uy * y + self.ry * z,
           self.fz * x + self.uz * y + self.rz * z
end

function Frame:toLocal(x, y, z)
    x, y, z = x - self.px, y - self.py, z - self.pz
    return self.fx * x + self.fy * y + self.fz * z,
           self.ux * x + self.uy * y + self.uz * z,
           self.rx * x + self.ry * y + self.rz * z
end

function Frame:dirToLocal(x, y, z)
    return self.fx * x + self.fy * y + self.fz * z,
           self.ux * x + self.uy * y + self.uz * z,
           self.rx * x + self.ry * y + self.rz * z
end

-- compose: child expressed in self -> child in parent space
function Frame:compose(child, out)
    out = out or M.frame()
    out.px, out.py, out.pz = self:toWorld(child.px, child.py, child.pz)
    out.fx, out.fy, out.fz = self:dirToWorld(child.fx, child.fy, child.fz)
    out.ux, out.uy, out.uz = self:dirToWorld(child.ux, child.uy, child.uz)
    out.rx, out.ry, out.rz = self:dirToWorld(child.rx, child.ry, child.rz)
    return out
end

function Frame:copyFrom(o)
    self.px, self.py, self.pz = o.px, o.py, o.pz
    self.fx, self.fy, self.fz = o.fx, o.fy, o.fz
    self.ux, self.uy, self.uz = o.ux, o.uy, o.uz
    self.rx, self.ry, self.rz = o.rx, o.ry, o.rz
    return self
end

function Frame:yaw() return math.atan2(self.fz, self.fx) end

function Frame:matrix(out, scale)
    out = out or {}
    local s = scale or 1
    out[1], out[2], out[3], out[4] = self.fx * s, self.ux * s, self.rx * s, self.px
    out[5], out[6], out[7], out[8] = self.fy * s, self.uy * s, self.ry * s, self.py
    out[9], out[10], out[11], out[12] = self.fz * s, self.uz * s, self.rz * s, self.pz
    out[13], out[14], out[15], out[16] = 0, 0, 0, 1
    return out
end

-- quick model matrix: translation + yaw (+ uniform scale)
function M.trsYaw(x, y, z, yaw, s, out)
    out = out or {}
    s = s or 1
    local c, si = cos(yaw), sin(yaw)
    out[1], out[2], out[3], out[4] = c * s, 0, -si * s, x
    out[5], out[6], out[7], out[8] = 0, s, 0, y
    out[9], out[10], out[11], out[12] = si * s, 0, c * s, z
    out[13], out[14], out[15], out[16] = 0, 0, 0, 1
    return out
end

-- project a world point with a combined view-projection matrix; returns ndc x,y and w
function M.project(vp, x, y, z)
    local cx = vp[1] * x + vp[2] * y + vp[3] * z + vp[4]
    local cy = vp[5] * x + vp[6] * y + vp[7] * z + vp[8]
    local cw = vp[13] * x + vp[14] * y + vp[15] * z + vp[16]
    if cw <= 0.001 then return nil end
    return cx / cw, cy / cw, cw
end

return M
