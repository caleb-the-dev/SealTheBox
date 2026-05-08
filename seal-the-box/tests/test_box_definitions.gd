extends SceneTree

# Validation suite for the full box pool after slice-boxes-2-roll-mods.
# Checks structural invariants for all boxes and presence of the 7 ROLL modifier boxes.
# Run headless: godot --headless --path seal-the-box --script tests/test_box_definitions.gd

func _init() -> void:
	var box_lib = load("res://scripts/globals/box_library.gd").new()
	box_lib.name = "BoxLibrary"
	get_root().add_child(box_lib)
	box_lib._ready()
	Engine.register_singleton("BoxLibrary", box_lib)

	_test_box_count()
	_test_all_tab_sums_positive()
	_test_win_thresholds_in_range()
	_test_round_limits_at_least_2()
	_test_all_boxes_have_at_least_5_tabs()
	_test_no_duplicate_ids()
	_test_all_boxes_have_valid_tier()
	_test_roll_modifier_boxes_present()
	_test_roll_modifier_registry_coverage()
	print("All test_box_definitions tests passed!")
	quit()

func _test_box_count() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_all()
	# 5 original + 3 source/boss + 7 ROLL modifier boxes = 15.
	assert(all.size() == 15, "BoxLibrary should have 15 boxes, got %d" % all.size())

func _test_all_tab_sums_positive() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_all()
	for box in all:
		assert(box.tab_sum() > 0,
			"box '%s' tab_sum should be positive, got %d" % [box.id, box.tab_sum()])

func _test_win_thresholds_in_range() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_all()
	for box in all:
		assert(box.win_threshold > 0,
			"box '%s' win_threshold should be > 0, got %d" % [box.id, box.win_threshold])
		assert(box.win_threshold < box.tab_sum(),
			"box '%s' win_threshold (%d) should be < tab_sum (%d)" % [box.id, box.win_threshold, box.tab_sum()])

func _test_round_limits_at_least_2() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_all()
	for box in all:
		assert(box.round_limit >= 2,
			"box '%s' round_limit should be >= 2, got %d" % [box.id, box.round_limit])

func _test_all_boxes_have_at_least_5_tabs() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_all()
	for box in all:
		assert(box.tabs.size() >= 5,
			"box '%s' should have at least 5 tabs, got %d" % [box.id, box.tabs.size()])

func _test_no_duplicate_ids() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_all()
	var seen: Dictionary = {}
	for box in all:
		assert(not seen.has(box.id),
			"duplicate box id found: '%s'" % box.id)
		seen[box.id] = true

func _test_all_boxes_have_valid_tier() -> void:
	var valid_tiers = ["easy", "medium", "hard", "boss"]
	var all = Engine.get_singleton("BoxLibrary").get_all()
	for box in all:
		assert(box.tier in valid_tiers,
			"box '%s' tier '%s' should be one of easy/medium/hard/boss" % [box.id, box.tier])
		assert(not box.tier.is_empty(),
			"box '%s' should have a non-empty tier" % box.id)

func _test_roll_modifier_boxes_present() -> void:
	var roll_ids := [
		"heavy_dice", "weak_dice", "halving_box", "doubling_box",
		"exploding_ones", "pair_swallows", "high_die_doubles"
	]
	var lib := Engine.get_singleton("BoxLibrary")
	for id in roll_ids:
		var box = lib.get_box(id)
		assert(box != null, "ROLL box '%s' should exist in BoxLibrary" % id)
		assert(box.id == id, "box id mismatch: expected '%s', got '%s'" % [id, box.id])
		assert(box.tab_sum() > 0, "ROLL box '%s' tab_sum should be positive" % id)

func _test_roll_modifier_registry_coverage() -> void:
	# Every box in the ROLL tier has a registered modifier.
	var roll_ids := [
		"heavy_dice", "weak_dice", "halving_box", "doubling_box",
		"exploding_ones", "pair_swallows", "high_die_doubles"
	]
	for id in roll_ids:
		assert(BoxRollModifiers.has_modifier(id),
			"BoxRollModifiers should have a modifier for ROLL box '%s'" % id)
	# Original boxes should NOT have a modifier registered.
	var non_roll_ids := ["classic", "low_evens", "high_odds", "compressed", "stairs"]
	for id in non_roll_ids:
		assert(not BoxRollModifiers.has_modifier(id),
			"non-ROLL box '%s' should not have a modifier in BoxRollModifiers" % id)
