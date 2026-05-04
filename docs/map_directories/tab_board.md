# Tab Board
*Manages the set of unsealed tabs for the current match.*

## Location
`scripts/match/tab_board.gd` (class_name TabBoard, extends RefCounted)

## Responsibility
Track which tabs are sealed/unsealed. Validate seal attempts. Check win conditions.
Does NOT know about dice — it only knows about tab values.

## Public API
```gdscript
func reset(tab_range: Array[int]) -> void
    # Initialise with a fresh tab set. Called by RoundManager.start_match().

func seal_tab(value: int) -> void        # seal a single tab
func seal_tabs(tabs: Array) -> void      # seal multiple tabs at once

func get_remaining() -> Array[int]       # returns a duplicate of unsealed tabs

func get_sum() -> int
    # Sum of remaining (unsealed) tabs. Used by check_win().

func check_win(threshold: int) -> bool
    # Returns true when get_sum() <= threshold.
    # WIN DIRECTION: remaining sum must be AT OR BELOW the threshold, not sealed sum above it.

func check_critical_win() -> bool
    # Returns true when no tabs remain (all sealed).

func can_seal_multi(dice_total: int, tabs: Array) -> bool
    # Validates that: (a) all tabs are still unsealed, (b) their sum equals dice_total.
    # Used by attempt_seal() before committing.
```

## Dependencies
- None — pure logic object. RoundManager creates it and calls its methods.
- `GameState.tabs` is written AFTER a seal via `GameState.tabs = _tab_board.get_remaining()`.

## Gotchas
- **win_threshold is a remaining-sum threshold**, not a sealed-sum threshold. `check_win(13)` passes when 13 or fewer points of tabs are left unsealed — NOT when 13+ points have been sealed. The two are mathematically different because the threshold value itself encodes this direction.
- Tab values are not assumed to be 1–9. Boxes like high_odds use [3,5,7,9,11]. Any positive int is valid.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-02 | Tab range now set from BoxDefinition via RoundManager.start_match(box), not hardcoded. |
| 2026-05-01 | Initial implementation. |
