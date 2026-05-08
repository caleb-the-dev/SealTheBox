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
      top_bar (HBoxContainer)    — HP label (centered)
      top_left_vbox (VBoxContainer) — anchored top-left
        _match_label             — "Match N / 27"
        _act_label               — "Act N" (grey, smaller)
        _location_label          — entity-themed location name (e.g. "sulfur manor"); falls back to "Location N" if entity not set
        _case_label              — "Case: [entity display_name]" (dimmer grey, font_size=11; empty before first reset_run)
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
      _run_over_overlay          — hidden until run over (HP = 0); "Play Again" button → start_run()
      _run_won_overlay           — hidden until match 27 won; "[display_name] is sealed" (e.g. "the devil is sealed") + "Begin a new case" → start_run()
      _crossroads_overlay        — hidden until act boundary (after match 9 or 21); "Crossroads" + "Choose your path" + Rest/Whetstone buttons
      _vignette_overlay          — hidden until a vignette beat fires; opaque black; one-line text; click anywhere to dismiss
      _event_overlay             — hidden until an event beat fires; opaque black; prompt + two choice buttons; applies effects on pick
      dev_toggle (Button)        — "DEV" button, top-right corner
      _dev_overlay               — dev menu (see Dev Menu section)
      _dev_power_overlay         — Give Power submenu; populated dynamically on open
      _dev_ability_overlay       — Give Ability submenu; populated dynamically on open
      _powers_panel              — always-visible right-side panel listing owned powers
```

## Responsibilities
- Instantiates and owns RoundManager and RunManager
- Registers all 9 singletons (AbilityLibrary, GameState, BoxLibrary, PowerLibrary, PowerManager, CaseManager, VignetteLibrary, EventLibrary, EntityLibrary)
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
RunManager.show_die_swap        → _on_show_die_swap          (shows die swap overlay; also called directly in dev path)
RunManager.show_crossroads      → _on_show_crossroads        (shows crossroads overlay; _after_match param intentionally unused for now)
RunManager.show_texture_beat    → _on_show_texture_beat      (shows vignette or event overlay based on beat["type"])
RunManager.run_over             → _on_run_over               (shows over overlay)
CaseManager.run_won             → _on_run_won                (shows run_won_overlay — wired only if CaseManager singleton is registered)
```

## Texture Beat Overlay Flow
After every non-crossroads match win, following the rotation pick, RunManager rolls the texture beat:
- **Silent** (50%): RunManager calls `_start_next_match()` directly — no overlay appears.
- **Vignette** (30%): `_on_show_texture_beat(beat)` fires.
  1. `_vignette_overlay.setup(vignette_data)` sets text
  2. `_vignette_overlay.visible = true`
  3. `dismissed` signal connected with `CONNECT_ONE_SHOT`
  4. Player clicks anywhere → `_on_vignette_dismissed()` → hides overlay, `_refresh_ui()`, `_run_manager.handle_texture_done()` → next match starts
- **Event** (20%): `_on_show_texture_beat(beat)` fires.
  1. `_event_overlay.setup(event_data)` sets prompt and button labels
  2. `_event_overlay.visible = true`
  3. `resolved` signal connected with `CONNECT_ONE_SHOT`
  4. Player clicks Option A or B → effects applied → `resolved("a"/"b")` emitted → `_on_event_resolved()` → hides overlay, `_refresh_ui()`, `_refresh_powers_panel()`, `_run_manager.handle_texture_done()` → next match starts

Texture overlays are also force-hidden in `_on_next_match_ready()` as a safeguard.

## Power Offer Overlay Flow
After every **critical win** (shut the box):
1. `_on_show_power_offer(powers: Array)` fires — receives up to 3 PowerData candidates
2. Power offer overlay appears (opaque black `Color(0,0,0,1.0)`)
3. Shows: header "Shut the Box! — Choose a Power", three card buttons (200×140), disabled Confirm button, Skip button
4. Player **clicks a card** → it highlights (yellow tint), Confirm button enables; `_current_power_offer` is set
5. **Confirm** → `_run_manager.handle_power_offer_accepted(_current_power_offer)` → power added → `_refresh_powers_panel()` → rotation follows
6. **Skip** → `_run_manager.handle_power_offer_skipped()` → rotation overlay follows
7. If no unowned powers remain: overlay is skipped entirely, rotation fires immediately

