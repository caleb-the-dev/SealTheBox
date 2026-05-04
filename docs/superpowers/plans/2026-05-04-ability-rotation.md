# Ability Rotation + Charges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current free one-time ability system with a 3-slot fixed hand where abilities have limited charges and rotate out every match.

**Architecture:** AbilityData gains a `charges` field; GameState ability_hand becomes a fixed 3-slot array; RoundManager decrements charges instead of erasing; RunManager replaces the ability-offer flow with a mandatory rotation overlay that appears after every match win (threshold or critical); match.gd replaces the ability-offer overlay with a rotation overlay and updates the slot display to show charges and the "next to discard" slot.

**Tech Stack:** GDScript / Godot 4.5, headless test runner

---

## File Map

| File | Change |
|------|--------|
| `seal-the-box/data/abilities.csv` | Add `charges` column (8th field) |
| `seal-the-box/resources/ability_data.gd` | Add `charges: int` and `max_charges: int` fields |
| `seal-the-box/scripts/globals/ability_library.gd` | Parse `charges` from row[7], set `max_charges = charges` |
| `seal-the-box/scripts/globals/game_state.gd` | Fixed 3-slot `ability_hand`; random starter in slot 2; add `ABILITY_POOL_IDS` const |
| `seal-the-box/scripts/match/round_manager.gd` | Add charges guard; decrement instead of erase |
| `seal-the-box/scripts/run/run_manager.gd` | Replace ability-offer flow with rotation flow; add `dev_skip_rotation()` |
| `seal-the-box/scripts/match/match.gd` | Replace ability-offer overlay with rotation overlay; update slot display |
| `seal-the-box/tests/test_run_manager.gd` | Substantial rewrite for new ability system |

---

## Task 1: Branch + Data Layer (CSV, AbilityData, AbilityLibrary)

**Files:**
- Modify: `seal-the-box/data/abilities.csv`
- Modify: `seal-the-box/resources/ability_data.gd`
- Modify: `seal-the-box/scripts/globals/ability_library.gd`

- [ ] **Step 1: Create the feature branch**

```bash
git checkout master
git checkout -b feature/ability-rotation
```

Expected: prompt shows `feature/ability-rotation`

- [ ] **Step 2: Add `charges` column to abilities.csv**

Replace the entire file content with:

```
id,flavor_name,type,traits,cooldown,ap_cost,description,charges
reroll_die,Reroll,Ethereal,Repeatable,0,0,Reroll any one die — discard its current value and roll it again within its face range.,2
greater_1,Empower,Mundane,,0,0,Add 1 to any rolled die's value. Cannot exceed the die's maximum face.,3
lesser_1,Weaken,Cosmic,,0,0,Subtract 1 from any rolled die's value. Cannot go below 1.,3
greater_2,Empower II,Mundane,,0,0,Add 2 to any rolled die's value. Cannot exceed the die's maximum face.,2
lesser_2,Weaken II,Cosmic,,0,0,Subtract 2 from any rolled die's value. Cannot go below 1.,2
reroll_all,Reroll All,Ethereal,,0,0,Reroll every die in hand — each die discards its current value and rolls again.,1
roll_d4,Mundane Card,Mundane,,0,1,Roll 1 mundane d4,1
lesser_greater_1,Mundane Card,Mundane,,0,2,Apply lesser 1 or greater 1 to any die,1
cosmic_coin,Cosmic Card,Cosmic,,0,1,Flip a cosmic coin (1d2),1
lesser_2_cosmic,Cosmic Card,Cosmic,Preroll,0,1,Apply lesser 2 to any 1 cosmic die,1
roll_d20,Diabolic Card,Diabolic,,0,2,Roll 1 diabolic d20,1
greater_2_diabolic,Diabolic Card,Diabolic,,1,2,Apply greater 2 to any 1 diabolic die,1
x2_diabolic,Diabolic Card,Diabolic,Preroll,1,1,Apply x2 to any 1 diabolic die,1
greater_1_diabolic,Diabolic Card,Diabolic,,0,1,Apply greater 1 to any 1 diabolic die,1
put_down_highest,Diabolic Card,Diabolic,Non-Final,0,2,Put down the highest tab,1
```

- [ ] **Step 3: Add `charges` and `max_charges` fields to AbilityData**

Replace the entire content of `seal-the-box/resources/ability_data.gd` with:

