class_name TextureRoller

# Probability constants — adjust here for one-line tuning.
const PROB_SILENT := 0.50
const PROB_VIGNETTE := 0.30
# PROB_EVENT is the remainder (0.20) — anything >= PROB_SILENT + PROB_VIGNETTE

## Returns a Dictionary with key "type" set to "silent", "vignette", or "event".
## For "vignette": also includes "vignette" key (VignetteData).
## For "event":    also includes "event"    key (EventData).
## Falls back to "silent" if the chosen pool is empty.
static func roll(pool_id: String) -> Dictionary:
	var r := randf()

	if r < PROB_SILENT:
		return { "type": "silent" }

	if r < PROB_SILENT + PROB_VIGNETTE:
		# Attempt vignette
		if Engine.has_singleton("VignetteLibrary"):
			var pool: Array = Engine.get_singleton("VignetteLibrary").get_pool(pool_id)
			if pool.size() > 0:
				var pick = pool[randi() % pool.size()]
				return { "type": "vignette", "vignette": pick }
		# Fall back to silent if pool empty or library missing
		return { "type": "silent" }

	# Attempt event
	if Engine.has_singleton("EventLibrary"):
		var pool: Array = Engine.get_singleton("EventLibrary").get_pool(pool_id)
		if pool.size() > 0:
			var pick = pool[randi() % pool.size()]
			return { "type": "event", "event": pick }
	# Fall back to silent if pool empty or library missing
	return { "type": "silent" }
