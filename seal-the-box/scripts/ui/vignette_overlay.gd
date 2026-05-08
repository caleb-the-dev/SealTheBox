extends Control

signal dismissed

var _text_label: Label

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
	center.anchor_top = 0.4
	center.anchor_bottom = 0.7
	center.add_theme_constant_override("separation", 24)
	add_child(center)

	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.add_theme_font_size_override("font_size", 24)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_text_label)

	var hint = Label.new()
	hint.text = "[ click anywhere to continue ]"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.6, 0.6, 0.6)
	center.add_child(hint)

## Call this before showing the overlay.
func setup(vignette) -> void:
	_text_label.text = vignette.text

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismissed.emit()
