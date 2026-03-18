extends RefCounted

const GOLD_PICKUP_SCENE: PackedScene = preload("res://entities/pickups/pickup.tscn")
const GOLD_ITEM_ID: StringName = &"gold_coin"
const MIMIC_DISGUISED_TEXTURE_PATH: String = "res://assets/characters/summons/greed/mimic_disguised.png"
const STORM_TOTEM_PLANTED_TEXTURE_PATH: String = "res://assets/characters/summons/elemental/storm_totem_planted.png"
const COIN_SPRITE_PROJECTILE_TEXTURE_PATH: String = "res://assets/objects/gold.png"
const CINDER_IMP_FIREBALL_TEXTURE_PATH: String = "res://assets/vfx/fireball.png"
const MAGMA_TRAIL_TEXTURE_PATH: String = "res://assets/vfx/magma_trail.png"
const UNSTABLE_SHARD_PROJECTILE_TEXTURE_PATH: String = "res://assets/vfx/unstable_shard_projectile.png"
const BANSHEE_SCREAM_TEXTURE_PATH: String = "res://assets/vfx/banshee_scream.png"

static var _mimic_disguised_texture: Texture2D
static var _storm_totem_planted_texture: Texture2D
static var _coin_sprite_projectile_texture: Texture2D
static var _cinder_imp_fireball_texture: Texture2D
static var _magma_trail_texture: Texture2D
static var _unstable_shard_projectile_texture: Texture2D
static var _banshee_scream_texture: Texture2D

var unit
var _magma_trail_tick_time_left: float = 0.0
var _magma_trail_zones: Array[Dictionary] = []
var _soul_support_tick_time_left: float = 0.0
var _soul_target_refresh_time_left: float = 0.0
var _soul_shield_cooldowns: Dictionary = {}
var _storm_totem_planted_time_left: float = 0.0
var _mimic_disguised: bool = false
var _mimic_opening_strike_ready: bool = true
var _mimic_default_texture: Texture2D
var _storm_totem_default_texture: Texture2D
var _tax_collector_bonus_damage: float = 0.0
var _unstable_shard_detonated: bool = false
var _possession_time_left: float = 0.0
var _possessed_target: Node2D

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
	var delta: float = maxf(unit.get_physics_process_delta_time(), 0.0001)
	_update_state_timers(delta)

	if unit._sprite != null:
		var bounce_time: float = Time.get_ticks_msec() / 1000.0
		var bounce_speed: float = unit.idle_bounce_slow_speed
		var bounce_height: float = unit.idle_bounce_slow_height
		if unit.summon_identity == unit.ID_JACK_IN_THE_BOX or unit.summon_identity == unit.ID_SLIME or unit.summon_identity == unit.ID_MIMIC:
			bounce_speed = unit.idle_bounce_fast_speed
			bounce_height = unit.idle_bounce_fast_height

		unit._sprite.position.y = sin(bounce_time * bounce_speed) * bounce_height

	if unit.summon_identity == unit.ID_GHOST:
		if unit._behavior_tick_time_left > 0.0:
			return
		unit._behavior_tick_time_left = 0.22
		for enemy in unit._get_enemies_in_radius(unit.attack_range):
			unit._deal_damage_to_target(enemy, 3.0)
		return

	match unit.summon_identity:
		unit.ID_MAGMA_BEETLE:
			_update_magma_beetle_trail(delta)
		unit.ID_STORM_TOTEM:
			_update_storm_totem_planted_state()
		unit.ID_SOUL_LANTERN:
			_update_soul_lantern_support(delta)
		unit.ID_BANSHEE:
			_update_banshee_retreat()
		unit.ID_MIMIC:
			_update_mimic_disguise_state()
		unit.ID_POSSESSOR:
			_update_possession_state()
		_:
			pass

