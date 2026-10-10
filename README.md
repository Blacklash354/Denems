# STEEL HEARTH

A first-person survival / exploration / tank game for **LÖVE 11.4+** (real 3D, PSX style).
The war is over and nobody won. A nuclear winter has buried the Soviet countryside in snow; what is
left of the Red Army, bandits and a few survivors fight over the ruins. You are Kurt Weber, a German tank
driver left behind in the south of the map with a worn-out heavy tank; what is left of your company is dug in at
an outpost by a frozen lake far to the north. The tank is your shelter, storage, weapon platform and only way
across the 4 km of snow between you and them.

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

**Driver seat:** `W/S` throttle, `A/D` steer (tracks pivot), `Space` brake, `F` engine, `L` headlights, `V` toggles a third-person chase camera (mouse orbits it). The mouse turns your head: the compass is right of the vision slit, the radar behind your left shoulder.

**Challenges:** when a sentry stops you, answer with `1`-`4` or a click.
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

Roads are separate meshes that follow smooth centre lines: packed snow over asphalt or a snowed-over dirt track,
a faint centre line, ploughed snow banks at the edges (textured at the same density as the snow around them) and a
flattened corridor so the terrain never pokes through. Tanks, people, prints and spent brass stand on the road
surface itself (`W.groundHeight`), not on the terrain sunk underneath it. The world shader uses perspective-correct
texture coordinates (the old hand-made uv/w interpolation broke on big ground triangles reaching behind the camera,
which made the snow and roads smear and stretch while walking). The optional "RETRO WOBBLE" setting still gives the
PSX affine look to everything but the ground: terrain, roads and prints are always drawn without it, so the roads
never swim under you.

The roads carry no painted ruts. The marks on them are the ones that are really made: every tank lays a cleated
print per track link (grey pressed slush on a road, a blue-shadowed trench in deep snow) and people leave boot
prints. Falling snow fills them in - in a few minutes when it is calm, much faster in a blizzard - until they are
gone.

### Deep snow and drifts

Snow lies knee deep in the open and packed thin on the roads. In deep snow the tank sinks into it, slows down and
throws snow up off its tracks; on foot you sink in and wade. Wind has piled drifts across the roads: the tank has
to plough through them - it bucks, slows and throws a wave of snow, and what it shoves aside stays as a low heap.
Fresh snowfall slowly builds the drifts back up.

Snow builds up on the tank too: packed into the running gear and plastered on the bow when you plough through deep
snow, and settling on the decks and turret roof while it stands still in a snowfall. The engine's heat melts it
again - the engine deck first, in clouds of steam, the turret roof last - and a cold tank keeps its snow for hours.

The exhausts have rain caps that flutter with the engine. A cold diesel coughs black smoke and sparks while the
starter turns it over; running, it breathes a thin blue-grey haze plus white vapour in the frozen air (thicker
while the engine is still cold), and only puts out a black plume when it really labours.

## People

There are no monsters - only people, and they are dangerous enough.

* **Soldiers** of the Red Army (greatcoats and olive helmets, gas masks, winter whites, a bareheaded sergeant; NBC
  suits around the power plant) hold the checkpoint, the city square, the airfield, the base, the tower and the plant,
  and patrol the roads.
* **Bandits** (balaclavas, leather, tracksuits) squat in the garages, the tractor works, the school and the city's east side.
* **Survivors** sit at their fires in the camp, in Pervomaisk, in the city and in the forest. They talk, give
  you something useful the first time, trade (Old Petro) and fight bandits and soldiers. Shooting one turns their friends against you.

* **Our own** - a German garrison in field grey - holds Stutzpunkt Nord in the far north.

Not everyone shoots first. About half the army posts and a third of the bandit hideouts are *wary*: when they
spot you on foot one of them raises his rifle, walks over and asks who you are and where you are coming from
("STOI! Hands where I can see them!"). The game pauses on the question and you pick an answer: tell them you are
trying to get back north, claim to be a survivor, hand over food, documents or ammunition, bluff a bandit with your
tank, or tell them it is none of their business. The right answer (or the right bribe) and the whole post lets you
pass; a wrong one, walking off or pointing a gun at them starts the fight. A German tank gets no questions.

