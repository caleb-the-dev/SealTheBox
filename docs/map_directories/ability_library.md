# Ability Library
*Autoload singleton — parses abilities.csv and exposes typed AbilityData resources.*

## Location
`scripts/globals/ability_library.gd` (Autoload: `AbilityLibrary`)
`resources/ability_data.gd` (Resource subclass)
`data/abilities.csv` (source data)

## Responsibility
Parse abilities.csv once at startup. Index by id. Never re-parse at runtime.
Does NOT determine which abilities a player has — that's GameState.

## Public API
```gdscript
func get_ability(id: String) -> AbilityData
func get_all() -> Array[AbilityData]
```

## AbilityData Fields
```gdscript
var id: String
var flavor_name: String
var type: String        # Diabolic, Cosmic, Ethereal, Mundane
var traits: Array[String]
var cooldown: int
var ap_cost: int
var description: String
```

## Dependencies
None — loaded before any other system via Autoload order.

## Data
Reads: `data/abilities.csv`

## Known Issues / TODOs
- [ ] Implement (not yet built)
- [ ] abilities.csv needs id column added (currently uses row index)

## Last Updated
2026-05-01
