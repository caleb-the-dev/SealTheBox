# Match Scene
*Root scene and controller for the entire game (match loop + run structure).*

## Location
`scenes/match/match.tscn` (root script: `scripts/match/match.gd`)

## Entry Point
This is the game's main scene (`run/main_scene` in project.godot). It starts automatically on launch.

## Scene Tree
```
match.tscn  (Node3D, script: match.gd)
  Camera3D
  DirectionalLight3D
  MeshInstance3D               # flat table plane — placeholder for 3D environment
  CanvasLayer
    Control (root UI)
      top_bar (HBoxContainer)    — Round / HP / Match / Box labels
      tabs_vbox (VBoxContainer)  — tab area
        tabs_lbl                 — "── TABS ──"
        tab_area (HBoxContainer)
          _sealed_total_label    — remaining sum ("X left"), left of tabs
          _tab_row               — dynamic tab buttons (rebuilt per match)
          thresh_col (VBoxContainer)
            _threshold_label     — win condition ("≤N to win")
            _continue_button     — "Continue →", hidden until threshold reached; disabled during seal phase
      _status_label              — narrative status / rolled total
      bottom (HBoxContainer)
        content_panel            — dice hand + abilities
          dice_panel             — 3 die buttons + draw/discard counts + Roll/Commit button
          ability_panel          — 3 ability slots (TooltipButton)
      _power_offer_overlay       — hidden until critical win; shows power name/desc + Accept/Skip
      _rotation_overlay          — hidden until any match win; shows 3 ability pick buttons
      _run_over_overlay          — hidden until run over (HP = 0)
      dev_toggle (Button)        — "DEV" button, top-right corner
      _dev_overlay               — dev menu (see Dev Menu section)
      _dev_power_overlay         — Give Power submenu; populated dynamically on open
      _powers_panel              — always-visible right-side panel listing owned powers
```

## Responsibilities
- Instantiates and owns RoundManager and RunManager
- Registers all 5 singletons (AbilityLibrary, GameState, BoxLibrary, PowerLibrary, PowerManager)
- Builds all UI in code (_setup_ui()) — no UI child nodes in the .tscn
- Wires signals from both managers in _connect_signals()
- Rebuilds tab buttons dynamically per match (_rebuild_tab_buttons()) since tab values vary by box
- Guards end_round() calls after attempt_seal to prevent double-advancing on a winning seal

## Key Signal Wiring
```
RoundManager.phase_changed      → _on_phase_changed         (switches button labels, enables/disables Continue)
RoundManager.round_ended        → _on_round_ended            (clears selections)
RoundManager.match_won          → _on_match_won              (disables input, calls handle_match_won)
RoundManager.match_lost         → _on_match_lost             (disables input, calls handle_match_lost)
RoundManager.tabs_sealed        → _on_tabs_sealed            (clears selections, refreshes UI)
RoundManager.status_updated     → _on_status_updated         (sets status label text)
RoundManager.threshold_reached  → _on_threshold_reached      (shows + animates _continue_button)
RunManager.next_match_ready     → _on_next_match_ready       (resets UI, start_match, rebuilds tabs, refreshes powers panel)
RunManager.show_power_offer     → _on_show_power_offer       (shows power offer overlay)
RunManager.show_rotation_offer  → _on_show_rotation_offer    (shows rotation overlay with 3 picks)
RunManager.run_over             → _on_run_over               (shows over overlay)
```

## Power Offer Overlay Flow
After every **critical win** (shut the box):
1. `_on_show_power_offer(powers: Array)` fires — receives up to 3 PowerData candidates
2. Power offer overlay appears (opaque black `Color(0,0,0,1.0)`)
3. Shows: header "Shut the Box! — Choose a Power", three card buttons (200×140), disabled Confirm button, Skip button
4. Player **clicks a card** → it highlights (yellow tint), Confirm button enables; `_current_power_offer` is set
5. **Confirm** → `_run_manager.handle_power_offer_accepted(_current_power_offer)` → power added → `_refresh_powers_panel()` → rotation follows
6. **Skip** → `_run_manager.handle_power_offer_skipped()` → rotation overlay follows
7. If no unowned powers remain: overlay is skipped entirely, rotation fires immediately

