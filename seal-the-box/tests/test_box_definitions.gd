extends SceneTree

# Validation suite for the full box pool after slice-boxes-4-dice-access.
# Checks structural invariants for all boxes and presence of the 6 DICE boxes.
# Run headless: godot --headless --path seal-the-box --script tests/test_box_definitions.gd

# Preload so BDA is available in headless --script mode.
# In headless mode class_name types in subdirectories may not be registered at parse time;
# preload forces the script to be loaded and available as a constant.
const BDA = preload("res://scripts/match/box_dice_access.gd")

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
	_test_dice_access_boxes_present()
	_test_dice_access_registry_coverage()
	print("All test_box_definitions tests passed!")
	quit()

func _test_box_count() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_all()
	# 5 original + 3 source/boss + 7 ROLL + 2 WIN + 6 DICE = 23.
	assert(all.size() == 23, "BoxLibrary should have 23 boxes, got %d" % all.size())

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

func _test_dice_access_boxes_present() -> void:
	var dice_ids := [
		"single_die", "locked_d8", "locked_d4", "bounty_box", "tax_per_roll", "forced_full_commit"
	]
	var lib := Engine.get_singleton("BoxLibrary")
	for id in dice_ids:
		var box = lib.get_box(id)
		assert(box != null, "DICE box '%s' should exist in BoxLibrary" % id)
		assert(box.id == id, "box id mismatch: expected '%s', got '%s'" % [id, box.id])
		assert(box.tab_sum() > 0, "DICE box '%s' tab_sum should be positive" % id)

func _test_dice_access_registry_coverage() -> void:
	# Pool-override boxes have a registered override.
	var pool_override_ids := ["single_die", "locked_d8", "locked_d4"]
	for id in pool_override_ids:
		assert(BDA.has_override(id),
			"BDA should have a pool override for DICE box '%s'" % id)
	# Non-override DICE boxes (round-end hooks, entry power) should NOT have pool override.
	var no_pool_override_ids := ["bounty_box", "tax_per_roll", "forced_full_commit"]
	for id in no_pool_override_ids:
		assert(not BDA.has_override(id),
			"DICE box '%s' should not have a pool override (uses other hooks)" % id)
	# Non-DICE boxes should not have pool overrides.
	var non_dice_ids := ["classic", "low_evens", "high_odds", "compressed", "stairs"]
	for id in non_dice_ids:
		assert(not BDA.has_override(id),
			"non-DICE box '%s' should not have a pool override" % id)