func perform_attack(target: Node2D) -> void:
	if target == null:
		return

	if unit.summon_identity != unit.ID_GHOST and unit.summon_identity != unit.ID_BUSH_BOY and unit.summon_identity != unit.ID_SOUL_LANTERN:
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
		unit.ID_CINDER_IMP:
			attack_cinder_imp(target)
		unit.ID_FROST_WISP:
			attack_frost_wisp(target)
		unit.ID_MAGMA_BEETLE:
			attack_magma_beetle(target)
		unit.ID_STORM_TOTEM:
			attack_storm_totem(target)
		unit.ID_UNSTABLE_SHARD:
			attack_unstable_shard(target)
		unit.ID_BANSHEE:
			attack_banshee(target)
		unit.ID_GRAVE_HOUND:
			attack_grave_hound(target)
		unit.ID_HEX_DOLL:
			attack_hex_doll(target)
		unit.ID_POSSESSOR:
			attack_possessor(target)
		unit.ID_MIMIC:
			attack_mimic(target)
		unit.ID_COIN_SPRITE:
			attack_coin_sprite(target)
		unit.ID_PROSPECTOR:
			attack_prospector(target)
		unit.ID_GOLDEN_GUNNER:
			attack_golden_gunner(target)
		unit.ID_TAX_COLLECTOR:
			attack_tax_collector(target)
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

func attack_cinder_imp(target: Node2D) -> void:
	var damage_multiplier: float = 1.0
	if target is EnemyUnit and (target as EnemyUnit).is_burning():
		damage_multiplier = 1.35
	unit._launch_projectile_attack(target, {
		"projectile_texture": _get_cinder_imp_fireball_texture(),
		"burn_dps": 4.8,
		"burn_duration": 3.0,
		"damage_override": unit.attack_damage * damage_multiplier,
	})

func attack_frost_wisp(target: Node2D) -> void:
	unit._launch_projectile_attack(target, {
		"chill_add": 1,
		"chill_duration": 3.0,
		"freeze_threshold": 5,
		"freeze_duration": 1.25,
		"damage_override": unit.attack_damage,
	})

func attack_magma_beetle(target: Node2D) -> void:
	unit._deal_damage_to_target(target, unit.attack_damage, {
		"burn_dps": 2.2,
		"burn_duration": 2.6,
		"knockback_force": 90.0,
	})

func attack_storm_totem(target: Node2D) -> void:
	if _storm_totem_planted_time_left <= 0.0:
		_storm_totem_planted_time_left = 2.6
		_apply_storm_totem_planted_visual(true)
		unit._attack_lock_time_left = maxf(unit._attack_lock_time_left, 0.3)
		return

	_chain_lightning_enemy_only(target, 3, unit.attack_damage * 0.82, 0.86)

func attack_unstable_shard(_target: Node2D) -> void:
	explode_unstable_shard()
	unit.take_damage(unit.max_health * 99.0)

func attack_banshee(primary_target: Node2D) -> void:
	var to_primary: Vector2 = (primary_target.global_position - unit.global_position).normalized()
	if to_primary == Vector2.ZERO:
		to_primary = Vector2.RIGHT

	var scream_texture: Texture2D = _get_banshee_scream_texture()
	if scream_texture != null:
		unit._spawn_world_vfx(
			scream_texture,
			unit.global_position,
			to_primary.angle() + deg_to_rad(30.0),
			Vector2(1.4, 1.1) * 4.0,
			0.2,
			true,
			Vector2(0.0, 1.0)
		)

	var cone_half_angle_cos: float = cos(deg_to_rad(30.0))
	for enemy in unit._get_enemies_in_radius(unit.attack_range * 0.95):
		var to_enemy: Vector2 = (enemy.global_position - unit.global_position).normalized()
		if to_enemy == Vector2.ZERO:
			continue
		if to_primary.dot(to_enemy) < cone_half_angle_cos:
			continue
		unit._deal_damage_to_target(enemy, unit.attack_damage * 0.7, {
			"fear_duration": 1.6,
		})

func attack_grave_hound(target: Node2D) -> void:
	var missing_health_ratio: float = 0.0
	if target is EnemyUnit:
		missing_health_ratio = (target as EnemyUnit).get_missing_health_ratio()
	var scaled_damage: float = unit.attack_damage * (1.0 + (missing_health_ratio * 1.2))
	unit._deal_damage_to_target(target, scaled_damage)

