# Game State
*Autoload singleton — single source of truth for all mutable match and run state.*

## Location
`scripts/globals/game_state.gd` (Autoload: `GameState`)

## Responsibility
Own all mutable state: HP, AP, tabs, dice pool, ability hand, round number, round limit, win threshold, current box.
Does NOT own game logic — it stores data, never drives phase transitions.

## Public Fields
```gdscript
var hp: int = 6
var ap: int = 3
var round: int = 0
var round_limit: int = 3          # set per match by RoundManager.start_match(box)
var win_threshold: int = 13       # set per match by RoundManager.start_match(box)
var tabs: Array[int]              # unsealed tabs remaining — set per match from box
var dice_pool: Array              # Array of Die — full pool (deck)
var dice_hand: Array              # Array of Die — currently drawn hand
var ability_hand: Array           # Array of AbilityData — abilities available this series
var current_box: BoxDefinition    # active box for the current match (null before first match)
```

## Public Methods
```gdscript
func reset_run() -> void
    # Resets hp=6, rebuilds dice_pool (3d6+1d4+1d8), calls reset_match(),
    # then calls _setup_ability_hand(). Does NOT set tabs/round_limit/win_threshold —
    # those come from start_match(box).

func reset_match() -> void
    # Resets ap=3, round=0, dice_hand=[]. Resets all dice in pool to value=0/rolled=false.
    # Does NOT touch tabs, round_limit, win_threshold, ability_hand, or dice_pool size.

func reset_run_end() -> void
    # Calls reset_match(). Used after the final match reward is picked to clean up
    # match state before showing the run-won screen. Does NOT reset ability_hand or dice_pool.

func spend_ap(amount: int) -> bool
    # Deducts AP if sufficient. Returns false (and does not deduct) if ap < amount.
```

## Private Methods
```gdscript
func _setup_dice_pool() -> void
    # Rebuilds dice_pool as [d6, d6, d6, d4, d8] (5 dice total). Called by reset_run().

func _setup_ability_hand() -> void
    # Populates ability_hand from AbilityLibrary with ids [reroll_die, greater_1, lesser_1].
    # Called only by reset_run() — NOT by reset_match(). Abilities persist across
    # all matches in a series.
```

## Dependencies
- `AbilityLibrary` — used by `_setup_ability_hand()` to look up ability definitions
- `BoxDefinition` — type of `current_box`; values set by RoundManager, not GameState itself

## Gotchas
- **`reset_match()` does NOT reset tabs, round_limit, or win_threshold.** Those are set by `RoundManager.start_match(box)` before `reset_match()` is called. If you need default tab values in a test, set them manually.
- **Ability hand persists across matches.** `_setup_ability_hand()` is called only in `reset_run()`. An ability used in match 1 is gone for matches 2 and 3. This is intentional game design.
- Die objects in `dice_pool` are shared references. `reset_match()` mutates them in place (value=0, rolled=false) rather than replacing them. Code that holds a reference to a specific Die object will see updated values after reset.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-02 | Added `current_box: BoxDefinition`. Removed hardcoded tabs/round_limit/win_threshold from reset_match(). Moved _setup_ability_hand() out of reset_match() — now called only in reset_run(). Added reset_run_end(). |
| 2026-05-01 | Initial implementation. |
