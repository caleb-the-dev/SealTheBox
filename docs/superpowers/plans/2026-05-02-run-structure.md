# Run Structure + Dice Rewards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 3-match run structure with dice rewards between matches — win all 3 to complete the run, lose any single match to end it; after match 1 and 2, pick one of 3 offered dice to permanently add to your pool.

**Architecture:** `RunManager` (Node child of the match scene) tracks `match_number`, emits signals for UI decisions (`next_match_ready`, `show_reward`, `run_won`, `run_over`). `match.gd` consumes those signals to show/hide overlay panels built in code. `GameState` gets a split reset: `reset_run()` for full run initialization, `reset_match()` for per-match state only — HP and dice_pool survive match transitions.

**Tech Stack:** Godot 4.5, GDScript, headless test runner (`--script tests/<file>.gd`)

---

## File Map

| File | Change | Purpose |
|------|--------|---------|
| `seal-the-box/scripts/globals/game_state.gd` | Modify | Split `reset_match()` into `reset_run()` + `reset_match()`; update starting pool to 3d6 + 1d4 + 1d8 |
| `seal-the-box/scripts/run/run_manager.gd` | Create | Tracks `match_number`, emits run-flow signals, owns reward die pool |
| `seal-the-box/scripts/match/match.gd` | Modify | Wire `RunManager`; replace `AcceptDialog` end screens with overlay panels; add reward/win/over overlays |
| `seal-the-box/tests/test_run_manager.gd` | Create | Headless tests for the GameState split and all RunManager logic |

---

## Task 1: Split GameState reset + update starting dice pool

**Files:**
- Modify: `seal-the-box/scripts/globals/game_state.gd`
- Create: `seal-the-box/tests/test_run_manager.gd`

- [ ] **Step 1: Write the failing tests**

Create `seal-the-box/tests/test_run_manager.gd`:

```gdscript
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

	_test_reset_run_sets_hp()
	_test_reset_run_sets_starting_dice_pool()
	_test_reset_match_preserves_hp()
	_test_reset_match_preserves_dice_pool()
	print("GameState split tests passed!")
	quit()

func _test_reset_run_sets_hp() -> void:
	GameState.hp = 1
	GameState.reset_run()
	assert(GameState.hp == 5, "reset_run should restore HP to 5, got %d" % GameState.hp)

func _test_reset_run_sets_starting_dice_pool() -> void:
	GameState.dice_pool = []
	GameState.reset_run()
	assert(GameState.dice_pool.size() == 5, "starting pool should be 5 dice, got %d" % GameState.dice_pool.size())
	var faces = GameState.dice_pool.map(func(d): return d.faces)
	faces.sort()
	assert(faces == [4, 6, 6, 6, 8], "starting pool should be 1d4+3d6+1d8, got %s" % str(faces))

func _test_reset_match_preserves_hp() -> void:
	GameState.reset_run()
	GameState.hp = 3
	GameState.reset_match()
	assert(GameState.hp == 3, "reset_match should not change HP, got %d" % GameState.hp)

func _test_reset_match_preserves_dice_pool() -> void:
	GameState.reset_run()
	GameState.dice_pool.append(Die.new(12))
	var pool_size = GameState.dice_pool.size()
	GameState.reset_match()
	assert(GameState.dice_pool.size() == pool_size, "reset_match should not clear dice_pool, got %d" % GameState.dice_pool.size())
```

- [ ] **Step 2: Run to confirm failure**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: error about `reset_run` not found, or assertion failure on HP/dice_pool.

- [ ] **Step 3: Rewrite game_state.gd**

Replace the entire file `seal-the-box/scripts/globals/game_state.gd`:

```gdscript
extends Node

var hp: int = 5
var ap: int = 3
var round: int = 0
var round_limit: int = 4
var win_threshold: int = 13
var tabs: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
var dice_pool: Array = []   # Array of Die
var dice_hand: Array = []   # Array of Die (currently drawn)
var ability_hand: Array = []  # Array of AbilityData

func reset_run() -> void:
	hp = 5
	_setup_dice_pool()
	reset_match()

func reset_match() -> void:
	ap = 3
	round = 0
	round_limit = 4
	win_threshold = 13
	tabs = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	dice_hand = []
	_setup_ability_hand()

func spend_ap(amount: int) -> bool:
	if ap < amount:
		return false
	ap -= amount
	return true

func _setup_dice_pool() -> void:
	dice_pool = []
	for i in 3:
		dice_pool.append(Die.new(6))
	dice_pool.append(Die.new(4))
	dice_pool.append(Die.new(8))

func _setup_ability_hand() -> void:
	ability_hand = []
	for id in ["reroll_die", "greater_1", "lesser_1"]:
		var ability = AbilityLibrary.get_ability(id)
		if ability:
			ability_hand.append(ability.duplicate())
		else:
			push_error("GameState: ability not found: %s" % id)
```