func attack_hex_doll(target: Node2D) -> void:
	unit._deal_damage_to_target(target, unit.attack_damage, {
		"hex_duration": 4.0,
		"hex_damage_multiplier": 1.22,
		"hex_spread_on_death_radius": 135.0,
	})

func attack_possessor(target: Node2D) -> void:
	unit._deal_damage_to_target(target, unit.attack_damage, {
		"stun_duration": 1.25,
	})
	_possessed_target = target
	_possession_time_left = 1.25
	_set_possession_intangible(true)
	unit._attack_lock_time_left = maxf(unit._attack_lock_time_left, 0.35)

func attack_mimic(target: Node2D) -> void:
	if _mimic_disguised:
		_mimic_disguised = false
		_apply_mimic_visual(false)

	var damage: float = unit.attack_damage
	if _mimic_opening_strike_ready:
		damage *= 2.2
		_mimic_opening_strike_ready = false

	unit._deal_damage_to_target(target, damage, {
		"knockback_force": 170.0,
	})

func attack_coin_sprite(target: Node2D) -> void:
	unit._launch_projectile_attack(target, {
		"coin_mark_add": 1,
		"projectile_texture": _get_coin_sprite_projectile_texture(),
	})

func attack_prospector(target: Node2D) -> void:
	unit._launch_projectile_attack(target, {
		"knockback_force": 140.0,
	})

func attack_golden_gunner(target: Node2D) -> void:
	var wealth_gold: int = _get_player_gold_count()
	var wealth_multiplier: float = 1.0 + (float(mini(wealth_gold, 60)) * 0.03)
	var scaled_damage: float = unit.attack_damage * wealth_multiplier
	unit._launch_projectile_attack(target, {
		"damage_override": scaled_damage,
	})

func attack_tax_collector(target: Node2D) -> void:
	var scaled_damage: float = unit.attack_damage + _tax_collector_bonus_damage
	unit._deal_damage_to_target(target, scaled_damage)

func on_enemy_died_nearby(enemy_position: Vector2, _dead_enemy: Node2D) -> void:
	if unit.summon_identity != unit.ID_TAX_COLLECTOR:
		return

	var growth_radius_sq: float = 230.0 * 230.0
	if unit.global_position.distance_squared_to(enemy_position) > growth_radius_sq:
		return

	_tax_collector_bonus_damage = minf(_tax_collector_bonus_damage + 0.5, 45.0)

func explode_unstable_shard() -> void:
	if unit.summon_identity != unit.ID_UNSTABLE_SHARD:
		return
	if _unstable_shard_detonated:
		return

	_unstable_shard_detonated = true
	var shard_texture: Texture2D = _get_unstable_shard_projectile_texture()
	var shard_count: int = 12
	var shard_arc_cos: float = cos(deg_to_rad(24.0))
	var shard_range: float = 240.0
	var shard_damage: float = unit.attack_damage * 1.3
	var nearby_enemies: Array[Node2D] = unit._get_enemies_in_radius(shard_range)
	var used_targets: Dictionary = {}

	for shard_index in range(shard_count):
		var direction: Vector2 = Vector2.RIGHT.rotated((TAU * float(shard_index)) / float(shard_count))
		var directional_target: Node2D = _find_best_enemy_in_direction(nearby_enemies, direction, shard_arc_cos, shard_range, used_targets)
		if is_instance_valid(directional_target):
			used_targets[directional_target.get_instance_id()] = true
			unit._launch_projectile_attack(directional_target, {
				"projectile_texture": shard_texture,
				"damage_override": shard_damage,
				"burn_dps": 5.0,
				"burn_duration": 2.2,
				"knockback_force": 210.0,
			})
			continue

		# If no enemy is lined up for this shard, still render a directional shard burst.
		unit._spawn_world_vfx(
			shard_texture,
			unit.global_position + (direction * 135.0),
			direction.angle(),
			Vector2(1.0, 1.0),
			0.34,
			false,
			Vector2.ZERO,
			12
		)