## Rotation Overlay Flow
After every match win (threshold or critical, after power offer resolves):
1. `_on_show_rotation_offer(options: Array)` fires — 3 AbilityData options
2. Rotation overlay appears (opaque black, `Color(0,0,0,1.0)`)
3. Three buttons show: `"FlavorName\n\nDescription\n\n[N charges]"`
4. Player picks one → `_on_rotation_pick_pressed(index)` → `_run_manager.handle_rotation_pick(chosen)`
5. RunManager shifts slots, `next_match_ready` fires, overlay hides in `_on_next_match_ready`

## Powers Side Panel
`_powers_panel` is anchored to the right edge (offset_left=-175, offset_right=-6, top=60, bottom=-310).
- Always visible, even when empty (shows "── POWERS ──" header with no pills)
- Contains `_powers_vbox: VBoxContainer` — rebuilt by `_refresh_powers_panel()`
- `_refresh_powers_panel()` deduplicates owned_powers by id — if you own 2× Lighter Box, one pill appears
- Each pill is a `TooltipButton` showing the power name; hover shows description tooltip
- When count > 1: a small Label badge (font_size=11) appears anchored to the bottom-right corner of the pill showing the stack count. `mouse_filter = MOUSE_FILTER_IGNORE` so it doesn't block the button.
- `_refresh_powers_panel()` called from: `_on_power_confirm_pressed()`, `_on_dev_give_power()`, `_on_next_match_ready()`

## Dev Menu
Open with T key or the "DEV" button (top-right corner). Full-screen opaque overlay.

| Button | Effect |
|--------|--------|
| Win Current Match | `dev_win_match()` → threshold win; rotation overlay appears |
| Shut the Box (Critical Win) | `dev_critical_win()` → power offer + rotation overlays |
| Give Power → | Opens `_dev_power_overlay` with all 8 power buttons |
| Win Entire Series | Loops threshold wins + auto-rotation until stuck; no power offers |
| Restart Run | `start_run()` — resets everything including owned powers |
| Close [T] | Hides overlay |

Both the main dev menu and the Give Power submenu are **scrollable** (mouse wheel + scrollbar). The button list lives inside a `ScrollContainer` with `SIZE_EXPAND_FILL`; title and Close/Back are pinned outside the scroll. Panels expand to 5%–95% of screen height so all buttons are reachable at any resolution.

**Give Power submenu:** Populated dynamically when opened (not at startup). Each power button calls `_on_dev_give_power(power)` → appends to owned_powers and refreshes panel. Multiple copies of the same power can be stacked by clicking repeatedly — the stack badge will reflect the count.

## Tab Buttons
Tab buttons are dynamic. `_rebuild_tab_buttons()` clears `_tab_row` children and creates one Button per value in `GameState.tabs`. Called after `start_match(box)` sets the new tab set. `_refresh_tab_display()` reads each button's text value to determine sealed/active state — no hardcoded 1–9 range.

## Singleton Registration Pattern
```gdscript
if not Engine.has_singleton("PowerLibrary"):
    Engine.register_singleton("PowerLibrary", PowerLibrary)
```
Done in `_ready()` for all 5 autoloads. Necessary because `Engine.get_singleton()` requires explicit registration even when the autoload is declared in project.godot.

## Continue Button Flow
`_continue_button` is hidden at match start. When `threshold_reached` fires:
1. Button becomes visible
2. A tween runs once: scale 1.0 → 1.3 → 1.0 + modulate white → yellow → white (0.4s total)
3. **Button is disabled during "act" phase** (dice have been rolled). It re-enables when the next "roll" phase begins. Player cannot Continue mid-round.

`_on_phase_changed` toggles `_continue_button.disabled` — false on "roll", true on "act".

## Die Face Labels
Each die button has a small child Label (`font_size=11`, anchored to bottom-right corner).
- **Hidden** when die is unrolled (shows "d?" as button text instead)
- **Visible** after rolling: shows "d6", "d4", etc. so player knows the max value for Empower

