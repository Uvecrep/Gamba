extends Node2D

@export var navigation_obstacle_padding: float = 10.0
@export var navigation_rebuild_delay_seconds: float = 0.15
@export var navigation_block_full_collision_cells: bool = true
@export var navigation_grid_clearance_pixels: float = 18.0

var _is_game_over: bool = false

@onready var _house: Node = get_node_or_null("house")
@onready var _enemy_spawner: Node = get_node_or_null("EnemySpawner")
@onready var _game_over_layer: CanvasLayer = get_node_or_null("GameOverLayer") as CanvasLayer
@onready var _restart_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/RestartButton") as Button
@onready var _quit_button: Button = get_node_or_null("GameOverLayer/GameOverPanel/MarginContainer/VBoxContainer/QuitButton") as Button

var _navigation_rebuild_timer: Timer
var _world_navigation_region: NavigationRegion2D
var _is_exiting_tree: bool = false

func _ready() -> void:
	_is_exiting_tree = false
	if is_instance_valid(_house) and _house.has_signal("destroyed"):
		_house.connect("destroyed", _on_house_destroyed)

	_ensure_navigation_runtime_nodes()
	_schedule_navigation_rebuild()

	if not get_tree().node_added.is_connected(_on_scene_node_added):
		get_tree().node_added.connect(_on_scene_node_added)
	if not get_tree().node_removed.is_connected(_on_scene_node_removed):
		get_tree().node_removed.connect(_on_scene_node_removed)

	if is_instance_valid(_restart_button):
		_restart_button.pressed.connect(_on_restart_pressed)
	if is_instance_valid(_quit_button):
		_quit_button.pressed.connect(_on_quit_pressed)

	_set_game_over_visible(false)

func _exit_tree() -> void:
	_is_exiting_tree = true
	if is_instance_valid(_navigation_rebuild_timer):
		_navigation_rebuild_timer.stop()

	if get_tree() == null:
		return

	if get_tree().node_added.is_connected(_on_scene_node_added):
		get_tree().node_added.disconnect(_on_scene_node_added)
	if get_tree().node_removed.is_connected(_on_scene_node_removed):
		get_tree().node_removed.disconnect(_on_scene_node_removed)

func _on_house_destroyed() -> void:
	if _is_game_over:
		return

	_is_game_over = true
	if is_instance_valid(_enemy_spawner) and _enemy_spawner.has_method("stop_spawning"):
		_enemy_spawner.call("stop_spawning")
	_set_game_over_visible(true)
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _set_game_over_visible(should_show: bool) -> void:
	if _game_over_layer == null:
		return

	_game_over_layer.visible = should_show
	if should_show and is_instance_valid(_restart_button):
		_restart_button.grab_focus()

func _ensure_navigation_runtime_nodes() -> void:
	if _world_navigation_region == null:
		_world_navigation_region = get_node_or_null("WorldNavigationRegion") as NavigationRegion2D
	if _world_navigation_region == null:
		_world_navigation_region = NavigationRegion2D.new()
		_world_navigation_region.name = "WorldNavigationRegion"
		add_child(_world_navigation_region)

	if _navigation_rebuild_timer == null:
		_navigation_rebuild_timer = Timer.new()
		_navigation_rebuild_timer.name = "NavigationRebuildTimer"
		_navigation_rebuild_timer.one_shot = true
		_navigation_rebuild_timer.timeout.connect(_on_navigation_rebuild_timer_timeout)
		add_child(_navigation_rebuild_timer)

	_navigation_rebuild_timer.wait_time = maxf(navigation_rebuild_delay_seconds, 0.01)

func _on_scene_node_added(node: Node) -> void:
	if _is_exiting_tree:
		return

	if not _is_navigation_obstacle_node(node):
		return

	_schedule_navigation_rebuild()

func _on_scene_node_removed(node: Node) -> void:
	if _is_exiting_tree:
		return

	if not _is_navigation_obstacle_node(node):
		return

	_schedule_navigation_rebuild()

func _is_navigation_obstacle_node(node: Node) -> bool:
	if node is StaticBody2D:
		return true

	return _is_collision_tile_map_layer(node)

func _schedule_navigation_rebuild() -> void:
	if _is_exiting_tree or not is_inside_tree():
		return

	if _navigation_rebuild_timer == null or not is_instance_valid(_navigation_rebuild_timer):
		return

	if not _navigation_rebuild_timer.is_inside_tree():
		return

	_navigation_rebuild_timer.start(maxf(navigation_rebuild_delay_seconds, 0.01))

