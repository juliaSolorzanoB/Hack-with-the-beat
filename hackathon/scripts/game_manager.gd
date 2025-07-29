extends Node

var bpm_data = []
var beat_index = 0
var music_player: AudioStreamPlayer

const START_TIME := 36.216604167

func _ready():
	load_bpm_data()

	# Find AudioStreamPlayer node
	music_player = $AudioStreamPlayer
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS

	# Seek and play
	music_player.play()
	await get_tree().process_frame
	music_player.seek(START_TIME)

	# Start at the correct beat
	beat_index = get_starting_beat_index(START_TIME)

func load_bpm_data():
	var file = FileAccess.open("res://song_data/riddim.json", FileAccess.READ)
	if file:
		bpm_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		push_error("Failed to load riddim.json!")

func get_starting_beat_index(start_time: float) -> int:
	for i in bpm_data.size():
		if bpm_data[i]["time"] >= start_time:
			return i
	return bpm_data.size()

func _process(_delta):
	if beat_index >= bpm_data.size():
		return

	var song_time = music_player.get_playback_position() + START_TIME
	var beat_time = bpm_data[beat_index]["time"]

	if song_time >= beat_time:
		trigger_beat_event(bpm_data[beat_index])
		beat_index += 1

func trigger_beat_event(_beat_info: Dictionary):
	var player = get_tree().get_first_node_in_group("player")
	var color_manager = get_tree().get_first_node_in_group("color_manager")
	if player and color_manager:
		var forward_position = player.global_position + Vector2(200, 0)
		color_manager.create_new_bleed_event(forward_position)
