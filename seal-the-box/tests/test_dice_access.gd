extends SceneTree

# Tests for BoxDiceAccess registry and RoundManager integration.
# Run headless: godot --headless --path seal-the-box --script tests/test_dice_access.gd

# Preload BDA so static methods are callable in headless --script mode.
const BDA = preload("res://scripts/match/box_dice_access.gd")

func _init() -> void:
	# Set up minimal singletons.
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

	var power_lib = load("res://scripts/globals/power_library.gd").new()
	power_lib.name = "PowerLibrary"
	get_root().add_child(power_lib)
	power_lib._ready()
	Engine.register_singleton("PowerLibrary", power_lib)

	var power_mgr = load("res://scripts/run/power_manager.gd").new()
	power_mgr.name = "PowerManager"
	get_root().add_child(power_mgr)
	Engine.register_singleton("PowerManager", power_mgr)

	# Registry unit tests.
	_test_registry_has_three_pool_overrides()
	_test_no_pool_override_for_non_dice_boxes()
	_test_has_tax_single()
	_test_has_forced_commit_single()
	_test_has_entry_power_bounty_box()
	_test_bounty_box_power_id_is_phoenix_down()
	# Note: bounty_box and forced_full_commit were dropped from boxes.csv (playtest 2026-05-09).
	# The has_entry_power / has_forced_commit infra is tested above; BoxLibrary-dependent
	# bounty_box tests are removed because bounty_box no longer exists in the library.

	# single_die override.
	_test_single_die_returns_one_die(gs)
	_test_single_die_die_is_from_pool(gs)

	# locked_d8 override.
	_test_locked_d8_removes_d8s(gs)
	_test_locked_d8_keeps_d4_and_d6(gs)

	# locked_d4 override.
	_test_locked_d4_removes_d4(gs)
	_test_locked_d4_keeps_d6_and_d8(gs)

	# Pool override does not mutate persistent pool.
	_test_pool_override_does_not_mutate_persistent_pool(gs)

	# tax_per_roll round-end damage.
	_test_tax_per_roll_no_damage_round_1(gs)
	_test_tax_per_roll_damage_round_2(gs)

	# forced_full_commit leftover damage.
	_test_forced_full_commit_no_damage_when_all_pips_used(gs)
	_test_forced_full_commit_damage_for_leftover_pips(gs)

	# CaseManager marquee deduplication (bounty_box not in pool, expect count=0 ≤ 1).
	_test_bounty_box_at_most_once_in_run()

	print("All test_dice_access tests passed!")
	quit()

# ---------------------------------------------------------------------------
# Helper: build a Die with a specified number of faces.
# ---------------------------------------------------------------------------
func _make_rolled_die(faces: int, value: int) -> Die:
	var d := Die.new(faces)
	d.value = value
	d.rolled = true
	return d

func _make_box_with_id(id: String, tabs: Array[int], threshold: int, tier: String) -> BoxDefinition:
	var box := BoxDefinition.new()
	box.id = id
	box.name = id
	box.tabs.assign(tabs)
	box.win_threshold = threshold
	box.tier = tier
	return box

# ---------------------------------------------------------------------------
# Registry tests
# ---------------------------------------------------------------------------

func _test_registry_has_three_pool_overrides() -> void:
	var ids := ["single_die", "locked_d8", "locked_d4"]
	for id in ids:
		assert(BDA.has_override(id),
			"BDA should have pool override for '%s'" % id)

func _test_no_pool_override_for_non_dice_boxes() -> void:
	var ids := ["classic", "low_evens", "quick_seal", ""]
	for id in ids:
		assert(not BDA.has_override(id),
			"'%s' should NOT have a pool override" % id)

func _test_has_tax_single() -> void:
	assert(BDA.has_tax("tax_per_roll"),   "tax_per_roll should have tax")
	assert(not BDA.has_tax("classic"),    "classic should not have tax")
	assert(not BDA.has_tax("single_die"), "single_die should not have tax")

func _test_has_forced_commit_single() -> void:
	assert(BDA.has_forced_commit("forced_full_commit"),
		"forced_full_commit should have forced commit")
	assert(not BDA.has_forced_commit("classic"),
		"classic should not have forced commit")
	assert(not BDA.has_forced_commit("tax_per_roll"),
		"tax_per_roll should not have forced commit")

