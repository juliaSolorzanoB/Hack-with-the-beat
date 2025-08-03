extends StaticBody2D

signal tile_hit  # New signal for music progression

# --- NODE REFERENCES ---
var color_manager: ColorManager
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $Area2D

# --- TRIGGER STATE MANAGEMENT ---
var is_active_trigger: bool = false
var trigger_cooldown_timer: float = 0.0
const TRIGGER_COOLDOWN_TIME: float = 0.1

# --- VISUAL EFFECT POSITIONING ---
@export var bleed_offset: Vector2 = Vector2(0, 0)

func _ready() -> void:
	call_deferred("_find_color_manager")
	detection_area.body_entered.connect(_on_player_entered)
	detection_area.body_exited.connect(_on_player_exited)

func _process(delta: float) -> void:
	if trigger_cooldown_timer > 0:
		trigger_cooldown_timer -= delta

func _find_color_manager() -> void:
	color_manager = get_tree().root.find_child("ColorManager", true, false)

func _on_player_entered(body: Node2D) -> void:
	if (body.is_in_group("player") and 
		color_manager and 
		not is_active_trigger and 
		trigger_cooldown_timer <= 0):
		
		is_active_trigger = true
		trigger_cooldown_timer = TRIGGER_COOLDOWN_TIME
		
		var event_position = global_position + bleed_offset
		color_manager.create_new_bleed_event(event_position)
		
		# Emit tile hit signal for music progression
		tile_hit.emit()
		
		print(name, ": Creating new color bleed event at adjusted position.")

func _on_player_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_active_trigger = false
