extends Node
class_name ColorManager

# --- SHADER SYSTEM REFERENCES ---
@onready var canvas_layer: CanvasLayer  # Overlay layer for shader
@onready var color_rect: ColorRect      # Full-screen rect with shader
@onready var shader_material: ShaderMaterial  # The actual shader

# --- CAMERA SYSTEM ---
var player_camera: Camera2D  # Reference to player's camera for world-to-screen conversion

# --- EFFECT MANAGEMENT ---
# Array holding all active color bleed events
var active_bleed_events: Array[ColorBleedEvent] = []

# --- PROGRESSIVE RADIUS SYSTEM - UPDATED FOR 50-400 RANGE ---
@export var min_bleed_radius: float = 50.0   # Starting radius
@export var max_bleed_radius: float = 400.0  # Maximum radius when fully progressed
var current_max_radius: float = 50.0         # Current maximum radius (grows over time)

# --- PROGRESS TRACKING SYSTEM ---
var game_progress_percentage: float = 0.0    # 0.0 to 100.0 progress through the game

# --- ANIMATION PARAMETERS ---
# control how color bleed effects animate over time
@export var grow_duration: float = 1.0       # Time to grow to full size
@export var stay_duration: float = 0.5       # Time to stay at full size
@export var shrink_duration: float = 1.0     # Time to shrink away

# --- DEATH EFFECT SYSTEM ---
var is_death_mode: bool = false
var death_fade_tween: Tween

# --- INITIALIZATION ---
func _ready():
	# Defer to ensure player exists and is in the "player" group
	call_deferred("_deferred_ready")

func _deferred_ready():
	# Sets up camera reference and shader system after scene is fully loaded.
	# Important: for world-to-screen coordinate conversion.
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_camera = player_node.get_node("Camera2D")
		if not player_camera:
			print("Warning: Player Camera not found! The color effect will not work.")
	
	await get_tree().process_frame
	setup_shader()

# --- MAIN UPDATE LOOP ---
func _physics_process(delta):
	# Main update loop that manages all active bleed events and updates shader.
	if not player_camera or not shader_material:
		return

	# FIXED: Update progression every frame to track music progress
	update_progression()
	
	# Clean up finished events and update active ones
	update_bleed_events()
	
	# Send current event data to the shader for rendering
	update_shader_parameters()

# --- PROGRESSIVE RADIUS SYSTEM - FIXED PROGRESS TRACKING ---
func update_progression():
	"""Updates the maximum bleed radius based on music playback progress."""
	# Get music manager to track actual music progress
	var music_manager = get_tree().root.find_child("MusicManager", true, false)
	if not music_manager:
		print("DEBUG: MusicManager not found")
		return
	
	# Check if music is actually playing
	if not music_manager.is_playing:
		print("DEBUG: Music not playing")
		return
	
	# Calculate progress based on music playback time vs total music duration
	var current_time = 0.0
	var total_duration = 0.0
	
	if music_manager.audio_players.size() > 0 and music_manager.audio_players[0]:
		var audio_player = music_manager.audio_players[0]
		if audio_player.stream and audio_player.is_playing():
			current_time = audio_player.get_playback_position()
			total_duration = audio_player.stream.get_length()
		else:
			print("DEBUG: No stream or not playing - Stream: ", audio_player.stream != null, " Playing: ", audio_player.is_playing())
			return
	else:
		print("DEBUG: No audio players available")
		return
	
	if total_duration > 0:
		# Calculate progress as percentage of music completion
		game_progress_percentage = (current_time / total_duration) * 100.0
		game_progress_percentage = clamp(game_progress_percentage, 0.0, 100.0)
		
		# Convert percentage to 0.0-1.0 for radius calculation
		var progression = game_progress_percentage / 100.0
		
		# FIXED: Direct linear interpolation from 50 to 400
		current_max_radius = min_bleed_radius + (progression * (max_bleed_radius - min_bleed_radius))
		current_max_radius = clamp(current_max_radius, min_bleed_radius, max_bleed_radius)
		
		# DEBUG: Print every 5% progress change
		var progress_rounded = int(game_progress_percentage / 5) * 5
		if progress_rounded > 0 and progress_rounded % 5 == 0:
			print("Music Progress: ", game_progress_percentage, "% | Current max radius: ", current_max_radius, " | Time: ", current_time, "/", total_duration)
	else:
		print("DEBUG: Total duration is 0")

# --- BLEED EVENT LIFECYCLE ---
func create_new_bleed_event(platform_global_pos: Vector2):
	# Creates a new color bleed effect at the specified world position.
	
	# Don't create new events during death mode
	if is_death_mode:
		return
	
	# Prevent duplicate events at the same location
	for event in active_bleed_events:
		if event.position == platform_global_pos:
			return

	# FIXED: Always update progression before creating new event
	update_progression()

	# Create new event object with current max radius
	var new_event = ColorBleedEvent.new()  
	new_event.position = platform_global_pos
	new_event.max_radius = current_max_radius  # Use progressive radius
	new_event.state = 0 # Start in the growing state
	active_bleed_events.append(new_event)
	
	print("Created bleed event at world position: ", platform_global_pos, " with max radius: ", current_max_radius)
	
	# Animate the growing phase with smooth easing
	var grow_tween = create_tween()
	grow_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	grow_tween.tween_property(new_event, "current_radius", new_event.max_radius, grow_duration)

	# Stay at full size, then begin shrinking (unless in death mode)
	grow_tween.tween_interval(stay_duration)
	grow_tween.tween_callback(shrink_event.bind(new_event))