func _find_best_enemy_in_direction(enemies: Array[Node2D], direction: Vector2, min_direction_dot: float, max_distance: float, used_targets: Dictionary) -> Node2D:
	var best_enemy: Node2D
	var best_distance: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if used_targets.has(enemy.get_instance_id()):
			continue

		var to_enemy: Vector2 = enemy.global_position - unit.global_position
		var distance_to_enemy: float = to_enemy.length()
		if distance_to_enemy <= 0.001 or distance_to_enemy > max_distance:
			continue

		var direction_to_enemy: Vector2 = to_enemy / distance_to_enemy
		if direction.dot(direction_to_enemy) < min_direction_dot:
			continue

		if distance_to_enemy < best_distance:
			best_distance = distance_to_enemy
			best_enemy = enemy

	return best_enemy

func drop_tax_collector_gold() -> void:
	if unit.summon_identity != unit.ID_TAX_COLLECTOR:
		return

	var drop_count: int = int(floor(_tax_collector_bonus_damage * 0.45))
	if _tax_collector_bonus_damage > 0.0:
		drop_count = maxi(drop_count, 1)
	drop_count = mini(drop_count, 12)
	if drop_count <= 0:
		return

	_spawn_gold_pickups(drop_count, unit.global_position)

func is_enemy_detectable() -> bool:
	if unit.summon_identity == unit.ID_MIMIC and _mimic_disguised:
		return false
	return true

func is_mimic_disguised() -> bool:
	return _mimic_disguised

func _update_state_timers(delta: float) -> void:
	_magma_trail_tick_time_left = maxf(_magma_trail_tick_time_left - delta, 0.0)
	_soul_support_tick_time_left = maxf(_soul_support_tick_time_left - delta, 0.0)
	_soul_target_refresh_time_left = maxf(_soul_target_refresh_time_left - delta, 0.0)
	_update_soul_shield_cooldowns(delta)

	if _storm_totem_planted_time_left > 0.0:
		_storm_totem_planted_time_left = maxf(_storm_totem_planted_time_left - delta, 0.0)
		if _storm_totem_planted_time_left <= 0.0:
			_apply_storm_totem_planted_visual(false)

	if _possession_time_left > 0.0:
		_possession_time_left = maxf(_possession_time_left - delta, 0.0)
		if _possession_time_left <= 0.0:
			_possessed_target = null
			_set_possession_intangible(false)

func _update_magma_beetle_trail(delta: float) -> void:
	if unit.summon_identity != unit.ID_MAGMA_BEETLE:
		return
	_update_magma_trail_zones(delta)
	if delta <= 0.0:
		return
	if _magma_trail_tick_time_left > 0.0:
		return

	_magma_trail_tick_time_left = 0.56
	var trail_position: Vector2 = unit.global_position + Vector2(0.0, 6.0)
	unit._spawn_world_vfx(_get_magma_trail_texture(), trail_position, 0.0, Vector2(1.75, 1.75), 5.4, false, Vector2.ZERO, -5)
	_magma_trail_zones.append({
		"position": trail_position,
		"time_left": 5.4,
		"tick_time_left": 0.0,
	})
	for enemy in unit._get_enemies_in_radius_from_point(trail_position, 56.0):
		unit._deal_damage_to_target(enemy, 1.6, {
			"burn_dps": 2.0,
			"burn_duration": 2.8,
		})

