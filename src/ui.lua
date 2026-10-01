-- Minimal, immersive retro-military UI drawn on a 640x360 virtual canvas.
local U = require("src.utils")
local Inv = require("src.inventory")
local I = require("src.interaction")

local UI = { notes = {}, VW = 640, VH = 360 }
local G
local lg = love.graphics

UI.COL = {
    text = { 0.86, 0.86, 0.82 }, dim = { 0.55, 0.56, 0.55 }, panel = { 0.05, 0.06, 0.07, 0.72 }, edge = { 0.4, 0.42, 0.42, 0.8 },
    warn = { 0.95, 0.35, 0.25 }, amber = { 0.95, 0.72, 0.3 }, good = { 0.55, 0.85, 0.5 }, cold = { 0.55, 0.75, 1.0 }, rad = { 0.7, 0.95, 0.35 },
}
local COL = UI.COL

function UI.init(game)
    G = game
    UI.canvas = lg.newCanvas(UI.VW, UI.VH)
    UI.canvas:setFilter("nearest", "nearest")
    UI.font = lg.newFont(10, "mono")
    UI.fontS = lg.newFont(8, "mono")
    UI.fontM = lg.newFont(13, "mono")
    UI.fontL = lg.newFont(22, "mono")
    UI.fontXL = lg.newFont(40, "mono")
    for _, f in ipairs({ UI.font, UI.fontS, UI.fontM, UI.fontL, UI.fontXL }) do f:setFilter("nearest", "nearest") end
    UI.warn = nil
    UI.area = nil
    UI.objMsg = nil
    UI.mouseDown = false
end

---------------------------------------------------------------------------
-- messages
---------------------------------------------------------------------------
function UI.notify(text)
    for _, n in ipairs(UI.notes) do if n.text == text then n.t = 4 return end end
    table.insert(UI.notes, { text = text, t = 4 })
    if #UI.notes > 5 then table.remove(UI.notes, 1) end
end
function UI.warning(text) UI.warn = { text = text, t = 4 } end
function UI.areaTitle(text) UI.area = { text = text, t = 5 } end
function UI.objective(head, text) UI.objMsg = { head = head, text = text, t = 5 } end

function UI.update(dt)
    for i = #UI.notes, 1, -1 do
        local n = UI.notes[i]
        n.t = n.t - dt
        if n.t <= 0 then table.remove(UI.notes, i) end
    end
    for _, k in ipairs({ "warn", "area", "objMsg" }) do
        if UI[k] then UI[k].t = UI[k].t - dt if UI[k].t <= 0 then UI[k] = nil end end
    end
end

---------------------------------------------------------------------------
-- drawing helpers
---------------------------------------------------------------------------
local function panel(x, y, w, h, alpha)
    lg.setColor(COL.panel[1], COL.panel[2], COL.panel[3], (alpha or 1) * COL.panel[4])
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(COL.edge[1], COL.edge[2], COL.edge[3], (alpha or 1) * COL.edge[4])
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end
UI.panel = panel

local function text(s, x, y, col, font, align, w)
    lg.setFont(font or UI.font)
    col = col or COL.text
    lg.setColor(0, 0, 0, (col[4] or 1) * 0.7)
    if align then lg.printf(s, x + 1, y + 1, w, align) else lg.print(s, x + 1, y + 1) end
    lg.setColor(col[1], col[2], col[3], col[4] or 1)
    if align then lg.printf(s, x, y, w, align) else lg.print(s, x, y) end
end
UI.text = text

local function bar(x, y, w, h, v, col)
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(col[1], col[2], col[3], 0.9)
    lg.rectangle("fill", x, y, math.floor(w * U.clamp(v, 0, 1)), h)
    lg.setColor(1, 1, 1, 0.25)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end
UI.bar = bar

function UI.mouse()
    local mx, my = love.mouse.getPosition()
    local sw, sh = lg.getDimensions()
    return mx * UI.VW / sw, my * UI.VH / sh
