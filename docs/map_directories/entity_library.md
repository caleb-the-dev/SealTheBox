# Entity Library
*Autoload singleton — parses entities.csv and provides entity lookup and random selection.*

## Location
`scripts/globals/entity_library.gd` (Autoload: `EntityLibrary`)

## Responsibility
Load all three entity definitions (Diabolic, Cosmic, Ethereal) from data/entities.csv at startup. Provide lookup by id and random selection for run-start entity assignment.

Does NOT drive any game logic — it is a data store. Entity selection happens in CaseManager.reset_run().

## Public API
```gdscript
func get_entity(id: String)
    # Returns the EntityData for the given id, or null if not found.
    # Valid ids: "diabolic", "cosmic", "ethereal"

func get_all() -> Array
    # Returns all EntityData objects in CSV row order (Array of EntityData).

func get_random()
    # Returns one EntityData selected uniformly at random from all loaded entities.
    # push_error and returns null if no entities are loaded.
```

## Internal State
```gdscript
const EntityDataScript = preload("res://resources/entity_data.gd")
    # Used instead of bare EntityData class reference to avoid "type not found" errors
    # in headless mode before import. EntityData has class_name but the preload is still needed.

var _entities: Dictionary = {}   # id (String) → EntityData
var _order: Array[String] = []   # insertion order for get_random() — preserves CSV row order
```

## Data File
`data/entities.csv`
```
id,display_name,location_names,vignette_pool_id,event_pool_id
diabolic,"the devil","sulfur manor;bone catacombs;pact tower",vig_diabolic,evt_diabolic
cosmic,"a cosmic horror","wrong-angled house;the deep mine;the silent observatory",vig_cosmic,evt_cosmic
ethereal,"an apparition","quiet hospice;the drowned chapel;the asylum gallery",vig_ethereal,evt_ethereal
```

The `location_names` column is a **single CSV cell** with semicolon-separated values. Parsed with `.split(";")` during load into `EntityData.location_names` (Array[String], length 3). The standard CSV parser would not split these — they must be split manually after `file.get_csv_line()`.

## Dependencies
- `EntityData` (resource) — the typed object each row is parsed into

## Depended On By
- `CaseManager` — calls `get_random()` in reset_run() and `get_entity()` in get_location_name()
- `TextureRoller` — calls `get_entity(GameState.entity_id)` in _get_pool_ids() to resolve pool ids
- `match.gd` — calls `get_entity(GameState.entity_id)` in _refresh_ui() (case label) and _on_run_won() (overlay title)

## Gotchas
- **No `class_name` declaration.** Adding class_name EntityLibrary would cause "hides an autoload singleton" parse error. Access via `Engine.get_singleton("EntityLibrary")`.
- **Preload pattern required.** `EntityDataScript = preload("res://resources/entity_data.gd")` is used instead of bare `EntityData.new()` to avoid parse errors in headless test mode where class_name registration is import-time.
- **Return types are untyped** (`func get_entity(...) ->` no type hint) for the same headless compatibility reason — typed return `-> EntityData` causes "Could not find type" in headless mode.
- **Headless test bootstrap:** Tests using EntityLibrary must load, call _ready(), and register it manually:
  ```gdscript
  var el = load("res://scripts/globals/entity_library.gd").new()
  el.name = "EntityLibrary"
  get_root().add_child(el)
  el._ready()
  Engine.register_singleton("EntityLibrary", el)
  ```
- **`_entities` dict is accessible from tests** for injecting fake entities (used in test_texture_roller.gd's empty-pool fallback test). This is intentional — no private access enforcement in GDScript.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Created (feature/entity-types). Loads 3 entities (diabolic, cosmic, ethereal). Registered in project.godot and match.gd._ready(). |
