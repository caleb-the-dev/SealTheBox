# Power Balance + 1-of-3 Offer + 3 New Powers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tune two overpowered powers, replace the auto-pick power offer with a 1-of-3 selection UI, and add three new powers (Phoenix Down, Coffee Break, Survivor).

**Architecture:** Data changes flow through powers.csv → PowerLibrary → PowerManager. Signal `show_power_offer` changes type from `(PowerData)` to `(Array)`. Three new PowerManager helpers are added and hooked in RunManager (Phoenix Down, Survivor) and RoundManager (Coffee Break). The match.gd power offer overlay is rebuilt from a single name/desc display into a three-card selection with a Confirm button.

**Tech Stack:** GDScript 4, Godot 4 headless tests, powers.csv

---

## File Map

| File | Change |
|------|--------|
| `seal-the-box/data/powers.csv` | Tune Lighter Box (+3→+1) and Box Shutter (+5→+2); add phoenix_down, coffee_break, survivor |
| `seal-the-box/scripts/globals/power_library.gd` | Add `get_random_unowned_multiple(owned, count) -> Array` |
| `seal-the-box/scripts/run/power_manager.gd` | Fix multipliers; add `apply_coffee_break()`, `apply_survivor()`, `try_phoenix_down() -> bool` |
| `seal-the-box/scripts/run/run_manager.gd` | Signal type change; Survivor in `handle_match_won`; Phoenix Down in `handle_match_lost`; `_do_power_offer` uses multiple |
| `seal-the-box/scripts/match/round_manager.gd` | `apply_coffee_break()` after Eager in `start_round()` |
| `seal-the-box/scripts/match/match.gd` | Rebuild power offer overlay: 3 cards + Confirm; update handler signatures |
| `seal-the-box/tests/test_power_effects.gd` | Update multiplier assertions; update `get_random_unowned` test; add tests for new powers and `get_random_unowned_multiple` |
| `seal-the-box/tests/test_run_manager.gd` | Update power count (5→8); update signal lambdas; add tests for 1-of-3 offer, Phoenix Down, Survivor, Coffee Break |

---

## Task 1: Create Feature Branch

**Files:** none

- [ ] **Step 1: Create and switch to the feature branch**

```bash
git checkout master && git checkout -b feature/power-balance-and-3-offer
```

Expected: `Switched to a new branch 'feature/power-balance-and-3-offer'`

---

## Task 2: Write Failing Tests — test_power_effects.gd

**Files:**
- Modify: `seal-the-box/tests/test_power_effects.gd`

These tests will fail until Task 5 and 6 are complete.

- [ ] **Step 1: Update `_init()` call list to add new test calls**

In `test_power_effects.gd`, replace the `_init()` function body with the updated list including new test calls:

```gdscript
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
	_test_survivor_heals_at_1hp(gs, pm)
	_test_survivor_no_heal_above_1hp(gs, pm)
	_test_phoenix_down_saves_run(gs, pm)
	_test_phoenix_down_not_triggered_when_not_owned(gs, pm)
	print("All PowerEffects tests passed!")
	quit()
```

- [ ] **Step 2: Update Lighter Box multiplier assertions (3→1, 6→2)**

Replace:
```gdscript
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
```

With:
```gdscript
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
```

- [ ] **Step 3: Update Box Shutter multiplier assertions (5→2, 10→4) and rename test**

Replace:
```gdscript
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
```

With:
```gdscript
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
```

- [ ] **Step 4: Update get_random_unowned test to account for 8 total powers**

Replace:
```gdscript
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
```

With:
```gdscript
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
```

- [ ] **Step 5: Add get_random_unowned_multiple tests (append after existing `get_random_unowned` tests)**

```gdscript
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
```

- [ ] **Step 6: Add Coffee Break, Survivor, and Phoenix Down unit tests (append after existing tests)**

```gdscript
# ── Coffee Break ─────────────────────────────────────────────────────────────

func _test_coffee_break_adds_charge(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("coffee_break")]
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("greater_1").duplicate()
	var original_charges = ability.charges
	gs.ability_hand = [null, null, ability]

	pm.apply_coffee_break()

	assert(ability.charges == original_charges + 1,
		"Coffee Break: charge should increase by 1, got %d (expected %d)" % [ability.charges, original_charges + 1])

func _test_coffee_break_no_effect_with_empty_hand(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("coffee_break")]
	gs.ability_hand = [null, null, null]
	pm.apply_coffee_break()
	# Should not crash; no assertion needed beyond reaching this line

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
```

