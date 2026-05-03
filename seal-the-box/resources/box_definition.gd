class_name BoxDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var tabs: Array[int] = []

func tab_sum() -> int:
    var sum = 0
    for tab in tabs:
        sum += tab
    return sum

var win_threshold: int:
    get: return floori(tab_sum() * 0.30)

var round_limit: int:
    get: return ceili(tab_sum() / 15.0)
