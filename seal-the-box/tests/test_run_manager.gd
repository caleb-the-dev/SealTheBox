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

	_test_reset_run_sets_hp(gs)
	_test_reset_run_sets_starting_dice_pool(gs)
	_test_reset_match_preserves_hp(gs)
	_test_reset_match_preserves_dice_pool(gs)
	_test_initial_hand_layout(gs)
	_test_run_manager_start_run(gs)
	_test_run_manager_match_lost()
	_test_reward_dice_unique()
	_test_threshold_win_triggers_rotation(gs)
	_test_critical_win_triggers_reward_then_rotation(gs)
	_test_rotation_after_match_1(gs)
	_test_rotation_after_match_3(gs)
	_test_rotation_discards_slot_0_regardless_of_charges(gs)
	_test_charges_decrement(gs)
	_test_exhausted_ability_blocked(gs)
	_test_owned_powers_persists_across_reset_match(gs)
	_test_owned_powers_cleared_by_reset_run(gs)
	_test_power_library_loads_all_powers()
	print("All RunManager tests passed!")
	quit()

# ── preserved tests ──────────────────────────────────────────────────────────

func _test_reset_run_sets_hp(gs: Node) -> void:
	gs.hp = 1
	gs.reset_run()
	assert(gs.hp == 6, "reset_run should restore HP to 6, got %d" % gs.hp)

func _test_reset_run_sets_starting_dice_pool(gs: Node) -> void:
	gs.dice_pool = []
	gs.reset_run()
	assert(gs.dice_pool.size() == 7, "starting pool should be 7 dice, got %d" % gs.dice_pool.size())
	var faces = gs.dice_pool.map(func(d): return d.faces)
	faces.sort()
	assert(faces == [4, 6, 6, 6, 6, 8, 8], "starting pool should be 1d4+4d6+2d8, got %s" % str(faces))

func _test_reset_match_preserves_hp(gs: Node) -> void:
	gs.reset_run()
	gs.hp = 3
	gs.reset_match()
	assert(gs.hp == 3, "reset_match should not change HP, got %d" % gs.hp)

func _test_reset_match_preserves_dice_pool(gs: Node) -> void:
	gs.reset_run()
	var extra = Die.new(12)
	gs.dice_pool.append(extra)
	var pool_size = gs.dice_pool.size()
	gs.reset_match()
	assert(gs.dice_pool.size() == pool_size, "reset_match should not change dice_pool size, got %d" % gs.dice_pool.size())
	assert(extra in gs.dice_pool, "reset_match should not remove the extra die from dice_pool")

