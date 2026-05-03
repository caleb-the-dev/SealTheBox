extends Node3D

# ── state ──────────────────────────────────────────────────────────────────
var _round_manager: RoundManager
var _run_manager: RunManager
var _selected_dice: Array = []
var _selected_tabs: Array[int] = []
var _selected_ability: AbilityData = null
var _targeting_die: bool = false
var _match_ended: bool = false
var _current_reward_faces: Array = []

# ── ui references ───────────────────────────────────────────────────────────
var _hp_label: Label
var _ap_label: Label
var _round_label: Label
var _status_label: Label
var _tab_buttons: Array[Button] = []
var _dice_buttons: Array[Button] = []
var _ability_buttons: Array[Button] = []
var _action_button: Button
var _roll_all_button: Button
var _draw_label: Label
var _discard_label: Label
var _current_phase: String = ""
var _match_label: Label
var _box_label: Label
var _threshold_label: Label
var _sealed_total_label: Label
var _tab_row: HBoxContainer
var _reward_overlay: Control
var _reward_title_label: Label
var _reward_buttons: Array[Button] = []
var _run_win_overlay: Control
var _run_win_detail_label: Label
var _run_over_overlay: Control
var _run_over_detail_label: Label

# ── lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_3d()
	_setup_ui()
	if not Engine.has_singleton("AbilityLibrary"):
		Engine.register_singleton("AbilityLibrary", AbilityLibrary)
	if not Engine.has_singleton("GameState"):
		Engine.register_singleton("GameState", GameState)
	if not Engine.has_singleton("BoxLibrary"):
		Engine.register_singleton("BoxLibrary", BoxLibrary)
	_round_manager = RoundManager.new()
	add_child(_round_manager)
	_run_manager = RunManager.new()
	add_child(_run_manager)
	_connect_signals()
	_run_manager.start_run()

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
func _make_rounded_panel(corner: int, color: Color, pad_h: int, pad_v: int) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	style.content_margin_left = pad_h
	style.content_margin_right = pad_h
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	const DARK = Color(0.18, 0.18, 0.18, 0.92)

	# ── Top center: Round + HP side by side ────────────────────────────────
	var top_bar = HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_top = 10
	top_bar.offset_bottom = 52
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 24)
	root.add_child(top_bar)

	_round_label = Label.new()
	top_bar.add_child(_round_label)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 28)
	top_bar.add_child(_hp_label)

	_match_label = Label.new()
	_match_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(_match_label)

	_box_label = Label.new()
	_box_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_box_label)

	# ── Tabs — full width, below top bar ───────────────────────────────────
	var tabs_vbox = VBoxContainer.new()
	tabs_vbox.anchor_left = 0.0
	tabs_vbox.anchor_right = 1.0
	tabs_vbox.anchor_top = 0.0
	tabs_vbox.anchor_bottom = 0.0
	tabs_vbox.offset_top = 70
	tabs_vbox.offset_bottom = 210
	tabs_vbox.add_theme_constant_override("separation", 6)
	root.add_child(tabs_vbox)

	var tabs_lbl = Label.new()
	tabs_lbl.text = "── TABS ──"
	tabs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tabs_vbox.add_child(tabs_lbl)

	var tab_area = HBoxContainer.new()
	tab_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_area.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_vbox.add_child(tab_area)

	_sealed_total_label = Label.new()
	_sealed_total_label.add_theme_font_size_override("font_size", 20)
	_sealed_total_label.custom_minimum_size = Vector2(110, 0)
	_sealed_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sealed_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_area.add_child(_sealed_total_label)

	_tab_row = HBoxContainer.new()
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row.add_theme_constant_override("separation", 8)
	_tab_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_area.add_child(_tab_row)

	_threshold_label = Label.new()
	_threshold_label.add_theme_font_size_override("font_size", 20)
	_threshold_label.custom_minimum_size = Vector2(110, 0)
	_threshold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_threshold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_area.add_child(_threshold_label)

	# ── Status / rolled total ───────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.anchor_left = 0.0
	_status_label.anchor_right = 1.0
	_status_label.anchor_top = 0.0
	_status_label.anchor_bottom = 0.0
	_status_label.offset_top = 218
	_status_label.offset_bottom = 290
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_status_label)

	# ── AP badge — centered circle, between status and table ────────────────
	var ap_row = HBoxContainer.new()
	ap_row.anchor_left = 0.0
	ap_row.anchor_right = 1.0
	ap_row.anchor_top = 1.0
	ap_row.anchor_bottom = 1.0
	ap_row.offset_top = -335
	ap_row.offset_bottom = -290
	ap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(ap_row)

	var ap_panel = _make_rounded_panel(50, DARK, 20, 8)
	ap_row.add_child(ap_panel)
	_ap_label = Label.new()
	_ap_label.add_theme_font_size_override("font_size", 16)
	_ap_label.custom_minimum_size = Vector2(60, 0)
	_ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_panel.add_child(_ap_label)

	# ── Bottom: [DRAW circle] [Dice + Abilities oval] [DISCARD circle] ──────
	var bottom = HBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -288
	bottom.offset_bottom = -20
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	root.add_child(bottom)

	# Draw pile circle
	var draw_panel = _make_rounded_panel(50, DARK, 14, 12)
	bottom.add_child(draw_panel)
	var draw_col = VBoxContainer.new()
	draw_col.add_theme_constant_override("separation", 2)
	draw_col.custom_minimum_size = Vector2(64, 0)
	draw_panel.add_child(draw_col)
	var draw_title = Label.new()
	draw_title.text = "DRAW"
	draw_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_col.add_child(draw_title)
	_draw_label = Label.new()
	_draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_draw_label.add_theme_font_size_override("font_size", 28)
	draw_col.add_child(_draw_label)

	# Dice + Abilities inside a shared oval panel
	var content_panel = _make_rounded_panel(28, DARK, 14, 14)
	content_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(content_panel)

	# Outer vbox so the action button can span the full panel width
	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	outer_vbox.custom_minimum_size = Vector2(520, 0)
	content_panel.add_child(outer_vbox)

	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 12)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)

	# Dice column — takes the majority of horizontal space
	var dice_col = VBoxContainer.new()
	dice_col.add_theme_constant_override("separation", 8)
	dice_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_col.size_flags_stretch_ratio = 2.0
	content_hbox.add_child(dice_col)

	var dice_lbl = Label.new()
	dice_lbl.text = "── DICE HAND ──"
	dice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_col.add_child(dice_lbl)

	var dice_row = HBoxContainer.new()
	dice_row.add_theme_constant_override("separation", 8)
	dice_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_col.add_child(dice_row)

	for i in 3:
		var btn = Button.new()
		btn.text = "d?"
		btn.custom_minimum_size = Vector2(72, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_die_pressed.bind(i))
		dice_row.add_child(btn)
		_dice_buttons.append(btn)

	# Abilities column — narrower, right of dice
	var ability_col = VBoxContainer.new()
	ability_col.add_theme_constant_override("separation", 8)
	ability_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_col.size_flags_stretch_ratio = 1.0
	content_hbox.add_child(ability_col)

	var ability_lbl = Label.new()
	ability_lbl.text = "── ABILITIES ──"
	ability_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_col.add_child(ability_lbl)

	for i in 3:
		var btn = TooltipButton.new()
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_ability_pressed.bind(i))
		ability_col.add_child(btn)
		_ability_buttons.append(btn)

	# Bottom button row — spans full width
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(btn_row)

	_roll_all_button = Button.new()
	_roll_all_button.text = "Roll All"
	_roll_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_all_button.pressed.connect(_on_roll_all_pressed)
	btn_row.add_child(_roll_all_button)

	_action_button = Button.new()
	_action_button.text = "Roll Selected  (1 AP each)"
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.pressed.connect(_on_action_pressed)
	btn_row.add_child(_action_button)

	# Discard pile circle
	var discard_panel = _make_rounded_panel(50, DARK, 14, 12)
	bottom.add_child(discard_panel)
	var discard_col = VBoxContainer.new()
	discard_col.add_theme_constant_override("separation", 2)
	discard_col.custom_minimum_size = Vector2(64, 0)
	discard_panel.add_child(discard_col)
	var discard_title = Label.new()
	discard_title.text = "DISCARD"
	discard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_col.add_child(discard_title)
	_discard_label = Label.new()
	_discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_label.add_theme_font_size_override("font_size", 28)
	discard_col.add_child(_discard_label)

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

