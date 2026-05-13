extends SceneTree

# Tests for the BHV-axis tab behavior dispatcher and TabBoard mutation API.
# Run headless: godot --headless --path seal-the-box --script tests/test_tab_behavior.gd

const _BoxTabBehavior = preload("res://scripts/match/box_tab_behavior.gd")

var _gs: Node   # GameState instance shared across tests

func _init() -> void:
	# Set up minimal singletons needed by BoxTabBehavior / TabBoard.
	var lib = load("res://scripts/globals/ability_library.gd").new()
	lib.name = "AbilityLibrary"
	get_root().add_child(lib)
	lib._ready()
	Engine.register_singleton("AbilityLibrary", lib)

	_gs = load("res://scripts/globals/game_state.gd").new()
	_gs.name = "GameState"
	get_root().add_child(_gs)
	Engine.register_singleton("GameState", _gs)

	# ── TabBoard mutation API ───────────────────────────────────────────────
	_test_tabboard_add_tab()
	_test_tabboard_remove_tab()
	_test_tabboard_change_tab_value()
	_test_tabboard_replace_all_tabs()
	_test_tabboard_decoy_init()
	_test_tabboard_decoy_real_sum()
	_test_tabboard_decoy_win_check()
	_test_tabboard_decoy_can_seal_multi_real_only()
	_test_tabboard_critical_win_ignores_decoys()
	_test_tabboard_reveal_and_vanish_decoys()

	# ── BoxTabBehavior.has_behavior ─────────────────────────────────────────
	_test_has_behavior_registered()
	_test_has_behavior_unknown()

	# ── regrowing ───────────────────────────────────────────────────────────
	_test_regrowing_no_return_round_1()
	_test_regrowing_returns_lowest_sealed()
	_test_regrowing_nothing_to_return()

	# ── rising_tide ─────────────────────────────────────────────────────────
	_test_rising_tide_increments_tabs()
	_test_rising_tide_ceiling()

	# ── growing_pillars ─────────────────────────────────────────────────────
	_test_growing_pillars_increments_tabs()

	# ── shuffler ────────────────────────────────────────────────────────────
	_test_shuffler_replaces_values()

	# ── clock_tabs ──────────────────────────────────────────────────────────
	_test_clock_tabs_decrements_one_tab()
	_test_clock_tabs_removes_tab_at_zero()

	# ── revenant_tabs ────────────────────────────────────────────────────────
	_test_revenant_tabs_no_seal_round()
	_test_revenant_tabs_sealed_round_no_return()

	# ── fading_decoys ────────────────────────────────────────────────────────
	_test_fading_decoys_board_has_decoys()
	_test_fading_decoys_real_sum_excludes_phantoms()
	_test_fading_decoys_decoys_vanish()

	# ── mitosis ──────────────────────────────────────────────────────────────
	_test_mitosis_sealing_small_tab_no_spawn()
	_test_mitosis_sealing_large_tab_spawns()
	_test_mitosis_recursion_cap()

	# ── moving_targets ────────────────────────────────────────────────────────
	_test_moving_targets_round_1_range()
	_test_moving_targets_round_4_range()

	print("All test_tab_behavior tests passed!")
	quit()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_gs_with_round(round_num: int) -> Node:
	# Returns the shared _gs with round set to round_num.
	_gs.round = round_num
	_gs.hp = 6
	_gs.current_box = null
	return _gs

func _make_box(id: String, tabs_arr: Array[int]) -> BoxDefinition:
	var box := BoxDefinition.new()
	box.id = id
	box.name = id
	box.tabs.assign(tabs_arr)
	box.win_threshold = 11
	return box

func _board_from(tabs: Array[int]) -> TabBoard:
	var b := TabBoard.new()
	b.reset(tabs)
	return b

# ---------------------------------------------------------------------------
# TabBoard mutation API
# ---------------------------------------------------------------------------

func _test_tabboard_add_tab() -> void:
	var b := _board_from([1, 2, 3])
	assert(b.get_remaining().size() == 3, "Should start with 3 tabs")
	b.add_tab(9)
	assert(b.get_remaining().size() == 4, "add_tab should grow board to 4")
	assert(9 in b.get_remaining(), "Tab 9 should be present after add_tab")

