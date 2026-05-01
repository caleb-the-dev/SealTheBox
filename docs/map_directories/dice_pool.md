# Dice Pool
*Manages the deck-like dice pool, drawing hands, rolling, and modifiers.*

## Location
`scripts/match/dice_pool.gd`

## Responsibility
Own the pool (deck) of Die objects, draw a hand of 3 each round, roll selected dice, apply modifiers.
Pool reshuffles (discards returned) when fewer than 3 dice remain.
Does NOT own AP logic — caller checks AP before calling roll.

## Public API
```gdscript
func draw_hand() -> Array[Die]               # draw 3 random dice into hand
func roll_die(die: Die) -> int               # randomise and return value
func apply_greater(die: Die, x: int) -> void
func apply_lesser(die: Die, x: int) -> void
func reroll(die: Die) -> int
func discard_hand() -> void                  # end of round cleanup
func reset(pool_config: Array) -> void
```

## Die Object
```gdscript
var faces: int      # 4, 6, 8, 10, 12
var value: int      # current rolled value (0 = not yet rolled)
var rolled: bool
```

## Dependencies
- `GameState` — writes dice_hand[]

## Data
Starting pool hardcoded [d6, d6, d6, d8] in vertical slice.

## Known Issues / TODOs
- [ ] Implement (not yet built)
- [ ] Type field on Die not used in vertical slice

## Last Updated
2026-05-01