- [ ] **Step 4: Run to confirm tests pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: `GameState split tests passed!`

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/globals/game_state.gd seal-the-box/tests/test_run_manager.gd
git commit -m "feat: split GameState reset into reset_run/reset_match, starting pool 3d6+1d4+1d8"
```

---

## Task 2: Create RunManager

**Files:**
- Create: `seal-the-box/scripts/run/run_manager.gd`
- Modify: `seal-the-box/tests/test_run_manager.gd`

- [ ] **Step 1: Write the failing tests**

Replace the entire `seal-the-box/tests/test_run_manager.gd` with the full file below. The GameState tests from Task 1 are preserved; RunManager tests are added.

```gdscript
extends SceneTree

func _init() -> void:
	var lib = load("res://scripts/globals/ability_library.gd").new()
	lib.name = "AbilityLibrary"
	get_root().add_child(lib)
	lib._ready()

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)

	_test_reset_run_sets_hp()
	_test_reset_run_sets_starting_dice_pool()
	_test_reset_match_preserves_hp()
	_test_reset_match_preserves_dice_pool()
	_test_run_manager_start_run()
	_test_run_manager_match_progression()
	_test_run_manager_final_match_win()
	_test_run_manager_match_lost()
	_test_reward_dice_unique()
	print("All RunManager tests passed!")
	quit()

func _test_reset_run_sets_hp() -> void:
	GameState.hp = 1
	GameState.reset_run()
	assert(GameState.hp == 5, "reset_run should restore HP to 5, got %d" % GameState.hp)

func _test_reset_run_sets_starting_dice_pool() -> void:
	GameState.dice_pool = []
	GameState.reset_run()
	assert(GameState.dice_pool.size() == 5, "starting pool should be 5 dice, got %d" % GameState.dice_pool.size())
	var faces = GameState.dice_pool.map(func(d): return d.faces)
	faces.sort()
	assert(faces == [4, 6, 6, 6, 8], "starting pool should be 1d4+3d6+1d8, got %s" % str(faces))

func _test_reset_match_preserves_hp() -> void:
	GameState.reset_run()
	GameState.hp = 3
	GameState.reset_match()
	assert(GameState.hp == 3, "reset_match should not change HP, got %d" % GameState.hp)

func _test_reset_match_preserves_dice_pool() -> void:
	GameState.reset_run()
	GameState.dice_pool.append(Die.new(12))
	var pool_size = GameState.dice_pool.size()
	GameState.reset_match()
	assert(GameState.dice_pool.size() == pool_size, "reset_match should not clear dice_pool, got %d" % GameState.dice_pool.size())

func _test_run_manager_start_run() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var counts = {"next_match": 0}
	rm.next_match_ready.connect(func(): counts["next_match"] += 1)

	rm.start_run()
	assert(rm.match_number == 1, "match_number should be 1 after start_run, got %d" % rm.match_number)
	assert(counts["next_match"] == 1, "start_run should emit next_match_ready once, got %d" % counts["next_match"])
	assert(GameState.hp == 5, "start_run should reset HP to 5, got %d" % GameState.hp)
	rm.queue_free()

func _test_run_manager_match_progression() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var reward_faces_log: Array = []
	rm.next_match_ready.connect(func(): pass)
	rm.show_reward.connect(func(faces): reward_faces_log.append(faces.duplicate()))

	rm.start_run()
	rm.handle_match_won(false)
	assert(reward_faces_log.size() == 1, "match 1 win should emit show_reward once")
	var faces = reward_faces_log[0]
	assert(faces.size() == 3, "should offer 3 reward dice, got %d" % faces.size())

	rm.advance_to_next_match(faces[0])
	assert(rm.match_number == 2, "match_number should be 2 after advancing, got %d" % rm.match_number)
	rm.queue_free()

