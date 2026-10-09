# STEEL HEARTH

A first-person survival / exploration / tank game for **LÖVE 11.4+** (real 3D, PSX style).
The war is over and nobody won. A nuclear winter has buried the Soviet countryside in snow; what is
left of the army, bandits and a few survivors fight over the ruins. Your heavy tank is your shelter,
storage, weapon platform and only way across a 4 km open world.

The 3D renderer, the tank, the world and **all audio** are generated procedurally in Lua. On top of that the game
loads hand-made PSX model packs (Soviet panel blocks, a metro car and a helicopter, a fuel station, wrecks,
forest clutter, guns and character figures) and textures from `assets/` — see `assets/psx/CREDITS.md`
for authors and licences. Nothing to install.

## Running

```
love .
```

Requires LÖVE 11.4 or newer (tested on 11.5). The first launch takes ten seconds or so to generate the world.

## Controls

| Action | Key |
|---|---|
| Move / sprint / crouch / jump | `WASD` / `Shift` / `C` or `Ctrl` / `Space` |
| Interact / leave a seat | `E` (some actions are hold-to-complete) |
| Flashlight | `F` |
| Fire / aim / reload | `LMB` / `RMB` / `R` |
| M14 / AK-74 / Makarov / pump shotgun | `1` / `2` / `3` / `4` or mouse wheel |
| Inventory and clothes / map | `Tab` / `M` |
| Controls reminder | `H` |
| Quick save / load | `F5` / `F9` |
| Pause | `Esc` |
| FPS / draw-call counter | `F3` |

**Driver seat:** `W/S` throttle, `A/D` steer (tracks pivot), `Space` brake, `F` engine, `L` headlights, `V` toggles a third-person chase camera (mouse orbits it).
**Gunner seat:** mouse or `WASD` traverses the turret and elevates the gun, `RMB` optic, wheel zoom,
`R` loads a shell from the racks, `T`/`1`/`2` choose AP or HE, `LMB` fires.
**Bow MG:** mouse aims, `LMB` fires (watch the heat), `R` loads a new belt from storage.

## The screen

The HUD stays out of the way: three thin bars (health, body warmth and - when it is not full - stamina),
a snowflake that pulses when the cold is winning, the ammo count, and the `[E]` prompt for what you look at.
No objective list, no compass, no markers: you find your way with the map, the roads, the landmarks on the
horizon and the radio. The crew stations show their gauges (gear, rpm, fuel, shells, belt) only while you sit there.

## The open world

The map is about 4 x 4 km of snowy hills, forest and fields, crossed by a river and a road network. Places are
far apart: the highway alone is several kilometres long, a walk from one town to the next takes many minutes,
and the tank burns fuel all the way.

| Place | What is there |
|---|---|
| Kolkhoz 'Red Dawn' | barns, silos, farmhouses and a machine yard near the start; a couple of bandits |
| Survivors' camp | a fire, tents, Old Petro the trader and the people who know the land |
| Fuel station | the PSX gas station kit on the highway |
| Army checkpoint | barriers, sandbags and soldiers astride the highway |
| Garage cooperative No.4 | four rows of Soviet garage boxes (gates open, hanging or closed) and a tank repair depot; bandits |
| Pervomaisk | old village houses along the road, a church, a gastronom, a school and new panel blocks |
| Tractor works | factory hall, warehouses, chimneys, a rail line with wagons and a station |
| Zarechny | the dead city: dozens of five-storey panel blocks, shops, garages and ruins around a square with a monument, a stranded metro car and a crashed helicopter; soldiers in the square, bandits in the east |
| Tank airfield | runway, apron, hangars full of armour, a tank park, control tower, barracks and fuel depot; a strong garrison |
| Army base | walled barracks, hangars, HQ and fuel depot |
| Frozen forest | thousands of trees east of the river, the hunter's cabin, the broken bridge |
| Radio tower, Object 12, power plant | the old story: the transmitter, the bunker and the reactor's control block |

Between them: hamlets, battlefields of the last war with knocked-out tanks and hedgehogs, wrecked traffic on the
roads, telephone lines, and forests generated from a noise mask so that dense woods and open fields alternate.

### Buildings you can enter

The panel blocks (khrushchyovka) are real buildings: every section has a podyezd door, a stairwell with two
flights and a half landing per floor, and two flats per floor with rooms, wallpaper, linoleum, kitchens,
balconies and windows (some blown out, some sections collapsed). Flats hold wardrobes, bedside tables and kitchen
cupboards to search. Garages, shops, hangars, barracks, houses and the factory are enterable too, and every
interior counts as shelter from the wind.