func _test_has_entry_power_bounty_box() -> void:
	assert(BDA.has_entry_power("bounty_box"),  "bounty_box should have entry power")
	assert(not BDA.has_entry_power("classic"), "classic should not have entry power")

func _test_bounty_box_power_id_is_phoenix_down() -> void:
	assert(BDA.BOUNTY_BOX_POWER_ID == "phoenix_down",
		"bounty_box power id should be 'phoenix_down', got '%s'" % BDA.BOUNTY_BOX_POWER_ID)

# ---------------------------------------------------------------------------
# single_die
# ---------------------------------------------------------------------------

func _test_single_die_returns_one_die(gs: Node) -> void:
	gs.reset_run()
	var active: Array = BDA.get_active_pool("single_die", gs.dice_pool)
	assert(active.size() == 1, "single_die: active pool should have 1 die, got %d" % active.size())

func _test_single_die_die_is_from_pool(gs: Node) -> void:
	gs.reset_run()
	var active: Array = BDA.get_active_pool("single_die", gs.dice_pool)
	assert(active.size() == 1, "single_die: active pool size should be 1")
	assert(active[0] in gs.dice_pool,
		"single_die: the chosen die must be from the persistent pool")

# ---------------------------------------------------------------------------
# locked_d8
# ---------------------------------------------------------------------------

func _test_locked_d8_removes_d8s(gs: Node) -> void:
	gs.reset_run()
	var active: Array = BDA.get_active_pool("locked_d8", gs.dice_pool)
	for die in active:
		assert(die.faces != 8, "locked_d8: no d8 should remain in active pool, got d%d" % die.faces)

func _test_locked_d8_keeps_d4_and_d6(gs: Node) -> void:
	gs.reset_run()
	var active: Array = BDA.get_active_pool("locked_d8", gs.dice_pool)
	# Pool = 1d4 + 4d6 + 2d8. Remove 2d8 → 5 remain.
	assert(active.size() == 5, "locked_d8: should have 5 dice (1d4+4d6), got %d" % active.size())
	var has_d4 := false
	var has_d6 := false
	for die in active:
		if die.faces == 4: has_d4 = true
		if die.faces == 6: has_d6 = true
	assert(has_d4, "locked_d8: d4 should remain in active pool")
	assert(has_d6, "locked_d8: d6 should remain in active pool")

# ---------------------------------------------------------------------------
# locked_d4
# ---------------------------------------------------------------------------

func _test_locked_d4_removes_d4(gs: Node) -> void:
	gs.reset_run()
	var active: Array = BDA.get_active_pool("locked_d4", gs.dice_pool)
	for die in active:
		assert(die.faces != 4, "locked_d4: no d4 should remain in active pool, got d%d" % die.faces)

func _test_locked_d4_keeps_d6_and_d8(gs: Node) -> void:
	gs.reset_run()
	var active: Array = BDA.get_active_pool("locked_d4", gs.dice_pool)
	# 1d4 removed → 6 dice remain (4d6 + 2d8).
	assert(active.size() == 6, "locked_d4: should have 6 dice (4d6+2d8), got %d" % active.size())
	var has_d6 := false
	var has_d8 := false
	for die in active:
		if die.faces == 6: has_d6 = true
		if die.faces == 8: has_d8 = true
	assert(has_d6, "locked_d4: d6 should remain in active pool")
	assert(has_d8, "locked_d4: d8 should remain in active pool")

# ---------------------------------------------------------------------------
# Pool override does not mutate persistent pool
# ---------------------------------------------------------------------------

func _test_pool_override_does_not_mutate_persistent_pool(gs: Node) -> void:
	gs.reset_run()
	var original_size: int = gs.dice_pool.size()
	BDA.get_active_pool("single_die", gs.dice_pool)
	assert(gs.dice_pool.size() == original_size,
		"single_die override must not mutate persistent pool (size: %d → %d)" % [original_size, gs.dice_pool.size()])
	BDA.get_active_pool("locked_d8", gs.dice_pool)
	assert(gs.dice_pool.size() == original_size,
		"locked_d8 override must not mutate persistent pool")
	BDA.get_active_pool("locked_d4", gs.dice_pool)
	assert(gs.dice_pool.size() == original_size,
		"locked_d4 override must not mutate persistent pool")