func _test_run_manager_final_match_win() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var run_won_log: Array = []
	var show_reward_counts = [0]
	rm.next_match_ready.connect(func(): pass)
	rm.show_reward.connect(func(_f): show_reward_counts[0] += 1)
	rm.run_won.connect(func(mn, hp): run_won_log.append({"match": mn, "hp": hp}))

	rm.start_run()
	rm.handle_match_won(false)    # match 1 → show_reward
	rm.advance_to_next_match(6)  # → match 2
	rm.handle_match_won(false)    # match 2 → show_reward
	rm.advance_to_next_match(4)  # → match 3
	show_reward_counts[0] = 0    # reset counter; match 3 win must NOT emit show_reward
	rm.handle_match_won(true)    # match 3 → run_won
	assert(run_won_log.size() == 1, "match 3 win should emit run_won once")
	assert(show_reward_counts[0] == 0, "match 3 win must NOT emit show_reward")
	assert(run_won_log[0]["match"] == 3, "run_won should report match 3, got %d" % run_won_log[0]["match"])
	rm.queue_free()

func _test_run_manager_match_lost() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var run_over_log: Array = []
	rm.next_match_ready.connect(func(): pass)
	rm.run_over.connect(func(mn): run_over_log.append(mn))

	rm.start_run()
	rm.handle_match_lost()
	assert(run_over_log.size() == 1, "match lost should emit run_over once")
	assert(run_over_log[0] == 1, "run_over on match 1 should report 1, got %d" % run_over_log[0])
	rm.queue_free()

func _test_reward_dice_unique() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	for i in 20:
		var picks = rm._pick_reward_dice(3)
		assert(picks.size() == 3, "should pick 3 dice, got %d" % picks.size())
		var seen = {}
		for face in picks:
			assert(not face in seen, "duplicate face %d in picks %s" % [face, str(picks)])
			seen[face] = true
			assert(face in RunManager.REWARD_DIE_FACES, "face %d not in reward pool" % face)
	rm.queue_free()
```

- [ ] **Step 2: Run to confirm failure**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: error that `RunManager` class is not found.

- [ ] **Step 3: Create run_manager.gd**

Create `seal-the-box/scripts/run/run_manager.gd`:

```gdscript
class_name RunManager
extends Node

signal next_match_ready()
signal show_reward(dice_faces: Array)
signal run_won(match_number: int, hp: int)
signal run_over(match_number: int)

const REWARD_DIE_FACES = [2, 3, 4, 5, 6, 7, 8, 10, 12]
const RUN_LENGTH: int = 3

var match_number: int = 1

func start_run() -> void:
	match_number = 1
	GameState.reset_run()
	next_match_ready.emit()

func handle_match_won(_critical: bool) -> void:
	if match_number >= RUN_LENGTH:
		run_won.emit(match_number, GameState.hp)
	else:
		show_reward.emit(_pick_reward_dice(3))

func handle_match_lost() -> void:
	run_over.emit(match_number)

func advance_to_next_match(chosen_face: int) -> void:
	GameState.dice_pool.append(Die.new(chosen_face))
	match_number += 1
	GameState.reset_match()
	next_match_ready.emit()

func _pick_reward_dice(count: int) -> Array:
	var pool: Array = REWARD_DIE_FACES.duplicate()
	var picks: Array = []
	for i in count:
		var idx = randi() % pool.size()
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks
```

- [ ] **Step 4: Run to confirm tests pass**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: `All RunManager tests passed!`

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/run/run_manager.gd seal-the-box/tests/test_run_manager.gd
git commit -m "feat: add RunManager with match tracking, reward pool, and run-flow signals"
```

---

## Task 3: Wire RunManager into match.gd

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

This task replaces the existing `_on_match_won` / `_on_match_lost` / `_show_end_dialog` with RunManager-driven flow, adds the match-number display to the HUD, and creates stub handlers for the overlay signals (Tasks 4 and 5 fill them in).

- [ ] **Step 1: Add new member variables to the state and UI sections**

In the `# ── state ──` block (top of the file), replace lines 3–9 with:

```gdscript
# ── state ──────────────────────────────────────────────────────────────────
var _round_manager: RoundManager
var _run_manager: RunManager
var _selected_dice: Array = []
var _selected_tabs: Array[int] = []
var _selected_ability: AbilityData = null
var _targeting_die: bool = false
var _match_ended: bool = false
var _current_reward_faces: Array = []
```

In the `# ── ui references ──` block (below state), add these at the end of that block (before the `# ── lifecycle` comment):

