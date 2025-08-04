extends Control
class_name ProgressUI
# Was used for debbugging 

# --- UI ELEMENTS ---
@onready var progress_label: Label
@onready var radius_label: Label
@onready var time_label: Label

# --- REFERENCES ---
var color_manager: ColorManager
var music_manager: MusicManager

func _ready():
	# Create UI elements
	setup_ui()
	
	# Get references to game systems
	color_manager = get_tree().root.find_child("ColorManager", true, false)
	music_manager = get_tree().root.find_child("MusicManager", true, false)
	
	if not color_manager:
		print("WARNING: ColorManager not found for progress UI")
	if not music_manager:
		print("WARNING: MusicManager not found for progress UI")

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
	
	# Create time label
	time_label = Label.new()
	time_label.text = "Time: 00:00 / 00:00"
	time_label.position = Vector2(20, 80)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	time_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	time_label.add_theme_constant_override("shadow_offset_x", 2)
	time_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(time_label)

func _process(delta):
	update_progress_display()

func update_progress_display():
	var progress = 0.0
	var radius = 50
	
	# Get progress from ColorManager
	if color_manager:
		progress = color_manager.get_game_progress_percentage()
		radius = int(color_manager.get_current_max_radius())
		
		progress_label.text = "Progress: " + str(progress).pad_decimals(1) + "%"
		radius_label.text = "Bleed Radius: " + str(radius) + " / 400"
		
	# Get time info from MusicManager
	if music_manager:
		var music_info = music_manager.get_music_time_info()
		
		if music_info.playing:
			var current_minutes = int(music_info.current) / 60
			var current_seconds = int(music_info.current) % 60
			var total_minutes = int(music_info.total) / 60
			var total_seconds = int(music_info.total) % 60
			
			time_label.text = "Time: %02d:%02d / %02d:%02d" % [current_minutes, current_seconds, total_minutes, total_seconds]
		elif music_info.finished:
			time_label.text = "Time: Music Finished"
		else:
			time_label.text = "Time: Music Stopped"

func format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]
