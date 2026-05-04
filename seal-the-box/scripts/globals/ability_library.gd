extends Node

var _abilities: Dictionary = {}

func _ready() -> void:
	_load_csv()

func _load_csv() -> void:
	var file = FileAccess.open("res://data/abilities.csv", FileAccess.READ)
	if not file:
		push_error("AbilityLibrary: cannot open res://data/abilities.csv")
		return
	file.get_csv_line()  # skip header row
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 7 or row[0].strip_edges().is_empty():
			continue
		if not row[4].is_valid_int() or not row[5].is_valid_int():
			push_warning("AbilityLibrary: skipping malformed row (non-integer cost/cooldown): %s" % row[0])
			continue
		var data = AbilityData.new()
		data.id = row[0].strip_edges()
		data.flavor_name = row[1].strip_edges()
		data.type = row[2].strip_edges()
		var traits_raw = row[3].strip_edges()
		data.traits.clear()
		if traits_raw != "":
			for t in traits_raw.split(",", false):
				data.traits.append(t.strip_edges())
		data.cooldown = row[4].to_int()
		data.ap_cost = row[5].to_int()
		data.description = row[6].strip_edges()
		data.charges = row[7].to_int() if row.size() > 7 and row[7].strip_edges().is_valid_int() else 1
		data.max_charges = data.charges
		_abilities[data.id] = data
	file.close()

func get_ability(id: String) -> AbilityData:
	return _abilities.get(id, null)

func get_all() -> Array:
	return _abilities.values()
