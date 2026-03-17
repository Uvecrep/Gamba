extends RefCounted


static func tick_refresh_time_left(time_left: float, delta: float) -> float:
	return maxf(time_left - delta, 0.0)


static func schedule_next_refresh(
	refresh_interval: float,
	minimum_interval: float,
	jitter_ratio: float,
	initial_delay: float = -1.0
) -> float:
	if initial_delay >= 0.0:
		return initial_delay

	var base_interval: float = maxf(refresh_interval, minimum_interval)
	var clamped_jitter_ratio: float = clampf(jitter_ratio, 0.0, 1.0)
	var jitter: float = randf_range(0.0, base_interval * clamped_jitter_ratio)
	return base_interval + jitter


static func is_any_player_in_fixed_range(
	context_node: Node,
	origin: Vector2,
	radius: float,
	spatial_index: SpatialIndex2D
) -> bool:
	var safe_radius: float = maxf(radius, 0.0)
	if is_instance_valid(spatial_index):
		var nearby_players: Array[Node2D] = spatial_index.get_nodes_in_radius(origin, &"players", safe_radius)
		return not nearby_players.is_empty()

	if context_node == null or context_node.get_tree() == null:
		return false

	var radius_sq: float = safe_radius * safe_radius
	for player in context_node.get_tree().get_nodes_in_group("players"):
		if not (player is Node2D):
			continue

		var player_node: Node2D = player as Node2D
		if origin.distance_squared_to(player_node.global_position) <= radius_sq:
			return true

	return false


static func is_any_player_in_dynamic_range(
	context_node: Node,
	origin: Vector2,
	default_radius: float,
	spatial_index: SpatialIndex2D,
	player_range_property: StringName = &"harvest_range"
) -> bool:
	var safe_default_radius: float = maxf(default_radius, 0.0)
	if is_instance_valid(spatial_index):
		var nearest_player: Node2D = spatial_index.find_closest_in_group(origin, &"players")
		if nearest_player != null:
			var nearest_range: float = _get_player_range(nearest_player, safe_default_radius, player_range_property)
			var nearest_distance_sq: float = origin.distance_squared_to(nearest_player.global_position)
			if nearest_distance_sq <= nearest_range * nearest_range:
				return true

	if context_node == null or context_node.get_tree() == null:
		return false

	for player in context_node.get_tree().get_nodes_in_group("players"):
		if not (player is Node2D):
			continue

		var player_range: float = _get_player_range(player, safe_default_radius, player_range_property)
		var player_node: Node2D = player as Node2D
		var distance_sq: float = origin.distance_squared_to(player_node.global_position)
		if distance_sq <= player_range * player_range:
			return true

	return false


static func _get_player_range(player: Node, fallback_range: float, range_property: StringName) -> float:
	var player_range: Variant = player.get(range_property)
	if typeof(player_range) == TYPE_FLOAT or typeof(player_range) == TYPE_INT:
		return maxf(float(player_range), 0.0)

	return fallback_range
