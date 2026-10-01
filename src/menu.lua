-- Main menu (live 3D background of the tank in the snow), pause menu and settings.
local U = require("src.utils")
local R = require("src.engine.renderer")
local Settings = require("src.settings")

local Menu = { sub = "main", t = 0 }
local G
local lg = love.graphics

function Menu.init(game) G = game end

function Menu.open()
    G.app = "menu"
    Menu.sub = "main"
    love.mouse.setRelativeMode(false)
    G.renderer.fx.optic = 0
    G.renderer.fx.tint = { 0, 0, 0, 0 }
    G.renderer.fx.frost = 0
    G.renderer.fx.radiation = 0
    -- put the scene in a known state for the backdrop
    G.tank.reset()
    G.player.reset()
    G.environment.time = 16.8
end

function Menu.update(dt)
    Menu.t = Menu.t + dt
    G.weather.update(dt)
    G.environment.update(dt)
    G.effects.update(dt)
    local T = G.tank
    -- gentle exhaust from the idling tank for atmosphere
    if math.random() < dt * 6 then
        local ex, ey, ez = T.frame:toWorld(-4.08, 2.8, 0.75)
        G.effects.smoke(ex, ey, ez, 0.35, 0.3, 0.3, 0.32, 3)
    end
end

function Menu.draw()
    local sw, sh = lg.getDimensions()
    local T = G.tank
    local a = Menu.t * 0.05 + 2.3
    local cam = G.camera
    local cx, cz = T.x + math.cos(a) * 11.5, T.z + math.sin(a) * 11.5
    local cy = G.world.height(cx, cz) + 2.2
    local tx, ty, tz = T.x, T.y + 1.8, T.z
    local fx, fy, fz = U.norm3(tx - cx, ty - cy, tz - cz)
    cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz = cx, cy, cz, fx, fy, fz
    cam.ux, cam.uy, cam.uz = 0, 1, 0
    cam.fov = cam.baseFov
    R.setCamera(cam)
    G.game.menuMode = true
    G.game.drawWorld()
    G.game.menuMode = false
    R.endFrame(sw, sh)
    local UI = G.ui
    UI.beginDraw()
    if Menu.sub == "settings" then
        Menu.drawSettings(function() Menu.sub = "main" end)
    else
        UI.text("STEEL HEARTH", 34, 46, { 0.92, 0.9, 0.85 }, UI.fontXL)
        UI.text("A NUCLEAR WINTER SURVIVAL", 38, 92, { 0.95, 0.72, 0.3 }, UI.font)
        local y = 140
        if UI.button("NEW GAME", 38, y, 150, 20) then G.startNewGame() end
        if UI.button("CONTINUE", 38, y + 26, 150, 20, G.save.exists()) then G.continueGame() end
        if UI.button("SETTINGS", 38, y + 52, 150, 20) then Menu.sub = "settings" end
        if UI.button("QUIT", 38, y + 78, 150, 20) then love.event.quit() end
        UI.text("LOVE2D PROTOTYPE  -  ALL ASSETS PROCEDURAL", 0, UI.VH - 12, { 0.6, 0.6, 0.6 }, UI.fontS, "right", UI.VW - 8)
    end
    UI.endDraw()
end

function Menu.drawPause()
    local UI = G.ui
    lg.setColor(0, 0, 0, 0.55)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    UI.text("PAUSED", 0, 60, UI.COL.text, UI.fontL, "center", UI.VW)
    local x, y = 245, 100
    local Game = G.game
    if UI.button("RESUME", x, y, 150, 18) then Game.state = "play" love.mouse.setRelativeMode(true) end
    if UI.button("SAVE GAME", x, y + 24, 150, 18, G.player.mode ~= "dead") then
        local ok = G.save.save()
        G.ui.notify(ok and "GAME SAVED" or "SAVE FAILED")
    end
    if UI.button("LOAD GAME", x, y + 48, 150, 18, G.save.exists()) then Game.loadGame() end
    if UI.button("SETTINGS", x, y + 72, 150, 18) then Game.state = "settings" end
    if UI.button("MAIN MENU", x, y + 96, 150, 18) then Menu.open() end
    if UI.button("QUIT", x, y + 120, 150, 18) then love.event.quit() end
    -- objectives & controls reminder
    UI.text("OBJECTIVE: " .. (G.missions.current() and G.missions.current().text or "COMPLETE"), 0, 260, UI.COL.amber, UI.fontS, "center", UI.VW)
    UI.text("TIME " .. G.environment.clockString() .. "   PLAYED " .. U.formatTime(Game.playTime), 0, 272, UI.COL.dim, UI.fontS, "center", UI.VW)
end

function Menu.drawSettings(back)
    local UI = G.ui
    local s = Settings.data
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    local x, y, w = 140, 50, 360
    UI.panel(x - 10, y - 14, w + 20, 250)
    UI.text("SETTINGS", x, y - 10, UI.COL.amber, UI.fontM)
    y = y + 14
    local old = { s.master, s.sfx, s.music }
    s.master = UI.slider("MASTER VOLUME", x, y, w, s.master)
    s.sfx = UI.slider("SFX VOLUME", x, y + 20, w, s.sfx)
    s.music = UI.slider("MUSIC VOLUME", x, y + 40, w, s.music)
    s.sensitivity = UI.slider("MOUSE SENSITIVITY", x, y + 60, w, s.sensitivity)
    if old[1] ~= s.master then G.audio.applyVolume() end
    local by = y + 84
    UI.text("FULLSCREEN", x, by + 4, UI.COL.text)
    if UI.button(s.fullscreen and "ON" or "OFF", x + 150, by, 90, 16) then
        s.fullscreen = not s.fullscreen
        Settings.applyWindow()
    end
    local r = Settings.RESOLUTIONS[s.resolution]
    UI.text("RESOLUTION", x, by + 26, UI.COL.text)
    if UI.button(string.format("%dx%d", r[1], r[2]), x + 150, by + 22, 90, 16, not s.fullscreen) then
        s.resolution = s.resolution % #Settings.RESOLUTIONS + 1
        Settings.applyWindow()
    end
    UI.text("GRAPHICS QUALITY", x, by + 48, UI.COL.text)
    if UI.button(R.qualities[s.quality].name, x + 150, by + 44, 90, 16) then
        s.quality = s.quality % #R.qualities + 1
        R.setQuality(s.quality)
    end
    UI.text("RETRO WOBBLE (PSX)", x, by + 70, UI.COL.text)
    if UI.button(s.wobble and "ON" or "OFF", x + 150, by + 66, 90, 16) then
        s.wobble = not s.wobble
        R.wobble = s.wobble
    end
    UI.text("Quality changes the internal render resolution and draw distance.", x, by + 92, UI.COL.dim, UI.fontS)
    if UI.button("BACK", x + w / 2 - 50, by + 108, 100, 18) then
        Settings.save()
        back()
    end
end

return Menu
