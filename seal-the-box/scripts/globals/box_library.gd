extends Node

var _boxes: Dictionary = {}
var _order: Array = []

func _ready() -> void:
    _load_csv()

func _load_csv() -> void:
    var file = FileAccess.open("res://data/boxes.csv", FileAccess.READ)
    if not file:
        push_error("BoxLibrary: cannot open res://data/boxes.csv")
        return
    file.get_csv_line()
    while not file.eof_reached():
        var row = file.get_csv_line()
        if row.size() < 4 or row[0].strip_edges().is_empty():
            continue
        var data = BoxDefinition.new()
        data.id = row[0].strip_edges()
        data.name = row[1].strip_edges()
        data.tabs.clear()
        for part in row[2].split(";", false):
            data.tabs.append(part.strip_edges().to_int())
        data.win_threshold = row[3].strip_edges().to_int()
        if row.size() >= 5:
            data.tier = row[4].strip_edges()
        _boxes[data.id] = data
        _order.append(data.id)
    file.close()

func get_box(id: String) -> BoxDefinition:
    return _boxes.get(id, null)

func get_all() -> Array:
    return _boxes.values()

func get_ordered() -> Array:
    return _order.map(func(id): return _boxes[id])

func get_by_tier(tier: String) -> Array:
    return _boxes.values().filter(func(b): return b.tier == tier)
