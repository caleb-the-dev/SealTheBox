# Power Library
*Autoload singleton — parses powers.csv and exposes power definitions by id.*

## Location
`scripts/globals/power_library.gd` (Autoload: `PowerLibrary`, no class_name — avoids singleton name conflict)

## Responsibility
Load all power definitions once at startup. Provide lookup by id and filtered random selection for power offers. Does not hold any runtime state — all data is static after `_ready()`.

## Public API
```gdscript
func get_power(id: String) -> PowerData
    # Returns the PowerData for the given id, or null if not found.

func get_all() -> Array
    # Returns all PowerData values (unordered; reflects CSV insertion order in practice).

func get_random_unowned(owned_powers: Array) -> PowerData
    # Returns a random PowerData whose id does NOT appear in owned_powers.
    # Returns null if every power id in the library already appears in owned_powers.
    # Used by RunManager._do_power_offer() to select the next power to offer.
```

## Data Source
`seal-the-box/data/powers.csv` — columns: `id, name, type, description`
Currently 5 rows (lighter_box, eager, tab_9_bounty, bonus_seal, box_shutter).

## Gotchas
- **No class_name** — the file starts with `extends Node` only. Adding `class_name PowerLibrary` would conflict with the autoload singleton name and cause a parse error.
- **Uses `preload` for PowerData** — `const PowerData = preload("res://resources/power_data.gd")` at the top of the file. Required because in headless test mode the global class cache may not have registered the class_name yet.
- **`get_random_unowned` filters by id presence, not object identity.** The same PowerData object can appear multiple times in owned_powers (stacked powers) — all copies with the same id are treated as "already owned" for selection purposes.
- **In headless tests**, manually register PowerLibrary before using it:
  ```gdscript
  var power_lib = load("res://scripts/globals/power_library.gd").new()
  power_lib.name = "PowerLibrary"
  get_root().add_child(power_lib)
  power_lib._ready()
  Engine.register_singleton("PowerLibrary", power_lib)
  ```

## Dependencies
- `PowerData` — instantiated during CSV parsing

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Created. |
