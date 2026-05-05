# Power Manager
*Autoload singleton — applies active power effects at the right game moments.*

## Location
`scripts/run/power_manager.gd` (Autoload: `PowerManager`, no class_name — avoids singleton name conflict)

## Responsibility
Expose one method per power effect. Each method reads `GameState.owned_powers`, counts relevant power copies, and applies the effect. Holds no fields of its own — all effect state lives in GameState. Called directly by RoundManager and RunManager at the appropriate hooks.

## Public API
```gdscript
func count_owned(power_id: String) -> int
    # Returns how many copies of the given power id are in GameState.owned_powers.
    # Stacked powers (e.g. 2x Lighter Box) return 2.

func add_power(power: PowerData) -> void
    # Appends power to GameState.owned_powers.
    # If power.counter_target > 0 AND no counter entry exists yet for power.id:
    #   initializes GameState.power_counters[power.id] = 1.
    # Second and subsequent copies of the same counter power share the existing counter entry.
    # Single entry point for power acquisition — called by both RunManager and match.gd dev menu.

func get_threshold_bonus() -> int
    # Returns count_owned("lighter_box") — 1 per copy owned.
    # Called by RoundManager.start_match() to inflate win_threshold.

func apply_eager(dice: Array) -> void
    # If eager is owned and dice is non-empty: picks one random die, sets value=die.faces, rolled=true.
    # Called by RoundManager.start_round() on round 1 only, passing the drawn hand Array.

func on_round_end() -> void
    # Increments the bonus_seal counter by 1 (up to its target) at the end of each round.
    # No-ops if bonus_seal is not owned, or counter is already at target.
    # Called by RoundManager.end_round() before round_ended is emitted.

func on_match_end() -> void
    # Resets the bonus_seal counter to 0.
    # Called at every match-end path in RoundManager (critical win, threshold win, match lost,
    #   dev_win_match, dev_critical_win).

func get_bonus_seals_if_ready(tab_board: TabBoard, primary_seals: Array) -> Array
    # If bonus_seal is owned AND GameState.power_counters["bonus_seal"] == counter_target (3):
    #   resets counter to 0, then for each tab N in primary_seals where N >= 2,
    #   computes bonus_tab = N / 2 (integer), adds to result if open in tab_board.
    # Returns empty Array if bonus_seal not owned, counter not at target, or no eligible tabs.
    # Does NOT cascade — caller must not feed results back into this method.

func apply_tab9_bounty(all_sealed_tabs: Array) -> void
    # If tab_9_bounty owned AND 9 is in all_sealed_tabs: GameState.hp += count_owned("tab_9_bounty").

func apply_box_shutter() -> void
    # GameState.pending_threshold_bonus += count_owned("box_shutter") * 2.
    # Called by RunManager.handle_match_won(true). The bonus is consumed in the next start_match().

func apply_coffee_break() -> void
    # Picks a random ability in GameState.ability_hand whose charges < max_charges.
    # Adds count_owned("coffee_break") charges to it, capped at max_charges.
    # Does nothing if all abilities are null or already at max charges.
    # Called by RoundManager.start_round() on round 1 only, AFTER apply_eager().

func apply_survivor() -> void
    # If survivor is owned AND GameState.hp == 1: GameState.hp += count_owned("survivor").
    # Called by RunManager.handle_match_won() on every win (threshold or critical).

func try_phoenix_down() -> bool
    # If phoenix_down is owned: removes one copy from GameState.owned_powers,
    #   sets GameState.hp = 1, returns true.
    # Returns false if no phoenix_down owned (run ends normally).
    # Called by RunManager.handle_match_lost() before emitting run_over.
```

