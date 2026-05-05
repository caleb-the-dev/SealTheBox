# Round Manager
*Orchestrates match phases and round transitions. The heart of the match loop.*

## Location
`scripts/match/round_manager.gd` (class_name RoundManager, instantiated by match.gd)

## Responsibility
Own phase transitions (Roll → Act). Check win/lose after each seal and at start of each round.
Apply power effects at the right moments. Emit signals for match.gd to react to. Does NOT render anything.

## Signals
```gdscript
signal phase_changed(phase: String)   # "roll" or "act"
signal round_ended(round_num: int)
signal match_won(critical: bool)      # true = shut the box; false = player clicked Continue
signal match_lost()
signal tabs_sealed(tabs: Array)       # fired after a successful multi-tab seal (includes bonus-sealed tabs)
signal status_updated(text: String)   # narrative status line for the player
signal threshold_reached()            # fires once per match when remaining sum first hits ≤ win_threshold
```

## Public API
```gdscript
func start_match(box: BoxDefinition) -> void
    # Computes win_threshold = box.win_threshold + PowerManager.get_threshold_bonus()
    #   + GameState.pending_threshold_bonus, then resets pending_threshold_bonus to 0.
    # Sets GameState.current_box, win_threshold, round_limit, tabs from box.
    # Then calls GameState.reset_match(), resets TabBoard and DicePool, calls start_round().

func start_round() -> void
    # Increments GameState.round. If round > round_limit: deduct 1 HP (overtime).
    # Draws a hand. On round 1 only, calls PowerManager.apply_eager(hand) then
    # PowerManager.apply_coffee_break() — Coffee Break must fire after Eager so
    # the Eager-pre-rolled die doesn't consume a charge slot prematurely.
    # Sets phase to "roll".

func commit_roll(dice: Array) -> void
    # Rolls each provided die. Transitions phase to "act".

func attempt_seal(dice: Array, tabs: Array) -> bool
    # Validates dice sum == tab sum and all tabs are unsealed. Seals primary tabs.
    # Calls PowerManager.get_bonus_seals_if_ready() — fires only when bonus_seal counter==target (3);
    #   seals bonus tabs and resets counter. No cascade — called once on primary seals only.
    # Calls PowerManager.apply_tab9_bounty(all_sealed) — grants HP if 9 was sealed.
    # Updates GameState.tabs, emits tabs_sealed(all_sealed), checks win condition.
    # Returns false if invalid.

func use_ability(ability: AbilityData, target_die: Die) -> bool
    # Guards: returns false if match is over, ability.charges <= 0, or phase is "roll".
    # Applies ability effect (reroll_die / greater_N / lesser_N / reroll_all).
    # Decrements ability.charges by 1 on success. Does NOT remove ability from hand.
    # Returns false if unknown ability id.

func end_round() -> void
    # Discards hand, clears GameState.dice_hand.
    # Calls PowerManager.on_round_end() (increments bonus_seal counter, if owned and below target).
    # Emits round_ended(round_num). Calls start_round() OR emits match_lost if HP=0 in overtime.
    # PowerManager.on_match_end() is called before match_lost.emit() on the losing path.

func accept_threshold_win() -> void
    # Called by match.gd when player clicks Continue. Sets _match_over = true,
    # calls PowerManager.on_match_end(), emits match_won(false).
    # Safe to call from any phase — no-ops if already over.

func dev_win_match() -> void
    # Dev shortcut: calls PowerManager.on_match_end(), emits match_won(false). Threshold (not critical).

func dev_critical_win() -> void
    # Dev shortcut: calls PowerManager.on_match_end(), emits match_won(true) (power offer + rotation).

func get_draw_count() -> int
func get_discard_count() -> int
```

## Win Conditions
- **Critical win** (`match_won(true)`): all tabs sealed — fires automatically via `TabBoard.check_critical_win()`
- **Threshold win** (`match_won(false)`): player manually clicks Continue after `threshold_reached` fires. Does NOT auto-end the match — emits `threshold_reached()` once and waits.

## Power Hooks Summary
| Power | Hook location | When |
|-------|--------------|------|
| Lighter Box | start_match() | Every match start — adds count (1 per copy) to threshold |
| Box Shutter (consume) | start_match() | Reads pending_threshold_bonus, resets to 0 |
| Eager | start_round() | Round 1 only — pre-rolls one hand die at max face |
| Coffee Break | start_round() | Round 1 only, AFTER Eager — charges a random below-max ability |
| Bonus Seal (counter tick) | end_round() via on_round_end() | Every round — increments counter toward 3 |
| Bonus Seal (fire) | attempt_seal() via get_bonus_seals_if_ready() | When counter==3 — bonus seals floor(N/2), resets counter |
| Tab 9 Bounty | attempt_seal() | After all seals — grants HP if 9 in sealed set |
| Counter reset (all powers) | accept_threshold_win, _check_win, end_round(loss), dev_win, dev_critical | Every match end via on_match_end() |

