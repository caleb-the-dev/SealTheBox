extends Node

var GameState: Node:
	get: return Engine.get_singleton("GameState")

func count_owned(power_id: String) -> int:
	var count = 0
	for p in GameState.owned_powers:
		if p.id == power_id:
			count += 1
	return count

func get_threshold_bonus() -> int:
	return count_owned("lighter_box") * 3

func apply_eager(dice: Array) -> void:
	if count_owned("eager") == 0 or dice.is_empty():
		return
	var idx = randi() % dice.size()
	var die = dice[idx]
	die.value = die.faces
	die.rolled = true

func get_bonus_seals(tab_board: TabBoard, primary_seals: Array) -> Array:
	if count_owned("bonus_seal") == 0:
		return []
	var remaining = tab_board.get_remaining()
	var bonus: Array = []
	for tab in primary_seals:
		if tab < 2:
			continue
		var bonus_tab: int = tab / 2
		if bonus_tab in remaining and not bonus_tab in bonus:
			bonus.append(bonus_tab)
	return bonus

func apply_tab9_bounty(all_sealed_tabs: Array) -> void:
	var count = count_owned("tab_9_bounty")
	if count == 0 or not (9 in all_sealed_tabs):
		return
	GameState.hp += count

func apply_box_shutter() -> void:
	var count = count_owned("box_shutter")
	if count == 0:
		return
	GameState.pending_threshold_bonus += count * 5