```gdscript
var _match_label: Label
var _reward_overlay: Control
var _reward_title_label: Label
var _reward_buttons: Array[Button] = []
var _run_win_overlay: Control
var _run_win_detail_label: Label
var _run_over_overlay: Control
var _run_over_detail_label: Label
```

- [ ] **Step 2: Update _ready() to create RunManager and call start_run()**

Replace `_ready()`:

```gdscript
func _ready() -> void:
	_setup_3d()
	_setup_ui()
	_round_manager = RoundManager.new()
	add_child(_round_manager)
	_run_manager = RunManager.new()
	add_child(_run_manager)
	_connect_signals()
	_run_manager.start_run()
```

- [ ] **Step 3: Add RunManager signal connections in _connect_signals()**

Replace `_connect_signals()`:

```gdscript
func _connect_signals() -> void:
	_round_manager.phase_changed.connect(_on_phase_changed)
	_round_manager.round_ended.connect(_on_round_ended)
	_round_manager.match_won.connect(_on_match_won)
	_round_manager.match_lost.connect(_on_match_lost)
	_round_manager.tabs_sealed.connect(_on_tabs_sealed)
	_round_manager.status_updated.connect(_on_status_updated)
	_run_manager.next_match_ready.connect(_on_next_match_ready)
	_run_manager.show_reward.connect(_on_show_reward)
	_run_manager.run_won.connect(_on_run_won)
	_run_manager.run_over.connect(_on_run_over)
```

- [ ] **Step 4: Replace _on_match_won and _on_match_lost**

Replace the two handlers (currently lines 308–313):

```gdscript
func _on_match_won(critical: bool) -> void:
	if _match_ended:
		return
	_match_ended = true
	_action_button.disabled = true
	_roll_all_button.disabled = true
	for btn in _tab_buttons + _dice_buttons + _ability_buttons:
		btn.disabled = true
	_run_manager.handle_match_won(critical)

func _on_match_lost() -> void:
	if _match_ended:
		return
	_match_ended = true
	_action_button.disabled = true
	_roll_all_button.disabled = true
	for btn in _tab_buttons + _dice_buttons + _ability_buttons:
		btn.disabled = true
	_run_manager.handle_match_lost()
```

- [ ] **Step 5: Add _on_next_match_ready and overlay signal stubs**

Add these methods after `_on_match_lost` (replacing the old `_on_tabs_sealed` block area — keep `_on_tabs_sealed` and `_on_status_updated` as they are, just insert new methods):

```gdscript
func _on_next_match_ready() -> void:
	_match_ended = false
	_selected_dice = []
	_selected_tabs = []
	_selected_ability = null
	_targeting_die = false
	if _reward_overlay:
		_reward_overlay.visible = false
	if _run_win_overlay:
		_run_win_overlay.visible = false
	if _run_over_overlay:
		_run_over_overlay.visible = false
	_action_button.disabled = false
	_roll_all_button.disabled = false
	for btn in _tab_buttons + _dice_buttons + _ability_buttons:
		btn.disabled = false
	_round_manager.start_match()

func _on_show_reward(_dice_faces: Array) -> void:
	pass  # implemented in Task 4

func _on_run_won(_match_number: int, _hp: int) -> void:
	pass  # implemented in Task 5

func _on_run_over(_match_number: int) -> void:
	pass  # implemented in Task 5
```

- [ ] **Step 6: Delete _show_end_dialog**

Remove the entire `_show_end_dialog` method (currently the last function, lines 517–529):

```gdscript
func _show_end_dialog(message: String) -> void:
	if _match_ended:
		return
	_match_ended = true
	_action_button.disabled = true
	_roll_all_button.disabled = true
	for btn in _tab_buttons + _dice_buttons + _ability_buttons:
		btn.disabled = true
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Match Over"
	add_child(dialog)
	dialog.popup_centered()
```

- [ ] **Step 7: Add match label to the top bar in _setup_ui()**

After `top_bar.add_child(_hp_label)` (around line 94), add:

```gdscript
	_match_label = Label.new()
	_match_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(_match_label)
```

- [ ] **Step 8: Update _refresh_ui() to display match number**

Replace `_refresh_ui()`:

