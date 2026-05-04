# Game State
*Autoload singleton — single source of truth for all mutable match and run state.*

## Location
`scripts/globals/game_state.gd` (Autoload: `GameState`)

## Responsibility
Own all mutable state: HP, AP, tabs, dice pool, ability hand, round number, round limit, win threshold, current box.
Does NOT own game logic — it stores data, never drives phase transitions.

## Constants
```gdscript
const ABILITY_POOL_IDS: Array[String] = [
    "reroll_die", "greater_1", "lesser_1", "greater_2", "lesser_2", "reroll_all"
]
# The 6 abilities eligible for rotation offers and as the run starter.
# Also read by RunManager._do_rotation_offer() via gs.ABILITY_POOL_IDS.
```

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
var ability_hand: Array = [null, null, null]
    # Fixed 3-slot array. null = empty slot.
    # Slot 0 = oldest (next to be discarded on rotation)
    # Slot 2 = newest (where rotation picks land)
    # RunManager shifts slots on each rotation: [0]=old[1], [1]=old[2], [2]=new pick
var current_box: BoxDefinition    # active box for the current match (null before first match)
```

## Public Methods
```gdscript
func reset_run() -> void
    # Resets hp=6, rebuilds dice_pool (3d6+1d4+1d8), calls reset_match(),
    # then always calls _setup_ability_hand() (no is_empty guard).
    # Does NOT set tabs/round_limit/win_threshold — those come from start_match(box).

func reset_match() -> void
    # Resets ap=3, round=0, dice_hand=[]. Resets all dice in pool to value=0/rolled=false.
    # Does NOT touch tabs, round_limit, win_threshold, ability_hand, or dice_pool size.

func reset_run_end() -> void
    # Calls reset_match(). Called by RunManager after rotation pick before starting next match.
    # Does NOT reset ability_hand or dice_pool — rotation already handled the hand shift.

func spend_ap(amount: int) -> bool
    # Deducts AP if sufficient. Returns false (and does not deduct) if ap < amount.
```

## Private Methods
```gdscript
func _setup_dice_pool() -> void
    # Rebuilds dice_pool as [d6, d6, d6, d4, d8] (5 dice total). Called by reset_run().

func _setup_ability_hand() -> void
    # Resets ability_hand = [null, null, null].
    # Picks ONE random id from ABILITY_POOL_IDS, duplicates it from AbilityLibrary,
    # places it in slot 2 only. Slots 0 and 1 remain null.
    # Called every reset_run() — resets the hand fresh each new run.
```

## Dependencies
- `AbilityLibrary` — used by `_setup_ability_hand()` to look up ability definitions
- `BoxDefinition` — type of `current_box`; values set by RoundManager, not GameState itself

## Gotchas
- **`ability_hand` is always exactly 3 elements.** Slots can be null (empty). Never use `ability_hand.append()` or `ability_hand.erase()` — slots must be assigned by index. RunManager owns all mutations post-setup.
- **`reset_match()` does NOT reset tabs, round_limit, or win_threshold.** Those are set by `RoundManager.start_match(box)` before `reset_match()` is called.
- **Charges persist across matches.** An ability with 1 charge left in match 1 enters match 2 with 1 charge. Charges only reset if the ability is discarded and a fresh duplicate is picked in rotation.
- **`ABILITY_POOL_IDS` is the single source of truth for the rotation pool.** RunManager reads it via `gs.ABILITY_POOL_IDS` rather than maintaining its own copy.
- Die objects in `dice_pool` are shared references. `reset_match()` mutates them in place (value=0, rolled=false) rather than replacing them.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Added ABILITY_POOL_IDS const (6 ability ids). Restructured ability_hand from variable Array to fixed 3-slot [null, null, null]. _setup_ability_hand() now picks ONE random ability into slot 2 only (slots 0,1 = null). reset_run() always calls _setup_ability_hand() unconditionally. Added null guard on AbilityLibrary singleton. |
| 2026-05-02 | Added `current_box: BoxDefinition`. Removed hardcoded tabs/round_limit/win_threshold from reset_match(). Moved _setup_ability_hand() out of reset_match() — now called only in reset_run(). Added reset_run_end(). |
| 2026-05-01 | Initial implementation. |
