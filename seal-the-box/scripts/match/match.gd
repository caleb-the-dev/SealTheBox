extends Node3D

# ── state ──────────────────────────────────────────────────────────────────
var _round_manager: RoundManager
var _run_manager: RunManager
var _selected_dice: Array = []
var _selected_tabs: Array[int] = []      # stores button indices, not values
var _sealed_button_indices: Array[int] = []  # which tab buttons are sealed this match
var _bhv_rebuilt_since_select: bool = false  # true when BHV triggered a full rebuild before tabs_sealed fires
var _selected_ability: AbilityData = null
var _targeting_die: bool = false
var _match_ended: bool = false

# ── ui references ───────────────────────────────────────────────────────────
var _hp_label: Label
var _hp_max_label: Label
var _hp_tween: Tween = null
var _status_label: Label
var _tab_buttons: Array[Button] = []
var _dice_buttons: Array[Button] = []
var _dice_face_labels: Array[Label] = []
var _dice_mod_labels: Array[Label] = []
var _ability_buttons: Array[Button] = []
var _action_button: Button
var _roll_hint_label: Label
var _draw_label: Label
var _discard_label: Label
var _current_phase: String = ""
var _match_label: Label
var _act_label: Label
var _tier_label: Label
var _box_name_label: Label
var _box_mod_hint: Label
var _mod_hint_time: float = 0.0
var _mod_tooltip: PanelContainer
var _mod_tooltip_label: Label
var _run_won_overlay: Control
var _run_won_title_label: Label
var _dev_box_label: Label
var _threshold_label: Label
var _continue_button: Button
var _sealed_total_label: Label
var _tab_row: HBoxContainer
var _tabs_header: HBoxContainer
var _thresh_col: VBoxContainer
var _power_offer_overlay: Control
var _power_offer_cards: Array[Button] = []
var _power_offer_confirm_btn: Button
var _power_offer_options: Array = []
var _current_power_offer: PowerData = null
var _heal_notice_label: Label
var _run_over_overlay: Control
var _run_over_detail_label: Label
var _rotation_overlay: Control
var _rotation_buttons: Array[Button] = []
var _current_rotation_options: Array = []
var _dev_overlay: Control
var _dev_power_overlay: Control
var _dev_power_list: VBoxContainer
var _dev_ability_overlay: Control
var _dev_ability_list: VBoxContainer
var _dev_goto_match_overlay: Control
var _dev_goto_box_overlay: Control
var _dev_goto_box_list: VBoxContainer
var _powers_vbox: VBoxContainer
var _die_swap_overlay: Control
var _crossroads_overlay: Control
var _die_swap_offered_buttons: Array[Button] = []
var _die_swap_pool_row: HBoxContainer
var _die_swap_pool_buttons: Array[Button] = []
var _die_swap_confirm_btn: Button
var _die_swap_offered_dice: Array = []
var _selected_swap_offered_idx: int = -1
var _selected_swap_pool_die = null
var _selected_swap_pool_idx: int = -1
var _dev_die_swap_mode: bool = false
var _dev_force_round_overlay: Control

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
	if not Engine.has_singleton("CaseManager"):
		Engine.register_singleton("CaseManager", CaseManager)
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

	# ── Top bar: HP centered, Match top-left ───────────────────────────────
	var top_bar = HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_top = 10
	top_bar.offset_bottom = 52
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top_bar)

	var hp_container = HBoxContainer.new()
	hp_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_container.add_theme_constant_override("separation", 1)
	top_bar.add_child(hp_container)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 28)
	hp_container.add_child(_hp_label)

	_hp_max_label = Label.new()
	_hp_max_label.add_theme_font_size_override("font_size", 16)
	_hp_max_label.modulate = Color(0.6, 0.6, 0.6)
	_hp_max_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hp_container.add_child(_hp_max_label)

	var top_left_vbox = VBoxContainer.new()
	top_left_vbox.anchor_left = 0.0
	top_left_vbox.anchor_right = 0.0
	top_left_vbox.anchor_top = 0.0
	top_left_vbox.anchor_bottom = 0.0
	top_left_vbox.offset_left = 8
	top_left_vbox.offset_right = 240
	top_left_vbox.offset_top = 8
	top_left_vbox.offset_bottom = 120
	top_left_vbox.add_theme_constant_override("separation", 2)
	root.add_child(top_left_vbox)

	# Row 1: Box name (prominent) + modifier badge
	var box_name_row = HBoxContainer.new()
	box_name_row.add_theme_constant_override("separation", 6)
	top_left_vbox.add_child(box_name_row)

	_box_name_label = Label.new()
	_box_name_label.add_theme_font_size_override("font_size", 22)
	box_name_row.add_child(_box_name_label)

	_box_mod_hint = Label.new()
	_box_mod_hint.add_theme_font_size_override("font_size", 18)
	_box_mod_hint.text = "[!]"
	_box_mod_hint.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1))
	_box_mod_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_box_mod_hint.visible = false
	_box_mod_hint.mouse_entered.connect(_on_mod_hint_entered)
	_box_mod_hint.mouse_exited.connect(_on_mod_hint_exited)
	box_name_row.add_child(_box_mod_hint)

	# Row 2: Difficulty (small, muted)
	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", 12)
	_tier_label.modulate = Color(0.6, 0.6, 0.6)
	top_left_vbox.add_child(_tier_label)

	# Row 3: Match number (medium)
	_match_label = Label.new()
	_match_label.add_theme_font_size_override("font_size", 16)
	top_left_vbox.add_child(_match_label)

	# Row 4: Act (small, muted)
	_act_label = Label.new()
	_act_label.add_theme_font_size_override("font_size", 12)
	_act_label.modulate = Color(0.6, 0.6, 0.6)
	top_left_vbox.add_child(_act_label)

	# Floating tooltip for the modifier badge — shown on hover, not via built-in tooltip
	_mod_tooltip = PanelContainer.new()
	_mod_tooltip.anchor_left = 0.0
	_mod_tooltip.anchor_top = 0.0
	_mod_tooltip.offset_left = 8
	_mod_tooltip.offset_top = 130
	_mod_tooltip.custom_minimum_size = Vector2(250, 0)
	_mod_tooltip.visible = false
	root.add_child(_mod_tooltip)

	var tip_margin = MarginContainer.new()
	tip_margin.add_theme_constant_override("margin_left", 10)
	tip_margin.add_theme_constant_override("margin_right", 10)
	tip_margin.add_theme_constant_override("margin_top", 6)
	tip_margin.add_theme_constant_override("margin_bottom", 6)
	_mod_tooltip.add_child(tip_margin)

	_mod_tooltip_label = Label.new()
	_mod_tooltip_label.add_theme_font_size_override("font_size", 12)
	_mod_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_margin.add_child(_mod_tooltip_label)

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

	# Header row: [x left]  ── TABS ──  [≤y to win]
	# Width is matched to _tab_row dynamically in _update_tabs_header_widths().
	var tabs_header = HBoxContainer.new()
	tabs_header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tabs_header.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_header.add_theme_constant_override("separation", 8)
	tabs_vbox.add_child(tabs_header)
	_tabs_header = tabs_header

	_sealed_total_label = Label.new()
	_sealed_total_label.add_theme_font_size_override("font_size", 20)
	_sealed_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs_header.add_child(_sealed_total_label)

	var tabs_lbl = Label.new()
	tabs_lbl.text = "── TABS ──"
	tabs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tabs_bold = FontVariation.new()
	tabs_bold.variation_embolden = 1.0
	tabs_lbl.add_theme_font_override("font", tabs_bold)
	tabs_lbl.add_theme_font_size_override("font_size", 20)
	tabs_header.add_child(tabs_lbl)

	var thresh_col = VBoxContainer.new()
	thresh_col.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_header.add_child(thresh_col)
	_thresh_col = thresh_col

	_threshold_label = Label.new()
	_threshold_label.add_theme_font_size_override("font_size", 20)
	_threshold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	thresh_col.add_child(_threshold_label)


	# Tab buttons row (centered, no flanking labels)
	var tab_area = HBoxContainer.new()
	tab_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_area.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_vbox.add_child(tab_area)

	_tab_row = HBoxContainer.new()
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row.add_theme_constant_override("separation", 8)
	_tab_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_area.add_child(_tab_row)

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

		# Bottom-left modifier tag (e.g. "×2" for high_die_doubles, "+N" for exploding_ones)
		var mod_lbl = Label.new()
		mod_lbl.add_theme_font_size_override("font_size", 11)
		mod_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1))
		mod_lbl.anchor_left = 0.0
		mod_lbl.anchor_right = 0.0
		mod_lbl.anchor_top = 1.0
		mod_lbl.anchor_bottom = 1.0
		mod_lbl.offset_left = 4
		mod_lbl.offset_right = 36
		mod_lbl.offset_top = -18
		mod_lbl.offset_bottom = -3
		mod_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		mod_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		mod_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mod_lbl.visible = false
		btn.add_child(mod_lbl)
		_dice_mod_labels.append(mod_lbl)

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

	# ── Continue button — centered above dice panel ─────────────────────────────
	_continue_button = Button.new()
	_continue_button.text = "Continue →"
	_continue_button.visible = false
	_continue_button.anchor_left = 0.5
	_continue_button.anchor_right = 0.5
	_continue_button.anchor_top = 1.0
	_continue_button.anchor_bottom = 1.0
	_continue_button.offset_left = -80
	_continue_button.offset_right = 80
	_continue_button.offset_top = -330
	_continue_button.offset_bottom = -286
	_continue_button.add_theme_font_size_override("font_size", 18)
	_continue_button.pressed.connect(_on_continue_pressed)
	root.add_child(_continue_button)

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

	_heal_notice_label = Label.new()
	_heal_notice_label.text = "Healed 1 HP!"
	_heal_notice_label.add_theme_font_size_override("font_size", 18)
	_heal_notice_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_heal_notice_label.anchor_left = 0.0
	_heal_notice_label.anchor_right = 0.0
	_heal_notice_label.anchor_top = 1.0
	_heal_notice_label.anchor_bottom = 1.0
	_heal_notice_label.offset_left = 24
	_heal_notice_label.offset_right = 200
	_heal_notice_label.offset_top = -52
	_heal_notice_label.offset_bottom = -24
	power_overlay.add_child(_heal_notice_label)

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
	dev_panel.anchor_left = 0.3
	dev_panel.anchor_right = 0.7
	dev_panel.anchor_top = 0.05
	dev_panel.anchor_bottom = 0.95
	dev_panel.add_theme_constant_override("separation", 14)
	dev_overlay.add_child(dev_panel)

	var dev_title = Label.new()
	dev_title.text = "— DEV MENU —"
	dev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_title.add_theme_font_size_override("font_size", 22)
	dev_panel.add_child(dev_title)

	_dev_box_label = Label.new()
	_dev_box_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dev_box_label.add_theme_font_size_override("font_size", 15)
	_dev_box_label.modulate = Color(0.7, 0.7, 0.7)
	dev_panel.add_child(_dev_box_label)

	var dev_scroll = ScrollContainer.new()
	dev_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dev_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dev_btns = VBoxContainer.new()
	dev_btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_btns.add_theme_constant_override("separation", 14)
	dev_scroll.add_child(dev_btns)
	dev_panel.add_child(dev_scroll)

	var dev_win_match_btn = Button.new()
	dev_win_match_btn.text = "Win Current Match"
	dev_win_match_btn.custom_minimum_size = Vector2(0, 56)
	dev_win_match_btn.add_theme_font_size_override("font_size", 17)
	dev_win_match_btn.pressed.connect(_on_dev_win_match_pressed)
	dev_btns.add_child(dev_win_match_btn)

	var dev_shut_box_btn = Button.new()
	dev_shut_box_btn.text = "Shut the Box (Critical Win)"
	dev_shut_box_btn.custom_minimum_size = Vector2(0, 56)
	dev_shut_box_btn.add_theme_font_size_override("font_size", 17)
	dev_shut_box_btn.pressed.connect(_on_dev_shut_box_pressed)
	dev_btns.add_child(dev_shut_box_btn)

	var dev_give_power_btn = Button.new()
	dev_give_power_btn.text = "Give Power →"
	dev_give_power_btn.custom_minimum_size = Vector2(0, 56)
	dev_give_power_btn.add_theme_font_size_override("font_size", 17)
	dev_give_power_btn.pressed.connect(_on_dev_give_power_menu_pressed)
	dev_btns.add_child(dev_give_power_btn)

	var dev_give_ability_btn = Button.new()
	dev_give_ability_btn.text = "Give Ability →"
	dev_give_ability_btn.custom_minimum_size = Vector2(0, 56)
	dev_give_ability_btn.add_theme_font_size_override("font_size", 17)
	dev_give_ability_btn.pressed.connect(_on_dev_give_ability_menu_pressed)
	dev_btns.add_child(dev_give_ability_btn)

	var dev_switch_dice_btn = Button.new()
	dev_switch_dice_btn.text = "Switch Dice →"
	dev_switch_dice_btn.custom_minimum_size = Vector2(0, 56)
	dev_switch_dice_btn.add_theme_font_size_override("font_size", 17)
	dev_switch_dice_btn.pressed.connect(_on_dev_switch_dice_pressed)
	dev_btns.add_child(dev_switch_dice_btn)

	var dev_win_series_btn = Button.new()
	dev_win_series_btn.text = "Win Entire Series"
	dev_win_series_btn.custom_minimum_size = Vector2(0, 56)
	dev_win_series_btn.add_theme_font_size_override("font_size", 17)
	dev_win_series_btn.pressed.connect(_on_dev_win_series_pressed)
	dev_btns.add_child(dev_win_series_btn)

	var dev_restart_btn = Button.new()
	dev_restart_btn.text = "Restart Run"
	dev_restart_btn.custom_minimum_size = Vector2(0, 56)
	dev_restart_btn.add_theme_font_size_override("font_size", 17)
	dev_restart_btn.pressed.connect(_on_dev_restart_pressed)
	dev_btns.add_child(dev_restart_btn)

	var dev_goto_match_btn = Button.new()
	dev_goto_match_btn.text = "Go to Match →"
	dev_goto_match_btn.custom_minimum_size = Vector2(0, 56)
	dev_goto_match_btn.add_theme_font_size_override("font_size", 17)
	dev_goto_match_btn.pressed.connect(_on_dev_goto_match_menu_pressed)
	dev_btns.add_child(dev_goto_match_btn)

	var dev_goto_box_btn = Button.new()
	dev_goto_box_btn.text = "Go to Box →"
	dev_goto_box_btn.custom_minimum_size = Vector2(0, 56)
	dev_goto_box_btn.add_theme_font_size_override("font_size", 17)
	dev_goto_box_btn.pressed.connect(_on_dev_goto_box_menu_pressed)
	dev_btns.add_child(dev_goto_box_btn)

	var dev_hp_btn = Button.new()
	dev_hp_btn.text = "+10 HP (Dev)"
	dev_hp_btn.custom_minimum_size = Vector2(0, 56)
	dev_hp_btn.add_theme_font_size_override("font_size", 17)
	dev_hp_btn.pressed.connect(_on_dev_give_hp_pressed)
	dev_btns.add_child(dev_hp_btn)

	var dev_storm_btn = Button.new()
	dev_storm_btn.text = "Force Storm Box →"
	dev_storm_btn.custom_minimum_size = Vector2(0, 56)
	dev_storm_btn.add_theme_font_size_override("font_size", 17)
	dev_storm_btn.pressed.connect(_on_dev_force_entry_box_pressed.bind("storm_box"))
	dev_btns.add_child(dev_storm_btn)

	var dev_cleanse_btn = Button.new()
	dev_cleanse_btn.text = "Force Cleanse Box →"
	dev_cleanse_btn.custom_minimum_size = Vector2(0, 56)
	dev_cleanse_btn.add_theme_font_size_override("font_size", 17)
	dev_cleanse_btn.pressed.connect(_on_dev_force_entry_box_pressed.bind("cleanse_box"))
	dev_btns.add_child(dev_cleanse_btn)

	var dev_borrowed_btn = Button.new()
	dev_borrowed_btn.text = "Force Borrowed Time →"
	dev_borrowed_btn.custom_minimum_size = Vector2(0, 56)
	dev_borrowed_btn.add_theme_font_size_override("font_size", 17)
	dev_borrowed_btn.pressed.connect(_on_dev_force_entry_box_pressed.bind("borrowed_time"))
	dev_btns.add_child(dev_borrowed_btn)

	var dev_force_round_btn = Button.new()
	dev_force_round_btn.text = "Force Round → (escalating)"
	dev_force_round_btn.custom_minimum_size = Vector2(0, 56)
	dev_force_round_btn.add_theme_font_size_override("font_size", 17)
	dev_force_round_btn.pressed.connect(_on_dev_force_round_menu_pressed)
	dev_btns.add_child(dev_force_round_btn)

	var dev_close_btn = Button.new()
	dev_close_btn.text = "Close  [T]"
	dev_close_btn.custom_minimum_size = Vector2(0, 44)
	dev_close_btn.pressed.connect(_on_dev_toggle_pressed)
	dev_btns.add_child(dev_close_btn)

	root.add_child(dev_overlay)
	_dev_overlay = dev_overlay

	# ── Dev power picker sub-overlay ─────────────────────────────────────────────
	var dev_power_overlay = Control.new()
	dev_power_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_power_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_power_overlay.visible = false
	var dev_power_bg = ColorRect.new()
	dev_power_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_power_bg.color = Color(0, 0, 0, 1.0)
	dev_power_overlay.add_child(dev_power_bg)

	var dev_power_panel = VBoxContainer.new()
	dev_power_panel.anchor_left = 0.3
	dev_power_panel.anchor_right = 0.7
	dev_power_panel.anchor_top = 0.05
	dev_power_panel.anchor_bottom = 0.95
	dev_power_panel.add_theme_constant_override("separation", 12)
	dev_power_overlay.add_child(dev_power_panel)

	var dev_power_title = Label.new()
	dev_power_title.text = "— GIVE POWER —"
	dev_power_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_power_title.add_theme_font_size_override("font_size", 22)
	dev_power_panel.add_child(dev_power_title)

	var dev_power_scroll = ScrollContainer.new()
	dev_power_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dev_power_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dev_power_list = VBoxContainer.new()
	_dev_power_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dev_power_list.add_theme_constant_override("separation", 12)
	dev_power_scroll.add_child(_dev_power_list)
	dev_power_panel.add_child(dev_power_scroll)

	var dev_power_back_btn = Button.new()
	dev_power_back_btn.text = "← Back"
	dev_power_back_btn.custom_minimum_size = Vector2(0, 44)
	dev_power_back_btn.pressed.connect(_on_dev_power_back_pressed)
	dev_power_panel.add_child(dev_power_back_btn)

	root.add_child(dev_power_overlay)
	_dev_power_overlay = dev_power_overlay

	# ── Dev ability picker sub-overlay ───────────────────────────────────────────
	var dev_ability_overlay = Control.new()
	dev_ability_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_ability_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_ability_overlay.visible = false
	var dev_ability_bg = ColorRect.new()
	dev_ability_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_ability_bg.color = Color(0, 0, 0, 1.0)
	dev_ability_overlay.add_child(dev_ability_bg)

	var dev_ability_panel = VBoxContainer.new()
	dev_ability_panel.anchor_left = 0.3
	dev_ability_panel.anchor_right = 0.7
	dev_ability_panel.anchor_top = 0.05
	dev_ability_panel.anchor_bottom = 0.95
	dev_ability_panel.add_theme_constant_override("separation", 12)
	dev_ability_overlay.add_child(dev_ability_panel)

	var dev_ability_title = Label.new()
	dev_ability_title.text = "— GIVE ABILITY —"
	dev_ability_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_ability_title.add_theme_font_size_override("font_size", 22)
	dev_ability_panel.add_child(dev_ability_title)

	var dev_ability_scroll = ScrollContainer.new()
	dev_ability_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dev_ability_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dev_ability_list = VBoxContainer.new()
	_dev_ability_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dev_ability_list.add_theme_constant_override("separation", 12)
	dev_ability_scroll.add_child(_dev_ability_list)
	dev_ability_panel.add_child(dev_ability_scroll)

	var dev_ability_back_btn = Button.new()
	dev_ability_back_btn.text = "← Back"
	dev_ability_back_btn.custom_minimum_size = Vector2(0, 44)
	dev_ability_back_btn.pressed.connect(_on_dev_ability_back_pressed)
	dev_ability_panel.add_child(dev_ability_back_btn)

	root.add_child(dev_ability_overlay)
	_dev_ability_overlay = dev_ability_overlay

	# ── Dev go-to-match sub-overlay ──────────────────────────────────────────────
	var dev_goto_overlay = Control.new()
	dev_goto_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_goto_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_goto_overlay.visible = false
	var dev_goto_bg = ColorRect.new()
	dev_goto_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_goto_bg.color = Color(0, 0, 0, 1.0)
	dev_goto_overlay.add_child(dev_goto_bg)

	var dev_goto_panel = VBoxContainer.new()
	dev_goto_panel.anchor_left = 0.25
	dev_goto_panel.anchor_right = 0.75
	dev_goto_panel.anchor_top = 0.05
	dev_goto_panel.anchor_bottom = 0.95
	dev_goto_panel.add_theme_constant_override("separation", 10)
	dev_goto_overlay.add_child(dev_goto_panel)

	var dev_goto_title = Label.new()
	dev_goto_title.text = "— GO TO MATCH —"
	dev_goto_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_goto_title.add_theme_font_size_override("font_size", 22)
	dev_goto_panel.add_child(dev_goto_title)

	var dev_goto_subtitle = Label.new()
	dev_goto_subtitle.text = "Restarts the run and fast-forwards to the selected match."
	dev_goto_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_goto_subtitle.add_theme_font_size_override("font_size", 13)
	dev_goto_subtitle.modulate = Color(0.6, 0.6, 0.6)
	dev_goto_panel.add_child(dev_goto_subtitle)

	var dev_goto_scroll = ScrollContainer.new()
	dev_goto_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dev_goto_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dev_goto_list = VBoxContainer.new()
	dev_goto_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_goto_list.add_theme_constant_override("separation", 8)
	dev_goto_scroll.add_child(dev_goto_list)
	dev_goto_panel.add_child(dev_goto_scroll)

	for match_n in range(1, 28):
		var tier_hint: String
		if match_n == 9 or match_n == 21 or match_n == 27:
			tier_hint = "BOSS"
		elif match_n <= 8:
			tier_hint = "easy"
		elif match_n <= 20:
			tier_hint = "medium"
		else:
			tier_hint = "hard"
		var mb = Button.new()
		mb.text = "Match %d  —  %s" % [match_n, tier_hint]
		mb.custom_minimum_size = Vector2(0, 44)
		mb.add_theme_font_size_override("font_size", 15)
		if tier_hint == "BOSS":
			mb.modulate = Color(1.0, 0.7, 0.3)
		mb.pressed.connect(_on_dev_goto_match_pressed.bind(match_n))
		dev_goto_list.add_child(mb)

	var dev_goto_back_btn = Button.new()
	dev_goto_back_btn.text = "← Back"
	dev_goto_back_btn.custom_minimum_size = Vector2(0, 44)
	dev_goto_back_btn.pressed.connect(func(): dev_goto_overlay.visible = false; _dev_overlay.visible = true)
	dev_goto_panel.add_child(dev_goto_back_btn)

	root.add_child(dev_goto_overlay)
	_dev_goto_match_overlay = dev_goto_overlay

	# ── Dev go-to-box sub-overlay ──────────────────────────────────────────────
	var dev_goto_box_overlay = Control.new()
	dev_goto_box_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_goto_box_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_goto_box_overlay.visible = false
	var dev_goto_box_bg = ColorRect.new()
	dev_goto_box_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_goto_box_bg.color = Color(0, 0, 0, 1.0)
	dev_goto_box_overlay.add_child(dev_goto_box_bg)

	var dev_goto_box_panel = VBoxContainer.new()
	dev_goto_box_panel.anchor_left = 0.25
	dev_goto_box_panel.anchor_right = 0.75
	dev_goto_box_panel.anchor_top = 0.05
	dev_goto_box_panel.anchor_bottom = 0.95
	dev_goto_box_panel.add_theme_constant_override("separation", 10)
	dev_goto_box_overlay.add_child(dev_goto_box_panel)

	var dev_goto_box_title = Label.new()
	dev_goto_box_title.text = "— GO TO BOX —"
	dev_goto_box_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_goto_box_title.add_theme_font_size_override("font_size", 22)
	dev_goto_box_panel.add_child(dev_goto_box_title)

	var dev_goto_box_subtitle = Label.new()
	dev_goto_box_subtitle.text = "Restarts the current match with the selected box."
	dev_goto_box_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_goto_box_subtitle.add_theme_font_size_override("font_size", 13)
	dev_goto_box_subtitle.modulate = Color(0.6, 0.6, 0.6)
	dev_goto_box_panel.add_child(dev_goto_box_subtitle)

	var dev_goto_box_scroll = ScrollContainer.new()
	dev_goto_box_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dev_goto_box_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dev_goto_box_list = VBoxContainer.new()
	_dev_goto_box_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dev_goto_box_list.add_theme_constant_override("separation", 8)
	dev_goto_box_scroll.add_child(_dev_goto_box_list)
	dev_goto_box_panel.add_child(dev_goto_box_scroll)

	var dev_goto_box_back_btn = Button.new()
	dev_goto_box_back_btn.text = "← Back"
	dev_goto_box_back_btn.custom_minimum_size = Vector2(0, 44)
	dev_goto_box_back_btn.pressed.connect(func(): dev_goto_box_overlay.visible = false; _dev_overlay.visible = true)
	dev_goto_box_panel.add_child(dev_goto_box_back_btn)

	root.add_child(dev_goto_box_overlay)
	_dev_goto_box_overlay = dev_goto_box_overlay

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

	# ── Dev force-round overlay (for testing escalating_threshold) ────────────
	var force_round_overlay = Control.new()
	force_round_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	force_round_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	force_round_overlay.visible = false
	var fr_bg = ColorRect.new()
	fr_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr_bg.color = Color(0, 0, 0, 1.0)
	force_round_overlay.add_child(fr_bg)

	var fr_panel = VBoxContainer.new()
	fr_panel.anchor_left = 0.3
	fr_panel.anchor_right = 0.7
	fr_panel.anchor_top = 0.2
	fr_panel.anchor_bottom = 0.8
	fr_panel.add_theme_constant_override("separation", 16)
	force_round_overlay.add_child(fr_panel)

	var fr_title = Label.new()
	fr_title.text = "— FORCE ROUND —"
	fr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fr_title.add_theme_font_size_override("font_size", 22)
	fr_panel.add_child(fr_title)

	var fr_sub = Label.new()
	fr_sub.text = "Sets GameState.round so the next win-check uses that round's threshold.\nUse with escalating_threshold box."
	fr_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fr_sub.add_theme_font_size_override("font_size", 14)
	fr_sub.modulate = Color(0.75, 0.75, 0.75)
	fr_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fr_panel.add_child(fr_sub)

	for round_num in [1, 2, 3, 4]:
		var fr_btn = Button.new()
		fr_btn.text = "Round %d  (threshold ≤%d)" % [round_num, BoxWinConditions.get_escalating_threshold(round_num)]
		fr_btn.custom_minimum_size = Vector2(0, 52)
		fr_btn.add_theme_font_size_override("font_size", 17)
		fr_btn.pressed.connect(_on_dev_force_round_pressed.bind(round_num))
		fr_panel.add_child(fr_btn)

	var fr_back_btn = Button.new()
	fr_back_btn.text = "← Back"
	fr_back_btn.custom_minimum_size = Vector2(0, 44)
	fr_back_btn.pressed.connect(_on_dev_force_round_back_pressed)
	fr_panel.add_child(fr_back_btn)

	root.add_child(force_round_overlay)
	_dev_force_round_overlay = force_round_overlay

	# ── Run-won overlay ────────────────────────────────────────────────────────
	var won_overlay = Control.new()
	won_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	won_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	won_overlay.visible = false
	var won_bg = ColorRect.new()
	won_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	won_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	won_overlay.add_child(won_bg)

	var won_center = VBoxContainer.new()
	won_center.anchor_left = 0.2
	won_center.anchor_right = 0.8
	won_center.anchor_top = 0.3
	won_center.anchor_bottom = 0.75
	won_center.add_theme_constant_override("separation", 20)
	won_overlay.add_child(won_center)

	var won_title = Label.new()
	won_title.text = "the entity is sealed"
	won_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	won_title.add_theme_font_size_override("font_size", 30)
	won_center.add_child(won_title)
	_run_won_title_label = won_title

	var won_btn = Button.new()
	won_btn.text = "Begin a new case"
	won_btn.custom_minimum_size = Vector2(200, 52)
	won_btn.add_theme_font_size_override("font_size", 18)
	won_btn.pressed.connect(_on_run_won_new_case_pressed)
	won_center.add_child(won_btn)

	root.add_child(won_overlay)
	_run_won_overlay = won_overlay

	# ── Crossroads overlay ─────────────────────────────────────────────────────
	var crossroads_overlay = Control.new()
	crossroads_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crossroads_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	crossroads_overlay.visible = false
	var crossroads_bg = ColorRect.new()
	crossroads_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	crossroads_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	crossroads_overlay.add_child(crossroads_bg)

	var crossroads_center = VBoxContainer.new()
	crossroads_center.anchor_left = 0.2
	crossroads_center.anchor_right = 0.8
	crossroads_center.anchor_top = 0.25
	crossroads_center.anchor_bottom = 0.80
	crossroads_center.add_theme_constant_override("separation", 24)
	crossroads_overlay.add_child(crossroads_center)

	var crossroads_title = Label.new()
	crossroads_title.text = "Crossroads"
	crossroads_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crossroads_title.add_theme_font_size_override("font_size", 30)
	crossroads_center.add_child(crossroads_title)

	var crossroads_sub = Label.new()
	crossroads_sub.text = "Choose your path"
	crossroads_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crossroads_sub.add_theme_font_size_override("font_size", 16)
	crossroads_sub.modulate = Color(0.75, 0.75, 0.75)
	crossroads_center.add_child(crossroads_sub)

	var crossroads_btn_row = HBoxContainer.new()
	crossroads_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crossroads_btn_row.add_theme_constant_override("separation", 32)
	crossroads_btn_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crossroads_center.add_child(crossroads_btn_row)

	var rest_btn = Button.new()
	rest_btn.text = "Rest\n+2 HP"
	rest_btn.custom_minimum_size = Vector2(200, 100)
	rest_btn.add_theme_font_size_override("font_size", 20)
	rest_btn.pressed.connect(_on_crossroads_rest_pressed)
	crossroads_btn_row.add_child(rest_btn)

	var whetstone_btn = Button.new()
	whetstone_btn.text = "Whetstone\nswap one die"
	whetstone_btn.custom_minimum_size = Vector2(200, 100)
	whetstone_btn.add_theme_font_size_override("font_size", 20)
	whetstone_btn.pressed.connect(_on_crossroads_whetstone_pressed)
	crossroads_btn_row.add_child(whetstone_btn)

	root.add_child(crossroads_overlay)
	_crossroads_overlay = crossroads_overlay

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
	_round_manager.tab_behavior_changed.connect(_on_tab_behavior_changed)
	_run_manager.next_match_ready.connect(_on_next_match_ready)
	_run_manager.show_power_offer.connect(_on_show_power_offer)
	_run_manager.run_over.connect(_on_run_over)
	_run_manager.show_rotation_offer.connect(_on_show_rotation_offer)
	_run_manager.show_die_swap.connect(_on_show_die_swap)
	_run_manager.show_crossroads.connect(_on_show_crossroads)
	if Engine.has_singleton("CaseManager"):
		Engine.get_singleton("CaseManager").run_won.connect(_on_run_won)

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
	_refresh_powers_panel()

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
	if _dev_power_overlay:
		_dev_power_overlay.visible = false
	if _dev_ability_overlay:
		_dev_ability_overlay.visible = false
	if _dev_goto_match_overlay:
		_dev_goto_match_overlay.visible = false
	if _dev_goto_box_overlay:
		_dev_goto_box_overlay.visible = false
	if _run_over_overlay:
		_run_over_overlay.visible = false
	if _rotation_overlay:
		_rotation_overlay.visible = false
	if _die_swap_overlay:
		_die_swap_overlay.visible = false
	if _run_won_overlay:
		_run_won_overlay.visible = false
	if _crossroads_overlay:
		_crossroads_overlay.visible = false
	_action_button.disabled = false
	for btn in _dice_buttons + _ability_buttons:
		btn.disabled = false
	_dev_box_label.text = "Box: %s" % box.name
	_round_manager.start_match(box)
	_rebuild_tab_buttons()
	_update_tabs_header_widths()
	for btn in _tab_buttons:
		btn.disabled = false
	_refresh_powers_panel()

