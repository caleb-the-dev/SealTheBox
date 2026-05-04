# First Powers + Dice Pool 7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the first 5 powers (persistent run progression), replace critical-win dice rewards with power offers, and bump the dice pool to 7 dice.

**Architecture:** PowerData/PowerLibrary mirror the AbilityData/AbilityLibrary pattern; PowerManager is a new autoload that exposes effect methods called directly by RoundManager and RunManager; RunManager replaces `show_reward` with `show_power_offer`; match.gd gets a powers side panel and replaces the reward overlay with a power offer overlay.

**Tech Stack:** GDScript 4, Godot 4.5.1, CSV data files, headless test runner via SceneTree

---

## File Map

**New files:**
- `seal-the-box/data/powers.csv` — 5 power rows (id, name, type, description)
- `seal-the-box/resources/power_data.gd` — PowerData Resource subclass
- `seal-the-box/scripts/globals/power_library.gd` — PowerLibrary autoload (parses CSV)
- `seal-the-box/scripts/run/power_manager.gd` — PowerManager autoload (effect methods)
- `seal-the-box/tests/test_power_effects.gd` — headless tests for all 5 power effects

**Modified files:**
- `seal-the-box/project.godot` — register PowerLibrary + PowerManager autoloads
- `seal-the-box/scripts/globals/game_state.gd` — owned_powers, pending_threshold_bonus, dice pool → 7
- `seal-the-box/scripts/run/run_manager.gd` — remove dice reward, add power offer signals/methods
- `seal-the-box/scripts/match/round_manager.gd` — Lighter Box in start_match, Eager in start_round, Bonus Seal + Tab9Bounty in attempt_seal
- `seal-the-box/scripts/match/match.gd` — remove reward overlay, add power offer overlay + powers side panel
- `seal-the-box/tests/test_run_manager.gd` — update pool size test, replace critical-win test, add owned_powers tests

---

## Task 1: Branch Setup

**Files:**
- No file edits — just git commands

- [ ] **Step 1: Create feature branch**

```bash
git checkout master
git checkout -b feature/first-powers
```

Expected: branch `feature/first-powers` checked out at the master HEAD.

---

## Task 2: Dice Pool → 7 Dice

Update the starting dice pool from 3d6+1d4+1d8 (5 dice) to 1d4+4d6+2d8 (7 dice), with a failing test first.

**Files:**
- Modify: `seal-the-box/tests/test_run_manager.gd:46-52` (update pool size test)
- Modify: `seal-the-box/scripts/globals/game_state.gd:31-35` (_setup_dice_pool)

- [ ] **Step 1: Update the failing test**

In `seal-the-box/tests/test_run_manager.gd`, replace the `_test_reset_run_sets_starting_dice_pool` function:

```gdscript
func _test_reset_run_sets_starting_dice_pool(gs: Node) -> void:
	gs.dice_pool = []
	gs.reset_run()
	assert(gs.dice_pool.size() == 7, "starting pool should be 7 dice, got %d" % gs.dice_pool.size())
	var faces = gs.dice_pool.map(func(d): return d.faces)
	faces.sort()
	assert(faces == [4, 6, 6, 6, 6, 8, 8], "starting pool should be 1d4+4d6+2d8, got %s" % str(faces))
```

- [ ] **Step 2: Run test to confirm failure**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: test fails with assertion about pool size 5 vs 7.

- [ ] **Step 3: Update `_setup_dice_pool` in game_state.gd**

Replace the `_setup_dice_pool` function body:

```gdscript
func _setup_dice_pool() -> void:
	dice_pool = []
	dice_pool.append(Die.new(4))
	for i in 4:
		dice_pool.append(Die.new(6))
	dice_pool.append(Die.new(8))
	dice_pool.append(Die.new(8))
```

