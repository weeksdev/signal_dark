class_name RuntimeDebugLog
extends RefCounted

static func init_session() -> void:
	var debug_system := _debug_system()
	if debug_system != null:
		debug_system.init_session()


static func log(channel: String, message: String) -> void:
	var debug_system := _debug_system()
	if debug_system != null:
		debug_system.log(channel, message)


static func _debug_system() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return loop.root.get_node_or_null("DebugSystem")