func _on_run_over(match_number: int) -> void:
	_run_over_detail_label.text = "Defeated on Match %d  |  HP: 0" % match_number
	_run_over_overlay.visible = true

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

func _refresh_powers_panel() -> void:
	if not _powers_vbox:
		return
	for child in _powers_vbox.get_children():
		child.queue_free()
	var counts: Dictionary = {}
	var deduped: Array = []
	for power in GameState.owned_powers:
		if power.id in counts:
			counts[power.id] += 1
		else:
			counts[power.id] = 1
			deduped.append(power)
	for power in deduped:
		var pill = TooltipButton.new()
		pill.custom_minimum_size = Vector2(0, 44)
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var display_name: String = power.name
		if power.counter_target > 0:
			var current_count: int = GameState.power_counters.get(power.id, 0)
			display_name = "%s %d/%d" % [power.name, current_count, power.counter_target]
		pill.text = display_name
		pill.tooltip_text = power.name
		pill._tooltip_title = power.name
		pill._tooltip_body = power.description
		var count = counts[power.id]
		if count > 1:
			var badge = Label.new()
			badge.text = str(count)
			badge.add_theme_font_size_override("font_size", 11)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.anchor_left = 1.0
			badge.anchor_right = 1.0
			badge.anchor_top = 1.0
			badge.anchor_bottom = 1.0
			badge.offset_left = -18
			badge.offset_right = -3
			badge.offset_top = -16
			badge.offset_bottom = -3
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pill.add_child(badge)
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