```gdscript
func _refresh_ui() -> void:
	_hp_label.text = "❤  %d" % GameState.hp
	_ap_label.text = "AP: %d" % GameState.ap
	_round_label.text = "Round: %d / %d" % [GameState.round, GameState.round_limit]
	_match_label.text = "Match: %d / %d" % [_run_manager.match_number, RunManager.RUN_LENGTH]
	_draw_label.text = str(_round_manager.get_draw_count())
	_discard_label.text = str(_round_manager.get_discard_count())
	_refresh_tab_display()
	_refresh_dice_display()
	_refresh_dice_highlight()
	_refresh_ability_display()
```

- [ ] **Step 9: Run the game and verify match 1 plays correctly**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --path seal-the-box
```

Expected: game opens, top bar shows `Match: 1 / 3`, rolling and sealing tabs all work. Winning or losing a match disables buttons and produces no crash (stubs do nothing yet). Starting dice pool is 5 dice (draws 3 per round, count shown in the Draw/Discard circles).

- [ ] **Step 10: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: wire RunManager into match.gd, add match label to HUD, remove old AcceptDialog end screen"
```

---

## Task 4: Add reward overlay

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

- [ ] **Step 1: Build the reward overlay at the end of _setup_ui()**

Inside `_setup_ui()`, just before the closing brace of the function, add:

```gdscript
	# ── Reward overlay (hidden until match 1 or 2 ends in a win) ──────────────
	var reward_overlay = Control.new()
	reward_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_overlay.visible = false
	var reward_bg = ColorRect.new()
	reward_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_bg.color = Color(0.0, 0.0, 0.0, 0.78)
	reward_overlay.add_child(reward_bg)

	var reward_center = VBoxContainer.new()
	reward_center.anchor_left = 0.2
	reward_center.anchor_right = 0.8
	reward_center.anchor_top = 0.3
	reward_center.anchor_bottom = 0.75
	reward_center.add_theme_constant_override("separation", 20)
	reward_overlay.add_child(reward_center)

	_reward_title_label = Label.new()
	_reward_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_title_label.add_theme_font_size_override("font_size", 24)
	reward_center.add_child(_reward_title_label)

	var reward_subtitle = Label.new()
	reward_subtitle.text = "Pick one die to permanently add to your pool:"
	reward_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_center.add_child(reward_subtitle)

	var reward_btn_row = HBoxContainer.new()
	reward_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_btn_row.add_theme_constant_override("separation", 20)
	reward_center.add_child(reward_btn_row)

	_reward_buttons = []
	for i in 3:
		var rbtn = Button.new()
		rbtn.custom_minimum_size = Vector2(110, 70)
		rbtn.add_theme_font_size_override("font_size", 22)
		rbtn.pressed.connect(_on_reward_die_picked.bind(i))
		reward_btn_row.add_child(rbtn)
		_reward_buttons.append(rbtn)

	root.add_child(reward_overlay)
	_reward_overlay = reward_overlay
```

- [ ] **Step 2: Implement _on_show_reward**

Replace the stub `_on_show_reward`:

```gdscript
func _on_show_reward(dice_faces: Array) -> void:
	_current_reward_faces = dice_faces
	_reward_title_label.text = "Match %d Complete — Pick a Reward Die" % _run_manager.match_number
	for i in 3:
		_reward_buttons[i].text = "d%d" % dice_faces[i]
	_reward_overlay.visible = true
```

- [ ] **Step 3: Add _on_reward_die_picked**

Add this method directly after `_on_show_reward`:

```gdscript
func _on_reward_die_picked(index: int) -> void:
	_reward_overlay.visible = false
	_run_manager.advance_to_next_match(_current_reward_faces[index])
```

- [ ] **Step 4: Smoke test the reward flow**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --path seal-the-box
```

1. Win match 1 (seal all tabs, or get remaining sum ≤ 13).
2. Reward overlay appears: title says "Match 1 Complete — Pick a Reward Die", three buttons show die labels (e.g., "d5", "d10", "d3").
3. Click a button — overlay disappears, match 2 begins.
4. Top bar shows `Match: 2 / 3`.
5. Draw + Discard circle counts reflect 6 dice total (5 base + 1 reward).

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: add reward overlay — pick 1 of 3 random dice after match 1 and 2"
```

---

## Task 5: Add run-win and run-over overlays

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

- [ ] **Step 1: Build the run-win overlay in _setup_ui()**

After the reward overlay block added in Task 4, add:

