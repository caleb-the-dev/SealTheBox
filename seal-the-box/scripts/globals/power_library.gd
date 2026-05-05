extends Node

const PowerData = preload("res://resources/power_data.gd")

var _powers: Dictionary = {}

func _ready() -> void:
	_load_csv()

func _load_csv() -> void:
	var file = FileAccess.open("res://data/powers.csv", FileAccess.READ)
	if not file:
		push_error("PowerLibrary: cannot open res://data/powers.csv")
		return
	file.get_csv_line()  # skip header row
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 4 or row[0].strip_edges().is_empty():
			continue
		var data = PowerData.new()
		data.id = row[0].strip_edges()
		data.name = row[1].strip_edges()
		data.type = row[2].strip_edges()
		data.description = row[3].strip_edges()
		_powers[data.id] = data
	file.close()

func get_power(id: String) -> PowerData:
	return _powers.get(id, null)

func get_all() -> Array:
	return _powers.values()

func get_random_unowned(owned_powers: Array) -> PowerData:
	var owned_ids: Dictionary = {}
	for p in owned_powers:
		owned_ids[p.id] = true
	var candidates = _powers.values().filter(func(p): return not owned_ids.has(p.id))
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func get_random_unowned_multiple(owned_powers: Array, count: int) -> Array:
	var owned_ids: Dictionary = {}
	for p in owned_powers:
		owned_ids[p.id] = true
	var candidates = _powers.values().filter(func(p): return not owned_ids.has(p.id))
	candidates.shuffle()
	return candidates.slice(0, min(count, candidates.size()))
