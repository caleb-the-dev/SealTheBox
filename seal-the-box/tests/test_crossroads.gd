extends SceneTree

func _init() -> void:
	var lib = load("res://scripts/globals/ability_library.gd").new()
	lib.name = "AbilityLibrary"
	get_root().add_child(lib)
	lib._ready()
	Engine.register_singleton("AbilityLibrary", lib)

	var power_lib = load("res://scripts/globals/power_library.gd").new()
	power_lib.name = "PowerLibrary"
	get_root().add_child(power_lib)
	power_lib._ready()
	Engine.register_singleton("PowerLibrary", power_lib)

	var box_lib = load("res://scripts/globals/box_library.gd").new()
	box_lib.name = "BoxLibrary"
	get_root().add_child(box_lib)
	box_lib._ready()
	Engine.register_singleton("BoxLibrary", box_lib)

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)
	Engine.register_singleton("GameState", gs)

	var pm = load("res://scripts/run/power_manager.gd").new()
	pm.name = "PowerManager"
	get_root().add_child(pm)
	Engine.register_singleton("PowerManager", pm)

	var cm = load("res://scripts/run/case_manager.gd").new()
	cm.name = "CaseManager"
	get_root().add_child(cm)
	Engine.register_singleton("CaseManager", cm)

	_test_crossroads_fires_after_match_9(gs)
	_test_crossroads_does_not_fire_at_match_8(gs)
	_test_crossroads_fires_after_match_21(gs)
	_test_crossroads_does_not_fire_at_match_10(gs)
	_test_crossroads_rest_adds_2_hp(gs)
	_test_crossroads_rest_capped_at_max_hp(gs)
	_test_crossroads_whetstone_emits_die_swap(gs)
	_test_periodic_die_swap_removed(gs)

	print("All crossroads tests passed!")
	quit()

# ── tests ─────────────────────────────────────────────────────────────────────

func _test_crossroads_fires_after_match_9(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	var crossroads_log: Array = []
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))
	rm.show_crossroads.connect(func(after):
		crossroads_log.append(after)
		rm.handle_crossroads_rest()
	)

	rm.start_run()

	# Advance matches 1-8: crossroads must NOT fire
	for _i in 8:
		rm.handle_match_won(false)
	assert(crossroads_log.size() == 0,
		"crossroads should NOT fire during matches 1-8, got %d" % crossroads_log.size())

	# Win match 9 — crossroads should fire exactly once with after_match == 9
	rm.handle_match_won(false)
	assert(crossroads_log.size() == 1,
		"crossroads should fire exactly once after match 9, got %d" % crossroads_log.size())
	assert(crossroads_log[0] == 9,
		"crossroads after_match should be 9, got %d" % crossroads_log[0])
	rm.queue_free()

func _test_crossroads_does_not_fire_at_match_8(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	var crossroads_log: Array = []
	rm.show_crossroads.connect(func(after): crossroads_log.append(after))

	rm.start_run()
	for _i in 8:
		rm.handle_match_won(false)

	assert(crossroads_log.size() == 0,
		"crossroads should NOT have fired after 8 matches, got %d" % crossroads_log.size())
	rm.queue_free()

func _test_crossroads_fires_after_match_21(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	var crossroads_log: Array = []
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))
	# Auto-resolve crossroads with rest so the run continues through match 21
	rm.show_crossroads.connect(func(after):
		crossroads_log.append(after)
		rm.handle_crossroads_rest()
	)

	rm.start_run()

	# Advance through all 21 matches; show_crossroads auto-resolved after match 9 and 21
	for _i in 21:
		rm.handle_match_won(false)

	assert(crossroads_log.size() == 2,
		"crossroads should fire exactly twice total (after match 9 and 21), got %d" % crossroads_log.size())
	assert(crossroads_log[0] == 9,
		"first crossroads should be after_match == 9, got %d" % crossroads_log[0])
	assert(crossroads_log[1] == 21,
		"second crossroads should be after_match == 21, got %d" % crossroads_log[1])
	rm.queue_free()

func _test_crossroads_does_not_fire_at_match_10(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	var crossroads_log: Array = []
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))
	rm.show_crossroads.connect(func(after):
		crossroads_log.append(after)
		rm.handle_crossroads_rest()  # resolve crossroads so the run continues
	)

	rm.start_run()

	# Win matches 1-9 (crossroads fires after match 9 and is auto-resolved above)
	for _i in 9:
		rm.handle_match_won(false)
	assert(crossroads_log.size() == 1, "should have one crossroads after match 9")

	# Win match 10 — crossroads must NOT fire again
	rm.handle_match_won(false)
	assert(crossroads_log.size() == 1,
		"crossroads should NOT fire at match 10 (only at 9 and 21), got %d" % crossroads_log.size())
	rm.queue_free()

func _test_crossroads_rest_adds_2_hp(gs: Node) -> void:
	gs.reset_run()
	gs.hp = 3
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	rm.handle_crossroads_rest()
	assert(gs.hp == 5,
		"crossroads rest should add 2 HP (3 -> 5), got %d" % gs.hp)
	rm.queue_free()

func _test_crossroads_rest_capped_at_max_hp(gs: Node) -> void:
	gs.reset_run()
	gs.hp = GameState.MAX_HP
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	rm.handle_crossroads_rest()
	assert(gs.hp == GameState.MAX_HP,
		"crossroads rest at MAX_HP should not exceed MAX_HP (%d), got %d" % [GameState.MAX_HP, gs.hp])
	rm.queue_free()

func _test_crossroads_whetstone_emits_die_swap(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)

	var swap_log: Array = []
	rm.show_die_swap.connect(func(offered): swap_log.append(offered))

	rm.handle_crossroads_whetstone()
	assert(swap_log.size() == 1,
		"handle_crossroads_whetstone should emit show_die_swap exactly once, got %d" % swap_log.size())
	rm.queue_free()

func _test_periodic_die_swap_removed(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))
	# Resolve crossroads with rest so show_die_swap is never triggered by crossroads
	rm.show_crossroads.connect(func(_after): rm.handle_crossroads_rest())

	var swap_log: Array = []
	rm.show_die_swap.connect(func(offered): swap_log.append(offered))

	rm.start_run()

	# Advance 10 matches — old code would have triggered periodic swaps at 5 and 10
	for _i in 10:
		rm.handle_match_won(false)

	assert(swap_log.size() == 0,
		"show_die_swap should NEVER fire during normal match progression (periodic swap removed), got %d" % swap_log.size())
	rm.queue_free()
