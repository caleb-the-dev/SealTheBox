# Die Swap + Five-Box Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 2 new boxes (Compressed + Stairs) to complete a 5-box cycle, and add a periodic die swap overlay that fires every 5 matches.

**Architecture:** CSV gets 2 new rows; RunManager gains a `show_die_swap` signal + 3 new methods; match.gd gains a new overlay and a top-bar swap countdown label. Die swap fires inside `handle_rotation_pick` after verifying `(match_number - 1) % 5 == 0`; defers `_start_next_match` until the player confirms or skips.

**Tech Stack:** GDScript 4, Godot 4.5.1, CSV data files, headless SceneTree test runner

---

## File Map

**Modified files:**
- `seal-the-box/data/boxes.csv` — 2 new rows (Compressed, Stairs)
- `seal-the-box/tests/test_box_definition.gd` — 3 new tests + BoxLibrary setup in `_init`
- `seal-the-box/tests/test_run_manager.gd` — 5 new test functions + calls in `_init`
- `seal-the-box/scripts/run/run_manager.gd` — `show_die_swap` signal, `DIE_SWAP_FACES` const, modified `handle_rotation_pick`, new `handle_die_swap_confirm` + `handle_die_swap_skip`
- `seal-the-box/scripts/match/match.gd` — die swap overlay, new var fields, signal wire-up, `_refresh_ui` update for swap label, `_on_next_match_ready` update to hide overlay

**New files:** none

---

## Task 1: Branch Setup + Add Boxes to CSV

**Files:**
- Create branch (git only)
- Modify: `seal-the-box/data/boxes.csv`

- [ ] **Step 1: Create feature branch**

```bash
git checkout master
git checkout -b feature/die-swap-five-boxes
```

Expected: branch `feature/die-swap-five-boxes` checked out at master HEAD.

- [ ] **Step 2: Add Compressed and Stairs rows to boxes.csv**

Current file content:
```
id,name,tabs,win_threshold
classic,Classic,1;2;3;4;5;6;7;8;9,20
low_evens,Low Evens,2;3;4;5;6;7;8,17
high_odds,High Odds,3;5;7;9;11,17
```

Replace with:
```
id,name,tabs,win_threshold
classic,Classic,1;2;3;4;5;6;7;8;9,20
low_evens,Low Evens,2;3;4;5;6;7;8,17
high_odds,High Odds,3;5;7;9;11,17
compressed,Compressed,2;4;5;6;8,13
stairs,Stairs,1;3;5;6;7;9,15
```

Tab sums for reference: Compressed = 2+4+5+6+8 = 25 (round_limit = ceili(25/15)+1 = 3); Stairs = 1+3+5+6+7+9 = 31 (round_limit = ceili(31/15)+1 = 4).

- [ ] **Step 3: Run existing box tests to confirm nothing broke**

```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_box_definition.gd 2>&1 | tail -5
```

Expected output includes: `All BoxDefinition tests passed!`

- [ ] **Step 4: Commit**

```bash
git add seal-the-box/data/boxes.csv
git commit -m "feat: add Compressed and Stairs boxes to CSV"
```

---

## Task 2: New Box Tests

**Files:**
- Modify: `seal-the-box/tests/test_box_definition.gd`

- [ ] **Step 1: Update `_init` to load BoxLibrary and call 3 new tests**

Replace the entire `_init` function:

```gdscript
func _init() -> void:
	var box_lib = load("res://scripts/globals/box_library.gd").new()
	box_lib.name = "BoxLibrary"
	get_root().add_child(box_lib)
	box_lib._ready()
	Engine.register_singleton("BoxLibrary", box_lib)

	_test_classic_box()
	_test_high_odds_box()
	_test_custom_box()
	_test_compressed_box()
	_test_stairs_box()
	_test_all_five_boxes_load()
	print("All BoxDefinition tests passed!")
	quit()
```

- [ ] **Step 2: Add the 3 new test functions after `_test_custom_box`**

