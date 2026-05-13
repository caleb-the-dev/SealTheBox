# Tab Board
*Manages the set of unsealed tabs for the current match.*

## Location
`scripts/match/tab_board.gd` (class_name TabBoard, extends RefCounted)

## Responsibility
Track which tabs are sealed/unsealed. Validate seal attempts. Check win conditions.
Support phantom "decoy" tabs (fading_decoys box). Does NOT know about dice — it only knows about tab values.

## Inner Class: TabData
```gdscript
class TabData:
    var value: int = 0
    var is_decoy: bool = false
    func _init(v: int, decoy: bool = false) -> void
```
Internal per-tab record. The `is_decoy` flag marks phantom tabs for fading_decoys. All internal storage uses `Array[TabData]`; public-facing methods still return `Array[int]` for backward compatibility.

## Signals
```gdscript
signal tabs_changed   # emitted by every mutation method; UI hooks to this for live redraw
```

## Public API

### Reset / Initialisation
```gdscript
func reset(tab_range: Array[int]) -> void
    # Initialise with a fresh tab set (all real, no decoys). Called by RoundManager.start_match().

func reset_with_decoys(tab_range: Array[int], decoy_count: int) -> void
    # Like reset, but the trailing decoy_count entries in tab_range are marked is_decoy=true.
    # Real tabs must come first; phantom tabs are appended after them.
    # Used by start_match for fading_decoys: phantoms [3,5,7] are appended to the real tabs.
```

### Mutation API (all emit tabs_changed)
```gdscript
func add_tab(value: int) -> void
    # Append a new real tab. Used by regrowing, revenant_tabs (on return), mitosis (spawn).

func remove_tab(value: int, check_decoy: bool = false) -> void
    # Remove the first tab matching value. Real tabs only by default.
    # Pass check_decoy=true to also target decoys (not used externally as of slice 6).

func change_tab_value(old_value: int, new_value: int) -> void
    # Change the first real tab with old_value to new_value (first match only).

func change_tab_value_at(index: int, new_value: int) -> void
    # Change the tab at a specific index in the internal array. Used by BHV hooks
    # (rising_tide, growing_pillars, clock_tabs, shuffler) — index-safe for duplicates.

func replace_all_tabs(new_values: Array[int]) -> void
    # Replace all tabs with a completely new set (all real, no decoys).
    # Used by moving_targets on_round_start to shift the range each round.

func reveal_and_vanish_decoys() -> Array[int]
    # Remove all decoy tabs. Returns their values for the caller to show a message.
    # Called by fading_decoys at round 3 start.
```

### Legacy Seal API
```gdscript
func seal_tab(value: int) -> void        # delegates to remove_tab(value, false)
func seal_tabs(tabs: Array) -> void      # calls seal_tab per entry
```

### Read API
```gdscript
func get_remaining() -> Array[int]
    # Values of ALL tabs (real + decoy). Used by RoundManager to sync GameState.tabs.

func get_real_remaining() -> Array[int]
    # Values of real (non-decoy) tabs only. Used by BHV hooks and auto-seal abilities.

func get_tab_data() -> Array
    # Returns a duplicate of the internal Array[TabData]. Used by the UI and BHV hooks
    # that need to inspect both value and is_decoy (e.g. rising_tide skips decoys).

func get_sum() -> int
    # Sum of ALL tab values (real + decoy). Legacy — prefer get_real_sum().

func get_real_sum() -> int
    # Sum of real tab values only. Used by check_win and the UI remaining-sum display.

func check_win(threshold: int) -> bool
    # Returns true when get_real_sum() <= threshold.
    # WIN DIRECTION: remaining real-tab sum must be AT OR BELOW the threshold.

func check_critical_win() -> bool
    # Returns true when no real tabs remain (decoys may still be present).

func can_seal_multi(dice_total: int, tabs: Array) -> bool
    # Validates that: (a) all tabs are real and unsealed, (b) their sum equals dice_total.
    # Decoys are excluded — cannot be sealed via normal play.

func has_decoys() -> bool
    # Returns true if any decoy tab remains. Used by fading_decoys round-start hook.
```

## Dependencies
- None — pure logic object. RoundManager creates it and calls its methods.
- `GameState.tabs` is synced from `_tab_board.get_remaining()` by RoundManager after every mutation.

## Gotchas
- **`win_threshold` is a remaining-sum threshold**, not a sealed-sum threshold. `check_win(13)` passes when 13 or fewer points of real tabs remain — NOT when 13+ points have been sealed.
- **`get_remaining()` includes decoys; `get_real_remaining()` excludes them.** BHV hooks that need to avoid phantom tabs must use `get_real_remaining()` or check `td.is_decoy` via `get_tab_data()`.
- **`change_tab_value_at(index, ...)` is preferred over `change_tab_value(old, new)`** for BHV mutations that iterate all tabs — it is index-safe for boxes with duplicate tab values (e.g. Den of Sevens: seven 7s).
- **Tab values are not assumed to be 1–9.** Boxes like high_odds use [3,5,7,9,11]; moving_targets can reach 10; clock_tabs can produce 0 (triggers damage then removal).
- **Decoy tab indices are stable within a round** but reset on replace_all_tabs/reset. Don't cache index-to-decoy mappings across BHV mutations.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-12 | slice-boxes-6: TabData inner class added (value + is_decoy). tabs_changed signal added. New mutation API: add_tab, remove_tab, change_tab_value, change_tab_value_at, replace_all_tabs, reveal_and_vanish_decoys. New read API: get_real_remaining, get_tab_data, get_real_sum, has_decoys. reset_with_decoys added for fading_decoys. check_win and check_critical_win updated to use real-sum / real-tab logic. Legacy seal/read API preserved for backward compatibility. |
| 2026-05-02 | Tab range now set from BoxDefinition via RoundManager.start_match(box), not hardcoded. |
| 2026-05-01 | Initial implementation. |