func shrink_event(event: ColorBleedEvent):
	"""Begins the shrinking animation for a bleed event."""
	# Don't shrink during death mode - events are cleared differently
	if is_death_mode:
		return
		
	event.state = 2  # 2 = shrinking
	
	# Animate shrinking with smooth easing
	var shrink_tween = create_tween()
	shrink_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	shrink_tween.tween_property(event, "current_radius", 0.0, shrink_duration)
	
	# Mark for removal when shrinking is complete
	shrink_tween.tween_callback(remove_event.bind(event))

func remove_event(event: ColorBleedEvent):
	# Marks an event as finished so it can be cleaned up.
	event.event_finished = true

func update_bleed_events():
	# Remove finished events from list
	var events_to_remove = []
	for event in active_bleed_events:
		if event.event_finished:
			events_to_remove.append(event)
	for event in events_to_remove:
		active_bleed_events.erase(event)

func update_shader_parameters():
	# Sends current camera and bleed event data to the shader.
	if not player_camera or not shader_material:
		return

	var event_data_array: Array = []
	
	# Gather all camera properties needed for world-to-screen conversion
	var camera_world_pos = player_camera.global_position
	var camera_zoom = player_camera.zoom
	var camera_rotation = player_camera.global_rotation 
	var camera_offset = player_camera.offset
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Convert bleed events to shader-compatible format
	# Shader expects Vector4 arrays: (x, y, radius, unused)
	for i in range(min(active_bleed_events.size(), 64)):  # Shader limit: 64 events
		var event = active_bleed_events[i]
		event_data_array.append(Vector4(event.position.x, event.position.y, event.current_radius, 0.0))

	# Send all data to shader
	shader_material.set_shader_parameter("bleed_events", event_data_array)
	shader_material.set_shader_parameter("num_events", event_data_array.size())
	shader_material.set_shader_parameter("camera_world_pos", camera_world_pos)
	shader_material.set_shader_parameter("camera_zoom", camera_zoom)
	shader_material.set_shader_parameter("camera_rotation", camera_rotation)
	shader_material.set_shader_parameter("camera_offset", camera_offset)
	shader_material.set_shader_parameter("viewport_size", viewport_size)

# --- SHADER SETUP ---
func setup_shader():
	# Creates the full-screen shader overlay system.
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # Render above everything else
	add_child(canvas_layer)
	
	# Create full-screen rectangle for shader
	color_rect = ColorRect.new()
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.material = ShaderMaterial.new()
	color_rect.material.shader = preload("res://shader/grayscale_color.gdshader")
	
	# Configure shader parameters - FIXED VALUES, NO MUSIC INTERFERENCE
	shader_material = color_rect.material
	shader_material.set_shader_parameter("color_strength", 0.7)    # Fixed color strength
	shader_material.set_shader_parameter("grayscale_strength", 0.9) # Fixed grayscale strength
	canvas_layer.add_child(color_rect)

# --- DEATH EFFECT SYSTEM ---
func trigger_death_fade():
	#FIXED: Triggers the death effect by immediately starting shrink animations for ALL active bleed events simultaneously.
	print("Triggering death fade effect...")
	is_death_mode = true
	
	# Stop any existing death fade
	if death_fade_tween:
		death_fade_tween.kill()
		
	# Create a new tween to fade the global grayscale strength
	death_fade_tween = create_tween()
	death_fade_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	death_fade_tween.tween_property(shader_material, "shader_parameter/grayscale_strength", 1.0, 2.0)
	
	# FIXED: Immediately start shrinking ALL active events together
	if not active_bleed_events.is_empty():
		print("Starting death shrink for ", active_bleed_events.size(), " active bleed events")
		
		for event in active_bleed_events:
			# Change state to shrinking
			event.state = 2
			
			# Create individual shrink tween for each event
			var fade_tween = create_tween()
			fade_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			fade_tween.tween_property(event, "current_radius", 0.0, shrink_duration)
			fade_tween.tween_callback(remove_event.bind(event))
	else:
		print("No active bleed events to shrink during death")

# --- PROGRESS TRACKING FUNCTIONS ---
func get_game_progress_percentage() -> float:
	#Returns current game progress as a percentage (0.0 to 100.0).
	return game_progress_percentage

# --- DEBUG FUNCTIONS ---
func get_current_max_radius() -> float:
	#Returns current maximum radius for debugging.
	return current_max_radius

func get_progression_info() -> Dictionary:
	#Returns progression information for debugging.
	return {
		"game_progress_percentage": game_progress_percentage,
		"current_max_radius": current_max_radius,
		"min_radius": min_bleed_radius,
		"max_radius": max_bleed_radius,
		"is_death_mode": is_death_mode,
		"active_events": active_bleed_events.size()
	}

func clear_all_bleed_events():
	#Immediately removes all active bleed events.
	for event in active_bleed_events:
		event.event_finished = true
	
	# Force immediate cleanup
	update_bleed_events()
	
	print("All bleed events cleared. Remaining events: ", active_bleed_events.size())
