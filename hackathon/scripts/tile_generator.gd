extends Node2D
class_name TileGenerator

# --- TILE RESOURCES ---
@export var tile_16x8_scene: PackedScene
@export var tile_32x8_scene: PackedScene

# --- GENERATION PARAMETERS ---
@export var tiles_ahead_of_player: int = 20
@export var tiles_behind_player: int = 5
@export var base_tile_spacing: float = 64.0
@export var player_speed: float = 150.0

# --- FREQUENCY TO HEIGHT MAPPING ---
const MIN_FREQUENCY: float = 650.0
const MAX_FREQUENCY: float = 2100.0
const GROUND_Y: float = 208.0  # Based on where player actually is
const MAX_HEIGHT_LEVELS: int = 5
const TILE_HEIGHT: float = 16.0

# --- GROUND OFFSET SYSTEM ---
const GROUND_OFFSET: float = 16.0  # Offset applied to tiles that would be too close to ground

# --- JUMP PHYSICS CONSTRAINTS ---
const MAX_JUMP_UP: int = 2
const SAFE_FALL_DOWN: int = 1
const MIN_HORIZONTAL_SPACING: float = 16.0
const MAX_HORIZONTAL_SPACING: float = 40.0

# --- DEBUG VISUALIZATION ---
@export var show_debug_visualization: bool = true
var debug_lines: Array[Line2D] = []
var kill_zone_debug_rects: Array[ColorRect] = []

# --- RUNTIME STATE ---
var generated_tiles: Array[Node2D] = []
var tile_positions: Array[Vector2] = []
var tile_intensities: Array[float] = []
var current_tile_index: int = 0
var last_tile_height_level: int = 0
var tiles_successfully_hit: int = 0
var music_manager: MusicManager
var player_node: CharacterBody2D
var generation_start_offset: float = 7

# --- MUSIC-BASED GENERATION CONTROL ---
var generation_active: bool = false  # Controls whether we should generate new tiles
var music_duration: float = 0.0      # Total length of the music track

# --- KILL ZONE MANAGEMENT ---
@export var kill_zone_scene: PackedScene
var active_kill_zones: Array[Area2D] = []

# --- PERFORMANCE TRACKING ---
var last_player_x: float = 0.0
const UPDATE_THRESHOLD: float = 32.0

func _ready():
	print("TileGenerator _ready() called")
	print("Ground level set to: ", GROUND_Y)
	print("Ground offset for low tiles: ", GROUND_OFFSET)
	
	music_manager = get_tree().root.find_child("MusicManager", true, false)
	player_node = get_tree().get_first_node_in_group("player")
	
	if music_manager:
		music_manager.beat_detected.connect(_on_beat_detected)
		music_manager.music_intensity_changed.connect(_on_intensity_changed)
		print("Connected to music manager signals")
		
		# Get music duration for progress tracking
		if music_manager.audio_players.size() > 0 and music_manager.audio_players[0].stream:
			music_duration = music_manager.audio_players[0].stream.get_length()
			print("Music duration: ", music_duration, " seconds")
	else:
		print("WARNING: Music manager not found!")
	
	if player_node:
		print("Player found at: ", player_node.global_position)
	else:
		print("WARNING: Player not found!")
	
	if not kill_zone_scene:
		print("WARNING: Kill zone scene not assigned in inspector!")
	else:
		print("Kill zone scene loaded: ", kill_zone_scene.resource_path)
	
	# Draw debug ground line
	if show_debug_visualization:
		draw_debug_ground_line()

func draw_debug_ground_line():
	var ground_line = Line2D.new()
	ground_line.add_point(Vector2(-1000, GROUND_Y))
	ground_line.add_point(Vector2(5000, GROUND_Y))
	ground_line.default_color = Color.RED
	ground_line.width = 3.0
	ground_line.z_index = 100
	get_tree().current_scene.add_child(ground_line)
	debug_lines.append(ground_line)
	
	print("Debug ground line drawn at y=", GROUND_Y)

func start_generation(start_delay: float):
	"""Starts pre-calculating tile positions with a delay to sync with music."""
	generation_start_offset = start_delay
	generation_active = true  # Enable generation
	print("Tile generation will start with an offset of ", generation_start_offset, " seconds.")
	call_deferred("pre_calculate_positions")