```gdscript
	# ── Run-win overlay ────────────────────────────────────────────────────────
	var win_overlay = Control.new()
	win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	win_overlay.visible = false
	var win_bg = ColorRect.new()
	win_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_bg.color = Color(0.0, 0.0, 0.0, 0.78)
	win_overlay.add_child(win_bg)

	var win_center = VBoxContainer.new()
	win_center.anchor_left = 0.2
	win_center.anchor_right = 0.8
	win_center.anchor_top = 0.3
	win_center.anchor_bottom = 0.75
	win_center.add_theme_constant_override("separation", 20)
	win_overlay.add_child(win_center)

	var win_title = Label.new()
	win_title.text = "Run Complete!\nYou Sealed the Box!"
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.add_theme_font_size_override("font_size", 30)
	win_center.add_child(win_title)

	_run_win_detail_label = Label.new()
	_run_win_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_win_detail_label.add_theme_font_size_override("font_size", 20)
	win_center.add_child(_run_win_detail_label)

	var win_play_btn = Button.new()
	win_play_btn.text = "Play Again"
	win_play_btn.custom_minimum_size = Vector2(160, 52)
	win_play_btn.add_theme_font_size_override("font_size", 18)
	win_play_btn.pressed.connect(_on_play_again_pressed)
	win_center.add_child(win_play_btn)

	root.add_child(win_overlay)
	_run_win_overlay = win_overlay

	# ── Run-over overlay ───────────────────────────────────────────────────────
	var over_overlay = Control.new()
	over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	over_overlay.visible = false
	var over_bg = ColorRect.new()
	over_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_bg.color = Color(0.0, 0.0, 0.0, 0.78)
	over_overlay.add_child(over_bg)

	var over_center = VBoxContainer.new()
	over_center.anchor_left = 0.2
	over_center.anchor_right = 0.8
	over_center.anchor_top = 0.3
	over_center.anchor_bottom = 0.75
	over_center.add_theme_constant_override("separation", 20)
	over_overlay.add_child(over_center)

	var over_title = Label.new()
	over_title.text = "Run Over"
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_title.add_theme_font_size_override("font_size", 30)
	over_center.add_child(over_title)

	_run_over_detail_label = Label.new()
	_run_over_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_over_detail_label.add_theme_font_size_override("font_size", 20)
	over_center.add_child(_run_over_detail_label)

	var over_play_btn = Button.new()
	over_play_btn.text = "Play Again"
	over_play_btn.custom_minimum_size = Vector2(160, 52)
	over_play_btn.add_theme_font_size_override("font_size", 18)
	over_play_btn.pressed.connect(_on_play_again_pressed)
	over_center.add_child(over_play_btn)

	root.add_child(over_overlay)
	_run_over_overlay = over_overlay
```

- [ ] **Step 2: Implement _on_run_won and _on_run_over**

Replace the stubs added in Task 3:

```gdscript
func _on_run_won(match_number: int, hp: int) -> void:
	_run_win_detail_label.text = "Match: %d / %d  |  Final HP: %d" % [match_number, RunManager.RUN_LENGTH, hp]
	_run_win_overlay.visible = true

func _on_run_over(match_number: int) -> void:
	_run_over_detail_label.text = "Defeated on Match: %d / %d  |  HP: 0" % [match_number, RunManager.RUN_LENGTH]
	_run_over_overlay.visible = true
```

- [ ] **Step 3: Add _on_play_again_pressed**

Add this method after `_on_run_over`:

```gdscript
func _on_play_again_pressed() -> void:
	_run_manager.start_run()
```

- [ ] **Step 4: Full run smoke test**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --path seal-the-box
```

**Win path:**
1. Win match 1 → reward overlay → pick die → match 2 (`Match: 2 / 3`).
2. Win match 2 → reward overlay → pick die → match 3 (`Match: 3 / 3`).
3. Win match 3 → run-win overlay shows "Run Complete! You Sealed the Box!" and `Match: 3 / 3  |  Final HP: N`.
4. Click "Play Again" → run resets, HP back to 5, back to `Match: 1 / 3`, original 5-dice pool.

**Lose path:**
1. Skip rounds until overtime drains HP to 0 → run-over overlay shows "Run Over" and `Defeated on Match: 1 / 3  |  HP: 0`.
2. Click "Play Again" → run resets cleanly.

**HP persistence check:**
1. Take overtime damage in match 1 (HP drops to 4 or 3) → win match 1 → pick reward → match 2 HP shows the reduced value, not reset to 5.

- [ ] **Step 5: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: add run-win and run-over overlays with Play Again — run structure complete"
```
