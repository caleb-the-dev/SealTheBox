extends Node

const EventDataScript = preload("res://resources/event_data.gd")

var _events: Dictionary = {}  # id -> EventData
var _pools: Dictionary = {}    # pool_id -> Array[EventData]

func _ready() -> void:
	_load_csv()

func _load_csv() -> void:
	var file = FileAccess.open("res://data/events.csv", FileAccess.READ)
	if not file:
		push_error("EventLibrary: cannot open res://data/events.csv")
		return
	file.get_csv_line()  # skip header row
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 7 or row[0].strip_edges().is_empty():
			continue
		var data = EventDataScript.new()
		data.id = row[0].strip_edges()
		data.pool_id = row[1].strip_edges()
		data.prompt = row[2].strip_edges()
		data.option_a_label = row[3].strip_edges()
		data.option_a_effect = row[4].strip_edges()
		data.option_b_label = row[5].strip_edges()
		data.option_b_effect = row[6].strip_edges()
		_events[data.id] = data
		if not _pools.has(data.pool_id):
			_pools[data.pool_id] = []
		_pools[data.pool_id].append(data)
	file.close()

func get_event(id: String) -> EventData:
	return _events.get(id, null)

func get_all() -> Array:
	return _events.values()

func get_pool(pool_id: String) -> Array:
	return _pools.get(pool_id, [])
