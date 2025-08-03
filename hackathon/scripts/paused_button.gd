extends Control

func _on_pause_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/paused_menu.tscn")
