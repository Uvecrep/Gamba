extends RefCounted

const NAVIGATION_GOAL_PROBE_SCRIPT = preload("res://entities/shared/navigation_goal_probe.gd")

var unit

func _init(owner) -> void:
	unit = owner

func handle_move_command() -> void:
	var distance_to_target: float = unit.global_position.distance_to(unit._move_target_position)
	if distance_to_target > unit.target_reach_distance:
		unit._move_towards(unit._move_target_position)
	else:
		unit.velocity = Vector2.ZERO
		if unit._hold_toggle_enabled:
			unit._command_mode = unit.CommandMode.HOLD
		else:
			unit._command_mode = unit.CommandMode.AUTO

	unit._try_attack_in_range()

func handle_hold_command() -> void:
	unit.velocity = Vector2.ZERO
	unit._clear_navigation_target()
	unit._try_attack_in_range()

func handle_follow_command() -> void:
	var follow_start_us: int = Time.get_ticks_usec()
	if not is_instance_valid(unit._player_target):
		unit._player_target = unit._find_player()

	if not is_instance_valid(unit._player_target):
		unit._command_mode = unit.CommandMode.AUTO
		unit.velocity = Vector2.ZERO
		unit._perf_mark_scope(&"summon.follow_handler", follow_start_us, {
			"status": "no_player",
		})
		return

	if unit._attack_lock_time_left > 0.0:
		unit.velocity = Vector2.ZERO
		unit._try_attack_in_range()
		unit._perf_mark_scope(&"summon.follow_handler", follow_start_us, {
			"status": "attack_lock",
		})
		return

	update_follow_navigation_target(unit._player_target.global_position)

	if unit._follow_snapshot_target == Vector2.INF:
		unit._follow_snapshot_target = get_follow_formation_target(unit._player_target.global_position)
		unit._set_navigation_target(unit._follow_snapshot_target)
		unit._last_follow_nav_target = unit._follow_snapshot_target
		unit._time_to_follow_nav_refresh = unit._get_follow_nav_refresh_wait(unit._follow_snapshot_target)

	var distance_to_follow_snapshot: float = unit.global_position.distance_to(unit._follow_snapshot_target)
	if distance_to_follow_snapshot > maxf(unit.target_reach_distance, 16.0):
		unit.velocity = unit._get_navigation_velocity(unit._follow_snapshot_target)
	else:
		unit.velocity = Vector2.ZERO
		unit._clear_navigation_target()

	unit._try_attack_in_range()
	unit._perf_mark_scope(&"summon.follow_handler", follow_start_us)

func handle_non_attacker_auto() -> void:
	if is_instance_valid(unit._player_target) and unit.global_position.distance_to(unit._player_target.global_position) > unit.follow_player_distance:
		unit._move_towards(unit._player_target.global_position)
	else:
		unit.velocity = Vector2.ZERO
		unit._clear_navigation_target()

func update_follow_navigation_target(player_position: Vector2) -> void:
	var update_start_us: int = Time.get_ticks_usec()
	if not unit._uses_navigation_agent():
		unit._perf_mark_scope(&"summon.update_follow_nav_target", update_start_us, {
			"status": "no_nav_agent",
		})
		return
	if unit._navigation_agent == null:
		unit._perf_mark_scope(&"summon.update_follow_nav_target", update_start_us, {
			"status": "missing_nav_agent",
		})
		return
	if unit._navigation_agent.get_navigation_map() == RID():
		unit._perf_mark_scope(&"summon.update_follow_nav_target", update_start_us, {
			"status": "missing_nav_map",
		})
		return

	var follow_target: Vector2 = get_follow_formation_target(player_position)
	if unit._time_to_follow_nav_refresh > 0.0:
		unit._perf_mark_scope(&"summon.update_follow_nav_target", update_start_us, {
			"status": "refresh_wait",
		})
		return

	unit._set_navigation_target(follow_target)
	unit._follow_snapshot_target = follow_target
	unit._last_follow_nav_target = follow_target
	unit._time_to_follow_nav_refresh = unit._get_follow_nav_refresh_wait(follow_target)
	unit._perf_inc(&"summon.follow_nav_target_updates")
	unit._perf_mark_scope(&"summon.update_follow_nav_target", update_start_us)

func get_follow_formation_target(player_position: Vector2) -> Vector2:
	var radius: float = maxf(unit.follow_formation_radius, 0.0)
	if radius <= 0.0:
		return player_position

	return player_position + (Vector2.RIGHT.rotated(unit._follow_formation_angle) * radius)

