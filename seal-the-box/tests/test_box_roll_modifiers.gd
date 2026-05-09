extends SceneTree

# Tests for BoxRollModifiers registry and RoundManager integration.
# Run headless: godot --headless --path seal-the-box --script tests/test_box_roll_modifiers.gd

func _init() -> void:
	# Set up minimal singletons for RoundManager integration tests.
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

	# Run unit tests (registry, per-modifier logic).
	_test_registry_has_all_six_modifiers()
	_test_heavy_dice_adds_one_to_each_die()
	_test_heavy_dice_ignores_dropped()
	_test_weak_dice_subtracts_one_floor_one()
	_test_weak_dice_floors_at_one()
	_test_weak_dice_ignores_dropped()
	_test_halving_box_returns_total_override()
	_test_halving_box_floors()
	_test_halving_box_does_not_mutate_dice()
	_test_doubling_box_returns_total_override()
	_test_doubling_box_does_not_mutate_dice()
	_test_exploding_ones_value_increases()
	_test_exploding_ones_non_one_unchanged()
	_test_exploding_ones_chain_depth_cap()
	_test_high_die_doubles_highest_counts_double()
	_test_high_die_doubles_single_die()
	_test_high_die_doubles_tie_only_one_doubled()
	_test_is_total_override_flags()
	_test_no_modifier_for_classic_box()

	# Integration tests with RoundManager.
	_test_round_manager_heavy_dice_wires_into_commit_roll(gs)
	_test_round_manager_halving_box_total_override_in_attempt_seal(gs)
	_test_round_manager_doubling_box_total_override_in_attempt_seal(gs)
	_test_round_manager_high_die_doubles_override_in_attempt_seal(gs)
	_test_round_manager_no_modifier_classic_sums_normally(gs)

	print("All BoxRollModifiers tests passed!")
	quit()

# ---------------------------------------------------------------------------
# Helper: make a rolled Die with a forced value.
# ---------------------------------------------------------------------------
func _make_die(faces: int, value: int) -> Die:
	var d := Die.new(faces)
	d.value = value
	d.rolled = true
	return d

func _make_dropped_die(faces: int, value: int) -> Die:
	var d := _make_die(faces, value)
	d.dropped = true
	return d

# ---------------------------------------------------------------------------
# Registry tests
# ---------------------------------------------------------------------------

func _test_registry_has_all_six_modifiers() -> void:
	var ids := ["heavy_dice", "weak_dice", "halving_box", "doubling_box",
				"exploding_ones", "high_die_doubles"]
	for id in ids:
		assert(BoxRollModifiers.has_modifier(id),
			"BoxRollModifiers should have modifier for '%s'" % id)

func _test_no_modifier_for_classic_box() -> void:
	assert(not BoxRollModifiers.has_modifier("classic"),
		"classic should have no roll modifier")
	assert(not BoxRollModifiers.has_modifier(""),
		"empty string should have no roll modifier")

func _test_is_total_override_flags() -> void:
	assert(BoxRollModifiers.is_total_override("halving_box"),  "halving_box should be total-override")
	assert(BoxRollModifiers.is_total_override("doubling_box"), "doubling_box should be total-override")
	assert(BoxRollModifiers.is_total_override("high_die_doubles"), "high_die_doubles should be total-override")
	assert(not BoxRollModifiers.is_total_override("heavy_dice"),  "heavy_dice should not be total-override")
	assert(not BoxRollModifiers.is_total_override("weak_dice"),   "weak_dice should not be total-override")
	assert(not BoxRollModifiers.is_total_override("exploding_ones"), "exploding_ones should not be total-override")

# ---------------------------------------------------------------------------
# heavy_dice
# ---------------------------------------------------------------------------

func _test_heavy_dice_adds_one_to_each_die() -> void:
	var dice := [_make_die(6, 3), _make_die(6, 5), _make_die(8, 2)]
	BoxRollModifiers.apply_dice_mutation("heavy_dice", dice)
	assert(dice[0].value == 4, "heavy_dice: 3+1=4, got %d" % dice[0].value)
	assert(dice[1].value == 6, "heavy_dice: 5+1=6, got %d" % dice[1].value)
	assert(dice[2].value == 3, "heavy_dice: 2+1=3, got %d" % dice[2].value)

func _test_heavy_dice_ignores_dropped() -> void:
	var dice := [_make_die(6, 3), _make_dropped_die(6, 5)]
	BoxRollModifiers.apply_dice_mutation("heavy_dice", dice)
	assert(dice[0].value == 4, "heavy_dice: live die 3+1=4, got %d" % dice[0].value)
	assert(dice[1].value == 5, "heavy_dice: dropped die unchanged, got %d" % dice[1].value)

# ---------------------------------------------------------------------------
# weak_dice
# ---------------------------------------------------------------------------

func _test_weak_dice_subtracts_one_floor_one() -> void:
	var dice := [_make_die(6, 4), _make_die(6, 2)]
	BoxRollModifiers.apply_dice_mutation("weak_dice", dice)
	assert(dice[0].value == 3, "weak_dice: 4-1=3, got %d" % dice[0].value)
	assert(dice[1].value == 1, "weak_dice: 2-1=1, got %d" % dice[1].value)