func pre_calculate_positions():
	print("Pre-calculating tile positions...")
	
	if not music_manager or music_manager.music_data.is_empty():
		print("No music data available for generation")
		return
	
	var current_x = 300.0
	var last_position = Vector2(current_x, GROUND_Y)  # Start at ground level
	last_tile_height_level = 0
	
	print("Starting tile generation from position: ", last_position)
	
	# FIRST TILE: Always place at reachable height (16px above ground)
	var first_tile_y = GROUND_Y - 16.0  # 16 pixels above ground - always reachable
	var first_tile_position = Vector2(current_x + 64.0, first_tile_y)  # Standard spacing from start
	tile_positions.append(first_tile_position)
	tile_intensities.append(0.05)  # Default intensity for first tile
	last_position = first_tile_position
	last_tile_height_level = 1  # Height level 1 = 16px above ground
	
	print("First tile positioned at: ", first_tile_position, " (guaranteed reachable)")
	
	# PROCESS REMAINING TILES: Start from second tile onward
	for i in range(music_manager.music_data.size()):
		var event = music_manager.music_data[i]
		var time_stamp = event.get("time", 0.0)

		if time_stamp < generation_start_offset:
			continue

		var frequency = event.get("dominant_frequency", 1000.0)
		var intensity = event.get("intensity", 0.05)
		
		var next_position = calculate_next_tile_position(last_position, frequency, intensity, time_stamp)
		
		if is_position_reachable(last_position, next_position):
			tile_positions.append(next_position)
			tile_intensities.append(intensity)
			last_position = next_position
			last_tile_height_level = world_y_to_height_level(next_position.y)
		else:
			var safe_position = create_safe_position(last_position, next_position)
			tile_positions.append(safe_position)
			tile_intensities.append(intensity)
			last_position = safe_position
			last_tile_height_level = world_y_to_height_level(safe_position.y)
	
	print("Pre-calculated ", tile_positions.size(), " tile positions (including guaranteed first tile)")
	
	call_deferred("update_tile_generation")

func create_safe_position(from_pos: Vector2, target_pos: Vector2) -> Vector2:
	var direction = (target_pos - from_pos).normalized()
	var safe_distance = clamp(target_pos.distance_to(from_pos), MIN_HORIZONTAL_SPACING, MAX_HORIZONTAL_SPACING)
	var safe_x = from_pos.x + (direction.x * safe_distance)
	
	var current_level = world_y_to_height_level(from_pos.y)
	var target_level = world_y_to_height_level(target_pos.y)
	var level_diff = target_level - current_level
	
	if level_diff > MAX_JUMP_UP:
		target_level = current_level + MAX_JUMP_UP
	elif level_diff < -SAFE_FALL_DOWN:
		target_level = current_level - SAFE_FALL_DOWN
	
	var safe_y = height_level_to_world_y(target_level)
	
	return Vector2(safe_x, safe_y)

func _process(delta):
	if not player_node:
		return
	
	# Check if music has ended and stop generation
	check_music_status()
	
	if abs(player_node.global_position.x - last_player_x) > UPDATE_THRESHOLD:
		update_tile_generation()
		cleanup_distant_tiles()
		last_player_x = player_node.global_position.x

func check_music_status():
	"""Checks if music has ended and stops tile generation accordingly."""
	if not music_manager or not generation_active:
		return
	
	# Check if music is still playing
	if music_manager.audio_players.size() > 0:
		var audio_player = music_manager.audio_players[0]
		if audio_player.stream:
			var current_time = audio_player.get_playback_position()
			var total_duration = audio_player.stream.get_length()
			
			# Stop generation when music ends OR when music stops playing
			if not audio_player.is_playing() or current_time >= total_duration - 0.1:
				generation_active = false
				print("Music ended - stopping tile generation and cleaning up future tiles")
				# Clean up tiles that are beyond the music duration
				cleanup_post_music_tiles()
		else:
			# No stream loaded
			generation_active = false
			print("No music stream - disabling tile generation")

func update_tile_generation():
	if not player_node or tile_positions.is_empty() or not generation_active:
		return
	
	var player_x = player_node.global_position.x
	var generation_distance = tiles_ahead_of_player * base_tile_spacing
	
	var tiles_needed = []
	for i in range(tile_positions.size()):
		var tile_pos = tile_positions[i]
		var distance_to_player = tile_pos.x - player_x
		
		if distance_to_player > -200 and distance_to_player < generation_distance:
			tiles_needed.append(i)
	
	var tiles_to_remove = []
	for tile in generated_tiles:
		var tile_index = get_tile_index(tile)
		if tile_index == -1 or tile_index not in tiles_needed:
			tiles_to_remove.append(tile)
	
	for tile in tiles_to_remove:
		generated_tiles.erase(tile)
		tile.queue_free()
	
	for tile_index in tiles_needed:
		if not is_tile_already_generated(tile_index):
			create_tile_at_index(tile_index)

