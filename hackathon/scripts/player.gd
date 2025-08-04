extends CharacterBody2D # Player.gd
# Manages movement, jumping, animations, and death state.

# --- MOVEMENT CONFIGURATION ---
@export var initial_speed: float = 75.0      # Starting horizontal speed.
@export var max_speed: float = 80.0          # Maximum horizontal speed.
@export var acceleration_rate: float = 5.0   # Rate at which the player accelerates on the ground.

# --- JUMP SYSTEM PARAMETERS ---
@export_group("Single Jump")
@export var single_jump_velocity: float = -320.0        # Upward velocity for a quick tap jump.
@export var single_jump_extra_fall_force: float = 680.0 # Extra gravity for a faster fall after a single jump.

@export_group("Bunny Hop Jump")
@export var bunny_hop_velocity: float = -340.0          # Upward velocity for a held jump.
@export var bunny_hop_extra_fall_force: float = 370.0   # Less extra gravity for a smoother fall during a bunny hop.
@export var bunny_hop_lockout_duration: float = 0.2    # Cooldown to prevent spamming bunny hops.

# --- RUNTIME STATE VARIABLES ---
var current_speed: float = 0.0               # The player's current horizontal speed.
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_lockout_timer: float = 0.0          # Timer for the bunny hop cooldown.
var can_move: bool = true                    # Flag to disable player input, e.g., on death.

# Jump type tracking - determines which fall physics to apply.
enum JumpType { NONE, SINGLE_JUMP, BUNNY_HOP }
var current_jump_type: JumpType = JumpType.NONE

# --- NODE REFERENCES ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

# --- CAMERA SETUP ---
var camera_fixed_y: float = 0.0 # Stores the initial Y position to create a side-scrolling effect.

# --- INITIALIZATION ---
func _ready() -> void:
	current_speed = initial_speed
	# The character is always facing right in this game, so we don't need to flip the sprite.
	animated_sprite.flip_h = false
	add_to_group("player")  # Add the player to a group for easy detection by other nodes like tiles.
	camera.make_current()

	# Lock the camera's Y position at game start.
	camera_fixed_y = camera.global_position.y

# --- MAIN GAME LOOP ---
func _physics_process(delta: float) -> void:
	# If the player cannot move (e.g., after dying), just apply gravity.
	if not can_move:
		move_and_slide()
		return

	var on_floor_now = is_on_floor()

	# Apply physics in a specific order for consistent behavior.
	apply_gravity_and_fall_force(delta, on_floor_now)
	update_jump_lockout(delta)
	handle_jump_input(on_floor_now)
	update_horizontal_speed(delta, on_floor_now)
	velocity.x = current_speed
	update_animation(on_floor_now)

	# The main physics function for CharacterBody2D.
	move_and_slide()

	# Enforce the side-scrolling camera behavior by fixing its Y position.
	camera.global_position.y = camera_fixed_y


# --- PHYSICS SYSTEMS ---
func apply_gravity_and_fall_force(delta: float, on_floor: bool) -> void:
	# Applies gravity and additional fall forces based on the current jump type.
	if not on_floor:
		velocity.y += gravity * delta
		
		# Apply different fall forces depending on whether the player did a single jump or a bunny hop.
		match current_jump_type:
			JumpType.SINGLE_JUMP:
				velocity.y += single_jump_extra_fall_force * delta
			JumpType.BUNNY_HOP:
				velocity.y += bunny_hop_extra_fall_force * delta
	else:
		# Reset the jump type when the player lands on the floor.
		if current_jump_type != JumpType.NONE:
			current_jump_type = JumpType.NONE

func update_jump_lockout(delta: float) -> void:
	# Decrements the bunny hop cooldown timer.
	if jump_lockout_timer > 0:
		jump_lockout_timer -= delta

func handle_jump_input(on_floor: bool) -> void:
	# Checks for jump input and executes the appropriate jump type.
	if on_floor and jump_lockout_timer <= 0:
		if Input.is_action_just_pressed("jump"):
			perform_jump(JumpType.SINGLE_JUMP)
		elif Input.is_action_pressed("jump"):
			perform_jump(JumpType.BUNNY_HOP)

func perform_jump(type: JumpType) -> void:
	# Sets the jump velocity and jump type, and starts the bunny hop cooldown if applicable.
	current_jump_type = type
	match type:
		JumpType.SINGLE_JUMP:
			velocity.y = single_jump_velocity
		JumpType.BUNNY_HOP:
			velocity.y = bunny_hop_velocity
			jump_lockout_timer = bunny_hop_lockout_duration

func update_horizontal_speed(delta: float, on_floor: bool) -> void:
	# Automatically accelerates the player while they are on the ground.
	if on_floor:
		current_speed = min(current_speed + acceleration_rate * delta, max_speed)

func update_animation(on_floor: bool) -> void:
	# Switches between "run" and "jump" animations based on whether the player is on the floor.
	var target_animation: String = "jump"
	if on_floor:
		target_animation = "run"

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

func die() -> void:
	# Handles the player's death sequence.
	can_move = false
	if animated_sprite.animation != "dead":
		animated_sprite.play("dead")
	
	# Trigger death-related effects in other managers.
	trigger_death_effects()

func trigger_death_effects():
	# Finds and calls the music and color managers to trigger a fade effect.
	var music_manager = get_tree().root.find_child("MusicManager", true, false)
	if music_manager:
		music_manager.fade_out_music()
	
	var color_manager = get_tree().root.find_child("ColorManager", true, false)
	if color_manager:
		color_manager.trigger_death_fade()
