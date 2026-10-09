# Third-party assets

Everything below is used under its own licence; the full text sits next to the files.

## Models and textures — CC BY 4.0, by heyheythere (https://heyheythere.itch.io)

Source repositories: https://github.com/Spyridon-Pikoulas

| Folder | Pack | Credit line |
|---|---|---|
| `assets/psx/creatures/` | PSX Creatures Free | PSX Creatures Free by heyheythere - https://heyheythere.itch.io/psx-creatures-free - CC BY 4.0 |
| `assets/psx/vehicles/` | PSX Vehicles Free | PSX Vehicles Free by heyheythere - https://heyheythere.itch.io/psx-vehicles-free - CC BY 4.0 |
| `assets/psx/gas_station_kit/` | PSX Gas Station Kit Free | see `LICENSE.txt` in the folder |
| `assets/psx/forest/` | PSX Forest Free | see `LICENSE.txt` in the folder |
| `assets/psx/firearms/` | PSX Firearms Free | see `LICENSE.txt` in the folder |
| `assets/textures/{concrete,brick,plaster,wood}.png` | PSX Textures Free | see `assets/textures/PSX_TEXTURES_LICENSE.txt` |

Changes made here: the `.glb` files are renamed (`*_model.glb` -> `*.glb`); models are tinted and
snow is added at load time; the textures are renamed to the game's material names.

## Shader references

* CRT / VHS screen filters in `shaders/post.glsl` are adapted from **Retro Screen FX Free** by
  heyheythere (CC BY 4.0) - https://github.com/Spyridon-Pikoulas/godot-retro-screen-fx-free
* The 4x4 dither table is the PlayStation GPU's own.

## Models added to `assets/` by hand (Sketchfab downloads)

| File | Title, author | Licence |
|---|---|---|
| `characters_psx.glb` | Characters_psx by Elbolillo (sketchfab.com/Elbolilloduro) | CC BY 4.0 |
| `low_poly_psx_style_soviet_subway_-_metro_props.glb` | Low Poly PSX Style Soviet Subway - Metro Props by keywizzz | CC BY 4.0 |
| `soviet_khrushchyovka_-_ps1_style.glb` | Soviet Khrushchyovka - PS1 Style by zufari4 | CC BY 4.0 |
| `psx_russian_soviet_housing_3d_model.glb` | PSX Russian Soviet Housing 3D Model by zhya (zzzhya) | CC BY 4.0 |
| `russian_residential_blocks_spalny_rayon_psx.glb` | Russian Residential Blocks (Spalny Rayon) PSX by crime100 | CC BY 4.0 |
| `lowpoly_panelka_psx.glb` | LowPoly Panelka psX by Ferya1L | CC BY-SA 4.0 (share-alike) |
| `ps1low_poly_kamov_ka29_helix_helicopter.glb` | PS1/Low Poly Kamov KA29 Helix Helicopter by Jellypack | CC BY-NC 4.0 (**non-commercial only**) |
| `psx_ak-74.glb` | PSX AK-74 by Charckes (charlesmoch) | Sketchfab Standard (**may not be redistributed**, e.g. in a public repository) |
| `PSXMiscGuns/` | PSX Misc Guns pack (M14-style rifle, Makarov, 1911, shotgun, flare gun) | no licence file in the folder - check the download page |

How they are used: the character figures are cut into rigid parts for the NPC rig
(`src/characters.lua`); the guns become the first-person rifle, AK and pistol (`src/weapons.lua`);
the buildings, metro car, props and helicopter make up the microdistrict (`src/world_psx.lua`).
All of these are optional: without the files the game falls back to its procedural models.