```gdscript
func _test_compressed_box() -> void:
	var box = BoxDefinition.new()
	box.tabs.assign([2, 4, 5, 6, 8])
	box.win_threshold = 13
	assert(box.tab_sum() == 25, "compressed tab_sum should be 25, got %d" % box.tab_sum())
	assert(box.win_threshold == 13, "compressed win_threshold should be 13, got %d" % box.win_threshold)
	assert(box.round_limit == 3, "compressed round_limit should be 3, got %d" % box.round_limit)

func _test_stairs_box() -> void:
	var box = BoxDefinition.new()
	box.tabs.assign([1, 3, 5, 6, 7, 9])
	box.win_threshold = 15
	assert(box.tab_sum() == 31, "stairs tab_sum should be 31, got %d" % box.tab_sum())
	assert(box.win_threshold == 15, "stairs win_threshold should be 15, got %d" % box.win_threshold)
	assert(box.round_limit == 4, "stairs round_limit should be 4, got %d" % box.round_limit)

func _test_all_five_boxes_load() -> void:
	var all = Engine.get_singleton("BoxLibrary").get_ordered()
	assert(all.size() == 5, "BoxLibrary should have 5 boxes, got %d" % all.size())
	assert(all[0].id == "classic",    "box 0 should be classic, got %s"    % all[0].id)
	assert(all[1].id == "low_evens",  "box 1 should be low_evens, got %s"  % all[1].id)
	assert(all[2].id == "high_odds",  "box 2 should be high_odds, got %s"  % all[2].id)
	assert(all[3].id == "compressed", "box 3 should be compressed, got %s" % all[3].id)
	assert(all[4].id == "stairs",     "box 4 should be stairs, got %s"     % all[4].id)
```

- [ ] **Step 3: Run box tests to verify all pass**

```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_box_definition.gd 2>&1 | tail -5
```

Expected: `All BoxDefinition tests passed!`

- [ ] **Step 4: Commit**

```bash
git add seal-the-box/tests/test_box_definition.gd
git commit -m "test: add Compressed/Stairs box tests and 5-box library count check"
```

---

## Task 3: Write Failing Die Swap Tests

**Files:**
- Modify: `seal-the-box/tests/test_run_manager.gd`

These tests reference `show_die_swap` which does not exist yet — they will error with "Nonexistent signal" when run. That is expected. After Task 4 implements the signal, they will pass.

- [ ] **Step 1: Add 5 new test calls to `_init` before the final print**

In `test_run_manager.gd`, find the `print("All RunManager tests passed!")` line (line 51) and add these calls immediately before it:

```gdscript
	_test_box_cycle_five_boxes(gs)
	_test_die_swap_fires_after_match_5(gs)
	_test_die_swap_fires_after_match_10(gs)
	_test_die_swap_confirm_replaces_die(gs)
	_test_die_swap_skip_preserves_pool(gs)
	print("All RunManager tests passed!")
```

- [ ] **Step 2: Add the 5 new test functions after `_test_power_offer_accept_adds_to_owned_powers`**

