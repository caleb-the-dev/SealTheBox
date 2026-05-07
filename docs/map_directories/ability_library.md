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
var description: String
var charges: int            # remaining charges on this instance (decremented on use)
var max_charges: int        # base charge count from CSV; set once at load, never mutated at runtime
```

## Current Abilities (abilities.csv) — Rotation Pool (14 abilities)
| id | flavor_name | charges | notes |
|----|-------------|---------|-------|
| reroll_die | Reroll | 2 | targets a die |
| greater_1 | Empower | 3 | targets a die; blocked if die.value >= die.faces |
| lesser_1 | Weaken | 3 | targets a die |
| greater_2 | Empower II | 2 | targets a die; blocked if die.value >= die.faces |
| lesser_2 | Weaken II | 2 | targets a die |
| reroll_all | Reroll All | 1 | no target; fires immediately on click |
| put_down_highest | Auto-Seal Highest | 1 | no target; fires immediately; Non-Final |
| auto_seal_lowest | Auto-Seal Lowest | 2 | no target; fires immediately; Non-Final |
| multiply_2 | Multiply x2 | 1 | targets a die; no ceiling |
| set_max | Set to Max | 2 | targets a die |
| set_min | Set to Min | 3 | targets a die |
| reroll_lucky | Reroll Lucky | 2 | targets a die; keeps higher result |
| reroll_unlucky | Reroll Unlucky | 2 | targets a die; keeps lower result |
| drop_die | Drop Die | 2 | targets a die; excludes from total + sealing |

Non-pool stubs in the CSV (roll_d4, cosmic_coin, lesser_greater_1, lesser_2_cosmic, roll_d20, greater_2_diabolic, x2_diabolic, greater_1_diabolic) — placeholders for a future dice-type system; not wired in round_manager.gd.

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
| 2026-05-06 | CSV expanded from 15 to 22 rows: added put_down_highest (updated from stub), auto_seal_lowest, multiply_2, set_max, set_min, reroll_lucky, reroll_unlucky, drop_die. Rotation pool expanded from 6 to 14. multiply_3 was added then removed. test_ability_library.gd count assertion updated to 22. |
| 2026-05-04 | Removed ap_cost field from AbilityData and abilities.csv. |
| 2026-05-04 | Added `charges` (col 8) and `max_charges` fields to AbilityData. Library parses row[7] with safe fallback to 1; clamps to max(1, value). All 15 CSV rows updated with charge values. |
| 2026-05-01 | Initial implementation. |
