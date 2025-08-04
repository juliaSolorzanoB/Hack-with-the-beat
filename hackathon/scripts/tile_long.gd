extends StaticBody2D # tle.gd
# Emits a signal and triggers a visual effect when the player enters its detection area.i

signal tile_hit  # Signal when the player lands on the tile.

# --- NODE REFERENCES ---
var color_manager: ColorManager
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $Area2D

# --- TRIGGER STATE MANAGEMENT ---
var is_active_trigger: bool = false
var trigger_cooldown_timer: float = 0.0
const TRIGGER_COOLDOWN_TIME: float = 0.1 # A short cooldown to prevent multiple triggers from one hit.

# --- VISUAL EFFECT POSITIONING ---
@export var bleed_offset: Vector2 = Vector2(0, 0) # Allows fine-tuning the visual effect's position.

func _ready() -> void:
	call_deferred("_find_color_manager")
	detection_area.body_entered.connect(_on_player_entered)
	detection_area.body_exited.connect(_on_player_exited)

func _process(delta: float) -> void:
	# Update the cooldown timer.
	if trigger_cooldown_timer > 0:
		trigger_cooldown_timer -= delta

func _find_color_manager() -> void:
	# Find the ColorManager node in the scene tree.
	color_manager = get_tree().root.find_child("ColorManager", true, false)

func _on_player_entered(body: Node2D) -> void:
	# Check if the entering body is the player and if the tile is ready to trigger.
	if (body.is_in_group("player") and 
		color_manager and 
		not is_active_trigger and 
		trigger_cooldown_timer <= 0):
		
		is_active_trigger = true
		trigger_cooldown_timer = TRIGGER_COOLDOWN_TIME
		
		# Create the color bleed visual effect at an adjusted position.
		var event_position = global_position + bleed_offset
		color_manager.create_new_bleed_event(event_position)
		
		# Emit the signal to inform other systems (e.g., the MusicManager).
		tile_hit.emit()

func _on_player_exited(body: Node2D) -> void:
	# Reset the trigger state when the player leaves the tile.
	if body.is_in_group("player"):
		is_active_trigger = false
