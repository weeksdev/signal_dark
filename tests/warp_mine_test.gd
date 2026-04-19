extends SceneTree


class FakePlayer extends CharacterBody2D:
	var dark_mode: bool = false
	var in_dark_pocket: bool = false
	var hit_taken: bool = false

	func _ready() -> void:
		add_to_group("player_ship")

	func get_effective_emission() -> float:
		return 0.85

	func take_hit() -> void:
		hit_taken = true


class TestWorld extends Node2D:
	var spawned_enemies: Array[Node] = []

	func register_spawned_enemy(enemy: Node) -> void:
		add_child(enemy)
		spawned_enemies.append(enemy)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var alert_system := get_root().get_node("/root/AlertSystem")
	alert_system.reset()

	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world

	var player := FakePlayer.new()
	player.global_position = Vector2(220.0, 200.0)
	world.add_child(player)

	var mine_scene := load("res://src/enemies/WarpMine.tscn") as PackedScene
	if mine_scene == null:
		push_error("WarpMine scene missing")
		quit(1)
		return

	var mine := mine_scene.instantiate()
	mine.global_position = Vector2(200.0, 200.0)
	world.add_child(mine)
	await process_frame

	mine.activate_for_combat(player)
	mine._start_arming()
	mine._deploy_payload()
	await process_frame

	if world.spawned_enemies.size() != 2:
		push_error("WarpMine should deploy exactly 2 payload enemies")
		quit(1)
		return

	if not player.hit_taken:
		push_error("WarpMine blast should hit player inside blast radius")
		quit(1)
		return

	print("WarpMine deployment test passed.")
	quit(0)
