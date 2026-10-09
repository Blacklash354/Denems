-- The tank radio: tune through frequencies, hear static, distorted voices and
-- transmissions that reveal locations.
local U = require("src.utils")
local Rd = { staticLevel = 0.4 }
local G

Rd.STATIONS = {
    { freq = "41.3 MHz", name = "EMERGENCY BROADCAST", always = true,
      text = "...KRRRZZ... THIS IS THE CIVIL DEFENCE NETWORK... REMAIN INDOORS... DO NOT ATTEMPT TO TRAVEL... THE FALLOUT CLOUD IS... ...KRRR... REPEAT, REMAIN INDOORS..." },
    { freq = "44.0 MHz", name = "TOWER SEVEN", always = true, reveal = "tower",
      text = "......KRRRRR..... IF ANYONE CAN HEAR THIS... TOWER SEVEN... ON THE HILL NORTH-EAST OF ZARECHNY... REPEAT... TOWER SEVEN... WE HAVE POWER... ...KSSSHH..." },
    { freq = "46.6 MHz", name = "MILITARY NET", always = true, reveal = "airfield",
      text = "...ZZT... ARMOUR GROUP KRASNOYE TO ALL UNITS... THE BASE IS LOST... HOLD THE AIRFIELD EAST OF THE RIVER... SHOOT LOOTERS ON SIGHT... ...KRRK..." },
    { freq = "38.9 MHz", name = "HUNTER", always = true, reveal = "forest",
      text = "...SSHHH... ...THE CABIN IN THE BIG FOREST... EAST, PAST THE BROKEN BRIDGE... I LEFT FUEL AND FOOD... KEEP THE FIRE BURNING... ...KRRRR..." },
    { freq = "49.5 MHz", name = "SURVIVORS", always = true, reveal = "town",
      text = "...KSSH... TO ANYONE OUT THERE... PERVOMAISK, WEST ON THE OLD ROAD... WE HAVE A FIRE AND A ROOF... BRING FOOD IF YOU CAN... ...KRRZ..." },
    { freq = "51.2 MHz", name = "NUMBERS", needStage = 3, reveal = "bunker",
      text = "...SEVEN... FOUR... NINE... OBJECT 12 BENEATH THE HILLS NORTH-WEST OF THE BASE... THE DOOR IS OPEN... SEVEN... FOUR... NINE..." },
    { freq = "57.0 MHz", name = "UNKNOWN SIGNAL", needStage = 5, reveal = "plant",
      text = "...KZZZZ... ...  ... THE REACTOR SINGS... COME TO THE CONTROL BLOCK... THE CARD OPENS THE DOOR... WE ARE STILL HERE... ...WE ARE STILL HERE..." },
}

function Rd.init(game)
    G = game
    Rd.index = 0
    Rd.shown = ""
    Rd.charT = 0
    Rd.active = nil
    Rd.voiceT = 0
end

function Rd.available()
    local list = {}
    for _, s in ipairs(Rd.STATIONS) do
        if s.always or (s.needStage and G.missions.stage >= s.needStage) then list[#list + 1] = s end
    end
    return list
end

-- each use of the radio tunes to the next frequency (or switches off after the last)
function Rd.tune()
    local T = G.tank
    local list = Rd.available()
    Rd.index = Rd.index + 1
    if Rd.index > #list then
        Rd.index = 0
        T.radioOn = false
        Rd.active = nil
        if G.audio then G.audio.play("switch", { tank = true }) end
        return
    end
    T.radioOn = true
    Rd.active = list[Rd.index]
    Rd.shown = ""
    Rd.charT = 0
    Rd.tuneT = 0.8
    Rd.staticLevel = 0.9
    if G.audio then G.audio.play("switch", { tank = true }) end
end

local GLITCH = "#%&*@$!?/\\|"

function Rd.update(dt)
    local T = G.tank
    if not T.radioOn or not Rd.active then
        Rd.staticLevel = 0.4
        return
    end
    if Rd.tuneT and Rd.tuneT > 0 then
        Rd.tuneT = Rd.tuneT - dt
        Rd.staticLevel = 0.8
        return
    end
    local s = Rd.active
    Rd.charT = Rd.charT + dt * 14
    local n = math.floor(Rd.charT)
    if n > #s.text + 40 then
        Rd.charT = 0
        n = 0
    end
    local txt = s.text:sub(1, n)
    -- glitch a few characters as if through interference
    local out = {}
    for i = 1, #txt do
        local ch = txt:sub(i, i)
        if ch ~= " " and math.random() < 0.025 then
            local k = math.random(#GLITCH)
            ch = GLITCH:sub(k, k)
        end
        out[i] = ch
    end
    Rd.shown = table.concat(out)
    local speaking = n < #s.text and not s.text:sub(n, n):match("[%.%s]")
    Rd.staticLevel = speaking and 0.25 or 0.5
    Rd.voiceT = Rd.voiceT - dt
    if speaking and Rd.voiceT <= 0 then
        Rd.voiceT = 2.2
        if G.audio then G.audio.play("voice", { tank = true, volume = 0.55, pitch = 0.9 }) end
    end
    if n > 40 and s.reveal and not s.revealedOnce then
        s.revealedOnce = true
        G.missions.reveal(s.reveal)
    end
end

return Rd
