# Run Manager
*Orchestrates the 27-match Case loop. Owns end-of-match power offers (critical wins) and mandatory ability rotation. Box selection delegated to CaseManager.*

## Location
`scripts/run/run_manager.gd` (class_name RunManager, instantiated by match.gd)

## Responsibility
Drive a 27-match Case: ask CaseManager for the next box, emit signals to advance the UI. After every match win (threshold or critical), run a mandatory ability rotation (player picks 1 of 3). Critical wins additionally fire a power offer before rotation. The run ends when HP reaches 0 (lose) OR when match 27 is won (run_won path → CaseManager.run_won signal).

## Signals
```gdscript
signal next_match_ready(box: BoxDefinition)     # emitted at run start and after rotation (or crossroads) is resolved
signal show_power_offer(powers: Array)          # emitted only on critical wins; Array of up to 3 PowerData
signal show_rotation_offer(options: Array)      # emitted after every match win (3 AbilityData options)
signal show_die_swap(offered_dice: Array)       # emitted by handle_crossroads_whetstone() or dev Switch Dice; Array of Die options
signal show_crossroads(after_match: int)        # emitted after matches 9 and 21; after_match is the just-completed match number
signal show_texture_beat(beat: Dictionary)      # emitted when a non-silent texture beat is drawn; beat has "type"+"vignette" or "type"+"event"
signal run_over(match_number: int)              # emitted when player loses (HP = 0) and no Phoenix Down
```

## Public API
```gdscript
var match_number: int                           # 1-based, incremented in handle_match_won()

func start_run() -> void
    # Resets match_number=1, calls gs.reset_run() (resets all GameState including case_match_index=1),
    # calls CaseManager.reset_run() (builds 27-match list), then _start_next_match().

func handle_match_won(critical: bool) -> void
    # Records completed_match = match_number, then increments match_number.
    # Syncs gs.case_match_index = match_number (post-increment value).
    # If completed_match == 27: sets gs.run_won = true (win path — _start_next_match will fire CaseManager.notify_run_won()).
    # Always calls PowerManager.apply_survivor() (heals if HP==1).
    # critical=false (threshold win): calls _do_rotation_offer() directly.
    # critical=true  (shut the box):  calls PowerManager.apply_box_shutter(), PowerManager.on_critical_win(), then _do_power_offer().

func handle_match_lost() -> void
    # Checks PowerManager.try_phoenix_down() first.
    #   If true: match_number += 1, starts next match (run continues at HP=1).
    #   If false: emits run_over(match_number).

func handle_power_offer_accepted(power: PowerData) -> void
    # Routes through PowerManager.add_power(power) — appends to owned_powers and initializes
    #   any counter (bonus_seal gets counter initialized to 0 on first acquisition).
    # Then calls _do_rotation_offer().

func handle_power_offer_skipped() -> void
    # No state change. Calls _do_rotation_offer() directly.

func handle_rotation_pick(chosen: AbilityData) -> void
    # Shifts ability_hand slots: [0]=old[1], [1]=old[2], [2]=chosen.
    # Old slot 0 is discarded regardless of remaining charges.
    # Clears _pending_rotation_options, calls gs.reset_run_end().
    # var completed = match_number - 1 (match_number already post-incremented).
    # If completed == 9 or 21: emits show_crossroads(completed) — crossroads preempts texture.
    # Otherwise: calls _do_texture_beat() — rolls the texture beat then either starts next match (silent) or emits show_texture_beat.

func handle_texture_done() -> void
    # Called by match.gd after the vignette or event overlay is dismissed/resolved.
    # Calls _start_next_match() to begin the next match.

func handle_die_swap_confirm(offered_die: Die, pool_die: Die) -> void
    # Replaces pool_die in GameState.dice_pool with offered_die. Then starts next match.

func handle_die_swap_skip() -> void
    # No state change. Starts next match.

func handle_crossroads_rest() -> void
    # Adds +2 HP capped at GameState.MAX_HP (6). Then starts next match.

func handle_crossroads_whetstone() -> void
    # Emits show_die_swap with all DIE_SWAP_FACES dice offered.
    # _start_next_match() is deferred to handle_die_swap_confirm() or handle_die_swap_skip().

func dev_skip_rotation() -> void
    # Dev tool: auto-picks _pending_rotation_options[0] if options are available.
    # Used by match.gd "Win Entire Series" to skip the rotation overlay in the dev loop.

func dev_skip_crossroads() -> void
    # Dev tool: unconditionally calls handle_crossroads_rest() (auto-picks Rest).
    # Used by match.gd "Win Entire Series" loop to skip the crossroads overlay at act boundaries.

func dev_skip_texture() -> void
    # Dev tool: calls handle_texture_done() directly, skipping whatever overlay would show.
    # Used by match.gd "Win Entire Series" loop — fires after dev_skip_rotation() in the fast-forward path.
```