## Hook Map
| Method | Called by | When |
|--------|-----------|------|
| add_power() | RunManager.handle_power_offer_accepted(), match.gd _on_dev_give_power() | Whenever a power is acquired |
| get_threshold_bonus() | RoundManager.start_match() | Every match start |
| apply_eager() | RoundManager.start_round() | Round 1 of every match |
| apply_coffee_break() | RoundManager.start_round() | Round 1 of every match, after apply_eager() |
| on_round_end() | RoundManager.end_round() | Every round end (before round_ended signal) |
| get_bonus_seals_if_ready() | RoundManager.attempt_seal() | After each successful primary seal |
| apply_tab9_bounty() | RoundManager.attempt_seal() | After primary + bonus seals resolved |
| on_match_end() | RoundManager (5 paths: accept_threshold_win, _check_win critical, end_round match_lost, dev_win_match, dev_critical_win) | Every match end, before match_won/match_lost emits |
| apply_box_shutter() | RunManager.handle_match_won(true) | Critical wins only |
| apply_survivor() | RunManager.handle_match_won() | Every win (before power/rotation offer) |
| try_phoenix_down() | RunManager.handle_match_lost() | On loss, before run_over emits |

## Gotchas
- **No class_name** — starts with `extends Node` only. Adding `class_name PowerManager` causes a "Class hides an autoload singleton" parse error.
- **No fields.** PowerManager holds no instance fields. All effect state lives in GameState (owned_powers, hp, pending_threshold_bonus, power_counters).
- **Counter starts at 1, not 0.** `add_power()` initializes counter to 1 so Bonus Seal fires on round 3 (not round 4). After firing, `get_bonus_seals_if_ready` resets to 0, then `on_round_end` bumps back to 1 in that same round end — display stays consistent at 1/N.
- **`get_bonus_seals_if_ready` receives a post-seal TabBoard.** Primary seals have already been applied before this is called, so `get_remaining()` reflects state after primary seals but before bonus seals. This prevents bonus-sealing a tab just primary-sealed.
- **Bonus seals do not cascade.** `get_bonus_seals_if_ready` is called once on primary seals only. Its results are applied but NOT fed back into the method.
- **`on_match_end()` must be called at ALL match-end paths.** RoundManager has 5 paths that end a match. Missing one would leave the counter non-zero at the start of the next match.
- **Counter shared across copies.** If the player owns 2× Bonus Seal, there is still only one counter entry — `add_power()` only initializes if the key doesn't exist yet. Both copies share the same 1/3 → 3/3 rhythm.
- **Callers guard with `Engine.has_singleton("PowerManager")`.** If PowerManager is not registered, all power effects are silently skipped. Existing tests without PowerManager registered continue to pass.
- **In headless tests**, register PowerManager manually (no _ready() needed):
  ```gdscript
  var pm = load("res://scripts/run/power_manager.gd").new()
  pm.name = "PowerManager"
  get_root().add_child(pm)
  Engine.register_singleton("PowerManager", pm)
  ```

## Dependencies
- `GameState` — reads owned_powers, power_counters; writes hp, pending_threshold_bonus, power_counters
- `TabBoard` — passed to get_bonus_seals_if_ready() to check remaining tabs
- `PowerLibrary` — read by `_get_counter_target()` to look up a power's counter_target value

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-05 | Added counter infrastructure: add_power() (initializes counter to 1 on first acquisition), on_round_end() (increments bonus_seal counter each round, capped at target), on_match_end() (resets bonus_seal counter to 0), get_bonus_seals_if_ready() (replaces get_bonus_seals — only fires when counter == target, then resets). Counter starts at 1 so Bonus Seal fires on round 3. Fixed post-fire reset: resets to 0, end_round bumps to 1 → display stays at 1/N. |
| 2026-05-05 | Tuned Lighter Box: get_threshold_bonus() now returns count (was count×3). Tuned Box Shutter: apply_box_shutter() now adds count×2 (was count×5). Added apply_coffee_break() — round-1 hook, charges a random below-max ability, capped at max_charges. Added apply_survivor() — match-win hook, heals at exactly 1 HP. Added try_phoenix_down() — match-loss intercept, consumes itself, sets HP=1. |
| 2026-05-04 | Created. |
