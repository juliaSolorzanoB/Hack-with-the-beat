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
		
	print("Music manager found and ready.")
	
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
	
	await get_tree().process_frame
	print("All systems initialized, waiting for full setup...")
	
	# Start the tile generation with the 7-second offset
	if tile_generator:
		tile_generator.start_generation(7.0)

	# Start the music system last
	print("Starting music system...")
	if music_manager:
		music_manager.start_music()

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
		if music_manager and music_manager.audio_players.size() > 0:
			var audio_player = music_manager.audio_players[0]
			if audio_player.stream:
				print("Music time: ", audio_player.get_playback_position(), "/", audio_player.stream.get_length())
				print("Music playing: ", audio_player.is_playing())
		print("Main scene children: ", get_child_count())
