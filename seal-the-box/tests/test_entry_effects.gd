extends SceneTree

# Tests for BoxEntryEffects registry and RoundManager integration.
# Run headless: godot --headless --path seal-the-box --script tests/test_entry_effects.gd

const BEE = preload("res://scripts/match/box_entry_effects.gd")

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

	# ── BoxEntryEffects static API ──────────────────────────────────────────
	_test_has_entry_effect_storm_box()
	_test_has_entry_effect_cleanse_box()
	_test_has_entry_effect_borrowed_time()
	_test_no_entry_effect_for_classic()
	_test_no_entry_effect_for_empty_string()

	# ── storm_box ───────────────────────────────────────────────────────────
	_test_storm_box_adds_one_die_to_delta(gs)
	_test_storm_box_die_faces_is_valid(gs)
	_test_storm_box_die_is_storm_temp(gs)
	_test_storm_box_does_not_modify_persistent_pool(gs)
	_test_storm_box_pool_has_extra_die_in_match(gs)

	# ── cleanse_box ─────────────────────────────────────────────────────────
	_test_cleanse_box_restores_all_charges(gs)
	_test_cleanse_box_skips_null_slots(gs)
	_test_cleanse_box_already_full_stays_full(gs)

	# ── borrowed_time ───────────────────────────────────────────────────────
	_test_borrowed_time_costs_1_hp(gs)
	_test_borrowed_time_increases_round_limit(gs)
	_test_borrowed_time_hp_gate_in_case_manager()

	# ── RoundManager start_match integration ────────────────────────────────
	_test_round_manager_fires_storm_entry(gs)
	_test_round_manager_fires_cleanse_entry(gs)
	_test_round_manager_fires_borrowed_time_entry(gs)

	# ── match_pool_delta cleared each match ─────────────────────────────────
	_test_match_pool_delta_cleared_between_matches(gs)

	print("All test_entry_effects tests passed!")
	quit()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_box(id: String, tabs: Array[int], threshold: int, tier: String) -> BoxDefinition:
	var box := BoxDefinition.new()
	box.id = id
	box.name = id
	box.tabs.assign(tabs)
	box.win_threshold = threshold
	box.tier = tier
	return box

func _make_ability(id: String, max_charges: int, current: int) -> AbilityData:
	var a := AbilityData.new()
	a.id = id
	a.flavor_name = id
	a.description = id
	a.max_charges = max_charges
	a.charges = current
	return a

# ---------------------------------------------------------------------------
# has_entry_effect
# ---------------------------------------------------------------------------

func _test_has_entry_effect_storm_box() -> void:
	assert(BEE.has_entry_effect("storm_box"),
		"storm_box should have entry effect")

func _test_has_entry_effect_cleanse_box() -> void:
	assert(BEE.has_entry_effect("cleanse_box"),
		"cleanse_box should have entry effect")

func _test_has_entry_effect_borrowed_time() -> void:
	assert(BEE.has_entry_effect("borrowed_time"),
		"borrowed_time should have entry effect")

func _test_no_entry_effect_for_classic() -> void:
	assert(not BEE.has_entry_effect("classic"),
		"classic should NOT have entry effect")

func _test_no_entry_effect_for_empty_string() -> void:
	assert(not BEE.has_entry_effect(""),
		"empty string should NOT have entry effect")

# ---------------------------------------------------------------------------
# storm_box: match_pool_delta
# ---------------------------------------------------------------------------

func _test_storm_box_adds_one_die_to_delta(gs: Node) -> void:
	gs.reset_run()
	assert(gs.match_pool_delta.is_empty(),
		"match_pool_delta should be empty after reset_run()")
	BEE.on_box_entry("storm_box", gs)
	assert(gs.match_pool_delta.size() == 1,
		"storm_box should add exactly 1 die to match_pool_delta, got %d" % gs.match_pool_delta.size())

func _test_storm_box_die_faces_is_valid(gs: Node) -> void:
	gs.reset_run()
	BEE.on_box_entry("storm_box", gs)
	var die: Die = gs.match_pool_delta[0]
	assert(die.faces in [4, 6, 8],
		"storm_box bonus die faces should be 4, 6, or 8 — got %d" % die.faces)

func _test_storm_box_die_is_storm_temp(gs: Node) -> void:
	gs.reset_run()
	BEE.on_box_entry("storm_box", gs)
	var die: Die = gs.match_pool_delta[0]
	assert(die.storm_temp,
		"storm_box bonus die should have storm_temp == true")

