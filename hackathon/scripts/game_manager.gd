extends Node

var bpm_data = []
var beat_index = 0
var music_player: AudioStreamPlayer  # ✅ Correct type

const START_TIME := 36.216604167

func _ready():
	load_bpm_data()
	music_player = $AudioStreamPlayer
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.play()
	await get_tree().process_frame
	music_player.seek(START_TIME)
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

func trigger_beat_event(beat_info):
	print("Beat at:", beat_info["time"], "BPM:", beat_info["bpm"])
