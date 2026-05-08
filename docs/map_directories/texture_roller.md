# Texture Roller
*Static-method helper — rolls the weighted between-match beat (silent / vignette / event).*

## Location
`scripts/run/texture_roller.gd` (class_name TextureRoller — NOT an autoload)

## Responsibility
Given a pool_id, randomly select a between-match beat type and return a result Dictionary. Called by RunManager after every non-crossroads match transition.

## Public API
```gdscript
const PROB_SILENT   := 0.50    # probability of a silent beat (nothing shown)
const PROB_VIGNETTE := 0.30    # probability of a vignette beat
# PROB_EVENT is implicit: 1.0 - PROB_SILENT - PROB_VIGNETTE = 0.20

static func roll(pool_id: String) -> Dictionary
    # Rolls a random float [0, 1).
    #   < PROB_SILENT                        → { type: "silent" }
    #   < PROB_SILENT + PROB_VIGNETTE        → { type: "vignette", vignette: VignetteData }
    #   else                                 → { type: "event",    event: EventData }
    #
    # If VignetteLibrary / EventLibrary singleton is missing, or the pool is empty
    # for the chosen type, falls back to { type: "silent" }.
    # Never returns null — always returns a valid Dictionary with a "type" key.
```

## Result Dictionary Shape
```
{ "type": "silent" }
{ "type": "vignette", "vignette": <VignetteData instance> }
{ "type": "event",    "event":    <EventData instance>    }
```

## Usage
```gdscript
# In RunManager._do_texture_beat():
var beat := TextureRoller.roll("default")
if beat["type"] == "silent":
    _start_next_match()
else:
    show_texture_beat.emit(beat)
```
TextureRoller is used as a static class — no instantiation needed, no autoload registration needed.

## Tuning
Change `PROB_SILENT` or `PROB_VIGNETTE` constants in the file to adjust distribution. The event probability is always the remainder. After tuning, run `test_texture_roller.gd` to verify distribution (1000 rolls, ±8% tolerance).

## Dependencies
- `VignetteLibrary` (singleton) — consulted for vignette pool via `get_pool(pool_id)`
- `EventLibrary` (singleton) — consulted for event pool via `get_pool(pool_id)`
- Both are guarded with `Engine.has_singleton()` — missing singletons fall back to silent

## Gotchas
- **Static methods only** — TextureRoller has no instance state. Call `TextureRoller.roll(...)` directly without creating an instance.
- **Falls back to silent on empty pools** — if the "default" pool has no vignettes, vignette rolls return silent. Same for events. This means changing PROB constants while pools are empty will still only produce silent beats.
- **No `class_name` conflict** — `class_name TextureRoller` is safe here because there is no autoload named TextureRoller.
- **Headless test access** — tests must `preload("res://scripts/run/texture_roller.gd")` and call `TextureRollerScript.roll(...)` because `class_name` registration is import-time, not parse-time, in headless mode.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Created (feature/within-act-texture). PROB_SILENT=0.50, PROB_VIGNETTE=0.30, PROB_EVENT=0.20. |
