class_name BoxWinConditions
extends RefCounted

# Hardcoded registry of win-condition-override Callables, keyed by box_id.
#
# Architecture decision (slice-boxes-3-win-conditions):
#   Option 1 — registry as a Dict[String → Callable].
#   Same pattern as BoxRollModifiers (slice 2). Move to CSV-driven at ~20 entries.
#
# Callable contract:
#   func condition_name(tab_board: TabBoard, current_round: int, base_threshold: int) -> Variant
#   Return value:
#     null    → no override; use the default win check (remaining sum ≤ base_threshold)
#     true    → win (all victory conditions met)
#     false   → not yet (suppress the threshold-win path even if remaining sum ≤ base_threshold)
#     int     → use this value as the threshold override instead of base_threshold
#
# Note on escalating_threshold:
#   The CSV win_threshold column stores the R1 value (30). The callable overrides it
#   dynamically per round. The round index is 1-based (R1, R2, R3, R4+).

static var _registry: Dictionary = {}
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_registry = {
		"crit_only":             _cond_crit_only,
		"escalating_threshold":  _cond_escalating_threshold,
	}

# Returns whether a box has a win-condition override registered.
static func has_override(box_id: String) -> bool:
	_ensure_init()
	return _registry.has(box_id)

# Evaluate the win condition for box_id.
#   tab_board:       the current TabBoard (to read remaining tabs / critical-win state)
#   current_round:   GameState.round (1-indexed)
#   base_threshold:  the threshold computed by RoundManager.start_match (CSV value + power bonuses)
#
# Returns one of:
#   null  → no override; caller uses default check
#   true  → win
#   false → not yet (suppress threshold-win even if remaining sum ≤ threshold)
#   int   → treat this value as the threshold (caller checks remaining sum ≤ int)
static func evaluate(box_id: String, tab_board: TabBoard, current_round: int, base_threshold: int) -> Variant:
	_ensure_init()
	if not _registry.has(box_id):
		return null
	var fn: Callable = _registry[box_id]
	return fn.call(tab_board, current_round, base_threshold)

# ---------------------------------------------------------------------------
# Condition implementations
# ---------------------------------------------------------------------------

# crit_only: the only win is sealing every tab (shut the box).
#   Returns true if all tabs are sealed (critical win), false otherwise.
#   This suppresses the threshold-win path so the Continue button never shows.
static func _cond_crit_only(tab_board: TabBoard, _round: int, _threshold: int) -> Variant:
	if tab_board.check_critical_win():
		return true   # critical win — all tabs sealed
	return false      # explicitly suppress threshold-win path

# escalating_threshold: threshold drops each round.
#   R1 ≤30, R2 ≤25, R3 ≤20, R4+ ≤15.
#   Returns the int threshold for the current round.
#   If the remaining sum is already ≤15, later rounds keep the floor.
static func _cond_escalating_threshold(_tab_board: TabBoard, current_round: int, _threshold: int) -> Variant:
	match current_round:
		1: return 30
		2: return 25
		3: return 20
		_: return 15  # R4 and beyond

# Helper: return the escalating threshold for a given round (used by RoundManager
# to display the correct threshold label each round start).
static func get_escalating_threshold(current_round: int) -> int:
	match current_round:
		1: return 30
		2: return 25
		3: return 20
		_: return 15
