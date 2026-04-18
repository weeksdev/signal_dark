extends Node

var current_world: Node = null


func register_world(world: Node) -> void:
	current_world = world


func restart_zone() -> void:
	AlertSystem.reset()
	ColorSystem.reset()
	get_tree().reload_current_scene()
