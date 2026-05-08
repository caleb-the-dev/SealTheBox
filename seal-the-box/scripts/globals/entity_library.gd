extends Node

const EntityDataScript = preload("res://resources/entity_data.gd")

var _entities: Dictionary = {}  # id -> EntityData
var _order: Array[String] = []   # insertion order for get_random()

func _ready() -> void:
	_load_csv()

func _load_csv() -> void:
	var file = FileAccess.open("res://data/entities.csv", FileAccess.READ)
	if not file:
		push_error("EntityLibrary: cannot open res://data/entities.csv")
		return
	file.get_csv_line()  # skip header row
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 5 or row[0].strip_edges().is_empty():
			continue
		var data = EntityDataScript.new()
		data.id = row[0].strip_edges()
		data.display_name = row[1].strip_edges()
		# location_names is a single cell with semicolon-separated values
		var raw_locations = row[2].strip_edges()
		data.location_names.clear()
		for loc in raw_locations.split(";", false):
			data.location_names.append(loc.strip_edges())
		data.vignette_pool_id = row[3].strip_edges()
		data.event_pool_id = row[4].strip_edges()
		_entities[data.id] = data
		_order.append(data.id)
	file.close()

func get_entity(id: String):
	return _entities.get(id, null)

func get_all() -> Array:
	var result: Array = []
	for id in _order:
		result.append(_entities[id])
	return result

func get_random():
	if _order.is_empty():
		push_error("EntityLibrary: no entities loaded — cannot get_random()")
		return null
	var id = _order[randi() % _order.size()]
	return _entities[id]
