# Entity Data
*Resource subclass — typed data object for one entity type.*

## Location
`resources/entity_data.gd` (class_name: EntityData, extends Resource)

## Responsibility
Hold all flavor data for one of the three entity types. Instantiated by EntityLibrary during CSV parse. Read-only at runtime (no game logic writes to it after load).

## Fields
```gdscript
var id: String = ""
    # Unique identifier: "diabolic", "cosmic", or "ethereal"

var display_name: String = ""
    # Human-readable name shown in UI: "the devil", "a cosmic horror", "an apparition"

var location_names: Array[String] = []
    # Length 3 — one name per act. Index 0 = act 1, index 1 = act 2, index 2 = act 3.
    # Examples (diabolic): ["sulfur manor", "bone catacombs", "pact tower"]
    # Accessed by CaseManager.get_location_name(act) as location_names[act - 1].

var vignette_pool_id: String = ""
    # pool_id to query VignetteLibrary with. Values: "vig_diabolic", "vig_cosmic", "vig_ethereal"

var event_pool_id: String = ""
    # pool_id to query EventLibrary with. Values: "evt_diabolic", "evt_cosmic", "evt_ethereal"
```

## Gotchas
- **`location_names` is a typed `Array[String]`** — assigning a plain Array literal to it raises "Invalid assignment of property ... with value of type 'Array'". Always use `.append()` to populate it, or assign from another typed `Array[String]`.
- **`class_name EntityData` is safe** — there is no autoload named EntityData, so no conflict. The class is accessible by name in scene context but NOT in headless test mode without a preload (see entity_library.md).

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | Created (feature/entity-types). 5 fields: id, display_name, location_names (Array[String] length 3), vignette_pool_id, event_pool_id. |