- [ ] **Step 4: Run tests to confirm pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: All RunManager tests passed!

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/tests/test_run_manager.gd seal-the-box/scripts/globals/game_state.gd
git commit -m "feat: bump default dice pool to 7 dice (1d4+4d6+2d8)"
```

---

## Task 3: GameState — owned_powers + pending_threshold_bonus

Add two new fields to GameState. `owned_powers` persists across `reset_match()` but clears on `reset_run()`. `pending_threshold_bonus` resets on `reset_run()` and is consumed/reset inside `start_match` (implemented in Task 7). The tests for persistence go first.

**Files:**
- Modify: `seal-the-box/tests/test_run_manager.gd` (add 2 tests + register steps)
- Modify: `seal-the-box/scripts/globals/game_state.gd` (add fields + reset logic)

- [ ] **Step 1: Add two new tests at the bottom of test_run_manager.gd**

Append before the closing of the file (after `_test_exhausted_ability_blocked`):

```gdscript
func _test_owned_powers_persists_across_reset_match(gs: Node) -> void:
	gs.reset_run()
	var fake_power = {"id": "test_power"}
	gs.owned_powers.append(fake_power)
	gs.reset_match()
	assert(gs.owned_powers.size() == 1, "reset_match should preserve owned_powers, got %d" % gs.owned_powers.size())

func _test_owned_powers_cleared_by_reset_run(gs: Node) -> void:
	gs.owned_powers = [{"id": "test_power"}, {"id": "another"}]
	gs.reset_run()
	assert(gs.owned_powers.size() == 0, "reset_run should clear owned_powers, got %d" % gs.owned_powers.size())
```

Also add the two calls to `_init()` after the existing test calls:

```gdscript
	_test_owned_powers_persists_across_reset_match(gs)
	_test_owned_powers_cleared_by_reset_run(gs)
```

- [ ] **Step 2: Run tests to confirm failures**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: fails — `owned_powers` doesn't exist yet.

- [ ] **Step 3: Add fields and reset logic to game_state.gd**

Add these two fields after `var current_box: BoxDefinition = null`:

```gdscript
var owned_powers: Array = []
var pending_threshold_bonus: int = 0
```

In `reset_run()`, add `owned_powers = []` and `pending_threshold_bonus = 0` after `hp = 6`:

```gdscript
func reset_run() -> void:
	hp = 6
	owned_powers = []
	pending_threshold_bonus = 0
	_setup_dice_pool()
	reset_match()
	_setup_ability_hand()
```

`reset_match()` stays unchanged — it does NOT clear `owned_powers` or `pending_threshold_bonus`.

- [ ] **Step 4: Run tests to confirm pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: All RunManager tests passed!

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/globals/game_state.gd seal-the-box/tests/test_run_manager.gd
git commit -m "feat: add owned_powers and pending_threshold_bonus to GameState"
```

---

## Task 4: PowerData Resource + powers.csv

No meaningful unit tests for a data class — correctness is verified when PowerLibrary loads it in Task 5.

**Files:**
- Create: `seal-the-box/resources/power_data.gd`
- Create: `seal-the-box/data/powers.csv`

- [ ] **Step 1: Create power_data.gd**

```gdscript
class_name PowerData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var type: String = ""
@export var description: String = ""
```

- [ ] **Step 2: Create powers.csv**

```
id,name,type,description
lighter_box,Lighter Box,Passive,All match win thresholds are +3 per copy owned.
eager,Eager,Match-Start,At each match start one random die is pre-set to its max face — usable for sealing in round 1 without rolling.
tab_9_bounty,Tab 9 Bounty,On-Seal,When tab 9 is sealed gain +1 HP per copy owned.
bonus_seal,Bonus Seal,On-Seal,When you seal tab N also seal tab floor(N/2) if it is open and N >= 2. Bonus seals do not cascade.
box_shutter,Box Shutter,Critical-Win,After a critical win the next match's win threshold is +5 per copy owned.
```

- [ ] **Step 3: Commit**

```bash
git add seal-the-box/resources/power_data.gd seal-the-box/data/powers.csv
git commit -m "feat: add PowerData resource and powers.csv with 5 powers"
```

---

## Task 5: PowerLibrary Autoload

**Files:**
- Create: `seal-the-box/scripts/globals/power_library.gd`
- Modify: `seal-the-box/project.godot` (register autoload)
- Modify: `seal-the-box/tests/test_run_manager.gd` (register PowerLibrary in _init)

- [ ] **Step 1: Write a failing test for PowerLibrary in test_run_manager.gd**

Add this test function and call in `_init()`. Add the call right before `print("All RunManager tests passed!")`:

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

Also add the PowerLibrary registration block to `_init()` (after AbilityLibrary, before GameState):

