# HUD
*All HUD elements are built in code inside match.gd — there is no separate HUD scene or script.*

## Location
Built in `scripts/match/match.gd` within `_setup_ui()`.

## Responsibility
Display round counter, HP, match progress, active box name, remaining-sum counter, win threshold, draw/discard counts, narrative status line, and owned powers list. All labels are updated by `_refresh_ui()` after any state change.

## UI Elements (top to bottom, left to right)

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
| Win threshold | "≤N to win" (boosted by powers if applicable) | `_threshold_label` |
| Continue button | "Continue →" — hidden until threshold first breached; animates once; player clicks to advance | `_continue_button` |

### Middle
- `_status_label` — narrative text (phase instructions, seal feedback, rolled total)

### Bottom Bar
- Draw pile count (`_draw_label`)
- Dice hand buttons (3 × `_dice_buttons`)
- Ability buttons (3 × `_ability_buttons`, type TooltipButton)
- Roll Dice / Commit & End Round (`_action_button`)
- Discard pile count (`_discard_label`)

### Powers Side Panel (right edge, always visible)
- `_powers_panel` — PanelContainer anchored to right edge (offset_left=-175)
- Header label: "── POWERS ──"
- `_powers_vbox` — VBoxContainer; one TooltipButton pill per owned power
- Pills show power name as button text; hover shows description via custom tooltip
- Empty at run start; updated by `_refresh_powers_panel()` whenever powers change

## Refresh Pattern
`_refresh_ui()` is called on every phase change, round end, and tab seal. It calls:
- `_refresh_tab_display()` — per button: check if tab still in GameState.tabs, update disabled/modulate
- `_refresh_dice_display()` — show value or "dX" per die
- `_refresh_dice_highlight()` — grey unrolled dice in act phase only; yellow selected unrolled dice
- `_refresh_ability_display()` — show available abilities or blank slots

`_refresh_powers_panel()` is called separately (not from _refresh_ui): on match win → power accepted, on dev give-power, and on next_match_ready. It rebuilds all power pills from scratch each call.

## Gotchas
- Remaining-sum counter shows **remaining** tab sum, not sealed sum. It starts high and counts down toward the win threshold.
- `_threshold_label` displays `≤N` not `≥N`. The win condition is `remaining_sum <= threshold`.
- Tab buttons are rebuilt each match via `_rebuild_tab_buttons()` to handle variable tab sets.
- **`_refresh_dice_highlight()` greys unrolled dice only in "act" phase**, not roll phase. This is intentional — in roll phase the Eager pre-rolled die should not make other dice look unclickable.
- **Power pills do NOT use `TooltipButton.update_info()`** because that method appends "(once)" to the text (charges display for abilities). Pills manually set text, tooltip_text, _tooltip_title, and _tooltip_body.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Added powers side panel (_powers_panel, _powers_vbox, _refresh_powers_panel()). Fixed _refresh_dice_highlight() to only grey unrolled dice in "act" phase. |
| 2026-05-04 | Removed AP badge (_ap_label) from HUD. |
| 2026-05-04 | Match label changed from "Match: X / 3" to "Match: X". Added _continue_button below threshold label; animates once on threshold breach. |
| 2026-05-02 | Added remaining-sum label and threshold label flanking the tab row. Moved threshold out of top bar. Tab buttons are now dynamically rebuilt per match. |
| 2026-05-01 | Initial implementation. All HUD built in match.gd._setup_ui(). |