## Box Selection
Box selection is delegated to CaseManager. `_start_next_match()` calls `CaseManager.get_box_for_match(match_number)`. If `gs.run_won == true` (match 27 just won), `_start_next_match()` calls `CaseManager.notify_run_won()` instead of starting another match. `_boxes` is kept as a fallback Array but is always empty in normal play (CaseManager path covers all cases).

## Crossroads Timing
After completing match 9 (end of Act 1) or match 21 (end of Act 2), `handle_rotation_pick()` emits `show_crossroads(completed)` instead of rolling a texture beat. The player must pick Rest or Whetstone before the next match starts. **Crossroads preempts texture** — these two matches never show a vignette or event.

- **Rest** → `handle_crossroads_rest()` → HP +2 (capped at MAX_HP=6) → `_start_next_match()`
- **Whetstone** → `handle_crossroads_whetstone()` → emits `show_die_swap` → player confirms/skips → `_start_next_match()` from die-swap handlers

The periodic "die swap every 5 matches" was removed. `DIE_SWAP_FACES`, `show_die_swap`, `handle_die_swap_confirm()`, and `handle_die_swap_skip()` are kept because Whetstone reuses them.

## Texture Beat Timing
For all matches EXCEPT crossroads points (9 and 21), `handle_rotation_pick()` calls `_do_texture_beat()` instead of `_start_next_match()` directly.

`_do_texture_beat()`:
1. Calls `TextureRoller.roll("default")` → gets `{type: "silent"}`, `{type: "vignette", ...}`, or `{type: "event", ...}`
2. Silent → calls `_start_next_match()` immediately
3. Vignette or event → emits `show_texture_beat(beat)` → match.gd shows the overlay → player dismisses → match.gd calls `handle_texture_done()` → `_start_next_match()`

Full beat flow (non-crossroads, non-silent):
```
handle_rotation_pick()
  → _do_texture_beat()
       → TextureRoller.roll("default") returns vignette or event
       → show_texture_beat.emit(beat)
            → match.gd shows VignetteOverlay or EventOverlay
            → player clicks / chooses
            → _on_vignette_dismissed() or _on_event_resolved()
                 → _run_manager.handle_texture_done()
                      → _start_next_match()
```

