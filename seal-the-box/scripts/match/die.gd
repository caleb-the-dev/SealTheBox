class_name Die
extends RefCounted

var faces: int
var value: int = 0
var rolled: bool = false
var dropped: bool = false

func _init(f: int) -> void:
    faces = f

func roll() -> int:
    value = randi_range(1, faces)
    rolled = true
    return value