func _test_weak_dice_floors_at_one() -> void:
	var dice := [_make_die(6, 1)]
	BoxRollModifiers.apply_dice_mutation("weak_dice", dice)
	assert(dice[0].value == 1, "weak_dice: 1-1 should floor at 1, got %d" % dice[0].value)

func _test_weak_dice_ignores_dropped() -> void:
	var dice := [_make_die(6, 3), _make_dropped_die(6, 4)]
	BoxRollModifiers.apply_dice_mutation("weak_dice", dice)
	assert(dice[0].value == 2, "weak_dice: live die 3-1=2, got %d" % dice[0].value)
	assert(dice[1].value == 4, "weak_dice: dropped die unchanged, got %d" % dice[1].value)

# ---------------------------------------------------------------------------
# halving_box
# ---------------------------------------------------------------------------

func _test_halving_box_returns_total_override() -> void:
	var dice := [_make_die(6, 4), _make_die(6, 6)]  # total=10 → 5
	var result: int = BoxRollModifiers.compute_total("halving_box", dice)
	assert(result == 5, "halving_box: 10/2=5, got %d" % result)

func _test_halving_box_floors() -> void:
	var dice := [_make_die(6, 3), _make_die(6, 4)]  # total=7 → floor(7/2)=3
	var result: int = BoxRollModifiers.compute_total("halving_box", dice)
	assert(result == 3, "halving_box: floor(7/2)=3, got %d" % result)

func _test_halving_box_does_not_mutate_dice() -> void:
	var dice := [_make_die(6, 4), _make_die(6, 6)]
	var before := [dice[0].value, dice[1].value]
	BoxRollModifiers.compute_total("halving_box", dice)
	assert(dice[0].value == before[0], "halving_box should not mutate die[0]")
	assert(dice[1].value == before[1], "halving_box should not mutate die[1]")

# ---------------------------------------------------------------------------
# doubling_box
# ---------------------------------------------------------------------------

func _test_doubling_box_returns_total_override() -> void:
	var dice := [_make_die(6, 3), _make_die(6, 4)]  # total=7 → 14
	var result: int = BoxRollModifiers.compute_total("doubling_box", dice)
	assert(result == 14, "doubling_box: 7*2=14, got %d" % result)

func _test_doubling_box_does_not_mutate_dice() -> void:
	var dice := [_make_die(6, 3), _make_die(6, 4)]
	var before := [dice[0].value, dice[1].value]
	BoxRollModifiers.compute_total("doubling_box", dice)
	assert(dice[0].value == before[0], "doubling_box should not mutate die[0]")
	assert(dice[1].value == before[1], "doubling_box should not mutate die[1]")

# ---------------------------------------------------------------------------
# exploding_ones
# ---------------------------------------------------------------------------

func _test_exploding_ones_value_increases() -> void:
	# A die showing 1 must end up with value >= 2 (original 1 + at least 1 from reroll).
	var die := _make_die(6, 1)
	BoxRollModifiers.apply_dice_mutation("exploding_ones", [die])
	assert(die.value >= 2, "exploding_ones: value starting at 1 must be >= 2, got %d" % die.value)

func _test_exploding_ones_non_one_unchanged() -> void:
	var die := _make_die(6, 3)
	BoxRollModifiers.apply_dice_mutation("exploding_ones", [die])
	assert(die.value == 3, "exploding_ones: non-1 die must be unchanged, got %d" % die.value)

func _test_exploding_ones_chain_depth_cap() -> void:
	# Simulate worst-case: forcibly test that _explode_die terminates.
	# We can't control rng, but we verify that a die=1 on a d1-like scenario
	# doesn't hang. A d1 die always rolls 1, so we verify depth cap works.
	# Create a special 1-face die (randi_range(1,1) always returns 1 → always explodes).
	var die := _make_die(1, 1)
	# Should return quickly without stack overflow.
	BoxRollModifiers.apply_dice_mutation("exploding_ones", [die])
	# With depth cap 10: 1 base + 10 explosions each adding 1 → value should be 11.
	assert(die.value == 11,
		"exploding_ones: d1 starting at 1 with depth cap 10 should yield 11, got %d" % die.value)

# ---------------------------------------------------------------------------
# high_die_doubles
# ---------------------------------------------------------------------------

func _test_high_die_doubles_highest_counts_double() -> void:
	# [3, 5, 2] → highest=5, total = 3 + 5*2 + 2 = 15.
	var dice := [_make_die(6, 3), _make_die(8, 5), _make_die(6, 2)]
	var result: int = BoxRollModifiers.compute_total("high_die_doubles", dice)
	assert(result == 15, "high_die_doubles: [3,5,2] → 3+10+2=15, got %d" % result)

func _test_high_die_doubles_single_die() -> void:
	var dice := [_make_die(6, 4)]
	var result: int = BoxRollModifiers.compute_total("high_die_doubles", dice)
	assert(result == 8, "high_die_doubles: single die 4 → 4*2=8, got %d" % result)

