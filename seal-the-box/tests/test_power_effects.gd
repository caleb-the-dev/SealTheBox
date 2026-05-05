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

	var power_lib = load("res://scripts/globals/power_library.gd").new()
	power_lib.name = "PowerLibrary"
	get_root().add_child(power_lib)
	power_lib._ready()
	Engine.register_singleton("PowerLibrary", power_lib)

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)
	Engine.register_singleton("GameState", gs)

	var pm = load("res://scripts/run/power_manager.gd").new()
	pm.name = "PowerManager"
	get_root().add_child(pm)
	Engine.register_singleton("PowerManager", pm)

	_test_lighter_box_no_powers(gs, pm)
	_test_lighter_box_one_owned(gs, pm)
	_test_lighter_box_two_owned(gs, pm)
	_test_eager_no_power_no_preroll(gs, pm)
	_test_eager_one_owned_exactly_one_die(gs, pm)
	_test_eager_die_at_max_face(gs, pm)
	_test_tab9_bounty_grants_hp_when_9_sealed(gs, pm)
	_test_tab9_bounty_no_hp_without_9(gs, pm)
	_test_tab9_bounty_two_copies_grants_two_hp(gs, pm)
	_test_bonus_seal_seals_half_tab(gs, pm)
	_test_bonus_seal_multi_primary(gs, pm)
	_test_bonus_seal_skips_already_sealed(gs, pm)
	_test_bonus_seal_skips_tab_1(gs, pm)
	_test_box_shutter_sets_pending_bonus(gs, pm)
	_test_box_shutter_two_copies_double(gs, pm)
	_test_box_shutter_no_power_no_change(gs, pm)
	_test_get_random_unowned_excludes_owned(gs, pm)
	_test_get_random_unowned_returns_null_when_all_owned(gs, pm)
	_test_get_random_unowned_multiple_returns_up_to_3(gs, pm)
	_test_get_random_unowned_multiple_respects_count(gs, pm)
	_test_get_random_unowned_multiple_returns_fewer_when_only_1_unowned(gs, pm)
	_test_get_random_unowned_multiple_returns_empty_when_all_owned(gs, pm)
	_test_get_random_unowned_multiple_no_duplicates(gs, pm)
	_test_coffee_break_adds_charge(gs, pm)
	_test_coffee_break_no_effect_with_empty_hand(gs, pm)
	_test_coffee_break_no_effect_when_all_at_max(gs, pm)
	_test_survivor_heals_at_1hp(gs, pm)
	_test_survivor_no_heal_above_1hp(gs, pm)
	_test_phoenix_down_saves_run(gs, pm)
	_test_phoenix_down_not_triggered_when_not_owned(gs, pm)
	print("All PowerEffects tests passed!")
	quit()

# ── Lighter Box ──────────────────────────────────────────────────────────────

func _test_lighter_box_no_powers(gs: Node, pm: Node) -> void:
	gs.owned_powers = []
	assert(pm.get_threshold_bonus() == 0,
		"0 Lighter Box: threshold bonus should be 0, got %d" % pm.get_threshold_bonus())

func _test_lighter_box_one_owned(gs: Node, pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("lighter_box")]
	assert(pm.get_threshold_bonus() == 1,
		"1 Lighter Box: threshold bonus should be 1, got %d" % pm.get_threshold_bonus())

