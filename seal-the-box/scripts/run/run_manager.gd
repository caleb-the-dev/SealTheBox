class_name RunManager
extends Node

signal next_match_ready(box: BoxDefinition)
signal show_reward(dice_faces: Array)
signal run_won(match_number: int, hp: int)
signal run_over(match_number: int)

const REWARD_DIE_FACES = [2, 3, 4, 5, 6, 7, 8, 10, 12]
const RUN_LENGTH: int = 3

var match_number: int = 1
var _boxes: Array = []

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
	gs.reset_run_end()
	run_won.emit(match_number, gs.hp)

func _pick_reward_dice(count: int) -> Array:
	var pool: Array = REWARD_DIE_FACES.duplicate()
	var picks: Array = []
	for i in count:
		var idx = randi() % pool.size()
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks
