-- Minimal binary glTF (.glb) loader for rigid, part-based PSX models: meshes per node,
-- node hierarchy, embedded textures and translation/rotation/scale animation tracks. No skinning.
-- glTF space (+y up, model faces +z) is rotated into the game's frames (+x forward, +z right).
local ffi = require("ffi")
local json = require("src.lib.json")
local MB = require("src.engine.meshbuilder")
local Textures = require("src.engine.textures")

local Gltf = { cache = {} }

local sqrt, floor = math.sqrt, math.floor

local CTYPE = { [5120] = "int8_t", [5121] = "uint8_t", [5122] = "int16_t", [5123] = "uint16_t", [5125] = "uint32_t", [5126] = "float" }
local CSIZE = { [5120] = 1, [5121] = 1, [5122] = 2, [5123] = 2, [5125] = 4, [5126] = 4 }
local CNORM = { [5120] = 127, [5121] = 255, [5122] = 32767, [5123] = 65535 }
local NCOMP = { SCALAR = 1, VEC2 = 2, VEC3 = 3, VEC4 = 4, MAT4 = 16 }

-- accessor -> flat Lua array of numbers, plus component count
local function readAccessor(doc, bin, index)
    local acc = doc.accessors[index + 1]
    local view = doc.bufferViews[acc.bufferView + 1]
    local n = NCOMP[acc.type]
    local size = CSIZE[acc.componentType]
    local stride = view.byteStride or (n * size)
    local base = bin + (view.byteOffset or 0) + (acc.byteOffset or 0)
    local ptrType = ffi.typeof("const " .. CTYPE[acc.componentType] .. "*")
    local norm = acc.normalized and CNORM[acc.componentType]
    local out = {}
    for i = 0, acc.count - 1 do
        local p = ffi.cast(ptrType, base + i * stride)
        for c = 0, n - 1 do
            local v = tonumber(p[c])
            out[i * n + c + 1] = norm and v / norm or v
        end
    end
    return out, n, acc.count
end

-- row-major 4x4 from translation, rotation quaternion (x,y,z,w) and scale
local function trs(t, r, s, out)
    local x, y, z, w = r[1], r[2], r[3], r[4]
    local sx, sy, sz = s[1], s[2], s[3]
    out[1], out[2], out[3], out[4] = (1 - 2 * (y * y + z * z)) * sx, 2 * (x * y - z * w) * sy, 2 * (x * z + y * w) * sz, t[1]
    out[5], out[6], out[7], out[8] = 2 * (x * y + z * w) * sx, (1 - 2 * (x * x + z * z)) * sy, 2 * (y * z - x * w) * sz, t[2]
    out[9], out[10], out[11], out[12] = 2 * (x * z - y * w) * sx, 2 * (y * z + x * w) * sy, (1 - 2 * (x * x + y * y)) * sz, t[3]
    out[13], out[14], out[15], out[16] = 0, 0, 0, 1
    return out
end

-- affine a * b (bottom row assumed 0,0,0,1)
local function mul(a, b, out)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12]
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12 = b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12]
    out[1], out[2], out[3], out[4] = a1 * b1 + a2 * b5 + a3 * b9, a1 * b2 + a2 * b6 + a3 * b10, a1 * b3 + a2 * b7 + a3 * b11, a1 * b4 + a2 * b8 + a3 * b12 + a4
    out[5], out[6], out[7], out[8] = a5 * b1 + a6 * b5 + a7 * b9, a5 * b2 + a6 * b6 + a7 * b10, a5 * b3 + a6 * b7 + a7 * b11, a5 * b4 + a6 * b8 + a7 * b12 + a8
    out[9], out[10], out[11], out[12] = a9 * b1 + a10 * b5 + a11 * b9, a9 * b2 + a10 * b6 + a11 * b10, a9 * b3 + a10 * b7 + a11 * b11, a9 * b4 + a10 * b8 + a11 * b12 + a12
    out[13], out[14], out[15], out[16] = 0, 0, 0, 1
    return out
end

-- glTF -> game axes: game x = gltf z, game y = gltf y, game z = -gltf x (a pure rotation)
local FIX = { 0, 0, 1, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 0, 1 }

-- node matrices in a .glb are column-major; ours are row-major
local function fromColumns(c)
    return { c[1], c[5], c[9], c[13], c[2], c[6], c[10], c[14], c[3], c[7], c[11], c[15], 0, 0, 0, 1 }
end