```gdscript
class_name AbilityData
extends Resource

@export var id: String = ""
@export var flavor_name: String = ""
@export var type: String = ""
@export var traits: Array[String] = []
@export var cooldown: int = 0
@export var ap_cost: int = 1
@export var description: String = ""
@export var charges: int = 1
@export var max_charges: int = 1

func _init() -> void:
	traits = []
```

- [ ] **Step 4: Update AbilityLibrary to parse charges and set max_charges**

Replace the entire content of `seal-the-box/scripts/globals/ability_library.gd` with:

```gdscript
extends Node

var _abilities: Dictionary = {}

func _ready() -> void:
	_load_csv()

func _load_csv() -> void:
	var file = FileAccess.open("res://data/abilities.csv", FileAccess.READ)
	if not file:
		push_error("AbilityLibrary: cannot open res://data/abilities.csv")
		return
	file.get_csv_line()  # skip header row
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 7 or row[0].strip_edges().is_empty():
			continue
		if not row[4].is_valid_int() or not row[5].is_valid_int():
			push_warning("AbilityLibrary: skipping malformed row (non-integer cost/cooldown): %s" % row[0])
			continue
		var data = AbilityData.new()
		data.id = row[0].strip_edges()
		data.flavor_name = row[1].strip_edges()
		data.type = row[2].strip_edges()
		var traits_raw = row[3].strip_edges()
		data.traits.clear()
		if traits_raw != "":
			for t in traits_raw.split(",", false):
				data.traits.append(t.strip_edges())
		data.cooldown = row[4].to_int()
		data.ap_cost = row[5].to_int()
		data.description = row[6].strip_edges()
		data.charges = row[7].to_int() if row.size() > 7 and row[7].strip_edges().is_valid_int() else 1
		data.max_charges = data.charges
		_abilities[data.id] = data
	file.close()

func get_ability(id: String) -> AbilityData:
	return _abilities.get(id, null)

func get_all() -> Array:
	return _abilities.values()
```

- [ ] **Step 5: Commit the data layer**

```bash
git add seal-the-box/data/abilities.csv seal-the-box/resources/ability_data.gd seal-the-box/scripts/globals/ability_library.gd
git commit -m "feat: add charges/max_charges to AbilityData; parse from CSV"
```

---

## Task 2: GameState — Fixed 3-Slot Hand

**Files:**
- Modify: `seal-the-box/scripts/globals/game_state.gd`

- [ ] **Step 1: Rewrite game_state.gd with 3-slot hand**

Replace the entire content of `seal-the-box/scripts/globals/game_state.gd` with:

```gdscript
extends Node

const ABILITY_POOL_IDS: Array = ["reroll_die", "greater_1", "lesser_1", "greater_2", "lesser_2", "reroll_all"]

var hp: int = 6
var ap: int = 3
var round: int = 0
var round_limit: int = 3
var win_threshold: int = 13
var tabs: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
var dice_pool: Array = []   # Array of Die
var dice_hand: Array = []   # Array of Die (currently drawn)
var ability_hand: Array = [null, null, null]  # fixed 3-slot array; null = empty
var current_box: BoxDefinition = null

func reset_run() -> void:
	hp = 6
	_setup_dice_pool()
	reset_match()
	_setup_ability_hand()

func reset_match() -> void:
	ap = 3
	round = 0
	dice_hand = []
	for die in dice_pool:
		die.value = 0
		die.rolled = false

func spend_ap(amount: int) -> bool:
	if ap < amount:
		return false
	ap -= amount
	return true

func reset_run_end() -> void:
	reset_match()

func _setup_dice_pool() -> void:
	dice_pool = []
	for i in 3:
		dice_pool.append(Die.new(6))
	dice_pool.append(Die.new(4))
	dice_pool.append(Die.new(8))

func _setup_ability_hand() -> void:
	var lib = Engine.get_singleton("AbilityLibrary")
	var chosen_id = ABILITY_POOL_IDS[randi() % ABILITY_POOL_IDS.size()]
	var ability = lib.get_ability(chosen_id)
	ability_hand = [null, null, null]
	if ability:
		ability_hand[2] = ability.duplicate()
	else:
		push_error("GameState: ability not found: %s" % chosen_id)
```

- [ ] **Step 2: Commit**

```bash
git add seal-the-box/scripts/globals/game_state.gd
git commit -m "feat: restructure ability_hand to fixed 3-slot array with random starter in slot 2"
```

---

## Task 3: RoundManager — Charge Decrement

