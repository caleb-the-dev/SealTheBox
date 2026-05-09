class_name BoxDiceAccess
extends RefCounted

# Registry of dice-access modifiers for DICE-axis boxes.
#
# Architecture (slice-boxes-4-dice-access):
#   Registry callable contract:
#     func override_name(pool: Array) -> Array
#     - pool: the persistent dice pool (Array of Die objects)
#     - Returns a NEW array of Die objects to use for this match only.
#       The persistent pool is NOT modified.
#
# Pool-override rules:
#   single_die  — return exactly 1 randomly-chosen die from the pool
#   locked_d8   — return pool with all d8s removed
#   locked_d4   — return pool with all d4s removed
#   bounty_box  — no pool override (uses persistent pool); entry effect handled separately
#   tax_per_roll — no pool override; round-end damage handled via has_tax hook
#   forced_full_commit — no pool override; commitment check handled via has_forced_commit hook

static var _registry: Dictionary = {}
static var _initialized: bool = false

static var _descriptions: Dictionary = {
	"single_die": "Only 1 randomly-chosen die per round. Tabs are tuned for low rolls.",
	"locked_d8":  "d8s are locked out for this match — roll without your biggest dice.",
	"locked_d4":  "d4 is locked out for this match. A lighter restriction.",
}

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_registry = {
		"single_die": _override_single_die,
		"locked_d8":  _override_locked_d8,
		"locked_d4":  _override_locked_d4,
	}

# Returns whether a box has a pool-override registered.
static func has_override(box_id: String) -> bool:
	_ensure_init()
	return _registry.has(box_id)

# Returns whether a box has a DICE-axis description (for the [!] badge).
static func has_description(box_id: String) -> bool:
	return _descriptions.has(box_id)

# Returns the one-line description for the [!] tooltip, or "" if none.
static func get_description(box_id: String) -> String:
	return _descriptions.get(box_id, "")

# Compute the active pool for box_id given the persistent pool.
# Returns a new array of Die objects (persistent pool is untouched).
# If box has no override, returns a shallow copy of the persistent pool.
static func get_active_pool(box_id: String, persistent_pool: Array) -> Array:
	_ensure_init()
	if not _registry.has(box_id):
		return persistent_pool.duplicate()
	var fn: Callable = _registry[box_id]
	return fn.call(persistent_pool)

# Returns true if this box imposes a per-round HP tax after round 1.
static func has_tax(box_id: String) -> bool:
	return box_id == "tax_per_roll"

# Returns true if this box requires all rolled pips to be committed.
static func has_forced_commit(box_id: String) -> bool:
	return box_id == "forced_full_commit"

# Returns true if this box grants a fixed Power on match entry.
static func has_entry_power(box_id: String) -> bool:
	return box_id == "bounty_box"

# The power id granted by bounty_box on entry.
# Chosen: phoenix_down — delivers maximum "marquee moment" drama as a failsafe.
const BOUNTY_BOX_POWER_ID := "phoenix_down"

# ---------------------------------------------------------------------------
# Override implementations
# ---------------------------------------------------------------------------

# single_die: return an array containing exactly 1 randomly-chosen die from pool.
static func _override_single_die(pool: Array) -> Array:
	if pool.is_empty():
		push_warning("BoxDiceAccess: single_die override called on empty pool")
		return []
	var idx := randi() % pool.size()
	return [pool[idx]]

# locked_d8: return pool with all d8 faces removed.
static func _override_locked_d8(pool: Array) -> Array:
	var result: Array = []
	for die in pool:
		if die.faces != 8:
			result.append(die)
	return result

# locked_d4: return pool with all d4 faces removed.
static func _override_locked_d4(pool: Array) -> Array:
	var result: Array = []
	for die in pool:
		if die.faces != 4:
			result.append(die)
	return result
