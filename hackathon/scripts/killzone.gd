extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var death_timer: Timer = $Timer

func _ready() -> void:
	# FORCE collision layer/mask settings
	collision_layer = 4  # Kill zone layer
	collision_mask = 2   # Player layer
	
	# Make sure monitoring is enabled
	monitoring = true
	monitorable = true
	
	print("🔥 KILL ZONE SETUP:")
	print("   Position: ", global_position)
	print("   Collision Layer: ", collision_layer)
	print("   Collision Mask: ", collision_mask)
	print("   Monitoring: ", monitoring)
	print("   Monitorable: ", monitorable)
	
	# Create collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(64, 64)
		collision_shape.shape = rect_shape
		add_child(collision_shape)
		print("   Created new collision shape")
	else:
		print("   Using existing collision shape: ", collision_shape.shape.get_class())
		if collision_shape.shape is RectangleShape2D:
			var rect = collision_shape.shape as RectangleShape2D
			print("   Shape size: ", rect.size)
	
	# Create timer if it doesn't exist
	if not death_timer:
		death_timer = Timer.new()
		death_timer.wait_time = 2.0
		death_timer.one_shot = true
		add_child(death_timer)
		print("   Created new timer")
	
	# Connect signals with extra debugging
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("   ✓ Connected body_entered signal")
	
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		print("   ✓ Connected body_exited signal")
	
	if not death_timer.timeout.is_connected(_on_death_timer_timeout):
		death_timer.timeout.connect(_on_death_timer_timeout)
		print("   ✓ Connected timer signal")
	
	# Test what bodies are already overlapping
	call_deferred("check_initial_overlaps")

func check_initial_overlaps():
	var overlapping_bodies = get_overlapping_bodies()
	print("🔍 INITIAL OVERLAP CHECK:")
	print("   Bodies found: ", overlapping_bodies.size())
	for body in overlapping_bodies:
		print("   - ", body.name, " (", body.get_class(), ") at ", body.global_position)
		print("     Groups: ", body.get_groups())
		print("     Collision layer: ", body.collision_layer)
		print("     Collision mask: ", body.collision_mask)

func _on_body_entered(body: Node2D) -> void:
	print("🚨 BODY ENTERED KILL ZONE!")
	print("   Body name: ", body.name)
	print("   Body type: ", body.get_class())
	print("   Body position: ", body.global_position)
	print("   Kill zone position: ", global_position)
	print("   Body groups: ", body.get_groups())
	print("   Body collision layer: ", body.collision_layer)
	print("   Body collision mask: ", body.collision_mask)
	
	# Check if it's a CharacterBody2D
	if body is CharacterBody2D:
		print("   ✓ Is CharacterBody2D")
		
		# Check if it's in player group
		if body.is_in_group("player"):
			print("   ✓ Is in player group")
			print("💀 PLAYER DEATH TRIGGERED!")
			
			var player_character = body as CharacterBody2D
			if player_character.has_method("die"):
				print("   ✓ Player has die() method - calling it")
				player_character.die()
			else:
				print("   ❌ Player doesn't have die() method")
			
			Engine.time_scale = 0.5
			death_timer.start()
			print("   Death timer started")
		else:
			print("   ❌ Not in player group")
			print("   Available groups: ", body.get_groups())
	else:
		print("   ❌ Not a CharacterBody2D, is: ", body.get_class())

func _on_body_exited(body: Node2D) -> void:
	print("🚪 BODY EXITED KILL ZONE: ", body.name)

func _on_death_timer_timeout() -> void:
	print("💀 Death timer timeout - reloading scene")
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func set_width(width: float):
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size.x = width
		rect_shape.size.y = 64.0
		print("📏 Kill zone size set to: ", rect_shape.size)
	else:
		print("❌ Cannot set width - no valid collision shape")

# Debug function to manually test collision
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space key
		print("🧪 MANUAL COLLISION TEST:")
		check_initial_overlaps()

# Continuous monitoring for debugging
var debug_timer = 0.0
func _process(delta):
	debug_timer += delta
	if debug_timer > 2.0:  # Every 2 seconds
		debug_timer = 0.0
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var distance = global_position.distance_to(player.global_position)
			if distance < 100:  # Only debug when player is nearby
				print("🔍 NEARBY PLAYER DEBUG:")
				print("   Kill zone: ", global_position)
				print("   Player: ", player.global_position)
				print("   Distance: ", distance)
				print("   Overlapping bodies: ", get_overlapping_bodies().size())