```gdscript
func _test_box_cycle_five_boxes(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.start_run()

	assert(rm._boxes.size() == 5, "should have 5 boxes, got %d" % rm._boxes.size())
	assert(rm._boxes[0].id == "classic",    "box 0 should be classic, got %s"    % rm._boxes[0].id)
	assert(rm._boxes[1].id == "low_evens",  "box 1 should be low_evens, got %s"  % rm._boxes[1].id)
	assert(rm._boxes[2].id == "high_odds",  "box 2 should be high_odds, got %s"  % rm._boxes[2].id)
	assert(rm._boxes[3].id == "compressed", "box 3 should be compressed, got %s" % rm._boxes[3].id)
	assert(rm._boxes[4].id == "stairs",     "box 4 should be stairs, got %s"     % rm._boxes[4].id)
	rm.queue_free()

func _test_die_swap_fires_after_match_5(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	var swap_log: Array = []
	rm.show_die_swap.connect(func(offered):
		swap_log.append(offered)
		rm.handle_die_swap_skip()
	)

	rm.start_run()

	for i in 4:
		rm.handle_match_won(false)
	assert(swap_log.size() == 0, "no swap after matches 1-4, got %d" % swap_log.size())

	rm.handle_match_won(false)
	assert(swap_log.size() == 1, "swap should fire after match 5, got %d" % swap_log.size())
	assert(swap_log[0].size() == 5, "offer should have 5 dice, got %d" % swap_log[0].size())
	var faces = swap_log[0].map(func(d): return d.faces)
	faces.sort()
	assert(faces == [2, 4, 8, 10, 12], "offer faces should be [2,4,8,10,12], got %s" % str(faces))
	rm.queue_free()

func _test_die_swap_fires_after_match_10(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	var swap_count = [0]
	rm.show_die_swap.connect(func(_offered):
		swap_count[0] += 1
		rm.handle_die_swap_skip()
	)

	rm.start_run()
	for i in 10:
		rm.handle_match_won(false)

	assert(swap_count[0] == 2, "swap should fire after matches 5 and 10 only, got %d" % swap_count[0])
	rm.queue_free()

func _test_die_swap_confirm_replaces_die(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	var pending_offered: Array = []
	rm.show_die_swap.connect(func(offered): pending_offered.assign(offered))

	rm.start_run()
	for i in 5:
		rm.handle_match_won(false)

	assert(pending_offered.size() == 5, "swap offer should have 5 dice, got %d" % pending_offered.size())

	var offered_die = pending_offered[0]
	var pool_die = gs.dice_pool[0]

	rm.handle_die_swap_confirm(offered_die, pool_die)

	assert(gs.dice_pool.size() == 7, "pool size should stay 7, got %d" % gs.dice_pool.size())
	assert(offered_die in gs.dice_pool, "offered die (d%d) should be in pool" % offered_die.faces)
	assert(not (pool_die in gs.dice_pool), "swapped-out die (d%d) should be gone" % pool_die.faces)
	rm.queue_free()

func _test_die_swap_skip_preserves_pool(gs: Node) -> void:
	gs.reset_run()
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))
	rm.show_die_swap.connect(func(_offered): pass)

	rm.start_run()
	for i in 5:
		rm.handle_match_won(false)

	var pool_before = gs.dice_pool.duplicate()

	rm.handle_die_swap_skip()

	assert(gs.dice_pool.size() == pool_before.size(), "pool size should be unchanged after skip")
	for i in pool_before.size():
		assert(pool_before[i] in gs.dice_pool, "die %d (d%d) should still be in pool after skip" % [i, pool_before[i].faces])
	rm.queue_free()
```

- [ ] **Step 3: Run tests and verify they fail**

```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd 2>&1 | tail -10
```

Expected: error output containing "Nonexistent signal 'show_die_swap'" — the `All RunManager tests passed!` line should NOT appear. `_test_box_cycle_five_boxes` may pass (boxes loaded in Task 1), but all die swap tests must fail.

- [ ] **Step 4: Commit failing tests**

```bash
git add seal-the-box/tests/test_run_manager.gd
git commit -m "test: add failing die swap tests (box cycle, trigger, confirm, skip)"
```

---

## Task 4: Implement RunManager Die Swap Logic

**Files:**
- Modify: `seal-the-box/scripts/run/run_manager.gd`

- [ ] **Step 1: Add signal and constant after the existing signal declarations**

Find these lines near the top of `run_manager.gd`:
```gdscript
signal next_match_ready(box: BoxDefinition)
signal show_power_offer(power: PowerData)
signal show_rotation_offer(options: Array)
signal run_over(match_number: int)
```

Replace with:
```gdscript
signal next_match_ready(box: BoxDefinition)
signal show_power_offer(power: PowerData)
signal show_rotation_offer(options: Array)
signal show_die_swap(offered_dice: Array)
signal run_over(match_number: int)

const DIE_SWAP_FACES: Array[int] = [2, 4, 8, 10, 12]
```

- [ ] **Step 2: Modify `handle_rotation_pick` to conditionally defer `_start_next_match`**

