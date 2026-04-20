extends "res://src/world/World.gd"

# Preloaded in dependency order — each preload registers its class_name before
# the next script is compiled, so internal cross-references resolve correctly.
const _SeedRng   := preload("res://src/arcade/ArcadeSeedRng.gd")
const _ZoneGraph := preload("res://src/arcade/ArcadeZoneGraph.gd")
const _Builder   := preload("res://src/arcade/ZoneGraphBuilder.gd")
const _Assembler := preload("res://src/arcade/ModuleAssembler.gd")
const _Placer    := preload("res://src/arcade/EncounterPlacer.gd")


func _ready() -> void:
	super._ready()
	if not ArcadeState.is_active:
		return

	var rng = _SeedRng.new(ArcadeState.get_floor_seed())
	var graph = _Builder.new().build(rng, ArcadeState.floor_index)

	print("[Arcade] seed=%d  floor=%d/%d\n%s" % [
		ArcadeState.run_seed,
		ArcadeState.floor_index + 1,
		ArcadeState.FLOOR_COUNT,
		graph.to_debug_string(),
	])

	var result = _Assembler.new().assemble(self, graph)

	ship.global_position = result["spawn"]
	grid.world_rect       = result["world_rect"]
	_configure_camera()

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.player_reached.connect(_on_exit_reached)

	_Placer.new().place(
		self,
		graph,
		result["node_rects"],
		result["node_cells"],
		ArcadeState.floor_index,
	)
