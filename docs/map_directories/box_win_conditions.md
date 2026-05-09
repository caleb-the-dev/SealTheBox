# Box Win Conditions
*Static registry of per-box win-condition overrides. Mirrors the BoxRollModifiers pattern.*

## Location
`scripts/match/box_win_conditions.gd` (class_name BoxWinConditions, extends RefCounted — static class, never instantiated)

## Responsibility
Map box_ids to Callable win-condition overrides. Each callable receives `(tab_board, current_round, base_threshold)` and returns a Variant that tells RoundManager how to interpret a win check.

Also owns round-limit overrides and human-readable descriptions for the [!] badge tooltip.

## Callable Contract
```
func condition(tab_board: TabBoard, current_round: int, base_threshold: int) -> Variant

Return value:
  null   → no override; caller uses default check (remaining sum ≤ base_threshold)
  true   → win (treat as critical win: heal +1 HP, power offer, rotation)
  false  → not yet (suppress threshold-win even if remaining sum ≤ base_threshold)
  int    → use this value as the effective threshold instead of base_threshold
```

## Public API
```gdscript
static func has_override(box_id: String) -> bool
    # Returns true if a win-condition override is registered for this box_id.

static func evaluate(box_id: String, tab_board: TabBoard, current_round: int, base_threshold: int) -> Variant
    # Calls the registered callable for box_id and returns its result.
    # Returns null if box_id has no override.

static func get_description(box_id: String) -> String
    # Returns a one-line human-readable description of the win condition, or "" if none.
    # Used by match.gd to populate the [!] hover tooltip for WIN boxes.

static func get_round_limit(box_id: String, base_limit: int) -> int
    # Returns the round_limit override for box_id, or base_limit if no override exists.
    # Called from RoundManager.start_match() instead of reading box.round_limit directly.

static func get_escalating_threshold(current_round: int) -> int
    # Helper: returns the win threshold for escalating_threshold at the given round.
    # R1=25, R2=20, R3=15, R4+=5. Used for display/testing.
```

## Win Condition Registry (2 active overrides)
| box_id | Returns | Rule |
|--------|---------|------|
| crit_only | bool (true/false) | true if all tabs sealed; false otherwise (suppresses threshold-win path entirely) |
| escalating_threshold | int | Per-round threshold: R1=25, R2=20, R3=15, R4+=5 |

## Round Limit Overrides
| box_id | Override | Reason |
|--------|---------|--------|
| crit_only | 5 | Base formula gives 4; extra round compensates for harder win condition |
| single_die | 3 | Base formula gives 2; playtest found 2 rounds too tight with only 1 die |
| quick_seal | 1 | Plain box with small tab set; 1-round design creates time pressure without a punishing mechanic |

## Key Internal State
```gdscript
static var _registry: Dictionary          # box_id → Callable, built once
static var _initialized: bool             # guards _ensure_init()
static var _descriptions: Dictionary      # box_id → human-readable tooltip string
static var _round_limit_overrides: Dictionary  # box_id → int
```

`_initialized` is a static bool — the registry is built only once per Godot session. Persists across headless test functions within the same run (same as BoxRollModifiers).

## Dependencies
- `TabBoard` — `evaluate()` passes the tab_board to each callable; `_cond_crit_only` calls `tab_board.check_critical_win()`

## Depended On By
- `RoundManager` — calls `has_override()`, `evaluate()`, `get_round_limit()` from `start_match()`, `start_round()`, and `_check_win()`
- `match.gd` — calls `has_override()` and `get_description()` for the [!] badge and cycling-color tooltip

## Gotchas
- **`evaluate()` return type matters.** `RoundManager._check_win()` distinguishes `bool true`, `bool false`, and `int` via GDScript 4's `is bool` / `is int` type checks. Do NOT compare int to bool with `==` — GDScript 4 raises a type error. Always type-check before comparing.
- **crit_only returns `false` (not `null`) when tabs remain.** This is intentional — `false` actively suppresses the threshold-win path. `null` would fall through to the default check and allow a threshold win. These two are not equivalent.
- **escalating_threshold returns an `int`, not `null`.** The int return causes RoundManager to use it as the effective threshold, AND `_apply_win_condition_threshold_update()` in `start_round()` writes it to `GameState.win_threshold` each round so the UI label stays in sync. If the callable returned `null`, the label would show the stale CSV value.
- **`get_round_limit` must be called with the box's computed base_limit, not a hardcoded value.** `BoxDefinition.round_limit` is a computed property (`ceili(tab_sum/15.0)+1`). RoundManager passes this computed value so the override is relative to the actual formula result.
- **No CSV column for win_condition.** Win conditions are hardcoded in the registry, not data-driven. This matches BoxRollModifiers; both move to CSV-driven at ~20 entries.
- **CSV `win_threshold` for escalating_threshold stores the R1 value (25).** RoundManager's `start_match()` writes this to `GameState.win_threshold` initially; `_apply_win_condition_threshold_update()` overwrites it each round with the callable's int return.

## Recent Changes
| Date | Change |
|------|--------|
| 2026-05-09 | slice-boxes-4 playtest: round_limit overrides added for single_die (3) and quick_seal (1). No win-condition callable changes. |
| 2026-05-09 | Playtest tuning: crit_only round_limit override 4→5 (extra round added); escalating_threshold curve tightened: was 30→25→20→15, now 25→20→15→5. Descriptions updated to match. |
| 2026-05-09 | Created (slice-boxes-3-win-conditions). Registry pattern mirrors BoxRollModifiers. 2 overrides: crit_only (bool — suppresses threshold path) and escalating_threshold (int — per-round threshold). get_round_limit() and _round_limit_overrides added for crit_only 5-round override. get_escalating_threshold() helper exposed for display/testing. get_description() for HUD tooltip. test_box_win_conditions.gd: 14 unit tests + 4 RoundManager integration tests. |