**Files:**
- Modify: `seal-the-box/scripts/match/round_manager.gd:80-113`

- [ ] **Step 1: Add charges guard and swap erase for decrement**

In `round_manager.gd`, replace the `use_ability` method (lines 80–113) with:

```gdscript
func use_ability(ability: AbilityData, target_die) -> bool:
	if _match_over:
		return false
	if ability.charges <= 0:
		return false
	if _current_phase == "roll":
		status_updated.emit("Use abilities after rolling dice.")
		return false
	if target_die == null and ability.id != "reroll_all":
		push_warning("RoundManager: target_die is null for ability: %s" % ability.id)
		return false
	match ability.id:
		"reroll_die":
			_dice_pool.reroll(target_die)
		"greater_1":
			_dice_pool.apply_greater(target_die, 1)
		"lesser_1":
			_dice_pool.apply_lesser(target_die, 1)
		"greater_2":
			_dice_pool.apply_greater(target_die, 2)
		"lesser_2":
			_dice_pool.apply_lesser(target_die, 2)
		"reroll_all":
			for die in GameState.dice_hand:
				if die.rolled:
					_dice_pool.reroll(die)
		_:
			push_warning("RoundManager: unhandled ability id: %s" % ability.id)
			return false
	ability.charges -= 1
	var total := 0
	for die in GameState.dice_hand:
		if die.rolled:
			total += die.value
	status_updated.emit("Seal Phase — Total: %d — select tabs that sum to it." % total)
	return true
```

- [ ] **Step 2: Commit**

```bash
git add seal-the-box/scripts/match/round_manager.gd
git commit -m "feat: decrement ability charges on use instead of erasing from hand"
```

---

## Task 4: RunManager — Rotation Flow

**Files:**
- Modify: `seal-the-box/scripts/run/run_manager.gd`

This task replaces the entire ability-offer flow (`show_ability_offer`, `handle_ability_offer_result`, `_pick_ability_offer`, `_current_offered_ability`) with a mandatory rotation flow.

- [ ] **Step 1: Rewrite run_manager.gd with rotation flow**

Replace the entire content of `seal-the-box/scripts/run/run_manager.gd` with:

```gdscript
class_name RunManager
extends Node

signal next_match_ready(box: BoxDefinition)
signal show_reward(dice_faces: Array)
signal show_rotation_offer(options: Array)
signal run_over(match_number: int)

const REWARD_DIE_FACES = [2, 4, 6, 8, 10, 12]
const ABILITY_POOL_IDS: Array = ["reroll_die", "greater_1", "lesser_1", "greater_2", "lesser_2", "reroll_all"]

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
		show_reward.emit(_pick_reward_dice(3))
	else:
		_do_rotation_offer()

func handle_match_lost() -> void:
	run_over.emit(match_number)

func handle_reward_picked(chosen_face: int) -> void:
	var gs = Engine.get_singleton("GameState")
	gs.dice_pool.append(Die.new(chosen_face))
	_do_rotation_offer()

func handle_rotation_pick(chosen: AbilityData) -> void:
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

func _pick_reward_dice(count: int) -> Array:
	var pool: Array = REWARD_DIE_FACES.duplicate()
	var picks: Array = []
	for i in count:
		var idx = randi() % pool.size()
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks

func _do_rotation_offer() -> void:
	var lib = Engine.get_singleton("AbilityLibrary")
	_pending_rotation_options = []
	for i in 3:
		var id = ABILITY_POOL_IDS[randi() % ABILITY_POOL_IDS.size()]
		var ability = lib.get_ability(id)
		if ability:
			_pending_rotation_options.append(ability.duplicate())
	show_rotation_offer.emit(_pending_rotation_options)
```

- [ ] **Step 2: Commit**

```bash
git add seal-the-box/scripts/run/run_manager.gd
git commit -m "feat: replace ability-offer flow with mandatory rotation overlay after every match"
```

---

## Task 5: match.gd — Rotation Overlay + Remove Old Offer Overlay

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

This task is split into parts because match.gd is large. Make all changes to match.gd in one edit session, then commit.

- [ ] **Step 1: Update state variable declarations**

At the top of `match.gd`, replace the ability-offer overlay vars with rotation overlay vars.

Remove these lines (around line 38–41):
```gdscript
var _ability_offer_overlay: Control
var _offer_ability_name_label: Label
var _offer_ability_desc_label: Label
var _offer_swap_buttons: Array[Button] = []
```