func create_tile_at_index(index: int):
	if index >= tile_positions.size() or index >= tile_intensities.size():
		return
	
	var position = tile_positions[index]
	var intensity = tile_intensities[index]
	
	# FIXED: Apply offset to tiles that would be too close to ground (instead of skipping)
	if position.y >= GROUND_Y - 8.0:
		position.y = GROUND_Y - GROUND_OFFSET
		print("Applied ground offset to tile. New position: ", position, " (", GROUND_Y - position.y, " pixels above ground)")
	
	var tile_scene = tile_16x8_scene if intensity < 0.07 else tile_32x8_scene
	
	if not tile_scene:
		return
	
	var tile_instance = tile_scene.instantiate()
	tile_instance.global_position = position
	tile_instance.set_meta("tile_index", index)
	
	get_tree().current_scene.add_child(tile_instance)
	generated_tiles.append(tile_instance)
	
	print("Created tile at: ", position, " (", GROUND_Y - position.y, " pixels above ground)")
	
	if tile_instance.has_signal("tile_hit"):
		tile_instance.tile_hit.connect(_on_tile_hit)
	
	if kill_zone_scene and index > 0:
		var prev_pos = tile_positions[index - 1]
		create_kill_zone_gap(prev_pos, position)

func is_tile_already_generated(index: int) -> bool:
	for tile in generated_tiles:
		if tile.get_meta("tile_index", -1) == index:
			return true
	return false

func get_tile_index(tile: Node2D) -> int:
	return tile.get_meta("tile_index", -1)

func calculate_next_tile_position(last_pos: Vector2, frequency: float, intensity: float, time_stamp: float) -> Vector2:
	var target_height_level = frequency_to_height_level(frequency)
	var last_height_level = world_y_to_height_level(last_pos.y)
	target_height_level = constrain_height_change(last_height_level, target_height_level)
	
	var spacing_variance = intensity * 20.0
	var base_spacing_adjusted = base_tile_spacing + randf_range(-spacing_variance, spacing_variance)
	var spacing = clamp(base_spacing_adjusted, MIN_HORIZONTAL_SPACING, MAX_HORIZONTAL_SPACING)
	
	var next_x = last_pos.x + spacing
	var next_y = height_level_to_world_y(target_height_level)
	
	return Vector2(next_x, next_y)

func frequency_to_height_level(frequency: float) -> int:
	var normalized = (frequency - MIN_FREQUENCY) / (MAX_FREQUENCY - MIN_FREQUENCY)
	normalized = clamp(normalized, 0.0, 1.0)
	return int(normalized * MAX_HEIGHT_LEVELS)

func height_level_to_world_y(height_level: int) -> float:
	var calculated_y = GROUND_Y - (height_level * TILE_HEIGHT)
	# Keep original logic - no automatic offset here
	return calculated_y

func world_y_to_height_level(world_y: float) -> int:
	return max(0, int((GROUND_Y - world_y) / TILE_HEIGHT))

func constrain_height_change(from_level: int, to_level: int) -> int:
	var height_diff = to_level - from_level
	
	if height_diff > MAX_JUMP_UP:
		return from_level + MAX_JUMP_UP
	elif height_diff < -SAFE_FALL_DOWN:
		return from_level - SAFE_FALL_DOWN
	
	return to_level

func is_position_reachable(from_pos: Vector2, to_pos: Vector2) -> bool:
	var horizontal_distance = abs(to_pos.x - from_pos.x)
	var vertical_distance = abs(to_pos.y - from_pos.y)
	
	if horizontal_distance < MIN_HORIZONTAL_SPACING or horizontal_distance > MAX_HORIZONTAL_SPACING:
		return false
	
	var height_levels_diff = abs(world_y_to_height_level(to_pos.y) - world_y_to_height_level(from_pos.y))
	if height_levels_diff > MAX_JUMP_UP:
		return false
	
	return true

func create_kill_zone_gap(from_pos: Vector2, to_pos: Vector2):
	if not kill_zone_scene:
		print("ERROR: Kill zone scene not assigned!")
		return
	
	var gap_center_x = (from_pos.x + to_pos.x) / 2.0
	var gap_width = abs(to_pos.x - from_pos.x)
	
	print("Checking gap: width=", gap_width, " between ", from_pos, " -> ", to_pos)
	
	if gap_width > 30.0:  # Lowered threshold for easier testing
		var kill_zone = kill_zone_scene.instantiate()
		
		# Position kill zone where player will fall - closer to ground level
		var kill_zone_y = GROUND_Y + 30.0  # Just below ground level
		
		kill_zone.global_position = Vector2(gap_center_x, kill_zone_y)
		
		# IMPORTANT: Set collision properties BEFORE adding to scene
		kill_zone.collision_layer = 4  # Kill zone layer
		kill_zone.collision_mask = 2   # Player layer (FIXED: back to 2!)
		
		# Add to scene first
		get_tree().current_scene.add_child(kill_zone)
		
		# Set the kill zone size AFTER adding to scene
		if kill_zone.has_method("set_width"):
			kill_zone.set_width(gap_width + 20.0)  # Extra width for safety
		
		active_kill_zones.append(kill_zone)
		
		print("✓ Created kill zone at: ", kill_zone.global_position, " with width: ", gap_width + 20.0)
		print("   Collision setup - Layer: ", kill_zone.collision_layer, " | Mask: ", kill_zone.collision_mask)
		
		# DEBUG VISUALIZATION
		if show_debug_visualization:
			create_kill_zone_debug_visual(gap_center_x, kill_zone_y, gap_width + 20.0)
	else:
		print("✗ Gap too small for kill zone: ", gap_width)