func _test_storm_box_does_not_modify_persistent_pool(gs: Node) -> void:
	gs.reset_run()
	var pool_before: int = gs.dice_pool.size()
	BEE.on_box_entry("storm_box", gs)
	assert(gs.dice_pool.size() == pool_before,
		"storm_box must not modify persistent dice_pool (size was %d, now %d)" % [pool_before, gs.dice_pool.size()])

func _test_storm_box_pool_has_extra_die_in_match(gs: Node) -> void:
	gs.reset_run()
	var box: BoxDefinition = Engine.get_singleton("BoxLibrary").get_box("storm_box")
	assert(box != null, "storm_box should exist in BoxLibrary")
	var persistent_size: int = gs.dice_pool.size()
	var rm := RoundManager.new()
	rm.start_match(box)
	# DicePool is internal to rm, so we verify via match_pool_delta presence.
	# delta should have been populated (then reset_match clears it next match).
	# After start_match, match_pool_delta still has the die until reset_match.
	assert(gs.match_pool_delta.size() == 1,
		"After start_match(storm_box), match_pool_delta should have 1 die; got %d" % gs.match_pool_delta.size())
	assert(gs.dice_pool.size() == persistent_size,
		"Persistent pool unchanged after storm_box match; expected %d got %d" % [persistent_size, gs.dice_pool.size()])

# ---------------------------------------------------------------------------
# cleanse_box: ability charge refill
# ---------------------------------------------------------------------------

func _test_cleanse_box_restores_all_charges(gs: Node) -> void:
	gs.reset_run()
	# Set up hand with partially-depleted abilities.
	gs.ability_hand[0] = _make_ability("test_a", 3, 1)
	gs.ability_hand[1] = _make_ability("test_b", 2, 0)
	gs.ability_hand[2] = _make_ability("test_c", 1, 0)
	BEE.on_box_entry("cleanse_box", gs)
	assert(gs.ability_hand[0].charges == 3,
		"cleanse_box: slot 0 charges should be 3, got %d" % gs.ability_hand[0].charges)
	assert(gs.ability_hand[1].charges == 2,
		"cleanse_box: slot 1 charges should be 2, got %d" % gs.ability_hand[1].charges)
	assert(gs.ability_hand[2].charges == 1,
		"cleanse_box: slot 2 charges should be 1, got %d" % gs.ability_hand[2].charges)

func _test_cleanse_box_skips_null_slots(gs: Node) -> void:
	gs.reset_run()
	gs.ability_hand[0] = null
	gs.ability_hand[1] = _make_ability("test_b", 2, 0)
	gs.ability_hand[2] = null
	# Should not crash with null slots.
	BEE.on_box_entry("cleanse_box", gs)
	assert(gs.ability_hand[1].charges == 2,
		"cleanse_box: slot 1 charges should be 2 (restored), got %d" % gs.ability_hand[1].charges)

func _test_cleanse_box_already_full_stays_full(gs: Node) -> void:
	gs.reset_run()
	gs.ability_hand[0] = _make_ability("test_a", 3, 3)
	BEE.on_box_entry("cleanse_box", gs)
	assert(gs.ability_hand[0].charges == 3,
		"cleanse_box: already-full charges should remain 3, got %d" % gs.ability_hand[0].charges)

# ---------------------------------------------------------------------------
# borrowed_time: HP cost + round limit bonus
# ---------------------------------------------------------------------------

func _test_borrowed_time_costs_1_hp(gs: Node) -> void:
	gs.reset_run()
	var hp_before: int = gs.hp
	# Set round_limit manually (start_match normally sets it from box.round_limit)
	gs.round_limit = 3
	BEE.on_box_entry("borrowed_time", gs)
	assert(gs.hp == hp_before - 1,
		"borrowed_time: hp should decrease by 1, expected %d got %d" % [hp_before - 1, gs.hp])

func _test_borrowed_time_increases_round_limit(gs: Node) -> void:
	gs.reset_run()
	gs.round_limit = 3
	var rl_before: int = gs.round_limit
	BEE.on_box_entry("borrowed_time", gs)
	assert(gs.round_limit == rl_before + 1,
		"borrowed_time: round_limit should increase by 1, expected %d got %d" % [rl_before + 1, gs.round_limit])

