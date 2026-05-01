extends Node3D

# ── state ──────────────────────────────────────────────────────────────────
var _round_manager: RoundManager
var _selected_dice: Array = []
var _selected_ability: AbilityData = null
var _targeting_die: bool = false

# ── ui references ───────────────────────────────────────────────────────────
var _hp_label: Label
var _ap_label: Label
var _round_label: Label
var _status_label: Label
var _tab_buttons: Array[Button] = []
var _dice_buttons: Array[Button] = []
var _ability_buttons: Array[Button] = []
var _roll_button: Button
var _end_round_button: Button

# ── lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_3d()
	_setup_ui()
	_round_manager = RoundManager.new()
	add_child(_round_manager)
	_connect_signals()
	_round_manager.start_match()

# ── 3D environment ──────────────────────────────────────────────────────────
func _setup_3d() -> void:
	var cam = Camera3D.new()
	cam.position = Vector3(0, 5, 8)
	cam.rotation_degrees = Vector3(-25, 0, 0)
	add_child(cam)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)

	var table = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(12, 10)
	table.mesh = mesh
	add_child(table)

# ── UI construction ─────────────────────────────────────────────────────────
func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	canvas.add_child(vbox)

	# Top bar: HP | Round | AP
	var top = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 30)
	vbox.add_child(top)

	_hp_label = Label.new()
	top.add_child(_hp_label)
	_round_label = Label.new()
	top.add_child(_round_label)
	_ap_label = Label.new()
	top.add_child(_ap_label)

	# Tab board
	_add_section_label(vbox, "── TABS ──")
	var tab_row = HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tab_row)

	for i in range(1, 10):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(52, 52)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_row.add_child(btn)
		_tab_buttons.append(btn)

	# Dice hand
	_add_section_label(vbox, "── DICE HAND ──")
	var dice_row = HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 10)
	vbox.add_child(dice_row)

	for i in 3:
		var btn = Button.new()
		btn.text = "d?"
		btn.custom_minimum_size = Vector2(64, 64)
		btn.pressed.connect(_on_die_pressed.bind(i))
		dice_row.add_child(btn)
		_dice_buttons.append(btn)

	_roll_button = Button.new()
	_roll_button.text = "Roll Selected  (1 AP each)"
	_roll_button.pressed.connect(_on_roll_pressed)
	vbox.add_child(_roll_button)

	# Ability hand
	_add_section_label(vbox, "── ABILITIES ──")
	var ability_row = HBoxContainer.new()
	ability_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ability_row.add_theme_constant_override("separation", 10)
	vbox.add_child(ability_row)

	for i in 3:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 52)
		btn.pressed.connect(_on_ability_pressed.bind(i))
		ability_row.add_child(btn)
		_ability_buttons.append(btn)

	# End round + status
	_end_round_button = Button.new()
	_end_round_button.text = "End Round"
	_end_round_button.pressed.connect(_on_end_round_pressed)
	vbox.add_child(_end_round_button)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(_status_label)

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)

# ── signal wiring ────────────────────────────────────────────────────────────
func _connect_signals() -> void:
	_round_manager.phase_changed.connect(_on_phase_changed)
	_round_manager.round_ended.connect(_on_round_ended)
	_round_manager.match_won.connect(_on_match_won)
	_round_manager.match_lost.connect(_on_match_lost)
	_round_manager.tab_sealed.connect(_on_tab_sealed)
	_round_manager.status_updated.connect(_on_status_updated)

# ── signal handlers ──────────────────────────────────────────────────────────
func _on_phase_changed(phase: String) -> void:
	_roll_button.disabled = (phase != "roll")
	_end_round_button.disabled = (phase == "roll")
	_refresh_ui()

func _on_round_ended(_round_num: int) -> void:
	_selected_dice = []
	_selected_ability = null
	_targeting_die = false
	_refresh_ui()

func _on_match_won(critical: bool) -> void:
	var msg = "SHUT THE BOX!\nCritical Win!" if critical else "Match Won!\nSum dropped below threshold."
	_show_end_dialog(msg)

func _on_match_lost() -> void:
	_show_end_dialog("Match Lost\nHP reached 0.")

