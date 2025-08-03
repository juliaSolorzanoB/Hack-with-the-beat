extends StaticBody2D

# --- NODE REFERENCES ---
var color_manager: ColorManager  # Found dynamically at runtime
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $Area2D  # Detects player proximity

# --- TRIGGER STATE MANAGEMENT ---
var is_active_trigger: bool = false           # Prevents multiple triggers
var trigger_cooldown_timer: float = 0.0       # Prevents rapid triggering
const TRIGGER_COOLDOWN_TIME: float = 0.1

# --- VISUAL EFFECT POSITIONING ---
# Important: fine-tuning where the color bleed effect appears relative to tile
@export var bleed_offset: Vector2 = Vector2(0, 0)

# --- INITIALIZATION ---
func _ready() -> void:
	# Defer to ensure all nodes are ready before searching
	call_deferred("_find_color_manager")
	
	# Connect player detection signals
	detection_area.body_entered.connect(_on_player_entered)
	detection_area.body_exited.connect(_on_player_exited)

func _process(delta: float) -> void:
	#Update cooldown timer to prevent spam triggering.
	if trigger_cooldown_timer > 0:
		trigger_cooldown_timer -= delta

# --- SYSTEM CONNECTIONS ---
func _find_color_manager() -> void:
	#Dynamically finds the ColorManager in the scene tree.
	color_manager = get_tree().root.find_child("ColorManager", true, false)
	
	# DELETE LATER - debuging purposes
	if color_manager:
		print(name, ": ColorManager successfully found!")
	else:
		printerr(name, ": Warning: ColorManager not found!")

# --- PLAYER INTERACTION ---
func _on_player_entered(body: Node2D) -> void:
	# When player touches this tile, create a color bleed effect.
	# safety checks prevent duplicate or invalid triggers.
	if (body.is_in_group("player") and 
		color_manager and 
		not is_active_trigger and 
		trigger_cooldown_timer <= 0):
		
		is_active_trigger = true
		trigger_cooldown_timer = TRIGGER_COOLDOWN_TIME
		
		# Apply offset for precise effect positioning
		var event_position = global_position + bleed_offset
		
		# Create the visual effect at the calculated position
		color_manager.create_new_bleed_event(event_position)
		# DELETE LATER - debuging purposes
		print(name, ": Creating new color bleed event at adjusted position.")

func _on_player_exited(body: Node2D) -> void:
	#Reset trigger state when player leaves tile area.
	if body.is_in_group("player"):
		is_active_trigger = false
