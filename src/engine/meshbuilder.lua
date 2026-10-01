-- Builds low-poly geometry grouped by material into LÖVE meshes.
-- Vertex layout: position(3) uv(2) normal(3) color(4 bytes).
local ffi = require("ffi")
local Textures = require("src.engine.textures")

ffi.cdef [[
typedef struct { float x, y, z, u, v, nx, ny, nz; unsigned char r, g, b, a; } psx_vertex;
]]

local FORMAT = {
    { "VertexPosition", "float", 3 },
    { "VertexTexCoord", "float", 2 },
    { "VertexNormal", "float", 3 },
    { "VertexColor", "byte", 4 },
}

local sqrt, cos, sin, floor = math.sqrt, math.cos, math.sin, math.floor

local MB = {}
MB.__index = MB
MB.FORMAT = FORMAT

function MB.new(seed)
    local self = setmetatable({}, MB)
    self.groups = {}
    self.mat = "white"
    self.r, self.g, self.b, self.a = 1, 1, 1, 1
    self.jitter = 0.06
    self.texScale = 0.5 -- texture repeats per meter
    self.maxEdge = nil  -- subdivide large faces (for vertex lighting)
    self.m = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0 } -- 3x4 transform
    self.stack = {}
    self.seed = seed or 1234
    self.bounds = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
    return self
end

function MB:rand()
    self.seed = (self.seed * 16807) % 2147483647
    return self.seed / 2147483647
end

