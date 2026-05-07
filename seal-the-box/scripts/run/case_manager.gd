extends Node

signal run_won

const ACT1_SIZE := 9
const ACT2_SIZE := 12
const ACT3_SIZE := 6

var _case_list: Array = []  # Array of BoxDefinition, length 27

func reset_run() -> void:
	_case_list = []
	var box_lib = Engine.get_singleton("BoxLibrary")
	var easy = box_lib.get_by_tier("easy")
	var medium = box_lib.get_by_tier("medium")
	var hard = box_lib.get_by_tier("hard")
	for i in ACT1_SIZE:
		_case_list.append(easy[randi() % easy.size()])
	for i in ACT2_SIZE:
		_case_list.append(medium[randi() % medium.size()])
	for i in ACT3_SIZE:
		_case_list.append(hard[randi() % hard.size()])

func get_box_for_match(idx: int) -> BoxDefinition:
	if idx < 1 or idx > _case_list.size():
		push_error("CaseManager: match index %d out of range" % idx)
		return null
	return _case_list[idx - 1]

func get_act_for_match(idx: int) -> int:
	if idx <= ACT1_SIZE:
		return 1
	elif idx <= ACT1_SIZE + ACT2_SIZE:
		return 2
	else:
		return 3

func notify_run_won() -> void:
	run_won.emit()
