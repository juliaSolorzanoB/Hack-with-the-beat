extends CharacterBody2D

# --- MOVEMENT CONFIGURATION ---
# control how the player accelerates and moves
@export var initial_speed: float = 75.0      # Starting movement speed
@export var max_speed: float = 80        # Maximum horizontal speed
@export var acceleration_rate: float = 5.0   # How quickly speed increases

# --- JUMP SYSTEM PARAMETERS ---
# Two different jump types with different behaviors
@export_group("Single Jump")
@export var single_jump_velocity: float = -330.0        # Upward force for tap jumps
@export var single_jump_extra_fall_force: float = 680.0 # Extra gravity while falling

@export_group("Bunny Hop Jump")
@export var bunny_hop_velocity: float = -350.0          # Upward force for held jumps
@export var bunny_hop_extra_fall_force: float = 370.0   # Less fall force for smoother hops
@export var bunny_hop_lockout_duration: float = 0.2    # Cooldown between bunny hops

# --- RUNTIME STATE VARIABLES ---
var current_speed: float = 0.0               # Current horizontal movement speed
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_lockout_timer: float = 0.0          # Prevents rapid bunny hopping
var can_move: bool = true                    # Disables movement when player dies

# Jump type tracking - determines which fall physics to apply
enum JumpType { NONE, SINGLE_JUMP, BUNNY_HOP }
var current_jump_type: JumpType = JumpType.NONE

# --- NODE REFERENCES ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

# --- FIXED CAMERA Y POSITION ---
# creates a side-scrolling effect where the camera only follows X movement
var camera_fixed_y: float = 0.0

# --- INITIALIZATION ---
func _ready() -> void:
	current_speed = initial_speed
	animated_sprite.flip_h = false # Makes character face right at all times - disables left flip
	add_to_group("player")  # Important: allows tiles to detect this as player
	camera.make_current()
	
	# Lock the camera's Y position at game start for side-scrolling effect
	camera_fixed_y = camera.global_position.y

# --- MAIN GAME LOOP ---
func _physics_process(delta: float) -> void:
	# Death state: only apply gravity, no player control
	if not can_move:
		move_and_slide()
		return

	var on_floor_now = is_on_floor()

	# Apply physics in order: gravity → jump input → horizontal movement → animation
	apply_gravity_and_fall_force(delta, on_floor_now)
	update_jump_lockout(delta)
	handle_jump_input(on_floor_now)
	update_horizontal_speed(delta, on_floor_now)
	velocity.x = current_speed
	update_animation(on_floor_now)

	move_and_slide()

	# Important: maintain side-scrolling camera behavior
	camera.global_position.y = camera_fixed_y


# --- PHYSICS SYSTEMS ---

func apply_gravity_and_fall_force(delta: float, on_floor: bool) -> void:
	
	# Applies gravity and additional fall forces based on jump type.
	if not on_floor:
		velocity.y += gravity * delta
		
		# based on current jump type
		match current_jump_type:
			JumpType.SINGLE_JUMP:
				# Heavier fall 
				velocity.y += single_jump_extra_fall_force * delta
			JumpType.BUNNY_HOP:
				# Lighter fall 
				velocity.y += bunny_hop_extra_fall_force * delta
	else:
		# Reset jump type when landing
		if current_jump_type != JumpType.NONE:
			current_jump_type = JumpType.NONE

func update_jump_lockout(delta: float) -> void:
	#Updates the bunny hop cooldown timer.
	if jump_lockout_timer > 0:
		jump_lockout_timer -= delta

func handle_jump_input(on_floor: bool) -> void:
	
	# Handles jump input with two different jump types:
	if on_floor and jump_lockout_timer <= 0:
		if Input.is_action_just_pressed("jump"):
			perform_jump(JumpType.SINGLE_JUMP)
		elif Input.is_action_pressed("jump"):
			perform_jump(JumpType.BUNNY_HOP)

func perform_jump(type: JumpType) -> void:
	#Executes the jump with the specified type and sets up fall physics
	current_jump_type = type
	match type:
		JumpType.SINGLE_JUMP:
			velocity.y = single_jump_velocity
		JumpType.BUNNY_HOP:
			velocity.y = bunny_hop_velocity
			jump_lockout_timer = bunny_hop_lockout_duration  # Prevent spam

func update_horizontal_speed(delta: float, on_floor: bool) -> void:
	#Automatically accelerates the player while on ground.
	if on_floor:
		current_speed = min(current_speed + acceleration_rate * delta, max_speed)

func update_animation(on_floor: bool) -> void:
	#Simple animation system: run when grounded, jump when airborne.
	var target_animation: String = "jump"
	if on_floor:
		target_animation = "run"

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

func die() -> void:
	#Called when player dies.
	# Disables movement and plays death animation.
	can_move = false
	if animated_sprite.animation != "dead":
		animated_sprite.play("dead")
	
	# Trigger music fadeout and shader effects
	trigger_death_effects()


func trigger_death_effects():
	print("Player death - triggering effects...")
	
	# Fade out music
	var music_manager = get_tree().root.find_child("MusicManager", true, false)
	if music_manager:
		music_manager.fade_out_music()
		print("Music fade out triggered")
	
	# Trigger shader fade to gray
	var color_manager = get_tree().root.find_child("ColorManager", true, false)
	if color_manager:
		color_manager.trigger_death_fade() # The correct function
		print("Death fade effect triggered")
	else:
		print("WARNING: ColorManager not found for death effects!")
