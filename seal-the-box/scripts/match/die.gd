class_name Die
extends RefCounted

var faces: int
var value: int = 0
var rolled: bool = false
var dropped: bool = false
var storm_temp: bool = false  # true on bonus die granted by storm_box; purely informational
var modifier_tag: String = ""  # display annotation set by box modifiers (e.g. "×2", "+5")

func _init(f: int) -> void:
	faces = f

func roll() -> int:
	value = randi_range(1, faces)
	rolled = true
	return value