func _on_show_die_swap(offered_dice: Array) -> void:
	assert(offered_dice.size() == _die_swap_offered_buttons.size(),
		"Die swap: offered_dice count %d does not match button count %d" \
		% [offered_dice.size(), _die_swap_offered_buttons.size()])
	_die_swap_offered_dice = offered_dice
	_selected_swap_offered_idx = -1
	_selected_swap_pool_die = null
	_selected_swap_pool_idx = -1
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
	_selected_swap_pool_idx = index
	for i in _die_swap_pool_buttons.size():
		_die_swap_pool_buttons[i].modulate = Color(1.5, 1.5, 0.3) if i == index else Color.WHITE
	_update_die_swap_confirm_state()

func _update_die_swap_confirm_state() -> void:
	_die_swap_confirm_btn.disabled = (_selected_swap_offered_idx < 0 or _selected_swap_pool_die == null)

func _on_die_swap_confirm_pressed() -> void:
	_die_swap_overlay.visible = false
	if _dev_die_swap_mode:
		_dev_die_swap_mode = false
		var offered = _die_swap_offered_dice[_selected_swap_offered_idx]
		if _selected_swap_pool_idx >= 0:
			GameState.dice_pool[_selected_swap_pool_idx] = offered
		_dev_overlay.visible = true
	else:
		_run_manager.handle_die_swap_confirm(_die_swap_offered_dice[_selected_swap_offered_idx], _selected_swap_pool_die)