func _test_high_die_doubles_tie_only_one_doubled() -> void:
	# [5, 5, 3] — both dice are tied at max. Only one should be doubled.
	# Total = 5*2 + 5 + 3 = 18 (or 5 + 5*2 + 3 = 18 either way).
	var dice := [_make_die(6, 5), _make_die(6, 5), _make_die(6, 3)]
	var result: int = BoxRollModifiers.compute_total("high_die_doubles", dice)
	assert(result == 18, "high_die_doubles: [5,5,3] tie → one doubled: 10+5+3=18, got %d" % result)

# ---------------------------------------------------------------------------
# RoundManager integration tests
# ---------------------------------------------------------------------------

func _make_box_with_modifier(id: String, tabs: Array[int], threshold: int) -> BoxDefinition:
	var box := BoxDefinition.new()
	box.id = id
	box.tabs.assign(tabs)
	box.win_threshold = threshold
	return box

func _test_round_manager_heavy_dice_wires_into_commit_roll(gs: Node) -> void:
	gs.reset_run()
	# Build a heavy_dice box.
	var box := _make_box_with_modifier("heavy_dice", [2, 3, 4, 5, 6, 7, 8, 9], 12)
	var rm := RoundManager.new()
	rm.start_match(box)
	# Call commit_roll — heavy_dice applies +1 to each rolled die.
	# Dice values are random post-roll, but after the modifier each must be >= 2
	# (minimum raw roll = 1, +1 heavy_dice = 2).
	rm.commit_roll(gs.dice_hand)
	for die in gs.dice_hand:
		if die.rolled and not die.dropped:
			assert(die.value >= 2,
				"heavy_dice: after commit_roll every die must be >= 2 (raw >=1 + 1), got %d" % die.value)

func _test_round_manager_halving_box_total_override_in_attempt_seal(gs: Node) -> void:
	gs.reset_run()
	# halving_box tabs: 1;2;3;4;5;6 (sum=21, threshold=6).
	var box := _make_box_with_modifier("halving_box", [1, 2, 3, 4, 5, 6], 6)
	var rm := RoundManager.new()
	rm.start_match(box)
	# Transition to "act" phase without rolling any dice (empty commit).
	rm.commit_roll([])
	# Now set known values: 6+2=8 raw → halved=4. Seal tab 4.
	gs.dice_hand[0].value = 6
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 2
	gs.dice_hand[1].rolled = true
	gs.dice_hand[2].rolled = false
	var sealed := rm.attempt_seal(gs.dice_hand, [4])
	assert(sealed, "halving_box: raw total 8 → halved 4 should seal tab [4]")

func _test_round_manager_doubling_box_total_override_in_attempt_seal(gs: Node) -> void:
	gs.reset_run()
	# doubling_box tabs: 4;6;8;10;12;14;16.
	var box := _make_box_with_modifier("doubling_box", [4, 6, 8, 10, 12, 14, 16], 20)
	var rm := RoundManager.new()
	rm.start_match(box)
	# Transition to "act" without rolling.
	rm.commit_roll([])
	# Set hand: d0=3, d1=2, d2=unrolled → raw total=5 → doubled=10. Seal tab 10.
	gs.dice_hand[0].value = 3
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 2
	gs.dice_hand[1].rolled = true
	gs.dice_hand[2].rolled = false
	var sealed := rm.attempt_seal(gs.dice_hand, [10])
	assert(sealed, "doubling_box: raw total 5 → doubled 10 should seal tab [10]")

func _test_round_manager_high_die_doubles_override_in_attempt_seal(gs: Node) -> void:
	gs.reset_run()
	var box := _make_box_with_modifier("high_die_doubles", [1, 2, 3, 4, 5, 6, 7, 8, 9], 13)
	var rm := RoundManager.new()
	rm.start_match(box)
	# Transition to "act" without rolling.
	rm.commit_roll([])
	# Set hand: d0=2, d1=3, d2=unrolled → high=3, total = 2 + 3*2 = 8.
	gs.dice_hand[0].value = 2
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 3
	gs.dice_hand[1].rolled = true
	gs.dice_hand[2].rolled = false
	var sealed := rm.attempt_seal(gs.dice_hand, [8])
	assert(sealed, "high_die_doubles: [2,3] → 2+6=8 should seal tab [8]")

func _test_round_manager_no_modifier_classic_sums_normally(gs: Node) -> void:
	gs.reset_run()
	var box := BoxDefinition.new()
	box.id = "classic"
	box.tabs.assign([1, 2, 3, 4, 5, 6, 7, 8, 9])
	box.win_threshold = 11
	var rm := RoundManager.new()
	rm.start_match(box)
	# Transition to "act" without rolling.
	rm.commit_roll([])
	# Set hand: d0=4, d1=5, d2=unrolled → natural total = 9.
	gs.dice_hand[0].value = 4
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 5
	gs.dice_hand[1].rolled = true
	gs.dice_hand[2].rolled = false
	var sealed := rm.attempt_seal(gs.dice_hand, [4, 5])
	assert(sealed, "classic: natural sum 9 should seal tabs [4,5]")