- [ ] **Step 7: Verify tests fail as expected (powers not implemented yet)**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: test failures referencing `get_random_unowned_multiple`, wrong multiplier values, and missing `apply_coffee_break`/`apply_survivor`/`try_phoenix_down`.

- [ ] **Step 8: Commit failing tests**

```bash
git add seal-the-box/tests/test_power_effects.gd
git commit -m "test: add failing tests for power balance and new power effects"
```

---

## Task 3: Write Failing Tests — test_run_manager.gd

**Files:**
- Modify: `seal-the-box/tests/test_run_manager.gd`

- [ ] **Step 1: Add new test calls to `_init()`**

In `test_run_manager.gd`, update the `_init()` body to add new test function calls after the existing ones (before `print("All RunManager tests passed!")`):

```gdscript
	_test_power_library_loads_all_powers()
	_test_critical_win_triggers_power_offer_then_rotation(gs)
	_test_power_offer_accept_adds_to_owned_powers(gs)
	_test_box_cycle_five_boxes(gs)
	_test_die_swap_fires_after_match_5(gs)
	_test_die_swap_fires_after_match_10(gs)
	_test_die_swap_confirm_replaces_die(gs)
	_test_die_swap_skip_preserves_pool(gs)
	_test_power_offer_shows_array_of_up_to_3(gs)
	_test_power_offer_fewer_than_3_shows_remainder(gs)
	_test_power_offer_0_unowned_skips_to_rotation(gs)
	_test_phoenix_down_prevents_run_over(gs)
	_test_survivor_heals_at_1hp_after_win(gs)
	_test_survivor_no_heal_above_1hp_after_win(gs)
	_test_coffee_break_adds_charge_at_match_start(gs)
```

- [ ] **Step 2: Update `_test_power_library_loads_all_powers` to expect 8 powers**

Replace:
```gdscript
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
```

With:
```gdscript
func _test_power_library_loads_all_powers() -> void:
	var power_lib = Engine.get_singleton("PowerLibrary")
	assert(power_lib != null, "PowerLibrary singleton should be registered")
	var all_powers = power_lib.get_all()
	assert(all_powers.size() == 8, "PowerLibrary should have 8 powers, got %d" % all_powers.size())
	var ids = all_powers.map(func(p): return p.id)
	assert("lighter_box" in ids, "lighter_box should be in PowerLibrary")
	assert("eager" in ids, "eager should be in PowerLibrary")
	assert("tab_9_bounty" in ids, "tab_9_bounty should be in PowerLibrary")
	assert("bonus_seal" in ids, "bonus_seal should be in PowerLibrary")
	assert("box_shutter" in ids, "box_shutter should be in PowerLibrary")
	assert("phoenix_down" in ids, "phoenix_down should be in PowerLibrary")
	assert("coffee_break" in ids, "coffee_break should be in PowerLibrary")
	assert("survivor" in ids, "survivor should be in PowerLibrary")
	var power = power_lib.get_power("lighter_box")
	assert(power != null, "get_power('lighter_box') should return a PowerData")
	assert(power.name == "Lighter Box", "lighter_box name should be 'Lighter Box', got '%s'" % power.name)
```

- [ ] **Step 3: Update `_test_critical_win_triggers_power_offer_then_rotation` for Array signal**

Replace the lambda inside it:
```gdscript
	rm.show_power_offer.connect(func(power): power_offer_log.append(power))
```

With:
```gdscript
	rm.show_power_offer.connect(func(powers): power_offer_log.append(powers))
```

- [ ] **Step 4: Update `_test_power_offer_accept_adds_to_owned_powers` for Array signal**

Replace the lambda inside it:
```gdscript
	rm.show_power_offer.connect(func(power): rm.call("handle_power_offer_accepted", power))
```

With:
```gdscript
	rm.show_power_offer.connect(func(powers): rm.call("handle_power_offer_accepted", powers[0]))
```

- [ ] **Step 5: Add power offer, Phoenix Down, Survivor, and Coffee Break integration tests (append after `_test_die_swap_skip_preserves_pool`)**

