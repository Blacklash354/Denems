# Assets

The game ships without external asset files: every texture, model and sound is generated
procedurally at startup (`src/engine/textures.lua`, `src/tank_model.lua`, `src/props.lua`,
`src/audio.lua`).

Drop-in overrides are supported:

* `assets/textures/<name>.png` replaces a procedural texture (e.g. `tank.png`, `snow.png`,
  `interior.png`, `concrete.png`). Keep them small (16–64 px) and tileable for the PSX look.
* `assets/sounds/<name>.ogg` or `.wav` replaces a synthesised sound. Names include
  `engine`, `tracks`, `turret`, `cannon`, `cannon_far`, `explosion`, `mg`, `rifle`, `pistol`,
  `step_snow`, `step_metal`, `wind`, `blizzard`, `hatch`, `static`, `voice`, `growl`, `howl`,
  `roar`, `geiger`, `music` (see `build()` in `src/audio.lua` for the full list).
  Loops (`wind`, `blizzard`, `engine`, `tracks`, `turret`, `static`, `breath`, `music`) should loop seamlessly.

`models/`, `music/` and `fonts/` are reserved for future hand-made content.
