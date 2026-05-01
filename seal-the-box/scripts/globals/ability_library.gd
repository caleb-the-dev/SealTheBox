extends Node

var _abilities: Dictionary = {}

func _ready() -> void:
    _load_csv()

func _load_csv() -> void:
    var file = FileAccess.open("res://data/abilities.csv", FileAccess.READ)
    if not file:
        push_error("AbilityLibrary: cannot open res://data/abilities.csv")
        return
    var headers = file.get_csv_line()  # skip header row
    while not file.eof_reached():
        var row = file.get_csv_line()
        if row.size() < 7 or row[0].strip_edges().is_empty():
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
        data.cooldown = int(row[4])
        data.ap_cost = int(row[5])
        data.description = row[6].strip_edges()
        _abilities[data.id] = data
    file.close()

func get_ability(id: String) -> AbilityData:
    return _abilities.get(id, null)

func get_all() -> Array:
    return _abilities.values()