func move_towards(target_position: Vector2) -> void:
	if unit._attack_lock_time_left > 0.0:
		unit.velocity = Vector2.ZERO
		return

	if unit.global_position.distance_to(target_position) > unit.target_reach_distance:
		if unit._uses_navigation_agent():
			# AUTO/FOLLOW already update nav goals on their own timers; avoid per-frame target resets.
			if unit._command_mode == unit.CommandMode.MOVE:
				unit._set_navigation_target(target_position)
			unit.velocity = unit._get_navigation_velocity(target_position)
		else:
			unit.velocity = unit.global_position.direction_to(target_position) * unit.move_speed
	else:
		unit.velocity = Vector2.ZERO
		unit._clear_navigation_target()

func update_stuck_recovery(delta: float, pre_move_position: Vector2) -> void:
	if not unit.stuck_detection_enabled:
		unit._stuck_window_failures = 0
		unit._stuck_window_distance_accum = 0.0
		unit._stuck_check_time_left = maxf(unit.stuck_check_window_seconds, 0.05)
		return
	if not unit._uses_navigation_agent():
		return
	if unit._navigation_agent == null or unit._navigation_agent.get_navigation_map() == RID():
		return
	if unit._command_mode == unit.CommandMode.HOLD:
		unit._stuck_window_failures = 0
		unit._stuck_window_distance_accum = 0.0
		unit._stuck_check_time_left = maxf(unit.stuck_check_window_seconds, 0.05)
		return
	if unit._command_mode == unit.CommandMode.FOLLOW:
		# Follow mode should keep snapping toward player updates rather than detouring to recovery waypoints.
		unit._stuck_window_failures = 0
		unit._stuck_window_distance_accum = 0.0
		unit._stuck_check_time_left = maxf(unit.stuck_check_window_seconds, 0.05)
		return

	var current_goal: Vector2 = unit._get_current_navigation_goal()
	if current_goal == Vector2.INF:
		unit._stuck_window_failures = 0
		unit._stuck_window_distance_accum = 0.0
		unit._stuck_check_time_left = maxf(unit.stuck_check_window_seconds, 0.05)
		return

	var min_goal_distance: float = maxf(unit.target_reach_distance * 2.0, 24.0)
	if unit._command_mode == unit.CommandMode.FOLLOW:
		min_goal_distance = maxf(unit.command_follow_distance * 0.5, 24.0)

	var should_be_advancing: bool = unit.global_position.distance_to(current_goal) > min_goal_distance
	if not should_be_advancing:
		unit._stuck_window_failures = 0
		unit._stuck_window_distance_accum = 0.0
		unit._stuck_check_time_left = maxf(unit.stuck_check_window_seconds, 0.05)
		return

	unit._stuck_check_time_left = maxf(unit._stuck_check_time_left - delta, 0.0)
	unit._stuck_window_distance_accum += pre_move_position.distance_to(unit.global_position)
	if unit._stuck_check_time_left > 0.0:
		return

	var moved_enough: bool = unit._stuck_window_distance_accum >= maxf(unit.stuck_min_distance_per_window, 0.5)
	if moved_enough:
		unit._stuck_window_failures = 0
	else:
		unit._stuck_window_failures += 1

	unit._stuck_check_time_left = maxf(unit.stuck_check_window_seconds, 0.05)
	unit._stuck_window_distance_accum = 0.0

	if unit._stuck_window_failures < maxi(unit.stuck_required_windows, 1):
		return
	if unit._stuck_recovery_cooldown_time_left > 0.0:
		return
	if not unit._try_consume_stuck_recovery_budget():
		return

	unit._trigger_stuck_recovery(current_goal)
	unit._stuck_window_failures = 0
	unit._stuck_recovery_cooldown_time_left = maxf(unit.stuck_recovery_cooldown_seconds, 0.25)

func get_current_navigation_goal() -> Vector2:
	if unit._command_mode == unit.CommandMode.MOVE:
		return unit._move_target_position

	if unit._command_mode == unit.CommandMode.FOLLOW:
		if unit._follow_snapshot_target != Vector2.INF:
			return unit._follow_snapshot_target
		if is_instance_valid(unit._player_target):
			return unit._player_target.global_position
		return Vector2.INF

	if unit._command_mode == unit.CommandMode.AUTO:
		if not unit._is_non_attacker_identity() and is_instance_valid(unit._enemy_target):
			return unit._enemy_target.global_position
		if is_instance_valid(unit._player_target):
			return unit._player_target.global_position
		return Vector2.INF

	return Vector2.INF

