class_name TooltipButton
extends Button

var _tooltip_title: String = ""
var _tooltip_body: String = ""

func update_info(display_name: String, full_description: String) -> void:
	_tooltip_title = display_name
	_tooltip_body = full_description
	text = "%s\n(once)" % display_name
	tooltip_text = display_name

func clear_info() -> void:
	_tooltip_title = ""
	_tooltip_body = ""
	text = "—"
	tooltip_text = ""

func _make_custom_tooltip(for_text: String) -> Object:
	if _tooltip_body.is_empty():
		return null
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.96)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = _tooltip_title
	title_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var body_lbl = Label.new()
	body_lbl.text = _tooltip_body
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(220, 0)
	body_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	vbox.add_child(body_lbl)

	return panel
