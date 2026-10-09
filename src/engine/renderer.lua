-- Low-resolution 3D renderer with PSX shaders and a post-processing pass.
local M3 = require("src.engine.math3d")
local Textures = require("src.engine.textures")

local R = {}
local lg = love.graphics

R.qualities = {
    { name = "LOW", w = 480, h = 270, drawDist = 200 },
    { name = "MEDIUM", w = 640, h = 360, drawDist = 280 },
    { name = "HIGH", w = 960, h = 540, drawDist = 360 },
    { name = "PSX 240P", w = 426, h = 240, drawDist = 240 },
}

-- full-screen display filters applied in the post pass
R.screenFilters = {
    { name = "OFF", crt = 0, vhs = 0 },
    { name = "CRT", crt = 1, vhs = 0 },
    { name = "VHS", crt = 0.6, vhs = 1 },
}

local identity = M3.identity()

local function loadShader(path)
    local src = love.filesystem.read(path)
    return lg.newShader(src)
end

function R.init(quality)
    R.world = loadShader("shaders/psx.glsl")
    R.billboard = loadShader("shaders/billboard.glsl")
    R.snowShader = loadShader("shaders/snow.glsl")
    R.skyShader = loadShader("shaders/sky.glsl")
    R.post = loadShader("shaders/post.glsl")
    R.cache = {}
    R.view = {}
    R.proj = {}
    R.viewProj = {}
    R.lights = {}
    R.time = 0
    R.stats = { draws = 0, tris = 0 }
    R.fx = { grain = 0.025, aberration = 0.4, levels = 32, tint = { 0, 0, 0, 0 }, frost = 0, radiation = 0,
             optic = 0, blur = 0, brightness = 1 }
    R.env = {
        fogColor = { 0.45, 0.47, 0.52 }, fogStart = 15, fogEnd = 170,
        sunDir = { 0.3, 0.35, -0.88 }, sunColor = { 0.45, 0.4, 0.38 }, ambient = { 0.42, 0.46, 0.55 },
        interiorAmbient = { 0.22, 0.17, 0.12 }, horizon = { 0.5, 0.48, 0.5 }, zenith = { 0.22, 0.22, 0.28 },
        sunGlow = { 0.9, 0.45, 0.2 },
        mist = { 0, 7, 0 },   -- ground height, thickness, density (see environment.lua)
    }
    R.spot = { 0, 0, 0, 0 }
    R.spotDir = { 0, 0, 1, 0.9 }
    R.buildSky()
    R.setQuality(quality or 2)
    local sup = lg.getSupported()
    R.instancing = sup and sup.instancing and not os.getenv("STEEL_NO_INSTANCING")
end

function R.setQuality(q)
    R.quality = R.qualities[q] or R.qualities[2]
    R.qualityIndex = q
    R.lowW, R.lowH = R.quality.w, R.quality.h
    R.canvas = lg.newCanvas(R.lowW, R.lowH, { format = "normal" })
    R.canvas:setFilter("nearest", "nearest")
    R.depth = lg.newCanvas(R.lowW, R.lowH, { format = "depth24", readable = false })
    R.drawDist = R.quality.drawDist
end

function R.buildSky()
    local MB = require("src.engine.meshbuilder")
    local mb = MB.new()
    mb.jitter = 0
    mb:sphere(0, 0, 0, 1, 1, 1, 16, 8)
    R.skyModel = mb:build()
end

-- uniform cache to avoid redundant sends
local function send(shader, name, ...)
    local c = R.cache[shader]
    if not c then c = {} R.cache[shader] = c end
    if not shader:hasUniform(name) then return end
    shader:send(name, ...)
end
R.send = send

local function sendCached(shader, name, v)
    local c = R.cache[shader]
    if not c then c = {} R.cache[shader] = c end
    if c[name] == v then return end
    c[name] = v
    if shader:hasUniform(name) then shader:send(name, v) end
end

function R.setCamera(cam)
    R.cam = cam
    local aspect = R.lowW / R.lowH
    M3.perspective(cam.fov, aspect, cam.near or 0.05, cam.far or 400, R.proj)
    M3.lookAt(cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz, cam.ux, cam.uy, cam.uz, R.view)
    M3.mul(R.proj, R.view, R.viewProj)
    -- camera right vector for billboards
    local fx, fy, fz, ux, uy, uz = cam.fx, cam.fy, cam.fz, cam.ux, cam.uy, cam.uz
    local rx, ry, rz = fy * uz - fz * uy, fz * ux - fx * uz, fx * uy - fy * ux
    local l = math.sqrt(rx * rx + ry * ry + rz * rz)
    R.camRight = { rx / l, ry / l, rz / l }
    R.camUp = { ry / l * fz - rz / l * fy, rz / l * fx - rx / l * fz, rx / l * fy - ry / l * fx }
