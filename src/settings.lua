-- Persistent player settings.
local json = require("src.lib.json")
local S = {}
local FILE = "settings.json"

S.RESOLUTIONS = { { 1280, 720 }, { 1600, 900 }, { 1920, 1080 }, { 1024, 576 }, { 2560, 1440 } }

S.data = { master = 0.8, sfx = 1.0, music = 0.6, sensitivity = 0.5, fullscreen = false, resolution = 1, quality = 2, wobble = false }

function S.load()
    local s = love.filesystem.read(FILE)
    if s then
        local d = json.decode(s)
        if type(d) == "table" then for k, v in pairs(d) do S.data[k] = v end end
    end
    return S.data
end

function S.save() love.filesystem.write(FILE, json.encode(S.data)) end

function S.sensitivity() return 0.0006 + S.data.sensitivity * 0.004 end

function S.applyWindow()
    local r = S.RESOLUTIONS[S.data.resolution] or S.RESOLUTIONS[1]
    local _, _, flags = love.window.getMode()
    if S.data.fullscreen then
        love.window.setMode(0, 0, { fullscreen = true, fullscreentype = "desktop", vsync = flags.vsync, depth = 24, resizable = true })
    else
        love.window.setMode(r[1], r[2], { fullscreen = false, vsync = flags.vsync, depth = 24, resizable = true, minwidth = 640, minheight = 360 })
    end
end

return S