func _on_die_swap_skip_pressed() -> void:
	_die_swap_overlay.visible = false
	if _dev_die_swap_mode:
		_dev_die_swap_mode = false
		_dev_overlay.visible = true
	else:
		_run_manager.handle_die_swap_skip()

func _on_show_crossroads(_after_match: int) -> void:
	_crossroads_overlay.visible = true

func _on_crossroads_rest_pressed() -> void:
	_crossroads_overlay.visible = false
	_run_manager.handle_crossroads_rest()

func _on_crossroads_whetstone_pressed() -> void:
	_crossroads_overlay.visible = false
	_run_manager.handle_crossroads_whetstone()

func _on_mod_hint_entered() -> void:
	_mod_tooltip.visible = true

func _on_mod_hint_exited() -> void:
	_mod_tooltip.visible = false

func _process(delta: float) -> void:
	if _box_mod_hint != null and _box_mod_hint.visible:
		_mod_hint_time += delta
		var hue := fmod(_mod_hint_time * 0.15, 1.0)
		_box_mod_hint.add_theme_color_override("font_color", Color.from_hsv(hue, 0.85, 1.0))

func _on_dev_toggle_pressed() -> void:
	_dev_overlay.visible = not _dev_overlay.visible

func _on_dev_win_match_pressed() -> void:
	_dev_overlay.visible = false
	if not _match_ended:
		_round_manager.dev_win_match()

