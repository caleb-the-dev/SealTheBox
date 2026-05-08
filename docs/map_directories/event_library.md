# Event Library
*Autoload singleton — parses events.csv into EventData objects grouped by pool_id.*

## Location
`scripts/globals/event_library.gd` (Autoload: `EventLibrary`)

## Responsibility
Load and index all event definitions from `data/events.csv` at startup. Expose pool-based access so TextureRoller can randomly draw from a named pool.

## Public API
```gdscript
func get_event(id: String) -> EventData
    # Returns the EventData with the given id, or null if not found.

func get_all() -> Array
    # Returns all EventData objects (unordered).

func get_pool(pool_id: String) -> Array
    # Returns all EventData objects whose pool_id field matches pool_id.
    # Returns [] if pool_id is unknown.
    # Used by TextureRoller.roll() to pick a random event from the "default" pool.
```

## Data File
`data/events.csv` — columns: `id, pool_id, prompt, option_a_label, option_a_effect, option_b_label, option_b_effect`

Current entries (pool_id="default"):
| id | prompt | option_a | effect_a | option_b | effect_b |
|----|--------|----------|----------|----------|----------|
| e_coin | a stranger offers a cursed coin | Accept | hp-1;charge_random+1 | Refuse | none |

## CSV Parsing Pattern
Matches AbilityLibrary / BoxLibrary pattern exactly:
- Opens file with `FileAccess`; skips header row via `get_csv_line()`
- Skips rows with `size() < 7` or empty first column
- Creates `EventDataScript.new()` (preloaded script, not class_name) to avoid class-not-found in headless tests before import

## Internal State
```gdscript
var _events: Dictionary   # id -> EventData
var _pools: Dictionary    # pool_id -> Array[EventData]
```
Both populated once in `_ready()` / `_load_csv()`. Never mutated afterward.

## Singleton Registration
Must be registered explicitly in `match.gd._ready()`:
```gdscript
if not Engine.has_singleton("EventLibrary"):
    Engine.register_singleton("EventLibrary", EventLibrary)
```
Also registered manually in headless tests before use.

## Dependencies
- None (reads CSV directly via FileAccess; no other singleton calls)

## Gotchas
- **No `class_name`** — same pattern as BoxLibrary / PowerLibrary.
- **`EventDataScript` preload** — preloads `res://resources/event_data.gd` and calls `.new()`, so `class_name EventData` does not need to be globally registered at parse time.
- **Pool returns empty array (not null)** when pool_id is unknown.
- **Effect strings are NOT parsed here** — EventLibrary only stores the raw string. Parsing is done in `EventOverlay.apply_effects()` at runtime when the player chooses an option.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Created (feature/within-act-texture). Parses data/events.csv; 1 entry in "default" pool. |