-- baked vertex colours are linear light; the renderer works in display space
local function toDisplay(v)
    if v <= 0 then return 0 end
    return v ^ (1 / 2.2)
end

-- texture for a material: the pack atlas when one is given, else the image embedded in the file
local function materialTexture(asset, index)
    if asset.tex then return asset.tex, nil, nil end
    local doc = asset.doc
    local m = index and doc.materials and doc.materials[index + 1]
    local pbr = m and m.pbrMetallicRoughness
    local factor = pbr and pbr.baseColorFactor
    local bt = pbr and pbr.baseColorTexture
    if not bt then return "white", factor, nil end
    local src = doc.textures[bt.index + 1].source
    local name = asset.key .. "_" .. src
    if not Textures.cache[name] then
        local img = doc.images[src + 1]
        local view = doc.bufferViews[img.bufferView + 1]
        local bytes = ffi.string(asset.bin + (view.byteOffset or 0), view.byteLength)
        local file = love.filesystem.newFileData(bytes, name .. (img.mimeType == "image/jpeg" and ".jpg" or ".png"))
        local tex = love.graphics.newImage(love.image.newImageData(file), { mipmaps = true })
        tex:setFilter("linear", "nearest", 8)
        tex:setMipmapFilter("linear")
        tex:setWrap("repeat", "repeat")
        Textures.cache[name] = tex
    end
    return name, factor, bt.extensions and bt.extensions.KHR_texture_transform
end

-- primitives of a mesh as flat vertex arrays (12 numbers per vertex), one per material
local function readPrims(asset, mesh)
    local doc, bin = asset.doc, asset.bin
    local prims = {}
    for _, prim in ipairs(mesh.primitives) do
        if (prim.mode or 4) == 4 then
            local tex, factor, xf = materialTexture(asset, prim.material)
            local a = prim.attributes
            local pos = readAccessor(doc, bin, a.POSITION)
            local nor = a.NORMAL and readAccessor(doc, bin, a.NORMAL)
            local uv = a.TEXCOORD_0 and readAccessor(doc, bin, a.TEXCOORD_0)
            local col, cn
            if a.COLOR_0 then col, cn = readAccessor(doc, bin, a.COLOR_0) end
            local idx
            if prim.indices then idx = readAccessor(doc, bin, prim.indices)
            else idx = {} for i = 1, #pos / 3 do idx[i] = i - 1 end end
            local su, sv, ou, ov = 1, 1, 0, 0
            if xf then
                if xf.scale then su, sv = xf.scale[1], xf.scale[2] end
                if xf.offset then ou, ov = xf.offset[1], xf.offset[2] end
            end
            local fr, fg, fb = 1, 1, 1
            if factor then fr, fg, fb = toDisplay(factor[1]), toDisplay(factor[2]), toDisplay(factor[3]) end
            local verts = {}
            for i = 1, #idx do
                local k = idx[i]
                local v = #verts
                verts[v + 1], verts[v + 2], verts[v + 3] = pos[k * 3 + 1], pos[k * 3 + 2], pos[k * 3 + 3]
                verts[v + 4], verts[v + 5] = uv and uv[k * 2 + 1] * su + ou or 0, uv and uv[k * 2 + 2] * sv + ov or 0
                verts[v + 6], verts[v + 7], verts[v + 8] = nor and nor[k * 3 + 1] or 0, nor and nor[k * 3 + 2] or 1, nor and nor[k * 3 + 3] or 0
                if col then
                    verts[v + 9], verts[v + 10], verts[v + 11] = toDisplay(col[k * cn + 1]) * fr, toDisplay(col[k * cn + 2]) * fg, toDisplay(col[k * cn + 3]) * fb
                    verts[v + 12] = cn == 4 and col[k * cn + 4] or 1
                else
                    verts[v + 9], verts[v + 10], verts[v + 11], verts[v + 12] = fr, fg, fb, 1
                end
            end
            if #verts > 0 then prims[#prims + 1] = { verts = verts, tex = tex } end
        end
    end
    return prims
end

local function primsOf(asset, node)
    if node.mesh == nil then return nil end
    local cache = asset.meshPrims
    if cache[node.mesh] == nil then cache[node.mesh] = readPrims(asset, asset.doc.meshes[node.mesh + 1]) end
    return cache[node.mesh]
end

