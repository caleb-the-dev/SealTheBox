# Ability Hand (UI)
*Ability slot display and interaction — 3 fixed slots built inside match.gd.*

## Location
`scripts/match/match.gd` — ability buttons are part of the main scene UI, not a separate script.
`_ability_buttons: Array[Button]` (3 TooltipButton nodes in the content_panel ability_col)

## Responsibility
Render the 3 fixed ability slots. Show charges remaining, grey out exhausted abilities, tint slot 0 orange (oldest/next-to-discard). Handle click → target die → call RoundManager.use_ability().
Does NOT resolve ability effects — that's RoundManager.

## Slot Layout
```
Slot 0 (index 0): oldest ability — orange tint, discarded next rotation
Slot 1 (index 1): middle ability
Slot 2 (index 2): newest ability — where rotation picks land
```
All slots can be null (empty). Empty = dimmed, disabled button with no label text.

## Button Display (per slot)
- **Non-null, charges > 0:** `"FlavorName  [N/M]"` as title, description as tooltip body
- **Non-null, slot 0:** orange tint (`Color(1.0, 0.75, 0.3)`), same text format
- **Non-null, charges = 0:** disabled, dark grey (`Color(0.45, 0.45, 0.45)`), still shows `[0/M]`
- **Null slot:** disabled, darker grey (`Color(0.3, 0.3, 0.3)`), no text

## Interaction Flow
1. Player clicks ability button → `_on_ability_pressed(index)`
2. Guard: if `hand[index] == null` → return (no-op)
3. Guard: if `ability.charges <= 0` → show "exhausted" status message, return
4. If `reroll_all`: immediately calls `use_ability(ability, null)`, flashes green
5. Otherwise: sets `_selected_ability` + `_targeting_die = true`, prompts player to click a die
6. Player clicks die → `_on_die_pressed(index)` calls `use_ability(ability, die)`
7. Flash green → `_refresh_ability_display()` (handles grey-out if now at 0 charges)

## Dependencies
- `GameState` — reads `ability_hand` (3-slot Array)
- `RoundManager` — calls `use_ability()`

## Gotchas
- **Ability buttons are `TooltipButton` nodes**, not plain `Button`. The `update_info(title, body)` / `clear_info()` API must be used for text — do not set `.text` directly.
- **`_flash_ability_used` calls `_refresh_ability_display()` after the 0.35s timer**, not `btn.modulate = Color.WHITE`. This ensures the grey-out applies immediately when an ability just hit 0 charges.
- **`_on_die_pressed` does not check the `use_ability` return value** in the targeting path (pre-existing). In normal flow this is safe because the charges guard in `_on_ability_pressed` prevents a 0-charge ability from ever entering targeting mode.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Fully implemented (was Planned). Ability buttons now show charges [N/M], orange tint on slot 0, grey-out at 0 charges, "exhausted" message on click. _on_ability_pressed guards null slot and 0-charge. _flash_ability_used now calls _refresh_ability_display() post-flash. |
| 2026-05-01 | Planned but not built. |