func _test_tabboard_remove_tab() -> void:
	var b := _board_from([1, 2, 3, 4])
	b.remove_tab(2)
	assert(b.get_remaining().size() == 3, "remove_tab should shrink board")
	assert(not (2 in b.get_remaining()), "Tab 2 should be gone")

func _test_tabboard_change_tab_value() -> void:
	var b := _board_from([1, 2, 3])
	b.change_tab_value(2, 7)
	var r := b.get_remaining()
	assert(not (2 in r), "Old value 2 should be gone")
	assert(7 in r, "New value 7 should be present")
	assert(r.size() == 3, "Size unchanged after change_tab_value")

func _test_tabboard_replace_all_tabs() -> void:
	var b := _board_from([1, 2, 3, 4, 5, 6])
	var new_tabs: Array[int] = [2, 3, 4, 5, 6, 7]
	b.replace_all_tabs(new_tabs)
	var r := b.get_remaining()
	assert(r.size() == 6, "replace_all_tabs should keep count: 6")
	assert(2 in r and 7 in r, "Should have 2 and 7 after replace")
	assert(not (1 in r), "Old tab 1 should be gone")

# ---------------------------------------------------------------------------
# TabBoard decoy support
# ---------------------------------------------------------------------------

func _test_tabboard_decoy_init() -> void:
	var b := TabBoard.new()
	# Real tabs: 1,2,3. Phantoms (appended): 5,7.
	var all_tabs: Array[int] = [1, 2, 3, 5, 7]
	b.reset_with_decoys(all_tabs, 2)   # last 2 are decoys
	assert(b.has_decoys(), "Board should have decoys after reset_with_decoys")
	assert(b.get_remaining().size() == 5, "All tabs (real + decoy) should be in get_remaining")

func _test_tabboard_decoy_real_sum() -> void:
	var b := TabBoard.new()
	# Real tabs: 1+2+3=6. Decoys (last 2): 5+7=12.
	var all_tabs: Array[int] = [1, 2, 3, 5, 7]
	b.reset_with_decoys(all_tabs, 2)
	assert(b.get_real_sum() == 6, "Real sum should be 6, got %d" % b.get_real_sum())
	assert(b.get_sum() == 18, "Total sum (with decoys) should be 18, got %d" % b.get_sum())

func _test_tabboard_decoy_win_check() -> void:
	var b := TabBoard.new()
	var all_tabs: Array[int] = [1, 2, 3, 5, 7]
	b.reset_with_decoys(all_tabs, 2)
	# Real sum = 6; threshold = 8 → should be winning.
	assert(b.check_win(8), "check_win should use real sum (6 <= 8)")
	assert(not b.check_win(5), "Real sum 6 does not satisfy threshold 5")

func _test_tabboard_decoy_can_seal_multi_real_only() -> void:
	var b := TabBoard.new()
	# Real: 1,2,3. Decoys: 5,7 (appended last).
	var all_tabs: Array[int] = [1, 2, 3, 5, 7]
	b.reset_with_decoys(all_tabs, 2)
	assert(b.can_seal_multi(3, [1, 2]), "Can seal real tabs 1+2=3")
	assert(not b.can_seal_multi(5, [5]), "Cannot seal decoy tab 5")
	assert(not b.can_seal_multi(7, [7]), "Cannot seal decoy tab 7")

func _test_tabboard_critical_win_ignores_decoys() -> void:
	var b := TabBoard.new()
	# Real: 1,2. Decoy: 5 (appended last).
	var all_tabs: Array[int] = [1, 2, 5]
	b.reset_with_decoys(all_tabs, 1)
	# Seal the real tabs only.
	b.seal_tab(1)
	b.seal_tab(2)
	# Real tabs are gone; decoy 5 remains.
	assert(b.check_critical_win(), "Critical win should fire when all REAL tabs sealed")

