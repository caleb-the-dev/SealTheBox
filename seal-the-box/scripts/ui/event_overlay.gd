extends Control

const EventDataScript = preload("res://resources/event_data.gd")

signal resolved(option: String)

var _prompt_label: Label
var _btn_a: Button
var _btn_b: Button
var _event = null  # EventData instance

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	add_child(bg)

	var center = VBoxContainer.new()
	center.anchor_left = 0.2
	center.anchor_right = 0.8
	center.anchor_top = 0.3
	center.anchor_bottom = 0.75
	center.add_theme_constant_override("separation", 32)
	add_child(center)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 22)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_prompt_label)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 32)
	center.add_child(btn_row)

	_btn_a = Button.new()
	_btn_a.custom_minimum_size = Vector2(160, 64)
	_btn_a.add_theme_font_size_override("font_size", 18)
	_btn_a.pressed.connect(_on_option_a_pressed)
	btn_row.add_child(_btn_a)

	_btn_b = Button.new()
	_btn_b.custom_minimum_size = Vector2(160, 64)
	_btn_b.add_theme_font_size_override("font_size", 18)
	_btn_b.pressed.connect(_on_option_b_pressed)
	btn_row.add_child(_btn_b)

## Call this before showing the overlay.
func setup(event) -> void:
	_event = event
	_prompt_label.text = event.prompt
	_btn_a.text = event.option_a_label
	_btn_b.text = event.option_b_label

func _on_option_a_pressed() -> void:
	if _event:
		apply_effects(_event.option_a_effect)
	resolved.emit("a")

func _on_option_b_pressed() -> void:
	if _event:
		apply_effects(_event.option_b_effect)
	resolved.emit("b")

## Parse and apply a semicolon-separated effect string.
## Supported: none, hp+N, hp-N, charge_random+1
## Unknown effects: push_error and skip.
static func apply_effects(effect_string: String) -> void:
	if effect_string.strip_edges().is_empty():
		return
	for raw in effect_string.split(";", false):
		var effect := raw.strip_edges()
		_apply_single_effect(effect)

static func _apply_single_effect(effect: String) -> void:
	if effect == "none":
		return  # explicit no-op

	if effect.begins_with("hp+"):
		var amount_str := effect.substr(3)
		if amount_str.is_valid_int():
			var amount := amount_str.to_int()
			var gs = Engine.get_singleton("GameState")
			gs.hp = min(gs.hp + amount, GameState.MAX_HP)
			return
		push_error("EventOverlay: malformed hp+ effect: %s" % effect)
		return

	if effect.begins_with("hp-"):
		var amount_str := effect.substr(3)
		if amount_str.is_valid_int():
			var amount := amount_str.to_int()
			var gs = Engine.get_singleton("GameState")
			gs.hp -= amount
			# Clamp to 0; the normal run-loss path (RunManager) detects hp == 0
			# on the next match-end check. We do not trigger it mid-overlay.
			if gs.hp < 0:
				gs.hp = 0
			return
		push_error("EventOverlay: malformed hp- effect: %s" % effect)
		return

	if effect == "charge_random+1":
		var gs = Engine.get_singleton("GameState")
		var valid_indices: Array[int] = []
		for i in gs.ability_hand.size():
			var a = gs.ability_hand[i]
			if a != null and a.charges < a.max_charges:
				valid_indices.append(i)
		if valid_indices.size() > 0:
			var pick_idx := valid_indices[randi() % valid_indices.size()]
			gs.ability_hand[pick_idx].charges += 1
		# If all null or all at max, silently no-op (valid state)
		return

	# Stub for future DSL effects — log and skip.
	push_error("EventOverlay: unknown effect '%s' — not implemented in this slice" % effect)
