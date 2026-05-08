# Dice Pool
*Manages the deck-like dice pool, drawing hands, rolling, and modifiers.*

## Location
`scripts/match/dice_pool.gd`

## Responsibility
Own the pool (deck) of Die objects, draw a hand of 2 each round, roll selected dice, apply modifiers.
Pool reshuffles (discards returned to draw) when fewer than 2 dice remain.

## Public API
```gdscript
func setup(pool: Array) -> void          # initialise from GameState.dice_pool.duplicate()
func draw_hand() -> Array                # draw up to 2 dice into hand; reshuffles discard into pool when fewer than 2 remain
func roll_die(die: Die) -> void          # randomise die.value, set die.rolled = true
func apply_greater(die: Die, x: int) -> void   # add x to die.value (capped at die.faces)
func apply_lesser(die: Die, x: int) -> void    # subtract x from die.value (floor 1)
func reroll(die: Die) -> void            # re-randomise an already-rolled die
func discard_hand() -> void              # return hand to discard pile; resets value/rolled/dropped
func apply_multiply(die: Die, factor: int) -> void  # multiply die.value by factor; NO ceiling
func apply_set_max(die: Die) -> void     # set die.value = die.faces
func apply_set_min(die: Die) -> void     # set die.value = 1
func reroll_lucky(die: Die) -> int       # reroll; keep whichever result (old or new) is higher
func reroll_unlucky(die: Die) -> int     # reroll; keep whichever result (old or new) is lower
func drop_die(die: Die) -> void          # mark die.dropped = true; dropped dice excluded from totals
func get_draw_count() -> int
func get_discard_count() -> int
```

## Die Object
```gdscript
class_name Die        # scripts/match/die.gd
var faces: int        # max face value (4, 6, 8, 10, 12)
var value: int        # current rolled value (0 = not yet rolled)
var rolled: bool      # true once die.roll() has been called this round
var dropped: bool     # true when Drop Die ability has been used; excludes die from all totals and sealing
```

## Starting Pool
Set by `GameState._setup_dice_pool()`: **1×d4 + 4×d6 + 2×d8 = 7 dice total**.

## Dependencies
- Called by RoundManager. Shares Die object references with GameState.dice_pool and GameState.dice_hand.

## Gotchas
- Die objects are **shared references** between GameState.dice_pool, GameState.dice_hand, and DicePool internals. Mutating a die (rolling, modifier) is immediately visible through all three references. This is intentional — RoundManager passes `GameState.dice_pool.duplicate()` to DicePool.setup() as a shallow copy, so the Die objects themselves are shared.
- **`apply_multiply` has no ceiling.** A d6 rolled 4 multiplied by 2 becomes 8 — exceeding `die.faces`. This is intentional design. `apply_greater` still caps at `die.faces`. Empower/Empower II guard against values already at or above `die.faces` rather than clamping.
- **`dropped` is reset by `discard_hand()`**, not by `reset_match()`. All Die state (value, rolled, dropped) is reset when the round ends.
- **`reroll_lucky` and `reroll_unlucky` do NOT call `power_mgr.on_die_rolled()`** — they are refinements, not new roll events. Contrast with `reroll_die` (plain reroll), which does call `on_die_rolled`.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-06 | Added apply_multiply (no ceiling), apply_set_max, apply_set_min, reroll_lucky, reroll_unlucky, drop_die methods. discard_hand() now resets die.dropped = false. Die class gained var dropped: bool = false. |
| 2026-05-08 | draw_hand() changed from draw-3 to draw-2 (playtest tuning — game was too easy with 3 dice). Reshuffle threshold lowered from < 3 to < 2. |
| 2026-05-01 | Initial implementation. |
