-- STEEL HEARTH - a first-person nuclear-winter tank survival prototype for LÖVE 11.
io.stdout:setvbuf("no")

local G = {}            -- shared registry of game systems
_G.GAME = G

local Settings = require("src.settings")
local Textures = require("src.engine.textures")
local R = require("src.engine.renderer")

local loader          -- coroutine building the world
local loadStatus = { step = "starting", frac = 0 }
local autotest

local function stamp(label)
    if os.getenv("STEEL_TIMING") then print(string.format("[timing] %-12s %.2f s", label, love.timer.getTime() - G.loadStart)) end
end

local function buildAll()
    G.settings = Settings
    G.renderer = R
    G.world = require("src.world")
    G.worldGen = require("src.world_gen")
    coroutine.yield("textures", 0)
    G.world.initChunks()
    G.world.computeHeights()
    stamp("heights")
    G.worldGen.build()
    stamp("locations")
    G.world.buildTerrain()
    stamp("terrain")
    G.world.buildSilhouettes()
    coroutine.yield("finalizing", 0.9)
    G.world.finalize()
    stamp("meshes")
    G.camera = require("src.camera")
    G.effects = require("src.effects")
    G.inventory = require("src.inventory")
    G.tank = require("src.tank")
    G.player = require("src.player")
    G.weapons = require("src.weapons")
    G.creatures = require("src.creatures")
    G.enemies = require("src.enemy_tank")
    G.humans = require("src.humans")
    G.radar = require("src.radar")
    G.ambience = require("src.ambience")
    G.environment = require("src.environment")
    G.weather = require("src.weather")
    G.survival = require("src.survival")
    G.missions = require("src.missions")
    G.radio = require("src.radio")
    G.map = require("src.map")
    G.save = require("src.save")
    G.ui = require("src.ui")
    G.game = require("src.game")
    G.menu = require("src.menu")
    G.stations = { driver = require("src.tank_driver"), gunner = require("src.tank_gunner"), mg = require("src.tank_mg") }
    coroutine.yield("systems", 0.93)
    G.effects.init(G)
    G.inventory.init(G)
    G.tank.init(G)
    G.player.init(G)
    G.weapons.init(G)
    G.creatures.init(G)
    G.enemies.init(G)
    G.humans.init(G)
    G.radar.init(G)
    G.ambience.init(G)
    G.environment.init(G)
    G.weather.init(G)
    G.survival.init(G)
    G.missions.init(G)
    G.radio.init(G)
    G.save.init(G)
    G.ui.init(G)
    for _, s in pairs(G.stations) do s.init(G) end
    G.menu.init(G)
    coroutine.yield("audio", 0.96)
    G.audio = require("src.audio")
    G.audio.init(G, Settings.data)
    stamp("audio")
    G.map.init(G)
    G.game.init(G)
end

function G.startNewGame()
    G.game.newGame()
    G.app = "game"
end

function G.continueGame()
    if G.game.loadGame() then G.app = "game" end
end

function love.load(args)
    love.graphics.setDefaultFilter("nearest", "nearest")
    Settings.load()
    for _, a in ipairs(args or {}) do
        if a == "--autotest" then autotest = require("tools.autotest") end
        if a == "--drivetest" then autotest = require("tools.drivetest") end
    end
    if not autotest and (Settings.data.fullscreen or Settings.data.resolution ~= 1) then Settings.applyWindow() end
    Textures.init()
    R.init(Settings.data.quality)
    R.wobble = Settings.data.wobble
    G.app = "loading"
    G.loadStart = love.timer.getTime()
    loader = coroutine.create(buildAll)
    love.graphics.setFont(love.graphics.newFont(14))
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    R.time = R.time + dt
    if G.app == "loading" then
        local ok, step, frac = coroutine.resume(loader)
        if not ok then error(step) end
        if step then loadStatus.step, loadStatus.frac = step, frac or 0 end
        if coroutine.status(loader) == "dead" then
            if os.getenv("STEEL_TIMING") then print(string.format("[timing] world ready after %.2f s", love.timer.getTime() - G.loadStart)) end
            if autotest then autotest.start(G) else G.menu.open() end
        end
        return
    end
    if autotest then autotest.update(dt) end
    if G.app == "menu" then
        G.menu.update(dt)
        G.audio.update(dt, false)
    elseif G.app == "game" then
        G.game.update(dt)
        G.audio.update(dt, true)
    end
end

function love.draw()
    if G.app == "loading" then
        local w, h = love.graphics.getDimensions()
        love.graphics.clear(0.04, 0.045, 0.05)
        love.graphics.setColor(0.85, 0.85, 0.8)
        love.graphics.printf("STEEL HEARTH", 0, h / 2 - 60, w, "center")
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf("GENERATING THE FROZEN WASTELAND... " .. string.upper(loadStatus.step), 0, h / 2 - 20, w, "center")
        love.graphics.rectangle("line", w / 2 - 150, h / 2 + 10, 300, 10)
        love.graphics.setColor(0.95, 0.72, 0.3)
        love.graphics.rectangle("fill", w / 2 - 148, h / 2 + 12, 296 * (loadStatus.frac or 0), 6)
        return
    end
    if G.app == "menu" then G.menu.draw()
    elseif G.app == "game" then G.game.draw() end
    if autotest then autotest.draw() end
    if G.showFPS then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print(string.format("FPS %d  draws %d  tris %d", love.timer.getFPS(), R.stats.draws, R.stats.tris), 4, 4)
    end
end

function love.keypressed(key)
    if key == "f3" then G.showFPS = not G.showFPS return end
    if G.app == "game" then G.game.keypressed(key)
    elseif G.app == "menu" then
        if key == "escape" and G.menu.sub == "settings" then G.menu.sub = "main" end
    end
end

function love.mousepressed(x, y, b)
    if G.app == "game" then G.game.mousepressed(x, y, b)
    elseif G.app == "menu" and b == 1 then G.ui.clicked = true end
end

function love.wheelmoved(x, y) if G.app == "game" then G.game.wheelmoved(x, y) end end

function love.mousemoved(x, y, dx, dy)
    if G.app == "game" then G.game.mousemoved(x, y, dx, dy) end
end

function love.focus(f)
    if not f and G.app == "game" and G.game.state == "play" then
        G.game.state = "pause"
        love.mouse.setRelativeMode(false)
    end
end

function love.quit()
    if G.settings then G.settings.save() end
end
