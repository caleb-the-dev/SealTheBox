# Texture Roller
*Static-method helper — rolls the weighted between-match beat (silent / vignette / event).*

## Location
`scripts/run/texture_roller.gd` (class_name TextureRoller — NOT an autoload)

## Responsibility
Randomly select a between-match beat type and return a result Dictionary, using the current run's entity pools for content selection. Called by RunManager after every non-crossroads match transition.

## Public API
```gdscript
const PROB_SILENT   := 0.50    # probability of a silent beat (nothing shown)
const PROB_VIGNETTE := 0.30    # probability of a vignette beat
# PROB_EVENT is implicit: 1.0 - PROB_SILENT - PROB_VIGNETTE = 0.20

static func roll(_pool_id: String = "default") -> Dictionary
    # Rolls a random float [0, 1).
    #   < PROB_SILENT                        → { type: "silent" }
    #   < PROB_SILENT + PROB_VIGNETTE        → { type: "vignette", vignette: VignetteData }
    #   else                                 → { type: "event",    event: EventData }
    #
    # Pool ids are resolved from the current entity via GameState.entity_id + EntityLibrary,
    # NOT from the _pool_id parameter (kept for backward compat, ignored).
    # Falls back to "default" pool if entity_id is empty or EntityLibrary is missing.
    # If VignetteLibrary / EventLibrary singleton is missing, or the resolved pool is empty,
    # falls back to { type: "silent" }.
    # Never returns null — always returns a valid Dictionary with a "type" key.

static func _get_pool_ids() -> Dictionary
    # Internal helper — returns { "vignette": pool_id, "event": pool_id } by reading
    # GameState.entity_id and EntityLibrary. Returns "default" for both if entity_id is empty.
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
var beat := TextureRoller.roll()   # pool_id arg no longer needed — entity is read internally
if beat["type"] == "silent":
    _start_next_match()
else:
    show_texture_beat.emit(beat)
```
TextureRoller is used as a static class — no instantiation needed, no autoload registration needed.

## Tuning
Change `PROB_SILENT` or `PROB_VIGNETTE` constants in the file to adjust distribution. The event probability is always the remainder. After tuning, run `test_texture_roller.gd` to verify distribution (1000 rolls, ±8% tolerance).

## Dependencies
- `GameState` (singleton) — reads `entity_id` to determine which entity's pools to use
- `EntityLibrary` (singleton) — looks up entity by id to get vignette_pool_id and event_pool_id
- `VignetteLibrary` (singleton) — consulted for vignette pool via `get_pool(pool_id)`
- `EventLibrary` (singleton) — consulted for event pool via `get_pool(pool_id)`
- All four are guarded with `Engine.has_singleton()` — missing singletons fall back to "default" pool or silent

## Gotchas
- **pool_id parameter is now ignored.** The `roll(pool_id)` signature is preserved for backward compat but the parameter is unused. Pool ids come from the entity on GameState. Calling `roll("nonexistent_pool")` does NOT produce silent — it uses the entity's actual pools (or "default" fallback).
- **Static methods only** — TextureRoller has no instance state. Call `TextureRoller.roll()` directly without creating an instance.
- **Falls back to silent on empty pools** — if the entity's vignette pool has no entries (or the pool id doesn't exist in VignetteLibrary), vignette rolls return silent. Same for events.
- **No `class_name` conflict** — `class_name TextureRoller` is safe here because there is no autoload named TextureRoller.
- **Headless test access** — tests must `preload("res://scripts/run/texture_roller.gd")` and call `TextureRollerScript.roll()` because `class_name` registration is import-time, not parse-time, in headless mode. Tests must also bootstrap EntityLibrary singleton and set GameState.entity_id to control which pools are used.
- **Empty entity_id → "default" pool.** Before CaseManager.reset_run() runs (or in tests that don't bootstrap EntityLibrary), entity_id is "" and TextureRoller uses the "default" pool for both vignettes and events. This is intentional fallback behavior.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | feature/entity-types: Pool id resolution changed from caller-supplied pool_id parameter to internal entity lookup (GameState.entity_id → EntityLibrary → entity.vignette_pool_id / event_pool_id). Added _get_pool_ids() internal helper. "default" pool used as fallback when entity_id is empty. pool_id parameter kept for compat but ignored. |
| 2026-05-07 | Created (feature/within-act-texture). PROB_SILENT=0.50, PROB_VIGNETTE=0.30, PROB_EVENT=0.20. |
