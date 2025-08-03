extends Control
class_name ProgressUI

# --- UI ELEMENTS ---
@onready var progress_label: Label
@onready var radius_label: Label

# --- REFERENCES ---
var color_manager: ColorManager
var tile_generator: TileGenerator

func _ready():
	# Create UI elements
	setup_ui()
	
	# Get references to game systems
	color_manager = get_tree().root.find_child("ColorManager", true, false)
	tile_generator = get_tree().root.find_child("TileGenerator", true, false)
	
	if not color_manager:
		print("WARNING: ColorManager not found for progress UI")
	if not tile_generator:
		print("WARNING: TileGenerator not found for progress UI")

func setup_ui():
	# Create progress label
	progress_label = Label.new()
	progress_label.text = "Progress: 0.0%"
	progress_label.position = Vector2(20, 20)
	progress_label.add_theme_color_override("font_color", Color.WHITE)
	progress_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	progress_label.add_theme_constant_override("shadow_offset_x", 2)
	progress_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(progress_label)
	
	# Create radius label
	radius_label = Label.new()
	radius_label.text = "Bleed Radius: 50"
	radius_label.position = Vector2(20, 50)
	radius_label.add_theme_color_override("font_color", Color.WHITE)
	radius_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	radius_label.add_theme_constant_override("shadow_offset_x", 2)
	radius_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(radius_label)

func _process(delta):
	update_progress_display()

func update_progress_display():
	if color_manager:
		var progress = color_manager.get_game_progress_percentage()
		var radius = color_manager.get_current_max_radius()
		
		progress_label.text = "Progress: " + str(progress).pad_decimals(1) + "%"
		radius_label.text = "Bleed Radius: " + str(int(radius))
	
	if tile_generator:
		var generation_status = "Active" if tile_generator.is_generation_active() else "Stopped"
		var existing_text = progress_label.text
		progress_label.text = existing_text + " | Generation: " + generation_status
