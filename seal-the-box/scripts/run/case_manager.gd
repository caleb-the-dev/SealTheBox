extends Node

signal run_won

const ACT1_SIZE := 9
const ACT2_SIZE := 12
const ACT3_SIZE := 6

var _case_list: Array = []  # Array of BoxDefinition, length 27

func reset_run() -> void:
	_case_list = []
	# Pick a random entity and store on GameState
	if Engine.has_singleton("EntityLibrary"):
		var entity = Engine.get_singleton("EntityLibrary").get_random()
		if entity and Engine.has_singleton("GameState"):
			Engine.get_singleton("GameState").entity_id = entity.id
	var box_lib = Engine.get_singleton("BoxLibrary")
	var easy = box_lib.get_by_tier("easy")
	var medium = box_lib.get_by_tier("medium")
	var hard = box_lib.get_by_tier("hard")
	for i in ACT1_SIZE:
		_case_list.append(easy[randi() % easy.size()])
	for i in ACT2_SIZE:
		_case_list.append(medium[randi() % medium.size()])
	# Act 3: matches 22–26 draw from regular hard-tier boxes (Source boxes excluded
	# by get_by_tier); match 27 is forced to the entity's Source box.
	for i in ACT3_SIZE - 1:
		_case_list.append(hard[randi() % hard.size()])
	var source_box: BoxDefinition = null
	if Engine.has_singleton("BoxLibrary") and Engine.has_singleton("GameState"):
		var entity_id: String = Engine.get_singleton("GameState").entity_id
		source_box = Engine.get_singleton("BoxLibrary").get_source(entity_id)
	if source_box == null and hard.size() > 0:
		push_error("CaseManager: Source box not found — falling back to random hard-tier box")
		source_box = hard[randi() % hard.size()]
	_case_list.append(source_box)

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

func get_location_name(act: int) -> String:
	if not Engine.has_singleton("EntityLibrary") or not Engine.has_singleton("GameState"):
		return "Location %d" % act
	var gs = Engine.get_singleton("GameState")
	if gs.entity_id.is_empty():
		return "Location %d" % act
	var entity = Engine.get_singleton("EntityLibrary").get_entity(gs.entity_id)
	if entity == null or entity.location_names.size() < act:
		return "Location %d" % act
	return entity.location_names[act - 1]

func notify_run_won() -> void:
	run_won.emit()
