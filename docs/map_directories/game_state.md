# Game State
*Autoload singleton — single source of truth for all mutable match and run state.*

## Location
`scripts/globals/game_state.gd` (Autoload: `GameState`)

## Responsibility
Owns all mutable state: HP, AP, tabs, dice pool, ability hand, round number, round limit, win threshold.
Does NOT own game logic — it stores data, never drives phase transitions.

## Public API
```gdscript
var hp: int
var ap: int
var round: int
var round_limit: int
var win_threshold: int
var tabs: Array[int]          # unsealed tabs remaining
var dice_pool: Array[Die]     # full pool (deck)
var dice_hand: Array[Die]     # currently drawn dice
var ability_hand: Array[AbilityData]

func reset_match() -> void    # re-initialise for a new match
func spend_ap(amount: int) -> bool   # returns false if insufficient
```

## Dependencies
None — other systems read from and write to GameState.

## Data
Initialised with hardcoded values in vertical slice. Future: reads run config from RunManager.

## Known Issues / TODOs
- [ ] Implement (not yet built)

## Last Updated
2026-05-01
