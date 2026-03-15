extends RefCounted

var unit

func _init(owner) -> void:
	unit = owner

func try_attack_in_range() -> bool:
	if not is_instance_valid(unit._enemy_target):
		return false
	if unit.attack_range <= 0.0 or unit.attack_damage <= 0.0:
		return false

	if unit.global_position.distance_to(unit._enemy_target.global_position) > unit.attack_range:
		return false

	if unit._time_to_next_attack > 0.0:
		return false

	unit._time_to_next_attack = unit.attack_cooldown
	perform_attack(unit._enemy_target)
	return true

func update_passive_archetype_behavior() -> void:
	if unit._sprite != null:
		var bounce_time: float = Time.get_ticks_msec() / 1000.0
		var bounce_speed: float = unit.idle_bounce_slow_speed
		var bounce_height: float = unit.idle_bounce_slow_height
		if unit.summon_identity == unit.ID_JACK_IN_THE_BOX or unit.summon_identity == unit.ID_SLIME:
			bounce_speed = unit.idle_bounce_fast_speed
			bounce_height = unit.idle_bounce_fast_height

		unit._sprite.position.y = sin(bounce_time * bounce_speed) * bounce_height

	if unit.summon_identity != unit.ID_GHOST:
		return
	if unit._behavior_tick_time_left > 0.0:
		return

	unit._behavior_tick_time_left = 0.22
	for enemy in unit._get_enemies_in_radius(unit.attack_range):
		unit._deal_damage_to_target(enemy, 3.0)

func perform_attack(target: Node2D) -> void:
	if target == null:
		return

	if unit.summon_identity != unit.ID_GHOST and unit.summon_identity != unit.ID_BUSH_BOY:
		play_attack_tilt_animation()

	match unit.summon_identity:
		unit.ID_BABY_DRAGON:
			attack_baby_dragon(target)
		unit.ID_SLIME:
			attack_slime(target)
		unit.ID_GHOST:
			# Ghost deals proximity drain as a passive aura.
			pass
		unit.ID_SPARK_GOBLIN:
			attack_spark_goblin(target)
		unit.ID_JACK_IN_THE_BOX:
			attack_jack(target)
		unit.ID_MUSHROOM_KNIGHT:
			attack_mushroom_knight(target)
		unit.ID_ACORN_SPITTER:
			attack_acorn_spitter(target)
		unit.ID_BUSH_BOY:
			# Bush unit is a defensive body blocker and does not attack.
			pass
		unit.ID_BEE_SWARM:
			attack_bee_swarm(target)
		unit.ID_ROOTER:
			attack_rooter(target)
		_:
			unit._launch_projectile_attack(target)