func _on_tab_sealed(value: int) -> void:
	var btn = _tab_buttons[value - 1]
	btn.disabled = true
	btn.modulate = Color(0.4, 0.4, 0.4)
	_selected_dice = []
	_refresh_dice_highlight()
	_refresh_ui()

func _on_status_updated(text: String) -> void:
	_status_label.text = text

# ── input handlers ───────────────────────────────────────────────────────────
func _on_die_pressed(index: int) -> void:
	var hand = GameState.dice_hand
	if index >= hand.size():
		return
	var die = hand[index]

	if _targeting_die and _selected_ability != null:
		_round_manager.use_ability(_selected_ability, die)
		_selected_ability = null
		_targeting_die = false
		_refresh_ui()
		return

	if die in _selected_dice:
		_selected_dice.erase(die)
	else:
		_selected_dice.append(die)
	_refresh_dice_highlight()
	_update_sum_status()

func _on_tab_pressed(tab_value: int) -> void:
	var rolled = _selected_dice.filter(func(d): return d.rolled)
	if rolled.is_empty():
		_status_label.text = "Select rolled dice first, then a tab to seal."
		return
	if not _round_manager.attempt_seal(rolled, tab_value):
		var sum = 0
		for d in rolled:
			sum += d.value
		_status_label.text = "Can't seal tab %d with sum %d." % [tab_value, sum]

func _on_roll_pressed() -> void:
	var to_roll = _selected_dice.filter(func(d): return not d.rolled)
	if to_roll.is_empty():
		_status_label.text = "Select unrolled dice to roll."
		return
	_round_manager.commit_roll(to_roll)
	_selected_dice = []

func _on_ability_pressed(index: int) -> void:
	if index >= GameState.ability_hand.size():
		return
	var ability = GameState.ability_hand[index]
	if GameState.ap < ability.ap_cost:
		_status_label.text = "Not enough AP for %s." % ability.flavor_name
		return
	_selected_ability = ability
	_targeting_die = true
	_status_label.text = "%s — click a die to target it." % ability.description

func _on_end_round_pressed() -> void:
	_selected_dice = []
	_selected_ability = null
	_targeting_die = false
	_round_manager.end_round()

# ── ui refresh ───────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
	_hp_label.text = "HP: %d" % GameState.hp
	_ap_label.text = "AP: %d" % GameState.ap
	_round_label.text = "Round: %d / %d" % [GameState.round, GameState.round_limit]
	_refresh_dice_display()
	_refresh_ability_display()

func _refresh_dice_display() -> void:
	var hand = GameState.dice_hand
	for i in 3:
		var btn = _dice_buttons[i]
		if i < hand.size():
			var die = hand[i]
			btn.text = str(die.value) if die.rolled else "d%d" % die.faces
			btn.disabled = false
		else:
			btn.text = "—"
			btn.disabled = true

func _refresh_dice_highlight() -> void:
	var hand = GameState.dice_hand
	for i in hand.size():
		if i < _dice_buttons.size():
			_dice_buttons[i].modulate = Color(1.5, 1.5, 0.3) if hand[i] in _selected_dice else Color.WHITE

func _refresh_ability_display() -> void:
	var hand = GameState.ability_hand
	for i in 3:
		var btn = _ability_buttons[i]
		if i < hand.size():
			var a = hand[i]
			btn.text = "%s\n%d AP" % [a.flavor_name, a.ap_cost]
			btn.disabled = (GameState.ap < a.ap_cost)
		else:
			btn.text = "—"
			btn.disabled = true

func _update_sum_status() -> void:
	var rolled_selected = _selected_dice.filter(func(d): return d.rolled)
	if rolled_selected.is_empty():
		return
	var total = 0
	for d in rolled_selected:
		total += d.value
	_status_label.text = "Selected dice sum: %d" % total

func _show_end_dialog(message: String) -> void:
	_end_round_button.disabled = true
	_roll_button.disabled = true
	for btn in _tab_buttons + _dice_buttons + _ability_buttons:
		btn.disabled = true
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Match Over"
	add_child(dialog)
	dialog.popup_centered()