func _on_dev_shut_box_pressed() -> void:
	_dev_overlay.visible = false
	if not _match_ended:
		_round_manager.dev_critical_win()

func _on_dev_switch_dice_pressed() -> void:
	_dev_overlay.visible = false
	_dev_die_swap_mode = true
	var offered: Array = []
	for f in RunManager.DIE_SWAP_FACES:
		offered.append(Die.new(f))
	_on_show_die_swap(offered)

func _on_dev_give_power_menu_pressed() -> void:
	for child in _dev_power_list.get_children():
		child.queue_free()
	if Engine.has_singleton("PowerLibrary"):
		for power in Engine.get_singleton("PowerLibrary").get_all():
			var pbtn = Button.new()
			pbtn.text = power.name
			pbtn.tooltip_text = power.description
			pbtn.custom_minimum_size = Vector2(0, 52)
			pbtn.add_theme_font_size_override("font_size", 17)
			pbtn.pressed.connect(_on_dev_give_power.bind(power))
			_dev_power_list.add_child(pbtn)
	_dev_overlay.visible = false
	_dev_power_overlay.visible = true

func _on_dev_give_power(power: PowerData) -> void:
	if Engine.has_singleton("PowerManager"):
		Engine.get_singleton("PowerManager").add_power(power)
	else:
		GameState.owned_powers.append(power)
	_refresh_powers_panel()

