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
	_test_box_shutter_two_copies_adds_ten(gs, pm)
	_test_box_shutter_no_power_no_change(gs, pm)
	_test_get_random_unowned_excludes_owned(gs, pm)
	_test_get_random_unowned_returns_null_when_all_owned(gs, pm)

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
	assert(pm.get_threshold_bonus() == 3,
		"1 Lighter Box: threshold bonus should be 3, got %d" % pm.get_threshold_bonus())

func _test_lighter_box_two_owned(gs: Node, pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	var lb = power_lib.get_power("lighter_box")
	gs.owned_powers = [lb, lb]
	assert(pm.get_threshold_bonus() == 6,
		"2 Lighter Box: threshold bonus should be 6, got %d" % pm.get_threshold_bonus())

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
	gs.owned_powers = [power_lib.get_power("bonus_seal")]
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
	tb.seal_tabs([8])
	var bonus = pm.get_bonus_seals(tb, [8])
	assert(4 in bonus,
		"Bonus Seal: sealing 8 should return bonus seal on 4")
	assert(bonus.size() == 1,
		"Bonus Seal: exactly 1 bonus expected, got %d" % bonus.size())

func _test_bonus_seal_multi_primary(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("bonus_seal")]
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
	tb.seal_tabs([3, 5])
	var bonus = pm.get_bonus_seals(tb, [3, 5])
	# floor(3/2)=1, floor(5/2)=2 — both open in remaining
	assert(1 in bonus, "Bonus Seal: sealing 3 should bonus-seal tab 1")
	assert(2 in bonus, "Bonus Seal: sealing 5 should bonus-seal tab 2")
	assert(bonus.size() == 2, "Bonus Seal: exactly 2 bonuses expected for sealing {3,5}, got %d" % bonus.size())

func _test_bonus_seal_skips_already_sealed(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("bonus_seal")]
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 5, 6, 7, 8, 9])  # tab 4 already sealed
	tb.seal_tabs([8])
	var bonus = pm.get_bonus_seals(tb, [8])
	assert(not (4 in bonus),
		"Bonus Seal: tab 4 already sealed should not appear in bonus list")

func _test_bonus_seal_skips_tab_1(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("bonus_seal")]
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
	tb.seal_tabs([2])
	var bonus = pm.get_bonus_seals(tb, [2])
	# floor(2/2) = 1 — tab 1 should be bonus-sealed (N=2 >= 2, bonus_tab=1 >= 1)
	assert(1 in bonus, "Bonus Seal: sealing tab 2 should bonus-seal tab 1")

# ── Box Shutter ──────────────────────────────────────────────────────────────

func _test_box_shutter_sets_pending_bonus(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("box_shutter")]
	assert(gs.pending_threshold_bonus == 0, "pending_threshold_bonus should start at 0")
	pm.apply_box_shutter()
	assert(gs.pending_threshold_bonus == 5,
		"1 Box Shutter: pending bonus should be 5, got %d" % gs.pending_threshold_bonus)

func _test_box_shutter_two_copies_adds_ten(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	var shutter = power_lib.get_power("box_shutter")
	gs.owned_powers = [shutter, shutter]
	pm.apply_box_shutter()
	assert(gs.pending_threshold_bonus == 10,
		"2 Box Shutter: pending bonus should be 10, got %d" % gs.pending_threshold_bonus)

func _test_box_shutter_no_power_no_change(gs: Node, pm: Node) -> void:
	gs.reset_run()
	gs.owned_powers = []
	pm.apply_box_shutter()
	assert(gs.pending_threshold_bonus == 0,
		"No Box Shutter: pending bonus should remain 0, got %d" % gs.pending_threshold_bonus)

# ── PowerLibrary.get_random_unowned ─────────────────────────────────────────

func _test_get_random_unowned_excludes_owned(gs: Node, _pm: Node) -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	# Own all 5 powers except box_shutter
	gs.owned_powers = [
		power_lib.get_power("lighter_box"),
		power_lib.get_power("eager"),
		power_lib.get_power("tab_9_bounty"),
		power_lib.get_power("bonus_seal"),
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
