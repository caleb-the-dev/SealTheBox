# Round Manager
*Orchestrates match phases and round transitions. The heart of the match loop.*

## Location
`scripts/match/round_manager.gd` (class_name RoundManager, instantiated by match.gd)

## Responsibility
Own phase transitions (Roll → Act). Check win/lose after each seal and at start of each round.
Emit signals for match.gd to react to. Does NOT render anything.

## Signals
```gdscript
signal phase_changed(phase: String)   # "roll" or "act"
signal round_ended(round_num: int)
signal match_won(critical: bool)      # true = shut the box; false = player clicked Continue
signal match_lost()
signal tabs_sealed(tabs: Array)       # fired after a successful multi-tab seal
signal status_updated(text: String)   # narrative status line for the player
signal threshold_reached()            # fires once per match when remaining sum first hits ≤ win_threshold
```

## Public API
```gdscript
func start_match(box: BoxDefinition) -> void
    # Sets GameState.current_box, win_threshold, round_limit, tabs from box.
    # Then calls GameState.reset_match(), resets TabBoard and DicePool, calls start_round().

func start_round() -> void
    # Increments GameState.round. If round > round_limit: deduct 1 HP (overtime).
    # Draws a hand, sets phase to "roll".

func commit_roll(dice: Array) -> void
    # Spends 1 AP per die, rolls each. Transitions phase to "act".

func attempt_seal(dice: Array, tabs: Array) -> bool
    # Validates dice sum == tab sum and all tabs are unsealed. Seals tabs,
    # updates GameState.tabs, emits tabs_sealed, checks win condition.
    # Returns false if invalid.

func use_ability(ability: AbilityData, target_die: Die) -> bool
    # Applies ability effect (reroll_die / greater_1 / lesser_1). Erases ability
    # from GameState.ability_hand. Returns false if used in roll phase or unknown id.

func end_round() -> void
    # Discards hand, clears GameState.dice_hand, emits round_ended, calls start_round().

func accept_threshold_win() -> void
    # Called by match.gd when player clicks Continue. Sets _match_over = true,
    # emits match_won(false). Safe to call from any phase — no-ops if already over.

func get_draw_count() -> int
func get_discard_count() -> int
```

## Win Conditions
- **Critical win** (`match_won(true)`): all tabs sealed — fires automatically via `TabBoard.check_critical_win()`
- **Threshold win** (`match_won(false)`): player manually clicks Continue after `threshold_reached` fires. Does NOT auto-end the match — emits `threshold_reached()` once and waits.

## Key Internal State
```gdscript
var _threshold_notified: bool   # true once threshold_reached has been emitted this match; reset in start_match()
```

## Dependencies
- `GameState` — reads/writes hp, ap, round, round_limit, win_threshold, tabs, dice_hand, ability_hand, current_box
- `TabBoard` — seals tabs, checks win condition, validates combinations
- `DicePool` — draws hand, rolls dice, applies modifiers, discards hand

## Gotchas
- **`start_match(box)` sets box fields BEFORE calling `reset_match()`** so the fields survive the reset. Change this order and tabs/round_limit will be wiped.
- **Synchronous signal cascade on critical win:** `attempt_seal` → `_check_win` → `match_won.emit(true)` → match.gd `_on_match_won` → RunManager → `show_reward.emit()` — all inline before `attempt_seal()` returns.
- **Threshold win is NOT automatic.** `_check_win` emits `threshold_reached` (once) and stops. The match stays live. The player clicks Continue → `accept_threshold_win()` → `match_won.emit(false)`.
- **`_threshold_notified` must be reset in `start_match()`** or the Continue button will never appear in subsequent matches.
- Phase only has two states: "roll" and "act". There is no explicit "end" phase — round end is an action, not a state.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-04 | Threshold win no longer auto-ends match. Added threshold_reached signal (fires once per match). Added accept_threshold_win() for player-initiated threshold exit. Added _threshold_notified internal flag. |
| 2026-05-02 | start_match() now accepts BoxDefinition and sets GameState box fields before reset. |
| 2026-05-01 | Initial implementation. |
