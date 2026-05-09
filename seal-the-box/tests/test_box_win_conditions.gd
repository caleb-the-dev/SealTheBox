extends SceneTree

# Tests for BoxWinConditions registry and RoundManager integration.
# Run headless: godot --headless --path seal-the-box --script tests/test_box_win_conditions.gd

func _init() -> void:
	# Minimal singletons needed for RoundManager integration tests.
	var lib = load("res://scripts/globals/ability_library.gd").new()
	lib.name = "AbilityLibrary"
	get_root().add_child(lib)
	lib._ready()
	Engine.register_singleton("AbilityLibrary", lib)

	var box_lib = load("res://scripts/globals/box_library.gd").new()
	box_lib.name = "BoxLibrary"
	get_root().add_child(box_lib)
	box_lib._ready()
	Engine.register_singleton("BoxLibrary", box_lib)

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)
	Engine.register_singleton("GameState", gs)

	# Registry unit tests
	_test_registry_has_both_win_conditions()
	_test_no_override_for_classic_box()
	_test_no_override_for_empty_id()

	# crit_only tests
	_test_crit_only_suppresses_threshold_win()
	_test_crit_only_wins_only_when_all_tabs_sealed()
	_test_crit_only_returns_false_when_tabs_remain()

	# escalating_threshold tests
	_test_escalating_threshold_round_1_is_25()
	_test_escalating_threshold_round_2_is_20()
	_test_escalating_threshold_round_3_is_15()
	_test_escalating_threshold_round_4_is_5()
	_test_escalating_threshold_round_99_is_5()
	_test_get_escalating_threshold_helper()

	# crit_only round_limit override
	_test_crit_only_round_limit_is_5()

	# RoundManager integration tests
	_test_round_manager_crit_only_suppresses_threshold_reached(gs)
	_test_round_manager_crit_only_allows_critical_win(gs)
	_test_round_manager_escalating_threshold_updates_each_round(gs)
	_test_round_manager_escalating_threshold_threshold_reached_at_correct_value(gs)

	print("All BoxWinConditions tests passed!")
	quit()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_die(faces: int, value: int) -> Die:
	var d := Die.new(faces)
	d.value = value
	d.rolled = true
	return d

func _make_tab_board(tabs: Array[int]) -> TabBoard:
	var tb := TabBoard.new()
	tb.reset(tabs)
	return tb

func _make_box(id: String, tabs: Array[int], threshold: int) -> BoxDefinition:
	var box := BoxDefinition.new()
	box.id = id
	box.tabs.assign(tabs)
	box.win_threshold = threshold
	return box

# ---------------------------------------------------------------------------
# Registry tests
# ---------------------------------------------------------------------------

func _test_registry_has_both_win_conditions() -> void:
	assert(BoxWinConditions.has_override("crit_only"),
		"BoxWinConditions should have override for 'crit_only'")
	assert(BoxWinConditions.has_override("escalating_threshold"),
		"BoxWinConditions should have override for 'escalating_threshold'")

func _test_no_override_for_classic_box() -> void:
	assert(not BoxWinConditions.has_override("classic"),
		"classic should have no win-condition override")

func _test_no_override_for_empty_id() -> void:
	assert(not BoxWinConditions.has_override(""),
		"empty string should have no win-condition override")

# ---------------------------------------------------------------------------
# crit_only tests
# ---------------------------------------------------------------------------

func _test_crit_only_suppresses_threshold_win() -> void:
	# When tabs remain, crit_only must return false (suppress threshold path).
	var tb := _make_tab_board([1, 2, 3, 4, 5, 6, 7, 8, 9])
	var result = BoxWinConditions.evaluate("crit_only", tb, 1, 11)
	assert(result == false,
		"crit_only with tabs remaining: expected false, got %s" % str(result))

func _test_crit_only_wins_only_when_all_tabs_sealed() -> void:
	# After sealing all tabs, crit_only returns true.
	var tb := _make_tab_board([])
	var result = BoxWinConditions.evaluate("crit_only", tb, 1, 11)
	assert(result == true,
		"crit_only with all tabs sealed: expected true, got %s" % str(result))