func create_kill_zone_debug_visual(center_x: float, center_y: float, width: float):
	var debug_rect = ColorRect.new()
	debug_rect.size = Vector2(width, 32)
	debug_rect.position = Vector2(center_x - width/2, center_y - 16)
	debug_rect.color = Color(1.0, 0.0, 0.0, 0.3)  # Semi-transparent red
	debug_rect.z_index = 50
	
	get_tree().current_scene.add_child(debug_rect)
	kill_zone_debug_rects.append(debug_rect)
	
	# Add a label showing kill zone info
	var label = Label.new()
	label.text = "KILL ZONE\nW:" + str(int(width))
	label.position = Vector2(center_x - 30, center_y - 30)
	label.add_theme_color_override("font_color", Color.RED)
	label.z_index = 51
	
	get_tree().current_scene.add_child(label)
	print("Created debug visualization for kill zone at x=", center_x)

func cleanup_distant_tiles():
	if not player_node:
		return
	
	var player_x = player_node.global_position.x
	var zones_to_remove = []
	var debug_rects_to_remove = []
	
	for zone in active_kill_zones:
		if zone.global_position.x < player_x - 300:
			zones_to_remove.append(zone)
	
	for zone in zones_to_remove:
		active_kill_zones.erase(zone)
		zone.queue_free()
	
	# Clean up debug visuals
	for rect in kill_zone_debug_rects:
		if rect.position.x < player_x - 300:
			debug_rects_to_remove.append(rect)
	
	for rect in debug_rects_to_remove:
		kill_zone_debug_rects.erase(rect)
		rect.queue_free()

func _on_beat_detected(strength: float, frequency: float, time_stamp: float):
	# Music beat detection - no color effects, just for tile generation timing
	pass

func _on_intensity_changed(intensity: float):
	# Music intensity changes - no color effects needed
	pass

func _on_tile_hit():
	# Just count the tiles hit, no color effects
	tiles_successfully_hit += 1
	print("Tile hit! Total tiles hit: ", tiles_successfully_hit)

func get_tiles_successfully_hit() -> int:
	return tiles_successfully_hit

# --- PROGRESS TRACKING FUNCTIONS ---
func get_game_progress_percentage() -> float:
	"""Returns current game progress as a percentage based on music playback."""
	if not music_manager or not music_manager.audio_players.size() > 0:
		return 0.0
	
	var audio_player = music_manager.audio_players[0]
	if not audio_player.stream or not audio_player.is_playing():
		return 0.0
	
	var current_time = audio_player.get_playback_position()
	var total_duration = audio_player.stream.get_length()
	
	if total_duration > 0:
		return (current_time / total_duration) * 100.0
	
	return 0.0

func cleanup_post_music_tiles():
	"""Removes tiles that would appear after the music has ended."""
	if not music_manager or music_manager.audio_players.size() == 0:
		return
	
	var audio_player = music_manager.audio_players[0]
	if not audio_player.stream:
		return
	
	var total_duration = audio_player.stream.get_length()
	var tiles_to_remove = []
	
	# Calculate which tiles should be removed based on music timing
	# Estimate: each tile roughly represents a music event
	var music_events_count = music_manager.music_data.size()
	var max_valid_tiles = int((total_duration / (total_duration + generation_start_offset)) * tile_positions.size())
	
	# Remove tiles beyond the music duration
	for tile in generated_tiles:
		var tile_index = get_tile_index(tile)
		if tile_index > max_valid_tiles:
			tiles_to_remove.append(tile)
	
	for tile in tiles_to_remove:
		generated_tiles.erase(tile)
		tile.queue_free()
		print("Removed post-music tile at index: ", get_tile_index(tile))
	
func is_generation_active() -> bool:
	"""Returns whether tile generation is currently active."""
	return generation_active
