extends Node2D

@export var target: PackedScene


func _on_timer_timeout():
	GlobalTransition.change_scene_to_packed(target)