func trigger_stuck_recovery(goal_position: Vector2) -> void:
	if goal_position == Vector2.INF:
		return

	var recovery_start_us: int = Time.get_ticks_usec()
	var recovery_waypoint: Vector2 = choose_stuck_recovery_waypoint(goal_position)
	unit._clear_navigation_target()
	unit._set_navigation_target(recovery_waypoint)

	if unit._command_mode == unit.CommandMode.FOLLOW:
		unit._follow_snapshot_target = recovery_waypoint
		unit._time_to_follow_nav_refresh = 0.0

	unit._time_to_nav_goal_refresh = 0.0
	unit._time_to_repath = 0.0
	unit._perf_inc(&"summon.stuck_recoveries")
	unit._perf_mark_scope(&"summon.stuck_recovery", recovery_start_us, {
		"mode": unit.get_command_mode_name(),
	})

func choose_stuck_recovery_waypoint(goal_position: Vector2) -> Vector2:
	if unit._navigation_agent == null:
		return goal_position

	var nav_map: RID = unit._navigation_agent.get_navigation_map()
	if nav_map == RID():
		return goal_position

	var best_candidate: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, goal_position)
	var best_score: float = best_candidate.distance_to(goal_position) + (best_candidate.distance_to(unit.global_position) * 0.1)
	var base_direction: Vector2 = unit.global_position.direction_to(goal_position)
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT

	var probe_points: int = mini(maxi(unit.stuck_recovery_probe_points, 4), 8)
	var ring_count: int = mini(maxi(unit.stuck_recovery_probe_rings, 1), 2)
	var ring_step: float = maxf(unit.stuck_recovery_probe_step, 12.0)
	var max_samples: int = maxi(unit.stuck_recovery_max_samples, 4)
	var sampled: int = 0

	for ring_index in range(1, ring_count + 1):
		var probe_radius: float = ring_step * float(ring_index)
		for point_index in range(probe_points):
			if sampled >= max_samples:
				break
			var angle: float = TAU * float(point_index) / float(probe_points)
			var probe_direction: Vector2 = base_direction.rotated(angle)
			var sample_position: Vector2 = unit.global_position + (probe_direction * probe_radius)
			var projected_sample: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, sample_position)
			sampled += 1
			if projected_sample.distance_to(unit.global_position) < 12.0:
				continue

			var score: float = projected_sample.distance_to(sample_position) + (projected_sample.distance_to(goal_position) * 0.08)
			if score < best_score:
				best_score = score
				best_candidate = projected_sample

		if sampled >= max_samples:
			break

	return best_candidate

func uses_navigation_agent() -> bool:
	return unit.summon_identity != unit.ID_GHOST and unit.summon_identity != unit.ID_FROST_WISP and unit.summon_identity != unit.ID_SOUL_LANTERN and unit.summon_identity != unit.ID_GRAVE_HOUND and unit.summon_identity != unit.ID_POSSESSOR

func get_navigation_velocity(target_position: Vector2) -> Vector2:
	if not unit._uses_navigation_agent():
		return unit.global_position.direction_to(target_position) * unit.move_speed

	if unit._navigation_agent == null or unit._navigation_agent.get_navigation_map() == RID():
		return unit.global_position.direction_to(target_position) * unit.move_speed

	if unit._time_to_nav_velocity_refresh > 0.0:
		return unit._cached_nav_velocity

	unit._time_to_nav_velocity_refresh = unit._get_nav_velocity_refresh_wait()

	if unit._navigation_agent.is_navigation_finished():
		unit._cached_nav_velocity = Vector2.ZERO
		return unit._cached_nav_velocity

	var next_path_position: Vector2 = unit._navigation_agent.get_next_path_position()
	unit._cached_nav_velocity = unit.global_position.direction_to(next_path_position) * unit.move_speed
	return unit._cached_nav_velocity

func get_nav_velocity_refresh_wait() -> float:
	var wait_time: float = maxf(unit.nav_velocity_refresh_interval, 0.01)
	if unit._command_mode == unit.CommandMode.FOLLOW:
		wait_time = minf(wait_time, maxf(unit.follow_nav_target_update_interval * 0.5, 0.02))
	if unit._is_far_from_player():
		wait_time *= maxf(unit.far_lod_velocity_refresh_multiplier, 1.0)
	return wait_time

func set_navigation_target(target_position: Vector2) -> void:
	if not unit._uses_navigation_agent():
		return
	if unit._navigation_agent == null:
		return

	if unit._navigation_agent.target_position.distance_to(target_position) <= 6.0:
		return

	unit._navigation_agent.target_position = target_position
	unit._time_to_nav_velocity_refresh = 0.0