## Crossroads Overlay Flow
After completing match 9 (Act 1 end) or match 21 (Act 2 end), immediately following the rotation pick:
1. `_on_show_crossroads(_after_match)` fires — `_after_match` is unused (no per-act copy yet)
2. Crossroads overlay appears (opaque black, `Color(0,0,0,1.0)`, `MOUSE_FILTER_STOP`)
3. Header "Crossroads" (font_size 30), subheader "Choose your path" (font_size 16, grey)
4. Two buttons (200×100 min, font_size 20): **"Rest\n+2 HP"** and **"Whetstone\nswap one die"**
5. No skip/cancel — player must pick one
6. **Rest** → `_on_crossroads_rest_pressed()` → hides overlay → `_run_manager.handle_crossroads_rest()` → HP+2 capped at MAX_HP → next match starts
7. **Whetstone** → `_on_crossroads_whetstone_pressed()` → hides overlay → `_run_manager.handle_crossroads_whetstone()` → die swap overlay appears → confirm/skip → next match starts
8. Overlay also hidden in `_on_next_match_ready()` (safeguard for any programmatic advance)

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
- **Counter powers show `"Name X/Y"` format** — if `power.counter_target > 0`, pill text becomes `"%s %d/%d" % [power.name, current_count, counter_target]`. Current count is read from `GameState.power_counters[power.id]`.
- `_refresh_powers_panel()` called from: `_on_power_confirm_pressed()`, `_on_dev_give_power()`, `_on_next_match_ready()`, `_on_round_ended()` (counter ticks update each round), `_on_action_pressed()` after commit_roll (so Diabolic Pact counter updates immediately after rolling), and after ability rerolls (reroll_die and reroll_all paths in `_on_die_pressed` and `_on_ability_pressed`)

## Dev Menu
Open with T key or the "DEV" button (top-right corner). Full-screen opaque overlay.

| Button | Effect |
|--------|--------|
| Win Current Match | `dev_win_match()` → threshold win; rotation overlay appears |
| Shut the Box (Critical Win) | `dev_critical_win()` → power offer + rotation overlays |
| Give Power → | Opens `_dev_power_overlay` with all 11 power buttons |
| Give Ability → | Opens `_dev_ability_overlay` listing all 14 pool abilities; tapping one fills the first empty slot, or overwrites slot 3 if all are full |
| Switch Dice → | Opens the die swap overlay mid-match in dev mode (see below) |
| Win Entire Series | Loops threshold wins + auto-rotation + auto-texture-skip + auto-crossroads (Rest); terminates at match 27 win (shows run_won_overlay); no power offers |
| Restart Run | `start_run()` — resets everything including owned powers |
| Close [T] | Hides overlay |

**Switch Dice (dev):** Opens the standard die swap overlay (d2/d4/d8/d10/d12 offered). When the player confirms, the swap writes directly to `GameState.dice_pool[_selected_swap_pool_idx]` — no RunManager involvement, no match transition. The die swap overlay's Confirm/Skip handlers check `_dev_die_swap_mode: bool` to distinguish the dev path from the post-match path. Pool index is stored as `_selected_swap_pool_idx: int` at button-press time (not resolved via Array.find() at confirm time — avoids RefCounted identity edge cases). The swap affects the persistent pool; the dice are visible in the next match's draws.

Both the main dev menu and the Give Power submenu are **scrollable** (mouse wheel + scrollbar). The button list lives inside a `ScrollContainer` with `SIZE_EXPAND_FILL`; title and Close/Back are pinned outside the scroll. Panels expand to 5%–95% of screen height so all buttons are reachable at any resolution.

**Give Power submenu:** Populated dynamically when opened (not at startup). Each power button calls `_on_dev_give_power(power)` → appends to owned_powers and refreshes panel. Multiple copies of the same power can be stacked by clicking repeatedly — the stack badge will reflect the count.

## Tab Buttons
Tab buttons are dynamic. `_rebuild_tab_buttons()` clears `_tab_row` children and creates one Button per value in `GameState.tabs`. Called after `start_match(box)` sets the new tab set. `_refresh_tab_display()` reads each button's text value to determine sealed/active state — no hardcoded 1–9 range.

## Singleton Registration Pattern
```gdscript
if not Engine.has_singleton("EntityLibrary"):
    Engine.register_singleton("EntityLibrary", EntityLibrary)
```
Done in `_ready()` for all 9 autoloads (AbilityLibrary, GameState, BoxLibrary, PowerLibrary, PowerManager, CaseManager, VignetteLibrary, EventLibrary, EntityLibrary). Necessary because autoload scripts without `class_name` are not auto-registered as engine singletons — only those with `class_name` get that treatment. `Engine.get_singleton()` requires explicit registration in `_ready()` as a fallback.

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

## Dropped Die Rendering
When a die has `die.dropped == true` (from the Drop Die ability):
- `_refresh_dice_display()`: button text shows `"[X] <value>"`, button is **disabled**
- `_refresh_dice_highlight()`: modulate set to `Color(0.4, 0.4, 0.4)` — same grey as inactive unrolled dice
- `_on_die_pressed()`: early returns immediately if `die.dropped` — cannot be targeted by abilities or selected
- `_on_tab_pressed()` and `_on_end_round_pressed()`: `rolled` filter is `d.rolled and not d.dropped` — dropped dice excluded from total and from dice passed to `attempt_seal()`
- `_update_rolled_total()`: same exclusion filter