func _on_dev_power_back_pressed() -> void:
	_dev_power_overlay.visible = false
	_dev_overlay.visible = true

func _on_dev_give_ability_menu_pressed() -> void:
	for child in _dev_ability_list.get_children():
		child.queue_free()
	if Engine.has_singleton("AbilityLibrary"):
		var lib = Engine.get_singleton("AbilityLibrary")
		for id in GameState.ABILITY_POOL_IDS:
			var ability = lib.get_ability(id)
			if not ability:
				continue
			var abtn = Button.new()
			abtn.text = "%s  [%d charges]" % [ability.flavor_name, ability.max_charges]
			abtn.tooltip_text = ability.description
			abtn.custom_minimum_size = Vector2(0, 52)
			abtn.add_theme_font_size_override("font_size", 17)
			abtn.pressed.connect(_on_dev_give_ability.bind(ability))
			_dev_ability_list.add_child(abtn)
	_dev_overlay.visible = false
	_dev_ability_overlay.visible = true

func _on_dev_give_ability(ability: AbilityData) -> void:
	var gs = Engine.get_singleton("GameState")
	for i in gs.ability_hand.size():
		if gs.ability_hand[i] == null:
			gs.ability_hand[i] = ability.duplicate()
			_refresh_ui()
			return
	gs.ability_hand[2] = ability.duplicate()
	_refresh_ui()

func _on_dev_ability_back_pressed() -> void:
	_dev_ability_overlay.visible = false
	_dev_overlay.visible = true

func _on_dev_restart_pressed() -> void:
	_dev_overlay.visible = false
	_run_manager.start_run()

func _on_dev_goto_match_menu_pressed() -> void:
	_dev_overlay.visible = false
	_dev_goto_match_overlay.visible = true

func _on_dev_goto_match_pressed(target: int) -> void:
	_dev_goto_match_overlay.visible = false
	_run_manager.start_run()
	var safety := 0
	while _run_manager.match_number < target and safety < 30:
		safety += 1
		_round_manager.dev_win_match()
		_run_manager.dev_skip_rotation()
		_run_manager.dev_skip_crossroads()