```gdscript
func _test_power_offer_shows_array_of_up_to_3(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	var offer_log: Array = []
	rm.show_power_offer.connect(func(powers): offer_log.append(powers))
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	rm.handle_match_won(true)

	assert(offer_log.size() == 1, "critical win should emit show_power_offer once, got %d" % offer_log.size())
	var offered = offer_log[0]
	assert(offered is Array, "show_power_offer should emit an Array")
	assert(offered.size() >= 1, "power offer should have at least 1 power")
	assert(offered.size() <= 3, "power offer should have at most 3 powers, got %d" % offered.size())

	rm.handle_power_offer_skipped()
	rm.queue_free()

func _test_power_offer_fewer_than_3_shows_remainder(gs: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	# Own 7 of 8, leaving only box_shutter
	gs.owned_powers = [
		power_lib.get_power("lighter_box"),
		power_lib.get_power("eager"),
		power_lib.get_power("tab_9_bounty"),
		power_lib.get_power("bonus_seal"),
		power_lib.get_power("phoenix_down"),
		power_lib.get_power("coffee_break"),
		power_lib.get_power("survivor"),
	]
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	var offer_log: Array = []
	rm.show_power_offer.connect(func(powers): offer_log.append(powers))
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	rm.handle_match_won(true)

	assert(offer_log.size() == 1, "should fire once")
	assert(offer_log[0].size() == 1,
		"with 1 unowned power, offer should show 1, got %d" % offer_log[0].size())
	assert(offer_log[0][0].id == "box_shutter", "only unowned power should be box_shutter")

	rm.handle_power_offer_skipped()
	rm.queue_free()

func _test_power_offer_0_unowned_skips_to_rotation(gs: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = power_lib.get_all()  # own everything

	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	var power_offer_count = [0]
	var rotation_count = [0]
	rm.show_power_offer.connect(func(_powers): power_offer_count[0] += 1)
	rm.show_rotation_offer.connect(func(opts):
		rotation_count[0] += 1
		rm.handle_rotation_pick(opts[0])
	)

	rm.start_run()
	rm.handle_match_won(true)

	assert(power_offer_count[0] == 0,
		"0 unowned: power offer should NOT show, got %d" % power_offer_count[0])
	assert(rotation_count[0] == 1,
		"0 unowned: rotation should fire directly, got %d" % rotation_count[0])
	rm.queue_free()

func _test_phoenix_down_prevents_run_over(gs: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("phoenix_down")]

	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	var run_over_log: Array = []
	rm.run_over.connect(func(n): run_over_log.append(n))
	var next_match_count = [0]
	rm.next_match_ready.connect(func(_box): next_match_count[0] += 1)

	rm.start_run()
	assert(next_match_count[0] == 1, "start_run should emit next_match_ready once")

	rm.handle_match_lost()

	assert(run_over_log.size() == 0,
		"Phoenix Down: run_over should NOT fire, got %d" % run_over_log.size())
	assert(gs.hp == 1,
		"Phoenix Down: hp should be set to 1, got %d" % gs.hp)
	assert(next_match_count[0] == 2,
		"Phoenix Down: next match should start (next_match_ready fires again)")
	var phoenix_count := 0
	for p in gs.owned_powers:
		if p.id == "phoenix_down":
			phoenix_count += 1
	assert(phoenix_count == 0, "Phoenix Down: power should be consumed from owned_powers")
	rm.queue_free()

func _test_survivor_heals_at_1hp_after_win(gs: Node) -> void:
	gs.reset_run()
	gs.hp = 1
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("survivor")]

	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_power_offer.connect(func(_powers): rm.handle_power_offer_skipped())
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	rm.handle_match_won(false)

	assert(gs.hp == 2,
		"Survivor: hp should be 2 after threshold win at 1hp, got %d" % gs.hp)
	rm.queue_free()

func _test_survivor_no_heal_above_1hp_after_win(gs: Node) -> void:
	gs.reset_run()
	gs.hp = 3
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("survivor")]

	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	rm.handle_match_won(false)

	assert(gs.hp == 3,
		"Survivor: hp should remain 3, not change at 3hp, got %d" % gs.hp)
	rm.queue_free()

func _test_coffee_break_adds_charge_at_match_start(gs: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("coffee_break")]
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("greater_1").duplicate()
	var original_charges = ability.charges
	gs.ability_hand = [null, null, ability]

	var round_mgr = RoundManager.new()
	get_root().add_child(round_mgr)
	round_mgr.start_match(Engine.get_singleton("BoxLibrary").get_ordered()[0])

	assert(ability.charges == original_charges + 1,
		"Coffee Break: match start should add 1 charge, got %d (expected %d)" % [ability.charges, original_charges + 1])
	round_mgr.queue_free()
```

