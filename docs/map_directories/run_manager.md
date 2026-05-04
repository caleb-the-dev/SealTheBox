# Run Manager
*Orchestrates the infinite match loop. Owns box cycling, end-of-match rewards (critical wins), and mandatory ability rotation.*

## Location
`scripts/run/run_manager.gd` (class_name RunManager, instantiated by match.gd)

## Responsibility
Drive an infinite loop of matches: cycle through boxes in order, emit signals to advance the UI. After every match win (threshold or critical), run a mandatory ability rotation (player picks 1 of 3). Critical wins additionally fire a dice reward before rotation. The run ends only when HP reaches 0.

## Constants
```gdscript
const REWARD_DIE_FACES = [2, 4, 6, 8, 10, 12]   # standard dice only
# Note: ABILITY_POOL_IDS lives on GameState, not here. Access via gs.ABILITY_POOL_IDS.
```

## Signals
```gdscript
signal next_match_ready(box: BoxDefinition)     # emitted at run start and after rotation is resolved
signal show_reward(dice_faces: Array)           # emitted only on critical wins (shut the box)
signal show_rotation_offer(options: Array)      # emitted after every match win (3 AbilityData options)
signal run_over(match_number: int)              # emitted when player loses (HP = 0)
```

## Public API
```gdscript
var match_number: int                           # 1-based, incremented in handle_match_won()

func start_run() -> void
    # Loads boxes from BoxLibrary, calls gs.reset_run(), emits next_match_ready(_boxes[0]).

func handle_match_won(critical: bool) -> void
    # Always increments match_number first.
    # critical=false (threshold win): calls _do_rotation_offer() directly.
    # critical=true  (shut the box):  emits show_reward(3 unique random dice faces).

func handle_match_lost() -> void
    # Emits run_over(match_number).

func handle_reward_picked(chosen_face: int) -> void
    # Appends Die(chosen_face) to GameState.dice_pool. Then calls _do_rotation_offer().

func handle_rotation_pick(chosen: AbilityData) -> void
    # Shifts ability_hand slots: [0]=old[1], [1]=old[2], [2]=chosen.
    # Old slot 0 is discarded regardless of remaining charges.
    # Clears _pending_rotation_options, calls gs.reset_run_end(), then _start_next_match().

func dev_skip_rotation() -> void
    # Dev tool: auto-picks _pending_rotation_options[0] if options are available.
    # Used by match.gd "Win Entire Series" to skip the rotation overlay in the dev loop.
```

## Box Cycling
Boxes are loaded from `BoxLibrary.get_ordered()` in `start_run()`. After each match win, the next box is `_boxes[(match_number - 1) % _boxes.size()]`. With 3 boxes: Classic → Low Evens → High Odds → Classic → ... indefinitely.

## Match Win Flow
```
Every match win (threshold or critical):
  handle_match_won(critical)
    → match_number += 1
    → if critical: show_reward.emit(dice_faces)
         → handle_reward_picked(face) → dice_pool gets new die
    → _do_rotation_offer()
         → show_rotation_offer.emit([optionA, optionB, optionC])
    → handle_rotation_pick(chosen)
         → hand shifts: [0]=old[1], [1]=old[2], [2]=chosen
         → gs.reset_run_end()
         → _start_next_match() → next_match_ready.emit(next_box)
```

## Internal State
```gdscript
var _pending_rotation_options: Array   # the 3 AbilityData duplicates offered to the player;
                                       # cleared in handle_rotation_pick(); read by dev_skip_rotation()
```

## Dependencies
- `BoxLibrary` — loads ordered box list at start_run()
- `GameState` — calls reset_run(), reset_run_end(); appends to dice_pool; shifts ability_hand slots
- `AbilityLibrary` — used by _do_rotation_offer() to duplicate ability options

## Gotchas
- **`match_number` is incremented inside `handle_match_won()` BEFORE any signal fires.** By the time any listener sees match_number, it already reflects the upcoming match number.
- **Rotation is mandatory.** There is no skip. `handle_rotation_pick` must be called before `next_match_ready` fires.
- **`_do_rotation_offer` picks 3 UNIQUE abilities** (without replacement from ABILITY_POOL_IDS). Duplicates within the offer are impossible. Duplicates with currently-held abilities are allowed and intentional.
- **Signals emit synchronously in Godot 4.** By the time `handle_match_won()` returns for a threshold win with auto-rotation connected, the next match may already be mid-start.
- **`dev_skip_rotation()` only works for threshold wins** via the dev loop — it auto-picks immediately after `dev_win_match()` fires. It does not handle the critical-win reward step (but `dev_win_match` always emits `false`, so critical wins are never triggered from the dev button).

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Complete redesign of post-match flow. Removed: show_ability_offer signal, handle_ability_offer_result(), _pick_ability_offer(), _current_offered_ability, local ABILITY_POOL_IDS const. Added: show_rotation_offer signal, handle_rotation_pick(), _do_rotation_offer() (unique pick without replacement), dev_skip_rotation(), _pending_rotation_options. Both threshold and critical wins now trigger rotation. |
| 2026-05-04 | Complete redesign: removed RUN_LENGTH / run_won; threshold wins now advance directly without reward; critical wins trigger reward+ability offer then advance; boxes cycle infinitely; REWARD_DIE_FACES trimmed to standard dice only [2,4,6,8,10,12]. |
| 2026-05-02 | Created. Replaced mid-run reward flow with box-sequenced series. |
