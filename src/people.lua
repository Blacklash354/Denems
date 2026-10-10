-- People built from Quaternius' modular men and women (CC0): soldiers in greatcoats and olive helmets,
-- bandits in black, survivors with packs. tools/people_convert.py cuts the original skinned figures
-- into the rig's rigid parts (torso, head, upper arm, forearm + hand, thigh, shin + foot per side), each
-- re-based on its joint, and stores the joint layout in the file; humans.lua poses them with the same
-- walk / aim / sit / death code as the procedural outfits.
local Gltf = require("src.engine.gltf")
local MB = require("src.engine.meshbuilder")

local P = { cache = {} }

P.DIR = "assets/people/"
P.PARTS = { "torso", "head", "upperL", "foreL", "upperR", "foreR", "thighL", "shinL", "thighR", "shinR" }

-- which figures each faction wears (stable per NPC id)
P.LOOKS = {
    military = { "soldier", "soldier", "soldier_mask", "soldier", "sergeant", "soldier_winter" },
    bandit = { "bandit", "bandit_leather" },
    loner = { "loner", "loner_farmer", "loner_woman", "loner" },
}

function P.available(name)
    return love.filesystem.getInfo(P.DIR .. name .. ".glb") ~= nil
end

-- part models and joint layout for one figure, or nil when its file is missing
function P.build(name)
    if P.cache[name] ~= nil then return P.cache[name] or nil end
    P.cache[name] = false
    if not P.available(name) then return nil end
    local asset = Gltf.load(P.DIR .. name .. ".glb")
    local set = { people = true, name = name }
    for i, part in ipairs(P.PARTS) do
        if asset.byName[part] then
            local mb = MB.new(800 + i)
            mb.jitter = 0
            Gltf.emitPrims(mb, (Gltf.collect(asset, part)))
            set[part] = mb:build()
        end
    end
    local d = asset.doc.extras and asset.doc.extras.dims
    if not d or not set.torso then return nil end
    set.dims = d
    Gltf.release(asset)
    P.cache[name] = set
    return set
end

return P
