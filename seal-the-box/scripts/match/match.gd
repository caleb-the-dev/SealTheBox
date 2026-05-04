extends Node3D

# ── state ──────────────────────────────────────────────────────────────────
var _round_manager: RoundManager
var _run_manager: RunManager
var _selected_dice: Array = []
var _selected_tabs: Array[int] = []
var _selected_ability: AbilityData = null
var _targeting_die: bool = false
var _match_ended: bool = false

# ── ui references ───────────────────────────────────────────────────────────
var _hp_label: Label
var _round_label: Label
var _status_label: Label
var _tab_buttons: Array[Button] = []
var _dice_buttons: Array[Button] = []
var _dice_face_labels: Array[Label] = []
var _ability_buttons: Array[Button] = []
var _action_button: Button
var _roll_hint_label: Label
var _draw_label: Label
var _discard_label: Label
var _current_phase: String = ""
var _match_label: Label
var _box_label: Label
var _threshold_label: Label
var _continue_button: Button
var _sealed_total_label: Label
var _tab_row: HBoxContainer
var _power_offer_overlay: Control
var _power_offer_name_label: Label
var _power_offer_desc_label: Label
var _current_power_offer: PowerData = null
var _run_over_overlay: Control
var _run_over_detail_label: Label
var _rotation_overlay: Control
var _rotation_buttons: Array[Button] = []
var _current_rotation_options: Array = []
var _dev_overlay: Control
var _powers_vbox: VBoxContainer

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
	if not Engine.has_singleton("PowerLibrary"):
		Engine.register_singleton("PowerLibrary", PowerLibrary)
	if not Engine.has_singleton("PowerManager"):
		Engine.register_singleton("PowerManager", PowerManager)
	_round_manager = RoundManager.new()
	add_child(_round_manager)
	_run_manager = RunManager.new()
	add_child(_run_manager)
	_connect_signals()
	_run_manager.start_run()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_on_dev_toggle_pressed()

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

	var thresh_col = VBoxContainer.new()
	thresh_col.custom_minimum_size = Vector2(140, 0)
	thresh_col.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_area.add_child(thresh_col)

	_threshold_label = Label.new()
	_threshold_label.add_theme_font_size_override("font_size", 20)
	_threshold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thresh_col.add_child(_threshold_label)

	_continue_button = Button.new()
	_continue_button.text = "Continue →"
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	thresh_col.add_child(_continue_button)

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

	# ── Bottom: [Dice panel (2/3) + Abilities panel (1/3)] ──────────────────
	var bottom = HBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -288
	bottom.offset_bottom = -20
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)

	const INNER_DARK = Color(0.12, 0.12, 0.12, 0.95)

	var content_panel = _make_rounded_panel(28, DARK, 14, 14)
	content_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(content_panel)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	outer_vbox.custom_minimum_size = Vector2(520, 0)
	content_panel.add_child(outer_vbox)

	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 8)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(main_hbox)

	# Dice panel (left ~2/3) — header with draw/discard counts, dice buttons, roll control
	var dice_panel = _make_rounded_panel(12, INNER_DARK, 10, 8)
	dice_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_panel.size_flags_stretch_ratio = 2.0
	main_hbox.add_child(dice_panel)

	var dice_vbox = VBoxContainer.new()
	dice_vbox.add_theme_constant_override("separation", 6)
	dice_panel.add_child(dice_vbox)

	# Header row: [draw count]  ── DICE HAND ──  [discard count]
	var dice_header = HBoxContainer.new()
	dice_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_vbox.add_child(dice_header)

	_draw_label = Label.new()
	_draw_label.add_theme_font_size_override("font_size", 14)
	_draw_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_draw_label.custom_minimum_size = Vector2(28, 0)
	dice_header.add_child(_draw_label)

	var dice_title_lbl = Label.new()
	dice_title_lbl.text = "── DICE HAND ──"
	dice_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_header.add_child(dice_title_lbl)

	_discard_label = Label.new()
	_discard_label.add_theme_font_size_override("font_size", 14)
	_discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_discard_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_discard_label.custom_minimum_size = Vector2(28, 0)
	dice_header.add_child(_discard_label)

	# Dice buttons
	var dice_row = HBoxContainer.new()
	dice_row.add_theme_constant_override("separation", 8)
	dice_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_vbox.add_child(dice_row)

	for i in 3:
		var btn = Button.new()
		btn.text = "d?"
		btn.custom_minimum_size = Vector2(72, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_die_pressed.bind(i))
		dice_row.add_child(btn)
		_dice_buttons.append(btn)

		var face_lbl = Label.new()
		face_lbl.add_theme_font_size_override("font_size", 11)
		face_lbl.anchor_left = 1.0
		face_lbl.anchor_right = 1.0
		face_lbl.anchor_top = 1.0
		face_lbl.anchor_bottom = 1.0
		face_lbl.offset_left = -34
		face_lbl.offset_right = -4
		face_lbl.offset_top = -18
		face_lbl.offset_bottom = -3
		face_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		face_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		face_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_lbl.visible = false
		btn.add_child(face_lbl)
		_dice_face_labels.append(face_lbl)

	# Roll hint label + single action button (inside dice panel, below dice)
	_roll_hint_label = Label.new()
	_roll_hint_label.text = "Select dice to roll"
	_roll_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roll_hint_label.add_theme_font_size_override("font_size", 13)
	_roll_hint_label.modulate = Color(0.75, 0.75, 0.75)
	dice_vbox.add_child(_roll_hint_label)

	_action_button = Button.new()
	_action_button.text = "Roll Dice (All)"
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.pressed.connect(_on_action_pressed)
	dice_vbox.add_child(_action_button)

	# Abilities panel (right ~1/3)
	var ability_panel = _make_rounded_panel(12, INNER_DARK, 10, 8)
	ability_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_panel.size_flags_stretch_ratio = 1.0
	main_hbox.add_child(ability_panel)

	var ability_vbox = VBoxContainer.new()
	ability_vbox.add_theme_constant_override("separation", 8)
	ability_panel.add_child(ability_vbox)

	var ability_lbl = Label.new()
	ability_lbl.text = "── ABILITIES ──"
	ability_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_vbox.add_child(ability_lbl)

	for i in 3:
		var btn = TooltipButton.new()
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_ability_pressed.bind(i))
		ability_vbox.add_child(btn)
		_ability_buttons.append(btn)

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

	# ── Run-over overlay ───────────────────────────────────────────────────────
	var over_overlay = Control.new()
	over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	over_overlay.visible = false
	var over_bg = ColorRect.new()
	over_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_bg.color = Color(0.0, 0.0, 0.0, 1.0)
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

	# ── Dev toggle button (top-right corner) ──────────────────────────────────
	var dev_toggle = Button.new()
	dev_toggle.text = "DEV"
	dev_toggle.anchor_left = 1.0
	dev_toggle.anchor_right = 1.0
	dev_toggle.anchor_top = 0.0
	dev_toggle.anchor_bottom = 0.0
	dev_toggle.offset_left = -62
	dev_toggle.offset_right = -4
	dev_toggle.offset_top = 10
	dev_toggle.offset_bottom = 42
	dev_toggle.pressed.connect(_on_dev_toggle_pressed)
	root.add_child(dev_toggle)

	# ── Dev overlay ────────────────────────────────────────────────────────────
	var dev_overlay = Control.new()
	dev_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_overlay.visible = false
	var dev_bg = ColorRect.new()
	dev_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_bg.color = Color(0, 0, 0, 1.0)
	dev_overlay.add_child(dev_bg)

	var dev_panel = VBoxContainer.new()
	dev_panel.anchor_left = 0.35
	dev_panel.anchor_right = 0.65
	dev_panel.anchor_top = 0.3
	dev_panel.anchor_bottom = 0.72
	dev_panel.add_theme_constant_override("separation", 14)
	dev_overlay.add_child(dev_panel)

	var dev_title = Label.new()
	dev_title.text = "— DEV MENU —"
	dev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_title.add_theme_font_size_override("font_size", 22)
	dev_panel.add_child(dev_title)

	var dev_win_match_btn = Button.new()
	dev_win_match_btn.text = "Win Current Match"
	dev_win_match_btn.custom_minimum_size = Vector2(0, 56)
	dev_win_match_btn.add_theme_font_size_override("font_size", 17)
	dev_win_match_btn.pressed.connect(_on_dev_win_match_pressed)
	dev_panel.add_child(dev_win_match_btn)

	var dev_win_series_btn = Button.new()
	dev_win_series_btn.text = "Win Entire Series"
	dev_win_series_btn.custom_minimum_size = Vector2(0, 56)
	dev_win_series_btn.add_theme_font_size_override("font_size", 17)
	dev_win_series_btn.pressed.connect(_on_dev_win_series_pressed)
	dev_panel.add_child(dev_win_series_btn)

	var dev_close_btn = Button.new()
	dev_close_btn.text = "Close  [T]"
	dev_close_btn.custom_minimum_size = Vector2(0, 44)
	dev_close_btn.pressed.connect(_on_dev_toggle_pressed)
	dev_panel.add_child(dev_close_btn)

	root.add_child(dev_overlay)
	_dev_overlay = dev_overlay

	# ── Powers side panel (right side, always visible) ────────────────────────
	var powers_panel = _make_rounded_panel(12, Color(0.18, 0.18, 0.18, 0.92), 10, 8)
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