func _on_dev_goto_box_menu_pressed() -> void:
	for child in _dev_goto_box_list.get_children():
		child.queue_free()
	var lib = Engine.get_singleton("BoxLibrary") if Engine.has_singleton("BoxLibrary") else BoxLibrary
	var tier_colors := {"easy": Color.WHITE, "medium": Color(0.7, 1.0, 0.7), "hard": Color(1.0, 0.7, 0.7), "boss": Color(1.0, 0.7, 0.3)}
	for tier in ["easy", "medium", "hard", "boss"]:
		var boxes: Array = lib.get_by_tier(tier)
		if boxes.is_empty():
			continue
		var sep_lbl = Label.new()
		sep_lbl.text = "── %s ──" % tier.to_upper()
		sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sep_lbl.add_theme_font_size_override("font_size", 14)
		sep_lbl.modulate = tier_colors.get(tier, Color.WHITE)
		_dev_goto_box_list.add_child(sep_lbl)
		for box in boxes:
			var bbtn = Button.new()
			bbtn.text = "%s  (%d tabs, ≤%d to win)" % [box.name, box.tabs.size(), box.win_threshold]
			bbtn.custom_minimum_size = Vector2(0, 44)
			bbtn.add_theme_font_size_override("font_size", 15)
			bbtn.modulate = tier_colors.get(tier, Color.WHITE)
			bbtn.pressed.connect(_on_dev_goto_box_pressed.bind(box))
			_dev_goto_box_list.add_child(bbtn)
	_dev_overlay.visible = false
	_dev_goto_box_overlay.visible = true

func _on_dev_goto_box_pressed(box: BoxDefinition) -> void:
	_dev_goto_box_overlay.visible = false
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
	if _dev_power_overlay:
		_dev_power_overlay.visible = false
	if _dev_ability_overlay:
		_dev_ability_overlay.visible = false
	if _dev_goto_match_overlay:
		_dev_goto_match_overlay.visible = false
	if _run_over_overlay:
		_run_over_overlay.visible = false
	if _rotation_overlay:
		_rotation_overlay.visible = false
	if _die_swap_overlay:
		_die_swap_overlay.visible = false
	if _run_won_overlay:
		_run_won_overlay.visible = false
	if _crossroads_overlay:
		_crossroads_overlay.visible = false
	_action_button.disabled = false
	for btn in _dice_buttons + _ability_buttons:
		btn.disabled = false
	_dev_box_label.text = "Box: %s [DEV]" % box.name
	_round_manager.start_match(box)
	_rebuild_tab_buttons()
	_update_tabs_header_widths()
	for btn in _tab_buttons:
		btn.disabled = false
	_refresh_powers_panel()

func _on_dev_give_hp_pressed() -> void:
	GameState.hp += 10
	_refresh_ui()

func _on_dev_force_entry_box_pressed(box_id: String) -> void:
	_dev_overlay.visible = false
	var box_lib = Engine.get_singleton("BoxLibrary") if Engine.has_singleton("BoxLibrary") else null
	if box_lib == null:
		push_warning("Dev: BoxLibrary not available")
		return
	var box = box_lib.get_box(box_id)
	if box == null:
		push_warning("Dev: '%s' not found in BoxLibrary" % box_id)
		return
	if not _match_ended:
		_round_manager.dev_win_match()
	_round_manager.start_match(box)
	_rebuild_tab_buttons()
	_update_tabs_header_widths()
	for btn in _tab_buttons:
		btn.disabled = false
	_refresh_ui()
	_refresh_powers_panel()

func _on_dev_force_round_menu_pressed() -> void:
	_dev_overlay.visible = false
	_dev_force_round_overlay.visible = true

func _on_dev_force_round_pressed(round_num: int) -> void:
	GameState.round = round_num
	_dev_force_round_overlay.visible = false
	if GameState.current_box != null and GameState.current_box.id == "escalating_threshold":
		GameState.win_threshold = BoxWinConditions.get_escalating_threshold(round_num)
	_refresh_ui()

func _on_dev_force_round_back_pressed() -> void:
	_dev_force_round_overlay.visible = false
	_dev_overlay.visible = true

func _on_dev_win_series_pressed() -> void:
	_dev_overlay.visible = false
	var safety := 0
	while not _match_ended and safety < 10:
		safety += 1
		_round_manager.dev_win_match()
		_run_manager.dev_skip_rotation()
		_run_manager.dev_skip_crossroads()

func _on_play_again_pressed() -> void:
	_run_manager.start_run()

func _on_run_won() -> void:
	if _run_won_title_label:
		_run_won_title_label.text = "sealed"
	_run_won_overlay.visible = true

func _on_run_won_new_case_pressed() -> void:
	_run_won_overlay.visible = false
	_run_manager.start_run()

func _on_tabs_sealed(sealed_values: Array) -> void:
	if not _bhv_rebuilt_since_select:
		# Normal path: grey out the sealed buttons in-place so they stay visible.
		for i in _selected_tabs:
			_sealed_button_indices.append(i)
	_bhv_rebuilt_since_select = false
	_selected_tabs = []
	_selected_dice = []
	_update_tabs_header_widths()
	_refresh_ui()

func _on_status_updated(text: String) -> void:
	_status_label.text = text

# BHV tab mutation: rebuild the tab display and show message in status.
func _on_tab_behavior_changed(message: String) -> void:
	_selected_tabs = []
	_bhv_rebuilt_since_select = true
	_rebuild_tab_buttons()
	_update_tabs_header_widths()
	# Hide Continue if the tab mutation pushed remaining sum back above threshold.
	var remaining_sum := 0
	for t in GameState.tabs:
		remaining_sum += t
	if remaining_sum > GameState.win_threshold:
		_continue_button.visible = false
	_refresh_ui()
	if not message.is_empty():
		_status_label.text = message

# ── input handlers ───────────────────────────────────────────────────────────
func _on_die_pressed(index: int) -> void:
	var hand = GameState.dice_hand
	if index >= hand.size():
		return
	var die = hand[index]
	if die.dropped:
		return

	if _targeting_die and _selected_ability != null:
		var used_ability = _selected_ability
		var used_idx = GameState.ability_hand.find(used_ability)
		_round_manager.use_ability(used_ability, die)
		_selected_ability = null
		_targeting_die = false
		_refresh_ui()
		_refresh_powers_panel()
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

func _on_tab_pressed(idx: int) -> void:
	var rolled = GameState.dice_hand.filter(func(d): return d.rolled and not d.dropped)
	if rolled.is_empty():
		_status_label.text = "Roll your dice first, then click tabs that sum to your total."
		return

	var rolled_total := _round_manager.get_roll_total()

	var tab_value := int(_tab_buttons[idx].text)

	if idx in _selected_tabs:
		_selected_tabs.erase(idx)
	else:
		_selected_tabs.append(idx)

	var tab_sum := 0
	for i in _selected_tabs:
		tab_sum += int(_tab_buttons[i].text)

	if tab_sum > rolled_total:
		_selected_tabs.erase(idx)
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
		_refresh_powers_panel()
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
	if ability.id in ["reroll_all", "put_down_highest", "auto_seal_lowest"]:
		if _round_manager.use_ability(ability, null):
			_selected_ability = null
			_targeting_die = false
			_refresh_ui()
			_refresh_powers_panel()
			_flash_ability_used(index)
		return
	_selected_ability = ability
	_targeting_die = true
	_status_label.text = "%s — click a die to target it." % ability.description

