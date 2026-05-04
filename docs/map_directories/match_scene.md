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
  MeshInstance3D          # flat table plane — placeholder for 3D environment
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
        draw_panel               — draw pile circle
        content_panel            — dice hand + abilities oval
          dice_row               — 3 die buttons (each has a small face label child, e.g. "d6")
          ability_col            — 3 ability slots (TooltipButton)
          btn_row                — Roll All + Roll Selected / Commit & End Round
        discard_panel            — discard pile circle
      _reward_overlay            — hidden until critical win (shut the box)
      _rotation_overlay          — hidden until any match win; shows 3 ability pick buttons
      _run_over_overlay          — hidden until run over (HP = 0)
      dev_toggle (Button)        — "DEV" button, top-right corner
      _dev_overlay               — dev menu (Win Current Match / Win Entire Series)
```

## Responsibilities
- Instantiates and owns RoundManager and RunManager
- Registers all three singletons (AbilityLibrary, GameState, BoxLibrary) via Engine.register_singleton()
- Builds all UI in code (_setup_ui()) — no UI child nodes in the .tscn
- Wires signals from both managers in _connect_signals()
- Rebuilds tab buttons dynamically per match (_rebuild_tab_buttons()) since tab values vary by box
- Guards end_round() calls after attempt_seal to prevent double-advancing on a winning seal

## Key Signal Wiring
```
RoundManager.phase_changed      → _on_phase_changed       (switches button labels, enables/disables Continue)
RoundManager.round_ended        → _on_round_ended          (clears selections)
RoundManager.match_won          → _on_match_won            (disables input, calls handle_match_won)
RoundManager.match_lost         → _on_match_lost           (disables input, calls handle_match_lost)
RoundManager.tabs_sealed        → _on_tabs_sealed          (clears selections, refreshes UI)
RoundManager.status_updated     → _on_status_updated       (sets status label text)
RoundManager.threshold_reached  → _on_threshold_reached    (shows + animates _continue_button)
RunManager.next_match_ready     → _on_next_match_ready     (resets UI, calls start_match(box), rebuilds tabs)
RunManager.show_reward          → _on_show_reward          (shows reward overlay)
RunManager.show_rotation_offer  → _on_show_rotation_offer  (shows rotation overlay with 3 picks)
RunManager.run_over             → _on_run_over             (shows over overlay)
```

## Tab Buttons
Tab buttons are dynamic. `_rebuild_tab_buttons()` clears `_tab_row` children and creates one Button per value in `GameState.tabs`. Called after `start_match(box)` sets the new tab set. `_refresh_tab_display()` reads each button's text value to determine sealed/active state — no hardcoded 1–9 range.

## Singleton Registration Pattern
```gdscript
if not Engine.has_singleton("AbilityLibrary"):
    Engine.register_singleton("AbilityLibrary", AbilityLibrary)
```
Done in `_ready()` for all three autoloads. Necessary because `Engine.get_singleton()` (used by all game scripts) requires explicit registration even when the autoload is declared in project.godot.

## Continue Button Flow
`_continue_button` is hidden at match start. When `threshold_reached` fires:
1. Button becomes visible
2. A tween runs once: scale 1.0 → 1.3 → 1.0 + modulate white → yellow → white (0.4s total)
3. **Button is disabled during "act" phase** (dice have been rolled). It re-enables when the next "roll" phase begins. Player cannot Continue mid-round.
4. Shut-the-box still ends the match automatically (with reward); Continue button is hidden on either exit

`_on_phase_changed` toggles `_continue_button.disabled` — false on "roll", true on "act".

## Rotation Overlay Flow
After every match win (threshold or critical):
1. `_on_show_rotation_offer(options: Array)` fires — 3 AbilityData options
2. Rotation overlay appears (opaque black, `Color(0,0,0,1.0)`)
3. Three buttons show: `"FlavorName\n\nDescription\n\n[N charges]"`
4. Player picks one → `_on_rotation_pick_pressed(index)` → `_run_manager.handle_rotation_pick(chosen)`
5. RunManager shifts slots, `next_match_ready` fires, overlay hides in `_on_next_match_ready`

`_current_rotation_options: Array` stores the 3 options so `_on_rotation_pick_pressed` can pass the chosen AbilityData back.

## Die Face Labels
Each die button has a small child Label (`font_size=11`, anchored to bottom-right corner).
- **Hidden** when die is unrolled (shows "d?" as button text instead)
- **Visible** after rolling: shows "d6", "d4", etc. so player knows the max value for Empower

## Ability Slot Display
See `ability_hand.md` for full detail. Summary:
- Slot 0: orange tint (oldest, discarded next rotation)
- Any slot at 0 charges: grey, disabled
- Null slot: darker grey, disabled

## Dependencies
All game systems: RoundManager, RunManager, GameState, AbilityLibrary, BoxLibrary, TabBoard (indirect), DicePool (indirect).

## Gotchas
- **All UI is code-built.** Do not add child nodes to match.tscn — add them in `_setup_ui()`.
- **`_on_end_round_pressed` end_round guard:** After `attempt_seal()`, the code checks `_run_manager.match_number != match_before or _match_ended` before calling `end_round()`. Without this guard, the synchronous signal chain would start the next match and then `end_round()` would advance it to round 2 before the player acts.
- **Tab display uses button.text.to_int()** to get tab values. Don't change button text formatting without updating `_refresh_tab_display()`.
- **No run-won overlay.** The run-win overlay and `_on_run_won` handler were removed — there is no "run complete" state in the infinite loop.
- **`_on_die_pressed` does not check use_ability return value** in the targeting path. Safe in current flow because ability selection guards prevent a 0-charge ability from entering targeting mode.
- **Dev "Win Entire Series"** calls `dev_win_match()` then `dev_skip_rotation()` in a loop. Always produces threshold wins (not critical), so the reward overlay never appears in this path.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Removed ap_row (AP badge) from scene tree. |
| 2026-05-04 | Added die face labels (small "d6" etc. in bottom-right of each die button after rolling). Added rotation overlay replacing old ability-offer overlay. _on_phase_changed now disables Continue during "act" phase and enables on "roll". Ability buttons now show charges [N/M], orange tint on slot 0, grey-out at 0 charges. Signal wiring: show_rotation_offer replaces show_ability_offer. Dev "Win Entire Series" calls dev_skip_rotation() after each win. |
| 2026-05-04 | Removed run-win overlay and _on_run_won handler. Added _continue_button (threshold exit). Added _on_threshold_reached() with tween animation. Added _on_continue_pressed() → accept_threshold_win(). Match label changed from "Match: X/3" to "Match: X". Reward overlay title changed to "Shut the Box! — Pick a Reward Die". |
| 2026-05-02 | Added BoxLibrary singleton registration. _on_next_match_ready now accepts BoxDefinition and passes to start_match(box). Added _rebuild_tab_buttons() for variable tab sets. Added _sealed_total_label and _threshold_label flanking tab row. Moved threshold display from top bar to tab area. Fixed end_round guard for winning seal. |
| 2026-05-01 | Initial implementation — full match+run UI built in code. |