-- GPU model for a node, shaped like a meshbuilder Model so the renderer can draw it directly
local function modelOf(asset, node)
    if node.model ~= nil then return node.model end
    local prims = primsOf(asset, node)
    node.model = false
    if not prims or #prims == 0 then return false end
    local model = { parts = {}, tris = 0 }
    for _, pr in ipairs(prims) do
        local verts = pr.verts
        local n = #verts / 12
        local data = love.data.newByteData(n * ffi.sizeof("psx_vertex"))
        local p = ffi.cast("psx_vertex*", data:getFFIPointer())
        for i = 0, n - 1 do
            local k = i * 12
            local q = p[i]
            q.x, q.y, q.z, q.u, q.v = verts[k + 1], verts[k + 2], verts[k + 3], verts[k + 4], verts[k + 5]
            q.nx, q.ny, q.nz = verts[k + 6], verts[k + 7], verts[k + 8]
            q.r, q.g, q.b = floor(math.min(1, verts[k + 9]) * 255), floor(math.min(1, verts[k + 10]) * 255), floor(math.min(1, verts[k + 11]) * 255)
            q.a = floor(math.min(1, verts[k + 12]) * 255)
        end
        local gm = love.graphics.newMesh(MB.FORMAT, n, "triangles", "static")
        gm:setVertices(data)
        local tex = Textures.get(pr.tex)
        gm:setTexture(tex)
        model.parts[#model.parts + 1] = { mesh = gm, tex = tex, mat = pr.tex }
        model.tris = model.tris + n / 3
    end
    node.model = model
    return model
end

-- path: .glb inside the game directory. texName: a registered texture (pack atlas) for files
-- that carry no images; leave it nil to use the textures embedded in the file.
-- Geometry and textures are decoded on first use, so big files only cost what is drawn or baked.
function Gltf.load(path, texName)
    local key = path .. "|" .. (texName or "")
    if Gltf.cache[key] then return Gltf.cache[key] end
    local raw = assert(love.filesystem.read(path), "missing model " .. path)
    local bytes = ffi.cast("const uint8_t*", raw)
    local u32 = ffi.cast("const uint32_t*", bytes)
    assert(u32[0] == 0x46546C67, path .. " is not a .glb file")
    local jsonLen = u32[3]
    local doc = json.decode(raw:sub(21, 20 + jsonLen))

    local asset = { path = path, tex = texName, nodes = {}, anims = {}, order = {}, byName = {}, meshPrims = {},
                    doc = doc, raw = raw, bin = bytes + 20 + jsonLen + 8, cacheKey = key,
                    key = "glb_" .. path:match("([^/]+)%.glb$"):gsub("[^%w]", "_") }
    local bin = asset.bin
    for i, n in ipairs(doc.nodes or {}) do
        local node = { name = n.name, t = n.translation or { 0, 0, 0 }, r = n.rotation or { 0, 0, 0, 1 }, s = n.scale or { 1, 1, 1 },
                       matrix = n.matrix and fromColumns(n.matrix), mesh = n.mesh,
                       children = n.children or {}, rest = {}, global = {}, pt = {}, pr = {}, ps = {} }
        asset.nodes[i] = node
        if n.name and not asset.byName[n.name] then asset.byName[n.name] = i end
    end
    for i, node in ipairs(asset.nodes) do
        for _, c in ipairs(node.children) do asset.nodes[c + 1].parent = i end
    end
    -- parents before children
    local function visit(i)
        asset.order[#asset.order + 1] = i
        for _, c in ipairs(asset.nodes[i].children) do visit(c + 1) end
    end
    for i, node in ipairs(asset.nodes) do if not node.parent then visit(i) end end

    for _, a in ipairs(doc.animations or {}) do
        local anim = { name = a.name, tracks = {}, duration = 0 }
        local inputs = {}
        for _, ch in ipairs(a.channels) do
            local sm = a.samplers[ch.sampler + 1]
            if ch.target.node and (ch.target.path == "translation" or ch.target.path == "rotation" or ch.target.path == "scale") then
                inputs[sm.input] = inputs[sm.input] or readAccessor(doc, bin, sm.input)
                local values, n = readAccessor(doc, bin, sm.output)
                local times = inputs[sm.input]
                -- cubic splines store in-tangent, value, out-tangent: keep the values only
                if sm.interpolation == "CUBICSPLINE" then
                    local v = {}
                    for k = 0, #times - 1 do for c = 1, n do v[k * n + c] = values[(k * 3 + 1) * n + c] end end
                    values = v
                end
                anim.tracks[#anim.tracks + 1] = { node = ch.target.node + 1, path = ch.target.path, times = times, values = values,
                                                  n = n, step = sm.interpolation == "STEP" }
                if times[#times] > anim.duration then anim.duration = times[#times] end
            end
        end
        asset.anims[a.name] = anim
    end

    for _, i in ipairs(asset.order) do
        local node = asset.nodes[i]
        if node.matrix then for k = 1, 16 do node.rest[k] = node.matrix[k] end
        else trs(node.t, node.r, node.s, node.rest) end
        if node.parent then mul(asset.nodes[node.parent].global, node.rest, node.global)
        else for k = 1, 16 do node.global[k] = node.rest[k] end end
    end
    for _, node in ipairs(asset.nodes) do
        local g = {}
        for k = 1, 16 do g[k] = node.global[k] end
        node.restGlobal = g
    end
    Gltf.cache[key] = asset
    return asset
end

local function sampleTrack(tr, time, out)
    local times, values, n = tr.times, tr.values, tr.n
    local count = #times
    if count == 1 or time <= times[1] then
        for c = 1, n do out[c] = values[c] end
        return
    end
    if time >= times[count] then
        for c = 1, n do out[c] = values[(count - 1) * n + c] end
        return
    end
    local lo, hi = 1, count
    while hi - lo > 1 do
        local mid = floor((lo + hi) / 2)
        if times[mid] <= time then lo = mid else hi = mid end
    end
    local f = tr.step and 0 or (time - times[lo]) / (times[hi] - times[lo])
    local a, b = (lo - 1) * n, (hi - 1) * n
    if n == 4 then
        -- normalised lerp along the shorter arc
        local dot = values[a + 1] * values[b + 1] + values[a + 2] * values[b + 2] + values[a + 3] * values[b + 3] + values[a + 4] * values[b + 4]
        local sgn = dot < 0 and -1 or 1
        local x = values[a + 1] + (values[b + 1] * sgn - values[a + 1]) * f
        local y = values[a + 2] + (values[b + 2] * sgn - values[a + 2]) * f
        local z = values[a + 3] + (values[b + 3] * sgn - values[a + 3]) * f
        local w = values[a + 4] + (values[b + 4] * sgn - values[a + 4]) * f
        local l = sqrt(x * x + y * y + z * z + w * w)
        out[1], out[2], out[3], out[4] = x / l, y / l, z / l, w / l
    else
        for c = 1, n do out[c] = values[a + c] + (values[b + c] - values[a + c]) * f end
    end
end

-- pose the hierarchy (node.global, glTF space). animName may be nil for the rest pose.
function Gltf.pose(asset, animName, time, loop)
    local nodes = asset.nodes
    local anim = animName and asset.anims[animName]
    for _, node in ipairs(nodes) do
        local pt, pr, ps = node.pt, node.pr, node.ps
        pt[1], pt[2], pt[3] = node.t[1], node.t[2], node.t[3]
        pr[1], pr[2], pr[3], pr[4] = node.r[1], node.r[2], node.r[3], node.r[4]
        ps[1], ps[2], ps[3] = node.s[1], node.s[2], node.s[3]
    end
    if anim and anim.duration > 0 then
        if loop then time = time % anim.duration elseif time > anim.duration then time = anim.duration end
        for _, tr in ipairs(anim.tracks) do
            local node = nodes[tr.node]
            sampleTrack(tr, time, tr.path == "translation" and node.pt or (tr.path == "rotation" and node.pr or node.ps))
        end
    end
    for _, i in ipairs(asset.order) do
        local node = nodes[i]
        if node.matrix then for k = 1, 16 do node.rest[k] = node.matrix[k] end
        else trs(node.pt, node.pr, node.ps, node.rest) end
        if node.parent then mul(nodes[node.parent].global, node.rest, node.global)
        else for k = 1, 16 do node.global[k] = node.rest[k] end end
    end
end

local rootTmp, nodeTmp = {}, {}

-- draw the current pose; world is a row-major model matrix in game space (frame:matrix())
function Gltf.draw(R, asset, world, params)
    mul(world, FIX, rootTmp)
    for _, node in ipairs(asset.nodes) do
        local model = node.mesh ~= nil and modelOf(asset, node)
        if model then R.drawModel(model, mul(rootTmp, node.global, nodeTmp), params) end
    end
end

function Gltf.duration(asset, animName)
    local a = asset.anims[animName]
    return a and a.duration or 0
end

-- rest-pose geometry in game space: the whole file, or only the subtree under a named node.
-- Returns a list of { tex =, verts = } (12 numbers per vertex) and the bounds x0,y0,z0,x1,y1,z1.
function Gltf.collect(asset, rootName)
    local ckey = rootName or "*"
    asset.collected = asset.collected or {}
    local hit = asset.collected[ckey]
    if hit then return hit.prims, unpack(hit.bounds) end
    local include
    if rootName then
        local root = assert(asset.byName[rootName], "no node " .. rootName .. " in " .. asset.path)
        include = {}
        local function mark(i)
            include[i] = true
            for _, c in ipairs(asset.nodes[i].children) do mark(c + 1) end
        end
        mark(root)
    end
    local out, m = {}, {}
    local b = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
    for i, node in ipairs(asset.nodes) do
        local prims = (not include or include[i]) and primsOf(asset, node)
        if prims then
            mul(FIX, node.restGlobal, m)
            for _, pr in ipairs(prims) do
                local v, t = pr.verts, {}
                for k = 0, #v - 12, 12 do
                    local x, y, z = v[k + 1], v[k + 2], v[k + 3]
                    local nx, ny, nz = v[k + 6], v[k + 7], v[k + 8]
                    local px, py, pz = m[1] * x + m[2] * y + m[3] * z + m[4], m[5] * x + m[6] * y + m[7] * z + m[8], m[9] * x + m[10] * y + m[11] * z + m[12]
                    local qx, qy, qz = m[1] * nx + m[2] * ny + m[3] * nz, m[5] * nx + m[6] * ny + m[7] * nz, m[9] * nx + m[10] * ny + m[11] * nz
                    local l = sqrt(qx * qx + qy * qy + qz * qz)
                    if l < 1e-9 then qx, qy, qz, l = 0, 1, 0, 1 end
                    t[k + 1], t[k + 2], t[k + 3], t[k + 4], t[k + 5] = px, py, pz, v[k + 4], v[k + 5]
                    t[k + 6], t[k + 7], t[k + 8] = qx / l, qy / l, qz / l
                    t[k + 9], t[k + 10], t[k + 11], t[k + 12] = v[k + 9], v[k + 10], v[k + 11], v[k + 12]
                    if px < b[1] then b[1] = px end
                    if py < b[2] then b[2] = py end
                    if pz < b[3] then b[3] = pz end
                    if px > b[4] then b[4] = px end
                    if py > b[5] then b[5] = py end
                    if pz > b[6] then b[6] = pz end
                end
                out[#out + 1] = { tex = pr.tex, verts = t }
            end
        end
    end
    asset.collected[ckey] = { prims = out, bounds = b }
    return out, unpack(b)
end

-- emit collected geometry into a meshbuilder: (v - origin) * scale, tinted by the builder colour.
-- keep(x, y, z) may filter triangles by their centroid (after origin and scale).
function Gltf.emitPrims(mb, prims, scale, ox, oy, oz, keep)
    local prev = mb.mat
    scale, ox, oy, oz = scale or 1, ox or 0, oy or 0, oz or 0
    local t = {}
    for _, pr in ipairs(prims) do
        mb:material(pr.tex)
        local v = pr.verts
        for k = 0, #v - 36, 36 do
            local ok = true
            if keep then
                ok = keep(((v[k + 1] + v[k + 13] + v[k + 25]) / 3 - ox) * scale, ((v[k + 2] + v[k + 14] + v[k + 26]) / 3 - oy) * scale,
                          ((v[k + 3] + v[k + 15] + v[k + 27]) / 3 - oz) * scale)
            end
            if ok then
                for j = k, k + 24, 12 do
                    t[1], t[2], t[3] = (v[j + 1] - ox) * scale, (v[j + 2] - oy) * scale, (v[j + 3] - oz) * scale
                    for c = 4, 12 do t[c] = v[j + c] end
                    mb:vertex(t)
                end
            end
        end
    end
    mb:material(prev)
end

-- bake the whole rest pose into a meshbuilder at its current transform (static props)
function Gltf.emit(mb, asset, scale)
    Gltf.emitPrims(mb, (Gltf.collect(asset)), scale)
end

-- axis-aligned bounds of the rest pose in game-local space (for colliders)
function Gltf.bounds(asset)
    local _, x0, y0, z0, x1, y1, z1 = Gltf.collect(asset)
    return x0, y0, z0, x1, y1, z1
end

-- drop the file bytes once everything needed has been baked (big files)
function Gltf.release(asset)
    asset.raw, asset.bin, asset.doc, asset.collected, asset.meshPrims = nil, nil, nil, {}, {}
    Gltf.cache[asset.cacheKey] = nil
end

return Gltf