```gdscript
	var power_lib = load("res://scripts/globals/power_library.gd").new()
	power_lib.name = "PowerLibrary"
	get_root().add_child(power_lib)
	power_lib._ready()
	Engine.register_singleton("PowerLibrary", power_lib)
```

- [ ] **Step 2: Run test to confirm failure**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: fails — PowerLibrary file does not exist yet.

- [ ] **Step 3: Create power_library.gd**

```gdscript
extends Node

var _powers: Dictionary = {}

func _ready() -> void:
	_load_csv()

func _load_csv() -> void:
	var file = FileAccess.open("res://data/powers.csv", FileAccess.READ)
	if not file:
		push_error("PowerLibrary: cannot open res://data/powers.csv")
		return
	file.get_csv_line()  # skip header row
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 4 or row[0].strip_edges().is_empty():
			continue
		var data = PowerData.new()
		data.id = row[0].strip_edges()
		data.name = row[1].strip_edges()
		data.type = row[2].strip_edges()
		data.description = row[3].strip_edges()
		_powers[data.id] = data
	file.close()

func get_power(id: String) -> PowerData:
	return _powers.get(id, null)

func get_all() -> Array:
	return _powers.values()

func get_random_unowned(owned_powers: Array) -> PowerData:
	var owned_ids: Dictionary = {}
	for p in owned_powers:
		owned_ids[p.id] = true
	var candidates = _powers.values().filter(func(p): return not owned_ids.has(p.id))
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
```

- [ ] **Step 4: Register PowerLibrary in project.godot**

Add this line to the `[autoload]` section (after BoxLibrary):

```
PowerLibrary="*res://scripts/globals/power_library.gd"
```

- [ ] **Step 5: Run tests to confirm pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: All RunManager tests passed!

- [ ] **Step 6: Commit**

```bash
git add seal-the-box/scripts/globals/power_library.gd seal-the-box/project.godot seal-the-box/tests/test_run_manager.gd
git commit -m "feat: add PowerLibrary autoload — parses powers.csv"
```

---

## Task 6: PowerManager + All 5 Power Effect Tests

PowerManager is an autoload that exposes effect methods. Each method checks `GameState.owned_powers` to determine whether/how much to apply. All 5 power effects are tested here before implementing the hooks in Tasks 7–9.

**Files:**
- Create: `seal-the-box/tests/test_power_effects.gd`
- Create: `seal-the-box/scripts/run/power_manager.gd`
- Modify: `seal-the-box/project.godot` (register PowerManager autoload)

- [ ] **Step 1: Write the full test file**

Create `seal-the-box/tests/test_power_effects.gd`:

```gdscript
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
	_test_bonus_seal_no_cascade(gs, pm)
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

func _test_bonus_seal_no_cascade(gs: Node, pm: Node) -> void:
	gs.reset_run()
	var power_lib = Engine.get_singleton("PowerLibrary")
	gs.owned_powers = [power_lib.get_power("bonus_seal")]
	var tb = TabBoard.new()
	tb.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
	tb.seal_tabs([8])
	var primary_bonus = pm.get_bonus_seals(tb, [8])
	assert(4 in primary_bonus, "Bonus Seal: tab 4 should be bonus-sealed")
	tb.seal_tabs(primary_bonus)
	var cascade_bonus = pm.get_bonus_seals(tb, primary_bonus)
	assert(cascade_bonus.is_empty(),
		"Bonus Seal: no cascade expected after bonus seals, got %s" % str(cascade_bonus))

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
	# floor(2/2) = 1 — tab 1 should be bonus-sealed (1 >= 1 and 2 >= 2)
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
```

- [ ] **Step 2: Run test file to confirm failures**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: fails — PowerManager file doesn't exist.

- [ ] **Step 3: Create power_manager.gd**