### Roads

Roads are separate meshes that follow smooth centre lines: asphalt or dirt-track textures mapped along the road
(wheel ruts, a faint centre line), ploughed snow banks at the edges and a flattened corridor so the terrain never
pokes through. The world shader uses perspective-correct texture coordinates (the old hand-made uv/w interpolation
broke on big ground triangles reaching behind the camera, which made the snow and roads smear and stretch while
walking). The optional "RETRO WOBBLE" setting still gives the PSX affine look.

## People

There are no monsters - only people, and they are dangerous enough.

* **Soldiers** (greatcoats, ushankas, winter camo; NBC suits and gas masks around the power plant) hold the
  checkpoint, the city square, the airfield, the base, the tower and the plant. They shoot looters on sight.
* **Bandits** (balaclavas, leather, tracksuits) squat in the garages, the tractor works, the school and the city's east side.
* **Survivors** sit at their fires in the camp, in Pervomaisk, in the city and in the forest. They talk, give
  you something useful the first time, trade (Old Petro) and fight bandits and soldiers. Shooting one turns their friends against you.

Factions fight each other whenever they meet. Squads walk between places along the roads (they keep travelling
while you are far away), and a squad that is wiped out is replaced by a new one after a while. Bodies can be searched.
The figures are rigid-part PSX characters: procedural outfits plus figures from `assets/characters_psx.glb`,
with two-bone IK so their hands sit on the rifle.

## Cold, clothes and survival

Outside, your body warmth drains slowly - faster at night, much faster in a blizzard, slower while you keep moving.
Inside buildings it barely drops; near a fire or inside the tank (engine running) you warm up. Below 25 warmth you
shiver and slow down, below 15 the cold starts to kill you.

Clothes decide how long you last. There are five slots - head, body, legs, hands, feet - and every piece has a warmth
value (wool cap, ushanka, sweater, telogreika, army greatcoat, sheepskin coat, wool or quilted trousers, gloves,
fur mittens, army boots, valenki). You start in a telogreika and boots; better clothes are found in wardrobes in the
flats, lockers in barracks and hangars, on soldiers' bodies and at the trader. Wear them from the inventory
(`Tab`, click an item; click a worn item to take it off). Your sleeves and gloves in the first-person view change
with what you wear.

Tank supplies (AP/HE shells, MG belts, fuel cans, repair kits, spare parts) are found where tanks lived: the garages
and the repair depot, the airfield hangars and tank park, the army base and wrecked armour on old battlefields.

## Weapons in your hands

Both arms are modelled (sleeves, gloves) and follow the gun with two-bone IK: the right hand on the grip, the left on
the handguard. Reloads are done by the left hand: it takes the magazine out, goes to the pouch, brings a new one,
seats it (the rounds count when the magazine clicks in) and works the charging handle or slide if the gun was empty.
The shotgun is loaded shell by shell through the loading port and can be interrupted by firing.

## How the tank works

The tank interior is a real 3D space in the tank's local frame. You walk between the stations:
the gunner seat in the rotating turret basket, the driver and the radio-operator/MG seats in the
cramped front compartment (you automatically duck under the low roof), the storage shelves at the
firewall, the radio, the starter button and the ladder under the commander's cupola.
Climb the ladder, open the hatch, and climb out onto the turret roof. You can stand on the moving tank,
use the rear ladder to get down, repair tracks or other parts, refuel at the filler cap, use the bustle
storage box, and climb back in through the hatch.

Retro vertex wobble/affine textures are off by default (stable textures); enable "RETRO WOBBLE" in settings.
The picture is dithered to 15-bit colour like the console; "SCREEN FILTER" in settings switches the CRT tube
(default), a VHS look, or none, and "PSX 240P" is available as a graphics quality.

Every road wheel, idler and sprocket turns with its own track, so the two sides run at different speeds in a turn.

Components (engine, both tracks, turret, cannon and hull) can be damaged. Repairs cost repair kits.
You can build repair kits from spare parts.

## Destruction

Most man-made objects in the world are real destructible objects with their own hit points and
material: checkpoint barrier poles, crates, plank stacks, sandbags, concrete blocks, steel hedgehogs,
fences, watchtowers, tents, signs, vehicles and whole houses. Rifle, SMG and hull-MG bullets chip
away at them (wood and cloth go fast, steel slowly, concrete barely); cannon shells and explosions
take out much more. A destroyed object loses its collision, throws physical debris and a dust cloud,
houses collapse into a rubble mound with wall stubs, vehicles are burnt out with fire and black smoke,
and fuel tanks explode. The tank flattens poles, fences, crates and sandbags when driving through them.

