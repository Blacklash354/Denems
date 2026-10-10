-- Challenges: not every soldier shoots on sight. A wary sentry or patrol raises the rifle, walks up and
-- asks who you are and where you are coming from; the answer (or what you hand over) decides whether
-- the whole post lets you pass, opens fire, or - for bandits bluffed by a tank - runs.
local Dl = {}
local G

-- options: text; need/take = { item = count }; chance of success; result = pass | hostile | flee;
-- reply (on success) and fail (on a failed chance, which turns them hostile); go = next node
Dl.TREES = {
    military = {
        start = { text = "STOI! Hands where I can see them! Who are you, and where are you coming from?",
            options = {
                { text = "A soldier. My unit was cut off - I'm trying to get back north.", go = "north" },
                { text = "Just a survivor. Looking for food and somewhere warm.", go = "survivor" },
                { text = "(give 2 food) Here, take this. I don't want any trouble.", need = { food = 2 }, take = { food = 2 },
                  result = "pass", reply = "...Tinned meat. Real meat. Go on then - I never saw you." },
                { text = "None of your business.", result = "hostile", reply = "Wrong answer!" },
            } },
        north = { text = "North? There's nothing north but ice and the old line. And that accent... you're not one of ours.",
            options = {
                { text = "The war is over, comrade. Nobody is anybody's any more.", chance = 0.55, result = "pass",
                  reply = "...True enough. Go north, then. Keep off the airfield road - the lieutenant shoots first and asks later.",
                  fail = "Over? Tell that to my brother. On the ground - NOW!" },
                { text = "(show documents) Papers. Signed and stamped.", need = { documents = 1 }, take = { documents = 1 }, result = "pass",
                  reply = "Garrison stamp... fine. Move along, and don't come back this way." },
                { text = "(run for it)", result = "hostile", reply = "Stoi! Fire, fire!" },
            } },
        survivor = { text = "Survivors don't carry rifles like that. Turn around and walk away. Slowly.",
            options = {
                { text = "Alright. I'm going.", result = "pass", reply = "Good. And don't let me see you twice." },
                { text = "I'll go where I please.", chance = 0.3, result = "pass", reply = "...Ha. You've got nerve. Go on, before I change my mind.",
                  fail = "Then you'll go nowhere at all!" },
            } },
    },
    bandit = {
        start = { text = "Well, well. Look what the snow dragged in. Nice coat. Empty your pockets and maybe you walk away.",
            options = {
                { text = "(give 40 rounds) Take it. I'm not looking for a fight.", need = { pistol_ammo = 40 }, take = { pistol_ammo = 40 },
                  result = "pass", reply = "Smart. Now get lost before we change our minds." },
                { text = "(give a medkit) Here. It's all I've got.", need = { medkit = 1 }, take = { medkit = 1 }, result = "pass",
                  reply = "Hm. Morphine... fine. Beat it." },
                { text = "I've got a tank over that hill. Want to meet it?", chance = 0.45, result = "flee",
                  reply = "A tank? He's... he's not lying. Go, go, go!", fail = "A tank? Then you won't be needing your coat!" },
                { text = "Come and take it.", result = "hostile", reply = "With pleasure!" },
            } },
    },
}

function Dl.init(game) G = game end

local function has(need)
    if not need then return true end
    for item, n in pairs(need) do
        if G.inventory.player:count(item) < n then return false end
    end
    return true
end

-- open a challenge with NPC h (the game pauses while you answer)
function Dl.open(h)
    local tree = Dl.TREES[h.faction]
    if not tree or G.game.state ~= "play" then return end
    Dl.cur = { h = h, tree = tree, node = tree.start }
    G.game.state = "dialog"
    love.mouse.setRelativeMode(false)
    if G.audio then G.audio.play("voice", { volume = 0.6, pitch = 0.82 }) end
end

-- the whole group around the speaker takes the outcome
local function settle(h, result)
    for _, o in ipairs(G.humans.list) do
        if o.faction == h.faction and o.state ~= "dead" and (o == h or math.abs(o.x - h.x) + math.abs(o.z - h.z) < 70) then
            o.wary, o.challenged = false, true
            if result == "pass" then
                o.hostile, o.passed = false, true
                if o.state == "challenge" then o.state = o.squad and "idle" or (o.role == "sit" and "sit" or "return") end
            elseif result == "flee" then
                o.hostile, o.passed = false, true
                o.state, o.timer = "flee", 12
            else
                o.hostile = true
                if o.state ~= "combat" then
                    local pl = G.player
                    o.state, o.lastX, o.lastZ, o.lastSeen = "combat", pl.x, pl.z, 0
                end
            end
        end
    end
end

local function choose(i)
    local c = Dl.cur
    if not c then return end
    if c.reply then
        -- the last line has been read: back to the game
        Dl.cur = nil
        G.game.state = "play"
        love.mouse.setRelativeMode(true)
        settle(c.h, c.result)
        return
    end
    local o = c.node.options[i]
    if not o or not has(o.need) then return end
    for item, n in pairs(o.take or {}) do G.inventory.player:remove(item, n) end
    if o.go then
        c.node = c.tree[o.go]
        if G.audio then G.audio.play("voice", { volume = 0.5, pitch = 0.85 }) end
        return
    end
    local ok = not o.chance or math.random() < o.chance
    c.result = ok and o.result or "hostile"
    c.reply = ok and o.reply or o.fail
    if G.audio then G.audio.play("voice", { volume = 0.6, pitch = c.result == "hostile" and 0.75 or 0.85 }) end
end
Dl.choose = choose

function Dl.keypressed(key)
    local n = tonumber(key)
    if n then choose(n) return end
    if Dl.cur and Dl.cur.reply and (key == "return" or key == "space" or key == "e") then choose(1) end
end

function Dl.draw()
    local c = Dl.cur
    if not c then return end
    local UI = G.ui
    local lg = love.graphics
    local x, w = 60, UI.VW - 120
    local opts = c.reply and 1 or #c.node.options
    local h = 64 + opts * 18
    local y = UI.VH - h - 14
    UI.panel(x, y, w, h)
    local who = G.humans.FACTIONS[c.h.faction].name
    UI.text(who, x + 10, y + 7, UI.COL.amber, UI.fontM)
    UI.text(c.reply or c.node.text, x + 10, y + 24, UI.COL.text, UI.fontS, "left", w - 20)
    local oy = y + 56
    if c.reply then
        if UI.button("1. ...", x + 10, oy, w - 20, 15, true) then choose(1) end
        return
    end
    for i, o in ipairs(c.node.options) do
        local ok = has(o.need)
        if UI.button(i .. ". " .. o.text, x + 10, oy + (i - 1) * 18, w - 20, 15, ok) then choose(i) end
    end
    lg.setColor(1, 1, 1, 1)
end

return Dl
