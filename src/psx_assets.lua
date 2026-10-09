-- Hand-made PSX model packs (assets/psx/<pack>/): one texture atlas and a set of .glb models each.
-- See assets/psx/CREDITS.md for the authors and licences.
local Gltf = require("src.engine.gltf")
local Textures = require("src.engine.textures")

local PA = {}

-- model by pack and name; registers the pack atlas as material "psx_<pack>" on first use
function PA.model(pack, name)
    local tex = "psx_" .. pack
    Textures.loadFile(tex, "assets/psx/" .. pack .. "/atlas.png")
    return Gltf.load("assets/psx/" .. pack .. "/" .. name .. ".glb", tex)
end

-- bake a static model into a world context at a local position (model front = local +x).
-- tint multiplies the model's baked colours.
function PA.put(ctx, pack, name, x, y, z, rot, scale, tint)
    local mb = ctx.mb
    local r, g, b = mb.r, mb.g, mb.b
    if tint then mb:color(tint[1], tint[2], tint[3]) else mb:color(1, 1, 1) end
    mb:push()
    mb:translate(x or 0, y or 0, z or 0)
    if rot and rot ~= 0 then mb:rotateY(rot) end
    Gltf.emit(mb, PA.model(pack, name), scale)
    mb:pop()
    mb:color(r, g, b)
end

-- user-supplied gun pack (assets/PSXMiscGuns, .obj) and the AK-74 (.glb)
PA.GUNS = "assets/PSXMiscGuns/"
PA.AK = "assets/psx_ak-74.glb"

function PA.has(path)
    return love.filesystem.getInfo(path) ~= nil
end

-- the AK-74 with its receiver at the origin, muzzle along +x
function PA.emitAK(mb)
    local asset = Gltf.load(PA.AK)
    local prims, x0, y0, z0, x1, y1, z1 = Gltf.collect(asset)
    mb:push()
    mb:rotateY(PA.AK_FLIP and math.pi or 0)
    Gltf.emitPrims(mb, prims, 1, (x0 + x1) / 2, y1 - 0.075, (z0 + z1) / 2)
    mb:pop()
    return (x1 - x0) / 2
end

-- local bounds of a model (x0, y0, z0, x1, y1, z1), scaled
function PA.bounds(pack, name, scale)
    local x0, y0, z0, x1, y1, z1 = Gltf.bounds(PA.model(pack, name))
    scale = scale or 1
    return x0 * scale, y0 * scale, z0 * scale, x1 * scale, y1 * scale, z1 * scale
end

return PA