func _test_crit_only_returns_false_when_tabs_remain() -> void:
	# Even if the remaining sum is below the threshold, crit_only still returns false.
	# (Simulate: only tab 1 remains, threshold=5 — normally a threshold win.)
	var tb := _make_tab_board([1])
	var result = BoxWinConditions.evaluate("crit_only", tb, 1, 5)
	assert(result == false,
		"crit_only: single tab remaining (sum=1, threshold=5) should still return false")

# ---------------------------------------------------------------------------
# escalating_threshold tests
# ---------------------------------------------------------------------------

func _test_escalating_threshold_round_1_is_25() -> void:
	var tb := _make_tab_board([1, 2, 3, 4, 5, 6, 7, 8, 9])
	var result = BoxWinConditions.evaluate("escalating_threshold", tb, 1, 25)
	assert(result == 25,
		"escalating_threshold R1: expected 25, got %s" % str(result))

func _test_escalating_threshold_round_2_is_20() -> void:
	var tb := _make_tab_board([1, 2, 3, 4, 5, 6, 7, 8, 9])
	var result = BoxWinConditions.evaluate("escalating_threshold", tb, 2, 25)
	assert(result == 20,
		"escalating_threshold R2: expected 20, got %s" % str(result))

func _test_escalating_threshold_round_3_is_15() -> void:
	var tb := _make_tab_board([1, 2, 3, 4, 5, 6, 7, 8, 9])
	var result = BoxWinConditions.evaluate("escalating_threshold", tb, 3, 25)
	assert(result == 15,
		"escalating_threshold R3: expected 15, got %s" % str(result))

func _test_escalating_threshold_round_4_is_5() -> void:
	var tb := _make_tab_board([1, 2, 3, 4, 5, 6, 7, 8, 9])
	var result = BoxWinConditions.evaluate("escalating_threshold", tb, 4, 25)
	assert(result == 5,
		"escalating_threshold R4: expected 5, got %s" % str(result))

func _test_escalating_threshold_round_99_is_5() -> void:
	# Floor at R4+ = 5.
	var tb := _make_tab_board([1, 2, 3, 4, 5, 6, 7, 8, 9])
	var result = BoxWinConditions.evaluate("escalating_threshold", tb, 99, 25)
	assert(result == 5,
		"escalating_threshold R99: expected floor of 5, got %s" % str(result))

func _test_get_escalating_threshold_helper() -> void:
	assert(BoxWinConditions.get_escalating_threshold(1) == 25, "helper R1 should be 25")
	assert(BoxWinConditions.get_escalating_threshold(2) == 20, "helper R2 should be 20")
	assert(BoxWinConditions.get_escalating_threshold(3) == 15, "helper R3 should be 15")
	assert(BoxWinConditions.get_escalating_threshold(4) == 5,  "helper R4 should be 5")
	assert(BoxWinConditions.get_escalating_threshold(5) == 5,  "helper R5+ should be 5")

func _test_crit_only_round_limit_is_5() -> void:
	assert(BoxWinConditions.get_round_limit("crit_only", 4) == 5,
		"crit_only: round_limit override should be 5, base was 4")
	assert(BoxWinConditions.get_round_limit("classic", 4) == 4,
		"classic: no override, should return base_limit 4")

# ---------------------------------------------------------------------------
# RoundManager integration tests
# ---------------------------------------------------------------------------

func _test_round_manager_crit_only_suppresses_threshold_reached(gs: Node) -> void:
	gs.reset_run()
	# crit_only box: threshold win should never fire (threshold_reached signal).
	var box := _make_box("crit_only", [1, 2, 3, 4, 5, 6, 7, 8, 9], 44)
	var rm := RoundManager.new()
	# Use array to reliably capture count in lambda.
	var threshold_reached_count := [0]
	rm.threshold_reached.connect(func(): threshold_reached_count[0] += 1)
	rm.start_match(box)
	# Transition to act phase.
	rm.commit_roll([])
	# Set dice total = 15, seal tabs [3,5,7] sum=15.
	# After sealing: remaining = [1,2,4,6,8,9] sum=30. 30 ≤ 44 threshold, but crit_only
	# should suppress threshold_reached.
	gs.dice_hand[0].value = 6
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 5
	gs.dice_hand[1].rolled = true
	gs.dice_hand[2].value = 4
	gs.dice_hand[2].rolled = true
	rm.attempt_seal(gs.dice_hand, [3, 5, 7])
	assert(threshold_reached_count[0] == 0,
		"crit_only: threshold_reached should not fire even when remaining sum <= threshold, got %d" % threshold_reached_count[0])