# ── signal wiring ────────────────────────────────────────────────────────────
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

# ── signal handlers ──────────────────────────────────────────────────────────
func _on_phase_changed(phase: String) -> void:
	_current_phase = phase
	if phase == "roll":
		_action_button.text = "Roll Selected  (1 AP each)"
		_roll_all_button.disabled = false
	else:
		_action_button.text = "Commit & End Round"
		_roll_all_button.disabled = true
	_refresh_ui()

func _on_round_ended(_round_num: int) -> void:
	_selected_dice = []
	_selected_tabs = []
	_selected_ability = null
	_targeting_die = false
	_refresh_ui()

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

func _on_next_match_ready(box: BoxDefinition) -> void:
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
	for btn in _dice_buttons + _ability_buttons:
		btn.disabled = false
	_round_manager.start_match(box)
	_rebuild_tab_buttons()
	for btn in _tab_buttons:
		btn.disabled = false

func _on_show_reward(dice_faces: Array) -> void:
	_current_reward_faces = dice_faces
	_reward_title_label.text = "Match %d Complete — Pick a Reward Die" % _run_manager.match_number
	for i in 3:
		_reward_buttons[i].text = "d%d" % dice_faces[i]
	_reward_overlay.visible = true

func _on_reward_die_picked(index: int) -> void:
	_reward_overlay.visible = false
	_run_manager.handle_reward_picked(_current_reward_faces[index])