func _test_tabboard_reveal_and_vanish_decoys() -> void:
	var b := TabBoard.new()
	# Real: 1,2,3. Decoys: 5,7 (appended last).
	var all_tabs: Array[int] = [1, 2, 3, 5, 7]
	b.reset_with_decoys(all_tabs, 2)
	assert(b.has_decoys(), "Should have decoys before vanish")
	var revealed := b.reveal_and_vanish_decoys()
	assert(revealed.size() == 2, "Should reveal 2 decoys, got %d" % revealed.size())
	assert(5 in revealed, "Revealed should contain 5")
	assert(7 in revealed, "Revealed should contain 7")
	assert(not b.has_decoys(), "No decoys after vanish")
	assert(b.get_remaining().size() == 3, "Real tabs should remain: 3, got %d" % b.get_remaining().size())

# ---------------------------------------------------------------------------
# BoxTabBehavior.has_behavior
# ---------------------------------------------------------------------------

func _test_has_behavior_registered() -> void:
	for box_id in ["regrowing", "rising_tide", "shuffler", "clock_tabs",
			"growing_pillars", "revenant_tabs", "fading_decoys", "mitosis", "moving_targets"]:
		assert(_BoxTabBehavior.has_behavior(box_id),
			"%s should be registered in has_behavior" % box_id)

func _test_has_behavior_unknown() -> void:
	assert(not _BoxTabBehavior.has_behavior("classic"),
		"classic should not have BHV behavior")
	assert(not _BoxTabBehavior.has_behavior(""),
		"empty string should not have BHV behavior")

# ---------------------------------------------------------------------------
# regrowing
# ---------------------------------------------------------------------------

func _test_regrowing_no_return_round_1() -> void:
	var gs := _make_gs_with_round(1)
	gs.current_box = _make_box("regrowing", [1, 2, 3, 4, 5, 6, 7, 8, 9])
	var b := _board_from([1, 2, 3, 4, 5, 6, 7, 8, 9])
	# Seal tab 1 then test round_start on round 1 (should not return it).
	b.seal_tab(1)
	var count_before := b.get_remaining().size()
	_BoxTabBehavior.on_round_start("regrowing", b, gs)
	assert(b.get_remaining().size() == count_before,
		"regrowing round 1 should not return any tab")

func _test_regrowing_returns_lowest_sealed() -> void:
	var gs := _make_gs_with_round(2)
	gs.current_box = _make_box("regrowing", [1, 2, 3, 4, 5, 6, 7, 8, 9])
	var b := _board_from([2, 3, 4, 5, 6, 7, 8, 9])   # Tab 1 already sealed
	var count_before := b.get_remaining().size()
	_BoxTabBehavior.on_round_start("regrowing", b, gs)
	assert(b.get_remaining().size() == count_before + 1,
		"regrowing round 2+ should restore 1 tab")
	assert(1 in b.get_remaining(),
		"regrowing should restore the lowest sealed tab (1)")

func _test_regrowing_nothing_to_return() -> void:
	var gs := _make_gs_with_round(2)
	gs.current_box = _make_box("regrowing", [1, 2, 3])
	var b := _board_from([1, 2, 3])  # Nothing sealed
	var count_before := b.get_remaining().size()
	_BoxTabBehavior.on_round_start("regrowing", b, gs)
	assert(b.get_remaining().size() == count_before,
		"regrowing with nothing sealed should not add tabs")

# ---------------------------------------------------------------------------
# rising_tide
# ---------------------------------------------------------------------------

func _test_rising_tide_increments_tabs() -> void:
	var b := _board_from([1, 2, 3, 4])
	var msg := _BoxTabBehavior.on_round_end("rising_tide", b, null)
	var r := b.get_remaining()
	assert(2 in r and 3 in r and 4 in r and 5 in r,
		"rising_tide should increment all tabs by 1")
	assert(not (1 in r), "Old tab 1 should be gone")
	assert(not msg.is_empty(), "rising_tide should return a message when tabs changed")

func _test_rising_tide_ceiling() -> void:
	var b := _board_from([12, 13])
	_BoxTabBehavior.on_round_end("rising_tide", b, null)
	var r := b.get_remaining()
	# 12 → 13, 13 → 13 (capped)
	assert(r.size() == 2, "Size unchanged")
	var thirteens := r.filter(func(v): return v == 13)
	assert(thirteens.size() == 2, "Both tabs should be 13 after ceiling clamp")

# ---------------------------------------------------------------------------
# growing_pillars
# ---------------------------------------------------------------------------