func _on_navigation_rebuild_timer_timeout() -> void:
	if _is_exiting_tree or not is_inside_tree():
		return

	_rebuild_navigation_mesh()

func _rebuild_navigation_mesh() -> void:
	if _world_navigation_region == null:
		return

	var world_bounds: Rect2 = _get_world_bounds_from_tile_map()
	if world_bounds.size.x <= 0.0 or world_bounds.size.y <= 0.0:
		return

	var obstacle_polygons: Array[PackedVector2Array] = _collect_obstacle_polygons(world_bounds, true)
	var final_obstacle_polygons: Array[PackedVector2Array] = obstacle_polygons
	var nav_polygon: NavigationPolygon = _build_navigation_polygon(world_bounds, final_obstacle_polygons)

	if nav_polygon.get_polygon_count() <= 0 and not obstacle_polygons.is_empty():
		# Retry with coarse tile blocking (full-cell collision cutouts) while preserving TileMapCollision fences.
		final_obstacle_polygons = _collect_obstacle_polygons(world_bounds, true, false)
		nav_polygon = _build_navigation_polygon(world_bounds, final_obstacle_polygons)

	if nav_polygon.get_polygon_count() <= 0 and not obstacle_polygons.is_empty():
		push_warning("Main: navigation mesh build produced no polygons; enemies/summons may not path.")

	_world_navigation_region.navigation_polygon = nav_polygon

func _build_navigation_polygon(world_bounds: Rect2, obstacle_polygons: Array[PackedVector2Array]) -> NavigationPolygon:
	var grid_nav_polygon: NavigationPolygon = _build_navigation_polygon_from_tile_grid()
	if grid_nav_polygon.get_polygon_count() > 0:
		return grid_nav_polygon

	var nav_polygon: NavigationPolygon = NavigationPolygon.new()
	var walkable_polygons: Array[PackedVector2Array] = _build_walkable_polygons(world_bounds, obstacle_polygons)
	if walkable_polygons.is_empty():
		return nav_polygon

	var vertices: PackedVector2Array = PackedVector2Array()
	var triangles: Array[PackedInt32Array] = []

	for walkable_polygon in walkable_polygons:
		var cleaned_polygon: PackedVector2Array = _sanitize_polygon(walkable_polygon)
		if cleaned_polygon.size() < 3:
			continue

		var triangulated_indices: PackedInt32Array = Geometry2D.triangulate_polygon(cleaned_polygon)
		if triangulated_indices.size() < 3:
			continue

		var vertex_offset: int = vertices.size()
		for point in cleaned_polygon:
			vertices.append(point)

		for index in range(0, triangulated_indices.size(), 3):
			if index + 2 >= triangulated_indices.size():
				break

			triangles.append(PackedInt32Array([
				vertex_offset + triangulated_indices[index],
				vertex_offset + triangulated_indices[index + 1],
				vertex_offset + triangulated_indices[index + 2],
			]))

	if vertices.is_empty() or triangles.is_empty():
		return nav_polygon

	nav_polygon.set_vertices(vertices)
	for triangle in triangles:
		nav_polygon.add_polygon(triangle)

	return nav_polygon

