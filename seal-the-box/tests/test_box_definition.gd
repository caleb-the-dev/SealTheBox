extends SceneTree

func _init() -> void:
	_test_classic_box()
	_test_high_odds_box()
	_test_custom_box()
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