func _update_magma_trail_zones(delta: float) -> void:
	if _magma_trail_zones.is_empty():
		return

	for zone_index in range(_magma_trail_zones.size() - 1, -1, -1):
		var zone: Dictionary = _magma_trail_zones[zone_index]
		var time_left: float = maxf(float(zone.get("time_left", 0.0)) - delta, 0.0)
		if time_left <= 0.0:
			_magma_trail_zones.remove_at(zone_index)
			continue

		var tick_time_left: float = maxf(float(zone.get("tick_time_left", 0.0)) - delta, 0.0)
		zone["time_left"] = time_left
		zone["tick_time_left"] = tick_time_left

		if tick_time_left <= 0.0:
			var zone_position: Vector2 = zone.get("position", Vector2.ZERO)
			for enemy in unit._get_enemies_in_radius_from_point(zone_position, 56.0):
				unit._deal_damage_to_target(enemy, 1.6, {
					"burn_dps": 2.0,
					"burn_duration": 2.8,
				})
			zone["tick_time_left"] = 0.25

		_magma_trail_zones[zone_index] = zone

func _update_soul_lantern_support(delta: float) -> void:
	if unit.summon_identity != unit.ID_SOUL_LANTERN:
		return
	if delta <= 0.0:
		return

	if _soul_target_refresh_time_left <= 0.0:
		_soul_target_refresh_time_left = 0.35
		var weakest_ally: Node2D = _find_weakest_ally_in_radius(320.0)
		if is_instance_valid(weakest_ally):
			unit._player_target = weakest_ally

	if _soul_support_tick_time_left > 0.0:
		return

	_soul_support_tick_time_left = 0.4
	for ally in _get_allied_targets_in_radius(155.0):
		if not is_instance_valid(ally):
			continue

		var health_fraction: float = _get_health_fraction(ally)
		if ally is SummonUnit:
			var ally_summon: SummonUnit = ally as SummonUnit
			if health_fraction < 0.98:
				ally_summon.heal(6.0)
			else:
				_try_apply_soul_shield(ally_summon)
		elif ally is Player:
			var ally_player: Player = ally as Player
			if health_fraction < 0.98:
				ally_player.heal(6.0)
			else:
				_try_apply_soul_shield(ally_player)

func _update_soul_shield_cooldowns(delta: float) -> void:
	if _soul_shield_cooldowns.is_empty():
		return

	var keys_to_erase: Array[int] = []
	for key_variant in _soul_shield_cooldowns.keys():
		var key: int = int(key_variant)
		var remaining: float = maxf(float(_soul_shield_cooldowns.get(key, 0.0)) - delta, 0.0)
		if remaining <= 0.0:
			keys_to_erase.append(key)
		else:
			_soul_shield_cooldowns[key] = remaining

	for key in keys_to_erase:
		_soul_shield_cooldowns.erase(key)

func _try_apply_soul_shield(ally: Node2D) -> void:
	if ally == null:
		return

	var ally_id: int = ally.get_instance_id()
	if float(_soul_shield_cooldowns.get(ally_id, 0.0)) > 0.0:
		return

	var granted: bool = false
	if ally is SummonUnit:
		granted = (ally as SummonUnit).grant_hit_shield()
	elif ally is Player:
		granted = (ally as Player).grant_hit_shield()

	if not granted:
		return

	_soul_shield_cooldowns[ally_id] = 2.8
	unit._spawn_world_vfx(load("res://assets/vfx/shield.png") as Texture2D, ally.global_position + Vector2(0.0, -14.0), 0.0, Vector2(1.0, 1.0), 0.3, false, Vector2.ZERO, 18)

func _update_banshee_retreat() -> void:
	if unit.summon_identity != unit.ID_BANSHEE:
		return
	if not is_instance_valid(unit._enemy_target):
		return
	if unit._time_to_next_attack <= unit.attack_cooldown * 0.45:
		return

	var distance_to_enemy: float = unit.global_position.distance_to(unit._enemy_target.global_position)
	if distance_to_enemy >= unit.attack_range:
		return

	unit.velocity = unit._enemy_target.global_position.direction_to(unit.global_position) * unit.move_speed