func _build_navigation_polygon_from_tile_grid() -> NavigationPolygon:
	var nav_polygon: NavigationPolygon = NavigationPolygon.new()
	var ground_layer: TileMapLayer = _find_world_tile_map_layer()
	if ground_layer == null:
		return nav_polygon

	var used_rect: Rect2i = ground_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return nav_polygon

	var tile_size: Vector2 = Vector2(32.0, 32.0)
	if ground_layer.tile_set != null:
		tile_size = Vector2(ground_layer.tile_set.tile_size)

	var blocked_cells: Dictionary = {}
	for collision_layer in _find_collision_tile_map_layers():
		for collision_cell in collision_layer.get_used_cells():
			var collision_center_global: Vector2 = collision_layer.to_global(collision_layer.map_to_local(collision_cell))
			var ground_cell: Vector2i = ground_layer.local_to_map(ground_layer.to_local(collision_center_global))
			blocked_cells[ground_cell] = true

	_mark_static_obstacles_on_ground_grid(ground_layer, blocked_cells, tile_size)
	_inflate_blocked_cells(used_rect, blocked_cells, tile_size, navigation_grid_clearance_pixels)

	var vertices: PackedVector2Array = PackedVector2Array()
	var triangles: Array[PackedInt32Array] = []

	for y in range(used_rect.position.y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if blocked_cells.has(cell):
				continue

			var cell_polygon: PackedVector2Array = _build_tile_cell_polygon(ground_layer, cell, tile_size)
			if cell_polygon.size() < 4:
				continue

			var vertex_offset: int = vertices.size()
			for point in cell_polygon:
				vertices.append(point)

			triangles.append(PackedInt32Array([vertex_offset + 0, vertex_offset + 1, vertex_offset + 2]))
			triangles.append(PackedInt32Array([vertex_offset + 0, vertex_offset + 2, vertex_offset + 3]))

	if vertices.is_empty() or triangles.is_empty():
		return nav_polygon

	nav_polygon.set_vertices(vertices)
	for triangle in triangles:
		nav_polygon.add_polygon(triangle)

	return nav_polygon

func _mark_static_obstacles_on_ground_grid(ground_layer: TileMapLayer, blocked_cells: Dictionary, tile_size: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var static_bodies: Array = scene_root.find_children("*", "StaticBody2D", true, false)
	for static_body_node in static_bodies:
		if not (static_body_node is StaticBody2D):
			continue

		for polygon in _extract_static_body_polygons(static_body_node as StaticBody2D):
			if polygon.size() < 3:
				continue

			var expanded: PackedVector2Array = _expand_polygon(polygon, navigation_obstacle_padding)
			_mark_polygon_cells_blocked(ground_layer, blocked_cells, tile_size, expanded)

func _mark_polygon_cells_blocked(ground_layer: TileMapLayer, blocked_cells: Dictionary, tile_size: Vector2, polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var min_point: Vector2 = polygon[0]
	var max_point: Vector2 = polygon[0]
	for point in polygon:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)

	var min_cell: Vector2i = ground_layer.local_to_map(ground_layer.to_local(min_point - tile_size * 0.5))
	var max_cell: Vector2i = ground_layer.local_to_map(ground_layer.to_local(max_point + tile_size * 0.5))

	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var candidate_cell: Vector2i = Vector2i(x, y)
			var center_global: Vector2 = ground_layer.to_global(ground_layer.map_to_local(candidate_cell))
			if Geometry2D.is_point_in_polygon(center_global, polygon):
				blocked_cells[candidate_cell] = true

func _inflate_blocked_cells(used_rect: Rect2i, blocked_cells: Dictionary, tile_size: Vector2, clearance_pixels: float) -> void:
	if clearance_pixels <= 0.0:
		return

	var cell_step_x: float = maxf(tile_size.x, 0.001)
	var cell_step_y: float = maxf(tile_size.y, 0.001)
	var radius_x: int = int(ceili(clearance_pixels / cell_step_x))
	var radius_y: int = int(ceili(clearance_pixels / cell_step_y))

	var expanded_cells: Dictionary = {}
	for blocked_cell_variant in blocked_cells.keys():
		if not (blocked_cell_variant is Vector2i):
			continue

		var blocked_cell: Vector2i = blocked_cell_variant as Vector2i
		for offset_y in range(-radius_y, radius_y + 1):
			for offset_x in range(-radius_x, radius_x + 1):
				var offset_distance: float = Vector2(offset_x * cell_step_x, offset_y * cell_step_y).length()
				if offset_distance > clearance_pixels + 0.001:
					continue

				var candidate_cell: Vector2i = Vector2i(blocked_cell.x + offset_x, blocked_cell.y + offset_y)
				if candidate_cell.x < used_rect.position.x or candidate_cell.y < used_rect.position.y:
					continue
				if candidate_cell.x >= used_rect.end.x or candidate_cell.y >= used_rect.end.y:
					continue

				expanded_cells[candidate_cell] = true

	for expanded_cell in expanded_cells.keys():
		blocked_cells[expanded_cell] = true

func _build_walkable_polygons(world_bounds: Rect2, obstacle_polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var walkable_polygons: Array[PackedVector2Array] = [_rect_to_polygon(world_bounds)]

	for obstacle in obstacle_polygons:
		var obstacle_polygon: PackedVector2Array = _sanitize_polygon(obstacle)
		if obstacle_polygon.size() < 3:
			continue

		var next_walkable: Array[PackedVector2Array] = []
		for walkable in walkable_polygons:
			if walkable.size() < 3:
				continue

			var clipped_results: Array = Geometry2D.clip_polygons(walkable, obstacle_polygon)
			if clipped_results.is_empty():
				var intersections: Array = Geometry2D.intersect_polygons(walkable, obstacle_polygon)
				if intersections.is_empty():
					next_walkable.append(walkable)
				continue

			for clipped_polygon in clipped_results:
				if not (clipped_polygon is PackedVector2Array):
					continue

				var cleaned_clipped: PackedVector2Array = _sanitize_polygon(clipped_polygon as PackedVector2Array)
				if cleaned_clipped.size() < 3:
					continue

				next_walkable.append(cleaned_clipped)

		walkable_polygons = next_walkable
		if walkable_polygons.is_empty():
			break

	return walkable_polygons

func _sanitize_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.size() < 3:
		return PackedVector2Array()

	var deduped: PackedVector2Array = PackedVector2Array()
	for point in polygon:
		if deduped.is_empty() or not deduped[deduped.size() - 1].is_equal_approx(point):
			deduped.append(point)

	if deduped.size() > 1 and deduped[0].is_equal_approx(deduped[deduped.size() - 1]):
		deduped.remove_at(deduped.size() - 1)

	if deduped.size() < 3:
		return PackedVector2Array()

	var simplified: PackedVector2Array = PackedVector2Array()
	for i in deduped.size():
		var previous_point: Vector2 = deduped[(i - 1 + deduped.size()) % deduped.size()]
		var current_point: Vector2 = deduped[i]
		var next_point: Vector2 = deduped[(i + 1) % deduped.size()]

		var previous_vector: Vector2 = current_point - previous_point
		var next_vector: Vector2 = next_point - current_point
		if previous_vector.length_squared() <= 0.0001 or next_vector.length_squared() <= 0.0001:
			continue

		var cross_value: float = previous_vector.normalized().cross(next_vector.normalized())
		var is_collinear: bool = absf(cross_value) <= 0.001 and previous_vector.dot(next_vector) > 0.0
		if is_collinear:
			continue

		simplified.append(current_point)

	if simplified.size() < 3:
		return PackedVector2Array()

	return simplified

func _get_world_bounds_from_tile_map() -> Rect2:
	var tile_map_layer: TileMapLayer = _find_world_tile_map_layer()
	if tile_map_layer == null:
		push_warning("Main: could not find TileMapGround for navigation bounds.")
		return Rect2()

	var used_rect: Rect2i = tile_map_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		push_warning("Main: TileMapGround has no used cells for navigation bounds.")
		return Rect2()

	var tile_size: Vector2 = Vector2(32.0, 32.0)
	if tile_map_layer.tile_set != null:
		tile_size = Vector2(tile_map_layer.tile_set.tile_size)

	var top_left_local: Vector2 = tile_map_layer.map_to_local(used_rect.position) - (tile_size * 0.5)
	var bottom_right_local: Vector2 = top_left_local + (Vector2(used_rect.size) * tile_size)

	var top_left_global: Vector2 = tile_map_layer.to_global(top_left_local)
	var bottom_right_global: Vector2 = tile_map_layer.to_global(bottom_right_local)
	var min_point: Vector2 = Vector2(min(top_left_global.x, bottom_right_global.x), min(top_left_global.y, bottom_right_global.y))
	var max_point: Vector2 = Vector2(max(top_left_global.x, bottom_right_global.x), max(top_left_global.y, bottom_right_global.y))

	return Rect2(min_point, max_point - min_point)

func _find_world_tile_map_layer() -> TileMapLayer:
	var world_node: Node = get_node_or_null("World")
	if world_node != null:
		var world_tile_map: Node = world_node.get_node_or_null("TileMapGround")
		if world_tile_map is TileMapLayer:
			return world_tile_map as TileMapLayer

	var fallback: Node = find_child("TileMapGround", true, false)
	if fallback is TileMapLayer:
		return fallback as TileMapLayer

	return null

func _collect_obstacle_polygons(world_bounds: Rect2, include_tile_map_collision: bool = true, include_tile_shape_polygons: bool = true) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return polygons

	var static_bodies: Array = scene_root.find_children("*", "StaticBody2D", true, false)
	for static_body_node in static_bodies:
		if not (static_body_node is StaticBody2D):
			continue

		for polygon in _extract_static_body_polygons(static_body_node as StaticBody2D):
			if polygon.size() < 3:
				continue
			if not _is_polygon_inside_or_near_rect(polygon, world_bounds, 64.0):
				continue

			polygons.append(_expand_polygon(polygon, navigation_obstacle_padding))

	if include_tile_map_collision:
		for tile_map_layer in _find_collision_tile_map_layers():
			for polygon in _extract_tile_map_collision_polygons(tile_map_layer, world_bounds, include_tile_shape_polygons):
				if polygon.size() < 3:
					continue

				polygons.append(_expand_polygon(polygon, navigation_obstacle_padding))

	return _merge_overlapping_polygons(polygons)

func _merge_overlapping_polygons(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var merged: Array[PackedVector2Array] = []

	for polygon in polygons:
		if polygon.size() < 3:
			continue

		var working_polygon: PackedVector2Array = polygon
		var did_merge_any: bool = true
		while did_merge_any:
			did_merge_any = false
			var i: int = 0
			while i < merged.size():
				var existing_polygon: PackedVector2Array = merged[i]
				var union_polygons: Array = Geometry2D.merge_polygons(working_polygon, existing_polygon)
				if union_polygons.size() != 1 or not (union_polygons[0] is PackedVector2Array):
					i += 1
					continue

				working_polygon = union_polygons[0] as PackedVector2Array
				merged.remove_at(i)
				did_merge_any = true

		merged.append(working_polygon)

	return merged

func _find_collision_tile_map_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	var world_node: Node = get_node_or_null("World")
	if world_node != null:
		var explicit_collision_layer: Node = world_node.get_node_or_null("TileMapCollision")
		if explicit_collision_layer is TileMapLayer:
			layers.append(explicit_collision_layer as TileMapLayer)

	var discovered_layers: Array = find_children("TileMapCollision", "TileMapLayer", true, false)
	for node in discovered_layers:
		if not (node is TileMapLayer):
			continue

		var layer: TileMapLayer = node as TileMapLayer
		if layers.has(layer):
			continue

		layers.append(layer)

	return layers

func _is_collision_tile_map_layer(node: Node) -> bool:
	if not (node is TileMapLayer):
		return false

	return node.name == "TileMapCollision"

func _extract_tile_map_collision_polygons(tile_map_layer: TileMapLayer, world_bounds: Rect2, include_shape_polygons: bool = true) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	if tile_map_layer == null:
		return polygons

	var physics_layer_count: int = 1
	var tile_size: Vector2 = Vector2(32.0, 32.0)
	if tile_map_layer.tile_set != null:
		physics_layer_count = maxi(tile_map_layer.tile_set.get_physics_layers_count(), 1)
		tile_size = Vector2(tile_map_layer.tile_set.tile_size)

	for cell_coords in tile_map_layer.get_used_cells():
		var tile_data: TileData = tile_map_layer.get_cell_tile_data(cell_coords)
		if navigation_block_full_collision_cells:
			var cell_polygon: PackedVector2Array = _build_tile_cell_polygon(tile_map_layer, cell_coords, tile_size)
			if _is_polygon_inside_or_near_rect(cell_polygon, world_bounds, 64.0):
				polygons.append(cell_polygon)

		if tile_data == null:
			continue

		var cell_center_local: Vector2 = tile_map_layer.map_to_local(cell_coords)
		var has_any_collision: bool = false
		var has_area_polygon: bool = false
		for physics_layer_index in physics_layer_count:
			var polygon_count: int = tile_data.get_collision_polygons_count(physics_layer_index)
			if polygon_count <= 0:
				continue

			has_any_collision = true
			if not include_shape_polygons:
				continue

			for polygon_index in polygon_count:
				var tile_polygon_local: PackedVector2Array = tile_data.get_collision_polygon_points(physics_layer_index, polygon_index)
				if tile_polygon_local.size() < 3:
					continue

				has_area_polygon = true

				var tile_polygon_global: PackedVector2Array = PackedVector2Array()
				for point in tile_polygon_local:
					tile_polygon_global.append(tile_map_layer.to_global(cell_center_local + point))

				if not _is_polygon_inside_or_near_rect(tile_polygon_global, world_bounds, 64.0):
					continue

				polygons.append(tile_polygon_global)

		if has_any_collision and not navigation_block_full_collision_cells and not has_area_polygon:
			var cell_polygon: PackedVector2Array = _build_tile_cell_polygon(tile_map_layer, cell_coords, tile_size)
			if _is_polygon_inside_or_near_rect(cell_polygon, world_bounds, 64.0):
				polygons.append(cell_polygon)

	return polygons

func _build_tile_cell_polygon(tile_map_layer: TileMapLayer, cell_coords: Vector2i, tile_size: Vector2) -> PackedVector2Array:
	var cell_center_local: Vector2 = tile_map_layer.map_to_local(cell_coords)
	var half_tile: Vector2 = tile_size * 0.5
	var local_polygon: PackedVector2Array = PackedVector2Array([
		cell_center_local + Vector2(-half_tile.x, -half_tile.y),
		cell_center_local + Vector2(half_tile.x, -half_tile.y),
		cell_center_local + Vector2(half_tile.x, half_tile.y),
		cell_center_local + Vector2(-half_tile.x, half_tile.y),
	])

	return _transform_polygon(local_polygon, tile_map_layer.global_transform)

func _extract_static_body_polygons(body: StaticBody2D) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	if body == null:
		return polygons

	for collision_shape_node in body.find_children("*", "CollisionShape2D", true, false):
		if not (collision_shape_node is CollisionShape2D):
			continue

		var collision_shape: CollisionShape2D = collision_shape_node as CollisionShape2D
		if collision_shape.disabled or collision_shape.shape == null:
			continue

		var shape_polygon: PackedVector2Array = _shape_to_polygon(collision_shape)
		if shape_polygon.size() >= 3:
			polygons.append(shape_polygon)

	for collision_polygon_node in body.find_children("*", "CollisionPolygon2D", true, false):
		if not (collision_polygon_node is CollisionPolygon2D):
			continue

		var collision_polygon: CollisionPolygon2D = collision_polygon_node as CollisionPolygon2D
		if collision_polygon.disabled or collision_polygon.polygon.size() < 3:
			continue

		polygons.append(_transform_polygon(collision_polygon.polygon, collision_polygon.global_transform))

	return polygons

func _shape_to_polygon(collision_shape: CollisionShape2D) -> PackedVector2Array:
	var local_polygon: PackedVector2Array = PackedVector2Array()
	var shape: Shape2D = collision_shape.shape

	if shape is RectangleShape2D:
		var rectangle: RectangleShape2D = shape as RectangleShape2D
		var half_extents: Vector2 = rectangle.size * 0.5
		local_polygon = PackedVector2Array([
			Vector2(-half_extents.x, -half_extents.y),
			Vector2(half_extents.x, -half_extents.y),
			Vector2(half_extents.x, half_extents.y),
			Vector2(-half_extents.x, half_extents.y),
		])
	elif shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		local_polygon = _build_circle_polygon(circle.radius, 14)
	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		local_polygon = _build_capsule_polygon(capsule.radius, capsule.height, 8)
	else:
		return PackedVector2Array()

	return _transform_polygon(local_polygon, collision_shape.global_transform)

func _build_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	var clamped_points: int = maxi(point_count, 6)
	for i in clamped_points:
		var angle: float = TAU * float(i) / float(clamped_points)
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)

	return polygon

func _build_capsule_polygon(radius: float, height: float, arc_points: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	var clamped_arc_points: int = maxi(arc_points, 4)
	var segment_half_height: float = maxf((height * 0.5) - radius, 0.0)

	for i in range(clamped_arc_points + 1):
		var angle_top: float = PI * float(i) / float(clamped_arc_points)
		polygon.append(Vector2(cos(angle_top), sin(angle_top)) * radius + Vector2(0.0, -segment_half_height))

	for i in range(clamped_arc_points + 1):
		var angle_bottom: float = PI + (PI * float(i) / float(clamped_arc_points))
		polygon.append(Vector2(cos(angle_bottom), sin(angle_bottom)) * radius + Vector2(0.0, segment_half_height))

	return polygon

func _transform_polygon(local_polygon: PackedVector2Array, xform: Transform2D) -> PackedVector2Array:
	var global_polygon: PackedVector2Array = PackedVector2Array()
	for point in local_polygon:
		global_polygon.append(xform * point)

	return global_polygon

func _expand_polygon(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	if amount <= 0.0:
		return polygon

	var expanded: Array = Geometry2D.offset_polygon(polygon, amount)
	if expanded.is_empty():
		return polygon

	if expanded[0] is PackedVector2Array:
		return expanded[0] as PackedVector2Array

	return polygon

func _is_polygon_inside_or_near_rect(polygon: PackedVector2Array, rect: Rect2, margin: float) -> bool:
	var expanded_rect: Rect2 = rect.grow(margin)
	for point in polygon:
		if expanded_rect.has_point(point):
			return true

	return false

func _rect_to_polygon(rect: Rect2) -> PackedVector2Array:
	var min_point: Vector2 = rect.position
	var max_point: Vector2 = rect.end
	return PackedVector2Array([
		Vector2(min_point.x, min_point.y),
		Vector2(max_point.x, min_point.y),
		Vector2(max_point.x, max_point.y),
		Vector2(min_point.x, max_point.y),
	])