# ── signal wiring ────────────────────────────────────────────────────────────
func _connect_signals() -> void:
	_round_manager.phase_changed.connect(_on_phase_changed)
	_round_manager.round_ended.connect(_on_round_ended)
	_round_manager.match_won.connect(_on_match_won)
	_round_manager.match_lost.connect(_on_match_lost)
	_round_manager.tabs_sealed.connect(_on_tabs_sealed)
	_round_manager.status_updated.connect(_on_status_updated)
	_round_manager.threshold_reached.connect(_on_threshold_reached)
	_run_manager.next_match_ready.connect(_on_next_match_ready)
	_run_manager.show_power_offer.connect(_on_show_power_offer)
	_run_manager.run_over.connect(_on_run_over)
	_run_manager.show_rotation_offer.connect(_on_show_rotation_offer)

# ── signal handlers ──────────────────────────────────────────────────────────
func _on_phase_changed(phase: String) -> void:
	_current_phase = phase
	if phase == "roll":
		_roll_hint_label.visible = true
		_update_roll_button_text()
		_continue_button.disabled = false
	else:
		_roll_hint_label.visible = false
		_action_button.text = "Commit & End Round"
		_continue_button.disabled = true
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
	_continue_button.visible = false
	for btn in _tab_buttons + _dice_buttons + _ability_buttons:
		btn.disabled = true
	_run_manager.handle_match_won(critical)