func _test_growing_pillars_increments_tabs() -> void:
	var b := _board_from([2, 2, 2, 2])
	_BoxTabBehavior.on_round_end("growing_pillars", b, null)
	var r := b.get_remaining()
	assert(r.size() == 4, "growing_pillars: count unchanged")
	for v in r:
		assert(v == 3, "growing_pillars: all tabs should be 3 after one round, got %d" % v)

# ---------------------------------------------------------------------------
# shuffler
# ---------------------------------------------------------------------------

func _test_shuffler_replaces_values() -> void:
	var b := _board_from([1, 1, 1, 1, 1])
	_BoxTabBehavior.on_round_start("shuffler", b, null)
	var r := b.get_remaining()
	assert(r.size() == 5, "shuffler: count unchanged")
	for v in r:
		assert(v >= 1 and v <= 9, "shuffler: each tab value should be 1-9, got %d" % v)

# ---------------------------------------------------------------------------
# clock_tabs
# ---------------------------------------------------------------------------

func _test_clock_tabs_decrements_one_tab() -> void:
	# All tabs start at 5; lowest is 5, ticks down by 2 to 3.
	var gs := _make_gs_with_round(1)
	var b := _board_from([5, 5, 5])
	_BoxTabBehavior.on_round_end("clock_tabs", b, gs)
	var r := b.get_remaining()
	var threes := r.filter(func(v): return v == 3)
	var fives := r.filter(func(v): return v == 5)
	assert(threes.size() == 1, "clock_tabs: lowest tab should tick to 3, got %d threes" % threes.size())
	assert(fives.size() == 2, "clock_tabs: two tabs should remain at 5")
	assert(gs.hp == 6, "clock_tabs: no HP loss when tab > 0")

func _test_clock_tabs_removes_tab_at_zero() -> void:
	# Tab at 1 ticks down by 2 (1-2 = -1 ≤ 0) — removed, 1 HP damage.
	var gs := _make_gs_with_round(1)
	var b := _board_from([1])
	_BoxTabBehavior.on_round_end("clock_tabs", b, gs)
	assert(b.get_remaining().is_empty(), "clock_tabs: tab at 1 should vanish on tick")
	assert(gs.hp == 5, "clock_tabs: HP should decrease by 1 when tab hits 0")

# ---------------------------------------------------------------------------
# revenant_tabs
# ---------------------------------------------------------------------------

func _test_revenant_tabs_no_seal_round() -> void:
	var gs := _make_gs_with_round(2)
	gs.current_box = _make_box("revenant_tabs", [1, 2, 3, 4, 5, 6, 7, 8, 9])
	var b := _board_from([2, 3, 4, 5, 6, 7, 8, 9])  # Tab 1 sealed
	var count_before := b.get_remaining().size()
	var msg := _BoxTabBehavior.on_round_end_no_seal("revenant_tabs", b, gs)
	assert(b.get_remaining().size() == count_before + 1,
		"revenant_tabs: sealed tab should return on no-seal round")
	assert(1 in b.get_remaining(),
		"revenant_tabs: should restore lowest sealed tab (1)")
	assert(not msg.is_empty(), "revenant_tabs: should return a message")

func _test_revenant_tabs_sealed_round_no_return() -> void:
	var gs := _make_gs_with_round(2)
	gs.current_box = _make_box("revenant_tabs", [1, 2, 3])
	var b := _board_from([1, 2, 3])  # Nothing sealed
	var count_before := b.get_remaining().size()
	_BoxTabBehavior.on_round_end_no_seal("revenant_tabs", b, gs)
	# No sealed tabs to return, count stays same.
	assert(b.get_remaining().size() == count_before,
		"revenant_tabs: nothing to return when no tabs are sealed")

# ---------------------------------------------------------------------------
# fading_decoys
# ---------------------------------------------------------------------------

func _test_fading_decoys_board_has_decoys() -> void:
	var b := TabBoard.new()
	# Real: 1-9. Phantoms (last 3): 3,5,7.
	var all_tabs: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 3, 5, 7]
	b.reset_with_decoys(all_tabs, 3)
	assert(b.has_decoys(), "fading_decoys board should have decoys")
	assert(b.get_remaining().size() == 12, "fading_decoys: 9 real + 3 phantom = 12 tabs")

