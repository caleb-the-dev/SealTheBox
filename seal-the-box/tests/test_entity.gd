extends SceneTree

func _init() -> void:
	# ── Bootstrap libraries ────────────────────────────────────────────────────
	var ability_lib = load("res://scripts/globals/ability_library.gd").new()
	ability_lib.name = "AbilityLibrary"
	get_root().add_child(ability_lib)
	ability_lib._ready()
	Engine.register_singleton("AbilityLibrary", ability_lib)

	var box_lib = load("res://scripts/globals/box_library.gd").new()
	box_lib.name = "BoxLibrary"
	get_root().add_child(box_lib)
	box_lib._ready()
	Engine.register_singleton("BoxLibrary", box_lib)

	var gs = load("res://scripts/globals/game_state.gd").new()
	gs.name = "GameState"
	get_root().add_child(gs)
	Engine.register_singleton("GameState", gs)

	var vl = load("res://scripts/globals/vignette_library.gd").new()
	vl.name = "VignetteLibrary"
	get_root().add_child(vl)
	vl._ready()
	Engine.register_singleton("VignetteLibrary", vl)

	var el = load("res://scripts/globals/event_library.gd").new()
	el.name = "EventLibrary"
	get_root().add_child(el)
	el._ready()
	Engine.register_singleton("EventLibrary", el)

	var entity_lib = load("res://scripts/globals/entity_library.gd").new()
	entity_lib.name = "EntityLibrary"
	get_root().add_child(entity_lib)
	entity_lib._ready()
	Engine.register_singleton("EntityLibrary", entity_lib)

	var cm = load("res://scripts/run/case_manager.gd").new()
	cm.name = "CaseManager"
	get_root().add_child(cm)
	Engine.register_singleton("CaseManager", cm)

	# ── Run tests ──────────────────────────────────────────────────────────────
	_test_entity_library_loads_all_three(entity_lib)
	_test_get_entity_by_id(entity_lib)
	_test_location_names_parsed(entity_lib)
	_test_pool_ids(entity_lib)
	_test_get_random_covers_all_entities(entity_lib)
	_test_reset_run_sets_entity_id(cm, gs)
	_test_reset_run_entity_variety(cm, gs)
	_test_get_location_name(cm, gs, entity_lib)
	_test_texture_roller_uses_entity_pools(gs, entity_lib)

	print("All Entity tests passed!")
	quit()

# ── EntityLibrary tests ───────────────────────────────────────────────────────

func _test_entity_library_loads_all_three(entity_lib: Node) -> void:
	var all = entity_lib.get_all()
	assert(all.size() == 3, "EntityLibrary should load 3 entities, got %d" % all.size())

func _test_get_entity_by_id(entity_lib: Node) -> void:
	var d = entity_lib.get_entity("diabolic")
	assert(d != null, "get_entity('diabolic') should not be null")
	assert(d.id == "diabolic", "entity id should be 'diabolic', got '%s'" % d.id)
	assert(d.display_name == "the devil", "diabolic display_name should be 'the devil', got '%s'" % d.display_name)

	var c = entity_lib.get_entity("cosmic")
	assert(c != null, "get_entity('cosmic') should not be null")
	assert(c.display_name == "a cosmic horror", "cosmic display_name should be 'a cosmic horror', got '%s'" % c.display_name)

	var e = entity_lib.get_entity("ethereal")
	assert(e != null, "get_entity('ethereal') should not be null")
	assert(e.display_name == "an apparition", "ethereal display_name should be 'an apparition', got '%s'" % e.display_name)

	var missing = entity_lib.get_entity("nonexistent")
	assert(missing == null, "get_entity('nonexistent') should return null")

func _test_location_names_parsed(entity_lib: Node) -> void:
	var d = entity_lib.get_entity("diabolic")
	assert(d.location_names.size() == 3, "diabolic should have 3 location names, got %d" % d.location_names.size())
	assert(d.location_names[0] == "sulfur manor", "diabolic location 1 should be 'sulfur manor', got '%s'" % d.location_names[0])
	assert(d.location_names[1] == "bone catacombs", "diabolic location 2 should be 'bone catacombs', got '%s'" % d.location_names[1])
	assert(d.location_names[2] == "pact tower", "diabolic location 3 should be 'pact tower', got '%s'" % d.location_names[2])

	var c = entity_lib.get_entity("cosmic")
	assert(c.location_names.size() == 3, "cosmic should have 3 location names, got %d" % c.location_names.size())

	var e = entity_lib.get_entity("ethereal")
	assert(e.location_names.size() == 3, "ethereal should have 3 location names, got %d" % e.location_names.size())