Find the existing function:
```gdscript
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
```

Replace with:
```gdscript
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
	if (match_number - 1) % 5 == 0:
		var offered: Array = []
		for f in DIE_SWAP_FACES:
			offered.append(Die.new(f))
		show_die_swap.emit(offered)
	else:
		_start_next_match()
```

- [ ] **Step 3: Add `handle_die_swap_confirm` and `handle_die_swap_skip` after `handle_rotation_pick`**

```gdscript
func handle_die_swap_confirm(offered_die: Die, pool_die: Die) -> void:
	var gs = Engine.get_singleton("GameState")
	var idx = gs.dice_pool.find(pool_die)
	if idx >= 0:
		gs.dice_pool[idx] = offered_die
	_start_next_match()

func handle_die_swap_skip() -> void:
	_start_next_match()
```

- [ ] **Step 4: Run all tests and verify they pass**

```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd 2>&1 | tail -5
```

Expected: `All RunManager tests passed!`

Also run box definition tests:
```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_box_definition.gd 2>&1 | tail -5
```

Expected: `All BoxDefinition tests passed!`

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/run/run_manager.gd
git commit -m "feat: add die swap signal and logic to RunManager (every 5 matches)"
```

---

## Task 5: Die Swap Overlay UI in match.gd

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

- [ ] **Step 1: Add new variable declarations at the top of match.gd**

Find the `# ── ui references` block. After the existing `_powers_vbox: VBoxContainer` line, add:

```gdscript
var _die_swap_overlay: Control
var _die_swap_offered_buttons: Array[Button] = []
var _die_swap_pool_row: HBoxContainer
var _die_swap_pool_buttons: Array[Button] = []
var _die_swap_confirm_btn: Button
var _die_swap_offered_dice: Array = []
var _selected_swap_offered_idx: int = -1
var _selected_swap_pool_die = null
```

- [ ] **Step 2: Build the die swap overlay in `_setup_ui`**

Find the line `root.add_child(dev_power_overlay)` followed by `_dev_power_overlay = dev_power_overlay`. After that block (before the powers side panel block), add:

```gdscript
	# ── Die swap overlay ────────────────────────────────────────────────────────
	var swap_overlay = Control.new()
	swap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	swap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	swap_overlay.visible = false
	var swap_bg = ColorRect.new()
	swap_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	swap_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	swap_overlay.add_child(swap_bg)

	var swap_center = VBoxContainer.new()
	swap_center.anchor_left = 0.1
	swap_center.anchor_right = 0.9
	swap_center.anchor_top = 0.05
	swap_center.anchor_bottom = 0.95
	swap_center.add_theme_constant_override("separation", 20)
	swap_overlay.add_child(swap_center)

	var swap_title = Label.new()
	swap_title.text = "Choose a New Die"
	swap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swap_title.add_theme_font_size_override("font_size", 30)
	swap_center.add_child(swap_title)

	var swap_sub = Label.new()
	swap_sub.text = "Select a die from the offer, then a die from your pool to replace."
	swap_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swap_sub.add_theme_font_size_override("font_size", 16)
	swap_center.add_child(swap_sub)

	var swap_offer_lbl = Label.new()
	swap_offer_lbl.text = "── OFFERED DICE ──"
	swap_offer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swap_center.add_child(swap_offer_lbl)

	var swap_offer_row = HBoxContainer.new()
	swap_offer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	swap_offer_row.add_theme_constant_override("separation", 16)
	swap_center.add_child(swap_offer_row)

	_die_swap_offered_buttons = []
	for i in 5:
		var btn = Button.new()
		btn.text = "d?"
		btn.custom_minimum_size = Vector2(90, 90)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_die_swap_offered_pressed.bind(i))
		swap_offer_row.add_child(btn)
		_die_swap_offered_buttons.append(btn)

	var swap_pool_lbl = Label.new()
	swap_pool_lbl.text = "── YOUR POOL ──"
	swap_pool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swap_center.add_child(swap_pool_lbl)

	_die_swap_pool_row = HBoxContainer.new()
	_die_swap_pool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_die_swap_pool_row.add_theme_constant_override("separation", 12)
	swap_center.add_child(_die_swap_pool_row)

	var swap_action_row = HBoxContainer.new()
	swap_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	swap_action_row.add_theme_constant_override("separation", 24)
	swap_center.add_child(swap_action_row)

	_die_swap_confirm_btn = Button.new()
	_die_swap_confirm_btn.text = "Confirm Swap"
	_die_swap_confirm_btn.custom_minimum_size = Vector2(160, 60)
	_die_swap_confirm_btn.add_theme_font_size_override("font_size", 18)
	_die_swap_confirm_btn.disabled = true
	_die_swap_confirm_btn.pressed.connect(_on_die_swap_confirm_pressed)
	swap_action_row.add_child(_die_swap_confirm_btn)

	var swap_skip_btn = Button.new()
	swap_skip_btn.text = "Skip"
	swap_skip_btn.custom_minimum_size = Vector2(120, 60)
	swap_skip_btn.add_theme_font_size_override("font_size", 18)
	swap_skip_btn.pressed.connect(_on_die_swap_skip_pressed)
	swap_action_row.add_child(swap_skip_btn)

	root.add_child(swap_overlay)
	_die_swap_overlay = swap_overlay
```