func set_navigation_target_for_target(target: Node2D) -> void:
	var nav_target_start_us: int = Time.get_ticks_usec()
	if target == null:
		unit._perf_mark_scope(&"summon.set_nav_target_for_target", nav_target_start_us, {
			"status": "missing_target",
		})
		return

	if not unit._uses_navigation_agent():
		unit._perf_mark_scope(&"summon.set_nav_target_for_target", nav_target_start_us, {
			"status": "no_nav_agent",
		})
		return

	if unit._navigation_agent == null or unit._navigation_agent.get_navigation_map() == RID():
		unit._set_navigation_target(target.global_position)
		unit._perf_mark_scope(&"summon.set_nav_target_for_target", nav_target_start_us, {
			"status": "fallback_direct_target",
		})
		return

	var desired_distance: float = unit.attack_range if target == unit._enemy_target else unit.target_reach_distance
	var should_probe_ring: bool = target == unit._enemy_target and not unit._is_far_from_player() and unit._try_consume_nav_probe_budget()
	var best_target: Vector2 = unit._choose_best_navigation_target(target.global_position, desired_distance, should_probe_ring)
	unit._set_navigation_target(best_target)
	unit._perf_mark_scope(&"summon.set_nav_target_for_target", nav_target_start_us, {
		"probe_ring": should_probe_ring,
	})

func choose_best_navigation_target(target_position: Vector2, desired_distance: float, probe_ring: bool) -> Vector2:
	return NAVIGATION_GOAL_PROBE_SCRIPT.choose_best_navigation_target(
		unit._navigation_agent,
		unit.global_position,
		target_position,
		desired_distance,
		probe_ring,
		unit.nav_probe_ring_points
	)

func try_consume_nav_probe_budget() -> bool:
	return NAVIGATION_GOAL_PROBE_SCRIPT.try_consume_probe_budget(&"summon_nav_probe", unit.nav_probe_ring_max_per_frame)

func try_consume_stuck_recovery_budget() -> bool:
	var frame: int = Engine.get_physics_frames()
	if frame != unit._stuck_recovery_frame:
		unit._stuck_recovery_frame = frame
		unit._stuck_recovery_count = 0

	var max_per_frame: int = maxi(unit.stuck_recovery_max_per_frame, 1)
	if unit._stuck_recovery_count >= max_per_frame:
		return false

	unit._stuck_recovery_count += 1
	return true

func clear_navigation_target() -> void:
	if not unit._uses_navigation_agent():
		return
	if unit._navigation_agent == null:
		return

	unit._navigation_agent.target_position = unit.global_position
	unit._cached_nav_velocity = Vector2.ZERO
	unit._time_to_nav_velocity_refresh = 0.0

func get_follow_enemy_scan_wait() -> float:
	var wait_time: float = maxf(unit.follow_enemy_scan_interval, 0.1)
	if unit._is_far_from_player():
		wait_time *= maxf(unit.far_lod_follow_refresh_multiplier, 1.0)
	return wait_time

func should_refresh_auto_navigation_goal(nav_target: Node2D) -> bool:
	if nav_target == null:
		return false
	if unit._last_nav_goal_target != nav_target:
		return true
	if unit._navigation_agent == null:
		return true

	var desired_position: Vector2 = nav_target.global_position
	var current_target_position: Vector2 = unit._navigation_agent.target_position
	return current_target_position.distance_to(desired_position) >= maxf(unit.follow_nav_target_min_shift, 4.0)

func get_target_retarget_wait(target_position: Vector2) -> float:
	var base_wait: float = maxf(unit.retarget_min_interval, 2.0)
	base_wait = maxf(base_wait, maxf(unit.nav_goal_update_interval, 0.05))
	base_wait = maxf(base_wait, maxf(unit.follow_nav_target_update_interval, 0.05))

	var extra_wait: float = 0.0
	var start_distance: float = maxf(unit.retarget_far_distance_start, 0.0)
	var span_distance: float = maxf(unit.retarget_far_distance_span, 1.0)
	var distance_to_target: float = unit.global_position.distance_to(target_position)
	if distance_to_target > start_distance:
		var t: float = clampf((distance_to_target - start_distance) / span_distance, 0.0, 1.0)
		extra_wait = t * maxf(unit.retarget_far_interval_bonus, 0.0)

	return base_wait + extra_wait

func get_follow_nav_refresh_wait(follow_target: Vector2) -> float:
	var wait_time: float = maxf(unit.follow_nav_target_update_interval, 0.08)
	if unit._is_far_from_player():
		wait_time *= maxf(unit.far_lod_follow_refresh_multiplier, 1.0)

	var distance_to_follow_target: float = unit.global_position.distance_to(follow_target)
	if distance_to_follow_target > maxf(unit.command_follow_distance * 1.5, 110.0):
		wait_time *= 0.5

	return clampf(wait_time, 0.05, maxf(unit.follow_player_retarget_interval, 0.2))