Factions fight each other whenever they meet. Squads walk between places along the roads (they keep travelling
while you are far away), and a squad that is wiped out is replaced by a new one after a while. Bodies can be searched.
The people are Quaternius' CC0 modular men and women, recoloured and cut into rigid PSX body parts by
`tools/people_convert.py` (heads, torsos, upper arms, forearms with hands, thighs, shins with boots), posed with
two-bone IK so their hands sit on the rifle; the NBC troops and masked raiders come from
`assets/characters_psx.glb`.

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

Your arms are the soldier model's own sleeves and gloved hands, the fingers posed round the pistol grip and under the
handguard, tinted with the coat and gloves you wear. They follow the gun with two-bone IK: the right hand on the grip,
the left on the handguard (with the pistol it hangs out of sight until a reload). The gun is drawn with its own,
narrower field of view so it points where you look instead of bending towards the middle of the screen. Reloads are done by the left hand: it takes the magazine out, goes to the pouch, brings a new one,
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
You can build repair kits from spare parts. A shell in the running gear can throw a track: the belt runs off the
wheels and lies in the snow beside the tank, and the tank can only pivot until you fit it back on with a repair kit.

The driver can turn his head right round in the seat: forward through the vision slit, right to the compass on the
front wall (the red needle swings to north as the hull turns; the red mark on the rim is the nose), back over the
left shoulder to the radar screen.

### Enemy armour

The Red Army still has tanks: T-34-85s (sloped glacis and sides, five big Christie road wheels, the long 85 mm, fuel
drums and an unditching log) and IS-2s (longer hull, six wheels, a big turret and the 122 mm with its muzzle brake),
in a patchy winter whitewash with white tactical numbers. They patrol the roads, the base, the airfield, the plant
and the tower. Frontal armour shrugs off a lot, the rear is weak, and a hit low on the side throws a track and
leaves them sitting where they are - the turret still fights.

## Destruction

Trees break. Ram one hard and the trunk snaps: the butt is kicked forward, the crown comes down backwards on the
tank, lies across the hull and slides off the back as you drive on (snow showers off it and onto your decks); push one
slowly and it goes over ahead of you. Shell blasts and direct hits fell them too. Falling trees are rigid rods
hinged at the stump that rest on the tank or the ground; the stumps stay and the fallen trees are saved.

Most man-made objects in the world are real destructible objects with their own hit points and
material: checkpoint barrier poles, crates, plank stacks, sandbags, concrete blocks, steel hedgehogs,
fences, watchtowers, tents, signs, vehicles and whole houses. Rifle, SMG and hull-MG bullets chip
away at them (wood and cloth go fast, steel slowly, concrete barely); cannon shells and explosions
take out much more. A destroyed object loses its collision, throws physical debris and a dust cloud,
houses sink into a rubble mound with wall stubs in a rolling cloud of dust, vehicles are burnt out with fire and
black smoke, and fuel tanks explode. Debris has a shape (splintered planks, bent sheet metal, rubble, slabs with
rebar) and whatever lands on the tank rides along and slides off as it rattles and tilts. The tank flattens poles,
fences, crates and sandbags when driving through them.

Smoke, fire, explosions and muzzle flashes are sprites from Kenney's CC0 particle packs, shrunk to blocky PSX size
(`assets/fx`, built by `tools/fx_atlas.py`): rolling puffs, fireballs, star-shaped muzzle flames, clods of earth.

## Radar

The tank carries a radar: a live green scope on the left sponson inside the hull (turn round in the driver's seat to
read it), mirrored on the HUD only while you are glued to the gunner's sight. New hostile contacts are announced
briefly ("RADAR: HOSTILES NE 140M").

## Story and the map