Add in their place:
```gdscript
var _rotation_overlay: Control
var _rotation_buttons: Array[Button] = []
var _current_rotation_options: Array = []
```

- [ ] **Step 2: Replace the ability-offer overlay build code in `_setup_ui`**

Remove the entire ability-offer overlay block (from `# ── Ability offer overlay` comment down to `_ability_offer_overlay = offer_overlay`, approximately lines 425–489). Replace it with the rotation overlay build code:

```gdscript
	# ── Rotation overlay ──────────────────────────────────────────────────────
	var rot_overlay = Control.new()
	rot_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	rot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	rot_overlay.visible = false
	var rot_bg = ColorRect.new()
	rot_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	rot_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	rot_overlay.add_child(rot_bg)

	var rot_center = VBoxContainer.new()
	rot_center.anchor_left = 0.1
	rot_center.anchor_right = 0.9
	rot_center.anchor_top = 0.1
	rot_center.anchor_bottom = 0.9
	rot_center.add_theme_constant_override("separation", 24)
	rot_overlay.add_child(rot_center)

	var rot_title = Label.new()
	rot_title.text = "Pick an Ability"
	rot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot_title.add_theme_font_size_override("font_size", 32)
	rot_center.add_child(rot_title)

	var rot_subtitle = Label.new()
	rot_subtitle.text = "Fills Slot 3 — Slot 1 will be discarded after this pick"
	rot_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot_subtitle.add_theme_font_size_override("font_size", 16)
	rot_center.add_child(rot_subtitle)

	var rot_btn_row = HBoxContainer.new()
	rot_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rot_btn_row.add_theme_constant_override("separation", 24)
	rot_btn_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rot_center.add_child(rot_btn_row)

	_rotation_buttons = []
	for i in 3:
		var rbtn = Button.new()
		rbtn.custom_minimum_size = Vector2(200, 140)
		rbtn.add_theme_font_size_override("font_size", 15)
		rbtn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rbtn.pressed.connect(_on_rotation_pick_pressed.bind(i))
		rot_btn_row.add_child(rbtn)
		_rotation_buttons.append(rbtn)

	root.add_child(rot_overlay)
	_rotation_overlay = rot_overlay
```

- [ ] **Step 3: Update `_connect_signals`**

Replace:
```gdscript
	_run_manager.show_ability_offer.connect(_on_show_ability_offer)
```

With:
```gdscript
	_run_manager.show_rotation_offer.connect(_on_show_rotation_offer)
```

- [ ] **Step 4: Update `_on_next_match_ready` to hide the rotation overlay**

Replace:
```gdscript
	if _ability_offer_overlay:
		_ability_offer_overlay.visible = false
```

With:
```gdscript
	if _rotation_overlay:
		_rotation_overlay.visible = false
```

- [ ] **Step 5: Replace offer overlay signal handlers with rotation handlers**

Remove these three methods completely:
- `_on_show_ability_offer`
- `_on_offer_swap_pressed`
- `_on_offer_skip_pressed`

Add in their place:
```gdscript
func _on_show_rotation_offer(options: Array) -> void:
	_current_rotation_options = options
	for i in 3:
		var a = options[i]
		_rotation_buttons[i].text = "%s\n\n%s\n\n[%d charges]" % [a.flavor_name, a.description, a.max_charges]
	_rotation_overlay.visible = true

func _on_rotation_pick_pressed(index: int) -> void:
	_rotation_overlay.visible = false
	_run_manager.handle_rotation_pick(_current_rotation_options[index])
```

- [ ] **Step 6: Update `_on_dev_win_series_pressed` to auto-skip rotation**

Replace:
```gdscript
func _on_dev_win_series_pressed() -> void:
	_dev_overlay.visible = false
	var safety := 0
	while not _match_ended and safety < 10:
		safety += 1
		_round_manager.dev_win_match()
```

With:
```gdscript
func _on_dev_win_series_pressed() -> void:
	_dev_overlay.visible = false
	var safety := 0
	while not _match_ended and safety < 10:
		safety += 1
		_round_manager.dev_win_match()
		_run_manager.dev_skip_rotation()
```

