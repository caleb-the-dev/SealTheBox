class_name AbilityData
extends Resource

@export var id: String = ""
@export var flavor_name: String = ""
@export var type: String = ""
@export var traits: Array[String] = []
@export var cooldown: int = 0
@export var description: String = ""
@export var charges: int = 1
@export var max_charges: int = 1

func _init() -> void:
	traits = []
