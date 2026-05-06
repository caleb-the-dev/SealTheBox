# Run Manager
*Orchestrates the infinite match loop. Owns box cycling, end-of-match power offers (critical wins), and mandatory ability rotation.*

## Location
`scripts/run/run_manager.gd` (class_name RunManager, instantiated by match.gd)

## Responsibility
Drive an infinite loop of matches: cycle through boxes in order, emit signals to advance the UI. After every match win (threshold or critical), run a mandatory ability rotation (player picks 1 of 3). Critical wins additionally fire a power offer before rotation. The run ends only when HP reaches 0.

## Signals
```gdscript
signal next_match_ready(box: BoxDefinition)     # emitted at run start and after rotation is resolved
signal show_power_offer(powers: Array)          # emitted only on critical wins; Array of up to 3 PowerData
signal show_rotation_offer(options: Array)      # emitted after every match win (3 AbilityData options)
signal show_die_swap(offered_dice: Array)       # emitted every 5 matches; Array of Die options
signal run_over(match_number: int)              # emitted when player loses (HP = 0) and no Phoenix Down
```

## Public API
```gdscript
var match_number: int                           # 1-based, incremented in handle_match_won()

func start_run() -> void
    # Loads boxes from BoxLibrary, calls gs.reset_run(), emits next_match_ready(_boxes[0]).

func handle_match_won(critical: bool) -> void
    # Always increments match_number first.
    # Always calls PowerManager.apply_survivor() (heals if HP==1).
    # critical=false (threshold win): calls _do_rotation_offer() directly.
    # critical=true  (shut the box):  calls PowerManager.apply_box_shutter(), PowerManager.on_critical_win(), then _do_power_offer().

func handle_match_lost() -> void
    # Checks PowerManager.try_phoenix_down() first.
    #   If true: match_number += 1, starts next match (run continues at HP=1).
    #   If false: emits run_over(match_number).

func handle_power_offer_accepted(power: PowerData) -> void
    # Routes through PowerManager.add_power(power) — appends to owned_powers and initializes
    #   any counter (bonus_seal gets counter initialized to 1 on first acquisition).
    # Then calls _do_rotation_offer().

func handle_power_offer_skipped() -> void
    # No state change. Calls _do_rotation_offer() directly.

func handle_rotation_pick(chosen: AbilityData) -> void
    # Shifts ability_hand slots: [0]=old[1], [1]=old[2], [2]=chosen.
    # Old slot 0 is discarded regardless of remaining charges.
    # Clears _pending_rotation_options, calls gs.reset_run_end().
    # If (match_number - 1) % 5 == 0: emits show_die_swap instead of starting next match.
    # Otherwise: calls _start_next_match() directly.

func handle_die_swap_confirm(offered_die: Die, pool_die: Die) -> void
    # Replaces pool_die in GameState.dice_pool with offered_die. Then starts next match.

func handle_die_swap_skip() -> void
    # No state change. Starts next match.

func dev_skip_rotation() -> void
    # Dev tool: auto-picks _pending_rotation_options[0] if options are available.
    # Used by match.gd "Win Entire Series" to skip the rotation overlay in the dev loop.
```

## Box Cycling
Boxes are loaded from `BoxLibrary.get_ordered()` in `start_run()`. After each match win, the next box is `_boxes[(match_number - 1) % _boxes.size()]`. With 5 boxes: Classic → Low Evens → High Odds → Compressed → Stairs → Classic → ... indefinitely.

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
         → if match 5/10/15…: show_die_swap.emit(offered_dice)
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
- `BoxLibrary` — loads ordered box list at start_run()
- `GameState` — calls reset_run(), reset_run_end(); appends to owned_powers; shifts ability_hand slots
- `AbilityLibrary` — used by _do_rotation_offer() to duplicate ability options
- `PowerLibrary` — used by _do_power_offer() to get random unowned power
- `PowerManager` — called in handle_match_won(true) for Box Shutter; in handle_power_offer_accepted() via add_power(); in handle_match_won() for apply_survivor(); in handle_match_lost() for try_phoenix_down()