# ---------------------------------------------------------------------------
# tax_per_roll round-end damage
# ---------------------------------------------------------------------------

func _test_tax_per_roll_no_damage_round_1(gs: Node) -> void:
	gs.reset_run()
	var box := _make_box_with_id("tax_per_roll", [2, 3, 4, 5, 6], 8, "hard")
	var rm := RoundManager.new()
	rm.start_match(box)
	var hp_before: int = gs.hp
	# Round 1: commit empty roll → end round → no tax expected.
	rm.commit_roll([])
	rm.end_round()
	# end_round fires tax only if round > 1. Round was 1 when end_round was called.
	# After end_round, start_round is called, incrementing to round 2.
	# round_limit for sum=20: ceili(20/15)+1 = 3. Not in overtime.
	assert(gs.hp == hp_before,
		"tax_per_roll: no HP damage on round 1 end, expected %d got %d" % [hp_before, gs.hp])

func _test_tax_per_roll_damage_round_2(gs: Node) -> void:
	gs.reset_run()
	var box := _make_box_with_id("tax_per_roll", [2, 3, 4, 5, 6], 8, "hard")
	var rm := RoundManager.new()
	rm.start_match(box)
	var hp_before: int = gs.hp
	# Round 1: no tax.
	rm.commit_roll([])
	rm.end_round()
	# Round 2: tax fires (round was 2 when end_round called).
	rm.commit_roll([])
	rm.end_round()
	assert(gs.hp == hp_before - 1,
		"tax_per_roll: -1 HP on round 2 end, expected %d got %d" % [hp_before - 1, gs.hp])

# ---------------------------------------------------------------------------
# forced_full_commit leftover damage
# ---------------------------------------------------------------------------

func _test_forced_full_commit_no_damage_when_all_pips_used(gs: Node) -> void:
	gs.reset_run()
	var box := _make_box_with_id("forced_full_commit", [1, 2, 3, 4, 5, 6, 7, 8, 9], 13, "hard")
	var rm := RoundManager.new()
	rm.start_match(box)
	var hp_before: int = gs.hp
	# Manually set dice values for deterministic test.
	gs.dice_hand[0].value = 3
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 2
	gs.dice_hand[1].rolled = true
	gs.dice_hand[2].rolled = false
	# commit_roll with empty array — transitions to act phase without re-rolling.
	rm.commit_roll([])
	# Seal [2, 3] — total = 5 = rolled total (3+2), so no leftover.
	var sealed := rm.attempt_seal(gs.dice_hand, [2, 3])
	assert(sealed, "forced_full_commit: should seal [2,3] with total 5")
	rm.end_round()
	assert(gs.hp == hp_before,
		"forced_full_commit: no damage when all pips sealed, expected %d got %d" % [hp_before, gs.hp])

func _test_forced_full_commit_damage_for_leftover_pips(gs: Node) -> void:
	gs.reset_run()
	var box := _make_box_with_id("forced_full_commit", [1, 2, 3, 4, 5, 6, 7, 8, 9], 13, "hard")
	var rm := RoundManager.new()
	rm.start_match(box)
	var hp_before: int = gs.hp
	# Set dice: total = 6. Seal nothing.
	gs.dice_hand[0].value = 4
	gs.dice_hand[0].rolled = true
	gs.dice_hand[1].value = 2
	gs.dice_hand[1].rolled = true
	gs.dice_hand[2].rolled = false
	rm.commit_roll([])
	# End round without sealing anything → 6 leftover pips → -6 HP.
	rm.end_round()
	assert(gs.hp == hp_before - 6,
		"forced_full_commit: -6 HP for 6 leftover pips, expected %d got %d" % [hp_before - 6, gs.hp])

# ---------------------------------------------------------------------------
# CaseManager marquee deduplication
# ---------------------------------------------------------------------------

func _test_bounty_box_at_most_once_in_run() -> void:
	var cm = load("res://scripts/run/case_manager.gd").new()
	cm.name = "CaseManager_test"
	get_root().add_child(cm)
	for _i in 10:
		cm.reset_run()
		var count := 0
		for j in range(1, 28):
			var box = cm.get_box_for_match(j)
			if box != null and box.id == "bounty_box":
				count += 1
		assert(count <= 1,
			"CaseManager: bounty_box should appear at most once per run, found %d times" % count)
	cm.queue_free()