func _on_run_won(match_number: int, hp: int) -> void:
	_run_win_detail_label.text = "Match: %d / %d  |  Final HP: %d" % [match_number, RunManager.RUN_LENGTH, hp]
	_run_win_overlay.visible = true

func _on_run_over(match_number: int) -> void:
	_run_over_detail_label.text = "Defeated on Match: %d / %d  |  HP: 0" % [match_number, RunManager.RUN_LENGTH]
	_run_over_overlay.visible = true

func _on_play_again_pressed() -> void:
	_run_manager.start_run()

func _on_tabs_sealed(_tabs: Array) -> void:
	_selected_tabs = []
	_selected_dice = []
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
		var used_ability = _selected_ability
		var used_idx = GameState.ability_hand.find(used_ability)
		_round_manager.use_ability(used_ability, die)
		_selected_ability = null
		_targeting_die = false
		_refresh_ui()
		if used_idx >= 0 and used_idx < _ability_buttons.size():
			_flash_ability_used(used_idx)
		return

	if die.rolled:
		_update_rolled_total()
		return

	if die in _selected_dice:
		_selected_dice.erase(die)
	else:
		_selected_dice.append(die)
	_refresh_dice_highlight()

func _on_tab_pressed(tab_value: int) -> void:
	var rolled = GameState.dice_hand.filter(func(d): return d.rolled)
	if rolled.is_empty():
		_status_label.text = "Roll your dice first, then click tabs that sum to your total."
		return

	var rolled_total := 0
	for d in rolled:
		rolled_total += d.value

	if tab_value in _selected_tabs:
		_selected_tabs.erase(tab_value)
	else:
		_selected_tabs.append(tab_value)

	var tab_sum := 0
	for t in _selected_tabs:
		tab_sum += t

	if tab_sum > rolled_total:
		_selected_tabs.erase(tab_value)
		tab_sum -= tab_value
		_status_label.text = "Tab %d would exceed rolled total %d (currently at %d)." % [tab_value, rolled_total, tab_sum]
	elif tab_sum == rolled_total and not _selected_tabs.is_empty():
		_status_label.text = "Tabs selected: %d / %d — press Commit & End Round to seal!" % [tab_sum, rolled_total]
	else:
		_status_label.text = "Tabs selected: %d / %d — keep adding or press Commit & End Round." % [tab_sum, rolled_total]

	_refresh_tab_display()

func _on_action_pressed() -> void:
	if _current_phase == "roll":
		_on_roll_pressed()
	else:
		_on_end_round_pressed()

func _on_roll_all_pressed() -> void:
	var to_roll = GameState.dice_hand.filter(func(d): return not d.rolled)
	if to_roll.is_empty():
		_status_label.text = "All dice are already rolled."
		return
	_round_manager.commit_roll(to_roll)
	_selected_dice = []

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
	_selected_ability = ability
	_targeting_die = true
	_status_label.text = "%s — click a die to target it." % ability.description

