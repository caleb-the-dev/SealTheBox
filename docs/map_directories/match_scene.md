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
            _continue_button     — "Continue →", hidden until threshold is first reached
      _status_label              — narrative status / rolled total
      ap_row                     — AP badge (centered)
      bottom (HBoxContainer)
        draw_panel               — draw pile circle
        content_panel            — dice hand + abilities oval
          dice_row               — 3 die buttons
          ability_col            — 3 ability buttons (TooltipButton)
          btn_row                — Roll All + Roll Selected / Commit & End Round
        discard_panel            — discard pile circle
      _reward_overlay            — hidden until critical win (shut the box)
      _run_over_overlay          — hidden until run over (HP = 0)
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
RoundManager.phase_changed      → _on_phase_changed     (switches button labels, refreshes UI)
RoundManager.round_ended        → _on_round_ended        (clears selections)
RoundManager.match_won          → _on_match_won          (disables input, calls handle_match_won)
RoundManager.match_lost         → _on_match_lost         (disables input, calls handle_match_lost)
RoundManager.tabs_sealed        → _on_tabs_sealed        (clears selections, refreshes UI)
RoundManager.status_updated     → _on_status_updated     (sets status label text)
RoundManager.threshold_reached  → _on_threshold_reached  (shows + animates _continue_button)
RunManager.next_match_ready     → _on_next_match_ready   (resets UI, calls start_match(box), rebuilds tabs)
RunManager.show_reward          → _on_show_reward        (shows reward overlay)
RunManager.run_over             → _on_run_over           (shows over overlay)
```

## Tab Buttons
Tab buttons are dynamic. `_rebuild_tab_buttons()` clears `_tab_row` children and creates one Button per value in `GameState.tabs`. Called after `start_match(box)` sets the new tab set. `_refresh_tab_display()` reads each button's text value to determine sealed/active state — no hardcoded 1–9 range.

## Singleton Registration Pattern
```gdscript
if not Engine.has_singleton("AbilityLibrary"):
    Engine.register_singleton("AbilityLibrary", AbilityLibrary)
```
Done in `_ready()` for all three autoloads. Necessary because `Engine.get_singleton()` (used by all game scripts) requires explicit registration even when the autoload is declared in project.godot.

## Dependencies
All game systems: RoundManager, RunManager, GameState, AbilityLibrary, BoxLibrary, TabBoard (indirect), DicePool (indirect).

## Continue Button Flow
`_continue_button` is hidden at match start. When `threshold_reached` fires:
1. Button becomes visible
2. A tween runs once: scale 1.0 → 1.3 → 1.0 + modulate white → yellow → white (0.4s total)
3. Button stays visible; player can click it anytime to end the match (no reward)
4. Shut-the-box still ends the match automatically (with reward); Continue button is hidden on either exit

`_on_threshold_reached()` uses `_continue_button.size / 2.0` as `pivot_offset` so the scale animation is centered. The `pivot_offset` is read at signal time — by then at least one round has passed and the layout is settled.

## Gotchas
- **All UI is code-built.** Do not add child nodes to match.tscn — add them in `_setup_ui()`.
- **`_on_end_round_pressed` end_round guard:** After `attempt_seal()`, the code checks `_run_manager.match_number != match_before or _match_ended` before calling `end_round()`. Without this guard, the synchronous signal chain would start the next match and then `end_round()` would advance it to round 2 before the player acts.
- **Tab display uses button.text.to_int()** to get tab values. Don't change button text formatting without updating `_refresh_tab_display()`.
- **No run-won overlay.** The run-win overlay and `_on_run_won` handler were removed — there is no "run complete" state in the infinite loop. `_run_over_overlay` (HP = 0) is the only end-state overlay remaining.
- **Match label shows "Match: N"** (no denominator). `RunManager.RUN_LENGTH` no longer exists.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Removed run-win overlay and _on_run_won handler. Added _continue_button (threshold exit). Added _on_threshold_reached() with tween animation. Added _on_continue_pressed() → accept_threshold_win(). Match label changed from "Match: X/3" to "Match: X". Reward overlay title changed to "Shut the Box! — Pick a Reward Die". |
| 2026-05-02 | Added BoxLibrary singleton registration. _on_next_match_ready now accepts BoxDefinition and passes to start_match(box). Added _rebuild_tab_buttons() for variable tab sets. Added _sealed_total_label and _threshold_label flanking tab row. Moved threshold display from top bar to tab area. Fixed end_round guard for winning seal. |
| 2026-05-01 | Initial implementation — full match+run UI built in code. |
