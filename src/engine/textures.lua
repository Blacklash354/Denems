-- Procedurally generated low-resolution textures (PSX style: tiny, nearest filtered).
local U = require("src.utils")
local T = { cache = {} }

local function clamp01(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end

local function make(name, size, fn, seed)
    -- drop-in replacement: assets/textures/<name>.png overrides the procedural texture
    local path = "assets/textures/" .. name .. ".png"
    if love.filesystem.getInfo(path) then
        local img = love.graphics.newImage(path, { mipmaps = true })
        img:setFilter("linear", "nearest", 8)
        img:setMipmapFilter("linear")
        img:setWrap("repeat", "repeat")
        T.cache[name] = img
        return img
    end
    local data = love.image.newImageData(size, size)
    local rng = U.rng(seed or #name * 977)
    data:mapPixel(function(x, y)
        local r, g, b, a = fn(x, y, size, rng)
        -- posterize slightly for a limited palette
        local q = 24
        return math.floor(clamp01(r) * q + 0.5) / q, math.floor(clamp01(g) * q + 0.5) / q,
               math.floor(clamp01(b) * q + 0.5) / q, a or 1
    end)
    -- mipmapped + anisotropic minification stops distant/grazing textures from crawling when
    -- the camera turns; magnification stays nearest for the chunky low-res look
    local img = love.graphics.newImage(data, { mipmaps = true })
    img:setFilter("linear", "nearest", 8)
    img:setMipmapFilter("linear")
    img:setWrap("repeat", "repeat")
    T.cache[name] = img
    return img
end

-- tileable noise using wrapped coordinates
local function tnoise(x, y, size, freq, seed)
    local f = freq
    local function wn(ix, iy) return U.hash2(ix % f, iy % f, seed) end
    local fx, fy = x / size * f, y / size * f
    local ix, iy = math.floor(fx), math.floor(fy)
    local tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    local a, b, c, d = wn(ix, iy), wn(ix + 1, iy), wn(ix, iy + 1), wn(ix + 1, iy + 1)
    return (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty
end
local function tfbm(x, y, size, freq, oct, seed)
    local v, amp, tot = 0, 1, 0
    for i = 1, oct do
        v = v + tnoise(x, y, size, freq, seed + i * 31) * amp
        tot = tot + amp
        amp = amp * 0.5
        freq = freq * 2
    end
    return v / tot
end
T.tnoise, T.tfbm = tnoise, tfbm

function T.init()
    make("white", 4, function() return 1, 1, 1 end)
    -- wind-packed snow: soft drifts with blue hollows, sastrugi ripples, crust sparkle and grit
    make("snow", 64, function(x, y, s, r)
        local drift = tfbm(x, y, s, 2, 3, 1)
        local fine = tfbm(x, y, s, 8, 2, 71)
        local warp = tnoise(x, y, s, 4, 72) * 2.2
        local ripple = math.sin(((x + y * 0.5) / s * 6 + warp) * 2 * math.pi)
        local v = 0.74 + drift * 0.17 + fine * 0.07 + (ripple > 0.55 and 0.045 or (ripple < -0.7 and -0.05 or 0))
        local shade = clamp01((0.5 - drift) * 2.2)                 -- hollows turn blue-grey
        local cr, cg, cb = v * (0.97 - shade * 0.09), v * (0.985 - shade * 0.04), v * (1.0 + shade * 0.03)
        local k = r:next()
        if k > 0.985 then cr, cg, cb = cr + 0.14, cg + 0.14, cb + 0.14       -- ice crystals
        elseif k < 0.006 then cr, cg, cb = cr * 0.62, cg * 0.6, cb * 0.56 end -- twigs and grit
        return cr, cg, cb
    end)
    -- driven road: packed grey snow, slush and patches worn down to the wet asphalt
    make("snowroad", 64, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 2)
        local fine = tfbm(x, y, s, 16, 2, 73)
        local worn = tfbm(x, y, s, 4, 3, 74)
        local v = 0.62 + n * 0.16 + fine * 0.07
        local cr, cg, cb = v * 0.95, v * 0.95, v * 0.97
        if worn > 0.6 then
            local k = 0.21 + fine * 0.12 + (r:next() > 0.9 and 0.06 or 0)
            cr, cg, cb = k, k * 0.98, k * 0.97
        elseif worn > 0.53 then
            cr, cg, cb = v * 0.7, v * 0.67, v * 0.64
        end
        return cr, cg, cb
    end)
    -- road surface: u runs across the road (edge to edge), v along it. Packed snow over asphalt, a
    -- faint dashed centre line and snowy shoulders. No baked ruts or stains: the tracks on the roads
    -- are the ones vehicles actually leave (effects.lua decals).
    make("road", 64, function(x, y, s, r)
        local u = (x + 0.5) / s
        local n = tfbm(x, y, s, 4, 3, 81)
        local fine = tfbm(x, y, s, 16, 2, 82)
        local v = 0.7 + n * 0.12 + fine * 0.06
        local cr, cg, cb = v * 0.95, v * 0.955, v * 0.975
        if math.abs(u - 0.5) < 0.018 and (y % 32) < 16 and n > 0.4 then cr, cg, cb = cr * 0.85 + 0.12, cg * 0.85 + 0.12, cb * 0.8 + 0.08 end
        local edge = math.min(u, 1 - u)
        if edge < 0.08 then
            local k = 1 - edge / 0.08
            cr, cg, cb = U.lerp(cr, 0.86 + fine * 0.08, k), U.lerp(cg, 0.88 + fine * 0.08, k), U.lerp(cb, 0.92 + fine * 0.07, k)
        end
        if r:next() > 0.985 then cr, cg, cb = cr + 0.08, cg + 0.08, cb + 0.09 end
        return cr, cg, cb
    end)
    -- dirt track: frozen, snow-covered earth; just a hint of earth where the snow is thin
    make("track", 64, function(x, y, s, r)
        local u = (x + 0.5) / s
        local n = tfbm(x, y, s, 4, 3, 83)
        local fine = tfbm(x, y, s, 16, 2, 84)
        local v = 0.78 + n * 0.12 + fine * 0.06
        local cr, cg, cb = v * 0.97, v * 0.98, v
        local thin = tfbm(x, y, s, 4, 2, 79)
        if thin > 0.7 then
            local k = U.clamp((thin - 0.7) * 3, 0, 0.18)
            cr, cg, cb = U.lerp(cr, 0.6, k), U.lerp(cg, 0.57, k), U.lerp(cb, 0.54, k)
        end
        local edge = math.min(u, 1 - u)
        if edge < 0.1 then cr, cg, cb = cr + (0.1 - edge) * 0.8, cg + (0.1 - edge) * 0.8, cb + (0.1 - edge) * 0.8 end
        return cr, cg, cb
    end)
    -- print of a track (cleats across, u = across the belt, v = along) and of a boot sole
    make("trackprint", 32, function(x, y, s, r)
        local cleat = (y % 8) < 3
        local edge = x < 2 or x > s - 3
        local v = cleat and 0.62 or 0.92
        if edge then v = 0.8 end
        v = v + (r:next() - 0.5) * 0.06
        return v, v, v * 1.02
    end)
    -- snow lying on the tank: white with an alpha mask, revealed bit by bit (alpha cut = 1 - cover)
    make("snowmask", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 93)
        local fine = tnoise(x, y, s, 16, 94)
        local a = U.clamp(n * 0.85 + fine * 0.25 - 0.05, 0.02, 0.99)
        local v = 0.9 + fine * 0.08
        return v * 0.96, v * 0.98, v, a
    end)
    -- Soviet prefab facade: large panels with dark seams and rust/water streaks
    make("panel", 64, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 85)
        local v = 0.62 + n * 0.14 + r:next() * 0.04
        local seam = (x % 32 == 0) or (y % 32 == 0)
        if seam then v = v * 0.55 end
        local streak = tnoise(x, 0, s, 16, 86)
        if streak > 0.7 and (y % 32) > 6 then v = v * (0.88 - (streak - 0.7)) end
        local stain = tfbm(x, y, s, 2, 2, 87)
        if stain > 0.66 then return v * 0.92, v * 0.86, v * 0.78 end
        return v, v * 0.99, v * 0.97
    end)
    -- faded wallpaper with a repeating pattern, torn in places
    make("wallpaper", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 88)
        local motif = ((x % 8 == 3 or x % 8 == 4) and (y % 8 == 2 or y % 8 == 5)) and -0.07 or 0
        local stripe = (x % 16 < 2) and -0.04 or 0
        local v = 0.58 + n * 0.1 + motif + stripe
        if n > 0.72 then local c = 0.5 + r:next() * 0.06 return c, c * 0.97, c * 0.92 end
        return v * 0.95, v * 0.88, v * 0.7
    end)
    make("linoleum", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 89)
        local check = ((math.floor(x / 8) + math.floor(y / 8)) % 2 == 0) and 0.05 or -0.03
        local v = 0.42 + n * 0.12 + check + r:next() * 0.03
        return v * 1.05, v * 0.82, v * 0.62
    end)
    make("tile", 32, function(x, y, s, r)
        if x % 8 == 0 or y % 8 == 0 then return 0.42, 0.44, 0.44 end
        local v = 0.7 + tnoise(x, y, s, 4, 90) * 0.12 + r:next() * 0.03
        return v * 0.9, v * 0.97, v
    end)
    -- quilted army winter cloth (khaki/olive) for coats and sleeves
    make("quilt", 32, function(x, y, s, r)
        local seam = (y % 6 == 0) and -0.07 or 0
        local v = 0.4 + tnoise(x, y, s, 8, 91) * 0.1 + seam + r:next() * 0.03
        return v * 0.92, v * 0.95, v * 0.72
    end)
    -- knitted glove / mitten
    make("knit", 16, function(x, y, s, r)
        local v = 0.3 + (((x + y) % 2 == 0) and 0.05 or 0) + r:next() * 0.05
        return v, v * 0.95, v * 0.88
    end)
    -- a tiny face: brows, eyes, nose shadow, mouth on skin
    make("face", 16, function(x, y, s, r)
        local cr, cg, cb = 0.78, 0.6, 0.5
        local n = r:next() * 0.04
        cr, cg, cb = cr + n, cg + n, cb + n
        if y == 5 and (x >= 3 and x <= 6 or x >= 9 and x <= 12) then return 0.25, 0.18, 0.14 end   -- brows
        if y == 7 and (x == 4 or x == 5 or x == 10 or x == 11) then return 0.12, 0.1, 0.1 end      -- eyes
        if (y == 9 or y == 10) and (x == 7 or x == 8) then return cr * 0.82, cg * 0.78, cb * 0.75 end -- nose
        if y == 12 and x >= 5 and x <= 10 then return 0.45, 0.25, 0.22 end                          -- mouth
        if y >= 13 then return cr * 0.85, cg * 0.82, cb * 0.8 end                                     -- stubble
        return cr, cg, cb
    end)
    make("glass", 16, function(x, y, s, r)
        local v = 0.25 + tnoise(x, y, s, 4, 92) * 0.15 + ((x == y or x + 1 == y) and 0.2 or 0)
        return v * 0.8, v * 0.9, v * 1.05
    end)
    make("ground", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 3)
        local v = 0.35 + n * 0.25 + r:next() * 0.05
        return v * 0.9, v * 0.82, v * 0.75
    end)
    make("ice", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 2, 3, 4)
        local crack = (math.abs(tnoise(x, y, s, 8, 44) - 0.5) < 0.03) and 0.15 or 0
        local v = 0.55 + n * 0.2 + crack
        return v * 0.8, v * 0.9, v * 1.05
    end)
    make("concrete", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 4, 5)
        local seam = (y % 16 == 0) and -0.12 or 0
        local stain = tnoise(x, y, s, 2, 55) > 0.7 and -0.1 or 0
        local v = 0.5 + n * 0.18 + seam + stain + r:next() * 0.05
        return v, v * 0.98, v * 0.95
    end)
    make("brick", 32, function(x, y, s, r)
        local row = math.floor(y / 4)
        local off = (row % 2) * 4
        local mortar = (y % 4 == 0) or ((x + off) % 8 == 0)
        if mortar then return 0.55, 0.53, 0.5 end
        local bn = U.hash2(math.floor((x + off) / 8), row, 7)
        local v = 0.42 + bn * 0.15 + r:next() * 0.06
        return v * 1.25, v * 0.72, v * 0.58
    end)
    make("plaster", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 4, 8)
        local peel = n > 0.7
        if peel then
            local v = 0.5 + r:next() * 0.05
            return v * 1.05, v * 0.9, v * 0.8
        end
        local v = 0.6 + n * 0.2 + r:next() * 0.04
        return v * 0.95, v * 0.95, v * 0.88
    end)
    make("wood", 32, function(x, y, s, r)
        local plank = math.floor(x / 8)
        local grain = math.sin((y + U.hash2(plank, 0, 9) * 30) * 0.9 + tnoise(x, y, s, 4, 10) * 4) * 0.06
        local seam = (x % 8 == 0) and -0.15 or 0
        local v = 0.36 + grain + seam + U.hash2(plank, 1, 3) * 0.1
        return v * 1.1, v * 0.85, v * 0.62
    end)
    make("bark", 16, function(x, y, s, r)
        local v = 0.22 + tnoise(x, y, s, 4, 12) * 0.12 + ((x % 4 == 0) and -0.06 or 0)
        return v * 1.05, v * 0.95, v * 0.85
    end)
    make("pine", 16, function(x, y, s, r)
        local n = tnoise(x, y, s, 4, 13)
        local snow = n > 0.6 and 0.45 or 0
        local v = 0.16 + r:next() * 0.08
        return v * 0.8 + snow, v * 1.15 + snow, v * 0.95 + snow
    end)
    make("metal", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 14)
        local rivet = ((x % 16 == 3) and (y % 8 == 3)) and 0.15 or 0
        local scratch = r:next() > 0.97 and 0.12 or 0
        local v = 0.32 + n * 0.12 + rivet + scratch
        return v * 0.95, v * 0.97, v
    end)
    make("steel", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 41)
        local rivet = ((x % 16 == 3) and (y % 8 == 3)) and 0.12 or 0
        local scratch = r:next() > 0.97 and 0.1 or 0
        local v = 0.55 + n * 0.12 + rivet + scratch
        return v * 0.96, v * 0.97, v
    end)
    make("rust", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 4, 15)
        local v = 0.3 + n * 0.25 + r:next() * 0.05
        return v * 1.35, v * 0.72, v * 0.45
    end)
    -- worn dark grey tank paint with rust, chips, mud and whitewash streaks
    -- Soviet 4BO green, half covered in a hasty winter whitewash, scuffed back to green and rust
    make("sovwinter", 64, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 4, 61)
        local v = 0.3 + n * 0.08
        local cr, cg, cb = v * 0.92, v * 1.12, v * 0.72
        local wash = tfbm(x, y, s, 2, 3, 62) + (tnoise(x, y, s, 16, 63) - 0.5) * 0.25
        if wash > 0.42 then
            local k = U.clamp((wash - 0.42) * 6, 0, 1)
            local w = 0.78 + n * 0.1
            cr, cg, cb = U.lerp(cr, w * 0.98, k), U.lerp(cg, w, k), U.lerp(cb, w * 0.97, k)
        end
        local streak = tnoise(x, 0, s, 16, 64)
        if streak > 0.7 and (y / s) > 0.25 then cr, cg, cb = cr * 0.82, cg * 0.8, cb * 0.78 end
        if tfbm(x, y, s, 8, 3, 65) > 0.74 then cr, cg, cb = 0.4, 0.27, 0.18 end
        if r:next() > 0.985 then cr, cg, cb = 0.45, 0.45, 0.43 end
        return cr, cg, cb
    end)
    make("tank", 64, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 4, 16)
        local camo = tfbm(x, y, s, 2, 2, 116)
        local v = 0.34 + n * 0.07
        local cr, cg, cb = v * 0.93, v * 0.97, v * 0.92
        if camo > 0.6 then cr, cg, cb = cr * 0.86, cg * 0.9, cb * 0.82 end
        local rustn = tfbm(x, y, s, 8, 3, 17)
        if rustn > 0.7 then cr, cg, cb = 0.36 + rustn * 0.08, 0.24, 0.16 end
        if r:next() > 0.985 then cr, cg, cb = 0.5, 0.5, 0.48 end -- chipped bare metal
        local streak = tnoise(x, 0, s, 16, 18)
        if streak > 0.72 and (y / s) > 0.3 then cr, cg, cb = cr * 0.8, cg * 0.78, cb * 0.74 end
        local wash = tfbm(x, y, s, 4, 2, 19)
        if wash > 0.74 then cr, cg, cb = cr + 0.12, cg + 0.13, cb + 0.15 end
        local mud = (y / s) > 0.82 and tnoise(x, y, s, 8, 20) > 0.45
        if mud then cr, cg, cb = 0.27, 0.23, 0.19 end
        return cr, cg, cb
    end)
    -- track links run along u (x): 4 links per repeat, each a different shade so the scroll reads clearly
    make("tread", 16, function(x, y, s, r)
        local link = math.floor(x / 4)
        local lx = x % 4
        local v = 0.2 + U.hash2(link, 0, 61) * 0.1 + r:next() * 0.04
        if lx == 0 then v = 0.06 elseif lx == 1 then v = v + 0.2 end       -- gap, then the worn cleat edge
        if (y == 5 or y == 10) and lx > 0 then v = v - 0.08 end             -- guide horn rows
        local snow = (link == 2 and lx > 1 and y > 2 and y < 13 and r:next() > 0.35) and 0.45 or 0
        return v * 1.1 + snow, v * 0.95 + snow, v * 0.85 + snow
    end)
    -- road wheel disc (cylinder caps map the whole texture): rubber tyre, dished steel, spokes, hub
    make("wheel", 32, function(x, y, s, r)
        local dx, dy = (x - 15.5) / 15.5, (y - 15.5) / 15.5
        local d = math.sqrt(dx * dx + dy * dy)
        local a = math.atan2(dy, dx)
        if d > 0.84 then local v = 0.09 + r:next() * 0.04 return v, v, v end
        if d < 0.16 then return 0.5, 0.5, 0.48 end
        if d < 0.3 then
            if math.floor((a + math.pi) / (2 * math.pi) * 6) % 2 == 0 and d > 0.2 then return 0.12, 0.12, 0.12 end
            return 0.3, 0.31, 0.29
        end
        local spoke = math.abs(((a + math.pi) / (2 * math.pi) * 6) % 1 - 0.5) < 0.16
        local v = (spoke and 0.4 or 0.24) + r:next() * 0.04
        if d > 0.72 then v = v + 0.08 end
        local cr, cg, cb = v * 0.95, v * 0.98, v * 0.92
        -- one mud/snow smear so the rotation is obvious
        if a > 0.3 and a < 1.3 and d > 0.4 then
            if d > 0.6 then cr, cg, cb = 0.8, 0.82, 0.86 else cr, cg, cb = 0.3, 0.24, 0.18 end
        end
        return cr, cg, cb
    end)
    make("interior", 32, function(x, y, s, r)
        -- ivory painted interior with wear
        local n = tfbm(x, y, s, 4, 3, 21)
        local rivet = ((x % 8 == 4) and (y % 16 == 2)) and -0.15 or 0
        local wear = n > 0.68 and -0.25 or 0
        local v = 0.68 + n * 0.12 + rivet + wear
        return v * 1.0, v * 0.92, v * 0.74
    end)
    make("brass", 16, function(x, y, s, r)
        local v = 0.6 + tnoise(x, y, s, 4, 22) * 0.2 + ((y % 8 == 0) and 0.1 or 0)
        return v * 1.1, v * 0.85, v * 0.38
    end)
    make("cloth_red", 16, function(x, y, s, r)
        local v = 0.45 + tnoise(x, y, s, 4, 23) * 0.2
        return v * 1.1, v * 0.18, v * 0.16
    end)
    make("cloth", 16, function(x, y, s, r)
        local v = 0.3 + tnoise(x, y, s, 4, 24) * 0.15 + (((x + y) % 3 == 0) and 0.04 or 0)
        return v * 0.9, v * 0.88, v * 0.75
    end)
    make("window", 16, function(x, y, s, r)
        local frame = (x % 8 == 0) or (y % 8 == 0)
        if frame then return 0.3, 0.25, 0.2 end
        local v = 0.07 + r:next() * 0.05
        return v, v * 1.05, v * 1.2
    end)
    make("roof", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 25)
        local v = 0.8 + n * 0.15
        if n < 0.3 then return 0.35, 0.3, 0.28 end -- exposed tin/rust
        return v * 0.95, v * 0.97, v
    end)
    make("crate", 16, function(x, y, s, r)
        local edge = (x == 0 or y == 0 or x == s - 1 or y == s - 1 or x == y or x == s - 1 - y)
        local v = 0.3 + tnoise(x, y, s, 4, 26) * 0.1 + (edge and 0.08 or 0)
        return v * 0.95, v * 0.98, v * 0.75
    end)
    make("gauge", 16, function(x, y, s, r)
        local dx, dy = x - 7.5, y - 7.5
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 7 then return 0.1, 0.1, 0.1 end
        if math.abs(dx - dy * 0.6) < 0.8 and d < 6 then return 0.8, 0.1, 0.05 end
        if d > 5.5 and (math.floor(math.atan2(dy, dx) * 4) % 2 == 0) then return 0.15, 0.15, 0.12 end
        return 0.85, 0.82, 0.7
    end)
    make("sign", 32, function(x, y, s, r)
        local v = 0.6 + tnoise(x, y, s, 4, 27) * 0.2
        local border = x < 2 or y < 2 or x > s - 3 or y > s - 3
        if border then return 0.7, 0.1, 0.08 end
        -- crude cyrillic-ish glyph blocks
        if y > 10 and y < 22 and (math.floor(x / 4) % 2 == 0) and x > 4 and x < 28 then return 0.1, 0.1, 0.1 end
        return v, v, v * 0.95
    end)
    make("grille", 16, function(x, y, s, r)
        if x % 4 == 0 then return 0.38, 0.38, 0.36 end
        return 0.08, 0.08, 0.08
    end)
    make("rubble", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 8, 3, 28)
        local v = 0.35 + n * 0.3
        local snow = tnoise(x, y, s, 4, 29) > 0.55 and 0.35 or 0
        return v + snow, v * 0.95 + snow, v * 0.9 + snow
    end)
    make("lattice", 16, function(x, y, s, r)
        local on = (x < 2) or (x > s - 3) or (math.abs(x - y) < 1.5) or (math.abs(x - (s - 1 - y)) < 1.5)
        if on then return 0.55, 0.25, 0.2, 1 end
        return 0, 0, 0, 0
    end)
    make("star", 16, function(x, y, s)
        local dx, dy = x - 7.5, y - 7.5
        local a = math.atan2(dy, dx)
        local d = math.sqrt(dx * dx + dy * dy)
        local rr = 3.2 + 3.4 * (0.5 + 0.5 * math.cos(5 * (a + math.pi / 2)))^3
        if d < rr then return 0.85, 0.12, 0.1 end
        return 0.3, 0.35, 0.28
    end)
    make("cross", 16, function(x, y, s)
        local cx, cy = math.abs(x - 7.5), math.abs(y - 7.5)
        if (cx < 2 or cy < 2) and cx < 7 and cy < 7 then
            if cx < 1 or cy < 1 then return 0.1, 0.1, 0.1 end
            return 0.85, 0.85, 0.82
        end
        return 0.3, 0.31, 0.29
    end)
    make("hazard", 16, function(x, y)
        if math.floor((x + y) / 4) % 2 == 0 then return 0.75, 0.6, 0.1 end
        return 0.1, 0.1, 0.1
    end)
    make("paper", 16, function(x, y, s, r)
        if y % 3 == 0 and x > 2 and x < 13 then return 0.3, 0.3, 0.3 end
        return 0.8, 0.78, 0.68
    end)
    make("flesh", 32, function(x, y, s, r)
        local n = tfbm(x, y, s, 4, 3, 30)
        local v = 0.3 + n * 0.2
        local vein = math.abs(tnoise(x, y, s, 4, 31) - 0.5) < 0.05
        if vein then return 0.55, 0.12, 0.1 end
        return v * 1.25, v * 0.75, v * 0.72
    end)
    make("fur", 16, function(x, y, s, r)
        local v = 0.25 + r:next() * 0.2 + ((y % 3 == 0) and -0.05 or 0)
        local frost = r:next() > 0.8 and 0.35 or 0
        return v * 0.85 + frost, v * 0.85 + frost, v * 0.9 + frost
    end)
    make("smoke", 16, function(x, y, s, r)
        local dx, dy = (x - 7.5) / 7.5, (y - 7.5) / 7.5
        local d = math.sqrt(dx * dx + dy * dy)
        local a = clamp01(1 - d) * (0.6 + tnoise(x, y, s, 4, 32) * 0.6)
        return 1, 1, 1, a
    end)
    make("grass", 16, function(x, y, s, r)
        -- dry stalks poking out of the snow (alpha cut-out)
        local blade = U.hash2(x, 0, 51)
        local height = 4 + blade * 11
        if (s - y) < height and (x % 3 ~= 1 or blade > 0.6) then
            local v = 0.45 + U.hash2(x, y, 52) * 0.2
            return v * 1.05, v * 0.88, v * 0.55, 1
        end
        return 0, 0, 0, 0
    end)
    make("blob", 16, function(x, y, s)
        local dx, dy = math.abs((x - 7.5) / 7.5), math.abs((y - 7.5) / 7.5)
        local d = (dx ^ 4 + dy ^ 4) ^ 0.25
        local a = 1 - math.max(0, math.min(1, (d - 0.72) / 0.28))
        return 1, 1, 1, a
    end)
    make("flare", 16, function(x, y, s)
        local dx, dy = (x - 7.5) / 7.5, (y - 7.5) / 7.5
        local d = math.sqrt(dx * dx + dy * dy)
        local a = clamp01(1 - d)
        return 1, 1, 1, a * a
    end)
end

-- register an image file (model atlases etc.) under a material name
function T.loadFile(name, path)
    if T.cache[name] then return T.cache[name] end
    local img = love.graphics.newImage(path, { mipmaps = true })
    img:setFilter("linear", "nearest", 8)
    img:setMipmapFilter("linear")
    img:setWrap("repeat", "repeat")
    T.cache[name] = img
    return img
end

function T.get(name) return T.cache[name] or T.cache.white end

return T
