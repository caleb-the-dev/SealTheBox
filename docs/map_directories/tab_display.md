# Tab Display (UI)
*Renders the 9 tab buttons; handles dice-sum-to-tab assignment.*

## Location
**Not yet created.** `scripts/ui/tab_display.gd` does not exist. Tab display UI is currently built inline in `scripts/match/match.gd`. This file documents the planned standalone script.

## Responsibility
Show tabs 1–9. Dim sealed tabs. Let player select rolled dice (showing running sum) and confirm seal when sum matches a tab.
Activate Seal button only when selected dice sum exactly equals an unsealed tab.

## Public API
```gdscript
func refresh_tabs(remaining: Array[int]) -> void
func set_dice_selection(dice: Array[Die]) -> void   # to compute running sum
func clear_selection() -> void
```

## Dependencies
- `RoundManager` — calls attempt_seal()
- `TabBoard` — reads remaining tabs
- `DicePool` — reads rolled dice values

## Known Issues / TODOs
- [ ] Implement (not yet built)

## Last Updated
2026-05-01
