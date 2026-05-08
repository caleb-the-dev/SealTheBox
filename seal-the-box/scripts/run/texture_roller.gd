class_name TextureRoller

# Probability constants — adjust here for one-line tuning.
const PROB_SILENT := 0.50
const PROB_VIGNETTE := 0.30
# PROB_EVENT is the remainder (0.20) — anything >= PROB_SILENT + PROB_VIGNETTE

## Resolves the current entity's vignette and event pool ids from GameState.
## Falls back to "default" if entity_id is empty or EntityLibrary is missing.
static func _get_pool_ids() -> Dictionary:
	var vignette_pool_id := "default"
	var event_pool_id := "default"
	if Engine.has_singleton("GameState") and Engine.has_singleton("EntityLibrary"):
		var gs = Engine.get_singleton("GameState")
		if not gs.entity_id.is_empty():
			var entity = Engine.get_singleton("EntityLibrary").get_entity(gs.entity_id)
			if entity != null:
				vignette_pool_id = entity.vignette_pool_id
				event_pool_id = entity.event_pool_id
	return { "vignette": vignette_pool_id, "event": event_pool_id }

## Returns a Dictionary with key "type" set to "silent", "vignette", or "event".
## For "vignette": also includes "vignette" key (VignetteData).
## For "event":    also includes "event"    key (EventData).
## Falls back to "silent" if the chosen pool is empty.
## pool_id parameter is kept for backward compat but ignored — entity pool ids are used.
static func roll(_pool_id: String = "default") -> Dictionary:
	var pool_ids = _get_pool_ids()
	var r := randf()

	if r < PROB_SILENT:
		return { "type": "silent" }

	if r < PROB_SILENT + PROB_VIGNETTE:
		# Attempt vignette
		if Engine.has_singleton("VignetteLibrary"):
			var pool: Array = Engine.get_singleton("VignetteLibrary").get_pool(pool_ids["vignette"])
			if pool.size() > 0:
				var pick = pool[randi() % pool.size()]
				return { "type": "vignette", "vignette": pick }
		# Fall back to silent if pool empty or library missing
		return { "type": "silent" }

	# Attempt event
	if Engine.has_singleton("EventLibrary"):
		var pool: Array = Engine.get_singleton("EventLibrary").get_pool(pool_ids["event"])
		if pool.size() > 0:
			var pick = pool[randi() % pool.size()]
			return { "type": "event", "event": pick }
	# Fall back to silent if pool empty or library missing
	return { "type": "silent" }