## Match Win / Loss Flow
```
Threshold win (critical=false):
  handle_match_won(false)
    → match_number += 1
    → PowerManager.apply_survivor()        (heals if HP==1)
    → _do_rotation_offer()
         → show_rotation_offer.emit([optionA, optionB, optionC])
    → handle_rotation_pick(chosen)
         → hand shifts, gs.reset_run_end()
         → if completed == 9 or 21: show_crossroads.emit(completed)
              → handle_crossroads_rest()   → hp = min(hp+2, MAX_HP) → _start_next_match()
              OR handle_crossroads_whetstone() → show_die_swap.emit(offered) → (confirm/skip → _start_next_match())
         → else: _start_next_match()

Critical win (critical=true):
  handle_match_won(true)
    → match_number += 1
    → PowerManager.apply_survivor()        (heals if HP==1)
    → PowerManager.apply_box_shutter()     (adds count×2 to pending_threshold_bonus)
    → PowerManager.on_critical_win()       (increments Tax Collector counter; fires +1 HP at 3)
    → _do_power_offer()
         → if unowned powers exist: show_power_offer.emit([p1, p2, p3])
              → handle_power_offer_accepted(power) → PowerManager.add_power(power) → gs.owned_powers.append + counter init
              OR handle_power_offer_skipped() → no change
         → if no unowned powers remain: skip directly to _do_rotation_offer()
    → _do_rotation_offer() → handle_rotation_pick() → (same as threshold win above)

Match lost:
  handle_match_lost()
    → try_phoenix_down():
         true  → match_number += 1, _start_next_match() (HP=1, phoenix_down removed)
         false → run_over.emit(match_number)
```

## Internal State
```gdscript
var _pending_rotation_options: Array   # the 3 AbilityData duplicates offered to the player;
                                       # cleared in handle_rotation_pick(); read by dev_skip_rotation()
```

## Dependencies
- `CaseManager` — calls reset_run() in start_run(); get_box_for_match() in _start_next_match(); notify_run_won() when match 27 is won
- `GameState` — calls reset_run(), reset_run_end(); syncs case_match_index; sets run_won; appends to owned_powers; shifts ability_hand slots
- `AbilityLibrary` — used by _do_rotation_offer() to duplicate ability options
- `PowerLibrary` — used by _do_power_offer() to get random unowned power
- `PowerManager` — called in handle_match_won(true) for Box Shutter; in handle_power_offer_accepted() via add_power(); in handle_match_won() for apply_survivor(); in handle_match_lost() for try_phoenix_down()
- `TextureRoller` — called in _do_texture_beat(); static class, no singleton needed
- `VignetteLibrary` / `EventLibrary` — consulted indirectly via TextureRoller; must be registered singletons

