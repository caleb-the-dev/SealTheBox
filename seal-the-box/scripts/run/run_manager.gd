class_name RunManager
extends Node

signal next_match_ready(box: BoxDefinition)
signal show_reward(dice_faces: Array)
signal show_rotation_offer(options: Array)
signal run_over(match_number: int)

const REWARD_DIE_FACES = [2, 4, 6, 8, 10, 12]

var match_number: int = 1
var _boxes: Array = []
var _pending_rotation_options: Array = []

func start_run() -> void:
	var box_lib = Engine.get_singleton("BoxLibrary")
	_boxes = box_lib.get_ordered()
	match_number = 1
	var gs = Engine.get_singleton("GameState")
	gs.reset_run()
	next_match_ready.emit(_boxes[0])

func handle_match_won(critical: bool) -> void:
	match_number += 1
	if critical:
		show_reward.emit(_pick_reward_dice(3))
	else:
		_do_rotation_offer()

func handle_match_lost() -> void:
	run_over.emit(match_number)

func handle_reward_picked(chosen_face: int) -> void:
	var gs = Engine.get_singleton("GameState")
	gs.dice_pool.append(Die.new(chosen_face))
	_do_rotation_offer()

func handle_rotation_pick(chosen: AbilityData) -> void:
	var gs = Engine.get_singleton("GameState")
	gs.ability_hand[0] = gs.ability_hand[1]
	gs.ability_hand[1] = gs.ability_hand[2]
	gs.ability_hand[2] = chosen
	_pending_rotation_options = []
	gs.reset_run_end()
	_start_next_match()

func dev_skip_rotation() -> void:
	if _pending_rotation_options.size() > 0:
		handle_rotation_pick(_pending_rotation_options[0])

func _start_next_match() -> void:
	var next_box = _boxes[(match_number - 1) % _boxes.size()]
	next_match_ready.emit(next_box)

func _pick_reward_dice(count: int) -> Array:
	var pool: Array = REWARD_DIE_FACES.duplicate()
	var picks: Array = []
	for i in count:
		var idx = randi() % pool.size()
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks

func _do_rotation_offer() -> void:
	var gs = Engine.get_singleton("GameState")
	var lib = Engine.get_singleton("AbilityLibrary")
	_pending_rotation_options = []
	for i in 3:
		var id = gs.ABILITY_POOL_IDS[randi() % gs.ABILITY_POOL_IDS.size()]
		var ability = lib.get_ability(id)
		if ability:
			_pending_rotation_options.append(ability.duplicate())
	show_rotation_offer.emit(_pending_rotation_options)
