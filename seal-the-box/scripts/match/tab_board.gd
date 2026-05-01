class_name TabBoard
extends RefCounted

var _remaining: Array[int] = []

func reset(tab_range: Array[int]) -> void:
    _remaining = tab_range.duplicate()

func seal_tab(value: int) -> void:
    _remaining.erase(value)

func get_remaining() -> Array[int]:
    return _remaining.duplicate()

func get_sum() -> int:
    var total: int = 0
    for t in _remaining:
        total += t
    return total

func check_win(threshold: int) -> bool:
    return get_sum() <= threshold

func check_critical_win() -> bool:
    return _remaining.is_empty()

func can_seal(dice_values: Array[int], tab: int) -> bool:
    if not tab in _remaining:
        return false
    var total: int = 0
    for v in dice_values:
        total += v
    return total == tab
