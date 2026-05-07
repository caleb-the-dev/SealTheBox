extends SceneTree

func _init() -> void:
	var lib = load("res://scripts/globals/ability_library.gd").new()
	lib.name = "AbilityLibrary"
	get_root().add_child(lib)
	lib._ready()

	assert(lib != null, "AbilityLibrary must exist")

	var reroll = lib.get_ability("reroll_die")
	assert(reroll != null, "reroll_die must be in library")
	assert("Repeatable" in reroll.traits, "reroll_die should have Repeatable trait")

	var greater = lib.get_ability("greater_1")
	assert(greater != null, "greater_1 must be in library")
	assert(greater.traits.size() == 0, "greater_1 should have no traits")

	var missing = lib.get_ability("does_not_exist")
	assert(missing == null, "Missing ability should return null")

	var all = lib.get_all()
	assert(all.size() == 22, "Library should have exactly 22 abilities")

	print("AbilityLibrary tests passed!")
	quit()