## Gotchas
- **`match_number` is incremented inside `handle_match_won()` BEFORE any signal fires.** By the time any listener sees match_number, it already reflects the upcoming match number.
- **Rotation is mandatory.** There is no skip. `handle_rotation_pick` must be called before `next_match_ready` fires.
- **Power offer fires only on critical wins.** Threshold wins go straight to rotation. If no unowned powers remain, the power offer is skipped entirely even on critical wins.
- **Power offer is 1-of-3, not auto-grant.** `show_power_offer` emits an Array of up to 3 PowerData. The player picks one then confirms. `handle_power_offer_accepted` takes the single chosen PowerData.
- **`_do_rotation_offer` picks 3 UNIQUE abilities** (without replacement from ABILITY_POOL_IDS). Duplicates within the offer are impossible. Duplicates with currently-held abilities are allowed and intentional.
- **Signals emit synchronously in Godot 4.** By the time `handle_match_won()` returns for a threshold win with auto-rotation connected, the next match may already be mid-start.
- **`dev_skip_rotation()` only works for threshold wins** via the dev loop — it auto-picks immediately after `dev_win_match()` fires. Critical wins (dev_critical_win) require manual interaction with the power offer and rotation overlays.
- **`dev_skip_crossroads()` is unconditional** — it always calls `handle_crossroads_rest()`, which calls `_start_next_match()`. In the "Win Entire Series" loop this fires every iteration, but `_start_next_match()` is safe to call when no crossroads is pending (it just emits `next_match_ready` again, which the `_match_ended` guard in the loop catches).
- **`dev_skip_texture()` must fire after `dev_skip_rotation()`** in the dev fast-forward loop. Order: `dev_win_match()` → `dev_skip_rotation()` → `dev_skip_texture()` → `dev_skip_crossroads()`. Omitting `dev_skip_texture()` stalls the run at a vignette/event that never resolves.
- **Texture beat is silently skipped on crossroads matches** — `handle_rotation_pick()` checks `completed == 9 or 21` before calling `_do_texture_beat()`. No texture fires on those two transitions.
- **PowerManager and PowerLibrary calls are guarded** with `Engine.has_singleton()` so tests that don't register these singletons still pass.
- **Phoenix Down is consumed on use.** `try_phoenix_down()` removes one copy from `owned_powers`. The powers panel will reflect this immediately after the next `_refresh_powers_panel()` call.
- **apply_survivor() fires on every win** — before the power offer branch. A player at HP=1 who wins a critical match gets the survivor heal AND then gets to pick a power.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-07 | feature/within-act-texture: added show_texture_beat signal; handle_rotation_pick() now calls _do_texture_beat() instead of _start_next_match() for non-crossroads matches. Added _do_texture_beat() (calls TextureRoller.roll; either starts next match silently or emits show_texture_beat), handle_texture_done() (called by match.gd after overlay dismissal → _start_next_match), dev_skip_texture() (dev loop fast-forward). Updated Crossroads Timing: crossroads preempts texture. Updated dependencies: TextureRoller, VignetteLibrary, EventLibrary. |
| 2026-05-07 | feature/crossroads: added show_crossroads signal; handle_rotation_pick() now emits show_crossroads at completed==9 or 21 instead of the old periodic % 5 die swap. Added handle_crossroads_rest() (+2 HP capped at MAX_HP, then next match), handle_crossroads_whetstone() (emits show_die_swap, delegates _start_next_match to die-swap handlers), dev_skip_crossroads() (auto-Rest for dev loop). Periodic die swap removed. |
| 2026-05-07 | feature/case-shape: start_run() now calls CaseManager.reset_run() and uses _start_next_match() (no more _boxes[0]). handle_match_won() now records completed_match, syncs gs.case_match_index, sets gs.run_won=true when completed_match==27. _start_next_match() checks gs.run_won — if true, calls CaseManager.notify_run_won() and returns instead of starting match 28; otherwise calls CaseManager.get_box_for_match(match_number). |
| 2026-05-06 | handle_match_won(true) now calls PowerManager.on_critical_win() after apply_box_shutter() — Tax Collector hook. |
| 2026-05-05 | handle_power_offer_accepted() now routes through PowerManager.add_power() instead of direct gs.owned_powers.append() — ensures counter initialization for Counter-type powers. |
| 2026-05-05 | show_power_offer signal changed from (power: PowerData) to (powers: Array) — now emits up to 3 candidates. _do_power_offer() uses PowerLibrary.get_random_unowned_multiple(owned, 3); skips overlay if result is empty. handle_match_won() now calls PowerManager.apply_survivor() on every win before the critical branch. handle_match_lost() now calls PowerManager.try_phoenix_down() before emitting run_over — if true, increments match_number and starts next match at HP=1. |
| 2026-05-04 | Replaced dice reward with power offer. Removed: show_reward signal, REWARD_DIE_FACES const, handle_reward_picked(), _pick_reward_dice(). Added: show_power_offer(power: PowerData) signal, handle_power_offer_accepted(), handle_power_offer_skipped(), _do_power_offer(). Critical wins now call PowerManager.apply_box_shutter() then _do_power_offer(). |
| 2026-05-04 | Complete redesign of post-match flow. Removed: show_ability_offer signal, handle_ability_offer_result(), _pick_ability_offer(), _current_offered_ability, local ABILITY_POOL_IDS const. Added: show_rotation_offer signal, handle_rotation_pick(), _do_rotation_offer() (unique pick without replacement), dev_skip_rotation(), _pending_rotation_options. Both threshold and critical wins now trigger rotation. |
| 2026-05-04 | Complete redesign: removed RUN_LENGTH / run_won; threshold wins now advance directly without reward; critical wins trigger reward+ability offer then advance; boxes cycle infinitely; REWARD_DIE_FACES trimmed to standard dice only [2,4,6,8,10,12]. |
| 2026-05-02 | Created. Replaced mid-run reward flow with box-sequenced series. |