## Gotchas
- **`match_number` is incremented inside `handle_match_won()` BEFORE any signal fires.** By the time any listener sees match_number, it already reflects the upcoming match number.
- **Rotation is mandatory.** There is no skip. `handle_rotation_pick` must be called before `next_match_ready` fires.
- **Power offer fires only on critical wins.** Threshold wins go straight to rotation. If no unowned powers remain, the power offer is skipped entirely even on critical wins.
- **Power offer is 1-of-3, not auto-grant.** `show_power_offer` emits an Array of up to 3 PowerData. The player picks one then confirms. `handle_power_offer_accepted` takes the single chosen PowerData.
- **`_do_rotation_offer` picks 3 UNIQUE abilities** (without replacement from ABILITY_POOL_IDS). Duplicates within the offer are impossible. Duplicates with currently-held abilities are allowed and intentional.
- **Signals emit synchronously in Godot 4.** By the time `handle_match_won()` returns for a threshold win with auto-rotation connected, the next match may already be mid-start.
- **`dev_skip_rotation()` only works for threshold wins** via the dev loop — it auto-picks immediately after `dev_win_match()` fires. Critical wins (dev_critical_win) require manual interaction with the power offer and rotation overlays.
- **PowerManager and PowerLibrary calls are guarded** with `Engine.has_singleton()` so tests that don't register these singletons still pass.
- **Phoenix Down is consumed on use.** `try_phoenix_down()` removes one copy from `owned_powers`. The powers panel will reflect this immediately after the next `_refresh_powers_panel()` call.
- **apply_survivor() fires on every win** — before the power offer branch. A player at HP=1 who wins a critical match gets the survivor heal AND then gets to pick a power.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-06 | handle_match_won(true) now calls PowerManager.on_critical_win() after apply_box_shutter() — Tax Collector hook. |
| 2026-05-05 | handle_power_offer_accepted() now routes through PowerManager.add_power() instead of direct gs.owned_powers.append() — ensures counter initialization for Counter-type powers. |
| 2026-05-05 | show_power_offer signal changed from (power: PowerData) to (powers: Array) — now emits up to 3 candidates. _do_power_offer() uses PowerLibrary.get_random_unowned_multiple(owned, 3); skips overlay if result is empty. handle_match_won() now calls PowerManager.apply_survivor() on every win before the critical branch. handle_match_lost() now calls PowerManager.try_phoenix_down() before emitting run_over — if true, increments match_number and starts next match at HP=1. |
| 2026-05-04 | Replaced dice reward with power offer. Removed: show_reward signal, REWARD_DIE_FACES const, handle_reward_picked(), _pick_reward_dice(). Added: show_power_offer(power: PowerData) signal, handle_power_offer_accepted(), handle_power_offer_skipped(), _do_power_offer(). Critical wins now call PowerManager.apply_box_shutter() then _do_power_offer(). |
| 2026-05-04 | Complete redesign of post-match flow. Removed: show_ability_offer signal, handle_ability_offer_result(), _pick_ability_offer(), _current_offered_ability, local ABILITY_POOL_IDS const. Added: show_rotation_offer signal, handle_rotation_pick(), _do_rotation_offer() (unique pick without replacement), dev_skip_rotation(), _pending_rotation_options. Both threshold and critical wins now trigger rotation. |
| 2026-05-04 | Complete redesign: removed RUN_LENGTH / run_won; threshold wins now advance directly without reward; critical wins trigger reward+ability offer then advance; boxes cycle infinitely; REWARD_DIE_FACES trimmed to standard dice only [2,4,6,8,10,12]. |
| 2026-05-02 | Created. Replaced mid-run reward flow with box-sequenced series. |