func play_attack_tilt_animation() -> void:
	if unit._sprite == null:
		return

	if is_instance_valid(unit._attack_tilt_tween):
		unit._attack_tilt_tween.kill()

	var tilt_sign: float = -1.0 if (randi() % 2 == 0) else 1.0
	var tilt_angle: float = deg_to_rad(unit.attack_tilt_angle_degrees) * tilt_sign
	var half_duration: float = maxf(unit.attack_tilt_duration * 0.5, 0.03)

	unit._attack_tilt_tween = unit.create_tween()
	unit._attack_tilt_tween.tween_property(unit._sprite, "rotation", tilt_angle, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	unit._attack_tilt_tween.tween_property(unit._sprite, "rotation", 0.0, half_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func attack_baby_dragon(primary_target: Node2D) -> void:
	var to_primary: Vector2 = (primary_target.global_position - unit.global_position).normalized()
	if to_primary == Vector2.ZERO:
		to_primary = Vector2.RIGHT

	unit._spawn_world_vfx(
		unit._vfx_fire_cone,
		unit.global_position,
		to_primary.angle() + deg_to_rad(30.0),
		Vector2(1.45, 1.15) * 4.0,
		0.2,
		true,
		Vector2(0.0, 1.0)
	)

	var cone_half_angle_cos: float = cos(deg_to_rad(22.0))
	for enemy in unit._get_enemies_in_radius(unit.attack_range):
		var to_enemy: Vector2 = (enemy.global_position - unit.global_position).normalized()
		if to_enemy == Vector2.ZERO:
			continue
		if to_primary.dot(to_enemy) < cone_half_angle_cos:
			continue
		unit._deal_damage_to_target(enemy, unit.attack_damage, {
			"burn_dps": 4.0,
			"burn_duration": 2.5,
		})

func attack_slime(target: Node2D) -> void:
	unit._deal_damage_to_target(target, unit.attack_damage, {
		"knockback_force": 120.0,
	})

func attack_spark_goblin(target: Node2D) -> void:
	var visited: Dictionary = {}
	var current_target: Node2D = target
	var jump_damage: float = unit.attack_damage
	var chain_from: Vector2 = unit.global_position

	for jump_index in range(4):
		if not is_instance_valid(current_target):
			break

		unit._spawn_chain_lightning_vfx(chain_from, current_target.global_position)

		visited[current_target.get_instance_id()] = true
		unit._deal_damage_to_target(current_target, jump_damage)
		jump_damage *= 0.78
		chain_from = current_target.global_position

		if jump_index >= 3:
			break

		var next_target: Node2D = find_next_chain_target(current_target.global_position, visited)
		if not is_instance_valid(next_target):
			break
		current_target = next_target

func find_next_chain_target(from_position: Vector2, visited: Dictionary) -> Node2D:
	var enemy_candidates: Array[Node2D] = []
	for enemy in unit._get_enemies_in_radius_from_point(from_position, 135.0):
		if visited.has(enemy.get_instance_id()):
			continue
		enemy_candidates.append(enemy)

	var summon_candidates: Array[Node2D] = []
	for summon_candidate in unit._get_summons_in_radius_from_point(from_position, 135.0):
		if summon_candidate == unit:
			continue
		if visited.has(summon_candidate.get_instance_id()):
			continue
		summon_candidates.append(summon_candidate)

	if not summon_candidates.is_empty() and randf() < 0.65:
		return pick_closest_target(from_position, summon_candidates)

	if not enemy_candidates.is_empty():
		return pick_closest_target(from_position, enemy_candidates)

	if not summon_candidates.is_empty():
		return pick_closest_target(from_position, summon_candidates)

	return null

func pick_closest_target(from_position: Vector2, candidates: Array[Node2D]) -> Node2D:
	var best_target: Node2D
	var best_distance_sq: float = INF
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		var distance_sq: float = from_position.distance_squared_to(candidate.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_target = candidate

	return best_target

func attack_jack(target: Node2D) -> void:
	unit._launch_projectile_attack(target, {
		"knockback_force": 260.0,
		"projectile_texture": unit._vfx_spring_projectile,
		"projectile_rotation_offset": deg_to_rad(45.0),
	})

func attack_mushroom_knight(target: Node2D) -> void:
	unit._deal_damage_to_target(target, unit.attack_damage)

func attack_acorn_spitter(target: Node2D) -> void:
	unit._attack_lock_time_left = maxf(unit._attack_lock_time_left, 0.22)
	unit.velocity = Vector2.ZERO
	unit._launch_projectile_attack(target, {
		"projectile_texture": unit._vfx_acorn_projectile,
	})

func attack_bee_swarm(target: Node2D) -> void:
	unit._deal_damage_to_target(target, unit.attack_damage, {
		"sting_stacks_add": 1,
		"sting_dps_per_stack": 0.5,
		"sting_duration": 2.4,
		"sting_max_stack_burst_damage": 12.0,
	})

func attack_rooter(target: Node2D) -> void:
	unit._deal_damage_to_target(target, unit.attack_damage, {
		"root_duration": 1.1,
	})