- [ ] **Step 6: Commit failing tests**

```bash
git add seal-the-box/tests/test_run_manager.gd
git commit -m "test: add failing tests for 1-of-3 power offer, Phoenix Down, Survivor, Coffee Break"
```

---

## Task 4: Update powers.csv

**Files:**
- Modify: `seal-the-box/data/powers.csv`

- [ ] **Step 1: Rewrite powers.csv with tuned values and 3 new powers**

Replace the entire file content with:
```
id,name,type,description
lighter_box,Lighter Box,Passive,All match win thresholds are +1 per copy owned.
eager,Eager,Match-Start,At each match start one random die is pre-set to its max face — usable for sealing in round 1 without rolling.
tab_9_bounty,Tab 9 Bounty,On-Seal,When tab 9 is sealed gain +1 HP per copy owned.
bonus_seal,Bonus Seal,On-Seal,Sealing a tab also seals half its value (rounded down) if still open. E.g. sealing 8 seals 4; sealing 5 seals 2. No chain reactions.
box_shutter,Box Shutter,Critical-Win,After a critical win the next match's win threshold is +2 per copy owned.
phoenix_down,Phoenix Down,Failsafe,When your run would end from HP reaching 0 instead set HP to 1 and continue. Consumed on use.
coffee_break,Coffee Break,Match-Start,At each match start a random ability in your hand gains +1 charge per copy owned.
survivor,Survivor,Match-End,After winning any match if your HP is exactly 1 gain +1 HP per copy owned.
```

- [ ] **Step 2: Commit CSV changes**

```bash
git add seal-the-box/data/powers.csv
git commit -m "data: tune Lighter Box (+1) and Box Shutter (+2); add phoenix_down, coffee_break, survivor"
```

---

## Task 5: Update power_library.gd

**Files:**
- Modify: `seal-the-box/scripts/globals/power_library.gd`

- [ ] **Step 1: Add `get_random_unowned_multiple` method**

Append to `power_library.gd` (after `get_random_unowned`):

```gdscript
func get_random_unowned_multiple(owned_powers: Array, count: int) -> Array:
	var owned_ids: Dictionary = {}
	for p in owned_powers:
		owned_ids[p.id] = true
	var candidates = _powers.values().filter(func(p): return not owned_ids.has(p.id))
	candidates.shuffle()
	return candidates.slice(0, min(count, candidates.size()))
```

- [ ] **Step 2: Commit**

```bash
git add seal-the-box/scripts/globals/power_library.gd
git commit -m "feat: add get_random_unowned_multiple to PowerLibrary"
```

---

## Task 6: Update power_manager.gd

**Files:**
- Modify: `seal-the-box/scripts/run/power_manager.gd`

- [ ] **Step 1: Fix `get_threshold_bonus` multiplier (3 → 1)**

Replace:
```gdscript
func get_threshold_bonus() -> int:
	return count_owned("lighter_box") * 3
```

With:
```gdscript
func get_threshold_bonus() -> int:
	return count_owned("lighter_box") * 1
```

- [ ] **Step 2: Fix `apply_box_shutter` multiplier (5 → 2)**

Replace:
```gdscript
func apply_box_shutter() -> void:
	var count = count_owned("box_shutter")
	if count == 0:
		return
	GameState.pending_threshold_bonus += count * 5
```

With:
```gdscript
func apply_box_shutter() -> void:
	var count = count_owned("box_shutter")
	if count == 0:
		return
	GameState.pending_threshold_bonus += count * 2
```

- [ ] **Step 3: Add new power helpers (append to end of file)**

