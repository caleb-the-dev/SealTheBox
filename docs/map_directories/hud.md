# HUD
*All HUD elements are built in code inside match.gd — there is no separate HUD scene or script.*

## Location
Built in `scripts/match/match.gd` within `_setup_ui()`.

## Responsibility
Display round counter, HP, match progress, active box name, remaining-sum counter, win threshold, AP, draw/discard counts, and a narrative status line. All labels are updated by `_refresh_ui()` after any state change.

## UI Elements (top to bottom)

### Top Bar (HBoxContainer, anchored top)
| Label | Content | Field |
|-------|---------|-------|
| Round label | "Round: X / Y" | `_round_label` |
| HP label | "❤  X" | `_hp_label` |
| Match label | "Match: X" (no denominator — infinite loop) | `_match_label` |
| Box label | "Box: Classic" | `_box_label` |

### Tab Area
| Element | Content | Field |
|---------|---------|-------|
| Remaining sum | "X left" (remaining tab sum, counts down) | `_sealed_total_label` |
| Tab buttons | Dynamic — rebuilt per match from GameState.tabs | `_tab_row` / `_tab_buttons` |
| Win threshold | "≤N to win" | `_threshold_label` |
| Continue button | "Continue →" — hidden until threshold first breached; animates once; player clicks to advance with no reward | `_continue_button` |

### Middle
- `_status_label` — narrative text (phase instructions, seal feedback, rolled total)
- AP badge — "AP: X" (`_ap_label`)

### Bottom Bar
- Draw pile count (`_draw_label`)
- Dice hand buttons (3 × `_dice_buttons`)
- Ability buttons (3 × `_ability_buttons`, type TooltipButton)
- Roll All button / Roll Selected / Commit & End Round (`_roll_all_button`, `_action_button`)
- Discard pile count (`_discard_label`)

## Refresh Pattern
`_refresh_ui()` is called on every phase change, round end, and tab seal. It calls:
- `_refresh_tab_display()` — per button: check if tab still in GameState.tabs, update disabled/modulate
- `_refresh_dice_display()` — show value or "dX" per die
- `_refresh_dice_highlight()` — grey out rolled dice; yellow selected unrolled dice
- `_refresh_ability_display()` — show available abilities or blank slots

## Gotchas
- Remaining-sum counter shows **remaining** tab sum, not sealed sum. It starts high and counts down toward the win threshold.
- `_threshold_label` displays `≤N` not `≥N`. The win condition is `remaining_sum <= threshold`.
- Tab buttons are rebuilt each match via `_rebuild_tab_buttons()` to handle variable tab sets (e.g. high_odds has tab 11).

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Match label changed from "Match: X / 3" to "Match: X". Added _continue_button below threshold label; animates once on threshold breach. Threshold label and continue button now live in a shared VBoxContainer (thresh_col). |
| 2026-05-02 | Added remaining-sum label and threshold label flanking the tab row. Moved threshold out of top bar. Tab buttons are now dynamically rebuilt per match. |
| 2026-05-01 | Initial implementation. All HUD built in match.gd._setup_ui(). |
