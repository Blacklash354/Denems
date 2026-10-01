-- run with: love . --rtest
local R = require("src.engine.renderer")
local T = require("src.engine.textures")
local MB = require("src.engine.meshbuilder")
return function()
    T.init()
    R.init(3)
    local mb = MB.new()
    mb:material("snow"):color(1,1,1)
    mb:box(-20,-1,-20,20,0,20)
    mb:material("brick"):color(1,0.6,0.6)
    mb:box(4,0,-1,6,4,1)   -- in front (+x), tall red
    mb:material("metal"):color(0.4,0.4,1)
    mb:box(4,0,3,6,1,5)    -- in front, to the right (+z), low blue
    local model = mb:build()
    local cam = {x=0,y=1.6,z=0,fx=1,fy=0,fz=0,ux=0,uy=1,uz=0,fov=1.2}
    R.setCamera(cam)
    R.beginFrame()
    R.drawModel(model)
    R.endFrame(1280,720)
    love.graphics.captureScreenshot(function(img) img:encode("png","rtest.png") print("saved", love.filesystem.getSaveDirectory()) love.event.quit() end)
end