## Radar

The tank carries a radar: a live green scope on the left sponson inside the hull, mirrored on the HUD while you sit
at a station. New hostile contacts are announced briefly ("RADAR: HOSTILES NE 140M").

## Story

There is no objective list, but there is a thread to follow: the radio in the tank picks up broadcasts that mark
places on the map. Tower Seven's transmitter points to Object 12, the bunker holds the plant's keycard, and someone is
still transmitting from the power plant's control block.

## Project layout

```
main.lua               bootstrap, progressive world loader, app state (loading/menu/game)
conf.lua               window configuration
shaders/               psx.glsl (vertex lighting, snapping, affine UVs, fog), post.glsl (dither,
                       banding, grain, CA, frost/radiation/optic overlays), sky, snow, billboard
src/engine/            math3d (frames/matrices), meshbuilder (procedural low-poly geometry -> meshes),
                       textures (procedural low-res textures), renderer (low-res canvas, lights, post)
src/world.lua          4 km heightfield, road network (smoothed centre lines, road meshes, bridges), indexed terrain
                       chunks, instanced vegetation, colliders, shelters, queries
src/world_gen.lua      every place, loot tables, people and squads, forests, hamlets, battlefields, interiors
src/buildings.lua      enterable panel blocks (stairwells, flats), garage rows, shops, ruins, monuments
src/props.lua          modular props (houses, halls, hangars, towers, wrecks, trees...)
src/engine/gltf.lua    .glb loader for rigid part-animated models; src/psx_assets.lua model packs
src/world_psx.lua      fuel station, city blocks / metro car / helicopter, roadside wrecks, forest clutter from the packs
src/rig.lua            rigid-part human figures (outfits) and two-bone IK
src/characters.lua     figures cut from assets/characters_psx.glb into rigid parts; src/engine/obj.lua .obj loader
src/humans.lua         soldiers, bandits and survivors: faction AI, combat, squads (A-life), dialogue, trade
src/destruction.lua    destructible objects: damage, collapse, ruins, debris
src/tank*.lua          tank model, interior, physics/damage, driver / gunner / MG stations
src/player.lua         first-person controller (world or tank-local frame), ladders, seats
src/interaction.lua    reusable interactable components ([E] prompts, hold-to-use)
src/weapons.lua        shells, hitscan, explosions, personal firearms and viewmodel
src/viewmodel.lua      first-person arms, grip poses and keyframed reload tracks
src/enemy_tank.lua     rare Soviet-inspired enemy tanks
src/effects.lua        particles, flashes, tracers, casings, footprints and track marks
src/audio.lua          procedural sound synthesis, 3D audio, interior muffling, ambience, music
src/environment.lua    time of day and lighting; src/weather.lua blizzards and snowfall
src/survival.lua       health, stamina, body temperature (clothing insulation), radiation
src/missions.lua, radio.lua, map.lua, inventory.lua, save.lua (JSON), settings.lua, ui.lua, menu.lua
tools/autotest.lua     automated playtest (love . --autotest): drives the game, checks gameplay flows, saves screenshots
tools/drivetest.lua    autopilot (love . --drivetest): drives the tank up the highway from the start to the garages
tools/geartest.lua     running gear check (love . --geartest): tracks and all wheels turn, sides split in a turn
tools/tour.lua         world tour (love . --tour): every place, roads, people, the map and a panel block inside
tools/vmtest.lua       first-person weapons (love . --vmtest): every gun at the hip, aimed and through its reload
```

Saves and settings are JSON files in the LÖVE save directory (`steel_hearth`).

## Testing

Self-driving test modes ship with the project:

```
love . --autotest     # scripted playtest: tank interior, ladder + hatch, driving, cannon/optic, MG, every place,
                      # walking up the stairs of a panel block, clothing vs a night blizzard, a soldier/bandit
                      # firefight, squads on the move, reloads, save/load, repair, bunker, keycard, ending, UI
                      # screens; screenshots -> <save dir>/autotest/
love . --drivetest    # autopilot drives the tank 1.2 km up the highway (logs time, fuel, hull)
love . --tour         # screenshots of every place, the roads, the people and a panel block from outside and inside
love . --vmtest       # screenshots of each gun at the hip, aimed and at six moments of its reload
```

They also run headless, e.g. `SDL_AUDIODRIVER=dummy xvfb-run -a love . --autotest`.
Set `STEEL_TIMING=1` to print world-generation timings (about 10 s on a software renderer).