func _test_run_manager_start_run(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var counts = {"next_match": 0}
	rm.next_match_ready.connect(func(_box): counts["next_match"] += 1)

	rm.start_run()
	assert(rm.match_number == 1, "match_number should be 1 after start_run, got %d" % rm.match_number)
	assert(counts["next_match"] == 1, "start_run should emit next_match_ready once, got %d" % counts["next_match"])
	assert(gs.hp == 6, "start_run should reset HP to 6, got %d" % gs.hp)
	rm.queue_free()

func _test_run_manager_match_lost() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var run_over_log: Array = []
	rm.next_match_ready.connect(func(_box): pass)
	rm.run_over.connect(func(mn): run_over_log.append(mn))

	rm.start_run()
	rm.handle_match_lost()
	assert(run_over_log.size() == 1, "match lost should emit run_over once")
	assert(run_over_log[0] == 1, "run_over on match 1 should report 1, got %d" % run_over_log[0])
	rm.queue_free()

func _test_reward_dice_unique() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	for i in 20:
		var picks = rm._pick_reward_dice(3)
		assert(picks.size() == 3, "should pick 3 dice, got %d" % picks.size())
		var seen = {}
		for face in picks:
			assert(not face in seen, "duplicate face %d in picks %s" % [face, str(picks)])
			seen[face] = true
			assert(face in RunManager.REWARD_DIE_FACES, "face %d not in reward pool" % face)
	rm.queue_free()

# ── new ability-hand tests ────────────────────────────────────────────────────

func _test_initial_hand_layout(gs: Node) -> void:
	gs.reset_run()
	assert(gs.ability_hand.size() == 3, "ability_hand should have 3 slots, got %d" % gs.ability_hand.size())
	assert(gs.ability_hand[0] == null, "slot 0 should be null initially")
	assert(gs.ability_hand[1] == null, "slot 1 should be null initially")
	assert(gs.ability_hand[2] != null, "slot 2 should have the starter ability")

func _test_threshold_win_triggers_rotation(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var reward_count = [0]
	var rotation_count = [0]
	var next_match_log: Array = []
	rm.next_match_ready.connect(func(box): next_match_log.append(box))
	rm.show_reward.connect(func(_f): reward_count[0] += 1)
	rm.show_rotation_offer.connect(func(opts):
		rotation_count[0] += 1
		rm.handle_rotation_pick(opts[0])
	)

	rm.start_run()
	assert(next_match_log.size() == 1, "start_run should emit next_match_ready once")

	rm.handle_match_won(false)
	assert(reward_count[0] == 0, "threshold win should NOT emit show_reward")
	assert(rotation_count[0] == 1, "threshold win should emit show_rotation_offer once")
	assert(next_match_log.size() == 2, "after rotation pick, next_match_ready should fire")
	assert(rm.match_number == 2, "match_number should be 2, got %d" % rm.match_number)
	rm.queue_free()

func _test_critical_win_triggers_reward_then_rotation(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var reward_faces_log: Array = []
	var rotation_count = [0]
	var next_match_log: Array = []
	rm.next_match_ready.connect(func(box): next_match_log.append(box))
	rm.show_reward.connect(func(faces): reward_faces_log.append(faces.duplicate()))
	rm.show_rotation_offer.connect(func(opts):
		rotation_count[0] += 1
		rm.handle_rotation_pick(opts[0])
	)

	rm.start_run()                    # next_match_log: 1
	rm.handle_match_won(true)         # show_reward fires; rotation NOT yet
	assert(reward_faces_log.size() == 1, "critical win should emit show_reward once")
	assert(rotation_count[0] == 0, "rotation offer should not fire until reward is picked")
	assert(next_match_log.size() == 1, "next_match_ready should NOT fire before rotation resolved")

	var faces = reward_faces_log[0]
	assert(faces.size() == 3, "should offer 3 reward dice, got %d" % faces.size())
	rm.handle_reward_picked(faces[0])
	assert(rotation_count[0] == 1, "show_rotation_offer should fire after reward pick")
	assert(next_match_log.size() == 2, "next_match_ready should fire after rotation pick, got %d" % next_match_log.size())
	assert(rm.match_number == 2, "match_number should be 2, got %d" % rm.match_number)
	rm.queue_free()

func _test_rotation_after_match_1(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	var starter = gs.ability_hand[2]
	assert(starter != null, "starter ability should be in slot 2")

	rm.handle_match_won(false)

	assert(gs.ability_hand[0] == null, "slot 0 should still be null after match 1 rotation")
	assert(gs.ability_hand[1] == starter, "slot 1 should hold the starter (shifted from slot 2)")
	assert(gs.ability_hand[2] != null, "slot 2 should hold the newly picked ability")
	rm.queue_free()

func _test_rotation_after_match_3(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	var starter = gs.ability_hand[2]

	rm.handle_match_won(false)  # match 1: null→slot0, starter→slot1, pick_A→slot2
	var pick_A = gs.ability_hand[2]

	rm.handle_match_won(false)  # match 2: starter→slot0, pick_A→slot1, pick_B→slot2
	var pick_B = gs.ability_hand[2]

	assert(gs.ability_hand[0] == starter, "slot 0 should hold starter after match 2 rotation")

	rm.handle_match_won(false)  # match 3: starter discarded, pick_A→slot0, pick_B→slot1, pick_C→slot2

	assert(gs.ability_hand[0] != starter, "slot 0 should NOT hold starter after match 3 (starter was discarded)")
	# handle_rotation_pick shifts references without duplicating, so identity check is valid
	assert(gs.ability_hand[0] == pick_A, "slot 0 should hold pick_A (shifted up from slot 1)")
	assert(gs.ability_hand[1] == pick_B, "slot 1 should hold pick_B (shifted up from slot 2)")
	assert(gs.ability_hand[2] != null, "slot 2 should have a fresh pick")
	rm.queue_free()

func _test_rotation_discards_slot_0_regardless_of_charges(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	var lib = Engine.get_singleton("AbilityLibrary")
	var ability_slot0 = lib.get_ability("reroll_all").duplicate()
	ability_slot0.charges = 1  # has charges — should still be discarded
	var ability_slot1 = lib.get_ability("greater_1").duplicate()
	var ability_slot2 = lib.get_ability("lesser_1").duplicate()
	gs.ability_hand = [ability_slot0, ability_slot1, ability_slot2]
	rm.match_number = 1
	rm._boxes = Engine.get_singleton("BoxLibrary").get_ordered()

	var picked_log: Array = []
	rm.show_rotation_offer.connect(func(opts):
		picked_log.append(opts[0])
		rm.handle_rotation_pick(opts[0])
	)

	rm.handle_match_won(false)

	assert(picked_log.size() == 1, "rotation offer should have fired once, got %d" % picked_log.size())
	var picked_option = picked_log[0]
	assert(gs.ability_hand[0] == ability_slot1, "slot 0 should now hold what was in slot 1")
	assert(gs.ability_hand[1] == ability_slot2, "slot 1 should now hold what was in slot 2")
	assert(gs.ability_hand[2] == picked_option, "slot 2 should hold the newly picked ability")
	assert(not ability_slot0 in gs.ability_hand, "old slot 0 should be gone (discarded despite having charges)")
	rm.queue_free()

func _test_charges_decrement(gs: Node) -> void:
	gs.reset_run()
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("greater_1").duplicate()
	assert(ability.charges == 3, "greater_1 should start with 3 charges, got %d" % ability.charges)
	assert(ability.max_charges == 3, "greater_1 max_charges should be 3, got %d" % ability.max_charges)
	gs.ability_hand = [null, null, ability]

	var round_mgr = RoundManager.new()
	get_root().add_child(round_mgr)
	var box_lib = Engine.get_singleton("BoxLibrary")
	round_mgr.start_match(box_lib.get_ordered()[0])
	# Enter act phase by rolling one die
	round_mgr.commit_roll([gs.dice_hand[0]])

	var result1 = round_mgr.use_ability(ability, gs.dice_hand[0])
	assert(result1 == true, "first use should succeed")
	assert(ability.charges == 2, "charges should be 2 after first use, got %d" % ability.charges)

	var result2 = round_mgr.use_ability(ability, gs.dice_hand[0])
	assert(result2 == true, "second use should succeed")
	assert(ability.charges == 1, "charges should be 1 after second use, got %d" % ability.charges)

	var result3 = round_mgr.use_ability(ability, gs.dice_hand[0])
	assert(result3 == true, "third use should succeed")
	assert(ability.charges == 0, "charges should be 0 after third use, got %d" % ability.charges)

	round_mgr.queue_free()

func _test_owned_powers_persists_across_reset_match(gs: Node) -> void:
	gs.reset_run()
	var fake_power = {"id": "test_power"}
	gs.owned_powers.append(fake_power)
	gs.reset_match()
	assert(gs.owned_powers.size() == 1, "reset_match should preserve owned_powers, got %d" % gs.owned_powers.size())

func _test_owned_powers_cleared_by_reset_run(gs: Node) -> void:
	gs.owned_powers = [{"id": "test_power"}, {"id": "another"}]
	gs.reset_run()
	assert(gs.owned_powers.size() == 0, "reset_run should clear owned_powers, got %d" % gs.owned_powers.size())

func _test_exhausted_ability_blocked(gs: Node) -> void:
	gs.reset_run()
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("greater_1").duplicate()
	ability.charges = 0
	gs.ability_hand = [null, null, ability]

	var round_mgr = RoundManager.new()
	get_root().add_child(round_mgr)
	var box_lib = Engine.get_singleton("BoxLibrary")
	round_mgr.start_match(box_lib.get_ordered()[0])
	round_mgr.commit_roll([gs.dice_hand[0]])

	var result = round_mgr.use_ability(ability, gs.dice_hand[0])
	assert(result == false, "use_ability should return false for 0-charge ability")
	assert(ability.charges == 0, "charges should remain 0 after failed use")
	round_mgr.queue_free()

func _test_power_library_loads_all_powers() -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	assert(power_lib != null, "PowerLibrary singleton should be registered")
	var all_powers = power_lib.get_all()
	assert(all_powers.size() == 5, "PowerLibrary should have 5 powers, got %d" % all_powers.size())
	var ids = all_powers.map(func(p): return p.id)
	assert("lighter_box" in ids, "lighter_box should be in PowerLibrary")
	assert("eager" in ids, "eager should be in PowerLibrary")
	assert("tab_9_bounty" in ids, "tab_9_bounty should be in PowerLibrary")
	assert("bonus_seal" in ids, "bonus_seal should be in PowerLibrary")
	assert("box_shutter" in ids, "box_shutter should be in PowerLibrary")
	var power = power_lib.get_power("lighter_box")
	assert(power != null, "get_power('lighter_box') should return a PowerData")
	assert(power.name == "Lighter Box", "lighter_box name should be 'Lighter Box', got '%s'" % power.name)
