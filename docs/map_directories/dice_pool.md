# Dice Pool
*Manages the deck-like dice pool, drawing hands, rolling, and modifiers.*

## Location
`scripts/match/dice_pool.gd`

## Responsibility
Own the pool (deck) of Die objects, draw a hand of 3 each round, roll selected dice, apply modifiers.
Pool reshuffles (discards returned to draw) when fewer than 3 dice remain.
Does NOT own AP logic — caller (RoundManager) checks AP before calling roll.

## Public API
```gdscript
func setup(pool: Array) -> void          # initialise from GameState.dice_pool.duplicate()
func draw_hand() -> Array                # draw up to 3 dice into hand
func roll_die(die: Die) -> void          # randomise die.value, set die.rolled = true
func apply_greater(die: Die, x: int) -> void   # add x to die.value
func apply_lesser(die: Die, x: int) -> void    # subtract x from die.value (floor 1)
func reroll(die: Die) -> void            # re-randomise an already-rolled die
func discard_hand() -> void              # return hand to discard pile (end of round)
func get_draw_count() -> int
func get_discard_count() -> int
```

## Die Object
```gdscript
class_name Die
var faces: int      # max value (4, 6, 8, 10, 12)
var value: int      # current rolled value (0 = not yet rolled)
var rolled: bool
```

## Starting Pool
Set by `GameState._setup_dice_pool()`: **3×d6 + 1×d4 + 1×d8 = 5 dice total**.
Grows over a run when the player picks reward dice after winning the final match.

## Dependencies
- Called by RoundManager. Shares Die object references with GameState.dice_pool and GameState.dice_hand.

## Gotchas
- Die objects are **shared references** between GameState.dice_pool, GameState.dice_hand, and DicePool internals. Mutating a die (rolling, modifier) is immediately visible through all three references. This is intentional — RoundManager passes `GameState.dice_pool.duplicate()` to DicePool.setup() as a shallow copy, so the Die objects themselves are shared.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-01 | Initial implementation. |
