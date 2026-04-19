extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var alert_system := get_root().get_node("/root/AlertSystem")
	alert_system.reset()
	var gate_scene := load("res://src/terrain/GateLock.tscn") as PackedScene
	if gate_scene == null:
		push_error("GateLock scene missing")
		quit(1)
		return

	var gate := gate_scene.instantiate()
	root.add_child(gate)
	await process_frame

	var collision := gate.get_node("CollisionShape2D") as CollisionShape2D
	if collision == null:
		push_error("GateLock collision missing")
		quit(1)
		return

	if collision.disabled:
		push_error("GateLock should start closed in stealth")
		quit(1)
		return

	alert_system.enter_combat()
	await process_frame
	if not collision.disabled:
		push_error("GateLock should open in combat")
		quit(1)
		return

	alert_system.exit_combat()
	await process_frame
	if collision.disabled:
		push_error("GateLock should close again after combat")
		quit(1)
		return

	print("GateLock combat toggle test passed.")
	quit(0)
