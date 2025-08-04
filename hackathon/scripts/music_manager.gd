extends Node
class_name MusicManager

# --- Signals ---
# allow other game components to react to music events.
signal beat_detected(strength: float, frequency: float, time_stamp: float)
signal music_layer_activated(layer_index: int)
signal music_intensity_changed(intensity: float)
signal music_finished_event # Signal emitted when the main music track finishes.

# --- MUSIC DATA ---
var music_data: Array = []        # Stores the parsed beat and event data from a JSON file.
var current_music_index: int = 0  # Index to track the current event being processed from music_data.
var is_playing: bool = false      # Flag to indicate if the music is actively playing.
var music_finished: bool = false  # Flag to indicate if the music has completely finished.

# --- AUDIO LAYERS ---
@export var base_music_track: AudioStream
@export var instrument_layer_1: AudioStream
@export var instrument_layer_2: AudioStream
@export var instrument_layer_3: AudioStream

@onready var audio_players: Array[AudioStreamPlayer] = [] # Array of dynamically created players.
var active_layers: int = 0  # Number of music layers currently active (playing at full volume).
var max_layers: int = 4     # Total number of audio layers available.

# --- INTENSITY TRACKING ---
var current_beat_intensity: float = 0.0 # The intensity of the most recent beat event.
var intensity_history: Array[float] = [] # A history of recent beat intensities to calculate an average.
const INTENSITY_HISTORY_SIZE: int = 10   # The number of past beat intensities to store.

# --- Initialization ---
func _ready():
	# Dynamically creates a set of AudioStreamPlayer nodes to handle music layers.
	for i in range(max_layers):
		var player = AudioStreamPlayer.new()
		player.name = "AudioLayer" + str(i)
		add_child(player)
		audio_players.append(player)
		# Initially set layers to be silent.
		player.volume_db = -80.0
		player.bus = "Master"

	# Assigns the music streams to the created players.
	if audio_players.size() > 0 and base_music_track:
		audio_players[0].stream = base_music_track
	if audio_players.size() > 1 and instrument_layer_1:
		audio_players[1].stream = instrument_layer_1
	if audio_players.size() > 2 and instrument_layer_2:
		audio_players[2].stream = instrument_layer_2
	if audio_players.size() > 3 and instrument_layer_3:
		audio_players[3].stream = instrument_layer_3

	# Loads the music analysis data from a JSON file.
	load_music_data()

# --- Music Data Loading ---
func load_music_data():
	# Loads and parses a JSON file containing pre-analyzed music events.
	var file_path = "res://music/hackathon_music_analysis_data.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var parse_result = JSON.parse_string(json_string)
		if parse_result is Array:
			music_data = parse_result
		file.close()
	else:
		printerr("Error opening music analysis data file: ", file_path)

# --- Music Playback Control ---
func start_music():
	# Starts the music playback.
	is_playing = true
	music_finished = false
	
	# Connects the main audio player's built-in 'finished' signal.
	audio_players[0].finished.connect(check_music_completion)
	
	audio_players[0].play()
	activate_music_layer(0) # Immediately activates the base layer.

func _process(delta):
	# The main update loop for music events and intensity tracking.
	if not is_playing or music_data.is_empty() or audio_players.is_empty():
		return
	
	if audio_players[0].is_playing():
		process_music_events()
		update_intensity_tracking()

# --- Completion Logic ---
# This function is triggered by the 'finished' signal of the main audio player.
func check_music_completion():
	is_playing = false
	music_finished = true
	music_finished_event.emit()
	
	# Reloads the scene to a finished menu when the music ends.
	get_tree().change_scene_to_file("res://scenes/menus/finished_menu.tscn")

# --- Event Processing ---
func process_music_events():
	# Iterates through the music data to emit events based on playback time.
	var current_playback_time = audio_players[0].get_playback_position()
	
	while current_music_index < music_data.size():
		var event = music_data[current_music_index]
		var event_time = event.get("time", 0.0)
		
		# If the current playback time has passed the event's timestamp, process it.
		if current_playback_time >= event_time:
			var frequency = event.get("dominant_frequency", 1000.0)
			var intensity = event.get("intensity", 0.0)
			
			beat_detected.emit(intensity, frequency, event_time)
			current_beat_intensity = intensity
			
			# Checks the number of successfully hit tiles to see if a new music layer should be activated.
			var tile_generator = get_tree().root.find_child("TileGenerator", true, false)
			if tile_generator and tile_generator.has_method("get_tiles_successfully_hit"):
				check_layer_activation(tile_generator.get_tiles_successfully_hit())
			
			current_music_index += 1
		else:
			break

# --- Dynamic Layer Activation ---
func check_layer_activation(tiles_hit: int):
	# Defines the number of hits required to activate each music layer.
	var required_hits = [0, 10, 25, 50]
	
	for i in range(max_layers):
		# Activates a new layer if the player has enough hits and it's not already active.
		if i < required_hits.size() and tiles_hit >= required_hits[i] and active_layers <= i:
			activate_music_layer(i)

func activate_music_layer(layer_index: int):
	# Fades in a specific music layer.
	if layer_index < audio_players.size() and layer_index >= active_layers:
		active_layers = layer_index + 1
		
		# Creates a tween to smoothly fade in the volume of the audio player.
		var tween = create_tween()
		tween.tween_property(audio_players[layer_index], "volume_db", 0.0, 2.0)
		
		music_layer_activated.emit(layer_index)

# --- Intensity Tracking ---
func update_intensity_tracking():
	# Tracks a history of beat intensities to calculate an average.
	intensity_history.append(current_beat_intensity)
	if intensity_history.size() > INTENSITY_HISTORY_SIZE:
		intensity_history.pop_front()
	
	var avg_intensity = 0.0
	if not intensity_history.is_empty():
		for intensity in intensity_history:
			avg_intensity += intensity
		avg_intensity /= intensity_history.size()
	
	# Emits a signal with the average intensity for other systems to use.
	music_intensity_changed.emit(avg_intensity)

func fade_out_music():
	# Fades out all music layers when player dies
	is_playing = false
	for audio_player in audio_players:
		var tween = create_tween()
		tween.tween_property(audio_player, "volume_db", -80.0, 3.0)

# --- Utility Functions ---
func get_music_progress() -> float:
	# Returns the music progress as a percentage for UI elements.
	if audio_players.is_empty() or not audio_players[0].stream or not audio_players[0].is_playing():
		return 0.0
	
	var current_time = audio_players[0].get_playback_position()
	var total_duration = audio_players[0].stream.get_length()
	
	if total_duration > 0:
		return (current_time / total_duration) * 100.0
	
	return 0.0

func get_music_time_info() -> Dictionary:
	# Returns a dictionary with detailed music timing information for debugging.
	if audio_players.is_empty() or not audio_players[0].stream:
		return {"current": 0.0, "total": 0.0, "progress": 0.0, "playing": false, "finished": music_finished}
	
	var audio_player = audio_players[0]
	var current_time = audio_player.get_playback_position()
	var total_duration = audio_player.stream.get_length()
	var progress = (current_time / total_duration * 100.0) if total_duration > 0 else 0.0
	
	return {
		"current": current_time,
		"total": total_duration,
		"progress": progress,
		"playing": audio_player.is_playing(),
		"finished": music_finished
	}
