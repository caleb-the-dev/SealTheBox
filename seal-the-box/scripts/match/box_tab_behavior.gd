class_name BoxTabBehavior
extends RefCounted

# Dispatcher for BHV-axis (Tab Behavior Over Time) boxes.
#
# Architecture
# ─────────────
# Each BHV box registers named handler functions here.  RoundManager
# calls the four hook points at the appropriate moments:
#
#   on_round_start(box_id, tab_board, game_state)
#   on_round_end(box_id, tab_board, game_state) -> bool (true = tabs changed)
#   on_round_end_no_seal(box_id, tab_board, game_state)
#   on_seal(box_id, sealed_value, tab_board, game_state)
#
# Only one BHV box is active per match, so a simple `match box_id` dispatch
# is sufficient — no registration table needed.
#
# All functions are static; no state lives here.  Per-match state (e.g.,
# fading_decoys reveal tracking, mitosis recursion depth) is stored in the
# tab_board or passed through game_state via a scratch dictionary.
#
# Tab-value ceiling for rising_tide / growing_pillars.
const RISING_TIDE_CEILING := 13

# Mitosis recursion cap.
const MITOSIS_MAX_DEPTH := 5

# ---------------------------------------------------------------------------
# Public dispatch API
# ---------------------------------------------------------------------------

# Returns true if the given box_id has any BHV hooks registered.
static func has_behavior(box_id: String) -> bool:
	return box_id in [
		"regrowing", "rising_tide", "shuffler", "clock_tabs",
		"growing_pillars", "revenant_tabs", "fading_decoys",
		"mitosis", "moving_targets"
	]

# Called at the start of each round (before roll phase).
# tab_board: the active TabBoard
# gs: GameState node
static func on_round_start(box_id: String, tab_board: TabBoard, gs: Node) -> void:
	match box_id:
		"regrowing":
			_regrowing_on_round_start(tab_board, gs)
		"shuffler":
			_shuffler_on_round_start(tab_board, gs)
		"moving_targets":
			_moving_targets_on_round_start(tab_board, gs)
		"fading_decoys":
			_fading_decoys_on_round_start(tab_board, gs)

# Called at the end of each round (after the hand is discarded, before
# checking overtime damage).  Returns the message to show the player, or ""
# if nothing happened.
static func on_round_end(box_id: String, tab_board: TabBoard, gs: Node) -> String:
	match box_id:
		"rising_tide":
			return _rising_tide_on_round_end(tab_board)
		"growing_pillars":
			return _growing_pillars_on_round_end(tab_board)
		"clock_tabs":
			return _clock_tabs_on_round_end(tab_board, gs)
	return ""

# Called at the end of a round where the player sealed nothing.
static func on_round_end_no_seal(box_id: String, tab_board: TabBoard, gs: Node) -> String:
	match box_id:
		"revenant_tabs":
			return _revenant_tabs_on_round_end_no_seal(tab_board, gs)
	return ""

# Called each time one or more tabs are sealed.
# sealed_values: Array[int] of tab values just sealed (real tabs only)
# depth: recursion guard (starts at 0; callers pass 0)
static func on_seal(box_id: String, sealed_values: Array, tab_board: TabBoard, gs: Node, depth: int = 0) -> String:
	match box_id:
		"mitosis":
			return _mitosis_on_seal(sealed_values, tab_board, gs, depth)
		"fading_decoys":
			return _fading_decoys_on_seal(sealed_values, tab_board, gs)
	return ""

# ---------------------------------------------------------------------------
# regrowing — round start: lowest sealed tab returns
# ---------------------------------------------------------------------------

static func _regrowing_on_round_start(tab_board: TabBoard, gs: Node) -> void:
	if gs.round <= 1:
		return   # Nothing sealed yet on round 1
	# Determine what tabs were in the original box.
	var original_tabs: Array[int] = []
	if gs.current_box:
		original_tabs = gs.current_box.tabs.duplicate()
	# Find the smallest tab value that is NOT in the remaining set.
	var remaining := tab_board.get_real_remaining()
	var sealed_candidates: Array[int] = []
	for v in original_tabs:
		if v not in remaining:
			sealed_candidates.append(v)
	if sealed_candidates.is_empty():
		return
	sealed_candidates.sort()
	var to_return := sealed_candidates[0]
	tab_board.add_tab(to_return)

# ---------------------------------------------------------------------------
# shuffler — round start: every unsealed tab gets a random value 1-9
# ---------------------------------------------------------------------------

static func _shuffler_on_round_start(tab_board: TabBoard, _gs: Node) -> void:
	# Replace all real tab values with random draws from 1-9.
	var tab_data := tab_board.get_tab_data()
	for i in tab_data.size():
		var td = tab_data[i]
		if not td.is_decoy:
			tab_board.change_tab_value_at(i, randi_range(1, 9))

# ---------------------------------------------------------------------------
# moving_targets — round start: set tab range based on round index
#   R1: 1-6, R2: 2-7, R3: 3-8, R4+: 4-9
# ---------------------------------------------------------------------------

static func _moving_targets_on_round_start(tab_board: TabBoard, gs: Node) -> void:
	var round_num: int = gs.round
	var base: int = clampi(round_num - 1, 0, 3)  # 0, 1, 2, 3
	var new_tabs: Array[int] = []
	for i in 6:
		new_tabs.append(base + 1 + i)   # R1: 1-6, R2: 2-7, etc.
	tab_board.replace_all_tabs(new_tabs)