end

-- immediate-mode button
function UI.button(label, x, y, w, h, enabled)
    local mx, my = UI.mouse()
    local hover = enabled ~= false and mx >= x and mx <= x + w and my >= y and my <= y + h
    panel(x, y, w, h, enabled == false and 0.4 or 1)
    if hover then
        lg.setColor(0.9, 0.7, 0.3, 0.25)
        lg.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    end
    text(label, x, y + h / 2 - 6, enabled == false and COL.dim or (hover and COL.amber or COL.text), UI.font, "center", w)
    if hover and UI.clicked then
        UI.clicked = false
        if G.audio then G.audio.play("ui", { volume = 0.6 }) end
        return true
    end
    return false
end

function UI.slider(label, x, y, w, value)
    local mx, my = UI.mouse()
    text(label, x, y, COL.text)
    local bx, by, bw = x + 150, y + 3, w - 190
    bar(bx, by, bw, 7, value, COL.amber)
    text(string.format("%3d%%", math.floor(value * 100 + 0.5)), bx + bw + 8, y, COL.dim)
    if love.mouse.isDown(1) and my >= y - 3 and my <= y + 13 and mx >= bx - 4 and mx <= bx + bw + 4 then
        value = U.clamp((mx - bx) / bw, 0, 1)
    end
    return value
end

---------------------------------------------------------------------------
-- HUD pieces
---------------------------------------------------------------------------
local DIRS = { [0] = "E", [45] = "SE", [90] = "S", [135] = "SW", [180] = "W", [225] = "NW", [270] = "N", [315] = "NE" }

local function compass(cx, y)
    local cam = G.camera
    local yaw = math.deg(math.atan2(cam.fz, cam.fx)) % 360
    local w = 220
    lg.setScissor(0, 0, 0, 0)
    lg.setScissor()
    for a = -120, 120, 5 do
        local deg = (yaw + a) % 360
        local x = cx + a / 120 * (w / 2)
        local fade = 1 - math.abs(a) / 120
        local d = math.floor(deg / 5 + 0.5) * 5 % 360
        lg.setColor(1, 1, 1, 0.5 * fade)
        if d % 45 == 0 then
            lg.rectangle("fill", x, y, 1, 5)
            text(DIRS[d], x - 10, y + 5, { 1, 1, 1, 0.85 * fade }, UI.fontS, "center", 20)
        elseif d % 15 == 0 then
            lg.rectangle("fill", x, y, 1, 3)
        end
    end
    lg.setColor(1, 1, 1, 0.8)
    lg.rectangle("fill", cx, y - 3, 1, 3)
    -- objective direction marker
    local tx, tz = UI.objectiveTarget()
    if tx then
        local a = math.deg(math.atan2(tz - cam.z, tx - cam.x)) % 360
        local rel = (a - yaw + 540) % 360 - 180
        if math.abs(rel) < 120 then
            local x = cx + rel / 120 * (w / 2)
            lg.setColor(COL.amber[1], COL.amber[2], COL.amber[3], 0.9)
            lg.polygon("fill", x - 3, y - 6, x + 3, y - 6, x, y - 2)
        end
    end
end

function UI.objectiveTarget()
    local M = G.missions
    local cur = M.current()
    if not cur then return nil end
    local W = G.world
    local id = cur.id
    if id == "tower" or id == "transmitter" then return W.tower.x, W.tower.z end
    if (id == "bunker" or id == "keycard") and M.revealed.bunker then return W.bunker.x, W.bunker.z end
    if (id == "plant" or id == "control" or id == "signal") and M.revealed.plant then return W.controlRoom.x0, W.controlRoom.z0 + 13 end
    return nil
end