- [ ] **Step 7: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: replace ability-offer overlay with rotation overlay; wire dev skip"
```

---

## Task 6: match.gd — Ability Slot Display

**Files:**
- Modify: `seal-the-box/scripts/match/match.gd`

- [ ] **Step 1: Update `_refresh_ability_display` for charges + slot indicator**

Replace the entire `_refresh_ability_display` method with:

```gdscript
func _refresh_ability_display() -> void:
	var hand = GameState.ability_hand
	for i in 3:
		var btn = _ability_buttons[i]
		var a = hand[i] if i < hand.size() else null
		if a != null:
			var name_text = a.flavor_name
			if i == 0:
				name_text += " ★"
			var charges_text = "%d/%d" % [a.charges, a.max_charges]
			if btn is TooltipButton:
				(btn as TooltipButton).update_info("%s  [%s]" % [name_text, charges_text], a.description)
			if a.charges <= 0:
				btn.disabled = true
				btn.modulate = Color(0.45, 0.45, 0.45)
			elif i == 0:
				btn.disabled = false
				btn.modulate = Color(1.0, 0.75, 0.3)
			else:
				btn.disabled = false
				btn.modulate = Color.WHITE
		else:
			if btn is TooltipButton:
				(btn as TooltipButton).clear_info()
			btn.disabled = true
			btn.modulate = Color(0.3, 0.3, 0.3)
```

- [ ] **Step 2: Update `_on_ability_pressed` to guard null slots and 0 charges**

Replace the entire `_on_ability_pressed` method with:

```gdscript
func _on_ability_pressed(index: int) -> void:
	var hand = GameState.ability_hand
	if index >= hand.size() or hand[index] == null:
		return
	var ability = hand[index]
	if ability.charges <= 0:
		_status_label.text = "%s is exhausted (0 charges)." % ability.flavor_name
		return
	if ability.id == "reroll_all":
		if _round_manager.use_ability(ability, null):
			_selected_ability = null
			_targeting_die = false
			_refresh_ui()
			_flash_ability_used(index)
		return
	_selected_ability = ability
	_targeting_die = true
	_status_label.text = "%s — click a die to target it." % ability.description
```

- [ ] **Step 3: Update `_flash_ability_used` to refresh display after flash (handles grey-out on exhaustion)**

Replace the entire `_flash_ability_used` method with:

```gdscript
func _flash_ability_used(idx: int) -> void:
	var btn = _ability_buttons[idx]
	btn.modulate = Color(0.3, 1.2, 0.3)
	await get_tree().create_timer(0.35).timeout
	_refresh_ability_display()