- [ ] **Step 3: Add `_swap_label` to the top bar in `_setup_ui`**

Find this block in `_setup_ui` (top bar section):
```gdscript
	_box_label = Label.new()
	_box_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_box_label)
```

After those three lines, add:
```gdscript
	_swap_label = Label.new()
	_swap_label.add_theme_font_size_override("font_size", 16)
	_swap_label.modulate = Color(0.8, 0.9, 1.0)
	top_bar.add_child(_swap_label)
```

- [ ] **Step 4: Add `_swap_label` to the variable declarations block**

Find `var _box_label: Label` in the `# ── ui references` block. Add immediately after it:
```gdscript
var _swap_label: Label
```

- [ ] **Step 5: Wire up the die swap signal in `_connect_signals`**

Find:
```gdscript
	_run_manager.show_rotation_offer.connect(_on_show_rotation_offer)
```

Add after it:
```gdscript
	_run_manager.show_die_swap.connect(_on_show_die_swap)
```

- [ ] **Step 6: Hide the die swap overlay in `_on_next_match_ready`**

Find this block inside `_on_next_match_ready`:
```gdscript
	if _rotation_overlay:
		_rotation_overlay.visible = false
```

Add after it:
```gdscript
	if _die_swap_overlay:
		_die_swap_overlay.visible = false
```

- [ ] **Step 7: Add die swap handler functions after `_on_rotation_pick_pressed`**

```gdscript
func _on_show_die_swap(offered_dice: Array) -> void:
	_die_swap_offered_dice = offered_dice
	_selected_swap_offered_idx = -1
	_selected_swap_pool_die = null
	for i in _die_swap_offered_buttons.size():
		_die_swap_offered_buttons[i].text = "d%d" % offered_dice[i].faces
		_die_swap_offered_buttons[i].modulate = Color.WHITE
	for child in _die_swap_pool_row.get_children():
		child.queue_free()
	_die_swap_pool_buttons = []
	for i in GameState.dice_pool.size():
		var die = GameState.dice_pool[i]
		var btn = Button.new()
		btn.text = "d%d" % die.faces
		btn.custom_minimum_size = Vector2(72, 72)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_die_swap_pool_pressed.bind(i))
		_die_swap_pool_row.add_child(btn)
		_die_swap_pool_buttons.append(btn)
	_die_swap_confirm_btn.disabled = true
	_die_swap_overlay.visible = true

func _on_die_swap_offered_pressed(index: int) -> void:
	_selected_swap_offered_idx = index
	for i in _die_swap_offered_buttons.size():
		_die_swap_offered_buttons[i].modulate = Color(1.5, 1.5, 0.3) if i == index else Color.WHITE
	_update_die_swap_confirm_state()

func _on_die_swap_pool_pressed(index: int) -> void:
	_selected_swap_pool_die = GameState.dice_pool[index]
	for i in _die_swap_pool_buttons.size():
		_die_swap_pool_buttons[i].modulate = Color(1.5, 1.5, 0.3) if i == index else Color.WHITE
	_update_die_swap_confirm_state()

func _update_die_swap_confirm_state() -> void:
	_die_swap_confirm_btn.disabled = (_selected_swap_offered_idx < 0 or _selected_swap_pool_die == null)

func _on_die_swap_confirm_pressed() -> void:
	_die_swap_overlay.visible = false
	_run_manager.handle_die_swap_confirm(_die_swap_offered_dice[_selected_swap_offered_idx], _selected_swap_pool_die)

func _on_die_swap_skip_pressed() -> void:
	_die_swap_overlay.visible = false
	_run_manager.handle_die_swap_skip()
```

