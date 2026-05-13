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
      top_bar (HBoxContainer)    — HP display (centered): _hp_label (font 28) + _hp_max_label (font 16, grey) inside an HBoxContainer showing "❤ N /MAX"
      top_left_vbox (VBoxContainer) — anchored top-left (offset_right=240, offset_bottom=120)
        box_name_row (HBoxContainer)
          _box_name_label        — box display name (font 22, white)
          _box_mod_hint          — "[!]" badge (font 18); visible for ROLL (BoxRollModifiers), WIN (BoxWinConditions), DICE (BoxDiceAccess), ENTRY (BoxEntryEffects), and BHV (BoxTabBehavior) boxes; priority: ROLL → WIN → DICE → ENTRY → BHV for tooltip text; hue cycles slowly via _process() delta accumulator; mouse_entered/exited show/hide _mod_tooltip
        _tier_label              — difficulty: "easy" / "medium" / "hard" / "BOSS" (font 12, muted)
        _match_label             — "Match N / 27" (font 16)
        _act_label               — "Act N" (font 12, muted)
      _mod_tooltip (PanelContainer) — floating panel anchored below top_left_vbox (offset_top=130); shown on [!] hover; contains _mod_tooltip_label with modifier description
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
      _run_won_overlay           — hidden until match 27 won; "sealed" title + "Begin a new case" → start_run()
      _crossroads_overlay        — hidden until act boundary (after match 9 or 21); "Crossroads" + "Choose your path" + Rest/Whetstone buttons
      dev_toggle (Button)        — "DEV" button, top-right corner
      _dev_overlay               — dev menu (see Dev Menu section)
      _dev_power_overlay         — Give Power submenu; populated dynamically on open
      _dev_ability_overlay       — Give Ability submenu; populated dynamically on open
      _dev_goto_match_overlay    — Go to Match submenu; 27 match buttons, BOSS tinted orange; restarts run + fast-forwards
      _dev_goto_box_overlay      — Go to Box submenu; all boxes grouped by tier; directly starts match with chosen box
      _powers_panel              — always-visible right-side panel listing owned powers
```

## Responsibilities
- Instantiates and owns RoundManager and RunManager
- Registers all 6 singletons (AbilityLibrary, GameState, BoxLibrary, PowerLibrary, PowerManager, CaseManager)
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
RunManager.run_over             → _on_run_over               (shows over overlay)
CaseManager.run_won             → _on_run_won                (shows run_won_overlay — wired only if CaseManager singleton is registered)
```

## Power Offer Overlay Flow
After every **critical win** (shut the box):
1. `_on_show_power_offer(powers: Array)` fires — receives up to 3 PowerData candidates
2. Power offer overlay appears (opaque black `Color(0,0,0,1.0)`)
3. Shows: header "Shut the Box! — Choose a Power", three card buttons (200×140), disabled Confirm button, Skip button, and a green "Healed 1 HP!" label anchored to the bottom-left corner
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
| Win Entire Series | Loops threshold wins + auto-rotation + auto-crossroads (Rest); terminates at match 27 win (shows run_won_overlay); no power offers |
| Restart Run | `start_run()` — resets everything including owned powers |
| Go to Match → | Opens `_dev_goto_match_overlay`: 27 match buttons (BOSS tinted orange). Selecting one calls `start_run()` then loops `dev_win_match()` + `dev_skip_rotation()` + `dev_skip_crossroads()` until `match_number == target`. Safety cap 30 iterations. |
| Go to Box → | Opens `_dev_goto_box_overlay`: all boxes from BoxLibrary grouped by tier (easy/medium/hard/boss), dynamically populated on open. Selecting one calls `start_match(box)` directly — no run restart, HP and powers preserved. Dev box label shows "Box: [Name] [DEV]". |
| +10 HP (Dev) | `GameState.hp += 10` — uncapped, for stress-testing difficult matches |
| Force Round → (escalating) | Opens sub-panel to force-advance to a specific round on escalating_threshold boxes (useful for testing per-round threshold values) |
| Close [T] | Hides overlay |

**Switch Dice (dev):** Opens the standard die swap overlay (d2/d4/d8/d10/d12 offered). When the player confirms, the swap writes directly to `GameState.dice_pool[_selected_swap_pool_idx]` — no RunManager involvement, no match transition. The die swap overlay's Confirm/Skip handlers check `_dev_die_swap_mode: bool` to distinguish the dev path from the post-match path. Pool index is stored as `_selected_swap_pool_idx: int` at button-press time (not resolved via Array.find() at confirm time — avoids RefCounted identity edge cases). The swap affects the persistent pool; the dice are visible in the next match's draws.

