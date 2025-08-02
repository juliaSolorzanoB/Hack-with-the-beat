extends Node

# --- NODE REFERENCES ---
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var player: Node2D = get_tree().get_root().find_child("Player", true, false)
@onready var camera: Camera2D = player.get_node("Camera2D")  # ✅ Fixed: Looks inside Player node

# --- PLATFORM CONFIGURATION ---
var platform_scene: PackedScene = preload("res://scenes/tile.tscn")
var bpm_data: Array = []
var processed_index := 0

# --- PLATFORM SPAWN OFFSETS ---
const SPAWN_X_OFFSET := 50.0   # Distance ahead of player [⬅ EDIT HERE]
const MIN_Y_OFFSET := -10.0    # Vertical range (min) [⬅ EDIT HERE]
const MAX_Y_OFFSET := -30.0    # Vertical range (max) [⬅ EDIT HERE]

func _ready():
	if not player:
		push_error("❌ Player node not found.")
	elif not camera:
		push_error("❌ Camera2D node not found inside Player.")
	else:
		camera.make_current()  # Ensure the camera is active

	_load_bpm_json()
	audio_player.play()

func _process(_delta):
	if processed_index >= bpm_data.size():
		return

	var current_time = audio_player.get_playback_position()
	var next_bpm_event = bpm_data[processed_index]

	if current_time >= next_bpm_event["time"]:
		match next_bpm_event["bpm"]:
			178.21:
				spawn_platform()
			172.27:
				trigger_camera_shake()
		processed_index += 1

func spawn_platform():
	if not player:
		printerr("❌ Player not found, cannot spawn platform.")
		return

	var platform = platform_scene.instantiate()

	# Spawn in front of player, with randomized Y
	var spawn_pos = player.global_position + Vector2(SPAWN_X_OFFSET, randf_range(MIN_Y_OFFSET, MAX_Y_OFFSET))
	platform.global_position = spawn_pos

	get_tree().current_scene.add_child(platform)
	print("✅ Platform spawned at ", spawn_pos)

func trigger_camera_shake():
	if not camera:
		return

	var shake_tween = create_tween()
	var original_offset = camera.offset

	# Simple quick shake
	shake_tween.tween_property(camera, "offset", Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.05)
	shake_tween.tween_property(camera, "offset", original_offset, 0.05).set_delay(0.05)

	print("💥 Camera shake triggered.")

func _load_bpm_json():
	var file = FileAccess.open("res://Song/8bits.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var data = JSON.parse_string(content)
		if typeof(data) == TYPE_ARRAY:
			bpm_data = data
			print("📄 Loaded BPM data: ", bpm_data.size(), " events")
		else:
			push_error("❌ Invalid JSON structure in 8bits.json")
	else:
		push_error("❌ Failed to load 8bits.json")