local function statusPanel()
    local pl = G.player
    local S = G.survival
    local x, y = 10, UI.VH - 70
    local lines = {}
    if S.coldLevel > 0.05 or pl.warmth < 60 then lines[#lines + 1] = { "COLD", COL.cold } end
    if S.radLevel > 0.05 or pl.radiation > 5 then lines[#lines + 1] = { "RADIATION", COL.rad } end
    local yy = y - #lines * 11
    for _, l in ipairs(lines) do
        lg.setColor(l[2][1], l[2][2], l[2][3], 0.85 + 0.15 * math.sin(love.timer.getTime() * 5))
        lg.circle("fill", x + 4, yy + 6, 3, 6)
        text(l[1], x + 11, yy, l[2], UI.fontS)
        yy = yy + 11
    end
    local rows = { { "HEALTH", pl.health / 100, COL.warn }, { "STAMINA", pl.stamina / 100, { 0.8, 0.8, 0.75 } },
                   { "WARMTH", pl.warmth / 100, COL.cold } }
    if pl.radiation > 1 then rows[#rows + 1] = { "RAD DOSE", pl.radiation / 100, COL.rad } end
    for i, r in ipairs(rows) do
        local ry = y + (i - 1) * 12
        text(r[1], x, ry, COL.dim, UI.fontS)
        bar(x + 52, ry + 2, 70, 5, r[2], r[3])
    end
    if pl.flashlight or pl.battery < 25 then
        text(string.format("LIGHT %d%%", pl.battery), x, y + #rows * 12, pl.battery < 25 and COL.warn or COL.dim, UI.fontS)
    end
end

local function weaponPanel()
    local Wp = G.weapons
    if not Wp.canUse() then return end
    local def = Wp.DEFS[Wp.current]
    local x, y = UI.VW - 130, UI.VH - 36
    text(def.name, x, y, COL.dim, UI.fontS, "right", 120)
    local reserve = G.inventory.player:count(def.ammo)
    local s = Wp.reloadT > 0 and "RELOADING" or string.format("%d / %d", Wp.mag[Wp.current], reserve)
    text(s, x, y + 10, Wp.mag[Wp.current] == 0 and COL.warn or COL.text, UI.fontM, "right", 120)
end

local function prompt()
    local cur = I.current
    if not cur then return end
    local s = I.currentText
    if not s then return end
    local key = "E"
    local w = UI.font:getWidth(s) + 30
    local x, y = UI.VW / 2 - w / 2, UI.VH / 2 + 26
    panel(x, y, w, 16)
    lg.setColor(0.85, 0.85, 0.8, 1)
    lg.rectangle("line", x + 3.5, y + 3.5, 10, 9)
    text(key, x + 3, y + 3, COL.text, UI.fontS, "center", 12)
    text(s, x + 18, y + 2, COL.text)
    if I.holding then
        bar(x, y + 17, w, 3, I.progress, COL.amber)
    end
end

local function objectivesPanel(force)
    local M = G.missions
    local a = force and 1 or U.clamp(M.flash / 1.5, 0, 1)
    if a <= 0 then return end
    local x, w = UI.VW - 185, 175
    local opts = {}
    for _, o in ipairs(M.optional) do if o.shown then opts[#opts + 1] = o end end
    local h = 38 + #opts * 11 + 6
    local y = 8
    panel(x, y, w, h, a)
    local cur = M.current()
    text("MAIN OBJECTIVE", x + 6, y + 4, { 0.9, 0.9, 0.85, a }, UI.fontS)
    text(cur and cur.text or "-", x + 6, y + 14, { COL.amber[1], COL.amber[2], COL.amber[3], a }, UI.fontS)
    text("OPTIONAL", x + 6, y + 28, { 0.9, 0.9, 0.85, a }, UI.fontS)
    for i, o in ipairs(opts) do
        local oy = y + 38 + (i - 1) * 11
        lg.setColor(1, 1, 1, 0.8 * a)
        lg.rectangle("line", x + 7.5, oy + 2.5, 6, 6)
        if o.done then
            lg.setColor(COL.good[1], COL.good[2], COL.good[3], a)
            lg.line(x + 8, oy + 5, x + 10, oy + 8, x + 14, oy + 1)
        end
        text(M.optText(o), x + 18, oy, o.done and { 0.55, 0.6, 0.55, a } or { 0.85, 0.85, 0.8, a }, UI.fontS)
    end
end

local function messages()
    local y = UI.VH - 110
    for i = #UI.notes, 1, -1 do
        local n = UI.notes[i]
        local a = U.clamp(n.t, 0, 1)
        text(n.text, 0, y, { 0.9, 0.88, 0.8, a }, UI.fontS, "center", UI.VW)
        y = y - 10
    end
    if UI.warn then
        local a = U.clamp(UI.warn.t, 0, 1) * (0.7 + 0.3 * math.sin(love.timer.getTime() * 10))
        text(UI.warn.text, 0, 60, { COL.warn[1], COL.warn[2], COL.warn[3], a }, UI.fontL, "center", UI.VW)
    end
    if UI.area then
        local t = UI.area.t
        local a = math.min(1, t, (5 - t) * 2)
        text(UI.area.text, 0, 120, { 0.92, 0.9, 0.85, a }, UI.fontL, "center", UI.VW)
        lg.setColor(0.9, 0.9, 0.85, a * 0.6)
        lg.rectangle("fill", UI.VW / 2 - 80, 148, 160, 1)
    end
    if UI.objMsg then
        local t = UI.objMsg.t
        local a = math.min(1, t, (5 - t) * 2)
        text(UI.objMsg.head, 0, 160, { COL.amber[1], COL.amber[2], COL.amber[3], a }, UI.fontS, "center", UI.VW)
        text(UI.objMsg.text, 0, 170, { 0.9, 0.9, 0.85, a }, UI.fontM, "center", UI.VW)
    end
end

---------------------------------------------------------------------------
-- tank station instruments
---------------------------------------------------------------------------
local function tankSilhouette(x, y, s)
    local T = G.tank
    local function col(v)
        if v > 66 then return { 0.6, 0.75, 0.55, 0.9 } elseif v > 33 then return { 0.95, 0.7, 0.3, 0.9 } end
        return { 0.95, 0.3, 0.2, 0.9 }
    end
    local c = T.comp
    lg.setLineWidth(1)
    lg.setColor(col(c.trackL)) lg.rectangle("fill", x, y, 40 * s, 5 * s)
    lg.setColor(col(c.trackR)) lg.rectangle("fill", x, y + 17 * s, 40 * s, 5 * s)
    lg.setColor(col(c.hull)) lg.rectangle("line", x + 3 * s, y + 5 * s, 34 * s, 12 * s)
    lg.setColor(col(c.engine)) lg.rectangle("fill", x + 4 * s, y + 7 * s, 8 * s, 8 * s)
    lg.setColor(col(c.turret))
    local cx, cy = x + 22 * s, y + 11 * s
    lg.circle("line", cx, cy, 5 * s, 10)
    lg.setColor(col(c.cannon))
    local a = T.turretYaw
    lg.line(cx, cy, cx + math.cos(a) * 18 * s, cy + math.sin(a) * 18 * s)
end
UI.tankSilhouette = tankSilhouette

local function driverUI()
    local T = G.tank
    local x, y = 12, UI.VH - 64
    panel(x, y, 150, 54)
    local gear = T.gear == -1 and "R" or (T.gear == 0 and "N" or tostring(T.gear))
    text("GEAR", x + 6, y + 4, COL.dim, UI.fontS) text(gear, x + 40, y + 2, COL.text, UI.font)
    text("RPM", x + 6, y + 15, COL.dim, UI.fontS) text(string.format("%d", T.rpm), x + 40, y + 13, COL.text, UI.font)
    text("SPD", x + 6, y + 26, COL.dim, UI.fontS) text(string.format("%d KM/H", math.abs(T.speed) * 3.6), x + 40, y + 24, COL.text, UI.font)
    text("FUEL", x + 6, y + 37, COL.dim, UI.fontS) text(string.format("%d%%", T.fuel), x + 40, y + 35, T.fuel < 15 and COL.warn or COL.text, UI.font)
    tankSilhouette(x + 98, y + 14, 1)
    local eng = T.engineOn and "ENGINE RUNNING" or (T.engineStarting > 0 and "STARTING..." or "ENGINE OFF")
    text(eng, x + 6, y - 11, T.engineOn and COL.good or COL.amber, UI.fontS)
    text("[W/S] THROTTLE  [A/D] STEER  [SPACE] BRAKE  [F] ENGINE  [L] LIGHTS  [E] LEAVE SEAT", 0, UI.VH - 9, COL.dim, UI.fontS, "center", UI.VW)
end

local function gunnerUI(optic)
    local T = G.tank
    local inv = G.inventory.tank
    local x, y = UI.VW - 132, UI.VH - 74
    if optic then x, y = UI.VW / 2 + 95, UI.VH / 2 + 80 end
    panel(x, y, 120, 58, optic and 0.6 or 1)
    text("AP SHELL", x + 6, y + 4, T.ammoSelect == "AP" and COL.amber or COL.text, UI.fontS)
    text(tostring(inv:count("ap_shell")), x + 80, y + 4, COL.text, UI.fontS)
    text("HE SHELL", x + 6, y + 14, T.ammoSelect == "HE" and COL.amber or COL.text, UI.fontS)
    text(tostring(inv:count("he_shell")), x + 80, y + 14, COL.text, UI.fontS)
    local st
    if T.reloadT > 0 then st = "LOADING " .. (T.reloading or "")
    elseif T.loaded then st = "LOADED: " .. T.loaded
    else st = "GUN EMPTY [R]" end
    text(st, x + 6, y + 28, T.loaded and COL.good or COL.amber, UI.fontS)
    if T.reloadT > 0 then bar(x + 6, y + 40, 108, 4, 1 - T.reloadT / 4.2, COL.amber) end
    text("NEXT: " .. T.ammoSelect, x + 6, y + 46, COL.dim, UI.fontS)
    if not optic then
        tankSilhouette(x - 60, y + 20, 1)
        text("[MOUSE/WASD] TRAVERSE  [LMB] FIRE  [RMB] OPTIC  [R] LOAD  [T] AMMO  [E] LEAVE", 0, UI.VH - 9, COL.dim, UI.fontS, "center", UI.VW)
    else
        text("[WHEEL] ZOOM  [RMB] EXIT OPTIC", 0, UI.VH - 9, COL.dim, UI.fontS, "center", UI.VW)
    end
end

local function haloed(fn)
    lg.push()
    lg.setColor(0.85, 0.82, 0.7, 0.35)
    lg.translate(1, 1)
    fn(true)
    lg.pop()
    lg.setColor(0.05, 0.05, 0.05, 0.92)
    fn(false)
end

local function opticReticle()
    haloed(function(h) UI.opticLines(h) end)
    local Gn = G.stations.gunner
    local cx, cy = UI.VW / 2, UI.VH / 2
    text(Gn.zoom == 2 and "5x" or "2.5x", cx - 160, cy + 120, { 0.75, 0.8, 0.7, 0.8 }, UI.fontS)
end

function UI.opticLines(halo)
    local cx, cy = UI.VW / 2, UI.VH / 2
    local tc = halo and { 0.85, 0.82, 0.7, 0.35 } or { 0.05, 0.05, 0.05, 0.92 }
    lg.setColor(tc)
    lg.setLineWidth(1)
    -- central aiming chevron (TZF style)
    lg.polygon("fill", cx - 6, cy + 9, cx + 6, cy + 9, cx, cy)
    -- side triangles
    for i = 1, 3 do
        local o = i * 26
        lg.polygon("fill", cx - o - 4, cy + 6, cx - o + 4, cy + 6, cx - o, cy)
        lg.polygon("fill", cx + o - 4, cy + 6, cx + o + 4, cy + 6, cx + o, cy)
    end
    -- horizontal stadia line with range numbers
    lg.rectangle("fill", cx - 150, cy - 0.5, 132, 1)
    lg.rectangle("fill", cx + 18, cy - 0.5, 132, 1)
    local labels = { "8", "16", "24", "32" }
    lg.setFont(UI.fontS)
    for i, l in ipairs(labels) do
        local o = 20 + i * 30
        lg.setColor(tc)
        lg.printf(l, cx - o - 8, cy - 14, 16, "center")
        lg.printf(l, cx + o - 8, cy - 14, 16, "center")
    end
    lg.setColor(tc)
    -- vertical drop marks (hundreds of metres)
    local Gn = G.stations.gunner
    local fov = Gn.zoom == 2 and math.rad(11) or math.rad(24)
    for i, r in ipairs({ 4, 6, 8, 10, 12, 14 }) do
        local dist = r * 100
        local t = dist / 760
        local drop = 0.5 * 9.8 * t * t / dist -- angular drop of an AP round (radians)
        local yy = cy + 10 + drop / fov * UI.VH * 2.5
        lg.rectangle("fill", cx - 4, yy, 8, 1)
        lg.print(tostring(r), cx + 6, yy - 4)
    end
    lg.rectangle("fill", cx - 0.5, cy + 10, 1, 120)
end

local function mgUI()
    local T = G.tank
    local cx, cy = UI.VW / 2, UI.VH / 2
    haloed(function()
        lg.circle("line", cx, cy, 14, 24)
        lg.circle("line", cx, cy, 40, 32)
        lg.rectangle("fill", cx - 40, cy, 26, 1)
        lg.rectangle("fill", cx + 14, cy, 26, 1)
        lg.rectangle("fill", cx, cy + 14, 1, 26)
        lg.rectangle("fill", cx - 1, cy - 1, 3, 3)
    end)
    local x, y = UI.VW / 2 + 70, UI.VH / 2 + 70
    panel(x, y, 110, 46, 0.6)
    text("BELT", x + 6, y + 4, COL.dim, UI.fontS)
    text(T.mgReload > 0 and "RELOADING" or tostring(T.mgBelt), x + 50, y + 4, T.mgBelt < 20 and COL.warn or COL.text, UI.fontS)
    text("STORED", x + 6, y + 14, COL.dim, UI.fontS)
    text(tostring(G.inventory.tank:count("mg_ammo")), x + 50, y + 14, COL.text, UI.fontS)
    text("HEAT", x + 6, y + 26, COL.dim, UI.fontS)
    bar(x + 50, y + 28, 52, 5, T.mgHeat / 100, T.mgJam and COL.warn or COL.amber)
    if T.mgJam then text("OVERHEATED", x + 6, y + 35, COL.warn, UI.fontS) end
    text("[LMB] FIRE  [R] RELOAD BELT  [E] LEAVE", 0, UI.VH - 9, COL.dim, UI.fontS, "center", UI.VW)
end

local function radioPanel()
    local Rd = G.radio
    if not G.tank.radioOn or not Rd.active then return end
    local pl = G.player
    if pl.frameName ~= "tank" and U.dist3(pl.x, pl.y, pl.z, G.tank.x, G.tank.y, G.tank.z) > 8 then return end
    local x, y, w = 120, 26, 400
    panel(x, y, w, 46, 0.85)
    text("RADIO  " .. Rd.active.freq, x + 6, y + 4, COL.amber, UI.fontS)
    text(Rd.tuneT and Rd.tuneT > 0 and "...TUNING..." or Rd.shown, x + 6, y + 15, COL.text, UI.fontS, "left", w - 12)
end

---------------------------------------------------------------------------
-- main HUD
---------------------------------------------------------------------------
function UI.drawHUD()
    local pl = G.player
    lg.setColor(1, 1, 1, 1)
    if pl.mode == "dead" then return end
    local st = pl.mode == "seat" and pl.station
    if st and st.name == "driver" then driverUI()
    elseif st and st.name == "gunner" then
        if G.stations.gunner.optic then opticReticle() gunnerUI(true) else gunnerUI(false) end
    elseif st and st.name == "mg" then mgUI()
    else
        compass(UI.VW / 2, 6)
        statusPanel()
        weaponPanel()
        -- crosshair
        if not (G.weapons.aiming and G.weapons.current == "rifle") then
            lg.setColor(1, 1, 1, 0.6)
            lg.rectangle("fill", UI.VW / 2 - 0.5, UI.VH / 2 - 0.5, 1.5, 1.5)
        end
        prompt()
        if pl.mode == "ladder" then
            text("[W/S] CLIMB", 0, UI.VH - 9, COL.dim, UI.fontS, "center", UI.VW)
        end
    end
    objectivesPanel(love.keyboard.isDown("j"))
    radioPanel()
    messages()
end

---------------------------------------------------------------------------
-- inventory and storage screens
---------------------------------------------------------------------------
local function itemRow(id, count, x, y, w, hover)
    local def = Inv.ITEMS[id]
    if hover then
        lg.setColor(0.9, 0.7, 0.3, 0.2)
        lg.rectangle("fill", x, y, w, 12)
    end
    lg.setColor(0.7, 0.7, 0.65, 0.8)
    lg.rectangle("line", x + 2.5, y + 2.5, 8, 8)
    text(def.name, x + 15, y + 1, hover and COL.amber or COL.text, UI.fontS)
    text(tostring(count), x, y + 1, COL.text, UI.fontS, "right", w - 4)
end

function UI.drawInventory()
    local inv = G.inventory.player
    lg.setColor(0, 0, 0, 0.55)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    local x, y, w, h = 120, 40, 400, 270
    panel(x, y, w, h)
    text("INVENTORY", x + 10, y + 8, COL.amber, UI.fontM)
    local mx, my = UI.mouse()
    local list = inv:list()
    local hoverId
    for i, id in ipairs(list) do
        local ry = y + 30 + (i - 1) * 13
        local hover = mx > x + 10 and mx < x + 210 and my > ry and my < ry + 12
        itemRow(id, inv:count(id), x + 10, ry, 200, hover)
        if hover then hoverId = id end
    end
    if #list == 0 then text("(EMPTY)", x + 10, y + 30, COL.dim, UI.fontS) end
    local sel = hoverId or UI.invSel
    if sel and Inv.ITEMS[sel] then
        local def = Inv.ITEMS[sel]
        text(def.name, x + 225, y + 30, COL.amber, UI.font)
        text(def.desc, x + 225, y + 44, COL.text, UI.fontS, "left", 165)
        text(string.format("CARRYING %d / %d", inv:count(sel), def.carry), x + 225, y + 80, COL.dim, UI.fontS)
        if def.use then text("CLICK TO USE", x + 225, y + 92, COL.good, UI.fontS) end
    end
    if hoverId and UI.clicked then
        UI.clicked = false
        UI.invSel = hoverId
        if Inv.ITEMS[hoverId].use then Inv.use(hoverId) end
    end
    local pl = G.player
    local sy = y + h - 64
    text(string.format("HEALTH %d   WARMTH %d   RADIATION %d   LIGHT %d%%", pl.health, pl.warmth, pl.radiation, pl.battery), x + 10, sy, COL.dim, UI.fontS)
    local Wp = G.weapons
    text(string.format("WEAPONS: [1] %s (%d)   [2] %s (%d)", Wp.DEFS.rifle.name, Wp.mag.rifle, Wp.DEFS.pistol.name, Wp.mag.pistol), x + 10, sy + 12, COL.dim, UI.fontS)
    text("[TAB] CLOSE   [M] MAP   [J] OBJECTIVES", x + 10, y + h - 14, COL.dim, UI.fontS)
end

local STORE_STEP = { mg_ammo = 50, rifle_ammo = 5, pistol_ammo = 8 }

function UI.drawStorage()
    local pinv, tinv = G.inventory.player, G.inventory.tank
    lg.setColor(0, 0, 0, 0.55)
    lg.rectangle("fill", 0, 0, UI.VW, UI.VH)
    local x, y, w, h = 60, 30, 520, 300
    panel(x, y, w, h)
    text("TANK STORAGE", x + 10, y + 8, COL.amber, UI.fontM)
    local T = G.tank
    text(string.format("FUEL %d%%", T.fuel), x + 270, y + 10, T.fuel < 20 and COL.warn or COL.text, UI.fontS)
    local cx = x + 340
    for i, k in ipairs({ "engine", "trackL", "trackR", "turret", "cannon", "hull" }) do
        local v = T.comp[k]
        text(T.COMP_NAMES[k], cx + ((i - 1) % 2) * 90, y + 6 + math.floor((i - 1) / 2) * 9, v < 40 and COL.warn or COL.dim, UI.fontS)
        bar(cx + ((i - 1) % 2) * 90 + 60, y + 9 + math.floor((i - 1) / 2) * 9, 24, 3, v / 100, v < 40 and COL.warn or COL.good)
    end
    local mx, my = UI.mouse()
    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local function column(title, inv, other, colX, toTank)
        text(title, colX, y + 36, COL.text, UI.font)
        local list = inv:list()
        for i, id in ipairs(list) do
            local ry = y + 52 + (i - 1) * 13
            local hover = mx > colX and mx < colX + 230 and my > ry and my < ry + 12
            itemRow(id, inv:count(id), colX, ry, 230, hover)
            if hover and UI.clicked then
                UI.clicked = false
                local n = shift and inv:count(id) or (STORE_STEP[id] or 1)
                local moved = Inv.transfer(inv, other, id, n)
                if moved > 0 then
                    if G.audio then G.audio.play("pickup", { volume = 0.5 }) end
                    if not toTank then G.missions.event("picked_from_tank", id) end
                else
                    UI.notify("NO ROOM")
                end
            end
        end
        if #list == 0 then text("(EMPTY)", colX, y + 52, COL.dim, UI.fontS) end
    end
    column("YOUR PACK  (CLICK: STORE)", pinv, tinv, x + 12, true)
    column("TANK  (CLICK: TAKE)", tinv, pinv, x + 275, false)
    if UI.button("STORE ALL SUPPLIES", x + 12, y + h - 30, 150, 18) then
        for _, id in ipairs(pinv:list()) do
            local def = Inv.ITEMS[id]
            if not def.quest and id ~= "rifle_ammo" and id ~= "pistol_ammo" and id ~= "medkit" then
                Inv.transfer(pinv, tinv, id, pinv:count(id))
            end
        end
        if G.audio then G.audio.play("pickup", {}) end
    end
    text("SHIFT+CLICK MOVES EVERYTHING   [E/ESC] CLOSE", x + 175, y + h - 25, COL.dim, UI.fontS)
end

---------------------------------------------------------------------------
-- frame entry
---------------------------------------------------------------------------
function UI.beginDraw()
    lg.setCanvas(UI.canvas)
    lg.clear(0, 0, 0, 0)
    lg.setColor(1, 1, 1, 1)
    lg.setLineStyle("rough")
    lg.setLineWidth(1)
end

function UI.endDraw()
    lg.setCanvas()
    lg.setColor(1, 1, 1, 1)
    local sw, sh = lg.getDimensions()
    lg.draw(UI.canvas, 0, 0, 0, sw / UI.VW, sh / UI.VH)
    UI.clicked = false
end

return UI