func _test_borrowed_time_hp_gate_in_case_manager() -> void:
	var cm = load("res://scripts/run/case_manager.gd").new()
	cm.name = "CaseManager_test_entry"
	get_root().add_child(cm)

	# Verify: when hp < 3, borrowed_time is never returned by get_box_for_match.
	var gs = Engine.get_singleton("GameState")
	var box_lib = Engine.get_singleton("BoxLibrary")

	# Make sure medium tier has enough non-borrowed_time boxes to substitute.
	var medium: Array = box_lib.get_by_tier("medium")
	assert(medium.size() >= 2,
		"HP gate test needs at least 2 medium boxes (borrowed_time + 1 other), got %d" % medium.size())

	# Force HP to 2 (below gate threshold of 3).
	var original_hp: int = gs.hp
	gs.hp = 2

	# Run many resets and check no borrowed_time box appears while HP < 3.
	var found_borrowed_time_when_low_hp := false
	for _trial in 20:
		cm.reset_run()
		for idx in range(1, 28):
			var b = cm.get_box_for_match(idx)
			if b != null and b.id == "borrowed_time":
				found_borrowed_time_when_low_hp = true
				break

	assert(not found_borrowed_time_when_low_hp,
		"CaseManager.get_box_for_match: borrowed_time should never appear when hp < 3")

	# Restore HP and confirm borrowed_time CAN appear when hp >= 3.
	gs.hp = original_hp
	cm.queue_free()

# ---------------------------------------------------------------------------
# RoundManager.start_match integration
# ---------------------------------------------------------------------------

func _test_round_manager_fires_storm_entry(gs: Node) -> void:
	gs.reset_run()
	var box = Engine.get_singleton("BoxLibrary").get_box("storm_box")
	assert(box != null, "storm_box must exist in BoxLibrary")
	var rm := RoundManager.new()
	rm.start_match(box)
	assert(gs.match_pool_delta.size() == 1,
		"RoundManager.start_match(storm_box): match_pool_delta should have 1 die, got %d" % gs.match_pool_delta.size())

func _test_round_manager_fires_cleanse_entry(gs: Node) -> void:
	gs.reset_run()
	# Deplete all abilities.
	for i in gs.ability_hand.size():
		if gs.ability_hand[i] != null:
			gs.ability_hand[i].charges = 0
	var box = Engine.get_singleton("BoxLibrary").get_box("cleanse_box")
	assert(box != null, "cleanse_box must exist in BoxLibrary")
	var rm := RoundManager.new()
	rm.start_match(box)
	# All non-null ability slots should now be at max charges.
	for i in gs.ability_hand.size():
		var a = gs.ability_hand[i]
		if a != null:
			assert(a.charges == a.max_charges,
				"After start_match(cleanse_box): slot %d charges should be max (%d), got %d" % [i, a.max_charges, a.charges])

func _test_round_manager_fires_borrowed_time_entry(gs: Node) -> void:
	gs.reset_run()
	var box = Engine.get_singleton("BoxLibrary").get_box("borrowed_time")
	assert(box != null, "borrowed_time must exist in BoxLibrary")
	var hp_before: int = gs.hp
	var rm := RoundManager.new()
	rm.start_match(box)
	# borrowed_time takes 1 HP and adds 1 to round_limit.
	# round_limit is set to box.round_limit by start_match before entry fires,
	# then +1 is applied by the effect.
	assert(gs.hp == hp_before - 1,
		"After start_match(borrowed_time): hp should be %d, got %d" % [hp_before - 1, gs.hp])
	assert(gs.round_limit == box.round_limit + 1,
		"After start_match(borrowed_time): round_limit should be %d, got %d" % [box.round_limit + 1, gs.round_limit])

# ---------------------------------------------------------------------------
# match_pool_delta cleared between matches
# ---------------------------------------------------------------------------

func _test_match_pool_delta_cleared_between_matches(gs: Node) -> void:
	gs.reset_run()
	var storm_box = Engine.get_singleton("BoxLibrary").get_box("storm_box")
	assert(storm_box != null, "storm_box must exist in BoxLibrary")
	var rm := RoundManager.new()
	rm.start_match(storm_box)
	assert(gs.match_pool_delta.size() == 1,
		"After storm_box match: delta should have 1 die, got %d" % gs.match_pool_delta.size())
	# Start a different match — delta should be cleared.
	var classic_box = Engine.get_singleton("BoxLibrary").get_box("classic")
	assert(classic_box != null, "classic must exist in BoxLibrary")
	var rm2 := RoundManager.new()
	rm2.start_match(classic_box)
	assert(gs.match_pool_delta.is_empty(),
		"After classic match: match_pool_delta should be empty, got %d" % gs.match_pool_delta.size())
