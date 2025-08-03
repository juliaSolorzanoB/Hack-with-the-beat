extends Node2D

# References to game systems
var music_manager: MusicManager
var tile_generator: TileGenerator
var color_manager: ColorManager
var player_node: CharacterBody2D
var progress_ui: ProgressUI

func _ready():
	print("=== GAME MAIN SCENE STARTING ===")
	
	player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		print("Player found at: ", player_node.global_position)
	else:
		print("WARNING: No player found in scene!")
	
	await get_tree().process_frame
	setup_game_systems()

func setup_game_systems():
	print("Setting up game systems...")
	
	music_manager = $MusicManager
	if not music_manager:
		printerr("MusicManager node not found in scene!")
		return
	
	var music_path = "res://music/Twinkle twinkle Little Star - Arima Kousei Ver [Synthesia].mp3"
	var music_resource = load(music_path)
	
	if music_resource:
		music_manager.base_music_track = music_resource
		print("Music track loaded successfully")
	else:
		print("ERROR: Could not load music from: ", music_path)
	
	await get_tree().process_frame
	
	tile_generator = $TileManager
	if not tile_generator:
		printerr("TileManager node not found in scene!")
		return
	
	var tile_path = "res://scenes/tiles/tile.tscn"
	var tile_long_path = "res://scenes/tiles/tile_long.tscn"
	var kill_zone_path = "res://scenes/killzone.tscn"
	
	var tile_scene = load(tile_path)
	var tile_long_scene = load(tile_long_path)
	var kill_zone_scene = load(kill_zone_path)
	
	if tile_scene:
		tile_generator.tile_16x8_scene = tile_scene
		print("16x8 tile scene loaded successfully")
	else:
		print("ERROR: Could not load tile scene from: ", tile_path)
	
	if tile_long_scene:
		tile_generator.tile_32x8_scene = tile_long_scene
		print("32x8 tile scene loaded successfully")
	else:
		print("ERROR: Could not load long tile scene from: ", tile_long_path)
	
	if kill_zone_scene:
		tile_generator.kill_zone_scene = kill_zone_scene
		print("Kill zone scene loaded successfully")
	else:
		print("WARNING: Could not load kill zone scene from: ", kill_zone_path)
	
	color_manager = $ColorManager
	if not color_manager:
		printerr("ColorManager node not found in scene!")
		return
	
	# Setup Progress UI
	setup_progress_ui()
	
	await get_tree().process_frame
	print("All systems initialized, waiting for full setup...")
	
	# Start the tile generation with the 7-second offset
	if tile_generator:
		tile_generator.start_generation(7.0)

	# Start the music system last
	print("Starting music system...")
	if music_manager:
		music_manager.start_music()
	
	# Optional: Print final scene structure for debugging
	print_scene_structure()

func setup_progress_ui():
	# Create progress UI as a CanvasLayer for overlay
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 200  # Above everything else
	ui_layer.name = "UILayer"
	add_child(ui_layer)
	
	# Create the progress UI control
	progress_ui = ProgressUI.new()
	progress_ui.name = "ProgressUI"
	ui_layer.add_child(progress_ui)
	
	print("Progress UI created and added to scene")

func print_scene_structure():
	print("=== FINAL SCENE STRUCTURE ===")
	print("Main scene children count: ", get_child_count())
	
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
		if child.name == "TileGenerator":
			var tg = child as TileGenerator
			if tg:
				print("    Generated tiles: ", tg.generated_tiles.size())
		
		for grandchild in child.get_children():
			print("    - ", grandchild.name, " (", grandchild.get_class(), ")")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("=== DEBUG INFO ===")
		if player_node:
			print("Player position: ", player_node.global_position)
		if tile_generator:
			print("Tile generator children: ", tile_generator.get_child_count())
			print("Generated tiles count: ", tile_generator.generated_tiles.size())
			print("Generation active: ", tile_generator.is_generation_active())
			print("Game progress: ", tile_generator.get_game_progress_percentage(), "%")
		if color_manager:
			var progress_info = color_manager.get_progression_info()
			print("Color manager progress: ", progress_info)
		print("Main scene children: ", get_child_count())

func _draw():
	var grid_size = 50
	var grid_color = Color.GRAY
	grid_color.a = 0.3
	
	for x in range(-10, 20):
		var line_x = x * grid_size
		draw_line(Vector2(line_x, -300), Vector2(line_x, 100), grid_color, 1)
	
	for y in range(-6, 3):
		var line_y = y * grid_size
		draw_line(Vector2(-500, line_y), Vector2(1000, line_y), grid_color, 1)
	
	draw_circle(Vector2.ZERO, 10, Color.RED)
	
	if player_node:
		var player_screen_pos = player_node.global_position
		draw_circle(player_screen_pos, 15, Color.GREEN)
