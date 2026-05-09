extends Node

signal run_won

const ACT1_SIZE := 9   # matches 1–9 (8 easy + 1 boss at position 9)
const ACT2_SIZE := 12  # matches 10–21 (11 medium + 1 boss at position 21)
const ACT3_SIZE := 6   # matches 22–27 (5 hard + 1 boss at position 27)

var _case_list: Array = []  # Array of BoxDefinition, length 27

func reset_run() -> void:
	_case_list = []
	var box_lib = Engine.get_singleton("BoxLibrary")
	var easy: Array   = box_lib.get_by_tier("easy")
	var medium: Array = box_lib.get_by_tier("medium")
	var hard: Array   = box_lib.get_by_tier("hard")
	var boss: Array   = box_lib.get_by_tier("boss")

	# Separate the fixed final boss (source_for == "final") from the mid-run boss pool.
	var final_boss: BoxDefinition = null
	var mid_boss: Array = []
	for box in boss:
		if box.source_for == "final":
			final_boss = box
		else:
			mid_boss.append(box)
	if final_boss == null:
		push_error("CaseManager: no final boss found (source_for='final'); using first boss box")
		final_boss = boss[0]
	mid_boss.shuffle()

	# Matches 1–8: easy tier
	for i in 8:
		_case_list.append(easy[randi() % easy.size()])
	# Match 9: mid-boss slot 0
	_case_list.append(mid_boss[0])

	# Matches 10–20: medium tier
	for i in 11:
		_case_list.append(medium[randi() % medium.size()])
	# Match 21: mid-boss slot 1
	_case_list.append(mid_boss[1])

	# Matches 22–26: hard tier
	for i in 5:
		_case_list.append(hard[randi() % hard.size()])
	# Match 27: always the final boss
	_case_list.append(final_boss)

	# Marquee-box deduplication pass: ensure once-per-run boxes (e.g. bounty_box)
	# appear at most once in the run. Walk the list; on the second encounter of a
	# marquee box, replace it with a fresh random draw from the same tier pool.
	# This is simpler and more reliable than "skip if seen" at runtime because the
	# list is committed upfront at reset_run() and never changes during play.
	var marquee_ids := ["bounty_box"]
	for marquee_id in marquee_ids:
		var seen_at := -1
		for i in _case_list.size():
			var box: BoxDefinition = _case_list[i]
			if box.id == marquee_id:
				if seen_at == -1:
					seen_at = i
				else:
					# Replace duplicate with another box from the same tier pool.
					var tier_pool: Array = box_lib.get_by_tier(box.tier)
					var non_marquee := tier_pool.filter(func(b: BoxDefinition) -> bool:
						return not b.id in marquee_ids)
					if not non_marquee.is_empty():
						_case_list[i] = non_marquee[randi() % non_marquee.size()]
					# else: tier has no non-marquee options — leave as-is (very unlikely)

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
