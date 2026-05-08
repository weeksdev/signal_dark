extends Node

const OUTPUT_PATH := "res://tmp/arcade_snapshot.png"
const RUN_SEED := 42424
const RUN_DIFFICULTY := 1
const ARCADE_WORLD_SCENE := preload("res://src/world/ArcadeWorld.tscn")

var _captured: bool = false
var _world: Node = null


func _ready() -> void:
	ArcadeState.start_run(RUN_SEED, RUN_DIFFICULTY)
	AlertSystem.reset()
	ColorSystem.reset()
	_world = ARCADE_WORLD_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(_world)


func _process(_delta: float) -> void:
	if _captured:
		return
	if _world == null or not is_instance_valid(_world):
		return
	if _world.get_parent() == null:
		return
	_captured = true
	_capture.call_deferred()


func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image != null:
		var abs_path := ProjectSettings.globalize_path(OUTPUT_PATH)
		DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
		image.save_png(abs_path)
		print("[Snapshot] saved=%s" % abs_path)
	get_tree().quit()