func _test_pool_ids(entity_lib: Node) -> void:
	var d = entity_lib.get_entity("diabolic")
	assert(d.vignette_pool_id == "vig_diabolic", "diabolic vignette pool should be 'vig_diabolic', got '%s'" % d.vignette_pool_id)
	assert(d.event_pool_id == "evt_diabolic", "diabolic event pool should be 'evt_diabolic', got '%s'" % d.event_pool_id)

	var c = entity_lib.get_entity("cosmic")
	assert(c.vignette_pool_id == "vig_cosmic", "cosmic vignette pool should be 'vig_cosmic', got '%s'" % c.vignette_pool_id)
	assert(c.event_pool_id == "evt_cosmic", "cosmic event pool should be 'evt_cosmic', got '%s'" % c.event_pool_id)

	var e = entity_lib.get_entity("ethereal")
	assert(e.vignette_pool_id == "vig_ethereal", "ethereal vignette pool should be 'vig_ethereal', got '%s'" % e.vignette_pool_id)
	assert(e.event_pool_id == "evt_ethereal", "ethereal event pool should be 'evt_ethereal', got '%s'" % e.event_pool_id)

func _test_get_random_covers_all_entities(entity_lib: Node) -> void:
	var seen: Dictionary = {}
	# Run enough times to almost certainly hit all 3 with 3 entities
	for i in 200:
		var entity = entity_lib.get_random()
		assert(entity != null, "get_random() should never return null")
		seen[entity.id] = true
	assert(seen.size() == 3, "get_random() should eventually return all 3 entities, only saw %d unique ids" % seen.size())

# ── CaseManager entity integration tests ─────────────────────────────────────

func _test_reset_run_sets_entity_id(cm: Node, gs: Node) -> void:
	gs.entity_id = ""
	cm.reset_run()
	assert(not gs.entity_id.is_empty(), "reset_run() should set entity_id on GameState")
	var valid_ids = ["diabolic", "cosmic", "ethereal"]
	assert(gs.entity_id in valid_ids, "entity_id should be one of diabolic/cosmic/ethereal, got '%s'" % gs.entity_id)

func _test_reset_run_entity_variety(cm: Node, gs: Node) -> void:
	# Run reset_run many times; should see all 3 entity types
	var seen: Dictionary = {}
	for i in 200:
		cm.reset_run()
		seen[gs.entity_id] = true
	assert(seen.size() == 3, "After many reset_run() calls, should see all 3 entity ids, only saw %d: %s" % [seen.size(), str(seen.keys())])

func _test_get_location_name(cm: Node, gs: Node, entity_lib: Node) -> void:
	# Set entity to diabolic and check location names
	gs.entity_id = "diabolic"
	var diabolic = entity_lib.get_entity("diabolic")
	assert(cm.get_location_name(1) == diabolic.location_names[0],
		"get_location_name(1) should return '%s', got '%s'" % [diabolic.location_names[0], cm.get_location_name(1)])
	assert(cm.get_location_name(2) == diabolic.location_names[1],
		"get_location_name(2) should return '%s', got '%s'" % [diabolic.location_names[1], cm.get_location_name(2)])
	assert(cm.get_location_name(3) == diabolic.location_names[2],
		"get_location_name(3) should return '%s', got '%s'" % [diabolic.location_names[2], cm.get_location_name(3)])

	# Empty entity_id should fall back gracefully
	gs.entity_id = ""
	var fallback = cm.get_location_name(1)
	assert(not fallback.is_empty(), "get_location_name with empty entity_id should return a fallback string")

# ── TextureRoller entity-pool integration tests ───────────────────────────────

func _test_texture_roller_uses_entity_pools(gs: Node, entity_lib: Node) -> void:
	const TextureRollerScript = preload("res://scripts/run/texture_roller.gd")
	const VignetteLibraryScript = preload("res://scripts/globals/vignette_library.gd")

	# With entity set to diabolic, vignettes should come from vig_diabolic pool
	gs.entity_id = "diabolic"
	var diabolic = entity_lib.get_entity("diabolic")
	var vl = Engine.get_singleton("VignetteLibrary")

	var diabolic_pool = vl.get_pool(diabolic.vignette_pool_id)
	assert(diabolic_pool.size() > 0, "vig_diabolic pool should have entries")

	# Roll many times and collect any vignettes — all should be from vig_diabolic
	var diabolic_ids: Array[String] = []
	for v in diabolic_pool:
		diabolic_ids.append(v.id)

	var found_non_diabolic := false
	for i in 300:
		var result = TextureRollerScript.roll()
		if result["type"] == "vignette":
			var v_id = result["vignette"].id
			if not v_id in diabolic_ids:
				found_non_diabolic = true
	assert(not found_non_diabolic, "TextureRoller should only return vig_diabolic vignettes when entity is diabolic")

	# With empty entity_id, should fall back to default pool
	gs.entity_id = ""
	var default_pool = vl.get_pool("default")
	assert(default_pool.size() > 0, "default vignette pool should have entries")
	var default_ids: Array[String] = []
	for v in default_pool:
		default_ids.append(v.id)

	var found_non_default := false
	for i in 300:
		var result = TextureRollerScript.roll()
		if result["type"] == "vignette":
			var v_id = result["vignette"].id
			if not v_id in default_ids:
				found_non_default = true
	assert(not found_non_default, "TextureRoller with empty entity_id should use default pool only")
