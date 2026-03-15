extends Node
class_name SpatialIndex2D

@export var rebuild_interval: float = 0.18
@export var cell_size: float = 320.0
@export var tracked_groups: PackedStringArray = [
	"players",
	"enemies",
	"summons",
	"house",
	"enemy_towers",
]

var _time_to_rebuild: float = 0.0
var _grid_by_group: Dictionary = {}
var _nodes_by_group: Dictionary = {}

func _ready() -> void:
	force_rebuild()

func _process(delta: float) -> void:
	_time_to_rebuild = maxf(_time_to_rebuild - delta, 0.0)
	if _time_to_rebuild > 0.0:
		return

	_time_to_rebuild = maxf(rebuild_interval, 0.03)
	_rebuild_index()

func force_rebuild() -> void:
	_time_to_rebuild = maxf(rebuild_interval, 0.03)
	_rebuild_index()

func find_closest_in_group(from_position: Vector2, group_name: StringName, radius: float = -1.0, exclude: Node2D = null) -> Node2D:
	var best_node: Node2D = null
	var best_distance_sq: float = INF
	var has_radius_limit: bool = radius > 0.0
	var radius_sq: float = radius * radius
	var candidates: Array[Node2D] = []

	if has_radius_limit:
		candidates = get_nodes_in_radius(from_position, group_name, radius, exclude)
	else:
		candidates = _get_group_nodes(group_name)

	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		if exclude != null and candidate == exclude:
			continue

		var distance_sq: float = from_position.distance_squared_to(candidate.global_position)
		if has_radius_limit and distance_sq > radius_sq:
			continue
		if distance_sq >= best_distance_sq:
			continue

		best_distance_sq = distance_sq
		best_node = candidate

	return best_node

func find_closest_in_groups(from_position: Vector2, group_names: PackedStringArray, radius: float = -1.0, exclude: Node2D = null) -> Node2D:
	var best_node: Node2D = null
	var best_distance_sq: float = INF
	var has_radius_limit: bool = radius > 0.0
	var radius_sq: float = radius * radius

	for group_name in group_names:
		var candidates: Array[Node2D] = []
		if has_radius_limit:
			candidates = get_nodes_in_radius(from_position, group_name, radius, exclude)
		else:
			candidates = _get_group_nodes(group_name)

		for candidate in candidates:
			if not is_instance_valid(candidate):
				continue
			if exclude != null and candidate == exclude:
				continue

			var distance_sq: float = from_position.distance_squared_to(candidate.global_position)
			if has_radius_limit and distance_sq > radius_sq:
				continue
			if distance_sq >= best_distance_sq:
				continue

			best_distance_sq = distance_sq
			best_node = candidate

	return best_node

func get_nodes_in_radius(from_position: Vector2, group_name: StringName, radius: float, exclude: Node2D = null) -> Array[Node2D]:
	var results: Array[Node2D] = []
	if radius <= 0.0:
		return results

	var grid: Dictionary = _grid_by_group.get(group_name, {})
	if grid.is_empty():
		if get_tree() == null:
			return results

		var radius_sq_fallback: float = radius * radius
		for candidate in get_tree().get_nodes_in_group(group_name):
			if not (candidate is Node2D):
				continue
			if not is_instance_valid(candidate):
				continue

			var node: Node2D = candidate as Node2D
			if exclude != null and node == exclude:
				continue
			if from_position.distance_squared_to(node.global_position) <= radius_sq_fallback:
				results.append(node)

		return results

	var clamped_cell_size: float = maxf(cell_size, 1.0)
	var center_cell: Vector2i = _cell_for_position(from_position)
	var cell_radius: int = int(ceili(radius / clamped_cell_size))
	var radius_sq: float = radius * radius

	for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
		for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
			var key: Vector2i = Vector2i(x, y)
			if not grid.has(key):
				continue

			var bucket: Array = grid[key]
			for candidate_variant in bucket:
				if not (candidate_variant is Node2D):
					continue
				var candidate: Node2D = candidate_variant as Node2D
				if not is_instance_valid(candidate):
					continue
				if exclude != null and candidate == exclude:
					continue

				if from_position.distance_squared_to(candidate.global_position) <= radius_sq:
					results.append(candidate)

	return results

func get_first_in_group(group_name: StringName) -> Node2D:
	var nodes: Array[Node2D] = _get_group_nodes(group_name)
	for node in nodes:
		if is_instance_valid(node):
			return node
	return null

func _rebuild_index() -> void:
	_grid_by_group.clear()
	_nodes_by_group.clear()
	if get_tree() == null:
		return

	for group_name in tracked_groups:
		var nodes: Array[Node2D] = []
		var grid: Dictionary = {}

		for candidate in get_tree().get_nodes_in_group(group_name):
			if not (candidate is Node2D):
				continue
			if not is_instance_valid(candidate):
				continue

			var node: Node2D = candidate as Node2D
			nodes.append(node)

			var key: Vector2i = _cell_for_position(node.global_position)
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append(node)

		_nodes_by_group[group_name] = nodes
		_grid_by_group[group_name] = grid

func _get_group_nodes(group_name: StringName) -> Array[Node2D]:
	if _nodes_by_group.has(group_name):
		return _nodes_by_group[group_name] as Array[Node2D]

	var nodes: Array[Node2D] = []
	if get_tree() == null:
		return nodes

	for candidate in get_tree().get_nodes_in_group(group_name):
		if candidate is Node2D and is_instance_valid(candidate):
			nodes.append(candidate as Node2D)

	return nodes

func _cell_for_position(position: Vector2) -> Vector2i:
	var clamped_cell_size: float = maxf(cell_size, 1.0)
	return Vector2i(
		int(floor(position.x / clamped_cell_size)),
		int(floor(position.y / clamped_cell_size))
	)