## Key Internal State
```gdscript
var _threshold_notified: bool   # true once threshold_reached has been emitted this match; reset in start_match()

# Headless test compatibility:
var GameState: Node: get: return Engine.get_singleton("GameState")
    # Shadows the autoload name so --script tests (which don't start autoloads) work correctly.
    # Zero behavior change in normal Godot runtime — the computed property and the autoload
    # return the same node.
```

## Dependencies
- `GameState` — reads/writes hp, round, round_limit, win_threshold, pending_threshold_bonus, tabs, dice_hand, ability_hand, current_box
- `TabBoard` — seals tabs, checks win condition, validates combinations
- `DicePool` — draws hand, rolls dice, applies modifiers, discards hand
- `PowerManager` — optional (guarded with has_singleton); called in start_match, start_round, attempt_seal

## Gotchas
- **All PowerManager calls use `Engine.has_singleton("PowerManager")` guard.** If PowerManager is not registered (e.g., headless tests without it), power effects are silently skipped. All existing tests still pass.
- **`tabs_sealed` now includes bonus-sealed tabs.** Code that reads this signal must handle more tabs than the dice total would suggest. The `all_sealed` array = primary seals + bonus seals.
- **Bonus seals do not cascade.** `get_bonus_seals_if_ready` is called once with the primary sealed tabs only. Its results are applied to the board but NOT fed back into the method.
- **on_match_end() must fire at every match-end path.** There are 5: accept_threshold_win(), _check_win() (critical), end_round() (loss branch), dev_win_match(), dev_critical_win(). Missing one leaves the bonus_seal counter non-zero going into the next match.
- **Eager applies to the drawn hand, not the pool.** `apply_eager(hand)` is called after `draw_hand()` in round 1. The pre-rolled die is in the hand array; dice in the pool are unaffected.
- **Unrolled dice in roll phase are NOT greyed.** The UI greys unrolled dice only in "act" phase. The Eager pre-rolled die shows its value while other dice remain bright and clickable during roll phase.
- **`use_ability` does NOT remove abilities from the hand.** It decrements `ability.charges`. The ability stays in its slot (visible, greyed out at 0 charges) until the rotation discards it.
- **0-charge abilities are blocked early.** The `charges <= 0` check is the second guard in `use_ability` (before the phase check), so exhausted abilities return false regardless of game phase.
- **`start_match(box)` sets box fields BEFORE calling `reset_match()`** so the fields survive the reset. Change this order and tabs/round_limit will be wiped.
- **Threshold win is NOT automatic.** `_check_win` emits `threshold_reached` (once) and stops. The match stays live. The player clicks Continue → `accept_threshold_win()` → `match_won.emit(false)`.
- **`_threshold_notified` must be reset in `start_match()`** or the Continue button will never appear in subsequent matches.
- Phase only has two states: "roll" and "act". There is no explicit "end" phase.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-05 | Counter hooks added: end_round() now calls PowerManager.on_round_end() before round_ended; all 5 match-end paths (accept_threshold_win, _check_win critical, end_round loss, dev_win_match, dev_critical_win) now call PowerManager.on_match_end() before emitting. attempt_seal() now calls get_bonus_seals_if_ready() (was get_bonus_seals) — only fires when counter==target. |
| 2026-05-05 | start_round(): added PowerManager.apply_coffee_break() call on round 1, immediately after apply_eager(). Ordering is intentional — Coffee Break fires after Eager. Lighter Box hook: threshold bonus now 1×count (was 3×count); this change is in PowerManager, not round_manager, but affects the value start_match() computes. |
| 2026-05-04 | Added dev_critical_win() — emits match_won(true) for testing power offer + Box Shutter flow. |
| 2026-05-04 | start_match(): computes win_threshold from box base + Lighter Box bonus + pending_threshold_bonus (then resets pending to 0). start_round(): calls PowerManager.apply_eager(hand) on round 1 only. attempt_seal(): calls PowerManager.get_bonus_seals() then seal_tabs(bonus), then PowerManager.apply_tab9_bounty(all_sealed); emits tabs_sealed with combined primary+bonus tab list. |
| 2026-05-04 | Removed AP initialization from start_round() and AP spending from commit_roll(). Rolling is now free. |
| 2026-05-04 | use_ability() now decrements ability.charges instead of erasing from ability_hand. Added charges <= 0 guard (second check, before phase check). Added computed GameState property for headless --script test compatibility. |
| 2026-05-04 | Threshold win no longer auto-ends match. Added threshold_reached signal (fires once per match). Added accept_threshold_win() for player-initiated threshold exit. Added _threshold_notified internal flag. |
| 2026-05-02 | start_match() now accepts BoxDefinition and sets GameState box fields before reset. |
| 2026-05-01 | Initial implementation. |