# ---------------------------------------------------------------------------
# fading_decoys — round start: on round 3, vanish the decoys
# ---------------------------------------------------------------------------

static func _fading_decoys_on_round_start(tab_board: TabBoard, gs: Node) -> void:
	# Decoys vanish at the END of round 2 — implemented here at round-3 start
	# so the player gets to see the reveal at the beginning of round 3.
	if gs.round == 3 and tab_board.has_decoys():
		var vanished := tab_board.reveal_and_vanish_decoys()
		# Store vanished list in gs scratch so RoundManager can show the message.
		gs.set_meta("bhv_fading_decoys_revealed", vanished)

# ---------------------------------------------------------------------------
# rising_tide — round end: every unsealed tab +1 (ceiling 13)
# ---------------------------------------------------------------------------

static func _rising_tide_on_round_end(tab_board: TabBoard) -> String:
	var tab_data: Array = tab_board.get_tab_data()
	var changed: bool = false
	for i in tab_data.size():
		var td: TabBoard.TabData = tab_data[i]
		if not td.is_decoy:
			var new_val: int = mini(td.value + 1, RISING_TIDE_CEILING)
			if new_val != td.value:
				tab_board.change_tab_value_at(i, new_val)
				changed = true
	return "Rising Tide — all tabs +1." if changed else ""

# ---------------------------------------------------------------------------
# growing_pillars — round end: every unsealed tab +1 (ceiling 13)
# Same rule as rising_tide; different starting tabs.
# ---------------------------------------------------------------------------

static func _growing_pillars_on_round_end(tab_board: TabBoard) -> String:
	var tab_data: Array = tab_board.get_tab_data()
	var changed: bool = false
	for i in tab_data.size():
		var td: TabBoard.TabData = tab_data[i]
		if not td.is_decoy:
			var new_val: int = mini(td.value + 1, RISING_TIDE_CEILING)
			if new_val != td.value:
				tab_board.change_tab_value_at(i, new_val)
				changed = true
	return "Growing Pillars — all tabs +1." if changed else ""

# ---------------------------------------------------------------------------
# clock_tabs — round end: one random tab -1; if it hits 0, player takes 1 HP
# ---------------------------------------------------------------------------

static func _clock_tabs_on_round_end(tab_board: TabBoard, gs: Node) -> String:
	var tab_data: Array = tab_board.get_tab_data()
	# Collect indices of real (non-decoy) tabs.
	var real_indices: Array[int] = []
	for i in tab_data.size():
		var td_check: TabBoard.TabData = tab_data[i]
		if not td_check.is_decoy:
			real_indices.append(i)
	if real_indices.is_empty():
		return ""
	var chosen_idx: int = real_indices[randi() % real_indices.size()]
	var td: TabBoard.TabData = tab_data[chosen_idx]
	var new_val: int = td.value - 1
	if new_val <= 0:
		# Tab reaches 0 — remove it AND deal 1 HP damage.
		tab_board.remove_tab(td.value, false)
		gs.hp -= 1
		return "Clock Tabs — tab ticked to 0! You took 1 damage."
	else:
		tab_board.change_tab_value_at(chosen_idx, new_val)
		return "Clock Tabs — tab ticked down to %d." % new_val

# ---------------------------------------------------------------------------
# revenant_tabs — round-end-no-seal: lowest sealed tab returns
# ---------------------------------------------------------------------------

static func _revenant_tabs_on_round_end_no_seal(tab_board: TabBoard, gs: Node) -> String:
	if gs.current_box == null:
		return ""
	var original_tabs: Array[int] = gs.current_box.tabs.duplicate()
	var remaining := tab_board.get_real_remaining()
	var sealed_candidates: Array[int] = []
	for v in original_tabs:
		if v not in remaining:
			sealed_candidates.append(v)
	if sealed_candidates.is_empty():
		return ""
	sealed_candidates.sort()
	var to_return := sealed_candidates[0]
	tab_board.add_tab(to_return)
	return "Revenant Tabs — the %d returned!" % to_return

# ---------------------------------------------------------------------------
# fading_decoys — on_seal: sealing a decoy does nothing (returns message)
# ---------------------------------------------------------------------------

static func _fading_decoys_on_seal(sealed_values: Array, _tab_board: TabBoard, _gs: Node) -> String:
	# The actual decoy-seal interception happens in RoundManager before calling
	# on_seal; this hook just returns a message if needed.
	# (Decoys are filtered out of real tabs in TabBoard.can_seal_multi already.)
	return ""

# ---------------------------------------------------------------------------
# mitosis — on_seal: sealing tab ≥ 6 spawns a tab of floor(value/2)
# ---------------------------------------------------------------------------

static func _mitosis_on_seal(sealed_values: Array, tab_board: TabBoard, _gs: Node, depth: int) -> String:
	if depth >= MITOSIS_MAX_DEPTH:
		return ""
	var messages: PackedStringArray = []
	for v in sealed_values:
		if v >= 6:
			var spawn: int = int(v) / 2   # integer floor division
			if spawn >= 1:
				tab_board.add_tab(spawn)
				messages.append("Mitosis — sealed %d spawned %d." % [v, spawn])
			# If spawn would be 0 or less, nothing spawns (already sealed).
	return "\n".join(messages)
