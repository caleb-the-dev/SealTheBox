class_name BoxDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var tabs: Array[int] = []
var win_threshold: int = 0
var tier: String = ""

func tab_sum() -> int:
    var sum = 0
    for tab in tabs:
        sum += tab
    return sum

var round_limit: int:
    get: return ceili(tab_sum() / 15.0) + 1