function MB:material(name) self.mat = name return self end
function MB:color(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a or 1 return self end

-- transform stack ----------------------------------------------------------
function MB:push()
    local m = self.m
    self.stack[#self.stack + 1] = { m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12] }
    return self
end
function MB:pop() self.m = table.remove(self.stack) return self end
function MB:reset() self.m = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0 } self.stack = {} return self end

local function mulm(m, n)
    -- m * n (3x4 affine)
    local o = {}
    for r = 0, 2 do
        local a, b, c, d = m[r * 4 + 1], m[r * 4 + 2], m[r * 4 + 3], m[r * 4 + 4]
        o[r * 4 + 1] = a * n[1] + b * n[5] + c * n[9]
        o[r * 4 + 2] = a * n[2] + b * n[6] + c * n[10]
        o[r * 4 + 3] = a * n[3] + b * n[7] + c * n[11]
        o[r * 4 + 4] = a * n[4] + b * n[8] + c * n[12] + d
    end
    return o
end

function MB:translate(x, y, z) self.m = mulm(self.m, { 1, 0, 0, x, 0, 1, 0, y, 0, 0, 1, z }) return self end
function MB:scale(x, y, z) self.m = mulm(self.m, { x, 0, 0, 0, 0, y or x, 0, 0, 0, 0, z or x, 0 }) return self end
-- rotation about Y that maps +x toward +z for positive angles (matches yaw convention)
function MB:rotateY(a)
    local c, s = cos(a), sin(a)
    self.m = mulm(self.m, { c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0 })
    return self
end
function MB:rotateX(a)
    local c, s = cos(a), sin(a)
    self.m = mulm(self.m, { 1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0 })
    return self
end
function MB:rotateZ(a)
    local c, s = cos(a), sin(a)
    self.m = mulm(self.m, { c, -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0 })
    return self
end

function MB:xf(x, y, z)
    local m = self.m
    return m[1] * x + m[2] * y + m[3] * z + m[4],
           m[5] * x + m[6] * y + m[7] * z + m[8],
           m[9] * x + m[10] * y + m[11] * z + m[12]
end
function MB:xfn(x, y, z)
    local m = self.m
    local nx, ny, nz = m[1] * x + m[2] * y + m[3] * z, m[5] * x + m[6] * y + m[7] * z, m[9] * x + m[10] * y + m[11] * z
    local l = sqrt(nx * nx + ny * ny + nz * nz)
    if l < 1e-9 then return 0, 1, 0 end
    return nx / l, ny / l, nz / l
end

-- raw emit -------------------------------------------------------------------
local function group(self)
    local g = self.groups[self.mat]
    if not g then
        g = { n = 0, v = {} }
        self.groups[self.mat] = g
    end
    return g
end

-- emit a triangle already in builder-local coordinates (transform applied here)
function MB:tri(ax, ay, az, au, av, bx, by, bz, bu, bv, cx, cy, cz, cu, cv, nx, ny, nz)
    local wax, way, waz = self:xf(ax, ay, az)
    local wbx, wby, wbz = self:xf(bx, by, bz)
    local wcx, wcy, wcz = self:xf(cx, cy, cz)
    if not nx then
        local ux, uy, uz = wbx - wax, wby - way, wbz - waz
        local vx, vy, vz = wcx - wax, wcy - way, wcz - waz
        nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        local l = sqrt(nx * nx + ny * ny + nz * nz)
        if l < 1e-12 then return end
        nx, ny, nz = nx / l, ny / l, nz / l
    else
        nx, ny, nz = self:xfn(nx, ny, nz)
    end
    local g = group(self)
    local v = g.v
    local k = #v
    local b = self.bounds
    local pts = { wax, way, waz, au, av, wbx, wby, wbz, bu, bv, wcx, wcy, wcz, cu, cv }
    for i = 0, 2 do
        local px, py, pz, u, vv = pts[i * 5 + 1], pts[i * 5 + 2], pts[i * 5 + 3], pts[i * 5 + 4], pts[i * 5 + 5]
        local j = 1 + (self:rand() - 0.5) * 2 * self.jitter
        v[k + 1], v[k + 2], v[k + 3], v[k + 4], v[k + 5] = px, py, pz, u, vv
        v[k + 6], v[k + 7], v[k + 8] = nx, ny, nz
        v[k + 9], v[k + 10], v[k + 11], v[k + 12] = self.r * j, self.g * j, self.b * j, self.a
        k = k + 12
        if px < b[1] then b[1] = px end
        if py < b[2] then b[2] = py end
        if pz < b[3] then b[3] = pz end
        if px > b[4] then b[4] = px end
        if py > b[5] then b[5] = py end
        if pz > b[6] then b[6] = pz end
    end
    g.n = g.n + 3
end

-- quad a,b,c,d (counter-clockwise when seen from front) with given uvs
function MB:quadUV(ax, ay, az, au, av, bx, by, bz, bu, bv, cx, cy, cz, cu, cv, dx, dy, dz, du, dv)
    self:tri(ax, ay, az, au, av, bx, by, bz, bu, bv, cx, cy, cz, cu, cv)
    self:tri(ax, ay, az, au, av, cx, cy, cz, cu, cv, dx, dy, dz, du, dv)
end

-- subdivided parallelogram: origin o, edge vectors e1, e2 ; uv by world length * texScale
function MB:grid(ox, oy, oz, e1x, e1y, e1z, e2x, e2y, e2z, uv0u, uv0v)
    local l1 = sqrt(e1x * e1x + e1y * e1y + e1z * e1z)
    local l2 = sqrt(e2x * e2x + e2y * e2y + e2z * e2z)
    local n1, n2 = 1, 1
    if self.maxEdge then
        n1 = math.max(1, math.min(16, math.ceil(l1 / self.maxEdge)))
        n2 = math.max(1, math.min(16, math.ceil(l2 / self.maxEdge)))
    end
    local ts = self.texScale
    uv0u, uv0v = uv0u or 0, uv0v or 0
    for i = 0, n1 - 1 do
        local s0, s1 = i / n1, (i + 1) / n1
        for j = 0, n2 - 1 do
            local t0, t1 = j / n2, (j + 1) / n2
            local function P(s, t)
                return ox + e1x * s + e2x * t, oy + e1y * s + e2y * t, oz + e1z * s + e2z * t,
                       uv0u + s * l1 * ts, uv0v + t * l2 * ts
            end
            local ax, ay, az, au, av = P(s0, t0)
            local bx, by, bz, bu, bv = P(s1, t0)
            local cx, cy, cz, cu, cv = P(s1, t1)
            local dx, dy, dz, du, dv = P(s0, t1)
            self:quadUV(ax, ay, az, au, av, bx, by, bz, bu, bv, cx, cy, cz, cu, cv, dx, dy, dz, du, dv)
        end
    end
end

-- generic quad with planar uvs
function MB:quad(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz)
    -- uv based on edge lengths
    local e1x, e1y, e1z = bx - ax, by - ay, bz - az
    local e2x, e2y, e2z = dx - ax, dy - ay, dz - az
    local ts = self.texScale
    local l1 = sqrt(e1x * e1x + e1y * e1y + e1z * e1z) * ts
    local l2 = sqrt(e2x * e2x + e2y * e2y + e2z * e2z) * ts
    self:quadUV(ax, ay, az, 0, l2, bx, by, bz, l1, l2, cx, cy, cz, l1, 0, dx, dy, dz, 0, 0)
end

-- axis aligned box (in builder local space). faces: optional table {top=false,...}
function MB:box(x0, y0, z0, x1, y1, z1, faces)
    local sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
    local f = faces
    -- each face via grid (origin, e1, e2) arranged so normal = e1 x e2 points outward
    if not f or f.top ~= false then self:grid(x0, y1, z0, 0, 0, sz, sx, 0, 0) end
    if not f or f.bottom ~= false then self:grid(x0, y0, z0, sx, 0, 0, 0, 0, sz) end
    if not f or f.front ~= false then self:grid(x1, y0, z0, 0, sy, 0, 0, 0, sz) end   -- +x
    if not f or f.back ~= false then self:grid(x0, y0, z0, 0, 0, sz, 0, sy, 0) end    -- -x
    if not f or f.right ~= false then self:grid(x0, y0, z1, sx, 0, 0, 0, sy, 0) end   -- +z
    if not f or f.left ~= false then self:grid(x0, y0, z0, 0, sy, 0, sx, 0, 0) end    -- -z
end

-- inward facing box (room), useful for interiors
function MB:room(x0, y0, z0, x1, y1, z1, faces)
    local sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
    local f = faces
    if not f or f.top ~= false then self:grid(x0, y1, z0, sx, 0, 0, 0, 0, sz) end
    if not f or f.bottom ~= false then self:grid(x0, y0, z0, 0, 0, sz, sx, 0, 0) end
    if not f or f.front ~= false then self:grid(x1, y0, z0, 0, 0, sz, 0, sy, 0) end
    if not f or f.back ~= false then self:grid(x0, y0, z0, 0, sy, 0, 0, 0, sz) end
    if not f or f.right ~= false then self:grid(x0, y0, z1, 0, sy, 0, sx, 0, 0) end
    if not f or f.left ~= false then self:grid(x0, y0, z0, sx, 0, 0, 0, sy, 0) end
end

function MB:boxC(cx, cy, cz, sx, sy, sz, faces)
    self:box(cx - sx / 2, cy - sy / 2, cz - sz / 2, cx + sx / 2, cy + sy / 2, cz + sz / 2, faces)
end

-- hexahedron from 8 corners: bottom (b1..b4) and top (t1..t4), each ccw seen from above,
-- order: (-x,-z), (+x,-z), (+x,+z), (-x,+z)
function MB:hexa(c)
    local function Q(a, b, cc, d)
        self:quad(c[a][1], c[a][2], c[a][3], c[b][1], c[b][2], c[b][3], c[cc][1], c[cc][2], c[cc][3], c[d][1], c[d][2], c[d][3])
    end
    -- indices 1-4 bottom, 5-8 top
    Q(5, 8, 7, 6)   -- top
    Q(1, 2, 3, 4)   -- bottom
    Q(2, 6, 7, 3)   -- +x
    Q(4, 8, 5, 1)   -- -x
    Q(3, 7, 8, 4)   -- +z
    Q(1, 5, 6, 2)   -- -z
end

-- same as hexa but faces point inward (rooms, cabins)
function MB:hexaIn(c, skip)
    local function Q(a, b, cc, d)
        self:quad(c[d][1], c[d][2], c[d][3], c[cc][1], c[cc][2], c[cc][3], c[b][1], c[b][2], c[b][3], c[a][1], c[a][2], c[a][3])
    end
    skip = skip or {}
    if not skip.top then Q(5, 8, 7, 6) end
    if not skip.bottom then Q(1, 2, 3, 4) end
    if not skip.front then Q(2, 6, 7, 3) end
    if not skip.back then Q(4, 8, 5, 1) end
    if not skip.right then Q(3, 7, 8, 4) end
    if not skip.left then Q(1, 5, 6, 2) end
end

-- quad that is guaranteed to face along (nx,ny,nz) (in builder-local space)
function MB:quadN(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz, nx, ny, nz)
    local ux, uy, uz = bx - ax, by - ay, bz - az
    local vx, vy, vz = cx - ax, cy - ay, cz - az
    local px, py, pz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    if px * nx + py * ny + pz * nz < 0 then
        self:quad(dx, dy, dz, cx, cy, cz, bx, by, bz, ax, ay, az)
    else
        self:quad(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz)
    end
end

-- horizontal rectangular plate (y) with a circular hole; ny = +1/-1 facing
function MB:plateHole(x0, z0, x1, z1, y, cx, cz, r, seg, ny)
    local angles = {}
    for i = 0, seg - 1 do angles[#angles + 1] = i / seg * 2 * math.pi end
    for _, p in ipairs({ { x1, z1 }, { x0, z1 }, { x0, z0 }, { x1, z0 } }) do
        angles[#angles + 1] = math.atan2(p[2] - cz, p[1] - cx) % (2 * math.pi)
    end
    table.sort(angles)
    local function rectHit(a)
        local dx, dz = math.cos(a), math.sin(a)
        local t = math.huge
        if dx > 1e-9 then t = math.min(t, (x1 - cx) / dx) elseif dx < -1e-9 then t = math.min(t, (x0 - cx) / dx) end
        if dz > 1e-9 then t = math.min(t, (z1 - cz) / dz) elseif dz < -1e-9 then t = math.min(t, (z0 - cz) / dz) end
        return cx + dx * t, cz + dz * t
    end
    for i = 1, #angles do
        local a0, a1 = angles[i], angles[i % #angles + 1]
        if i == #angles then a1 = a1 + 2 * math.pi end
        if a1 - a0 > 1e-6 then
            local px0, pz0 = rectHit(a0)
            local px1, pz1 = rectHit(a1)
            local c0x, c0z = cx + math.cos(a0) * r, cz + math.sin(a0) * r
            local c1x, c1z = cx + math.cos(a1) * r, cz + math.sin(a1) * r
            self:quadN(c0x, y, c0z, px0, y, pz0, px1, y, pz1, c1x, y, c1z, 0, ny, 0)
        end
    end
end

-- cylinder along local Y from y0 to y1
function MB:cylinder(cx, y0, cz, r0, y1, r1, seg, caps, uvWrap)
    seg = seg or 8
    r1 = r1 or r0
    local ts = self.texScale
    local circ = 2 * math.pi * math.max(r0, r1) * ts
    local h = (y1 - y0) * ts
    if uvWrap then circ = uvWrap end
    for i = 0, seg - 1 do
        local a0, a1 = i / seg * 2 * math.pi, (i + 1) / seg * 2 * math.pi
        local c0, s0, c1, s1 = cos(a0), sin(a0), cos(a1), sin(a1)
        local u0, u1 = i / seg * circ, (i + 1) / seg * circ
        self:quadUV(cx + c0 * r0, y0, cz + s0 * r0, u0, h,
                    cx + c0 * r1, y1, cz + s0 * r1, u0, 0,
                    cx + c1 * r1, y1, cz + s1 * r1, u1, 0,
                    cx + c1 * r0, y0, cz + s1 * r0, u1, h)
        if caps ~= false then
            if r1 > 0 then
                self:tri(cx, y1, cz, 0.5, 0.5, cx + c1 * r1, y1, cz + s1 * r1, 0.5 + c1 * 0.5, 0.5 + s1 * 0.5,
                    cx + c0 * r1, y1, cz + s0 * r1, 0.5 + c0 * 0.5, 0.5 + s0 * 0.5)
            end
            if r0 > 0 and caps ~= "top" then
                self:tri(cx, y0, cz, 0.5, 0.5, cx + c0 * r0, y0, cz + s0 * r0, 0.5 + c0 * 0.5, 0.5 + s0 * 0.5,
                    cx + c1 * r0, y0, cz + s1 * r0, 0.5 + c1 * 0.5, 0.5 + s1 * 0.5)
            end
        end
    end
end

-- cylinder along local X (barrels, wheels via rotate)
function MB:cylinderX(x0, x1, cy, cz, r0, r1, seg, caps)
    self:push()
    self:translate(0, cy, cz)
    self:rotateZ(-math.pi / 2)
    self:cylinder(0, x0, 0, r0, x1, r1, seg, caps)
    self:pop()
end
-- cylinder along local Z
function MB:cylinderZ(z0, z1, cx, cy, r, seg, caps)
    self:push()
    self:translate(cx, cy, 0)
    self:rotateX(math.pi / 2)
    self:cylinder(0, z0, 0, r, z1, r, seg, caps)
    self:pop()
end

function MB:sphere(cx, cy, cz, rx, ry, rz, segU, segV)
    segU, segV = segU or 8, segV or 5
    ry, rz = ry or rx, rz or rx
    local function P(i, j)
        local th = i / segU * 2 * math.pi
        local ph = j / segV * math.pi
        return cx + rx * sin(ph) * cos(th), cy + ry * cos(ph), cz + rz * sin(ph) * sin(th), i / segU, j / segV
    end
    for i = 0, segU - 1 do
        for j = 0, segV - 1 do
            local ax, ay, az, au, av = P(i, j)
            local bx, by, bz, bu, bv = P(i + 1, j)
            local cx2, cy2, cz2, cu, cv = P(i + 1, j + 1)
            local dx, dy, dz, du, dv = P(i, j + 1)
            if j > 0 then self:tri(ax, ay, az, au, av, bx, by, bz, bu, bv, cx2, cy2, cz2, cu, cv) end
            if j < segV - 1 then self:tri(ax, ay, az, au, av, cx2, cy2, cz2, cu, cv, dx, dy, dz, du, dv) end
        end
    end
end

-- double-sided flat panel (flags, signs, paper)
function MB:panel(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz)
    self:quadUV(ax, ay, az, 0, 1, bx, by, bz, 1, 1, cx, cy, cz, 1, 0, dx, dy, dz, 0, 0)
    self:quadUV(dx, dy, dz, 0, 0, cx, cy, cz, 1, 0, bx, by, bz, 1, 1, ax, ay, az, 0, 1)
end

-- build -------------------------------------------------------------------
local function toMesh(g)
    local n = g.n
    if n == 0 then return nil end
    local data = love.data.newByteData(n * ffi.sizeof("psx_vertex"))
    local p = ffi.cast("psx_vertex*", data:getFFIPointer())
    local v = g.v
    for i = 0, n - 1 do
        local k = i * 12
        local q = p[i]
        q.x, q.y, q.z, q.u, q.v = v[k + 1], v[k + 2], v[k + 3], v[k + 4], v[k + 5]
        q.nx, q.ny, q.nz = v[k + 6], v[k + 7], v[k + 8]
        local r, gg, b, a = v[k + 9], v[k + 10], v[k + 11], v[k + 12]
        q.r = r >= 1 and 255 or (r <= 0 and 0 or floor(r * 255))
        q.g = gg >= 1 and 255 or (gg <= 0 and 0 or floor(gg * 255))
        q.b = b >= 1 and 255 or (b <= 0 and 0 or floor(b * 255))
        q.a = a >= 1 and 255 or (a <= 0 and 0 or floor(a * 255))
    end
    local mesh = love.graphics.newMesh(FORMAT, n, "triangles", "static")
    mesh:setVertices(data)
    return mesh
end

-- returns a Model: { parts = { {mesh=, tex=, mat=} }, bounds = {...}, tris = n }
function MB:build()
    local model = { parts = {}, bounds = self.bounds, tris = 0 }
    local names = {}
    for name in pairs(self.groups) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local g = self.groups[name]
        local mesh = toMesh(g)
        if mesh then
            local tex = Textures.get(name:match("^[^#]+"))
            mesh:setTexture(tex)
            model.parts[#model.parts + 1] = { mesh = mesh, tex = tex, mat = name }
            model.tris = model.tris + g.n / 3
        end
    end
    local b = self.bounds
    model.cx, model.cy, model.cz = (b[1] + b[4]) / 2, (b[2] + b[5]) / 2, (b[3] + b[6]) / 2
    model.radius = sqrt((b[4] - b[1]) ^ 2 + (b[5] - b[2]) ^ 2 + (b[6] - b[3]) ^ 2) / 2
    if model.radius ~= model.radius or model.radius == math.huge then model.radius = 0 end
    return model
end

function MB:isEmpty()
    for _, g in pairs(self.groups) do if g.n > 0 then return false end end
    return true
end

return MB
