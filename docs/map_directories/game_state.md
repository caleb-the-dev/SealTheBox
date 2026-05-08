# Game State
*Autoload singleton — single source of truth for all mutable match and run state.*

## Location
`scripts/globals/game_state.gd` (Autoload: `GameState`)

## Responsibility
Own all mutable state: HP, tabs, dice pool, ability hand, round number, round limit, win threshold, current box, owned powers, pending threshold bonus.
Does NOT own game logic — it stores data, never drives phase transitions.

## Constants
```gdscript
const MAX_HP := 6
# Hard cap on HP. Used by reset_run() (hp = MAX_HP) and by
# RunManager.handle_crossroads_rest() (gs.hp = min(gs.hp + 2, GameState.MAX_HP)).
# Change here to adjust the HP ceiling — no other sites hardcode 6.

const ABILITY_POOL_IDS: Array[String] = [
    "reroll_die", "greater_1", "lesser_1", "greater_2", "lesser_2", "reroll_all",
    "put_down_highest", "auto_seal_lowest",
    "multiply_2", "set_max", "set_min",
    "reroll_lucky", "reroll_unlucky", "drop_die"
]
# The 14 abilities eligible for rotation offers and as the run starter.
# Also read by RunManager._do_rotation_offer() via gs.ABILITY_POOL_IDS.
# Stub-type abilities in the CSV (roll_d4, cosmic_coin, etc.) are NOT in this list
# — they are placeholders for a future dice-type system.
```

## Public Fields
```gdscript
var hp: int = MAX_HP     # starts at 6; capped at MAX_HP by handle_crossroads_rest()
var round: int = 0
var round_limit: int = 3          # set per match by RoundManager.start_match(box)
var win_threshold: int = 13       # set per match by RoundManager.start_match(box); may be boosted by powers
var tabs: Array[int]              # unsealed tabs remaining — set per match from box
var dice_pool: Array              # Array of Die — full pool (deck)
var dice_hand: Array              # Array of Die — currently drawn hand
var ability_hand: Array = [null, null, null]
    # Fixed 3-slot array. null = empty slot.
    # Slot 0 = oldest (next to be discarded on rotation)
    # Slot 2 = newest (where rotation picks land)
    # RunManager shifts slots on each rotation: [0]=old[1], [1]=old[2], [2]=new pick
var current_box: BoxDefinition    # active box for the current match (null before first match)
var owned_powers: Array = []      # Array of PowerData — powers earned during this run
    # Persists across matches (reset_match does NOT clear it).
    # Cleared by reset_run() at the start of each new run.
var power_counters: Dictionary = {}
    # Keyed by power id (e.g. "bonus_seal"). Tracks charge state for Counter-type powers.
    # Initialized to 1 by PowerManager.add_power() on first acquisition of a counter power.
    # Incremented by PowerManager.on_round_end(). Reset to 0 by PowerManager.on_match_end().
    # Cleared entirely by reset_run(). Not touched by reset_match().
var pending_threshold_bonus: int = 0
    # Carries the Box Shutter bonus from the previous match into the next start_match().
    # Consumed and reset to 0 inside RoundManager.start_match().
    # Cleared by reset_run(). Not touched by reset_match().
var case_match_index: int = 1
    # Current match number within the 27-match Case (1..27).
    # Synced by RunManager.handle_match_won(): gs.case_match_index = match_number after increment.
    # Reset to 1 by reset_run(). NOT reset by reset_match().
var run_won: bool = false
    # Set to true by RunManager.handle_match_won() when the completed match was #27.
    # Checked by RunManager._start_next_match() — if true, emits CaseManager.notify_run_won() instead of starting match 28.
    # Reset to false by reset_run().

var act: int:       # derived — read-only computed property
    get:
        # 1 if case_match_index ≤ 9, 2 if ≤ 21, 3 otherwise
var location_index: int:  # same as act — placeholder until entity-specific location names ship (slice 4)
    get: return act
```

## Public Methods
```gdscript
func reset_run() -> void
    # Resets hp=MAX_HP, owned_powers=[], power_counters={}, pending_threshold_bonus=0,
    # case_match_index=1, run_won=false,
    # rebuilds dice_pool (1d4+4d6+2d8 = 7 dice), calls reset_match(),
    # then always calls _setup_ability_hand() (no is_empty guard).
    # Does NOT set tabs/round_limit/win_threshold — those come from start_match(box).

func reset_match() -> void
    # Resets round=0, dice_hand=[]. Resets all dice in pool to value=0/rolled=false.
    # Does NOT touch tabs, round_limit, win_threshold, ability_hand, dice_pool size,
    # owned_powers, or pending_threshold_bonus.

func reset_run_end() -> void
    # Calls reset_match(). Called by RunManager after rotation pick before starting next match.
    # Does NOT reset ability_hand or dice_pool — rotation already handled the hand shift.
```

