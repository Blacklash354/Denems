# STEEL HEARTH

A first-person survival / exploration / tank game prototype for **LÖVE 11.4+** (real 3D, PSX style).
You are alone in a nuclear winter. Your heavy tank is your shelter, storage, weapon platform and only way home.

Everything — the 3D renderer, all models, textures and **all audio** — is generated procedurally in Lua.
There are no external assets or libraries to install.

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
| Rifle / pistol | `1` / `2` |
| Inventory / map / objectives | `Tab` / `M` / hold `J` |
| Quick save / load | `F5` / `F9` |
| Pause | `Esc` |
| FPS / draw-call counter | `F3` |

**Driver seat:** `W/S` throttle, `A/D` steer (tracks pivot), `Space` brake, `F` engine, `L` headlights.
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

Components (engine, both tracks, turret, cannon and hull) can be damaged. Repairs cost repair kits.
You can build repair kits from spare parts.

## Locations

The frozen village (Soviet Town), the industrial zone, the frozen forest with the hunter's cabin,
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
