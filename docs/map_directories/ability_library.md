# Ability Library
*Autoload singleton — parses abilities.csv and exposes typed AbilityData resources.*

## Location
`scripts/globals/ability_library.gd` (Autoload: `AbilityLibrary`)
`resources/ability_data.gd` (Resource subclass)
`data/abilities.csv` (source data)

## Responsibility
Parse abilities.csv once at _ready(). Index by id. Never re-parse at runtime.
Does NOT determine which abilities a player has — that's GameState.ability_hand.

## Public API
```gdscript
func get_ability(id: String) -> AbilityData   # returns null if not found
func get_all() -> Array                        # all AbilityData values (unordered)
```

## AbilityData Fields
```gdscript
var id: String
var flavor_name: String
var type: String            # Diabolic, Cosmic, Ethereal, Mundane
var traits: Array[String]
var cooldown: int
var ap_cost: int
var description: String
```

## Current Abilities (abilities.csv)
| id | flavor_name | effect |
|----|-------------|--------|
| reroll_die | Reroll | Reroll one die in hand |
| greater_1 | Empower | Add +1 to one die's value |
| lesser_1 | Weaken | Subtract 1 from one die's value |

## Dependencies
None — loaded before any other system via Autoload order.

## Gotchas
- **No `class_name`** — same rule as BoxLibrary. Adding a class_name matching the autoload name causes a parse error.
- Access via `Engine.get_singleton("AbilityLibrary")` everywhere. In tests, register manually before use.
- Abilities in `ability_hand` are `.duplicate()`d from the library — mutations don't affect the library's stored copies.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-01 | Initial implementation. |
