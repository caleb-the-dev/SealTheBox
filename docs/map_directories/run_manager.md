# Run Manager
*Orchestrates the infinite match loop. Owns box cycling, end-of-match rewards (critical wins only), and ability offers.*

## Location
`scripts/run/run_manager.gd` (class_name RunManager, instantiated by match.gd)

## Responsibility
Drive an infinite loop of matches: cycle through boxes in order, emit signals to advance the UI. Fire the dice reward + ability offer only on critical wins (shut the box). The run ends only when HP reaches 0 via match_lost.

## Constants
```gdscript
const REWARD_DIE_FACES = [2, 4, 6, 8, 10, 12]   # standard dice only
const ABILITY_POOL_IDS = [...]                    # 6 ability ids available for offers
```

## Signals
```gdscript
signal next_match_ready(box: BoxDefinition)   # emitted at run start and after every match ends
signal show_reward(dice_faces: Array)          # emitted only on critical wins (shut the box)
signal show_ability_offer(offered: AbilityData) # emitted after reward die is picked
signal run_over(match_number: int)             # emitted when player loses (HP = 0)
```
Note: `run_won` no longer exists — there is no run-won state in the infinite loop.

## Public API
```gdscript
var match_number: int                          # 1-based, increments after each match win

func start_run() -> void
    # Loads boxes from BoxLibrary, resets GameState, emits next_match_ready(_boxes[0]).

func handle_match_won(critical: bool) -> void
    # Always increments match_number.
    # critical=false (threshold win): calls _start_next_match() immediately, no reward.
    # critical=true  (shut the box):  emits show_reward(3 random dice faces).

func handle_match_lost() -> void
    # Emits run_over(match_number).

func handle_reward_picked(chosen_face: int) -> void
    # Appends Die(chosen_face) to GameState.dice_pool. Picks an ability offer.
    # If no ability available: calls reset_run_end() + _start_next_match().
    # Otherwise: emits show_ability_offer.

func handle_ability_offer_result(swap_index: int) -> void
    # swap_index >= 0: swaps that ability_hand slot with the offered ability.
    # swap_index < 0: skips (keeps current hand).
    # Always calls reset_run_end() + _start_next_match() after.
```

## Box Cycling
Boxes are loaded from `BoxLibrary.get_ordered()` in `start_run()`. After each match win, the next box is `_boxes[(match_number - 1) % _boxes.size()]`. With 3 boxes: Classic → Low Evens → High Odds → Classic → ... indefinitely.

## Reward Flow (critical wins only)
```
handle_match_won(true)
  → show_reward.emit(dice_faces)
  → player picks a die → handle_reward_picked(face)
  → show_ability_offer.emit(offered) (or skip to next match if all abilities owned)
  → player swaps or skips → handle_ability_offer_result(index)
  → _start_next_match() → next_match_ready.emit(next_box)
```

## Dependencies
- `BoxLibrary` — loads ordered box list at start_run()
- `GameState` — calls reset_run(), reset_run_end(); appends to dice_pool; reads/writes ability_hand

## Gotchas
- `match_number` is incremented inside `handle_match_won()` **before** `show_reward` or `next_match_ready` fires. By the time any listener sees match_number, it already reflects the upcoming match.
- Signals emit synchronously in Godot 4. By the time `handle_match_won()` returns for a threshold win, the next match may already be mid-start.
- If the player already owns all 6 abilities, `_pick_ability_offer` returns null and the offer step is skipped — `_start_next_match()` fires immediately after reward pick.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Complete redesign: removed RUN_LENGTH / run_won; threshold wins now advance directly without reward; critical wins trigger reward+ability offer then advance; boxes cycle infinitely; REWARD_DIE_FACES trimmed to standard dice only [2,4,6,8,10,12]. |
| 2026-05-02 | Created. Replaced mid-run reward flow with box-sequenced series. Reward fired only after final match. |
