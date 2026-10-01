function love.conf(t)
    t.identity = "steel_hearth"
    t.version = "11.4"
    t.window.title = "STEEL HEARTH"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.vsync = 0
    t.window.depth = 24
    t.window.minwidth = 640
    t.window.minheight = 360
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
end
