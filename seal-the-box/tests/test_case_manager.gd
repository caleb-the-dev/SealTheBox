extends SceneTree

func _init() -> void:
	var ability_lib = load("res://scripts/globals/ability_library.gd").new()
	ability_lib.name = "AbilityLibrary"
	get_root().add_child(ability_lib)
	ability_lib._ready()
	Engine.register_singleton("AbilityLibrary", ability_lib)

	var box_lib = load("res://scripts/globals/box_library.gd").new()
	box_lib.name = "BoxLibrary"
	get_root().add_child(box_lib)
	box_lib._ready()
	Engine.register_singleton("BoxLibrary", box_lib)

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)
	Engine.register_singleton("GameState", gs)

	var cm = load("res://scripts/run/case_manager.gd").new()
	cm.name = "CaseManager"
	get_root().add_child(cm)
	Engine.register_singleton("CaseManager", cm)

	_test_reset_run_builds_27_boxes(cm)
	_test_act_boundaries_correct(cm)
	_test_matches_1_to_8_are_easy(cm)
	_test_match_9_is_boss(cm)
	_test_matches_10_to_20_are_medium(cm)
	_test_match_21_is_boss(cm)
	_test_matches_22_to_26_are_hard(cm)
	_test_match_27_is_boss(cm)
	_test_boss_matches_are_all_different(cm)
	_test_get_act_for_match(cm)
	_test_case_match_index_increments(gs)
	_test_run_won_fires_on_match_27(cm, gs)
	_test_run_won_does_not_fire_before_match_27(cm)
	_test_reset_run_clears_run_won_and_rerolls(cm, gs)
	print("All CaseManager tests passed!")
	quit()

func _test_reset_run_builds_27_boxes(cm: Node) -> void:
	cm.reset_run()
	for i in range(1, 28):
		var box = cm.get_box_for_match(i)
		assert(box != null, "get_box_for_match(%d) should return a box" % i)
	var out_of_range = cm.get_box_for_match(28)
	assert(out_of_range == null, "get_box_for_match(28) should return null")

func _test_act_boundaries_correct(cm: Node) -> void:
	cm.reset_run()
	assert(cm.get_act_for_match(1) == 1,  "match 1 should be act 1")
	assert(cm.get_act_for_match(9) == 1,  "match 9 should be act 1")
	assert(cm.get_act_for_match(10) == 2, "match 10 should be act 2")
	assert(cm.get_act_for_match(21) == 2, "match 21 should be act 2")
	assert(cm.get_act_for_match(22) == 3, "match 22 should be act 3")
	assert(cm.get_act_for_match(27) == 3, "match 27 should be act 3")

func _test_matches_1_to_8_are_easy(cm: Node) -> void:
	cm.reset_run()
	for i in range(1, 9):
		var box = cm.get_box_for_match(i)
		assert(box.tier == "easy", "match %d should be easy tier, got '%s'" % [i, box.tier])

func _test_match_9_is_boss(cm: Node) -> void:
	# Run several resets to confirm match 9 is always boss tier
	for _i in 5:
		cm.reset_run()
		var box = cm.get_box_for_match(9)
		assert(box != null, "match 9 should return a box")
		assert(box.tier == "boss", "match 9 should be boss tier, got '%s'" % box.tier)

func _test_matches_10_to_20_are_medium(cm: Node) -> void:
	cm.reset_run()
	for i in range(10, 21):
		var box = cm.get_box_for_match(i)
		assert(box.tier == "medium", "match %d should be medium tier, got '%s'" % [i, box.tier])

func _test_match_21_is_boss(cm: Node) -> void:
	for _i in 5:
		cm.reset_run()
		var box = cm.get_box_for_match(21)
		assert(box != null, "match 21 should return a box")
		assert(box.tier == "boss", "match 21 should be boss tier, got '%s'" % box.tier)

func _test_matches_22_to_26_are_hard(cm: Node) -> void:
	cm.reset_run()
	for i in range(22, 27):
		var box = cm.get_box_for_match(i)
		assert(box.tier == "hard", "match %d should be hard tier, got '%s'" % [i, box.tier])

func _test_match_27_is_boss(cm: Node) -> void:
	for _i in 5:
		cm.reset_run()
		var box = cm.get_box_for_match(27)
		assert(box != null, "match 27 should return a box")
		assert(box.tier == "boss", "match 27 should be boss tier, got '%s'" % box.tier)

func _test_boss_matches_are_all_different(cm: Node) -> void:
	# Run several resets and confirm the 3 boss matches (9, 21, 27) are always different boxes
	for _i in 5:
		cm.reset_run()
		var b9  = cm.get_box_for_match(9)
		var b21 = cm.get_box_for_match(21)
		var b27 = cm.get_box_for_match(27)
		assert(b9 != null and b21 != null and b27 != null,
			"all three boss matches should return valid boxes")
		assert(b9.id != b21.id,
			"boss match 9 (%s) and 21 (%s) should be different boxes" % [b9.id, b21.id])
		assert(b9.id != b27.id,
			"boss match 9 (%s) and 27 (%s) should be different boxes" % [b9.id, b27.id])
		assert(b21.id != b27.id,
			"boss match 21 (%s) and 27 (%s) should be different boxes" % [b21.id, b27.id])

func _test_get_act_for_match(cm: Node) -> void:
	for i in range(1, 10):
		assert(cm.get_act_for_match(i) == 1, "match %d should be act 1" % i)
	for i in range(10, 22):
		assert(cm.get_act_for_match(i) == 2, "match %d should be act 2" % i)
	for i in range(22, 28):
		assert(cm.get_act_for_match(i) == 3, "match %d should be act 3" % i)

func _test_case_match_index_increments(gs: Node) -> void:
	gs.reset_run()
	assert(gs.case_match_index == 1, "case_match_index should be 1 after reset_run, got %d" % gs.case_match_index)
	gs.case_match_index = 10
	assert(gs.case_match_index == 10, "case_match_index should be settable")
	assert(gs.act == 2, "act should be 2 at index 10, got %d" % gs.act)
	gs.case_match_index = 22
	assert(gs.act == 3, "act should be 3 at index 22, got %d" % gs.act)

func _test_run_won_fires_on_match_27(cm: Node, gs: Node) -> void:
	cm.reset_run()
	gs.reset_run()
	var fired := [false]
	cm.run_won.connect(func(): fired[0] = true, CONNECT_ONE_SHOT)
	cm.notify_run_won()
	assert(fired[0], "run_won signal should fire when notify_run_won() is called")

func _test_run_won_does_not_fire_before_match_27(cm: Node) -> void:
	cm.reset_run()
	var fired := [false]
	var conn = func(): fired[0] = true
	cm.run_won.connect(conn)
	# Verify that getting boxes for matches 1-26 doesn't cause run_won
	for i in range(1, 27):
		cm.get_box_for_match(i)
	assert(not fired[0], "run_won should not fire just from getting boxes")
	cm.run_won.disconnect(conn)

func _test_reset_run_clears_run_won_and_rerolls(cm: Node, gs: Node) -> void:
	gs.run_won = true
	gs.case_match_index = 28
	gs.reset_run()
	assert(not gs.run_won, "reset_run should clear run_won")
	assert(gs.case_match_index == 1, "reset_run should reset case_match_index to 1, got %d" % gs.case_match_index)
	cm.reset_run()
	var box1 = cm.get_box_for_match(1)
	assert(box1 != null, "after reset_run, CaseManager should have a valid box for match 1")
	assert(box1.tier == "easy", "first box after reset should be easy tier")
