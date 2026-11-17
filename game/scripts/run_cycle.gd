extends RefCounted
## Approved 013--029 run cycle. Keep one pivot and scale across all 17 poses.
const COUNT := 17
const FPS := 24.0
const DURATION := COUNT / FPS
const DIRECTORY := "res://assets/char/run_cycle_v1/"

static func load_frames() -> Array:
	var result: Array = []
	for i in range(1, COUNT + 1):
		result.append(load(DIRECTORY + "%02d.png" % i))
	return result

static func prepare_origins(game: Node) -> void:
	var clip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "manifest.json"))
	assert(int(clip.count) == COUNT and is_equal_approx(float(clip.loop_seconds), DURATION))
	for i in range(COUNT):
		game.pose_origins["walk_v2"].append(Vector2(float(clip.origin[0]), float(clip.origin[1])))
		game.pose_scales["walk_v2"].append(float(clip.scale))
		game.pose_heights["walk_v2"].append(float(clip.pixel_heights[i]) * float(clip.scale))