## Dice Highlight Rules
`_refresh_dice_highlight()` greys unrolled dice **only in "act" phase**. In "roll" phase all unrolled dice show at full brightness — this prevents the Eager pre-rolled die from making other dice look unclickable.

## Ability Slot Display
See `ability_hand.md` for full detail. Summary:
- Slot 0: orange tint (oldest, discarded next rotation)
- Any slot at 0 charges: grey, disabled
- Null slot: darker grey, disabled

## Dependencies
All game systems: RoundManager, RunManager, GameState, AbilityLibrary, BoxLibrary, PowerLibrary, PowerManager, TabBoard (indirect), DicePool (indirect).

## Gotchas
- **All UI is code-built.** Do not add child nodes to match.tscn — add them in `_setup_ui()`.
- **Give Power submenu is populated on open, not at startup.** PowerLibrary.get_all() is called inside `_on_dev_give_power_menu_pressed()` to avoid initialization-order issues during `_setup_ui()`.
- **Power pills use direct field assignment instead of TooltipButton.update_info().** `update_info()` appends "(once)" to the button text (charge display for abilities). Powers have no charges, so pills set `pill.text`, `pill.tooltip_text`, `pill._tooltip_title`, and `pill._tooltip_body` directly.
- **Power offer uses `_current_power_offer` state.** The Confirm button is disabled until a card is clicked. If `_current_power_offer` is null when Confirm fires (shouldn't happen), it no-ops. Don't clear `_power_offer_options` before Confirm is handled.
- **`_on_end_round_pressed` end_round guard:** After `attempt_seal()`, the code checks `_run_manager.match_number != match_before or _match_ended` before calling `end_round()`. Without this guard, the synchronous signal chain would start the next match and then `end_round()` would advance it to round 2 before the player acts.
- **Tab display uses button.text.to_int()** to get tab values. Don't change button text formatting without updating `_refresh_tab_display()`.
- **No run-won overlay.** The run-win overlay and `_on_run_won` handler were removed — there is no "run complete" state in the infinite loop.
- **Dev "Win Entire Series"** calls `dev_win_match()` then `dev_skip_rotation()` in a loop. Always produces threshold wins (not critical), so the power offer overlay never appears in this path.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-05 | Power offer overlay rebuilt as 3-card selection: 3 card buttons (200×140, autowrap), disabled Confirm + Skip; player clicks card to highlight (yellow tint), Confirm enables. _on_show_power_offer now receives Array; _on_power_card_pressed, _on_power_confirm_pressed replace old _on_power_offer_accepted. Powers panel: _refresh_powers_panel() now deduplicates by id and adds a stack count badge (Label, font 11, bottom-right, MOUSE_FILTER_IGNORE) when count > 1. Dev menu: both main and Give Power panels are now scrollable (ScrollContainer + SIZE_EXPAND_FILL inner VBox); panels expanded to 5%–95% viewport height; Give Power now lists all 8 powers. |
| 2026-05-04 | Removed _reward_overlay and all dice reward UI. Added _power_offer_overlay (Accept/Skip, opaque black). Added _powers_panel (right-side always-visible list of owned powers with TooltipButton pills). Added _refresh_powers_panel(). Dev menu: added "Shut the Box (Critical Win)" button → dev_critical_win(), "Give Power →" submenu (_dev_power_overlay, populated on open), "Restart Run" button. Fixed dice highlight: unrolled dice no longer grey during roll phase (Eager fix). Registered PowerLibrary + PowerManager singletons in _ready(). Signal wiring: show_power_offer replaces show_reward. |
| 2026-05-04 | Removed ap_row (AP badge) from scene tree. |
| 2026-05-04 | Added die face labels, rotation overlay, ability charges display, dice panel/ability panel split. |
| 2026-05-02 | Added BoxLibrary singleton, dynamic tab buttons, remaining-sum label, threshold label, end_round guard. |
| 2026-05-01 | Initial implementation. |