- [ ] **Step 8: Update `_refresh_ui` to show swap countdown**

Find this block in `_refresh_ui`:
```gdscript
	_match_label.text = "Match: %d" % _run_manager.match_number
```

After that line, add:
```gdscript
	if _swap_label:
		var mn = _run_manager.match_number
		var remaining = (5 - (mn % 5)) % 5
		_swap_label.text = "Swap after this!" if remaining == 0 else "Swap in %d" % remaining
```

- [ ] **Step 9: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: add die swap overlay and top-bar swap countdown to match scene"
```

---

## Task 6: Final Verification + QA Handoff

**Files:** none — verification only

- [ ] **Step 1: Run all headless tests one final time**

```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_box_definition.gd 2>&1 | tail -5
```
Expected: `All BoxDefinition tests passed!`

```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd 2>&1 | tail -5
```
Expected: `All RunManager tests passed!`

```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_power_effects.gd 2>&1 | tail -5
```
Expected: `All PowerEffects tests passed!`

```bash
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_ability_library.gd 2>&1 | tail -5
```
Expected: `All AbilityLibrary tests passed!`

- [ ] **Step 2: Push branch**

```bash
git push -u origin feature/die-swap-five-boxes
```

- [ ] **Step 3: Deliver QA checklist to Caleb**

Print the following QA checklist:

```
QA CHECKLIST — Die Swap + Five-Box Cycle

FUNCTIONAL BUGS
[ ] Top bar shows "Swap in 4" during match 1 of a fresh run
[ ] Top bar counts down correctly: Swap in 3 / 2 / 1 / "Swap after this!" on match 5
[ ] After winning match 5 (threshold or critical), die swap overlay appears AFTER rotation pick
[ ] Swap overlay shows 5 offered dice labeled d2, d4, d8, d10, d12
[ ] Clicking an offered die highlights it (yellow); clicking another transfers highlight
[ ] Clicking a pool die highlights it (yellow); clicking another transfers highlight
[ ] Confirm Swap button is disabled until both an offered die and pool die are selected
[ ] After confirming: pool size stays 7, new die appears in the pool display next match
[ ] Skip: overlay dismisses, pool unchanged, next match starts normally
[ ] Die swap fires after match 10 win as well (win 10 matches to verify)
[ ] Die swap does NOT fire after a match loss
[ ] Box 4 (Compressed: tabs 2,4,5,6,8) is mechanically distinct — no 1s or 9s
[ ] Box 5 (Stairs: tabs 1,3,5,6,7,9) is mechanically distinct — irregular gaps
[ ] After match 5 (Stairs), match 6 returns to Classic correctly

PLAYABILITY QUESTIONS
[ ] Does the run feel like it has shape? Does it blur together after match 5?
[ ] Is the die swap moment exciting, or does it feel like a menu interrupt?
[ ] Are Compressed and Stairs mechanically distinct from Classic/Low Evens/High Odds?
[ ] Are powers accumulating at a good rate, or trivializing matches by mid-run?
[ ] Does the predictable 5-match rhythm work, or does it need variation?
```