## Auto-Seal Ability Firing
`put_down_highest` and `auto_seal_lowest` fire **immediately** when the ability button is clicked — no die targeting step. They are listed alongside `reroll_all` in the immediate-fire check in `_on_ability_pressed()`.

## Dice Highlight Rules
`_refresh_dice_highlight()` greys unrolled dice **only in "act" phase**. In "roll" phase all unrolled dice show at full brightness — this prevents the Eager pre-rolled die from making other dice look unclickable. Dropped dice are also always greyed regardless of phase.

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
- **Run-won overlay title is dynamic.** `_on_run_won()` reads EntityLibrary.get_entity(GameState.entity_id).display_name and sets `_run_won_title_label.text` to "[display_name] is sealed". Falls back to "the entity is sealed" if EntityLibrary is missing or entity_id is empty. `_run_won_title_label` is stored as a field (set once during _setup_ui()) so _on_run_won() can mutate it without rebuilding the overlay.
- **Run-won overlay exists.** `_run_won_overlay` shows after match 27 is won. CaseManager.run_won signal fires AFTER the rotation pick (not immediately on match win) — the normal rotation/power-offer flow completes first, then `_start_next_match()` detects `gs.run_won==true` and calls `notify_run_won()`. The overlay is hidden in `_on_next_match_ready()` (for "Begin a new case" flow).
- **Dev "Win Entire Series"** calls `dev_win_match()`, `dev_skip_rotation()`, and `dev_skip_crossroads()` in a loop. Always produces threshold wins (not critical), so the power offer overlay never appears. `dev_skip_crossroads()` auto-picks Rest unconditionally — it fires on every iteration (not only at boundaries), but this is safe since `handle_crossroads_rest()` calling `_start_next_match()` when no crossroads is pending is harmless.
- **CaseManager must be registered before start_run().** It has no `class_name`, so it's not auto-registered. `_ready()` now explicitly registers it alongside the other autoloads. Omitting this causes a modulo-by-zero error in `_start_next_match()` when the `_boxes` fallback array is empty.
- **VignetteLibrary and EventLibrary must also be registered** in `_ready()`. Without them, TextureRoller falls back to "silent" for all rolls (pools are considered empty). The game will still run, but no vignettes or events will appear.
- **EntityLibrary must also be registered** in `_ready()` (now 9 total). Without it, entity_id is never set, location names show "Location N", the case label is empty, and the run-won overlay shows "the entity is sealed" instead of the entity's name. The game runs correctly but without entity flavor.
- **Texture overlays are instantiated by loading the script directly** (`load("res://scripts/ui/vignette_overlay.gd").new()`) rather than instancing the .tscn. The .tscn files exist for future scene-tree usage but aren't currently loaded. All UI is built in the script's `_ready()`.
- **`_on_show_texture_beat()` uses untyped locals** for vignette_data and event_data. GDScript type hints on VignetteData / EventData cause parse-time errors in headless mode before import. Access only the fields you need (`.text`, `.prompt`, etc.).

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | feature/entity-types: Registered EntityLibrary in _ready() (now 9 total). Added _case_label (font_size=11, dimmer grey) below _location_label in top_left_vbox — shows "Case: [display_name]". _refresh_ui() updated: _location_label now calls CaseManager.get_location_name(GameState.act) instead of "Location N"; _case_label set from EntityLibrary.get_entity(entity_id).display_name (empty if entity not set). _on_run_won() now reads entity display_name and sets _run_won_title_label.text to "[name] is sealed". Added _run_won_title_label: Label field (assigned during _setup_ui()). |
| 2026-05-07 | feature/within-act-texture: Added _vignette_overlay and _event_overlay (both instantiated via `load(...).new()` in _setup_ui()). Connected show_texture_beat signal → _on_show_texture_beat(). Added _on_show_texture_beat(), _on_vignette_dismissed(), _on_event_resolved() handlers. Both overlays force-hidden in _on_next_match_ready(). Registered VignetteLibrary and EventLibrary in _ready() (now 8 total singleton registrations). Dev "Win Entire Series" loop now calls dev_skip_texture() between dev_skip_rotation() and dev_skip_crossroads(). |
| 2026-05-07 | feature/crossroads: added crossroads overlay + Rest/Whetstone handlers; registered CaseManager singleton in _ready() (fixes launch crash). |
| 2026-05-07 | feature/case-shape: added 27-match top-bar labels (_match_label, _act_label, _location_label) and run_won_overlay. |
| 2026-05-04–06 | Rotation overlay, power offer overlay, powers panel, dropped-die UI, auto-seal abilities, dev menu expansions, counter display. |
| 2026-05-01 | Initial build. |