```

- [ ] **Step 4: Commit**

```bash
git add seal-the-box/scripts/match/match.gd
git commit -m "feat: ability buttons show charges + slot indicator; grey out exhausted slots"
```

---

## Task 7: Tests Rewrite

**Files:**
- Modify: `seal-the-box/tests/test_run_manager.gd`

The existing ability-hand tests assume the old erase-on-use behavior and ability-offer overlay. Replace them entirely.

Tests to keep (still valid): reset_run_sets_hp, reset_run_sets_starting_dice_pool, reset_match_preserves_hp, reset_match_preserves_dice_pool, run_manager_start_run, run_manager_match_lost, reward_dice_unique.

Tests to replace or remove: threshold_win_advances_without_reward (update for rotation), critical_win_triggers_reward (update for rotation), ability_hand_persists_across_matches (remove), ability_offer_swap_updates_hand (remove), ability_offer_skip_leaves_hand_unchanged (remove).

Tests to add: initial_hand_layout, rotation_after_match_1, rotation_after_match_3, charges_decrement, exhausted_ability_blocked, rotation_discards_slot_0_regardless_of_charges.

- [ ] **Step 1: Rewrite the test file**

Replace the entire content of `seal-the-box/tests/test_run_manager.gd` with:

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

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)
	Engine.register_singleton("GameState", gs)

	_test_reset_run_sets_hp(gs)
	_test_reset_run_sets_starting_dice_pool(gs)
	_test_reset_match_preserves_hp(gs)
	_test_reset_match_preserves_dice_pool(gs)
	_test_initial_hand_layout(gs)
	_test_run_manager_start_run(gs)
	_test_run_manager_match_lost()
	_test_reward_dice_unique()
	_test_threshold_win_triggers_rotation(gs)
	_test_critical_win_triggers_reward_then_rotation(gs)
	_test_rotation_after_match_1(gs)
	_test_rotation_after_match_3(gs)
	_test_rotation_discards_slot_0_regardless_of_charges(gs)
	_test_charges_decrement(gs)
	_test_exhausted_ability_blocked(gs)
	print("All RunManager tests passed!")
	quit()

# ── preserved tests ──────────────────────────────────────────────────────────

func _test_reset_run_sets_hp(gs: Node) -> void:
	gs.hp = 1
	gs.reset_run()
	assert(gs.hp == 6, "reset_run should restore HP to 6, got %d" % gs.hp)

func _test_reset_run_sets_starting_dice_pool(gs: Node) -> void:
	gs.dice_pool = []
	gs.reset_run()
	assert(gs.dice_pool.size() == 5, "starting pool should be 5 dice, got %d" % gs.dice_pool.size())
	var faces = gs.dice_pool.map(func(d): return d.faces)
	faces.sort()
	assert(faces == [4, 6, 6, 6, 8], "starting pool should be 1d4+3d6+1d8, got %s" % str(faces))

func _test_reset_match_preserves_hp(gs: Node) -> void:
	gs.reset_run()
	gs.hp = 3
	gs.reset_match()
	assert(gs.hp == 3, "reset_match should not change HP, got %d" % gs.hp)

func _test_reset_match_preserves_dice_pool(gs: Node) -> void:
	gs.reset_run()
	var extra = Die.new(12)
	gs.dice_pool.append(extra)
	var pool_size = gs.dice_pool.size()
	gs.reset_match()
	assert(gs.dice_pool.size() == pool_size, "reset_match should not change dice_pool size, got %d" % gs.dice_pool.size())
	assert(extra in gs.dice_pool, "reset_match should not remove the extra die from dice_pool")

func _test_run_manager_start_run(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var counts = {"next_match": 0}
	rm.next_match_ready.connect(func(_box): counts["next_match"] += 1)

	rm.start_run()
	assert(rm.match_number == 1, "match_number should be 1 after start_run, got %d" % rm.match_number)
	assert(counts["next_match"] == 1, "start_run should emit next_match_ready once, got %d" % counts["next_match"])
	assert(gs.hp == 6, "start_run should reset HP to 6, got %d" % gs.hp)
	rm.queue_free()

func _test_run_manager_match_lost() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var run_over_log: Array = []
	rm.next_match_ready.connect(func(_box): pass)
	rm.run_over.connect(func(mn): run_over_log.append(mn))

	rm.start_run()
	rm.handle_match_lost()
	assert(run_over_log.size() == 1, "match lost should emit run_over once")
	assert(run_over_log[0] == 1, "run_over on match 1 should report 1, got %d" % run_over_log[0])
	rm.queue_free()

func _test_reward_dice_unique() -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	for i in 20:
		var picks = rm._pick_reward_dice(3)
		assert(picks.size() == 3, "should pick 3 dice, got %d" % picks.size())
		var seen = {}
		for face in picks:
			assert(not face in seen, "duplicate face %d in picks %s" % [face, str(picks)])
			seen[face] = true
			assert(face in RunManager.REWARD_DIE_FACES, "face %d not in reward pool" % face)
	rm.queue_free()

# ── new ability-hand tests ────────────────────────────────────────────────────

func _test_initial_hand_layout(gs: Node) -> void:
	gs.reset_run()
	assert(gs.ability_hand.size() == 3, "ability_hand should have 3 slots, got %d" % gs.ability_hand.size())
	assert(gs.ability_hand[0] == null, "slot 0 should be null initially")
	assert(gs.ability_hand[1] == null, "slot 1 should be null initially")
	assert(gs.ability_hand[2] != null, "slot 2 should have the starter ability")

func _test_threshold_win_triggers_rotation(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var reward_count = [0]
	var rotation_count = [0]
	var next_match_log: Array = []
	rm.next_match_ready.connect(func(box): next_match_log.append(box))
	rm.show_reward.connect(func(_f): reward_count[0] += 1)
	rm.show_rotation_offer.connect(func(opts):
		rotation_count[0] += 1
		rm.handle_rotation_pick(opts[0])
	)

	rm.start_run()
	assert(next_match_log.size() == 1, "start_run should emit next_match_ready once")

	rm.handle_match_won(false)
	assert(reward_count[0] == 0, "threshold win should NOT emit show_reward")
	assert(rotation_count[0] == 1, "threshold win should emit show_rotation_offer once")
	assert(next_match_log.size() == 2, "after rotation pick, next_match_ready should fire")
	assert(rm.match_number == 2, "match_number should be 2, got %d" % rm.match_number)
	rm.queue_free()

func _test_critical_win_triggers_reward_then_rotation(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	var reward_faces_log: Array = []
	var rotation_count = [0]
	var next_match_log: Array = []
	rm.next_match_ready.connect(func(box): next_match_log.append(box))
	rm.show_reward.connect(func(faces): reward_faces_log.append(faces.duplicate()))
	rm.show_rotation_offer.connect(func(opts):
		rotation_count[0] += 1
		rm.handle_rotation_pick(opts[0])
	)

	rm.start_run()                    # next_match_log: 1
	rm.handle_match_won(true)         # show_reward fires; rotation NOT yet
	assert(reward_faces_log.size() == 1, "critical win should emit show_reward once")
	assert(rotation_count[0] == 0, "rotation offer should not fire until reward is picked")
	assert(next_match_log.size() == 1, "next_match_ready should NOT fire before rotation resolved")

	var faces = reward_faces_log[0]
	assert(faces.size() == 3, "should offer 3 reward dice, got %d" % faces.size())
	rm.handle_reward_picked(faces[0])
	assert(rotation_count[0] == 1, "show_rotation_offer should fire after reward pick")
	assert(next_match_log.size() == 2, "next_match_ready should fire after rotation pick, got %d" % next_match_log.size())
	assert(rm.match_number == 2, "match_number should be 2, got %d" % rm.match_number)
	rm.queue_free()

func _test_rotation_after_match_1(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	var starter = gs.ability_hand[2]
	assert(starter != null, "starter ability should be in slot 2")

	rm.handle_match_won(false)

	assert(gs.ability_hand[0] == null, "slot 0 should still be null after match 1 rotation")
	assert(gs.ability_hand[1] == starter, "slot 1 should hold the starter (shifted from slot 2)")
	assert(gs.ability_hand[2] != null, "slot 2 should hold the newly picked ability")
	rm.queue_free()

func _test_rotation_after_match_3(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)
	rm.show_rotation_offer.connect(func(opts): rm.handle_rotation_pick(opts[0]))

	rm.start_run()
	var starter = gs.ability_hand[2]

	rm.handle_match_won(false)  # match 1: starter → slot 1; new → slot 2
	var after_match_1_slot_2 = gs.ability_hand[2]

	rm.handle_match_won(false)  # match 2: starter → slot 0; after_match_1_slot_2 → slot 1; new → slot 2

	assert(gs.ability_hand[0] == starter, "slot 0 should hold starter after match 2")

	rm.handle_match_won(false)  # match 3: starter discarded; after_match_1_slot_2 → slot 0; old slot 2 → slot 1; new → slot 2

	assert(gs.ability_hand[0] != starter, "slot 0 should NOT hold starter after match 3 (it was discarded)")
	assert(gs.ability_hand[0] == after_match_1_slot_2, "slot 0 should hold the match-1 pick (shifted up)")
	assert(gs.ability_hand[2] != null, "slot 2 should have a fresh pick")
	rm.queue_free()

func _test_rotation_discards_slot_0_regardless_of_charges(gs: Node) -> void:
	var rm = RunManager.new()
	get_root().add_child(rm)
	rm.next_match_ready.connect(func(_box): pass)

	var lib = Engine.get_singleton("AbilityLibrary")
	var ability_slot0 = lib.get_ability("reroll_all").duplicate()
	ability_slot0.charges = 1  # still has charges — should be discarded anyway
	var ability_slot1 = lib.get_ability("greater_1").duplicate()
	var ability_slot2 = lib.get_ability("lesser_1").duplicate()
	gs.ability_hand = [ability_slot0, ability_slot1, ability_slot2]
	rm.match_number = 1
	rm._boxes = Engine.get_singleton("BoxLibrary").get_ordered()

	var picked_option: AbilityData = null
	rm.show_rotation_offer.connect(func(opts):
		picked_option = opts[0]
		rm.handle_rotation_pick(opts[0])
	)

	rm.handle_match_won(false)

	assert(gs.ability_hand[0] == ability_slot1, "slot 0 should now hold what was in slot 1")
	assert(gs.ability_hand[1] == ability_slot2, "slot 1 should now hold what was in slot 2")
	assert(gs.ability_hand[2] == picked_option, "slot 2 should hold the newly picked ability")
	assert(not ability_slot0 in gs.ability_hand, "old slot 0 ability should be gone (discarded despite having charges)")
	rm.queue_free()

func _test_charges_decrement(gs: Node) -> void:
	gs.reset_run()
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("greater_1").duplicate()
	assert(ability.charges == 3, "greater_1 should start with 3 charges, got %d" % ability.charges)
	assert(ability.max_charges == 3, "greater_1 max_charges should be 3, got %d" % ability.max_charges)
	gs.ability_hand = [null, null, ability]

	var round_mgr = RoundManager.new()
	get_root().add_child(round_mgr)
	var box_lib = Engine.get_singleton("BoxLibrary")
	round_mgr.start_match(box_lib.get_ordered()[0])
	# Enter act phase by rolling one die
	round_mgr.commit_roll([gs.dice_hand[0]])

	var result1 = round_mgr.use_ability(ability, gs.dice_hand[0])
	assert(result1 == true, "first use should succeed")
	assert(ability.charges == 2, "charges should be 2 after first use, got %d" % ability.charges)

	var result2 = round_mgr.use_ability(ability, gs.dice_hand[0])
	assert(result2 == true, "second use should succeed")
	assert(ability.charges == 1, "charges should be 1 after second use, got %d" % ability.charges)

	var result3 = round_mgr.use_ability(ability, gs.dice_hand[0])
	assert(result3 == true, "third use should succeed")
	assert(ability.charges == 0, "charges should be 0 after third use, got %d" % ability.charges)

	round_mgr.queue_free()

func _test_exhausted_ability_blocked(gs: Node) -> void:
	gs.reset_run()
	var lib = Engine.get_singleton("AbilityLibrary")
	var ability = lib.get_ability("greater_1").duplicate()
	ability.charges = 0
	gs.ability_hand = [null, null, ability]

	var round_mgr = RoundManager.new()
	get_root().add_child(round_mgr)
	var box_lib = Engine.get_singleton("BoxLibrary")
	round_mgr.start_match(box_lib.get_ordered()[0])
	round_mgr.commit_roll([gs.dice_hand[0]])

	var result = round_mgr.use_ability(ability, gs.dice_hand[0])
	assert(result == false, "use_ability should return false for 0-charge ability")
	assert(ability.charges == 0, "charges should remain 0 after failed use")
	round_mgr.queue_free()
```