```gdscript
class_name PowerManager
extends Node

var GameState: Node:
	get: return Engine.get_singleton("GameState")

func count_owned(power_id: String) -> int:
	var count = 0
	for p in GameState.owned_powers:
		if p.id == power_id:
			count += 1
	return count

func get_threshold_bonus() -> int:
	return count_owned("lighter_box") * 3

func apply_eager(dice: Array) -> void:
	if count_owned("eager") == 0 or dice.is_empty():
		return
	var idx = randi() % dice.size()
	var die = dice[idx]
	die.value = die.faces
	die.rolled = true

func get_bonus_seals(tab_board: TabBoard, primary_seals: Array) -> Array:
	if count_owned("bonus_seal") == 0:
		return []
	var remaining = tab_board.get_remaining()
	var bonus: Array = []
	for tab in primary_seals:
		if tab < 2:
			continue
		var bonus_tab: int = tab / 2
		if bonus_tab in remaining and not bonus_tab in bonus:
			bonus.append(bonus_tab)
	return bonus

func apply_tab9_bounty(all_sealed_tabs: Array) -> void:
	var count = count_owned("tab_9_bounty")
	if count == 0 or not (9 in all_sealed_tabs):
		return
	GameState.hp += count

func apply_box_shutter() -> void:
	var count = count_owned("box_shutter")
	if count == 0:
		return
	GameState.pending_threshold_bonus += count * 5
```

- [ ] **Step 4: Register PowerManager in project.godot**

Add to the `[autoload]` section (after PowerLibrary):

```
PowerManager="*res://scripts/run/power_manager.gd"
```

- [ ] **Step 5: Run tests to confirm pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: All PowerEffects tests passed!

- [ ] **Step 6: Also confirm run_manager tests still pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: All RunManager tests passed!

- [ ] **Step 7: Commit**

```bash
git add seal-the-box/scripts/run/power_manager.gd seal-the-box/project.godot seal-the-box/tests/test_power_effects.gd
git commit -m "feat: add PowerManager autoload with all 5 power effect methods"
```

---

## Task 7: Hook Powers into RoundManager

Wire Lighter Box (threshold) and pending_threshold_bonus into `start_match`; wire Eager into `start_round` (round 1 only); wire Bonus Seal + Tab 9 Bounty into `attempt_seal`.

**Files:**
- Modify: `seal-the-box/scripts/match/round_manager.gd`

Note: All PowerManager calls are guarded with `if power_mgr:` so tests that don't register PowerManager still pass.

- [ ] **Step 1: Update `start_match` to apply Lighter Box + pending_threshold_bonus**

Replace the current `start_match` body with:

```gdscript
func start_match(box: BoxDefinition) -> void:
	GameState.current_box = box
	var threshold = box.win_threshold
	var power_mgr = Engine.get_singleton("PowerManager")
	if power_mgr:
		threshold += power_mgr.get_threshold_bonus()
		threshold += GameState.pending_threshold_bonus
		GameState.pending_threshold_bonus = 0
	GameState.win_threshold = threshold
	GameState.round_limit = box.round_limit
	GameState.tabs = box.tabs.duplicate()
	_tab_board = TabBoard.new()
	_dice_pool = DicePool.new()
	_match_over = false
	_threshold_notified = false
	GameState.reset_match()
	_tab_board.reset(GameState.tabs.duplicate())
	_dice_pool.setup(GameState.dice_pool.duplicate())
	start_round()
```

- [ ] **Step 2: Update `start_round` to apply Eager on round 1**

Replace the `start_round` body with:

```gdscript
func start_round() -> void:
	GameState.round += 1
	if GameState.round > GameState.round_limit:
		GameState.hp -= 1
		if GameState.hp <= 0:
			_match_over = true
			match_lost.emit()
			return
	var hand = _dice_pool.draw_hand()
	GameState.dice_hand = hand
	if GameState.round == 1:
		var power_mgr = Engine.get_singleton("PowerManager")
		if power_mgr:
			power_mgr.apply_eager(hand)
	_set_phase("roll")
	if GameState.round > GameState.round_limit:
		status_updated.emit("Overtime — Round %d / %d — Lost 1 HP (%d remaining). Roll Phase: select dice to roll." % [GameState.round, GameState.round_limit, GameState.hp])
	else:
		status_updated.emit("Round %d / %d — Roll Phase: select dice to roll." % [GameState.round, GameState.round_limit])
```

- [ ] **Step 3: Update `attempt_seal` to apply Bonus Seal + Tab 9 Bounty**

Replace the body of `attempt_seal` with:

```gdscript
func attempt_seal(dice: Array, tabs: Array) -> bool:
	if _match_over:
		return false
	var dice_total := 0
	for d in dice:
		dice_total += d.value
	if not _tab_board.can_seal_multi(dice_total, tabs):
		return false
	_tab_board.seal_tabs(tabs)
	var all_sealed = tabs.duplicate()
	var power_mgr = Engine.get_singleton("PowerManager")
	if power_mgr:
		var bonus = power_mgr.get_bonus_seals(_tab_board, tabs)
		if not bonus.is_empty():
			_tab_board.seal_tabs(bonus)
			all_sealed.append_array(bonus)
		power_mgr.apply_tab9_bounty(all_sealed)
	GameState.tabs = _tab_board.get_remaining()
	tabs_sealed.emit(all_sealed)
	_check_win()
	return true
```

- [ ] **Step 4: Run both test suites to confirm no regressions**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: Both print their "All ... tests passed!" lines.

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/match/round_manager.gd
git commit -m "feat: hook Lighter Box, Eager, Bonus Seal, Tab9Bounty into RoundManager"
```

---

## Task 8: Replace Dice Reward with Power Offer in RunManager

Remove `show_reward`, `REWARD_DIE_FACES`, `handle_reward_picked`, and `_pick_reward_dice`. Add `show_power_offer`, `handle_power_offer_accepted`, `handle_power_offer_skipped`, `_do_power_offer`. Wire Box Shutter into `handle_match_won`. Update test_run_manager.gd tests first.

**Files:**
- Modify: `seal-the-box/tests/test_run_manager.gd` (remove dice reward test, replace critical-win test)
- Modify: `seal-the-box/scripts/run/run_manager.gd`

- [ ] **Step 1: Update test_run_manager.gd — write the new critical-win test**

In `_init()`, replace the call `_test_critical_win_triggers_reward_then_rotation(gs)` with `_test_critical_win_triggers_power_offer_then_rotation(gs)`.

Remove the call `_test_reward_dice_unique()`.

Remove the functions `_test_reward_dice_unique` and `_test_critical_win_triggers_reward_then_rotation` entirely.

Add a PowerManager registration block to `_init()` (after PowerLibrary, before GameState):

```gdscript
	var pm = load("res://scripts/run/power_manager.gd").new()
	pm.name = "PowerManager"
	get_root().add_child(pm)
	Engine.register_singleton("PowerManager", pm)
