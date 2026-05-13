# Box Tab Behavior
*Static class — dispatches BHV-axis (Tab Behavior Over Time) hooks for tab-behavior boxes.*

## Location
`scripts/match/box_tab_behavior.gd` (class_name BoxTabBehavior, extends RefCounted)

## Responsibility
Implement per-round tab mutations for boxes whose tabs change value or count over time (BHV axis). Provides four hook points called by RoundManager. All functions are static; no state lives here — per-match state is stored on TabBoard or via GameState.set_meta/get_meta.

## Boxes Handled
| box_id | Trigger | Effect |
|--------|---------|--------|
| regrowing | on_round_start (round > 1) | Lowest sealed tab returns to the board |
| shuffler | on_round_start | All real tabs re-randomised to 1–9 |
| moving_targets | on_round_start | Tabs replaced: R1→1-7, R2→2-8, R3→3-9, R4+→4-10 |
| fading_decoys | on_round_start (round 3) | Decoy tabs vanish; uses gs.set_meta for message handoff |
| rising_tide | on_round_end | Every real tab +1 (ceiling 13) |
| growing_pillars | on_round_end | Every real tab +1 (ceiling 13) |
| clock_tabs | on_round_end | Lowest real tab −2; if ≤ 0 → remove and deal 1 HP damage |
| revenant_tabs | on_round_end_no_seal | Lowest sealed tab returns (only if player sealed nothing) |
| mitosis | on_seal | Sealed tab ≥ 6 spawns floor(value/2) new tab; recursive up to depth 5 |
| fading_decoys | on_seal | Hook exists; decoy interception happens upstream in RoundManager |

## Constants
```gdscript
const RISING_TIDE_CEILING := 13   # max tab value for rising_tide / growing_pillars
const MITOSIS_MAX_DEPTH := 5      # recursion cap for mitosis on_seal
```

## Public API
```gdscript
static func has_behavior(box_id: String) -> bool
    # Returns true if this box has any BHV hooks registered.
    # RoundManager calls this before firing any hook.

static func get_description(box_id: String) -> String
    # Returns a short rule string for the [!] badge tooltip in match.gd.
    # Used as the lowest-priority fallback in the badge wiring chain
    # (after ROLL → WIN → DICE → ENTRY).

static func on_round_start(box_id: String, tab_board: TabBoard, gs: Node) -> void
    # Called by RoundManager.start_round() before drawing dice.
    # Active boxes: regrowing, shuffler, moving_targets, fading_decoys.

static func on_round_end(box_id: String, tab_board: TabBoard, gs: Node) -> String
    # Called by RoundManager.end_round() after discarding the hand.
    # Returns a status message (or "" if nothing happened).
    # Active boxes: rising_tide, growing_pillars, clock_tabs.

static func on_round_end_no_seal(box_id: String, tab_board: TabBoard, gs: Node) -> String
    # Called by RoundManager.end_round() only when _sealed_this_round == false.
    # Active boxes: revenant_tabs.

static func on_seal(box_id: String, sealed_values: Array, tab_board: TabBoard, gs: Node, depth: int = 0) -> String
    # Called by RoundManager.attempt_seal() (and put_down_highest / auto_seal_lowest)
    # after primary seals are committed. sealed_values = all sealed this action (incl. bonus).
    # Active boxes: mitosis, fading_decoys.
    # depth: mitosis recursion guard (caller passes 0).
```

## Key Internal Methods
```gdscript
static func _regrowing_on_round_start(tab_board, gs)
    # Computes sealed = original_tabs minus get_real_remaining(); returns smallest.

static func _shuffler_on_round_start(tab_board, _gs)
    # Iterates get_tab_data(); for each real entry: calls change_tab_value_at(i, randi_range(1,9)).

static func _moving_targets_on_round_start(tab_board, gs)
    # base = clamp(round-1, 0, 3); builds [base+1 .. base+7] (7 tabs); calls replace_all_tabs.

static func _fading_decoys_on_round_start(tab_board, gs)
    # At round 3 only: calls reveal_and_vanish_decoys; stores result via gs.set_meta("bhv_fading_decoys_revealed").
    # RoundManager reads and clears the meta key to emit the status message.

static func _clock_tabs_on_round_end(tab_board, gs)
    # Finds lowest real tab by index; subtracts 2. If new_val <= 0: remove_tab + gs.hp -= 1.

static func _mitosis_on_seal(sealed_values, tab_board, _gs, depth)
    # For each value >= 6: add_tab(floor(value/2)); recursion depth guards at MITOSIS_MAX_DEPTH.

static func _revenant_tabs_on_round_end_no_seal(tab_board, gs)
    # Same diff logic as regrowing: original_tabs minus get_real_remaining(); adds smallest.
```

## Dependencies
- `TabBoard` — all mutations route through TabBoard's API (add_tab, remove_tab, change_tab_value_at, replace_all_tabs, reveal_and_vanish_decoys, get_tab_data, get_real_remaining)
- `GameState` — reads gs.round, gs.current_box.tabs (for original-tab reference), gs.hp (clock_tabs), set_meta/get_meta (fading_decoys message handoff)

## Gotchas
- **GameState.tabs must be synced BEFORE tab_behavior_changed emits.** RoundManager updates `GameState.tabs = _tab_board.get_remaining()` before each `tab_behavior_changed.emit()` call so `_rebuild_tab_buttons()` in match.gd sees correct state. Breaking this ordering causes stale tab displays (the Rising Tide / Revenant Tabs bugs from the original slice).
- **on_seal fires BEFORE tabs_sealed.** RoundManager calls on_seal, then emits tabs_sealed. Match.gd's `_on_tab_behavior_changed` fires mid-action and triggers a full tab button rebuild (`_rebuild_tab_buttons`). The `_bhv_rebuilt_since_select` flag in match.gd prevents the stale `_selected_tabs` indices from being re-applied as sealed after this rebuild.
- **fading_decoys message handoff via gs.set_meta.** The round-3 decoy reveal message cannot be returned from on_round_start (void return). RoundManager reads the meta key immediately after calling on_round_start and clears it. If you add another BHV box that needs a round-start message, use the same set_meta pattern OR change the hook to return String.
- **moving_targets replaces ALL tabs each round.** This means sealed tabs from R1 are gone. The full rebuild in match.gd's `_on_tab_behavior_changed` handles the display correctly — sealed button indices from R1 are cleared and R2 starts fresh.
- **regrowing and revenant_tabs compute "sealed" tabs by diffing original vs remaining.** They rely on `gs.current_box.tabs` as the source of truth for what started on the board. If a box mutates its own tabs (e.g. clock_tabs removes a tab), regrowing's diff becomes incorrect — but these two boxes are never combined on the same box. Per the slice-7 spec: TOPO × BHV combinations are explicitly deferred.
- **clock_tabs takes damage before round_ended, not overtime.** The −2 logic fires in on_round_end (called before round_ended emits). If HP hits 0 from clock_tabs, the match-lost check in end_round still fires correctly because hp is already ≤ 0 when it checks.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-12 | slice-boxes-6 playtest tuning: get_description() added (used by match.gd [!] badge — BHV is lowest-priority after ROLL→WIN→DICE→ENTRY). clock_tabs changed from random-tab -1 to lowest-tab -2. moving_targets changed from 6 tabs to 7 tabs (ranges now 1-7/2-8/3-9/4-10 per round). |
| 2026-05-12 | slice-boxes-6: BoxTabBehavior static class created. 9 BHV boxes implemented. Wired into RoundManager (start_round, end_round, attempt_seal, use_ability auto-seal paths). tab_behavior_changed signal added to RoundManager. |