func _on_match_lost() -> void:
	if _match_ended:
		return
	_match_ended = true
	_action_button.disabled = true
	_continue_button.visible = false
	for btn in _tab_buttons + _dice_buttons + _ability_buttons:
		btn.disabled = true
	_run_manager.handle_match_lost()

func _on_threshold_reached() -> void:
	_continue_button.visible = true
	_continue_button.scale = Vector2.ONE
	_continue_button.modulate = Color.WHITE
	_continue_button.pivot_offset = _continue_button.size / 2.0
	var tween = create_tween()
	tween.tween_property(_continue_button, "scale", Vector2(1.3, 1.3), 0.2)
	tween.parallel().tween_property(_continue_button, "modulate", Color(2.0, 1.8, 0.4), 0.2)
	tween.tween_property(_continue_button, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(_continue_button, "modulate", Color.WHITE, 0.2)

func _on_continue_pressed() -> void:
	_round_manager.accept_threshold_win()

func _on_next_match_ready(box: BoxDefinition) -> void:
	_match_ended = false
	_selected_dice = []
	_selected_tabs = []
	_selected_ability = null
	_targeting_die = false
	_continue_button.visible = false
	_continue_button.scale = Vector2.ONE
	_continue_button.modulate = Color.WHITE
	if _power_offer_overlay:
		_power_offer_overlay.visible = false
	if _run_over_overlay:
		_run_over_overlay.visible = false
	if _rotation_overlay:
		_rotation_overlay.visible = false
	_action_button.disabled = false
	for btn in _dice_buttons + _ability_buttons:
		btn.disabled = false
	_round_manager.start_match(box)
	_rebuild_tab_buttons()
	for btn in _tab_buttons:
		btn.disabled = false
	_refresh_powers_panel()

func _on_run_over(match_number: int) -> void:
	_run_over_detail_label.text = "Defeated on Match %d  |  HP: 0" % match_number
	_run_over_overlay.visible = true

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

func _on_show_rotation_offer(options: Array) -> void:
	_current_rotation_options = options
	for i in min(3, options.size()):
		var a = options[i]
		_rotation_buttons[i].text = "%s\n\n%s\n\n[%d charges]" % [a.flavor_name, a.description, a.max_charges]
	_rotation_overlay.visible = true

func _on_rotation_pick_pressed(index: int) -> void:
	_rotation_overlay.visible = false
	_run_manager.handle_rotation_pick(_current_rotation_options[index])

func _on_dev_toggle_pressed() -> void:
	_dev_overlay.visible = not _dev_overlay.visible

func _on_dev_win_match_pressed() -> void:
	_dev_overlay.visible = false
	if not _match_ended:
		_round_manager.dev_win_match()

func _on_dev_win_series_pressed() -> void:
	_dev_overlay.visible = false
	var safety := 0
	while not _match_ended and safety < 10:
		safety += 1
		_round_manager.dev_win_match()
		_run_manager.dev_skip_rotation()

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
	_update_roll_button_text()

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
		var to_roll = _selected_dice.filter(func(d): return not d.rolled)
		if to_roll.is_empty():
			to_roll = GameState.dice_hand.filter(func(d): return not d.rolled)
		if to_roll.is_empty():
			_status_label.text = "All dice are already rolled."
			return
		_round_manager.commit_roll(to_roll)
		_selected_dice = []
	else:
		_on_end_round_pressed()

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
	_round_label.text = "Round: %d / %d" % [GameState.round, GameState.round_limit]
	_match_label.text = "Match: %d" % _run_manager.match_number
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
	var draw_count := _round_manager.get_draw_count()
	var discard_count := _round_manager.get_discard_count()
	_draw_label.text = str(draw_count)
	_draw_label.tooltip_text = "Draw pile: %d remaining" % draw_count
	_discard_label.text = str(discard_count)
	_discard_label.tooltip_text = "Discard pile: %d remaining" % discard_count
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
		var face_lbl = _dice_face_labels[i] if i < _dice_face_labels.size() else null
		if i < hand.size():
			var die = hand[i]
			btn.text = str(die.value) if die.rolled else "d%d" % die.faces
			btn.disabled = false
			if face_lbl:
				if die.rolled:
					face_lbl.text = "d%d" % die.faces
					face_lbl.visible = true
				else:
					face_lbl.visible = false
		else:
			btn.text = "—"
			btn.disabled = true
			if face_lbl:
				face_lbl.visible = false

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
		var a = hand[i] if i < hand.size() else null
		if a != null:
			var name_text = a.flavor_name
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
	_refresh_ability_display()

func _update_roll_button_text() -> void:
	if _current_phase != "roll":
		return
	var unrolled_selected = _selected_dice.filter(func(d): return not d.rolled)
	if unrolled_selected.is_empty():
		_action_button.text = "Roll Dice (All)"
	else:
		_action_button.text = "Roll Dice (%d)" % unrolled_selected.size()
