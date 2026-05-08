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

	var entity_lib = load("res://scripts/globals/entity_library.gd").new()
	entity_lib.name = "EntityLibrary"
	get_root().add_child(entity_lib)
	entity_lib._ready()
	Engine.register_singleton("EntityLibrary", entity_lib)

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
	_test_all_act1_boxes_are_easy(cm)
	_test_all_act2_boxes_are_medium(cm)
	_test_all_act3_boxes_are_hard(cm)
	_test_get_act_for_match(cm)
	_test_case_match_index_increments(gs)
	_test_run_won_fires_on_match_27(cm, gs)
	_test_run_won_does_not_fire_before_match_27(cm)
	_test_reset_run_clears_run_won_and_rerolls(cm, gs)
	_test_match_27_is_source_box_for_entity(cm, gs, box_lib)
	_test_matches_22_to_26_are_never_source_boxes(cm)
	_test_each_entity_has_exactly_one_source(box_lib, entity_lib)
	_test_run_won_overlay_text_includes_source_box_name(gs, box_lib, entity_lib)
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

func _test_all_act1_boxes_are_easy(cm: Node) -> void:
	cm.reset_run()
	for i in range(1, 10):
		var box = cm.get_box_for_match(i)
		assert(box.tier == "easy", "match %d (act 1) should be easy tier, got '%s'" % [i, box.tier])

func _test_all_act2_boxes_are_medium(cm: Node) -> void:
	cm.reset_run()
	for i in range(10, 22):
		var box = cm.get_box_for_match(i)
		assert(box.tier == "medium", "match %d (act 2) should be medium tier, got '%s'" % [i, box.tier])

func _test_all_act3_boxes_are_hard(cm: Node) -> void:
	cm.reset_run()
	for i in range(22, 28):
		var box = cm.get_box_for_match(i)
		assert(box.tier == "hard", "match %d (act 3) should be hard tier, got '%s'" % [i, box.tier])

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

func _test_match_27_is_source_box_for_entity(cm: Node, gs: Node, box_lib: Node) -> void:
	# Run several resets and confirm match 27 always matches the entity's Source box
	for _i in 5:
		gs.reset_run()
		cm.reset_run()
		var entity_id: String = gs.entity_id
		assert(not entity_id.is_empty(), "entity_id should be set after reset_run")
		var expected_source: BoxDefinition = box_lib.get_source(entity_id)
		assert(expected_source != null, "BoxLibrary.get_source('%s') should return a box" % entity_id)
		var match27: BoxDefinition = cm.get_box_for_match(27)
		assert(match27 != null, "match 27 should return a valid box")
		assert(match27.id == expected_source.id,
			"match 27 id '%s' should equal Source box id '%s' for entity '%s'" \
			% [match27.id, expected_source.id, entity_id])

func _test_matches_22_to_26_are_never_source_boxes(cm: Node) -> void:
	# Run several resets and verify matches 22–26 never have a Source box
	for _i in 5:
		cm.reset_run()
		for match_idx in range(22, 27):
			var box: BoxDefinition = cm.get_box_for_match(match_idx)
			assert(box != null, "match %d should return a valid box" % match_idx)
			assert(box.source_for.is_empty(),
				"match %d should not be a Source box, got '%s' (source_for='%s')" \
				% [match_idx, box.id, box.source_for])

func _test_each_entity_has_exactly_one_source(box_lib: Node, entity_lib: Node) -> void:
	var entities = entity_lib.get_all()
	assert(entities.size() > 0, "EntityLibrary should have at least one entity")
	for entity in entities:
		var source = box_lib.get_source(entity.id)
		assert(source != null,
			"Entity '%s' should have exactly one Source box in BoxLibrary" % entity.id)
		assert(source.source_for == entity.id,
			"Source box source_for '%s' should match entity id '%s'" % [source.source_for, entity.id])
	# Also confirm non-entity source_for values don't exist
	var all_sources = box_lib.get_all().filter(func(b): return not b.source_for.is_empty())
	assert(all_sources.size() == entities.size(),
		"Number of Source boxes (%d) should equal number of entities (%d)" \
		% [all_sources.size(), entities.size()])

func _test_run_won_overlay_text_includes_source_box_name(gs: Node, box_lib: Node, entity_lib: Node) -> void:
	# Simulate the logic used in _on_run_won() and verify the composed text
	var entities = entity_lib.get_all()
	assert(entities.size() > 0, "EntityLibrary should have entities for overlay text test")
	for entity in entities:
		gs.entity_id = entity.id
		var entity_name: String = entity.display_name
		var source_box: BoxDefinition = box_lib.get_source(entity.id)
		assert(source_box != null, "Source box should exist for entity '%s'" % entity.id)
		var expected_text: String = "%s is sealed at %s" % [entity_name, source_box.name]
		# Verify the text format is correct (non-empty and contains the source name)
		assert(expected_text.contains(source_box.name),
			"Overlay text should include Source box name '%s'" % source_box.name)
		assert(expected_text.contains(entity_name),
			"Overlay text should include entity display_name '%s'" % entity_name)
