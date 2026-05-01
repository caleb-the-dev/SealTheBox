extends SceneTree

func _init() -> void:
    # Instantiate and initialize AbilityLibrary directly for headless --script testing
    var lib = load("res://scripts/globals/ability_library.gd").new()
    lib.name = "AbilityLibrary"
    get_root().add_child(lib)
    # _ready() is not called automatically in _init, so call _load_csv manually
    lib._load_csv()

    assert(lib != null, "AbilityLibrary must exist")

    var reroll = lib.get_ability("reroll_die")
    assert(reroll != null, "reroll_die must be in library")
    assert(reroll.ap_cost == 1, "reroll_die ap_cost should be 1")
    assert("Repeatable" in reroll.traits, "reroll_die should have Repeatable trait")

    var greater = lib.get_ability("greater_1")
    assert(greater != null, "greater_1 must be in library")
    assert(greater.ap_cost == 1, "greater_1 ap_cost should be 1")

    var missing = lib.get_ability("does_not_exist")
    assert(missing == null, "Missing ability should return null")

    var all = lib.get_all()
    assert(all.size() >= 3, "Library should have at least 3 abilities")

    print("AbilityLibrary tests passed!")
    quit()