func _on_end_round_pressed() -> void:
	var rolled = GameState.dice_hand.filter(func(d): return d.rolled and not d.dropped)
	if not _selected_tabs.is_empty() and not rolled.is_empty():
		var rolled_total := _round_manager.get_roll_total()
		var tab_sum := 0
		for i in _selected_tabs:
			tab_sum += int(_tab_buttons[i].text)
		if tab_sum != rolled_total:
			_status_label.text = "Selected tabs sum to %d but rolled total is %d — adjust your selection." % [tab_sum, rolled_total]
			return
		var selected_values: Array = []
		for i in _selected_tabs:
			selected_values.append(int(_tab_buttons[i].text))
		var match_before := _run_manager.match_number
		if not _round_manager.attempt_seal(rolled, selected_values):
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
func _update_tabs_header_widths() -> void:
	var tab_count = GameState.tabs.size()
	var btn_w: float
	var sep: float
	if tab_count >= 13:
		btn_w = 36.0; sep = 4.0
	elif tab_count >= 10:
		btn_w = 52.0; sep = 6.0
	else:
		btn_w = 62.0; sep = 8.0
	var row_width = tab_count * btn_w + max(0, tab_count - 1) * sep
	var side_width = max(60.0, (row_width - 110.0) / 2.0)
	_sealed_total_label.custom_minimum_size.x = side_width
	_thresh_col.custom_minimum_size.x = side_width

func _stop_hp_pulse() -> void:
	if _hp_tween:
		_hp_tween.kill()
		_hp_tween = null
	_hp_label.scale = Vector2.ONE

func _refresh_ui() -> void:
	_hp_label.text = "❤  %d" % GameState.hp
	_hp_max_label.text = "/%d" % GameState.MAX_HP
	match GameState.hp:
		1:
			_hp_label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
			if _hp_tween == null or not _hp_tween.is_running():
				_hp_label.pivot_offset = _hp_label.size / 2.0
				_hp_tween = create_tween().set_loops()
				_hp_tween.tween_property(_hp_label, "scale", Vector2(1.09, 1.09), 0.75).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				_hp_tween.tween_property(_hp_label, "scale", Vector2(1.0, 1.0), 0.75).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		2:
			_hp_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.0))
			_stop_hp_pulse()
		3:
			_hp_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.1))
			_stop_hp_pulse()
		_:
			_hp_label.remove_theme_color_override("font_color")
			_stop_hp_pulse()
	_match_label.text = "Match %d / 27" % _run_manager.match_number
	_act_label.text = "Act %d" % GameState.act
	if GameState.current_box:
		var tier := GameState.current_box.tier
		_tier_label.text = "BOSS" if tier == "boss" else tier
		_box_name_label.text = GameState.current_box.name
		var box_id := GameState.current_box.id
		var has_roll_mod := BoxRollModifiers.has_modifier(box_id)
		var has_win_mod := BoxWinConditions.has_override(box_id)
		var has_dice_mod := BoxDiceAccess.has_description(box_id)
		var has_entry_eff := BoxEntryEffects.has_entry_effect(box_id)
		var has_tab_bhv := BoxTabBehavior.has_behavior(box_id)
		if has_roll_mod or has_win_mod or has_dice_mod or has_entry_eff or has_tab_bhv:
			_box_mod_hint.visible = true
			if has_roll_mod:
				_mod_tooltip_label.text = BoxRollModifiers.get_description(box_id)
			elif has_win_mod:
				_mod_tooltip_label.text = BoxWinConditions.get_description(box_id)
			elif has_dice_mod:
				_mod_tooltip_label.text = BoxDiceAccess.get_description(box_id)
			elif has_entry_eff:
				_mod_tooltip_label.text = BoxEntryEffects.get_description(box_id)
			else:
				_mod_tooltip_label.text = BoxTabBehavior.get_description(box_id)
		else:
			_box_mod_hint.visible = false
			_mod_tooltip.visible = false
	else:
		_tier_label.text = ""
		_box_name_label.text = ""
		_box_mod_hint.visible = false
		_mod_tooltip.visible = false
	if GameState.current_box:
		var remaining_sum := 0
		for t in GameState.tabs:
			remaining_sum += t
		_sealed_total_label.text = "%d left" % remaining_sum
		_threshold_label.text = "≤%d to win" % GameState.win_threshold
	else:
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
	_sealed_button_indices = []
	var tab_count := GameState.tabs.size()
	var btn_w: int; var btn_h: int; var font_sz: int; var sep: int
	if tab_count <= 9:
		btn_w = 62; btn_h = 88; font_sz = 0; sep = 8
	elif tab_count <= 12:
		btn_w = 52; btn_h = 80; font_sz = 18; sep = 6
	else:
		btn_w = 36; btn_h = 66; font_sz = 14; sep = 4
	_tab_row.add_theme_constant_override("separation", sep)
	for i in tab_count:
		var tab_val = GameState.tabs[i]
		var btn = Button.new()
		btn.text = str(tab_val)
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		if font_sz > 0:
			btn.add_theme_font_size_override("font_size", font_sz)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_tab_row.add_child(btn)
		_tab_buttons.append(btn)

func _refresh_tab_display() -> void:
	for i in _tab_buttons.size():
		var btn = _tab_buttons[i]
		if i in _sealed_button_indices:
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4)
		elif i in _selected_tabs:
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
		var mod_lbl = _dice_mod_labels[i] if i < _dice_mod_labels.size() else null
		if i < hand.size():
			var die = hand[i]
			if die.dropped:
				btn.text = "[X] %d" % die.value
				btn.disabled = true
				if face_lbl: face_lbl.visible = false
				if mod_lbl:  mod_lbl.visible = false
			else:
				btn.text = str(die.value) if die.rolled else "d%d" % die.faces
				btn.disabled = false
				if face_lbl:
					if die.rolled:
						face_lbl.text = "d%d" % die.faces
						face_lbl.visible = true
					else:
						face_lbl.visible = false
				if mod_lbl:
					if die.rolled and die.modifier_tag != "":
						mod_lbl.text = die.modifier_tag
						mod_lbl.visible = true
					else:
						mod_lbl.visible = false
		else:
			btn.text = "—"
			btn.disabled = true
			if face_lbl: face_lbl.visible = false
			if mod_lbl:  mod_lbl.visible = false

func _refresh_dice_highlight() -> void:
	var hand = GameState.dice_hand
	var any_rolled = hand.any(func(d): return d.rolled)
	for i in hand.size():
		if i < _dice_buttons.size():
			var die = hand[i]
			if die.dropped or (any_rolled and not die.rolled and _current_phase == "act"):
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
			if i == 0:
				charges_text += " — lose after this round"
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
	var total := _round_manager.get_roll_total()
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