There is no objective list and no marker. Hans left a note taped to the instrument panel by the driver's seat: the
company pulled back north to Stutzpunkt Nord, the outpost by the lake past the big power station - follow the
compass. A soldier's postcard at the kolkhoz, a Red Army order at the checkpoint and two signposts in the north
point the same way. Reach the outpost, on foot or in the tank, and you are home.

The map (`M`) is under a fog of war: only ground you have seen yourself is drawn (you see further from the tank),
and places you have only read or heard about show as "NAME ?". There is a second thread for the curious: the radio
picks up broadcasts that lead from Tower Seven's transmitter to Object 12 and the power plant's control block, where
someone is still alive.

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
src/humans.lua         soldiers, bandits, survivors and our garrison: faction AI, combat, squads (A-life), dialogue, trade
src/people.lua         modelled people (assets/people, built by tools/people_convert.py) for the rig
src/dialog.lua         challenges: wary sentries ask who you are; answers, bribes and bluffs
src/destruction.lua    destructible objects: damage, collapse, ruins, debris; falling trees
src/tank*.lua          tank model, interior, physics/damage, driver / gunner / MG stations
src/player.lua         first-person controller (world or tank-local frame), ladders, seats
src/interaction.lua    reusable interactable components ([E] prompts, hold-to-use)
src/weapons.lua        shells, hitscan, explosions, personal firearms and viewmodel
src/viewmodel.lua      first-person arms, grip poses and keyframed reload tracks
src/enemy_tank.lua     Soviet T-34-85 and IS-2 tanks: patrols, gunnery, armour zones, thrown tracks, burning wrecks
src/effects.lua        particles, flashes, tracers, casings, footprints and track marks (filled in by snowfall)
src/snow.lua           snow depth, drifts across the roads, snow on the tank, engine heat and steam
src/audio.lua          procedural sound synthesis, 3D audio, interior muffling, ambience, music
src/environment.lua    time of day and lighting; src/weather.lua blizzards and snowfall
src/survival.lua       health, stamina, body temperature (clothing insulation), radiation
src/missions.lua, radio.lua, map.lua, inventory.lua, save.lua (JSON), settings.lua, ui.lua, menu.lua
tools/autotest.lua     automated playtest (love . --autotest): drives the game, checks gameplay flows, saves screenshots
tools/drivetest.lua    autopilot (love . --drivetest): drives the tank up the highway from the start to the garages
tools/geartest.lua     running gear check (love . --geartest): tracks and all wheels turn, sides split in a turn
tools/tour.lua         world tour (love . --tour): every place, roads, people, the map and a panel block inside
tools/vmtest.lua       first-person weapons (love . --vmtest): every gun at the hip, aimed and through its reload
tools/snowtest.lua     snow (love . --snowtest): ploughs a drift, leaves prints, runs in deep snow, melts, snows over
tools/treetest.lua     destruction (love . --treetest): a tree on the tank, a tree pushed over, a blast, debris, a collapse
tools/peopletest.lua   people (love . --peopletest): every figure in a row, idle, aiming, walking and sitting
tools/tanktest.lua     armour (love . --tanktest): T-34 and IS-2 close up, a track shot off theirs and ours
tools/talktest.lua     challenges (love . --talktest): paying a sentry with food, refusing a bandit
tools/northtest.lua    the way north (love . --northtest): Hans' note, the compass, the radar, map fog, the outpost
tools/fxtest.lua       effects (love . --fxtest): rifle, cannon blast, shell explosion, fire
tools/people_convert.py, tools/fx_atlas.py   build assets/people and assets/fx from the CC0 source packs
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
love . --snowtest     # chase-camera screenshots of the tank ploughing a drift, its prints on the road and in deep
                      # snow, the snow on it melting off a hot engine and the prints snowing over (logs the numbers);
                      # STEEL_WOBBLE=1 runs it with the retro wobble on
```

They also run headless, e.g. `SDL_AUDIODRIVER=dummy xvfb-run -a love . --autotest`.
Set `STEEL_TIMING=1` to print world-generation timings (about 10 s on a software renderer).