- [ ] **Step 2: Run the tests**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected output ends with: `All RunManager tests passed!`

If tests fail, fix the specific assertion before proceeding.

- [ ] **Step 3: Commit**

```bash
git add seal-the-box/tests/test_run_manager.gd
git commit -m "test: rewrite RunManager tests for charges + rotation system"
```

---

## Task 8: Integration Smoke Test + QA Handoff

- [ ] **Step 1: Run a full Godot import to update any asset references**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --import
```

Expected: completes without errors.

- [ ] **Step 2: Verify the test suite still passes after import**

```
"C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path seal-the-box --script tests/test_run_manager.gd
```

Expected: `All RunManager tests passed!`

- [ ] **Step 3: Provide QA checklist to Caleb**

Present the following checklist for manual playtesting:

**Bugs to verify:**
- [ ] Match starts with slots 1 and 2 empty, slot 3 has one ability (correct text, charges shown)
- [ ] Ability buttons show charges as "Name [N/M]" and slot 1 has a ★ marker with orange tint
- [ ] Using an ability decrements its displayed charges
- [ ] An ability at 0 charges is greyed out and clicking it shows "exhausted" message (does NOT activate)
- [ ] After threshold win, rotation overlay appears (opaque black) with 3 options showing name, description, charges
- [ ] Picking one of the 3 options shifts slots: old slot 1 is gone, old slot 2 → slot 1, old slot 3 → slot 2, pick → slot 3
- [ ] After critical win (shut the box): dice reward overlay appears first, then rotation overlay after picking a die
- [ ] Dev "Win Current Match" triggers the rotation overlay (you must pick before the next match starts)
- [ ] Dev "Win Entire Series" cycles through multiple matches automatically, triggering auto-rotation each time

**Playability questions (feel/design):**
- Does the "use it or lose it" pressure feel real? Do you find yourself burning charges aggressively?
- Does losing a barely-used ability (e.g., reroll_all with 1 charge unspent) feel like a meaningful loss, or arbitrary?
- Does starting with only 1 ability feel too ability-starved in match 1?
- Are the charge counts (reroll=2, empower/weaken=3, reroll_all=1) playable or do you run out immediately?
- Does the slot 1 ★ marker help you remember which ability is "about to leave"?
