extends Area2D

# --- Node References ---
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var death_timer: Timer = $Timer

# --- Initialization and Setup ---
func _ready() -> void:
	# Enforce specific collision layer and mask settings for the kill zone.
	collision_layer = 4  # The layer this Area2D exists on (Kill Zone).
	collision_mask = 2   # The layers it will detect (Player).
	
	# Ensure the Area2D is active for collision detection.
	monitoring = true
	monitorable = true
	
	# Dynamically creates a collision shape if one isn't already assigned.
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(64, 64)
		collision_shape.shape = rect_shape
		add_child(collision_shape)
	
	# Dynamically creates a timer if one isn't already assigned.
	if not death_timer:
		death_timer = Timer.new()
		death_timer.wait_time = 2.0
		death_timer.one_shot = true
		add_child(death_timer)
	
	# Connects the necessary signals to their corresponding functions.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	if not death_timer.timeout.is_connected(_on_death_timer_timeout):
		death_timer.timeout.connect(_on_death_timer_timeout)
	
	# A deferred call to check for any bodies already overlapping the kill zone
	# at the start of the scene, which is useful for debugging.
	call_deferred("check_initial_overlaps")

# --- Debugging Functions ---
func check_initial_overlaps():
	# Prints information about any bodies that are already overlapping.
	var overlapping_bodies = get_overlapping_bodies()
	for body in overlapping_bodies:
		# Displays body's name, type, position, groups, layers, and masks for debugging.
		pass 

# --- Core Game Logic ---
func _on_body_entered(body: Node2D) -> void:
	# This function is triggered whenever a body enters the Area2D.
	
	if body is CharacterBody2D and body.is_in_group("player"):
		# If the player is found, it triggers the death sequence.
		
		var player_character = body as CharacterBody2D
		if player_character.has_method("die"):
			player_character.die()
		
		# Slows down the game's time scale to create a "bullet-time" death effect.
		Engine.time_scale = 0.5
		
		# Starts the timer which will reload the scene after a delay.
		death_timer.start()

func _on_body_exited(body: Node2D) -> void:
	# This signal is triggered when a body leaves the kill zone.
	pass

func _on_death_timer_timeout() -> void:
	# It resets the game's time scale and reloads the current scene.
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

# --- Utility Functions ---
func set_width(width: float):
	# A helper function to dynamically change the width of the kill zone.
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size.x = width
		rect_shape.size.y = 64.0 # Height is fixed
