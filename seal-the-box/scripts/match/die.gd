class_name Die
extends RefCounted

var faces: int
var value: int = 0
var rolled: bool = false
var dropped: bool = false
# storm_temp: set to true on the bonus die granted by storm_box. Purely
# informational — no special logic, just available for UI labeling.
var storm_temp: bool = false

func _init(f: int) -> void:
	faces = f

func roll() -> int:
	value = randi_range(1, faces)
	rolled = true
	return value