```

Add two new test functions:

```gdscript
func _test_critical_win_triggers_power_offer_then_rotation(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var power_offer_log: Array = []
	var rotation_count = [0]
	var next_match_log: Array = []
	rm.next_match_ready.connect(func(box): next_match_log.append(box))
	rm.show_power_offer.connect(func(power): power_offer_log.append(power))
	rm.show_rotation_offer.connect(func(opts):
		rotation_count[0] += 1
		rm.handle_rotation_pick(opts[0])
	)

	rm.start_run()
	rm.handle_match_won(true)
	assert(power_offer_log.size() == 1, "critical win should emit show_power_offer once, got %d" % power_offer_log.size())
	assert(rotation_count[0] == 0, "rotation should not fire until power offer is resolved")
	assert(next_match_log.size() == 1, "next_match_ready should not fire before offer resolved")

	rm.handle_power_offer_skipped()
	assert(rotation_count[0] == 1, "rotation should fire after power offer skipped")
	assert(next_match_log.size() == 2, "next_match_ready should fire after rotation pick")
	rm.queue_free()

func _test_power_offer_accept_adds_to_owned_powers(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_power_offer.connect(func(power): rm.handle_power_offer_accepted(power))
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	assert(gs.owned_powers.size() == 0, "owned_powers should be empty before critical win")
	rm.handle_match_won(true)
	assert(gs.owned_powers.size() == 1, "accept should add 1 power, got %d" % gs.owned_powers.size())
	rm.queue_free()
```

Also add these calls in `_init()` before `print("All RunManager tests passed!")`:

```gdscript
	_test_critical_win_triggers_power_offer_then_rotation(gs)
	_test_power_offer_accept_adds_to_owned_powers(gs)
```

- [ ] **Step 2: Run tests to confirm new tests fail**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: fails — `show_power_offer` doesn't exist on RunManager yet.

- [ ] **Step 3: Rewrite run_manager.gd**

Replace the entire file content:

```gdscript
class_name RunManager
extends Node

signal next_match_ready(box: BoxDefinition)
signal show_power_offer(power: PowerData)
signal show_rotation_offer(options: Array)
signal run_over(match_number: int)

var match_number: int = 1
var _boxes: Array = []
var _pending_rotation_options: Array = []

func start_run() -> void:
	var box_lib = Engine.get_singleton("BoxLibrary")
	_boxes = box_lib.get_ordered()
	match_number = 1
	var gs = Engine.get_singleton("GameState")
	gs.reset_run()
	next_match_ready.emit(_boxes[0])

func handle_match_won(critical: bool) -> void:
	match_number += 1
	if critical:
		var power_mgr = Engine.get_singleton("PowerManager")
		if power_mgr:
			power_mgr.apply_box_shutter()
		_do_power_offer()
	else:
		_do_rotation_offer()

func handle_match_lost() -> void:
	run_over.emit(match_number)

func handle_power_offer_accepted(power: PowerData) -> void:
	var gs = Engine.get_singleton("GameState")
	gs.owned_powers.append(power)
	_do_rotation_offer()

func handle_power_offer_skipped() -> void:
	_do_rotation_offer()

func handle_rotation_pick(chosen: AbilityData) -> void:
	if chosen == null:
		push_error("RunManager: handle_rotation_pick called with null ability")
		return
	var gs = Engine.get_singleton("GameState")
	gs.ability_hand[0] = gs.ability_hand[1]
	gs.ability_hand[1] = gs.ability_hand[2]
	gs.ability_hand[2] = chosen
	_pending_rotation_options = []
	gs.reset_run_end()
	_start_next_match()

func dev_skip_rotation() -> void:
	if _pending_rotation_options.size() > 0:
		handle_rotation_pick(_pending_rotation_options[0])

func _start_next_match() -> void:
	var next_box = _boxes[(match_number - 1) % _boxes.size()]
	next_match_ready.emit(next_box)

func _do_power_offer() -> void:
	var gs = Engine.get_singleton("GameState")
	var power_lib = Engine.get_singleton("PowerLibrary")
	if not power_lib:
		_do_rotation_offer()
		return
	var power = power_lib.get_random_unowned(gs.owned_powers)
	if power == null:
		_do_rotation_offer()
		return
	show_power_offer.emit(power)

func _do_rotation_offer() -> void:
	var gs = Engine.get_singleton("GameState")
	var lib = Engine.get_singleton("AbilityLibrary")
	var pool: Array = gs.ABILITY_POOL_IDS.duplicate()
	_pending_rotation_options = []
	for i in 3:
		if pool.is_empty():
			break
		var idx = randi() % pool.size()
		var ability = lib.get_ability(pool[idx])
		pool.remove_at(idx)
		if ability:
			_pending_rotation_options.append(ability.duplicate())
	if _pending_rotation_options.size() < 3:
		push_error("RunManager: _do_rotation_offer could not build 3 options (got %d)" % _pending_rotation_options.size())
		return
	show_rotation_offer.emit(_pending_rotation_options)
```

- [ ] **Step 4: Run tests to confirm pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: Both print "All ... tests passed!"

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/run/run_manager.gd seal-the-box/tests/test_run_manager.gd
git commit -m "feat: replace dice reward with power offer in RunManager; add Box Shutter hook"
```

---

## Task 9: match.gd — Remove Reward Overlay, Add Power Offer Overlay

Remove all dice reward code from match.gd and replace with a power offer overlay. Update signal wiring and _on_next_match_ready.

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

- [ ] **Step 1: Remove reward overlay state variables**

In the `# ── ui references ──` section at the top of match.gd, remove these four lines:

```gdscript
var _current_reward_faces: Array = []
var _reward_overlay: Control
var _reward_title_label: Label
var _reward_buttons: Array[Button] = []
```

Replace them with power offer variables:

```gdscript
var _power_offer_overlay: Control
var _power_offer_name_label: Label
var _power_offer_desc_label: Label
var _current_power_offer: PowerData = null
```

- [ ] **Step 2: Register PowerLibrary + PowerManager singletons in `_ready()`**

In `_ready()`, after the existing singleton-registration block, add:

```gdscript
	if not Engine.has_singleton("PowerLibrary"):
		Engine.register_singleton("PowerLibrary", PowerLibrary)
	if not Engine.has_singleton("PowerManager"):
		Engine.register_singleton("PowerManager", PowerManager)
```

- [ ] **Step 3: Replace the reward overlay build block in `_setup_ui()` with the power offer overlay**

Find the section starting with `# ── Reward overlay (hidden until match 1 or 2 ends in a win) ──` and ending with `_reward_overlay = reward_overlay`. Replace the entire block with:

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

- [ ] **Step 4: Update `_connect_signals()`**

Replace `_run_manager.show_reward.connect(_on_show_reward)` with:

```gdscript
	_run_manager.show_power_offer.connect(_on_show_power_offer)
```

- [ ] **Step 5: Update `_on_next_match_ready()` to hide power offer overlay**

In `_on_next_match_ready`, find the block that hides overlays. Replace `if _reward_overlay: _reward_overlay.visible = false` with `if _power_offer_overlay: _power_offer_overlay.visible = false`.

The full overlay-hiding block should read:

```gdscript
	if _power_offer_overlay:
		_power_offer_overlay.visible = false
	if _run_over_overlay:
		_run_over_overlay.visible = false
	if _rotation_overlay:
		_rotation_overlay.visible = false
```

- [ ] **Step 6: Replace reward signal handlers with power offer handlers**

Remove functions `_on_show_reward` and `_on_reward_die_picked` entirely.

Add these new handlers (place after `_on_run_over`):

```gdscript
func _on_show_power_offer(power: PowerData) -> void:
	_current_power_offer = power
	_power_offer_name_label.text = power.name
	_power_offer_desc_label.text = power.description
	_power_offer_overlay.visible = true

func _on_power_offer_accepted() -> void:
	_power_offer_overlay.visible = false
	_run_manager.handle_power_offer_accepted(_current_power_offer)
	_refresh_powers_panel()

func _on_power_offer_skipped() -> void:
	_power_offer_overlay.visible = false
	_run_manager.handle_power_offer_skipped()
```

Note: `_refresh_powers_panel()` will be defined in Task 10. For now it can be stubbed as a no-op at the top of the file — add this method temporarily:

```gdscript
func _refresh_powers_panel() -> void:
	pass
```

- [ ] **Step 7: Launch the game and verify power offer overlay appears on critical win**

Start the game. Open the dev menu (T key). Use "Win Current Match" to get a threshold win (no power offer — correct). Then try to reach a critical win by sealing all tabs. On critical win, the power offer overlay should appear with a power name and description, and Accept/Skip buttons. Verify the overlay uses an opaque black background. Accept and confirm rotation overlay appears next. Skip and confirm rotation overlay also appears.

- [ ] **Step 8: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: replace reward overlay with power offer overlay in match UI"
```

---

## Task 10: match.gd — Owned Powers Side Panel

Add a permanently visible right-side panel that lists owned powers with hover tooltips. Update `_refresh_powers_panel()` to rebuild the pills.

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

- [ ] **Step 1: Add side panel state variables**

In the `# ── ui references ──` section, add:

```gdscript
var _powers_vbox: VBoxContainer
```

- [ ] **Step 2: Build the powers panel in `_setup_ui()`**

After the dev overlay section (after `root.add_child(_dev_overlay)`), add the powers panel:

```gdscript
	# ── Powers side panel (right side, always visible) ────────────────────────
	var powers_panel = _make_rounded_panel(12, DARK, 10, 8)
	powers_panel.anchor_left = 1.0
	powers_panel.anchor_right = 1.0
	powers_panel.anchor_top = 0.0
	powers_panel.anchor_bottom = 1.0
	powers_panel.offset_left = -175
	powers_panel.offset_right = -6
	powers_panel.offset_top = 60
	powers_panel.offset_bottom = -310
	root.add_child(powers_panel)

	var powers_outer = VBoxContainer.new()
	powers_outer.add_theme_constant_override("separation", 8)
	powers_panel.add_child(powers_outer)

	var powers_title = Label.new()
	powers_title.text = "── POWERS ──"
	powers_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powers_title.add_theme_font_size_override("font_size", 13)
	powers_outer.add_child(powers_title)

	_powers_vbox = VBoxContainer.new()
	_powers_vbox.add_theme_constant_override("separation", 6)
	powers_outer.add_child(_powers_vbox)
```

- [ ] **Step 3: Implement `_refresh_powers_panel()`**

Replace the stub `_refresh_powers_panel` with:

```gdscript
func _refresh_powers_panel() -> void:
	if not _powers_vbox:
		return
	for child in _powers_vbox.get_children():
		child.queue_free()
	for power in GameState.owned_powers:
		var pill = TooltipButton.new()
		pill.custom_minimum_size = Vector2(0, 44)
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if pill is TooltipButton:
			(pill as TooltipButton).update_info(power.name, power.description)
		_powers_vbox.add_child(pill)
```

- [ ] **Step 4: Call `_refresh_powers_panel()` in `_on_next_match_ready`**

At the end of `_on_next_match_ready`, after calling `_rebuild_tab_buttons()`, add:

```gdscript
	_refresh_powers_panel()
```

- [ ] **Step 5: Launch game and verify the powers panel**

Start the game. Confirm an empty "── POWERS ──" panel is visible on the right side. Trigger a critical win, accept a power. After the rotation pick and next match starts, confirm the power name appears as a button in the panel. Hover over it to verify the description tooltip appears.

Also confirm the panel doesn't visually collide with any existing UI elements.

- [ ] **Step 6: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: add owned powers side panel to match UI"
```

---

## Task 11: Final Verification + QA Handoff

- [ ] **Step 1: Run both test suites one final time**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd
```

Expected: Both print "All ... tests passed!"

- [ ] **Step 2: Full playthrough smoke test**

Start the game and verify:
- Dice hand shows 3 dice (drawn from 7-die pool)
- Round 1 dice hand: exactly one die shows its max value as pre-rolled (Eager — only if the power is owned; not present on first run start since no powers yet)
- Play through to a critical win (all tabs sealed): power offer overlay appears
- Accept → power appears in side panel → rotation overlay appears → pick ability → next match starts
- Skip → rotation overlay appears without adding power → next match starts
- After owning all 5 powers, critical win skips the offer and goes directly to rotation
- Threshold win (remaining sum ≤ threshold, hit Continue): no power offer, goes straight to rotation

- [ ] **Step 3: Verify dev menu still works**

Open dev menu (T), use "Win Entire Series" — should auto-complete 3 threshold wins without getting stuck on any overlay.

- [ ] **Step 4: Final commit if any fixes were made, then push**

After Caleb approves, push and merge per CLAUDE.md workflow:

```bash
git push -u origin feature/first-powers
```

Then merge locally:

```bash
git checkout master
git merge feature/first-powers
git push
git branch -d feature/first-powers
```

---

## Self-Review Against Spec

| Spec requirement | Covered in task |
|---|---|
| Dice pool → 7 (1d4+4d6+2d8) | Task 2 |
| PowerLibrary: data/powers.csv, power_data.gd, autoload, get_random_unowned | Tasks 4–5 |
| power_manager.gd autoload | Task 6 |
| GameState.owned_powers + pending_threshold_bonus | Task 3 |
| reset_run clears owned_powers; reset_match preserves | Task 3 |
| Replace critical-win dice reward with power offer | Tasks 8–9 |
| Power offer: Accept adds to owned_powers, Skip does not | Tasks 8–9 |
| If all powers owned, skip offer → straight to rotation | RunManager._do_power_offer handles null return |
| Lighter Box: threshold +3 per copy per match | Tasks 6–7 |
| Eager: one die pre-rolled at max on round 1 | Tasks 6–7 |
| Tab 9 Bounty: seal 9 → +1 HP per copy | Tasks 6–7 |
| Bonus Seal: seal N → bonus seal floor(N/2), no cascade | Tasks 6–7 |
| Box Shutter: critical win → next match +5 per copy | Tasks 8 + 7 |
| Owned-powers side panel (always visible, hover tooltip) | Task 10 |
| Power offer overlay (opaque black background) | Task 9 |
| Tests: pool size, owned_powers persistence, critical-win flow, each power | Tasks 2–3, 5–6, 8 |
| Delete dice reward flow | Task 8 |
| Opaque overlays (Color(0,0,0,1.0)) | Task 9 |