Both the main dev menu and the Give Power submenu are **scrollable** (mouse wheel + scrollbar). The button list lives inside a `ScrollContainer` with `SIZE_EXPAND_FILL`; title and Close/Back are pinned outside the scroll. Panels expand to 5%–95% of screen height so all buttons are reachable at any resolution.

**Give Power submenu:** Populated dynamically when opened (not at startup). Each power button calls `_on_dev_give_power(power)` → appends to owned_powers and refreshes panel. Multiple copies of the same power can be stacked by clicking repeatedly — the stack badge will reflect the count.

## Tab Buttons
Tab buttons are dynamic. `_rebuild_tab_buttons()` clears `_tab_row` children and creates one Button per tab in `GameState.tabs` (by index, not value). Called after `start_match(box)` sets the new tab set.

**Index-based selection and sealing (critical):** `_selected_tabs: Array[int]` stores button *indices*, not tab values. `_sealed_button_indices: Array[int]` tracks which button indices have been sealed this match. This is necessary for boxes with duplicate tab values (e.g. Lopsided Giant: seven 1s) — value-based tracking would highlight or seal all identical tabs together.

- `_on_tab_pressed(idx: int)` — toggles `idx` in `_selected_tabs`; derives displayed value from `_tab_buttons[idx].text`
- `_refresh_tab_display()` — highlights based on `i in _selected_tabs`; dims based on `i in _sealed_button_indices`; no longer reads `GameState.tabs` for display (avoids value-count ambiguity)
- `_on_tabs_sealed(sealed_values: Array)` — in-place greying: if `_bhv_rebuilt_since_select` is false, appends `_selected_tabs` indices to `_sealed_button_indices`; always clears `_selected_tabs` and resets the flag
- `_on_tab_behavior_changed(message: String)` — sets `_bhv_rebuilt_since_select = true`; calls `_rebuild_tab_buttons()` (full rebuild from GameState.tabs); hides `_continue_button` if remaining sum > win_threshold (prevents shuffler early-Continue bug)
- `_on_end_round_pressed()` — converts `_selected_tabs` (indices) to a values array before calling `attempt_seal()`

**BHV rebuild flag:**
`_bhv_rebuilt_since_select: bool` — set true by `_on_tab_behavior_changed`. When a BHV on_seal hook fires (e.g. mitosis) and triggers a full tab rebuild BEFORE `tabs_sealed` fires, the original `_selected_tabs` indices would be stale. The flag tells `_on_tabs_sealed` to skip in-place greying for that action — the rebuild already showed the correct state.

**Dynamic button sizing:** `_rebuild_tab_buttons()` sets size and font based on tab count to prevent overflow:
| Tab count | Button size | Font size | Gap |
|-----------|-------------|-----------|-----|
| ≤ 9 | 62 × 88 | default | 8 |
| 10–12 | 52 × 80 | 18 | 6 |
| 13+ | 36 × 66 | 14 | 4 |
`_tab_row.add_theme_constant_override("separation", sep)` is set dynamically per match. The Long Count (18 tabs) uses the 13+ tier.

## Singleton Registration Pattern
```gdscript
if not Engine.has_singleton("BoxLibrary"):
    Engine.register_singleton("BoxLibrary", BoxLibrary)
```
Done in `_ready()` for all 6 autoloads (AbilityLibrary, GameState, BoxLibrary, PowerLibrary, PowerManager, CaseManager). Necessary because autoload scripts without `class_name` are not auto-registered as engine singletons — only those with `class_name` get that treatment. `Engine.get_singleton()` requires explicit registration in `_ready()` as a fallback.

## Continue Button Flow
`_continue_button` is hidden at match start. When `threshold_reached` fires:
1. Button becomes visible
2. A tween runs once: scale 1.0 → 1.3 → 1.0 + modulate white → yellow → white (0.4s total)
3. **Button is disabled during "act" phase** (dice have been rolled). It re-enables when the next "roll" phase begins. Player cannot Continue mid-round.

`_on_phase_changed` toggles `_continue_button.disabled` — false on "roll", true on "act".

