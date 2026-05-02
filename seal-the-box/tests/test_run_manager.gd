extends SceneTree

func _init() -> void:
	# Bootstrap autoloads — headless --script does not load project autoloads automatically
	var lib = load("res://scripts/globals/ability_library.gd").new()
	lib.name = "AbilityLibrary"
	get_root().add_child(lib)
	lib._ready()

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)

	_test_reset_run_sets_hp(gs)
	_test_reset_run_sets_starting_dice_pool(gs)
	_test_reset_match_preserves_hp(gs)
	_test_reset_match_preserves_dice_pool(gs)
	print("GameState split tests passed!")
	quit()

func _test_reset_run_sets_hp(gs: Node) -> void:
	gs.hp = 1
	gs.reset_run()
	assert(gs.hp == 5, "reset_run should restore HP to 5, got %d" % gs.hp)

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
	gs.dice_pool.append(Die.new(12))
	var pool_size = gs.dice_pool.size()
	gs.reset_match()
	assert(gs.dice_pool.size() == pool_size, "reset_match should not clear dice_pool, got %d" % gs.dice_pool.size())
