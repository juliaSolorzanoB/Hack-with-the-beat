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

# --- ANIMATION PARAMETERS ---
# control how color bleed effects animate over time
@export var max_bleed_radius: float = 120.0  # Maximum size of color spots
@export var grow_duration: float = 1.0       # Time to grow to full size
@export var stay_duration: float = 0.5       # Time to stay at full size
@export var shrink_duration: float = 1.0     # Time to shrink away

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
			# DELETE LATER - debuging purposes
			print("Warning: Player Camera not found! The color effect will not work.")
	
	await get_tree().process_frame
	setup_shader()

# --- MAIN UPDATE LOOP ---
func _physics_process(_delta):
	# Main update loop that manages all active bleed events and updates shader. - Runs every physics frame for smooth animation.
	if not player_camera or not shader_material:
		return

	# Clean up finished events and update active ones
	update_bleed_events()
	
	# Send current event data to the shader for rendering
	update_shader_parameters()

# --- BLEED EVENT LIFECYCLE ---
func create_new_bleed_event(platform_global_pos: Vector2):
	# Creates a new color bleed effect at the specified world position. - Prevents duplicate events at the same location.
	for event in active_bleed_events:
		if event.position == platform_global_pos:
			return

	# Create new event object
	var new_event = ColorBleedEvent.new()  
	new_event.position = platform_global_pos
	new_event.max_radius = max_bleed_radius
	new_event.state = 0 # Start in the growing state
	active_bleed_events.append(new_event)
	# DELETE LATER - debuging purposes
	print("Created bleed event at world position: ", platform_global_pos)
	
	# Animate the growing phase with smooth easing
	var grow_tween = create_tween()
	grow_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	grow_tween.tween_property(new_event, "current_radius", new_event.max_radius, grow_duration)

	# Stay at full size, then begin shrinking
	grow_tween.tween_interval(stay_duration)
	grow_tween.tween_callback(shrink_event.bind(new_event))

func shrink_event(event: ColorBleedEvent):
	"""Begins the shrinking animation for a bleed event."""
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
	# This is where world coordinates are converted to shader-usable data.
	if not player_camera or not shader_material:
		return

	var event_data_array: Array = []
	
	# Gather all camera properties needed for world-to-screen conversion
	var camera_world_pos = player_camera.global_position
	var camera_zoom = player_camera.zoom
	var camera_rotation = player_camera.global_rotation 
	var camera_offset = player_camera.offset
	var viewport_size = get_viewport().get_visible_rect().size
	
	# DELETE LATER - debuging purposes
	# DEBUG: Print detailed info when events are active (for troubleshooting)
	if active_bleed_events.size() > 0:
		print("=== SHADER UPDATE DEBUG ===")
		print("Camera world pos: ", camera_world_pos)
		print("Camera offset: ", camera_offset)
		print("Camera zoom: ", camera_zoom)
		print("Camera rotation: ", camera_rotation)
		print("Viewport size: ", viewport_size)
		print("Active events count: ", active_bleed_events.size())
		if active_bleed_events.size() > 0:
			print("First event position: ", active_bleed_events[0].position)
			print("First event radius: ", active_bleed_events[0].current_radius)
		print("============================")
		
		# Additional debug: player position and distance calculations
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			print("Current player position: ", player_node.global_position)
			print("Distance from event to player: ", active_bleed_events[0].position.distance_to(player_node.global_position))
		
		print("Screen center should map to world pos: ", camera_world_pos)
		print("============================")
		
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
	# Create overlay layer (high priority to render on top)
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # Render above everything else
	add_child(canvas_layer)
	
	# Create full-screen rectangle for shader
	color_rect = ColorRect.new()
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.material = ShaderMaterial.new()
	color_rect.material.shader = preload("res://shader/grayscale_color.gdshader")
	
	# Configure shader parameters
	shader_material = color_rect.material
	shader_material.set_shader_parameter("color_strength", 0.7)    # How much color shows in bleed areas
	shader_material.set_shader_parameter("grayscale_strength", 0.9) # How gray the base image is
	canvas_layer.add_child(color_rect)

# --- RUNTIME SHADER CONTROL ---
func set_color_strength(strength: float):
	#Adjusts how much color is revealed in bleed areas (0.0 = no color, 1.0 = full color).
	if shader_material:
		shader_material.set_shader_parameter("color_strength", strength)

func set_grayscale_strength(strength: float):
	# (0.0 = no color, 1.0 = full grayscale)
	if shader_material:
		shader_material.set_shader_parameter("grayscale_strength", strength)