```gdscript
func apply_coffee_break() -> void:
	var count = count_owned("coffee_break")
	if count == 0:
		return
	var non_null: Array = []
	for ability in GameState.ability_hand:
		if ability != null:
			non_null.append(ability)
	if non_null.is_empty():
		return
	var target = non_null[randi() % non_null.size()]
	target.charges += count

func apply_survivor() -> void:
	var count = count_owned("survivor")
	if count == 0 or GameState.hp != 1:
		return
	GameState.hp += count

func try_phoenix_down() -> bool:
	var count = count_owned("phoenix_down")
	if count == 0:
		return false
	for i in GameState.owned_powers.size():
		if GameState.owned_powers[i].id == "phoenix_down":
			GameState.owned_powers.remove_at(i)
			break
	GameState.hp = 1
	return true
```

- [ ] **Step 4: Run power effects tests — verify all pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: `All PowerEffects tests passed!`

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/run/power_manager.gd
git commit -m "feat: fix Lighter Box/Box Shutter multipliers; add coffee_break, survivor, phoenix_down to PowerManager"
```

---

## Task 7: Update run_manager.gd

**Files:**
- Modify: `seal-the-box/scripts/run/run_manager.gd`

- [ ] **Step 1: Change `show_power_offer` signal type**

Replace:
```gdscript
signal show_power_offer(power: PowerData)
```

With:
```gdscript
signal show_power_offer(powers: Array)
```

- [ ] **Step 2: Add Survivor call in `handle_match_won`**

Replace:
```gdscript
func handle_match_won(critical: bool) -> void:
	match_number += 1
	if critical:
		if Engine.has_singleton("PowerManager"):
			Engine.get_singleton("PowerManager").apply_box_shutter()
		_do_power_offer()
	else:
		_do_rotation_offer()
```

With:
```gdscript
func handle_match_won(critical: bool) -> void:
	match_number += 1
	if Engine.has_singleton("PowerManager"):
		Engine.get_singleton("PowerManager").apply_survivor()
	if critical:
		if Engine.has_singleton("PowerManager"):
			Engine.get_singleton("PowerManager").apply_box_shutter()
		_do_power_offer()
	else:
		_do_rotation_offer()
```

- [ ] **Step 3: Add Phoenix Down intercept in `handle_match_lost`**

Replace:
```gdscript
func handle_match_lost() -> void:
	run_over.emit(match_number)
```

With:
```gdscript
func handle_match_lost() -> void:
	if Engine.has_singleton("PowerManager"):
		if Engine.get_singleton("PowerManager").try_phoenix_down():
			match_number += 1
			_start_next_match()
			return
	run_over.emit(match_number)
```

- [ ] **Step 4: Update `_do_power_offer` to use `get_random_unowned_multiple`**

Replace:
```gdscript
func _do_power_offer() -> void:
	var gs = Engine.get_singleton("GameState")
	if not Engine.has_singleton("PowerLibrary"):
		_do_rotation_offer()
		return
	var power = Engine.get_singleton("PowerLibrary").get_random_unowned(gs.owned_powers)
	if power == null:
		_do_rotation_offer()
		return
	show_power_offer.emit(power)
```

With:
```gdscript
func _do_power_offer() -> void:
	var gs = Engine.get_singleton("GameState")
	if not Engine.has_singleton("PowerLibrary"):
		_do_rotation_offer()
		return
	var powers = Engine.get_singleton("PowerLibrary").get_random_unowned_multiple(gs.owned_powers, 3)
	if powers.is_empty():
		_do_rotation_offer()
		return
	show_power_offer.emit(powers)
```

- [ ] **Step 5: Run run_manager tests — verify all pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: `All RunManager tests passed!`

- [ ] **Step 6: Commit**

```bash
git add seal-the-box/scripts/run/run_manager.gd
git commit -m "feat: 1-of-3 power offer signal; add Phoenix Down and Survivor hooks to RunManager"
```

---

## Task 8: Update round_manager.gd — Coffee Break Hook

**Files:**
- Modify: `seal-the-box/scripts/match/round_manager.gd`

- [ ] **Step 1: Add `apply_coffee_break()` call in `start_round()` after Eager**

Replace:
```gdscript
	if GameState.round == 1:
		var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
		if power_mgr:
			power_mgr.apply_eager(hand)
```

With:
```gdscript
	if GameState.round == 1:
		var power_mgr = Engine.get_singleton("PowerManager") if Engine.has_singleton("PowerManager") else null
		if power_mgr:
			power_mgr.apply_eager(hand)
			power_mgr.apply_coffee_break()
