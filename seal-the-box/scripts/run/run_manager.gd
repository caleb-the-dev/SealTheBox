class_name RunManager
extends Node

signal next_match_ready(box: BoxDefinition)
signal show_reward(dice_faces: Array)
signal show_ability_offer(offered_ability: AbilityData)
signal run_won(match_number: int, hp: int)
signal run_over(match_number: int)

const REWARD_DIE_FACES = [2, 3, 4, 5, 6, 7, 8, 10, 12]
const RUN_LENGTH: int = 3
const ABILITY_POOL_IDS: Array = ["reroll_die", "greater_1", "lesser_1", "greater_2", "lesser_2", "reroll_all"]

var match_number: int = 1
var _boxes: Array = []
var _current_offered_ability: AbilityData = null

func start_run() -> void:
	var box_lib = Engine.get_singleton("BoxLibrary")
	_boxes = box_lib.get_ordered()
	match_number = 1
	var gs = Engine.get_singleton("GameState")
	gs.reset_run()
	next_match_ready.emit(_boxes[0])

func handle_match_won(_critical: bool) -> void:
	if match_number < RUN_LENGTH:
		match_number += 1
		next_match_ready.emit(_boxes[match_number - 1])
	else:
		show_reward.emit(_pick_reward_dice(3))

func handle_match_lost() -> void:
	run_over.emit(match_number)

func handle_reward_picked(chosen_face: int) -> void:
	var gs = Engine.get_singleton("GameState")
	gs.dice_pool.append(Die.new(chosen_face))
	_current_offered_ability = _pick_ability_offer(gs.ability_hand)
	if _current_offered_ability == null:
		gs.reset_run_end()
		run_won.emit(match_number, gs.hp)
		return
	show_ability_offer.emit(_current_offered_ability)

func handle_ability_offer_result(swap_index: int) -> void:
	var gs = Engine.get_singleton("GameState")
	if swap_index >= 0 and swap_index < gs.ability_hand.size() and _current_offered_ability != null:
		gs.ability_hand[swap_index] = _current_offered_ability
	gs.reset_run_end()
	run_won.emit(match_number, gs.hp)
	_current_offered_ability = null

func _pick_reward_dice(count: int) -> Array:
	var pool: Array = REWARD_DIE_FACES.duplicate()
	var picks: Array = []
	for i in count:
		var idx = randi() % pool.size()
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks

func _pick_ability_offer(current_hand: Array) -> AbilityData:
	var current_ids = current_hand.map(func(a): return a.id)
	var available_ids = ABILITY_POOL_IDS.filter(func(id): return not id in current_ids)
	if available_ids.is_empty():
		return null
	var lib = Engine.get_singleton("AbilityLibrary")
	var id = available_ids[randi() % available_ids.size()]
	var ability = lib.get_ability(id)
	return ability.duplicate() if ability else null
