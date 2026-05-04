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
var charges: int            # remaining charges on this instance (decremented on use)
var max_charges: int        # base charge count from CSV; set once at load, never mutated at runtime
```

## Current Abilities (abilities.csv) — Rotation Pool
| id | flavor_name | charges |
|----|-------------|---------|
| reroll_die | Reroll | 2 |
| greater_1 | Empower | 3 |
| lesser_1 | Weaken | 3 |
| greater_2 | Empower II | 2 |
| lesser_2 | Weaken II | 2 |
| reroll_all | Reroll All | 1 |

Additional card-type abilities (roll_d4, cosmic_coin, etc.) are in the CSV with charges=1 but are not in the current rotation pool.

## Dependencies
None — loaded before any other system via Autoload order.

## Gotchas
- **No `class_name`** — same rule as BoxLibrary. Adding a class_name matching the autoload name causes a parse error.
- Access via `Engine.get_singleton("AbilityLibrary")` everywhere. In tests, register manually before use.
- Abilities in `ability_hand` are `.duplicate()`d from the library — mutations (charge decrements) don't affect the library's stored copies.
- **`max_charges` is set once at load time from the CSV and must not be mutated at runtime.** It is the UI source of truth for displaying "N/M charges".
- **Charges are clamped to `max(1, parsed_value)`** — a CSV row with charges=0 silently becomes charges=1. No ability can be born exhausted.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Added `charges` (col 8) and `max_charges` fields to AbilityData. Library parses row[7] with safe fallback to 1; clamps to max(1, value). All 15 CSV rows updated with charge values. |
| 2026-05-01 | Initial implementation. |