func _on_end_round_pressed() -> void:
	var rolled = GameState.dice_hand.filter(func(d): return d.rolled)
	if not _selected_tabs.is_empty() and not rolled.is_empty():
		var rolled_total := 0
		for d in rolled:
			rolled_total += d.value
		var tab_sum := 0
		for t in _selected_tabs:
			tab_sum += t
		if tab_sum != rolled_total:
			_status_label.text = "Selected tabs sum to %d but rolled total is %d — adjust your selection." % [tab_sum, rolled_total]
			return
		var match_before := _run_manager.match_number
		if not _round_manager.attempt_seal(rolled, _selected_tabs.duplicate()):
			_status_label.text = "Can't seal — invalid combination."
			_selected_tabs = []
			_refresh_tab_display()
			return
		# attempt_seal fires match_won synchronously, which may start the next match
		# before we return here — skip end_round() in that case
		if _run_manager.match_number != match_before or _match_ended:
			return
	_selected_dice = []
	_selected_ability = null
	_targeting_die = false
	_round_manager.end_round()

# ── ui refresh ───────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
	_hp_label.text = "❤  %d" % GameState.hp
	_ap_label.text = "AP: %d" % GameState.ap
	_round_label.text = "Round: %d / %d" % [GameState.round, GameState.round_limit]
	_match_label.text = "Match: %d / %d" % [_run_manager.match_number, RunManager.RUN_LENGTH]
	if GameState.current_box:
		_box_label.text = "Box: %s" % GameState.current_box.name
		var remaining_sum := 0
		for t in GameState.tabs:
			remaining_sum += t
		_sealed_total_label.text = "%d left" % remaining_sum
		_threshold_label.text = "≤%d to win" % GameState.win_threshold
	else:
		_box_label.text = ""
		_sealed_total_label.text = ""
		_threshold_label.text = ""
	_draw_label.text = str(_round_manager.get_draw_count())
	_discard_label.text = str(_round_manager.get_discard_count())
	_refresh_tab_display()
	_refresh_dice_display()
	_refresh_dice_highlight()
	_refresh_ability_display()

func _rebuild_tab_buttons() -> void:
	for child in _tab_row.get_children():
		child.queue_free()
	_tab_buttons.clear()
	for tab_val in GameState.tabs:
		var btn = Button.new()
		btn.text = str(tab_val)
		btn.custom_minimum_size = Vector2(62, 88)
		btn.pressed.connect(_on_tab_pressed.bind(tab_val))
		_tab_row.add_child(btn)
		_tab_buttons.append(btn)

func _refresh_tab_display() -> void:
	var remaining = GameState.tabs
	for btn in _tab_buttons:
		var tab_val = btn.text.to_int()
		var sealed = not (tab_val in remaining)
		if sealed:
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4)
		elif tab_val in _selected_tabs:
			btn.disabled = false
			btn.modulate = Color(1.5, 1.5, 0.3)
		else:
			btn.disabled = false
			btn.modulate = Color.WHITE

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
	var any_rolled = hand.any(func(d): return d.rolled)
	for i in hand.size():
		if i < _dice_buttons.size():
			var die = hand[i]
			if any_rolled and not die.rolled:
				_dice_buttons[i].modulate = Color(0.4, 0.4, 0.4)
			elif die in _selected_dice:
				_dice_buttons[i].modulate = Color(1.5, 1.5, 0.3)
			else:
				_dice_buttons[i].modulate = Color.WHITE

func _refresh_ability_display() -> void:
	var hand = GameState.ability_hand
	for i in 3:
		var btn = _ability_buttons[i]
		if i < hand.size():
			var a = hand[i]
			if btn is TooltipButton:
				(btn as TooltipButton).update_info(a.flavor_name, a.description)
			btn.disabled = false
		else:
			if btn is TooltipButton:
				(btn as TooltipButton).clear_info()
			else:
				btn.text = "—"
			btn.disabled = true

func _update_rolled_total() -> void:
	var total = 0
	for d in GameState.dice_hand:
		if d.rolled:
			total += d.value
	_status_label.text = "Rolled total: %d — click a tab to seal." % total

func _flash_ability_used(idx: int) -> void:
	var btn = _ability_buttons[idx]
	btn.modulate = Color(0.3, 1.2, 0.3)
	await get_tree().create_timer(0.35).timeout
	btn.modulate = Color.WHITE