```

- [ ] **Step 2: Run all tests to verify nothing broke**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: `All RunManager tests passed!`

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: `All PowerEffects tests passed!`

- [ ] **Step 3: Commit**

```bash
git add seal-the-box/scripts/match/round_manager.gd
git commit -m "feat: trigger Coffee Break after Eager at match start in RoundManager"
```

---

## Task 9: Rebuild match.gd Power Offer Overlay

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

This task rebuilds the power offer overlay from a single-power display (Accept/Skip) to a 3-card selection (card highlight + Confirm/Skip). No headless test covers this; QA will validate it visually.

- [ ] **Step 1: Update member variable declarations**

Remove these two lines from the member variable block (around lines 33-36):
```gdscript
var _power_offer_name_label: Label
var _power_offer_desc_label: Label
```

Add these three in their place:
```gdscript
var _power_offer_cards: Array[Button] = []
var _power_offer_confirm_btn: Button
var _power_offer_options: Array = []
```

- [ ] **Step 2: Replace the power offer overlay build in `_setup_ui()`**

Find and replace the entire power offer overlay section (from `# ── Power offer overlay` through `_power_offer_overlay = power_overlay`):

Replace this block:
```gdscript
	# ── Power offer overlay (hidden until a critical win) ────────────────────────
	var power_overlay = Control.new()
	power_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	power_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	power_overlay.visible = false
	var power_bg = ColorRect.new()
	power_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	power_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	power_overlay.add_child(power_bg)

	var power_center = VBoxContainer.new()
	power_center.anchor_left = 0.25
	power_center.anchor_right = 0.75
	power_center.anchor_top = 0.25
	power_center.anchor_bottom = 0.8
	power_center.add_theme_constant_override("separation", 24)
	power_overlay.add_child(power_center)

	var power_header = Label.new()
	power_header.text = "Shut the Box! — Power Earned"
	power_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_header.add_theme_font_size_override("font_size", 22)
	power_center.add_child(power_header)

	_power_offer_name_label = Label.new()
	_power_offer_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_offer_name_label.add_theme_font_size_override("font_size", 30)
	power_center.add_child(_power_offer_name_label)

	_power_offer_desc_label = Label.new()
	_power_offer_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_offer_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power_offer_desc_label.add_theme_font_size_override("font_size", 18)
	power_center.add_child(_power_offer_desc_label)

	var power_btn_row = HBoxContainer.new()
	power_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_btn_row.add_theme_constant_override("separation", 24)
	power_center.add_child(power_btn_row)

	var accept_btn = Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(130, 64)
	accept_btn.add_theme_font_size_override("font_size", 20)
	accept_btn.pressed.connect(_on_power_offer_accepted)
	power_btn_row.add_child(accept_btn)

	var skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(130, 64)
	skip_btn.add_theme_font_size_override("font_size", 20)
	skip_btn.pressed.connect(_on_power_offer_skipped)
	power_btn_row.add_child(skip_btn)

	root.add_child(power_overlay)
	_power_offer_overlay = power_overlay
```

With this new block:
```gdscript
	# ── Power offer overlay (hidden until a critical win) ────────────────────────
	var power_overlay = Control.new()
	power_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	power_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	power_overlay.visible = false
	var power_bg = ColorRect.new()
	power_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	power_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	power_overlay.add_child(power_bg)

	var power_center = VBoxContainer.new()
	power_center.anchor_left = 0.1
	power_center.anchor_right = 0.9
	power_center.anchor_top = 0.1
	power_center.anchor_bottom = 0.9
	power_center.add_theme_constant_override("separation", 24)
	power_overlay.add_child(power_center)

	var power_header = Label.new()
	power_header.text = "Shut the Box! — Choose a Power"
	power_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_header.add_theme_font_size_override("font_size", 22)
	power_center.add_child(power_header)

	var power_cards_row = HBoxContainer.new()
	power_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_cards_row.add_theme_constant_override("separation", 24)
	power_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	power_center.add_child(power_cards_row)

	_power_offer_cards = []
	for i in 3:
		var card = Button.new()
		card.custom_minimum_size = Vector2(200, 140)
		card.add_theme_font_size_override("font_size", 15)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.pressed.connect(_on_power_card_pressed.bind(i))
		power_cards_row.add_child(card)
		_power_offer_cards.append(card)

	var power_btn_row = HBoxContainer.new()
	power_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_btn_row.add_theme_constant_override("separation", 24)
	power_center.add_child(power_btn_row)

	_power_offer_confirm_btn = Button.new()
	_power_offer_confirm_btn.text = "Confirm"
	_power_offer_confirm_btn.custom_minimum_size = Vector2(130, 64)
	_power_offer_confirm_btn.add_theme_font_size_override("font_size", 20)
	_power_offer_confirm_btn.disabled = true
	_power_offer_confirm_btn.pressed.connect(_on_power_confirm_pressed)
	power_btn_row.add_child(_power_offer_confirm_btn)

	var skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(130, 64)
	skip_btn.add_theme_font_size_override("font_size", 20)
	skip_btn.pressed.connect(_on_power_offer_skipped)
	power_btn_row.add_child(skip_btn)

	root.add_child(power_overlay)
	_power_offer_overlay = power_overlay
```