end

-- lights: list of {x,y,z, radius, r,g,b, intensity}
function R.setLights(list)
    R.lights = list
end

function R.beginFrame()
    R.stats.draws, R.stats.tris = 0, 0
    lg.setCanvas({ R.canvas, depthstencil = R.depth })
    local fc = R.env.fogColor
    lg.clear(fc[1], fc[2], fc[3], 1, false, 1)
    lg.setDepthMode("lequal", true)
    lg.setMeshCullMode("none")
    lg.setColor(1, 1, 1, 1)
    lg.origin()
    local e = R.env
    local cam = R.cam

    -- sky
    local sh = R.skyShader
    lg.setShader(sh)
    lg.setDepthMode("always", false)
    send(sh, "viewProj", "row", R.viewProj)
    send(sh, "camPos", { cam.x, cam.y, cam.z })
    send(sh, "flipY", -1)
    send(sh, "horizonColor", e.horizon)
    send(sh, "zenithColor", e.zenith)
    send(sh, "sunDirSky", e.sunDir)
    send(sh, "sunGlow", e.sunGlow)
    send(sh, "time", R.time)
    for _, p in ipairs(R.skyModel.parts) do lg.draw(p.mesh) end
    lg.setDepthMode("lequal", true)

    -- world shader globals
    sh = R.world
    lg.setShader(sh)
    R.cache[sh] = {}
    send(sh, "viewProj", "row", R.viewProj)
    send(sh, "camPos", { cam.x, cam.y, cam.z })
    send(sh, "sunDir", e.sunDir)
    send(sh, "sunColor", e.sunColor)
    send(sh, "ambient", e.ambient)
    send(sh, "interiorAmbient", e.interiorAmbient)
    send(sh, "fogColor", e.fogColor)
    -- retro wobble (vertex snapping + affine UVs) is optional; default is stable textures
    if R.wobble then
        send(sh, "snapRes", { R.lowW * 0.5, R.lowH * 0.5 })
        send(sh, "affine", 0.35)
    else
        send(sh, "snapRes", { 8192, 8192 })
        send(sh, "affine", 0.0)
    end
    send(sh, "flipY", -1)
    send(sh, "mist", { e.mist[1], e.mist[2], e.mist[3], R.time })
    send(sh, "spotPos", R.spot)
    send(sh, "spotDir", R.spotDir)
    -- pick nearest lights
    local lights = R.lights
    local n = math.min(#lights, 10)
    if #lights > 10 then
        table.sort(lights, function(a, b)
            local da = (a[1] - cam.x) ^ 2 + (a[2] - cam.y) ^ 2 + (a[3] - cam.z) ^ 2 - a[4] * a[4]
            local db = (b[1] - cam.x) ^ 2 + (b[2] - cam.y) ^ 2 + (b[3] - cam.z) ^ 2 - b[4] * b[4]
            return da < db
        end)
    end
    local lp, lc = {}, {}
    for i = 1, 10 do
        local l = lights[i]
        if l and i <= n then
            lp[i] = { l[1], l[2], l[3], l[4] }
            lc[i] = { l[5], l[6], l[7], l[8] }
        else
            lp[i] = { 0, -1000, 0, 1 }
            lc[i] = { 0, 0, 0, 0 }
        end
    end
    send(sh, "lights", unpack(lp))
    send(sh, "lightCols", unpack(lc))
    send(sh, "numLights", n)
    R.defaults()
end

local cur = {}
function R.defaults()
    local sh = R.world
    local e = R.env
    sendCached(sh, "uInterior", 0)
    sendCached(sh, "uEmissive", 0)
    sendCached(sh, "uInstanced", 0)
    send(sh, "uTint", { 1, 1, 1, 1 })
    send(sh, "uvOffset", { 0, 0 })
    send(sh, "fogRange", { e.fogStart, e.fogEnd })
    sendCached(sh, "fogMax", 1)
    sendCached(sh, "alphaCut", 0.5)
    cur.tint, cur.uv, cur.fog, cur.amb = false, false, false, false
end

-- params: interior(0/1), emissive, tint{r,g,b,a}, uvOffset{u,v}, fog {start,end,max}
function R.drawModel(model, matrix, params)
    if not model then return end
    local sh = R.world
    send(sh, "model", "row", matrix or identity)
    if params then
        sendCached(sh, "uInterior", params.interior or 0)
        sendCached(sh, "uEmissive", params.emissive or 0)
        sendCached(sh, "alphaCut", params.alphaCut or 0.5)
        if params.tint then send(sh, "uTint", params.tint) cur.tint = true
        elseif cur.tint then send(sh, "uTint", { 1, 1, 1, 1 }) cur.tint = false end
        if params.amb then send(sh, "interiorAmbient", params.amb) cur.amb = true
        elseif cur.amb then send(sh, "interiorAmbient", R.env.interiorAmbient) cur.amb = false end
        if params.uv then send(sh, "uvOffset", params.uv) cur.uv = true
        elseif cur.uv then send(sh, "uvOffset", { 0, 0 }) cur.uv = false end
        if params.fog then
            send(sh, "fogRange", { params.fog[1], params.fog[2] })
            sendCached(sh, "fogMax", params.fog[3] or 1)
            cur.fog = true
        elseif cur.fog then
            send(sh, "fogRange", { R.env.fogStart, R.env.fogEnd })
            sendCached(sh, "fogMax", 1)
            cur.fog = false
        end
    else
        sendCached(sh, "uInterior", 0)
        sendCached(sh, "uEmissive", 0)
        sendCached(sh, "alphaCut", 0.5)
        if cur.amb then send(sh, "interiorAmbient", R.env.interiorAmbient) cur.amb = false end
        if cur.tint then send(sh, "uTint", { 1, 1, 1, 1 }) cur.tint = false end
        if cur.uv then send(sh, "uvOffset", { 0, 0 }) cur.uv = false end
        if cur.fog then
            send(sh, "fogRange", { R.env.fogStart, R.env.fogEnd })
            sendCached(sh, "fogMax", 1)
            cur.fog = false
        end
    end
    local parts = model.parts
    for i = 1, #parts do
        lg.draw(parts[i].mesh)
    end
    R.stats.draws = R.stats.draws + #parts
    R.stats.tris = R.stats.tris + model.tris
end

-- many copies of a small model (trees, rocks): per-instance position/yaw/scale from instMesh
function R.drawInstanced(model, instMesh, count)
    local sh = R.world
    sendCached(sh, "uInstanced", 1)
    sendCached(sh, "uInterior", 0)
    sendCached(sh, "uEmissive", 0)
    sendCached(sh, "alphaCut", 0.5)
    if cur.tint then send(sh, "uTint", { 1, 1, 1, 1 }) cur.tint = false end
    if cur.uv then send(sh, "uvOffset", { 0, 0 }) cur.uv = false end
    if cur.fog then
        send(sh, "fogRange", { R.env.fogStart, R.env.fogEnd })
        sendCached(sh, "fogMax", 1)
        cur.fog = false
    end
    local parts = model.parts
    for i = 1, #parts do
        local m = parts[i].mesh
        m:attachAttribute("InstXf", instMesh, "perinstance")
        m:attachAttribute("InstSc", instMesh, "perinstance")
        lg.drawInstanced(m, count)
    end
    sendCached(sh, "uInstanced", 0)
    R.stats.draws = R.stats.draws + #parts
    R.stats.tris = R.stats.tris + model.tris * count
end

-- visibility test of a world-space sphere against the camera (distance + rough frustum)
function R.visible(x, y, z, radius)
    local cam = R.cam
    local dx, dy, dz = x - cam.x, y - cam.y, z - cam.z
    local d2 = dx * dx + dy * dy + dz * dz
    local far = math.min(R.drawDist, R.env.fogEnd + 40) + radius
    if d2 > far * far then return false end
    if d2 < radius * radius then return true end
    local d = math.sqrt(d2)
    local along = (dx * cam.fx + dy * cam.fy + dz * cam.fz)
    -- cone test with generous angle
    local cosHalf = math.cos(math.min(cam.fov * 0.95 + 0.25, 1.5))
    return along + radius >= d * cosHalf - radius * 0.2
end

function R.useWorldShader()
    lg.setShader(R.world)
end

function R.endFrame(screenW, screenH)
    lg.setShader()
    lg.setDepthMode()
    lg.setCanvas()
    lg.origin()
    local sh = R.post
    lg.setShader(sh)
    local fx = R.fx
    send(sh, "lowRes", { R.lowW, R.lowH })
    send(sh, "time", R.time)
    send(sh, "grain", fx.grain)
    send(sh, "aberration", fx.aberration)
    send(sh, "colorLevels", fx.levels)
    send(sh, "screenTint", fx.tint)
    send(sh, "frost", fx.frost)
    send(sh, "radiation", fx.radiation)
    send(sh, "optic", fx.optic)
    send(sh, "aspect", screenW / screenH)
    send(sh, "blur", fx.blur)
    send(sh, "brightness", fx.brightness)
    local filter = R.screenFilters[R.screenFilter or 1] or R.screenFilters[1]
    send(sh, "crt", filter.crt)
    send(sh, "vhs", filter.vhs)
    lg.setColor(1, 1, 1, 1)
    lg.draw(R.canvas, 0, 0, 0, screenW / R.lowW, screenH / R.lowH)
    lg.setShader()
end

return R