func _update_mimic_disguise_state() -> void:
	if unit.summon_identity != unit.ID_MIMIC:
		return
	if unit._sprite == null:
		return

	if _mimic_default_texture == null:
		_mimic_default_texture = unit._sprite.texture

	var close_enemy: Node2D = null
	if is_instance_valid(unit._enemy_target):
		if unit.global_position.distance_to(unit._enemy_target.global_position) <= 120.0:
			close_enemy = unit._enemy_target

	if close_enemy == null:
		var nearby_enemies: Array[Node2D] = unit._get_enemies_in_radius(120.0)
		if not nearby_enemies.is_empty():
			close_enemy = nearby_enemies[0]

	var should_disguise: bool = close_enemy == null and unit._time_to_next_attack <= unit.attack_cooldown * 0.2
	if should_disguise:
		if not _mimic_disguised:
			_mimic_disguised = true
			_mimic_opening_strike_ready = true
			_apply_mimic_visual(true)
	else:
		if _mimic_disguised:
			_mimic_disguised = false
			_apply_mimic_visual(false)

func _update_possession_state() -> void:
	if unit.summon_identity != unit.ID_POSSESSOR:
		return
	if _possession_time_left <= 0.0:
		return
	if not is_instance_valid(_possessed_target):
		return

	unit.global_position = _possessed_target.global_position + Vector2(0.0, -6.0)
	unit.velocity = Vector2.ZERO

func _update_storm_totem_planted_state() -> void:
	if unit.summon_identity != unit.ID_STORM_TOTEM:
		return
	if _storm_totem_planted_time_left <= 0.0:
		return

	unit.velocity = Vector2.ZERO
	unit._attack_lock_time_left = maxf(unit._attack_lock_time_left, 0.06)

func _apply_mimic_visual(disguised: bool) -> void:
	if unit._sprite == null:
		return
	if disguised:
		var disguised_texture: Texture2D = _get_mimic_disguised_texture()
		if disguised_texture != null:
			unit._sprite.texture = disguised_texture
		return

	if _mimic_default_texture != null:
		unit._sprite.texture = _mimic_default_texture

func _apply_storm_totem_planted_visual(planted: bool) -> void:
	if unit._sprite == null:
		return
	if _storm_totem_default_texture == null:
		_storm_totem_default_texture = unit._sprite.texture
	if planted:
		var planted_texture: Texture2D = _get_storm_totem_planted_texture()
		if planted_texture != null:
			unit._sprite.texture = planted_texture
		return

	if _storm_totem_default_texture != null:
		unit._sprite.texture = _storm_totem_default_texture

func _set_possession_intangible(enabled: bool) -> void:
	if enabled:
		unit.collision_mask = 0
		unit.modulate = Color(1.0, 1.0, 1.0, 0.72)
		return

	unit.collision_mask = 0 if unit._is_phasing_identity() else unit.PHYSICS_LAYER_WORLD
	unit.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _chain_lightning_enemy_only(initial_target: Node2D, jump_count: int, starting_damage: float, damage_decay: float) -> void:
	var visited: Dictionary = {}
	var current_target: Node2D = initial_target
	var jump_damage: float = starting_damage
	var chain_from: Vector2 = unit.global_position

	for jump_index in range(maxi(jump_count, 1)):
		if not is_instance_valid(current_target):
			break

		unit._spawn_chain_lightning_vfx(chain_from, current_target.global_position)
		visited[current_target.get_instance_id()] = true
		unit._deal_damage_to_target(current_target, jump_damage)

		jump_damage *= clampf(damage_decay, 0.1, 1.0)
		chain_from = current_target.global_position

		var next_target: Node2D = null
		for enemy in unit._get_enemies_in_radius_from_point(chain_from, 145.0):
			if visited.has(enemy.get_instance_id()):
				continue
			next_target = enemy
			break
		if not is_instance_valid(next_target):
			break
		current_target = next_target

func _find_weakest_ally_in_radius(radius: float) -> Node2D:
	var best_target: Node2D = null
	var best_health_fraction: float = 2.0

	for ally in _get_allied_targets_in_radius(radius):
		if not is_instance_valid(ally):
			continue

		var health_fraction: float = _get_health_fraction(ally)
		if health_fraction < best_health_fraction:
			best_health_fraction = health_fraction
			best_target = ally

	return best_target

