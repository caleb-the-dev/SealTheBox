# Run Manager
*Orchestrates the series of matches that make up a run. Owns box sequencing and end-of-run rewards.*

## Location
`scripts/run/run_manager.gd` (class_name RunManager, instantiated by match.gd)

## Responsibility
Drive the 3-match series: select boxes in order, emit signals to advance the UI, and fire the dice reward after the final win.
Does NOT own match-level logic — that belongs to RoundManager.

## Constants
```gdscript
const RUN_LENGTH: int = 3
const REWARD_DIE_FACES = [2, 3, 4, 5, 6, 7, 8, 10, 12]
```

## Signals
```gdscript
signal next_match_ready(box: BoxDefinition)   # emitted at run start and after each non-final win
signal show_reward(dice_faces: Array)          # emitted only after winning the final match
signal run_won(match_number: int, hp: int)     # emitted after the player picks a reward die
signal run_over(match_number: int)             # emitted when the player loses a match
```

## Public API
```gdscript
var match_number: int                          # 1-based, current match in the series

func start_run() -> void
    # Loads boxes from BoxLibrary, resets GameState, emits next_match_ready(_boxes[0])

func handle_match_won(_critical: bool) -> void
    # If match < RUN_LENGTH: advance match_number, emit next_match_ready(next_box)
    # If match == RUN_LENGTH: emit show_reward (3 random dice faces)

func handle_match_lost() -> void
    # Emits run_over(match_number)

func handle_reward_picked(chosen_face: int) -> void
    # Appends Die(chosen_face) to GameState.dice_pool, calls gs.reset_run_end(),
    # emits run_won(match_number, hp)
```

## Box Sequencing
Boxes are loaded from BoxLibrary.get_ordered() in start_run(). The order matches the CSV row order (classic → low_evens → high_odds). No randomisation yet — fixed sequence.

## Dependencies
- `BoxLibrary` — loads ordered box list at start_run()
- `GameState` — calls reset_run(), reset_run_end(); appends to dice_pool

## Gotchas
- `next_match_ready` carries the BoxDefinition for the upcoming match. Listeners (match.gd) must forward it to RoundManager.start_match(box).
- `run_won` fires AFTER the reward is picked, not immediately after winning match 3. The show_reward → player picks → handle_reward_picked → run_won flow is intentional.
- Signals emit synchronously in Godot 4. By the time handle_match_won() returns, the next match may already be mid-start.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-02 | Created. Replaced mid-run reward flow (advance_to_next_match) with box-sequenced series. Reward now fires only after final match. next_match_ready now carries BoxDefinition. |
