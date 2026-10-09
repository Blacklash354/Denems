# STEEL HEARTH

A first-person survival / exploration / tank game prototype for **LÖVE 11.4+** (real 3D, PSX style).
You are alone in a nuclear winter. Your heavy tank is your shelter, storage, weapon platform and only way home.

The 3D renderer, the tank, the world and **all audio** are generated procedurally in Lua. On top of that the game
loads a few hand-made PSX model packs (fuel station, wrecks, forest clutter, walkers, giant spiders, pistol and
shotgun) and textures from `assets/` — see `assets/psx/CREDITS.md` for authors and licences. Nothing to install.

## Running

```
love .
```

Requires LÖVE 11.4 or newer (tested on 11.5). The first launch takes a few seconds to generate the world.

## Controls

| Action | Key |
|---|---|
| Move / sprint / crouch / jump | `WASD` / `Shift` / `C` or `Ctrl` / `Space` |
| Interact / leave a seat | `E` (some actions are hold-to-complete) |
| Flashlight | `F` |
| Fire / aim / reload | `LMB` / `RMB` / `R` |
| Rifle / AK or PPSh / pistol / pump shotgun | `1` / `2` / `3` / `4` or mouse wheel |
| Inventory / map / objectives | `Tab` / `M` / hold `J` |
| Quick save / load | `F5` / `F9` |
| Pause | `Esc` |
| FPS / draw-call counter | `F3` |

**Driver seat:** `W/S` throttle, `A/D` steer (tracks pivot), `Space` brake, `F` engine, `L` headlights, `V` toggles a third-person chase camera (mouse orbits it).
**Gunner seat:** mouse or `WASD` traverses the turret and elevates the gun, `RMB` optic, wheel zoom,
`R` loads a shell from the racks, `T`/`1`/`2` choose AP or HE, `LMB` fires.
**Bow MG:** mouse aims, `LMB` fires (watch the heat), `R` loads a new belt from storage.

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

## The people of the Zone

Loners rest at camp fires (the Loners' Camp south of the village, Yegor at the hunter's cabin). Talk to them for
hints and a gift, trade with Old Petro, and they will fight mutants that wander close. Shooting a loner turns the
camp hostile. Bandits hold the checkpoint, the military base and the radio tower: they patrol, raise the alarm,
keep their distance while firing bursts, and run when your tank rolls in. Bodies can be searched.

Mutants only live in their lairs: the forest by the river, the factory, the bunker and the nuclear plant.
Walkers shamble around the abandoned fuel station on the main road and the edge of the village; giant spiders
nest among dead trunks deep in the forest and in the industrial zone.
Anomalies (electric discharges and gravitational vortexes) crackle in a few places; a detector beeps as you get close.

## Destruction

Most man-made objects in the world are real destructible objects with their own hit points and
material: checkpoint barrier poles, crates, plank stacks, sandbags, concrete blocks, steel hedgehogs,
fences, watchtowers, tents, signs, vehicles and whole houses. Rifle, SMG and hull-MG bullets chip
away at them (wood and cloth go fast, steel slowly, concrete barely); cannon shells and explosions
take out much more. A destroyed object loses its collision, throws physical debris and a dust cloud,
houses collapse into a rubble mound with wall stubs, vehicles are burnt out with fire and black smoke,
and fuel tanks explode. The tank flattens poles, fences, crates and sandbags when driving through them.

## Radar and compass

The tank carries a radar: a live green scope on the left sponson inside the hull, mirrored on the HUD whenever
you are inside. New contacts are announced ("RADAR: HOSTILES NE 140M") and show up on the compass ribbon.
The compass at the top of the screen shows the headings, the objective with distance, known places and,
on foot, where you left the tank.

## Locations

The frozen village (Soviet Town), the dead microdistrict of panel blocks west of it (when the building models
are in `assets/`), the abandoned fuel station, the industrial zone, the frozen forest with the hunter's cabin,
the military checkpoint, the Soviet military base, Radio Tower Seven, the underground bunker (Object 12)
and the nuclear plant. The main story leads from the radio tower to the bunker and then to the plant's
control block. The radio in the tank picks up broadcasts that reveal locations on the map.

## Project layout

```
main.lua               bootstrap, progressive world loader, app state (loading/menu/game)
conf.lua               window configuration
shaders/               psx.glsl (vertex lighting, snapping, affine UVs, fog), post.glsl (dither,
                       banding, grain, CA, frost/radiation/optic overlays), sky, snow, billboard
src/engine/            math3d (frames/matrices), meshbuilder (procedural low-poly geometry -> meshes),
                       textures (procedural low-res textures), renderer (low-res canvas, lights, post)
src/world.lua          heightfield terrain, chunked static geometry, colliders, queries
src/world_gen.lua      all eight locations, roads, forest, loot, doors, tile-based interiors
src/props.lua          modular buildings and props (houses, halls, hangars, towers, wrecks, trees...)
src/engine/gltf.lua    .glb loader for rigid part-animated models; src/psx_assets.lua model packs
src/world_psx.lua      fuel station, microdistrict, roadside wrecks, forest clutter and lairs built from the packs
src/characters.lua     NPC figures cut from assets/characters_psx.glb into rigid parts; src/engine/obj.lua .obj loader
src/destruction.lua    destructible objects: damage, collapse, ruins, debris
src/tank*.lua          tank model, interior, physics/damage, driver / gunner / MG stations
src/player.lua         first-person controller (world or tank-local frame), ladders, seats
src/interaction.lua    reusable interactable components ([E] prompts, hold-to-use)
src/weapons.lua        shells, hitscan, explosions, personal firearms and viewmodel
src/creatures.lua      Frost Hound, Crawler, Burrower, Large Mutant and their AI
src/enemy_tank.lua     rare Soviet-inspired enemy tanks
src/effects.lua        particles, flashes, tracers, casings, footprints and track marks
src/audio.lua          procedural sound synthesis, 3D audio, interior muffling, ambience, music
src/environment.lua    time of day and lighting; src/weather.lua blizzards and snowfall
src/survival.lua       health, stamina, body temperature, radiation
src/missions.lua, radio.lua, map.lua, inventory.lua, save.lua (JSON), settings.lua, ui.lua, menu.lua
tools/autotest.lua     automated playtest (love . --autotest): drives the game, checks gameplay flows, saves screenshots
tools/drivetest.lua    autopilot (love . --drivetest): drives the tank from the start to the Radio Tower
tools/geartest.lua     running gear check (love . --geartest): tracks and all wheels turn, sides split in a turn
tools/psxtest.lua      imported assets tour (love . --psxtest): station, creatures, weapons; saves screenshots
tools/packtest.lua     user pack tour (love . --packtest): pack guns, character figures, microdistrict
```

Saves and settings are JSON files in the LÖVE save directory (`steel_hearth`).

## Testing

Two self-driving test modes ship with the project:

```
love . --autotest     # scripted playtest: interior walk, ladder + hatch, driving, cannon/optic, MG,
                      # all locations, creatures, enemy armour, repair, refuel, doors, bunker,
                      # keycard, ending, UI screens, save/load; screenshots -> <save dir>/autotest/
love . --drivetest    # autopilot drives the tank from the start to the Radio Tower
```

They also run headless, e.g. `SDL_AUDIODRIVER=dummy xvfb-run -a love . --autotest`.
Set `STEEL_TIMING=1` to print world-generation timings (about 2 s even on a software renderer).
A typical frame is roughly 100–170 draw calls and 25k–60k triangles.