func _test_round_manager_crit_only_allows_critical_win(gs: Node) -> void:
	gs.reset_run()
	var box := _make_box("crit_only", [1, 2, 3], 5)
	var rm := RoundManager.new()
	# Use array capture pattern for lambda.
	var won_log := [false, false]  # [fired, critical_flag]
	rm.match_won.connect(func(c: bool): won_log[0] = true; won_log[1] = c)
	rm.start_match(box)
	rm.commit_roll([])
	# Seal all tabs: dice total = 1+2+3 = 6.
	gs.dice_hand[0].value = 1
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 2
	gs.dice_hand[1].rolled = true
	gs.dice_hand[2].value = 3
	gs.dice_hand[2].rolled = true
	rm.attempt_seal(gs.dice_hand, [1, 2, 3])
	assert(won_log[0] == true,
		"crit_only: sealing all tabs should emit match_won signal")
	assert(won_log[1] == true,
		"crit_only: sealing all tabs should emit match_won(true) (critical), got match_won(false)")

func _test_round_manager_escalating_threshold_updates_each_round(gs: Node) -> void:
	gs.reset_run()
	var box := _make_box("escalating_threshold", [1, 2, 3, 4, 5, 6, 7, 8, 9], 25)
	var rm := RoundManager.new()
	rm.start_match(box)
	# After R1 start, threshold should be 25.
	assert(gs.win_threshold == 25,
		"escalating_threshold R1: win_threshold should be 25, got %d" % gs.win_threshold)
	# Advance to R2.
	rm.commit_roll([])
	rm.end_round()
	# After R2 start, threshold should be 20.
	assert(gs.win_threshold == 20,
		"escalating_threshold R2: win_threshold should be 20, got %d" % gs.win_threshold)
	# Advance to R3.
	rm.commit_roll([])
	rm.end_round()
	assert(gs.win_threshold == 15,
		"escalating_threshold R3: win_threshold should be 15, got %d" % gs.win_threshold)
	# Advance to R4.
	rm.commit_roll([])
	rm.end_round()
	assert(gs.win_threshold == 5,
		"escalating_threshold R4: win_threshold should be 5, got %d" % gs.win_threshold)

func _test_round_manager_escalating_threshold_threshold_reached_at_correct_value(gs: Node) -> void:
	gs.reset_run()
	# tabs [6,7,8,9] sum=30. In R1, threshold=25. Remaining=30 > 25, no fire in R1.
	# In R2, threshold=20. Seal [7,8] sum=15 → remaining=15 ≤ 20 → threshold_reached fires.
	var box := _make_box("escalating_threshold", [6, 7, 8, 9], 25)
	var rm := RoundManager.new()
	var threshold_reached_round := [-1]
	rm.threshold_reached.connect(func(): threshold_reached_round[0] = gs.round)
	rm.start_match(box)
	# R1: remaining sum=30 > threshold=25. Do not seal; just advance round.
	rm.commit_roll([])
	assert(threshold_reached_round[0] == -1,
		"escalating_threshold: threshold_reached should not fire in R1 with remaining=30 > threshold=25")
	rm.end_round()
	# Now in R2: threshold=20.
	assert(gs.win_threshold == 20,
		"escalating_threshold: after end_round, R2 threshold should be 20, got %d" % gs.win_threshold)
	# Commit R2 dice, seal [7,8] sum=15 → remaining=15 ≤ 20 → fires.
	rm.commit_roll([])
	gs.dice_hand[0].value = 7
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 8
	gs.dice_hand[1].rolled = true
	rm.attempt_seal(gs.dice_hand, [7, 8])
	assert(threshold_reached_round[0] == 2,
		"escalating_threshold: threshold_reached should fire in R2 (round=2), got round=%d" % threshold_reached_round[0])