- [ ] **Step 3: Replace signal handlers for power offer**

Remove the existing `_on_show_power_offer` and `_on_power_offer_accepted` functions entirely, and replace with these four:

```gdscript
func _on_show_power_offer(powers: Array) -> void:
	_power_offer_options = powers
	_current_power_offer = null
	_power_offer_confirm_btn.disabled = true
	for i in _power_offer_cards.size():
		if i < powers.size():
			var p = powers[i]
			_power_offer_cards[i].text = "%s\n\n%s" % [p.name, p.description]
			_power_offer_cards[i].modulate = Color.WHITE
			_power_offer_cards[i].visible = true
		else:
			_power_offer_cards[i].visible = false
	_power_offer_overlay.visible = true

func _on_power_card_pressed(index: int) -> void:
	if index >= _power_offer_options.size():
		return
	_current_power_offer = _power_offer_options[index]
	for i in _power_offer_cards.size():
		_power_offer_cards[i].modulate = Color(1.5, 1.5, 0.3) if i == index else Color.WHITE
	_power_offer_confirm_btn.disabled = false

func _on_power_confirm_pressed() -> void:
	if _current_power_offer == null:
		return
	_power_offer_overlay.visible = false
	_run_manager.handle_power_offer_accepted(_current_power_offer)
	_refresh_powers_panel()

func _on_power_offer_skipped() -> void:
	_power_offer_overlay.visible = false
	_run_manager.handle_power_offer_skipped()
```

- [ ] **Step 4: Run all headless tests to confirm logic is still intact**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: `All RunManager tests passed!`

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: `All PowerEffects tests passed!`

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: rebuild power offer overlay — 3-card selection with Confirm/Skip"
```

---

## Task 10: QA Handoff

**Files:** none

- [ ] **Step 1: Give Caleb the QA checklist**

Hand off the following to Caleb for playtesting:

**Bug checks:**
- [ ] Critical win shows exactly 3 power cards (or however many are unowned)
- [ ] Clicking a card highlights it yellow and enables Confirm
- [ ] Confirm adds the highlighted power to the owned powers panel
- [ ] Skip closes the overlay with no power added
- [ ] When all 8 powers are owned, critical win skips straight to rotation (no overlay)
- [ ] When only 1 power remains unowned, 1 card shows; the other 2 card slots are hidden
- [ ] Lighter Box: each copy owned adds exactly +1 to the match win threshold
- [ ] Box Shutter: each copy owned adds exactly +2 to the NEXT match's win threshold (not current)
- [ ] Phoenix Down: when a loss would end the run (HP hits 0 in overtime), HP resets to 1 and the next match starts — Phoenix Down is removed from the powers panel
- [ ] Phoenix Down: owning 2 copies saves you twice across two separate would-be run-ends
- [ ] Coffee Break: at each match start, a random non-null ability in your hand shows +1 extra charge compared to where it ended last match
- [ ] Coffee Break: if all ability slots are null, no crash and no error
- [ ] Survivor: win a match at exactly 1 HP → HP becomes 2
- [ ] Survivor: win a match at 2+ HP → HP unchanged

**Playability questions:**
- Does Lighter Box at +1 feel like a real choice now, or is it still auto-pick?
- Does 1-of-3 selection make power picks feel meaningful, or does the variety feel overwhelming?
- Does Phoenix Down remove the "bad-luck-killed-me" feeling, or is it too rare to matter?
- Are Coffee Break and Survivor useful enough to pick over the originals, or too situational?
