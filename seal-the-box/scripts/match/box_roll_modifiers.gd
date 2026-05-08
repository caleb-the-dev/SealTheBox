class_name BoxRollModifiers
extends RefCounted

# Hardcoded registry of roll-modifier Callables, keyed by box_id.
#
# Architecture decision (slice-boxes-2-roll-mods):
#   Option 1 — registry as a Dict[String → Callable].
#   Move to CSV-driven when registry exceeds ~20 entries.
#
# Modifier contract:
#   func modifier_name(dice: Array) -> int
#   - dice: array of Die objects that have been rolled (die.rolled == true, die.dropped skipped)
#   - Return value:
#       -1  → use the natural sum of dice (modifier mutated die values in-place)
#       ≥0  → use this value as the total override (modifier computed the total itself)
#
# exploding_ones chain depth cap: 10 (prevents infinite loops on a hypothetical 100%-1-face die)

const EXPLODING_ONES_MAX_DEPTH := 10

static var _registry: Dictionary = {}
# Set of box_ids whose modifiers compute a total override (pure functions —
# do NOT mutate die values, safe to call multiple times).
static var _total_override_ids: Dictionary = {}
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_registry = {
		"heavy_dice":       _mod_heavy_dice,
		"weak_dice":        _mod_weak_dice,
		"halving_box":      _mod_halving_box,
		"doubling_box":     _mod_doubling_box,
		"exploding_ones":   _mod_exploding_ones,
		"pair_swallows":    _mod_pair_swallows,
		"high_die_doubles": _mod_high_die_doubles,
	}
	# Total-override modifiers are pure: they read die values and return a total.
	# They are NOT applied at roll-time mutation — only when computing the total.
	_total_override_ids = {
		"halving_box":      true,
		"doubling_box":     true,
		"high_die_doubles": true,
	}

# Returns whether a box has a roll modifier registered.
static func has_modifier(box_id: String) -> bool:
	_ensure_init()
	return _registry.has(box_id)

# Returns true if the modifier for this box is a total-override type
# (pure computation, safe to call multiple times without mutating dice).
static func is_total_override(box_id: String) -> bool:
	_ensure_init()
	return _total_override_ids.has(box_id)

# Apply the dice-mutation modifier for box_id to the rolled dice.
# Should be called ONCE per roll, at roll-commit time.
# No-op for total-override boxes (they are pure functions, handled separately).
# dice: full dice hand (modifiers skip dropped/unrolled dice internally).
static func apply_dice_mutation(box_id: String, dice: Array) -> void:
	_ensure_init()
	if not _registry.has(box_id):
		return
	if _total_override_ids.has(box_id):
		return  # total-override: no mutation to apply
	var fn: Callable = _registry[box_id]
	fn.call(dice)  # return value is -1 (mutation type), discarded

# Compute the effective total for box_id given the current dice.
# For total-override boxes: returns the modifier's computed total.
# For mutation-type boxes or unknown boxes: returns -1 (caller should sum normally).
# Safe to call multiple times — does NOT mutate dice.
static func compute_total(box_id: String, dice: Array) -> int:
	_ensure_init()
	if not _total_override_ids.has(box_id):
		return -1
	var fn: Callable = _registry[box_id]
	return fn.call(dice)

# ---------------------------------------------------------------------------
# Modifier implementations
# ---------------------------------------------------------------------------

# heavy_dice: +1 to each die (no face cap — box rule overrides the die type).
static func _mod_heavy_dice(dice: Array) -> int:
	for die in dice:
		if die.rolled and not die.dropped:
			die.value += 1
	return -1  # use natural sum

# weak_dice: -1 to each die, floor of 1.
static func _mod_weak_dice(dice: Array) -> int:
	for die in dice:
		if die.rolled and not die.dropped:
			die.value = max(1, die.value - 1)
	return -1  # use natural sum

# halving_box: total = floor(total / 2). Acts on sum, not individual dice.
# Returns the halved total as an override so dice display their natural values
# but the sealing total is halved.
static func _mod_halving_box(dice: Array) -> int:
	var total := 0
	for die in dice:
		if die.rolled and not die.dropped:
			total += die.value
	return total / 2  # integer division = floor

# doubling_box: total = total * 2. Same total-override approach.
static func _mod_doubling_box(dice: Array) -> int:
	var total := 0
	for die in dice:
		if die.rolled and not die.dropped:
			total += die.value
	return total * 2

# exploding_ones: for each die showing 1, reroll same die type, add result.
# Chains on consecutive 1s; chain depth capped at EXPLODING_ONES_MAX_DEPTH.
# Mutates die.value in-place; returns -1 so caller sums normally.
static func _mod_exploding_ones(dice: Array) -> int:
	for die in dice:
		if die.rolled and not die.dropped and die.value == 1:
			_explode_die(die, 0)
	return -1  # use natural sum

static func _explode_die(die: Die, depth: int) -> void:
	if depth >= EXPLODING_ONES_MAX_DEPTH:
		return
	var extra := randi_range(1, die.faces)
	die.value += extra
	if extra == 1:
		_explode_die(die, depth + 1)

# pair_swallows: scan rolled dice; for each pair of equal values, remove one
# die from the active set and add the pair sum to the other.
# Operates on the dice array in a single pass — earliest pair found wins.
# Mutates die.value and die.dropped; returns -1.
static func _mod_pair_swallows(dice: Array) -> int:
	# Build a list of active (rolled, not dropped) dice.
	var active: Array = []
	for die in dice:
		if die.rolled and not die.dropped:
			active.append(die)

	# Greedy scan: find first pair, merge, repeat until no pairs remain.
	var changed := true
	while changed:
		changed = false
		for i in active.size():
			for j in range(i + 1, active.size()):
				if active[i].value == active[j].value:
					# Merge: add j's value to i, drop j.
					active[i].value += active[j].value
					active[j].dropped = true
					active.remove_at(j)
					changed = true
					break
			if changed:
				break
	return -1  # use natural sum

# high_die_doubles: the highest die in each roll counts double.
# Returns a total override = (sum of non-highest dice) + (highest die × 2).
# Ties: only one die gets the doubling (the first found at max value).
static func _mod_high_die_doubles(dice: Array) -> int:
	var active: Array = []
	for die in dice:
		if die.rolled and not die.dropped:
			active.append(die)
	if active.is_empty():
		return 0

	# Find the die with the highest value.
	var max_die: Die = active[0]
	for die in active:
		if die.value > max_die.value:
			max_die = die

	var total := 0
	var counted_max := false
	for die in active:
		if not counted_max and die == max_die:
			total += die.value * 2
			counted_max = true
		else:
			total += die.value
	return total
