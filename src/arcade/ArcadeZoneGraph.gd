class_name ArcadeZoneGraph
extends RefCounted

enum NodeType { START, CORRIDOR, ROOM, BRANCH_ROOM, SETPIECE_ROOM, EXIT }
enum ThreatType { NONE, SCANNER, SWEEPER, PULSAR, HUNTER, MIXED }
enum ZoneTheme { STEALTH_MAZE, PULSE_LATTICE, PRISM_LOCKDOWN, WARP_NEST, COMBAT_COLLAPSE }

const NODE_TYPE_NAMES  := ["START", "CORRIDOR", "ROOM", "BRANCH_ROOM", "SETPIECE_ROOM", "EXIT"]
const THREAT_TYPE_NAMES := ["NONE", "SCANNER", "SWEEPER", "PULSAR", "HUNTER", "MIXED"]
const THEME_NAMES      := ["STEALTH_MAZE", "PULSE_LATTICE", "PRISM_LOCKDOWN", "WARP_NEST", "COMBAT_COLLAPSE"]


class ZoneNode:
	var id: int
	var type: int
	var depth: int
	var is_branch: bool
	var preferred_threat: int

	func _init(p_id: int, p_type: int, p_depth: int, p_branch: bool) -> void:
		id = p_id
		type = p_type
		depth = p_depth
		is_branch = p_branch
		preferred_threat = ArcadeZoneGraph.ThreatType.NONE


class ZoneEdge:
	var from_id: int
	var to_id: int
	var traversal_width: int  # 1=tight 2=normal 3=wide
	var is_branch: bool

	func _init(p_from: int, p_to: int, p_width: int, p_branch: bool) -> void:
		from_id = p_from
		to_id = p_to
		traversal_width = p_width
		is_branch = p_branch


var nodes: Array = []
var edges: Array = []
var start_node_id: int = -1
var exit_node_id: int = -1
var theme: int = ZoneTheme.STEALTH_MAZE
var _next_id: int = 0


func add_node(type: int, depth: int, is_branch: bool) -> int:
	var node := ZoneNode.new(_next_id, type, depth, is_branch)
	nodes.append(node)
	_next_id += 1
	return node.id


func add_edge(from_id: int, to_id: int, width: int, is_branch: bool) -> void:
	edges.append(ZoneEdge.new(from_id, to_id, width, is_branch))


func get_node(id: int) -> ZoneNode:
	for n in nodes:
		if n.id == id:
			return n
	return null


func get_edges_from(node_id: int) -> Array:
	var result: Array = []
	for e in edges:
		if e.from_id == node_id:
			result.append(e)
	return result


func to_debug_string() -> String:
	var lines: Array = []
	lines.append("ZoneGraph  nodes=%d  edges=%d  theme=%s" % [nodes.size(), edges.size(), THEME_NAMES[theme]])
	for node in nodes:
		var type_str: String = NODE_TYPE_NAMES[node.type]
		var threat_str: String = THREAT_TYPE_NAMES[node.preferred_threat]
		var branch_tag: String = " [branch]" if node.is_branch else ""
		lines.append("  [%d] %-14s  depth=%d  threat=%-7s%s" % [
			node.id, type_str, node.depth, threat_str, branch_tag
		])
	for edge in edges:
		var branch_tag: String = " (branch)" if edge.is_branch else ""
		lines.append("  %d→%d  width=%d%s" % [
			edge.from_id, edge.to_id, edge.traversal_width, branch_tag
		])
	return "\n".join(lines)
