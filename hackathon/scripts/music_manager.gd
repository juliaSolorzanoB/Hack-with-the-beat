extends Node
class_name MusicManager

signal beat_detected(strength: float, frequency: float, time_stamp: float)
signal music_layer_activated(layer_index: int)
signal music_intensity_changed(intensity: float)

# --- MUSIC DATA ---
var music_data: Array = []
var current_music_index: int = 0
var is_playing: bool = false

# --- AUDIO LAYERS ---
@export var base_music_track: AudioStream
@export var instrument_layer_1: AudioStream
@export var instrument_layer_2: AudioStream
@export var instrument_layer_3: AudioStream

@onready var audio_players: Array[AudioStreamPlayer] = []
var active_layers: int = 0
var max_layers: int = 4

# --- INTENSITY TRACKING ---
var current_beat_intensity: float = 0.0
var intensity_history: Array[float] = []
const INTENSITY_HISTORY_SIZE: int = 10

func _ready():
	# Auto-load base track if not assigned
	if not base_music_track:
		base_music_track = load("res://music/Nightcore - Takedown (Huntrix).mp3")  # Update this path
		if not base_music_track:
			print("ERROR: Could not load base music track")
	
	# Dynamically add AudioStreamPlayer nodes
	for i in range(max_layers):
		var player = AudioStreamPlayer.new()
		player.name = "AudioLayer" + str(i)
		add_child(player)
		audio_players.append(player)
		player.volume_db = -80.0
		player.bus = "Master"

	# Assign streams to the players
	if audio_players.size() > 0 and base_music_track:
		audio_players[0].stream = base_music_track
		print("Base music track assigned successfully")
	if audio_players.size() > 1 and instrument_layer_1:
		audio_players[1].stream = instrument_layer_1
	if audio_players.size() > 2 and instrument_layer_2:
		audio_players[2].stream = instrument_layer_2
	if audio_players.size() > 3 and instrument_layer_3:
		audio_players[3].stream = instrument_layer_3

	load_music_data()

func load_music_data():
	var file_path = "res://music/3music_analysis_data.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var parse_result = JSON.parse_string(json_string)
		if parse_result is Array:
			music_data = parse_result
			print("Loaded ", music_data.size(), " music events from ", file_path)
		else:
			printerr("Error parsing music analysis data JSON from ", file_path)
		file.close()
	else:
		printerr("Error opening music analysis data file: ", file_path)

func start_music():
	if audio_players.is_empty():
		printerr("MusicManager: No audio players set up.")
		return
	
	if not audio_players[0].stream:
		printerr("MusicManager: Base track not assigned to first audio layer.")
		return
	
	print("Starting music with base track...")
	is_playing = true
	audio_players[0].play()
	activate_music_layer(0)

func _process(delta):
	if not is_playing or music_data.is_empty() or audio_players.is_empty() or not audio_players[0].is_playing():
		return
		
	process_music_events()
	update_intensity_tracking()

func process_music_events():
	var current_playback_time = audio_players[0].get_playback_position()
	
	while current_music_index < music_data.size():
		var event = music_data[current_music_index]
		var event_time = event.get("time", 0.0)
		
		if current_playback_time >= event_time:
			var frequency = event.get("dominant_frequency", 1000.0)
			var intensity = event.get("intensity", 0.0)
			
			beat_detected.emit(intensity, frequency, event_time)
			current_beat_intensity = intensity
			
			var tile_generator = get_tree().root.find_child("TileGenerator", true, false)
			if tile_generator and tile_generator.has_method("get_tiles_successfully_hit"):
				check_layer_activation(tile_generator.get_tiles_successfully_hit())
			
			current_music_index += 1
		else:
			break

func check_layer_activation(tiles_hit: int):
	var required_hits = [0, 10, 25, 50]
	
	for i in range(max_layers):
		if i < required_hits.size() and tiles_hit >= required_hits[i] and active_layers <= i:
			activate_music_layer(i)

func activate_music_layer(layer_index: int):
	if layer_index < audio_players.size() and layer_index >= active_layers:
		active_layers = layer_index + 1
		
		var tween = create_tween()
		tween.tween_property(audio_players[layer_index], "volume_db", 0.0, 2.0)
		
		music_layer_activated.emit(layer_index)
		print("Activated music layer: ", layer_index)

func update_intensity_tracking():
	intensity_history.append(current_beat_intensity)
	if intensity_history.size() > INTENSITY_HISTORY_SIZE:
		intensity_history.pop_front()
	
	var avg_intensity = 0.0
	if not intensity_history.is_empty():
		for intensity in intensity_history:
			avg_intensity += intensity
		avg_intensity /= intensity_history.size()
	
	music_intensity_changed.emit(avg_intensity)

func fade_out_music():
	is_playing = false
	for audio_player in audio_players:
		var tween = create_tween()
		tween.tween_property(audio_player, "volume_db", -80.0, 3.0)
