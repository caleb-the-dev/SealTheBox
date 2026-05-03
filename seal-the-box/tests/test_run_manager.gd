extends SceneTree

func _init() -> void:
	var lib = load("res://scripts/globals/ability_library.gd").new()
	lib.name = "AbilityLibrary"
	get_root().add_child(lib)
	lib._ready()
	Engine.register_singleton("AbilityLibrary", lib)

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)
	Engine.register_singleton("GameState", gs)

	_test_reset_run_sets_hp(gs)
	_test_reset_run_sets_starting_dice_pool(gs)
	_test_reset_match_preserves_hp(gs)
	_test_reset_match_preserves_dice_pool(gs)
	_test_run_manager_start_run()
	_test_run_manager_match_progression()
	_test_run_manager_final_match_win()
	_test_run_manager_match_lost()
	_test_reward_dice_unique()
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
	rm.next_match_ready.connect(func(): counts["next_match"] += 1)

	rm.start_run()
	assert(rm.match_number == 1, "match_number should be 1 after start_run, got %d" % rm.match_number)
	assert(counts["next_match"] == 1, "start_run should emit next_match_ready once, got %d" % counts["next_match"])
	var gs = Engine.get_singleton("GameState")
	assert(gs.hp == 6, "start_run should reset HP to 6, got %d" % gs.hp)
	rm.queue_free()

func _test_run_manager_match_progression() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var reward_faces_log: Array = []
	rm.next_match_ready.connect(func(): pass)
	rm.show_reward.connect(func(faces): reward_faces_log.append(faces.duplicate()))

	rm.start_run()
	rm.handle_match_won(false)
	assert(reward_faces_log.size() == 1, "match 1 win should emit show_reward once")
	var faces = reward_faces_log[0]
	assert(faces.size() == 3, "should offer 3 reward dice, got %d" % faces.size())

	rm.advance_to_next_match(faces[0])
	assert(rm.match_number == 2, "match_number should be 2 after advancing, got %d" % rm.match_number)
	rm.queue_free()

func _test_run_manager_final_match_win() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var run_won_log: Array = []
	var show_reward_counts = [0]
	rm.next_match_ready.connect(func(): pass)
	rm.show_reward.connect(func(_f): show_reward_counts[0] += 1)
	rm.run_won.connect(func(mn, hp): run_won_log.append({"match": mn, "hp": hp}))

	rm.start_run()
	rm.handle_match_won(false)    # match 1 → show_reward
	rm.advance_to_next_match(6)  # → match 2
	rm.handle_match_won(false)    # match 2 → show_reward
	rm.advance_to_next_match(4)  # → match 3
	show_reward_counts[0] = 0    # reset counter; match 3 win must NOT emit show_reward
	rm.handle_match_won(true)    # match 3 → run_won
	assert(run_won_log.size() == 1, "match 3 win should emit run_won once")
	assert(show_reward_counts[0] == 0, "match 3 win must NOT emit show_reward")
	assert(run_won_log[0]["match"] == 3, "run_won should report match 3, got %d" % run_won_log[0]["match"])
	rm.queue_free()

func _test_run_manager_match_lost() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var run_over_log: Array = []
	rm.next_match_ready.connect(func(): pass)
	rm.run_over.connect(func(mn): run_over_log.append(mn))

	rm.start_run()
	rm.handle_match_lost()
	assert(run_over_log.size() == 1, "match lost should emit run_over once")
	assert(run_over_log[0] == 1, "run_over on match 1 should report 1, got %d" % run_over_log[0])
	rm.queue_free()

func _test_reward_dice_unique() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	for i in 20:
		var picks = rm._pick_reward_dice(3)
		assert(picks.size() == 3, "should pick 3 dice, got %d" % picks.size())
		var seen = {}
		for face in picks:
			assert(not face in seen, "duplicate face %d in picks %s" % [face, str(picks)])
			seen[face] = true
			assert(face in RunManager.REWARD_DIE_FACES, "face %d not in reward pool" % face)
	rm.queue_free()
