-- Generic interaction component system.
-- An interactable is a plain table:
--   pos      {x,y,z} in the space of `frame`
--   frame    nil (world space) or function() -> Frame (e.g. the tank or turret)
--   space    "exterior" | "interior" | "any"  (interior = inside the tank)
--   prompt   string or function(self) -> string|nil   (nil hides it)
--   hold     nil | seconds | function(self)->seconds  (hold E to complete)
--   use      function(self)
--   radius, range   aim tolerance and max distance
local U = require("src.utils")
local P = require("src.physics")

local I = { list = {}, current = nil, progress = 0, holding = nil }

function I.add(def)
    def.radius = def.radius or 0.45
    def.range = def.range or 2.3
    def.space = def.space or "exterior"
    I.list[#I.list + 1] = def
    return def
end

function I.remove(def)
    for i = #I.list, 1, -1 do if I.list[i] == def then table.remove(I.list, i) end end
end

function I.clear() I.list = {} I.current = nil end

function I.worldPos(def)
    local p = def.pos
    if def.frame then
        local f = def.frame()
        if not f then return nil end
        return f:toWorld(p[1], p[2], p[3])
    end
    return p[1], p[2], p[3]
end

local function promptOf(def)
    if type(def.prompt) == "function" then return def.prompt(def) end
    return def.prompt
end
I.promptOf = promptOf

-- find the interactable the camera is aiming at
function I.update(dt, cam, space, occluders, keyDown)
    local best, bestScore, bestText = nil, 1e9, nil
    for _, def in ipairs(I.list) do
        if (def.space == "any" or def.space == space) and (not def.enabled or def.enabled(def)) then
            local x, y, z = I.worldPos(def)
            if x then
                local vx, vy, vz = x - cam.x, y - cam.y, z - cam.z
                local along = vx * cam.fx + vy * cam.fy + vz * cam.fz
                if along > 0.05 and along < def.range then
                    local px, py, pz = vx - cam.fx * along, vy - cam.fy * along, vz - cam.fz * along
                    local perp = math.sqrt(px * px + py * py + pz * pz)
                    local tol = def.radius + along * 0.06
                    if perp < tol then
                        local score = perp / tol + along * 0.15
                        if score < bestScore then
                            local text = promptOf(def)
                            if text then
                                local blocked = false
                                if occluders and space == "exterior" then
                                    local t = P.raycast(occluders, cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz, along - 0.35,
                                        function(b) return not b.door and not b.tree end)
                                    if t then blocked = true end
                                end
                                if not blocked then best, bestScore, bestText = def, score, text end
                            end
                        end
                    end
                end
            end
        end
    end
    I.current = best
    I.currentText = bestText
    -- hold progress
    if I.holding then
        if I.holding ~= best or not keyDown then
            I.holding = nil
            I.progress = 0
        else
            local need = type(best.hold) == "function" and best.hold(best) or best.hold
            I.progress = I.progress + dt / need
            if best.whileHolding then best.whileHolding(best, dt) end
            if I.progress >= 1 then
                I.holding = nil
                I.progress = 0
                best.use(best)
            end
        end
    end
end

-- E pressed
function I.press()
    local def = I.current
    if not def then return false end
    local hold = def.hold
    if type(hold) == "function" then hold = hold(def) end
    if hold and hold > 0 then
        I.holding = def
        I.progress = 0
        if def.onHoldStart then def.onHoldStart(def) end
    else
        def.use(def)
    end
    return true
end

return I