func _test_fading_decoys_real_sum_excludes_phantoms() -> void:
	var b := TabBoard.new()
	var all_tabs: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 3, 5, 7]
	b.reset_with_decoys(all_tabs, 3)
	assert(b.get_real_sum() == 45, "fading_decoys: real sum should be 45 (1-9), got %d" % b.get_real_sum())
	assert(b.get_sum() == 60, "fading_decoys: total sum 45+3+5+7=60, got %d" % b.get_sum())

func _test_fading_decoys_decoys_vanish() -> void:
	var gs := _make_gs_with_round(3)
	gs.current_box = _make_box("fading_decoys", [1, 2, 3, 4, 5, 6, 7, 8, 9])
	var b := TabBoard.new()
	var all_tabs: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 3, 5, 7]
	b.reset_with_decoys(all_tabs, 3)
	assert(b.has_decoys(), "Should have decoys before round 3")
	_BoxTabBehavior.on_round_start("fading_decoys", b, gs)
	assert(not b.has_decoys(), "Decoys should vanish at round 3 start")
	assert(b.get_remaining().size() == 9, "Only real tabs remain after decoy vanish")

# ---------------------------------------------------------------------------
# mitosis
# ---------------------------------------------------------------------------

func _test_mitosis_sealing_small_tab_no_spawn() -> void:
	var b := _board_from([4, 6, 8, 10, 12])
	# Sealing tab 4 (< 6) should not spawn anything.
	b.seal_tab(4)
	var size_before := b.get_remaining().size()
	_BoxTabBehavior.on_seal("mitosis", [4], b, null, 0)
	assert(b.get_remaining().size() == size_before,
		"mitosis: sealing tab < 6 should not spawn a new tab")

func _test_mitosis_sealing_large_tab_spawns() -> void:
	var b := _board_from([4, 6, 8, 10, 12])
	b.seal_tab(12)
	var size_before := b.get_remaining().size()   # 4 tabs
	_BoxTabBehavior.on_seal("mitosis", [12], b, null, 0)
	assert(b.get_remaining().size() == size_before + 1,
		"mitosis: sealing tab 12 should spawn tab 6")
	var r := b.get_remaining()
	# Count of 6s should increase by 1 (was 1, now 2)
	var sixes := r.filter(func(v): return v == 6)
	assert(sixes.size() == 2, "mitosis: should now have two 6s after sealing 12; got %d" % sixes.size())

func _test_mitosis_recursion_cap() -> void:
	# At max depth, on_seal should not spawn.
	var b := _board_from([4, 6, 8, 10, 12])
	b.seal_tab(12)
	var size_before := b.get_remaining().size()
	_BoxTabBehavior.on_seal("mitosis", [12], b, null, _BoxTabBehavior.MITOSIS_MAX_DEPTH)
	assert(b.get_remaining().size() == size_before,
		"mitosis at max depth should not spawn")

# ---------------------------------------------------------------------------
# moving_targets
# ---------------------------------------------------------------------------

func _test_moving_targets_round_1_range() -> void:
	var gs := _make_gs_with_round(1)
	var b := _board_from([1, 2, 3, 4, 5, 6, 7])
	_BoxTabBehavior.on_round_start("moving_targets", b, gs)
	var r := b.get_remaining()
	assert(r.size() == 7, "moving_targets R1: should have 7 tabs")
	for v in [1, 2, 3, 4, 5, 6, 7]:
		assert(v in r, "moving_targets R1: should contain tab %d" % v)

func _test_moving_targets_round_4_range() -> void:
	var gs := _make_gs_with_round(4)
	var b := _board_from([1, 2, 3, 4, 5, 6, 7])
	_BoxTabBehavior.on_round_start("moving_targets", b, gs)
	var r := b.get_remaining()
	assert(r.size() == 7, "moving_targets R4: should have 7 tabs")
	for v in [4, 5, 6, 7, 8, 9, 10]:
		assert(v in r, "moving_targets R4: should contain tab %d" % v)
	assert(not (1 in r), "moving_targets R4: tab 1 should be gone")