func _get_allied_targets_in_radius(radius: float) -> Array[Node2D]:
	var allies: Array[Node2D] = []
	var player: Node2D = unit._find_player()
	if is_instance_valid(player) and player != unit:
		if unit.global_position.distance_to(player.global_position) <= radius:
			allies.append(player)

	for summon_candidate in unit._get_summons_in_radius_from_point(unit.global_position, radius):
		if summon_candidate == unit:
			continue
		allies.append(summon_candidate)

	return allies

func _get_health_fraction(target: Node2D) -> float:
	if target is SummonUnit:
		return (target as SummonUnit).get_health_fraction()
	if target is EnemyUnit:
		return (target as EnemyUnit).get_health_fraction()
	if target is Player:
		var player: Player = target as Player
		if player.max_health <= 0.0:
			return 1.0
		return clampf(player.current_health / player.max_health, 0.0, 1.0)
	return 1.0

func _spawn_gold_pickups(count: int, origin: Vector2) -> void:
	if GOLD_PICKUP_SCENE == null:
		return
	if count <= 0:
		return

	var parent_node: Node = unit.get_tree().current_scene
	if parent_node == null:
		parent_node = unit.get_parent()
	if parent_node == null:
		return

	for index in range(count):
		var pickup_node: Node = GOLD_PICKUP_SCENE.instantiate()
		if not (pickup_node is Pickup):
			if is_instance_valid(pickup_node):
				pickup_node.queue_free()
			continue

		var gold_pickup: Pickup = pickup_node as Pickup
		parent_node.add_child(gold_pickup)
		gold_pickup.set_data(GOLD_ITEM_ID)
		var angle: float = TAU * float(index) / float(maxi(count, 1))
		var spread: float = randf_range(10.0, 22.0)
		gold_pickup.global_position = origin + (Vector2.RIGHT.rotated(angle) * spread)

func _get_player_gold_count() -> int:
	var player_target: Node2D = unit._find_player()
	if not (player_target is Player):
		return 0

	var player: Player = player_target as Player
	var inventory: PlayerInventory = player.player_inventory
	if inventory == null:
		return 0
	return maxi(inventory.get_gold_count(), 0)

func _get_mimic_disguised_texture() -> Texture2D:
	if _mimic_disguised_texture == null:
		_mimic_disguised_texture = load(MIMIC_DISGUISED_TEXTURE_PATH) as Texture2D
	return _mimic_disguised_texture

func _get_storm_totem_planted_texture() -> Texture2D:
	if _storm_totem_planted_texture == null:
		_storm_totem_planted_texture = load(STORM_TOTEM_PLANTED_TEXTURE_PATH) as Texture2D
	return _storm_totem_planted_texture

func _get_cinder_imp_fireball_texture() -> Texture2D:
	if _cinder_imp_fireball_texture == null:
		_cinder_imp_fireball_texture = load(CINDER_IMP_FIREBALL_TEXTURE_PATH) as Texture2D
	return _cinder_imp_fireball_texture

func _get_coin_sprite_projectile_texture() -> Texture2D:
	if _coin_sprite_projectile_texture == null:
		_coin_sprite_projectile_texture = load(COIN_SPRITE_PROJECTILE_TEXTURE_PATH) as Texture2D
	return _coin_sprite_projectile_texture

func _get_magma_trail_texture() -> Texture2D:
	if _magma_trail_texture == null:
		_magma_trail_texture = load(MAGMA_TRAIL_TEXTURE_PATH) as Texture2D
	return _magma_trail_texture

func _get_unstable_shard_projectile_texture() -> Texture2D:
	if _unstable_shard_projectile_texture == null:
		_unstable_shard_projectile_texture = load(UNSTABLE_SHARD_PROJECTILE_TEXTURE_PATH) as Texture2D
	return _unstable_shard_projectile_texture

func _get_banshee_scream_texture() -> Texture2D:
	if _banshee_scream_texture == null:
		_banshee_scream_texture = load(BANSHEE_SCREAM_TEXTURE_PATH) as Texture2D
	return _banshee_scream_texture
