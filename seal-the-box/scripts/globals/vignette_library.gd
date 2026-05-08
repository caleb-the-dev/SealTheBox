extends Node

const VignetteDataScript = preload("res://resources/vignette_data.gd")

var _vignettes: Dictionary = {}  # id -> VignetteData
var _pools: Dictionary = {}       # pool_id -> Array[VignetteData]

func _ready() -> void:
	_load_csv()

func _load_csv() -> void:
	var file = FileAccess.open("res://data/vignettes.csv", FileAccess.READ)
	if not file:
		push_error("VignetteLibrary: cannot open res://data/vignettes.csv")
		return
	file.get_csv_line()  # skip header row
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 3 or row[0].strip_edges().is_empty():
			continue
		var data = VignetteDataScript.new()
		data.id = row[0].strip_edges()
		data.pool_id = row[1].strip_edges()
		data.text = row[2].strip_edges()
		_vignettes[data.id] = data
		if not _pools.has(data.pool_id):
			_pools[data.pool_id] = []
		_pools[data.pool_id].append(data)
	file.close()

func get_vignette(id: String) -> VignetteData:
	return _vignettes.get(id, null)

func get_all() -> Array:
	return _vignettes.values()

func get_pool(pool_id: String) -> Array:
	return _pools.get(pool_id, [])
