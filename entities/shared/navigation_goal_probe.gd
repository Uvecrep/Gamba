extends RefCounted
class_name NavigationGoalProbe

static var _probe_frame_by_key: Dictionary = {}
static var _probe_count_by_key: Dictionary = {}

static func choose_best_navigation_target(navigation_agent: NavigationAgent2D, seeker_position: Vector2, target_position: Vector2, desired_distance: float, probe_ring: bool, ring_points: int) -> Vector2:
	if navigation_agent == null:
		return target_position

	var nav_map: RID = navigation_agent.get_navigation_map()
	if nav_map == RID():
		return target_position

	var projected_center: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, target_position)
	if not probe_ring:
		return projected_center

	var direction_from_target: Vector2 = (seeker_position - target_position).normalized()
	if direction_from_target == Vector2.ZERO:
		direction_from_target = Vector2.RIGHT

	var desired_ring_distance: float = maxf(desired_distance, 8.0)
	var best_candidate: Vector2 = projected_center
	var best_score: float = projected_center.distance_to(target_position)
	var sample_count: int = mini(maxi(ring_points, 4), 6)

	for i in range(sample_count):
		var angle_offset: float = TAU * float(i) / float(sample_count)
		var ring_target: Vector2 = target_position + (direction_from_target.rotated(angle_offset) * desired_ring_distance)
		var projected_ring: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, ring_target)
		var candidate_score: float = projected_ring.distance_to(ring_target)
		if candidate_score < best_score:
			best_score = candidate_score
			best_candidate = projected_ring

	return best_candidate

static func try_consume_probe_budget(budget_key: StringName, max_per_frame: int) -> bool:
	var frame: int = Engine.get_physics_frames()
	var tracked_frame: int = int(_probe_frame_by_key.get(budget_key, -1))
	var used_count: int = int(_probe_count_by_key.get(budget_key, 0))
	if frame != tracked_frame:
		tracked_frame = frame
		used_count = 0

	var clamped_max_per_frame: int = maxi(max_per_frame, 1)
	if used_count >= clamped_max_per_frame:
		_probe_frame_by_key[budget_key] = tracked_frame
		_probe_count_by_key[budget_key] = used_count
		return false

	used_count += 1
	_probe_frame_by_key[budget_key] = tracked_frame
	_probe_count_by_key[budget_key] = used_count
	return true