## Die Face Labels and Modifier Tags
Each die button has two small child Labels (`font_size=11`):

**Face label** (bottom-right, `_dice_face_labels[i]`):
- Hidden when die is unrolled
- Visible after rolling: shows "d6", "d4", etc. so player knows the max value for Empower

**Modifier tag label** (bottom-left, `_dice_mod_labels[i]`, orange):
- Hidden when unrolled or when `die.modifier_tag == ""`
- Set by BoxRollModifiers during `commit_roll`:
  - `"1→N"` on exploding_ones dice that exploded (e.g. `"1→7"` means die rolled 1 then exploded to 7)
  - `"×2"` on the highest die when playing high_die_doubles
- Cleared at the start of every `commit_roll` call in RoundManager

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
- Slot 0: orange tint (oldest, discarded next rotation). Tooltip charges text reads `"N/M — lose after this round"` to remind the player this slot is discarded at rotation.
- Any slot at 0 charges: grey, disabled
- Null slot: darker grey, disabled

## Dependencies
All game systems: RoundManager, RunManager, GameState, AbilityLibrary, BoxLibrary, PowerLibrary, PowerManager, BoxRollModifiers, TabBoard (indirect), DicePool (indirect).

## Gotchas
- **All UI is code-built.** Do not add child nodes to match.tscn — add them in `_setup_ui()`.
- **Give Power submenu is populated on open, not at startup.** PowerLibrary.get_all() is called inside `_on_dev_give_power_menu_pressed()` to avoid initialization-order issues during `_setup_ui()`.
- **Power pills use direct field assignment instead of TooltipButton.update_info().** `update_info()` appends "(once)" to the button text (charge display for abilities). Powers have no charges, so pills set `pill.text`, `pill.tooltip_text`, `pill._tooltip_title`, and `pill._tooltip_body` directly.
- **Power offer uses `_current_power_offer` state.** The Confirm button is disabled until a card is clicked. If `_current_power_offer` is null when Confirm fires (shouldn't happen), it no-ops. Don't clear `_power_offer_options` before Confirm is handled.
- **`_on_end_round_pressed` end_round guard:** After `attempt_seal()`, the code checks `_run_manager.match_number != match_before or _match_ended` before calling `end_round()`. Without this guard, the synchronous signal chain would start the next match and then `end_round()` would advance it to round 2 before the player acts.
- **Tab selection is index-based, not value-based.** `_selected_tabs` holds button indices; `_sealed_button_indices` holds sealed button indices. Do not compare tab values directly in selection or display logic — duplicate-value boxes (Lopsided Giant, Cluster of Twos, Den of Sevens) will break. `_on_end_round_pressed()` converts indices → values only at the point of calling `attempt_seal()`.
- **Tab display uses button.text.to_int()** to get tab values for summing and sealing only. Don't change button text formatting without updating `_on_tab_pressed()` and `_on_end_round_pressed()`.
- **Run-won overlay title is static.** `_on_run_won()` sets `_run_won_title_label.text = "sealed"`. The `_run_won_title_label` field is stored during `_setup_ui()` for this mutation.
- **Run-won overlay exists.** `_run_won_overlay` shows after match 27 is won. CaseManager.run_won signal fires AFTER the rotation pick (not immediately on match win) — the normal rotation/power-offer flow completes first, then `_start_next_match()` detects `gs.run_won==true` and calls `notify_run_won()`. The overlay is hidden in `_on_next_match_ready()` (for "Begin a new case" flow).
- **Dev "Win Entire Series"** calls `dev_win_match()`, `dev_skip_rotation()`, and `dev_skip_crossroads()` in a loop. Always produces threshold wins (not critical), so the power offer overlay never appears. No texture-skip step needed — RunManager goes directly to `_start_next_match()` for non-crossroads matches now. `dev_skip_crossroads()` fires on every iteration but calling `handle_crossroads_rest()` when no crossroads is pending is harmless.
- **CaseManager must be registered before start_run().** It has no `class_name`, so it's not auto-registered. `_ready()` now explicitly registers it alongside the other autoloads. Omitting this causes a modulo-by-zero error in `_start_next_match()` when the `_boxes` fallback array is empty.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-12 | slice-boxes-6 playtest: [!] badge priority extended to ENTRY (BoxEntryEffects) and BHV (BoxTabBehavior) — full chain now ROLL → WIN → DICE → ENTRY → BHV. Dev menu: "Force Storm Box →", "Force Cleanse Box →", "Force Borrowed Time →" buttons added. Greyed sealed tabs restored: _on_tabs_sealed switched back to in-place index approach (was calling _rebuild_tab_buttons, which lost greyed state). _bhv_rebuilt_since_select flag added to handle mitosis edge case (BHV rebuild fires before tabs_sealed). _on_tab_behavior_changed now hides _continue_button when remaining sum > threshold (fixes shuffler early-Continue bug). |
| 2026-05-12 | slice-boxes-6: tab_behavior_changed signal wired — _on_tab_behavior_changed handler added. |
| 2026-05-09 | slice-boxes-4 playtest: [!] badge extended to DICE boxes (BoxDiceAccess.has_description()); tooltip routing is now ROLL → WIN → DICE priority. Dev menu: removed "Force Bounty Box →" and "Reset Marquee Set" buttons (bounty_box dropped). "Force Round → (escalating)" button retained. Tab alignment fix: _sealed_total_label now right-aligned, _threshold_label now left-aligned; _update_tabs_header_widths() now uses correct per-tier button widths (62/52/36). |
| 2026-05-09 | slice-boxes-3: [!] badge extended to WIN boxes (BoxWinConditions.has_override()). Badge hue now cycles slowly via _process(delta) using a `_mod_hint_time: float` accumulator — `Color.from_hsv(fmod(time*0.15, 1.0), 0.85, 1.0)`. Tooltip text routes to BoxWinConditions.get_description() for WIN boxes (was ROLL-only). New member var: _mod_hint_time. |
| 2026-05-08 | slice-boxes-2: Top-left HUD reordered — box name (font 22) now first and prominent, then difficulty (font 12), match (font 16), act (font 12). [!] badge (_box_mod_hint) added next to box name for ROLL boxes; hover shows floating _mod_tooltip panel (not Godot built-in tooltip). _dice_mod_labels array added — each die button gains a bottom-left orange label showing modifier_tag (e.g. "1→7", "×2"). _on_tab_pressed(), _on_end_round_pressed(), _update_rolled_total() now route through _round_manager.get_roll_total() instead of raw die sum — fixes doubling_box validation bug where tab selection used unmodified total. New member vars: _box_name_label, _box_mod_hint, _mod_tooltip, _mod_tooltip_label, _dice_mod_labels. New handlers: _on_mod_hint_entered(), _on_mod_hint_exited(). |
| 2026-05-08 | Slice 1 playtest session. Tab selection changed from value-based to index-based (fixes multi-select bug on duplicate-value tabs). `_sealed_button_indices: Array[int]` added. `_rebuild_tab_buttons()` now binds button index, resets sealed list, and applies dynamic sizing (3 tiers by tab count). Dev menu: "Go to Match →" (restarts run + fast-forwards) and "Go to Box →" (restarts match in place with chosen box) added with full sub-overlays. |
| 2026-05-08 | UI polish: HP display now shows "❤ N /MAX" — _hp_label (font 28) + _hp_max_label (font 16, grey) in an HBoxContainer. Power offer overlay gains green "Healed 1 HP!" label in bottom-left (_heal_notice_label). Slot-0 ability tooltip charges text appends "— lose after this round". |
| 2026-05-08 | Playtest refactor: removed _vignette_overlay, _event_overlay, _case_label, and all associated vars/handlers. Replaced _location_label with _tier_label (shows "easy"/"medium"/"hard"/"BOSS"). Removed show_texture_beat signal wiring. Removed EntityLibrary, VignetteLibrary, EventLibrary from singleton registrations (now 6 total). Run-won overlay text simplified to "sealed". Added "+10 HP (Dev)" button to dev menu. Fixed overlay layout bug: vignette and event overlays were previously loaded from external scripts (zero-size layout); rebuilt inline (this became moot when both were removed). |
| 2026-05-07 | feature/crossroads: added crossroads overlay + Rest/Whetstone handlers; registered CaseManager singleton in _ready() (fixes launch crash). |
| 2026-05-07 | feature/case-shape: added 27-match top-bar labels (_match_label, _act_label, _location_label) and run_won_overlay. |
| 2026-05-04–06 | Rotation overlay, power offer overlay, powers panel, dropped-die UI, auto-seal abilities, dev menu expansions, counter display. |
| 2026-05-01 | Initial build. |
