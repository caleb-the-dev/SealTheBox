extends SceneTree

func _init() -> void:
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

	_test_reset_run_sets_hp(gs)
	_test_reset_run_sets_starting_dice_pool(gs)
	_test_reset_match_preserves_hp(gs)
	_test_reset_match_preserves_dice_pool(gs)
	_test_run_manager_start_run()
	_test_run_manager_match_1_advances_without_reward()
	_test_run_manager_final_match_win_then_reward()
	_test_ability_hand_persists_across_matches()
	_test_run_manager_match_lost()
	_test_reward_dice_unique()
	_test_ability_offer_swap_updates_hand()
	_test_ability_offer_skip_leaves_hand_unchanged()
	print("All RunManager tests passed!")
	quit()

func _test_reset_run_sets_hp(gs: Node) -> void:
	gs.hp = 1
	gs.reset_run()
	assert(gs.hp == 6, "reset_run should restore HP to 6, got %d" % gs.hp)

func _test_reset_run_sets_starting_dice_pool(gs: Node) -> void:
	gs.dice_pool = []
	gs.reset_run()
	assert(gs.dice_pool.size() == 5, "starting pool should be 5 dice, got %d" % gs.dice_pool.size())
	var faces = gs.dice_pool.map(func(d): return d.faces)
	faces.sort()
	assert(faces == [4, 6, 6, 6, 8], "starting pool should be 1d4+3d6+1d8, got %s" % str(faces))

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

func _test_run_manager_start_run() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var counts = {"next_match": 0}
	rm.next_match_ready.connect(func(_box): counts["next_match"] += 1)

	rm.start_run()
	assert(rm.match_number == 1, "match_number should be 1 after start_run, got %d" % rm.match_number)
	assert(counts["next_match"] == 1, "start_run should emit next_match_ready once, got %d" % counts["next_match"])
	var gs = Engine.get_singleton("GameState")
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

func _test_run_manager_match_1_advances_without_reward() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var reward_count = [0]
	var next_match_boxes: Array = []
	rm.next_match_ready.connect(func(box): next_match_boxes.append(box))
	rm.show_reward.connect(func(_f): reward_count[0] += 1)

	rm.start_run()
	assert(next_match_boxes.size() == 1, "start_run should emit next_match_ready once")
	assert(next_match_boxes[0] != null, "emitted box should not be null")

	rm.handle_match_won(false)
	assert(reward_count[0] == 0, "match 1 win should NOT emit show_reward, got %d" % reward_count[0])
	assert(next_match_boxes.size() == 2, "match 1 win should emit next_match_ready for match 2")
	assert(next_match_boxes[1] != null, "match 2 box should not be null")
	assert(rm.match_number == 2, "match_number should be 2, got %d" % rm.match_number)

	rm.queue_free()

func _test_run_manager_final_match_win_then_reward() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var reward_faces_log: Array = []
	var offer_log: Array = []
	var run_won_log: Array = []
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_reward.connect(func(faces): reward_faces_log.append(faces.duplicate()))
	rm.show_ability_offer.connect(func(a): offer_log.append(a))
	rm.run_won.connect(func(mn, hp): run_won_log.append({"match": mn, "hp": hp}))

	rm.start_run()
	rm.handle_match_won(false)    # match 1 → next_match_ready (no reward)
	assert(reward_faces_log.size() == 0, "match 1 win must NOT emit show_reward")
	rm.handle_match_won(false)    # match 2 → next_match_ready (no reward)
	assert(reward_faces_log.size() == 0, "match 2 win must NOT emit show_reward")
	rm.handle_match_won(true)     # match 3 → show_reward
	assert(reward_faces_log.size() == 1, "match 3 win should emit show_reward once")
	assert(run_won_log.size() == 0, "run_won should NOT fire until reward is picked")

	var faces = reward_faces_log[0]
	assert(faces.size() == 3, "should offer 3 reward dice, got %d" % faces.size())
	rm.handle_reward_picked(faces[0])
	assert(offer_log.size() == 1, "show_ability_offer should fire once after reward pick")
	assert(run_won_log.size() == 0, "run_won should NOT fire before offer resolved")

	rm.handle_ability_offer_result(-1)  # skip the offer
	assert(run_won_log.size() == 1, "run_won should fire after offer resolved")
	assert(run_won_log[0]["match"] == 3, "run_won should report match 3, got %d" % run_won_log[0]["match"])

	rm.queue_free()

func _test_ability_hand_persists_across_matches() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	rm.start_run()
	var gs = Engine.get_singleton("GameState")
	assert(gs.ability_hand.size() == 3, "should start with 3 abilities, got %d" % gs.ability_hand.size())

	var used = gs.ability_hand[0]
	gs.ability_hand.erase(used)
	assert(gs.ability_hand.size() == 2, "ability hand should have 2 after using one")

	rm.handle_match_won(false)
	assert(gs.ability_hand.size() == 2, "ability hand should still have 2 after advancing to match 2, got %d" % gs.ability_hand.size())

	gs.ability_hand = []  # reset so subsequent tests get a fresh hand
	rm.queue_free()

func _test_ability_offer_swap_updates_hand() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var offer_log: Array = []
	var run_won_log: Array = []
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_reward.connect(func(_f): pass)
	rm.show_ability_offer.connect(func(a): offer_log.append(a))
	rm.run_won.connect(func(mn, hp): run_won_log.append({"match": mn, "hp": hp}))

	rm.start_run()
	rm.handle_match_won(false)  # match 1
	rm.handle_match_won(false)  # match 2
	rm.handle_match_won(true)   # match 3 -> show_reward

	var gs = Engine.get_singleton("GameState")
	var original_hand = gs.ability_hand.duplicate()

	rm.handle_reward_picked(6)  # pick a d6

	assert(offer_log.size() == 1, "show_ability_offer should fire after reward pick")
	assert(run_won_log.is_empty(), "run_won should NOT fire before offer resolved")

	var offered = offer_log[0]
	rm.handle_ability_offer_result(0)  # swap slot 0

	assert(run_won_log.size() == 1, "run_won should fire after offer resolved")
	assert(gs.ability_hand[0] == offered, "slot 0 should now hold the offered ability")
	assert(gs.ability_hand[1] == original_hand[1], "slot 1 should be unchanged")
	assert(gs.ability_hand[2] == original_hand[2], "slot 2 should be unchanged")

	rm.queue_free()

func _test_ability_offer_skip_leaves_hand_unchanged() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var offer_log: Array = []
	var run_won_log: Array = []
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_reward.connect(func(_f): pass)
	rm.show_ability_offer.connect(func(a): offer_log.append(a))
	rm.run_won.connect(func(mn, hp): run_won_log.append({"match": mn, "hp": hp}))

	rm.start_run()
	rm.handle_match_won(false)  # match 1
	rm.handle_match_won(false)  # match 2
	rm.handle_match_won(true)   # match 3 -> show_reward

	var gs = Engine.get_singleton("GameState")
	var original_hand = gs.ability_hand.duplicate()

	rm.handle_reward_picked(6)

	assert(offer_log.size() == 1, "show_ability_offer should fire")
	assert(run_won_log.is_empty(), "run_won should not fire before offer resolved")

	rm.handle_ability_offer_result(-1)  # skip

	assert(run_won_log.size() == 1, "run_won should fire after skip")
	assert(gs.ability_hand[0] == original_hand[0], "slot 0 should be unchanged")
	assert(gs.ability_hand[1] == original_hand[1], "slot 1 should be unchanged")
	assert(gs.ability_hand[2] == original_hand[2], "slot 2 should be unchanged")

	rm.queue_free()