func _test_lighter_box_two_owned(gs: Node, pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	var lb = power_lib.get_power("lighter_box")
	gs.owned_powers = [lb, lb]
	assert(pm.get_threshold_bonus() == 2,
		"2 Lighter Box: threshold bonus should be 2, got %d" % pm.get_threshold_bonus())

# ── Eager ────────────────────────────────────────────────────────────────────

func _test_eager_no_power_no_preroll(gs: Node, pm: Node) -> void:
	gs.reset_run()
	gs.owned_powers = []
	pm.apply_eager(gs.dice_pool)
	var pre_rolled = gs.dice_pool.filter(func(d): return d.rolled)
	assert(pre_rolled.size() == 0,
		"No Eager: no die should be pre-rolled, got %d" % pre_rolled.size())

func _test_eager_one_owned_exactly_one_die(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("eager")]
	pm.apply_eager(gs.dice_pool)
	var pre_rolled = gs.dice_pool.filter(func(d): return d.rolled)
	assert(pre_rolled.size() == 1,
		"1 Eager: exactly 1 die should be pre-rolled, got %d" % pre_rolled.size())

func _test_eager_die_at_max_face(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("eager")]
	pm.apply_eager(gs.dice_pool)
	var pre_rolled = gs.dice_pool.filter(func(d): return d.rolled)
	assert(pre_rolled.size() == 1, "Eager: 1 die should be pre-rolled")
	var die = pre_rolled[0]
	assert(die.value == die.faces,
		"Eager: pre-rolled die should be at max face (%d), got %d" % [die.faces, die.value])

# ── Tab 9 Bounty ─────────────────────────────────────────────────────────────

func _test_tab9_bounty_grants_hp_when_9_sealed(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("tab_9_bounty")]
	var hp_before = gs.hp
	pm.apply_tab9_bounty([9, 5])
	assert(gs.hp == hp_before + 1,
		"Tab 9 Bounty: sealing 9 should grant +1 HP (expected %d, got %d)" % [hp_before + 1, gs.hp])

func _test_tab9_bounty_no_hp_without_9(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("tab_9_bounty")]
	var hp_before = gs.hp
	pm.apply_tab9_bounty([5, 7])
	assert(gs.hp == hp_before,
		"Tab 9 Bounty: no 9 in sealed list should not grant HP")

func _test_tab9_bounty_two_copies_grants_two_hp(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	var bounty = power_lib.get_power("tab_9_bounty")
	gs.owned_powers = [bounty, bounty]
	var hp_before = gs.hp
	pm.apply_tab9_bounty([9])
	assert(gs.hp == hp_before + 2,
		"2x Tab 9 Bounty: sealing 9 should grant +2 HP (expected %d, got %d)" % [hp_before + 2, gs.hp])

# ── Bonus Seal ───────────────────────────────────────────────────────────────

func _test_bonus_seal_seals_half_tab(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	pm.add_power(power_lib.get_power("bonus_seal"))
	pm.on_round_end(); pm.on_round_end(); pm.on_round_end()  # prime counter to 3
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
	tb.seal_tabs([8])
	var bonus = pm.get_bonus_seals_if_ready(tb, [8])
	assert(4 in bonus,
		"Bonus Seal: sealing 8 should return bonus seal on 4")
	assert(bonus.size() == 1,
		"Bonus Seal: exactly 1 bonus expected, got %d" % bonus.size())

func _test_bonus_seal_multi_primary(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	pm.add_power(power_lib.get_power("bonus_seal"))
	pm.on_round_end(); pm.on_round_end(); pm.on_round_end()  # prime counter to 3
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
	tb.seal_tabs([3, 5])
	var bonus = pm.get_bonus_seals_if_ready(tb, [3, 5])
	# floor(3/2)=1, floor(5/2)=2 — both open in remaining
	assert(1 in bonus, "Bonus Seal: sealing 3 should bonus-seal tab 1")
	assert(2 in bonus, "Bonus Seal: sealing 5 should bonus-seal tab 2")
	assert(bonus.size() == 2, "Bonus Seal: exactly 2 bonuses expected for sealing {3,5}, got %d" % bonus.size())

func _test_bonus_seal_skips_already_sealed(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	pm.add_power(power_lib.get_power("bonus_seal"))
	pm.on_round_end(); pm.on_round_end(); pm.on_round_end()  # prime counter to 3
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 5, 6, 7, 8, 9])  # tab 4 already sealed
	tb.seal_tabs([8])
	var bonus = pm.get_bonus_seals_if_ready(tb, [8])
	assert(not (4 in bonus),
		"Bonus Seal: tab 4 already sealed should not appear in bonus list")

func _test_bonus_seal_skips_tab_1(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	pm.add_power(power_lib.get_power("bonus_seal"))
	pm.on_round_end(); pm.on_round_end(); pm.on_round_end()  # prime counter to 3
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
	tb.seal_tabs([2])
	var bonus = pm.get_bonus_seals_if_ready(tb, [2])
	# floor(2/2) = 1 — tab 1 should be bonus-sealed (N=2 >= 2, bonus_tab=1 >= 1)
	assert(1 in bonus, "Bonus Seal: sealing tab 2 should bonus-seal tab 1")

# ── Box Shutter ──────────────────────────────────────────────────────────────

func _test_box_shutter_sets_pending_bonus(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("box_shutter")]
	assert(gs.pending_threshold_bonus == 0, "pending_threshold_bonus should start at 0")
	pm.apply_box_shutter()
	assert(gs.pending_threshold_bonus == 2,
		"1 Box Shutter: pending bonus should be 2, got %d" % gs.pending_threshold_bonus)

func _test_box_shutter_two_copies_double(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	var shutter = power_lib.get_power("box_shutter")
	gs.owned_powers = [shutter, shutter]
	pm.apply_box_shutter()
	assert(gs.pending_threshold_bonus == 4,
		"2 Box Shutter: pending bonus should be 4, got %d" % gs.pending_threshold_bonus)

func _test_box_shutter_no_power_no_change(gs: Node, pm: Node) -> void:
	gs.reset_run()
	gs.owned_powers = []
	pm.apply_box_shutter()
	assert(gs.pending_threshold_bonus == 0,
		"No Box Shutter: pending bonus should remain 0, got %d" % gs.pending_threshold_bonus)

# ── PowerLibrary.get_random_unowned ─────────────────────────────────────────

func _test_get_random_unowned_excludes_owned(gs: Node, _pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	# Own all 8 powers except box_shutter
	gs.owned_powers = [
		power_lib.get_power("lighter_box"),
		power_lib.get_power("eager"),
		power_lib.get_power("tab_9_bounty"),
		power_lib.get_power("bonus_seal"),
		power_lib.get_power("phoenix_down"),
		power_lib.get_power("coffee_break"),
		power_lib.get_power("survivor"),
	]
	for _i in 10:
		var result = power_lib.get_random_unowned(gs.owned_powers)
		assert(result != null, "get_random_unowned: should return a power when one is unowned")
		assert(result.id == "box_shutter",
			"get_random_unowned: should return 'box_shutter', got '%s'" % result.id)

func _test_get_random_unowned_returns_null_when_all_owned(gs: Node, _pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = power_lib.get_all()
	var result = power_lib.get_random_unowned(gs.owned_powers)
	assert(result == null,
		"get_random_unowned: should return null when all powers owned")

# ── PowerLibrary.get_random_unowned_multiple ─────────────────────────────────

func _test_get_random_unowned_multiple_returns_up_to_3(gs: Node, _pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = []
	var result = power_lib.get_random_unowned_multiple(gs.owned_powers, 3)
	assert(result is Array, "get_random_unowned_multiple: should return an Array")
	assert(result.size() == 3,
		"with 8 powers and 0 owned, should return 3, got %d" % result.size())

func _test_get_random_unowned_multiple_respects_count(gs: Node, _pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = []
	var result = power_lib.get_random_unowned_multiple(gs.owned_powers, 1)
	assert(result.size() == 1,
		"requesting 1 should return 1, got %d" % result.size())

func _test_get_random_unowned_multiple_returns_fewer_when_only_1_unowned(gs: Node, _pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	# Own 7 of 8, leaving only box_shutter unowned
	gs.owned_powers = [
		power_lib.get_power("lighter_box"),
		power_lib.get_power("eager"),
		power_lib.get_power("tab_9_bounty"),
		power_lib.get_power("bonus_seal"),
		power_lib.get_power("phoenix_down"),
		power_lib.get_power("coffee_break"),
		power_lib.get_power("survivor"),
	]
	var result = power_lib.get_random_unowned_multiple(gs.owned_powers, 3)
	assert(result.size() == 1,
		"with 1 unowned, requesting 3 should return 1, got %d" % result.size())
	assert(result[0].id == "box_shutter",
		"the only unowned power should be box_shutter, got '%s'" % result[0].id)

func _test_get_random_unowned_multiple_returns_empty_when_all_owned(gs: Node, _pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = power_lib.get_all()
	var result = power_lib.get_random_unowned_multiple(gs.owned_powers, 3)
	assert(result.is_empty(),
		"with all powers owned, should return empty array, got %d" % result.size())

func _test_get_random_unowned_multiple_no_duplicates(gs: Node, _pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = []
	var result = power_lib.get_random_unowned_multiple(gs.owned_powers, 3)
	var ids: Array = result.map(func(p): return p.id)
	var unique_ids: Dictionary = {}
	for id in ids:
		unique_ids[id] = true
	assert(unique_ids.size() == ids.size(),
		"get_random_unowned_multiple: result should have no duplicate powers")

# ── Coffee Break ─────────────────────────────────────────────────────────────

func _test_coffee_break_adds_charge(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("coffee_break")]
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("greater_1").duplicate()
	ability.charges = ability.max_charges - 1
	gs.ability_hand = [null, null, ability]

	pm.apply_coffee_break()

	assert(ability.charges == ability.max_charges,
		"Coffee Break: charge should increase to max, got %d (expected %d)" % [ability.charges, ability.max_charges])

func _test_coffee_break_no_effect_with_empty_hand(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("coffee_break")]
	gs.ability_hand = [null, null, null]
	pm.apply_coffee_break()
	# Should not crash; reaching this line is the assertion

func _test_coffee_break_no_effect_when_all_at_max(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("coffee_break")]
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("greater_1").duplicate()
	ability.charges = ability.max_charges
	gs.ability_hand = [null, null, ability]
	pm.apply_coffee_break()
	assert(ability.charges == ability.max_charges,
		"Coffee Break: should not exceed max_charges, got %d" % ability.charges)

# ── Survivor ──────────────────────────────────────────────────────────────────

func _test_survivor_heals_at_1hp(gs: Node, pm: Node) -> void:
	gs.reset_run()
	gs.hp = 1
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("survivor")]

	pm.apply_survivor()

	assert(gs.hp == 2,
		"Survivor: hp should go from 1 to 2, got %d" % gs.hp)

func _test_survivor_no_heal_above_1hp(gs: Node, pm: Node) -> void:
	gs.reset_run()
	gs.hp = 3
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("survivor")]

	pm.apply_survivor()

	assert(gs.hp == 3,
		"Survivor: hp should not change at 3hp, got %d" % gs.hp)

# ── Phoenix Down ──────────────────────────────────────────────────────────────

func _test_phoenix_down_saves_run(gs: Node, pm: Node) -> void:
	gs.reset_run()
	gs.hp = 1
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("phoenix_down")]

	var result = pm.try_phoenix_down()

	assert(result == true, "try_phoenix_down: should return true when owned")
	assert(gs.hp == 1, "Phoenix Down: hp should be 1 after trigger, got %d" % gs.hp)
	var phoenix_count := 0
	for p in gs.owned_powers:
		if p.id == "phoenix_down":
			phoenix_count += 1
	assert(phoenix_count == 0, "Phoenix Down: power should be consumed from owned_powers")

func _test_phoenix_down_not_triggered_when_not_owned(gs: Node, pm: Node) -> void:
	gs.reset_run()
	gs.owned_powers = []

	var result = pm.try_phoenix_down()

	assert(result == false, "try_phoenix_down: should return false when not owned")