## Private Methods
```gdscript
func _setup_dice_pool() -> void
    # Rebuilds dice_pool as 1d4 + 4d6 + 2d8 (7 dice total). Called by reset_run().

func _setup_ability_hand() -> void
    # Resets ability_hand = [null, null, null].
    # Picks ONE random id from ABILITY_POOL_IDS, duplicates it from AbilityLibrary,
    # places it in slot 2 only. Slots 0 and 1 remain null.
    # Called every reset_run() — resets the hand fresh each new run.
```

## Dependencies
- `AbilityLibrary` — used by `_setup_ability_hand()` to look up ability definitions
- `BoxDefinition` — type of `current_box`; values set by RoundManager, not GameState itself
- (read by) `CaseManager` — reads `case_match_index` / `run_won` from GameState but does not own them

## Gotchas
- **`owned_powers` persists across matches but NOT across runs.** reset_match() does not clear it; reset_run() does. Do not store ability-level state here — owned_powers holds PowerData objects only.
- **`power_counters` follows the same lifecycle as `owned_powers`.** reset_match() does not clear it (counters survive match transitions within a run); reset_run() clears it entirely. Individual counter values are reset to 0 at match end via PowerManager.on_match_end().
- **`pending_threshold_bonus` is a one-shot buffer.** RunManager.handle_match_won(critical=true) adds to it via PowerManager.apply_box_shutter(). RoundManager.start_match() reads and resets it to 0. It survives between matches in the same run but is cleared by reset_run().
- **`ability_hand` is always exactly 3 elements.** Slots can be null (empty). Never use `ability_hand.append()` or `ability_hand.erase()` — slots must be assigned by index. RunManager owns all mutations post-setup.
- **`reset_match()` does NOT reset tabs, round_limit, or win_threshold.** Those are set by `RoundManager.start_match(box)` before `reset_match()` is called.
- **Charges persist across matches.** An ability with 1 charge left in match 1 enters match 2 with 1 charge. Charges only reset if the ability is discarded and a fresh duplicate is picked in rotation.
- **`ABILITY_POOL_IDS` is the single source of truth for the rotation pool.** RunManager reads it via `gs.ABILITY_POOL_IDS` rather than maintaining its own copy.
- Die objects in `dice_pool` are shared references. `reset_match()` mutates them in place (value=0, rolled=false) rather than replacing them. `dropped` is NOT reset by `reset_match()` — it is reset by `DicePool.discard_hand()` at round end.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | feature/crossroads: added const MAX_HP := 6. hp field initializer and reset_run() both updated to use MAX_HP. |
| 2026-05-07 | feature/case-shape: Added case_match_index (int, default 1), run_won (bool, default false), act (computed getter: 1/2/3), location_index (alias for act). reset_run() now resets both case_match_index=1 and run_won=false. |
| 2026-05-06 | ABILITY_POOL_IDS expanded from 6 to 14 abilities (added put_down_highest, auto_seal_lowest, multiply_2, set_max, set_min, reroll_lucky, reroll_unlucky, drop_die). |
| 2026-05-05 | Added power_counters: Dictionary = {}. reset_run() clears it. reset_match() does not touch it. Individual values reset to 0 at match end via PowerManager.on_match_end(). |
| 2026-05-04 | Added owned_powers: Array = [] and pending_threshold_bonus: int = 0. reset_run() clears both. reset_match() leaves both untouched. _setup_dice_pool() changed from 3d6+1d4+1d8 (5 dice) to 1d4+4d6+2d8 (7 dice). |
| 2026-05-04 | Removed ap variable and spend_ap(). Rolling dice is now free. |
| 2026-05-04 | Added ABILITY_POOL_IDS const (6 ability ids). Restructured ability_hand from variable Array to fixed 3-slot [null, null, null]. _setup_ability_hand() now picks ONE random ability into slot 2 only (slots 0,1 = null). reset_run() always calls _setup_ability_hand() unconditionally. Added null guard on AbilityLibrary singleton. |
| 2026-05-02 | Added `current_box: BoxDefinition`. Removed hardcoded tabs/round_limit/win_threshold from reset_match(). Moved _setup_ability_hand() out of reset_match() — now called only in reset_run(). Added reset_run_end(). |
| 2026-05-01 | Initial implementation. |
