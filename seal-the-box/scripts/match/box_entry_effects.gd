class_name BoxEntryEffects
extends RefCounted

# Registry of ENTRY-axis box effects for slice-boxes-5-entry-effects.
#
# Architecture:
#   Entry hooks fire once at the start of a match (in RoundManager.start_match).
#   They read/write GameState directly — same pattern as PowerManager hooks.
#
# Registered boxes:
#   storm_box      — add one random temporary die to the match pool delta
#   cleanse_box    — refill all ability charges to max
#   borrowed_time  — hp -= 1; round_limit += 1
#
# Transient pool delta (storm_box):
#   GameState.match_pool_delta holds extra Die objects that are appended to the
#   active pool for the current match only. RoundManager.start_match() clears
#   the delta before calling on_box_entry(), then passes
#   (persistent_pool + delta) to DicePool.setup(). This is a single-match
#   read — the persistent dice_pool is never modified.

# Die face options available as the storm_box bonus die.
const STORM_DIE_FACES: Array[int] = [4, 6, 8]

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# Apply all entry effects for box_id. Call once per match in start_match().
# gs: the GameState node singleton
static func on_box_entry(box_id: String, gs: Node) -> void:
	match box_id:
		"storm_box":
			_apply_storm_box(gs)
		"cleanse_box":
			_apply_cleanse_box(gs)
		"borrowed_time":
			_apply_borrowed_time(gs)

# Returns true if box_id has a registered entry effect.
static func has_entry_effect(box_id: String) -> bool:
	return box_id in ["storm_box", "cleanse_box", "borrowed_time"]

# Returns a human-readable description for the [!] badge tooltip, or "" if not an ENTRY box.
static func get_description(box_id: String) -> String:
	match box_id:
		"storm_box":     return "ENTRY: A random bonus die (d4, d6, or d8) is added to your pool for this match only."
		"cleanse_box":   return "ENTRY: All ability charges are refilled to max when the match begins."
		"borrowed_time": return "ENTRY: You lose 1 HP but gain an extra round. Only appears when HP ≥ 3."
	return ""

# ---------------------------------------------------------------------------
# Effect implementations
# ---------------------------------------------------------------------------

# storm_box: add one random die to match_pool_delta for this match only.
static func _apply_storm_box(gs: Node) -> void:
	var faces := STORM_DIE_FACES[randi() % STORM_DIE_FACES.size()]
	var bonus_die := Die.new(faces)
	bonus_die.storm_temp = true   # label so UI can identify it (optional)
	gs.match_pool_delta.append(bonus_die)

# cleanse_box: restore all ability charges to max.
static func _apply_cleanse_box(gs: Node) -> void:
	for ability in gs.ability_hand:
		if ability != null:
			ability.charges = ability.max_charges

# borrowed_time: take 1 HP; gain +1 round limit.
# HP gate (hp >= 3) is enforced upstream in CaseManager.get_box_for_match —
# this function just applies the effect unconditionally.
static func _apply_borrowed_time(gs: Node) -> void:
	gs.hp -= 1
	gs.round_limit += 1
