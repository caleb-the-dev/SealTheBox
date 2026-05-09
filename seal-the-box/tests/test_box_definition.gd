extends SceneTree

func _init() -> void:
	var box_lib = load("res://scripts/globals/box_library.gd").new()
	box_lib.name = "BoxLibrary"
	get_root().add_child(box_lib)
	box_lib._ready()
	Engine.register_singleton("BoxLibrary", box_lib)

	_test_classic_box()
	_test_high_odds_box()
	_test_custom_box()
	_test_compressed_box()
	_test_stairs_box()
	_test_all_boxes_load()
	print("All BoxDefinition tests passed!")
	quit()

func _test_classic_box() -> void:
	var box = BoxDefinition.new()
	box.tabs.assign([1, 2, 3, 4, 5, 6, 7, 8, 9])
	box.win_threshold = 20
	assert(box.tab_sum() == 45, "classic tab_sum should be 45, got %d" % box.tab_sum())
	assert(box.win_threshold == 20, "classic win_threshold should be what was set, got %d" % box.win_threshold)
	assert(box.round_limit == 4, "classic round_limit should be 4, got %d" % box.round_limit)

func _test_high_odds_box() -> void:
	var box = BoxDefinition.new()
	box.tabs.assign([3, 5, 7, 9, 11])
	box.win_threshold = 17
	assert(box.tab_sum() == 35, "high_odds tab_sum should be 35, got %d" % box.tab_sum())
	assert(box.win_threshold == 17, "high_odds win_threshold should be what was set, got %d" % box.win_threshold)
	assert(box.round_limit == 4, "high_odds round_limit should be 4, got %d" % box.round_limit)

func _test_custom_box() -> void:
	var box = BoxDefinition.new()
	box.tabs.assign([1, 2, 3, 4, 5])
	box.win_threshold = 5
	assert(box.tab_sum() == 15, "custom tab_sum should be 15, got %d" % box.tab_sum())
	assert(box.win_threshold == 5, "custom win_threshold should be what was set, got %d" % box.win_threshold)
	assert(box.round_limit == 2, "custom round_limit should be 2 (ceili(15/15.0)+1=2), got %d" % box.round_limit)

func _test_compressed_box() -> void:
	var box = BoxDefinition.new()
	box.tabs.assign([2, 4, 5, 6, 8])
	box.win_threshold = 13
	assert(box.tab_sum() == 25, "compressed tab_sum should be 25, got %d" % box.tab_sum())
	assert(box.win_threshold == 13, "compressed win_threshold should be 13, got %d" % box.win_threshold)
	assert(box.round_limit == 3, "compressed round_limit should be 3, got %d" % box.round_limit)

func _test_stairs_box() -> void:
	var box = BoxDefinition.new()
	box.tabs.assign([1, 3, 5, 6, 7, 9])
	box.win_threshold = 15
	assert(box.tab_sum() == 31, "stairs tab_sum should be 31, got %d" % box.tab_sum())
	assert(box.win_threshold == 15, "stairs win_threshold should be 15, got %d" % box.win_threshold)
	assert(box.round_limit == 4, "stairs round_limit should be 4, got %d" % box.round_limit)

func _test_all_boxes_load() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_ordered()
	# 5 original + 3 boss + 13 comp + 6 ROLL + 2 WIN + 6 DICE = 34.
	assert(all.size() == 34, "BoxLibrary should have 34 boxes, got %d" % all.size())
	assert(all[0].id == "classic",    "box 0 should be classic, got %s"    % all[0].id)
	assert(all[1].id == "low_evens",  "box 1 should be low_evens, got %s"  % all[1].id)
	assert(all[2].id == "high_odds",  "box 2 should be high_odds, got %s"  % all[2].id)
	assert(all[3].id == "compressed", "box 3 should be compressed, got %s" % all[3].id)
	assert(all[4].id == "stairs",     "box 4 should be stairs, got %s"     % all[4].id)
