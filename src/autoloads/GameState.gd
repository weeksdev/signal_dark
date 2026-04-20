extends Node

const START_SCENE := "res://src/ui/StartScreen.tscn"
const ZONE_SCENES := [
	"res://src/world/World.tscn",
	"res://src/world/World02.tscn",
	"res://src/world/World03.tscn",
	"res://src/world/World04.tscn",
]

var current_world: Node = null
var current_zone_index: int = -1


func register_world(world: Node) -> void:
	current_world = world
	current_zone_index = ZONE_SCENES.find(world.scene_file_path)


func start_run() -> void:
	current_zone_index = 0
	_change_scene(ZONE_SCENES[current_zone_index])


func start_zone(zone_index: int) -> void:
	if zone_index < 0 or zone_index >= ZONE_SCENES.size():
		return
	current_zone_index = zone_index
	_change_scene(ZONE_SCENES[current_zone_index])


func start_arcade_run(seed_val: int) -> void:
	ArcadeState.start_run(seed_val)
	AlertSystem.reset()
	ColorSystem.reset()
	_change_scene(ArcadeState.get_current_scene_path())


func restart_zone() -> void:
	AlertSystem.reset()
	ColorSystem.reset()
	if ArcadeState.is_active:
		_change_scene(ArcadeState.get_current_scene_path())
		return
	if current_world != null and current_world.scene_file_path != "":
		_change_scene(current_world.scene_file_path)
		return
	if current_zone_index >= 0 and current_zone_index < ZONE_SCENES.size():
		_change_scene(ZONE_SCENES[current_zone_index])
		return
	get_tree().reload_current_scene()


func advance_zone() -> void:
	AlertSystem.reset()
	ColorSystem.reset()
	if ArcadeState.is_active:
		if ArcadeState.advance():
			_change_scene(ArcadeState.get_current_scene_path())
		else:
			ArcadeState.reset()
			_change_scene(START_SCENE)
		return
	if current_zone_index >= 0 and current_zone_index < ZONE_SCENES.size() - 1:
		current_zone_index += 1
		_change_scene(ZONE_SCENES[current_zone_index])
		return
	current_zone_index = -1
	_change_scene(START_SCENE)


func _change_scene(path: String) -> void:
	current_world = null
	get_tree().change_scene_to_file(path)
