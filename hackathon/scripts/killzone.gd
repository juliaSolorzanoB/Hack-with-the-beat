extends Area2D 

@onready var death_timer: Timer = $Timer 


# --- BUILT-IN FUNCTIONS ---
func _ready() -> void:
	# connect the body_entered signal to our custom handler
	self.body_entered.connect(_on_body_entered)
	# Connect the Timer's timeout signal
	death_timer.timeout.connect(_on_death_timer_timeout)

func _on_body_entered(body: Node2D) -> void:
	# check if the entered body is a CharacterBody2D (our player)
	if body is CharacterBody2D:
		# call the 'die' function on the player
		var player_character = body as CharacterBody2D
		player_character.die()
		
		Engine.time_scale = 0.5 # apply slow-motion effect
		death_timer.start() # start timer to reload the scene
		
func _on_death_timer_timeout() -> void:
	Engine.time_scale = 1.0 # reset time scale before reloading to avoid affecting the next scene load
	get_tree().change_scene_to_file("res://scenes/retry.tscn") # Reload the current scene = restarting the level
#hey i changed the above line from reload scene to change scene to file
