extends Node
class_name ColorManager

# --- SHADER SYSTEM REFERENCES ---
@onready var canvas_layer: CanvasLayer  # Overlay layer for shader
@onready var color_rect: ColorRect      # Full-screen rect with shader
@onready var shader_material: ShaderMaterial  # The actual shader

# --- CAMERA SYSTEM ---
var player_camera: Camera2D  # Reference to player's camera for world-to-screen conversion

# --- EFFECT MANAGEMENT ---
var active_bleed_events: Array[ColorBleedEvent] = []

# --- ANIMATION PARAMETERS ---
@export var max_bleed_radius: float = 120.0
@export var grow_duration: float = 1.0
@export var stay_duration: float = 0.5
@export var shrink_duration: float = 1.0

# --- COLOR FADE PARAMETERS ---
var color_fade_timer: float = 0.0
const COLOR_FADE_DURATION: float = 10.0  # seconds

# --- INITIALIZATION ---
func _ready():
	add_to_group("color_manager")  # Auto-register to group
	call_deferred("_deferred_ready")

func _deferred_ready():
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_camera = player_node.get_node("Camera2D") as Camera2D
		if not player_camera:
			print("Warning: Player Camera not found! Color effect will not work.")
	await get_tree().process_frame
	setup_shader()

# --- MAIN UPDATE LOOP ---
func _physics_process(_delta: float) -> void:
	if not player_camera or not shader_material:
		return
	update_bleed_events()
	update_shader_parameters()

func _process(delta: float) -> void:
	# Gradually fade in color within the first 10 seconds
	if shader_material and color_fade_timer < COLOR_FADE_DURATION:
		color_fade_timer += delta
		var t: float = clamp(color_fade_timer / COLOR_FADE_DURATION, 0.0, 1.0)
		var color_strength: float = lerp(0.0, 1.0, t)
		var grayscale_strength: float = lerp(1.0, 0.0, t)
		shader_material.set_shader_parameter("color_strength", color_strength)
		shader_material.set_shader_parameter("grayscale_strength", grayscale_strength)

# --- BLEED EVENT LIFECYCLE ---
func create_new_bleed_event(platform_global_pos: Vector2) -> void:
	for event in active_bleed_events:
		if event.position == platform_global_pos:
			return
	var new_event: ColorBleedEvent = ColorBleedEvent.new()
	new_event.position = platform_global_pos
	new_event.max_radius = max_bleed_radius
	new_event.state = 0
	active_bleed_events.append(new_event)
	print("Created bleed event at world position: ", platform_global_pos)

	var grow_tween: Tween = create_tween()
	grow_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	grow_tween.tween_property(new_event, "current_radius", new_event.max_radius, grow_duration)
	grow_tween.tween_interval(stay_duration)
	grow_tween.tween_callback(shrink_event.bind(new_event))

func shrink_event(event: ColorBleedEvent) -> void:
	event.state = 2
	var shrink_tween: Tween = create_tween()
	shrink_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	shrink_tween.tween_property(event, "current_radius", 0.0, shrink_duration)
	shrink_tween.tween_callback(remove_event.bind(event))

func remove_event(event: ColorBleedEvent) -> void:
	event.event_finished = true

func update_bleed_events() -> void:
	var events_to_remove: Array[ColorBleedEvent] = []
	for event in active_bleed_events:
		if event.event_finished:
			events_to_remove.append(event)
	for event in events_to_remove:
		active_bleed_events.erase(event)

func update_shader_parameters() -> void:
	if not player_camera or not shader_material:
		return

	var event_data_array: Array[Vector4] = []

	var camera_world_pos: Vector2 = player_camera.global_position
	var camera_zoom: Vector2 = player_camera.zoom
	var camera_rotation: float = player_camera.global_rotation
	var camera_offset: Vector2 = player_camera.offset
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	for i in range(min(active_bleed_events.size(), 64)):
		var event: ColorBleedEvent = active_bleed_events[i]
		event_data_array.append(Vector4(event.position.x, event.position.y, event.current_radius, 0.0))

	shader_material.set_shader_parameter("bleed_events", event_data_array)
	shader_material.set_shader_parameter("num_events", event_data_array.size())
	shader_material.set_shader_parameter("camera_world_pos", camera_world_pos)
	shader_material.set_shader_parameter("camera_zoom", camera_zoom)
	shader_material.set_shader_parameter("camera_rotation", camera_rotation)
	shader_material.set_shader_parameter("camera_offset", camera_offset)
	shader_material.set_shader_parameter("viewport_size", viewport_size)

# --- SHADER SETUP ---
func setup_shader() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)

	color_rect = ColorRect.new()
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.material = ShaderMaterial.new()
	color_rect.material.shader = preload("res://shader/grayscale_color.gdshader")

	shader_material = color_rect.material
	shader_material.set_shader_parameter("color_strength", 0.0)
	shader_material.set_shader_parameter("grayscale_strength", 1.0)
	canvas_layer.add_child(color_rect)

# --- RUNTIME SHADER CONTROL ---
func set_color_strength(strength: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("color_strength", strength)

func set_grayscale_strength(strength: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("grayscale_strength", strength)
