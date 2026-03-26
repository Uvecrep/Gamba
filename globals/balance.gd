extends Node

const ENEMY_ARCHETYPE_BASIC_RAIDER: StringName = &"basic_raider"
const ENEMY_ARCHETYPE_FAST_RAIDER: StringName = &"fast_raider"
const ENEMY_ARCHETYPE_TANK_RAIDER: StringName = &"tank_raider"
const ENEMY_ARCHETYPE_RANGED_RAIDER: StringName = &"ranged_raider"
const ENEMY_ARCHETYPE_HEALING_RAIDER: StringName = &"healing_raider"
const ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN: StringName = &"trenchcoat_goblin"
const ENEMY_ARCHETYPE_GOBLIN: StringName = &"goblin"

const DAY_NIGHT_DEFAULTS: Dictionary = {
	"enable_day_night_cycle": true,
	"day_duration_seconds": 60.0,
	"night_duration_seconds": 36.0,
	"first_night_starts_immediately": false,
	"night_waves_per_cycle": 3,
	"night_wave_base_size": 2,
	"night_wave_size_growth_per_night": 1,
	"night_wave_spawn_scale": 0.9,
	"night_wave_spacing_seconds": 10.0,
}

const ENEMY_SPAWNER_DEFAULTS: Dictionary = {
	"spawn_interval": 25.0,
	"max_alive_enemies": 16,
	"wave_spawn_point_radius": 200.0,
	"spawn_archetype_pool": [
		"basic_raider",
		"basic_raider",
		"basic_raider",
		"fast_raider",
		"fast_raider",
		"tank_raider",
		"ranged_raider",
		"healing_raider",
		"trenchcoat_goblin",
	],
}

const BASE_ENEMY_ARCHETYPE_STATS: Dictionary = {
	"move_speed": 90.0,
	"max_health": 100.0,
	"melee_damage": 15.0,
	"melee_attack_cooldown": 1.0,
	"ranged_damage": 0.0,
	"ranged_attack_range": 340.0,
	"ranged_attack_cooldown": 1.3,
	"healer_keep_away_distance": 170.0,
	"healer_aura_radius": 220.0,
	"healer_heal_per_second": 0.0,
	"split_spawn_count": 4,
	"texture_path": "res://assets/characters/raider.png",
}

const ENEMY_ARCHETYPE_OVERRIDES: Dictionary = {
	ENEMY_ARCHETYPE_BASIC_RAIDER: {
		"texture_path": "res://assets/characters/raider.png",
	},
	ENEMY_ARCHETYPE_FAST_RAIDER: {
		"move_speed": 145.0,
		"max_health": 65.0,
		"melee_damage": 14.0,
		"melee_attack_cooldown": 0.85,
		"texture_path": "res://assets/characters/fast_raider.png",
	},
	ENEMY_ARCHETYPE_TANK_RAIDER: {
		"move_speed": 58.0,
		"max_health": 240.0,
		"melee_damage": 9.0,
		"melee_attack_cooldown": 1.1,
		"texture_path": "res://assets/characters/tank_raider.png",
	},
	ENEMY_ARCHETYPE_RANGED_RAIDER: {
		"move_speed": 84.0,
		"max_health": 70.0,
		"melee_damage": 0.0,
		"ranged_damage": 13.0,
		"ranged_attack_range": 360.0,
		"ranged_attack_cooldown": 1.35,
		"texture_path": "res://assets/characters/ranged_raider.png",
	},
	ENEMY_ARCHETYPE_HEALING_RAIDER: {
		"move_speed": 76.0,
		"max_health": 85.0,
		"melee_damage": 0.0,
		"healer_keep_away_distance": 180.0,
		"healer_aura_radius": 230.0,
		"healer_heal_per_second": 14.0,
		"texture_path": "res://assets/characters/healing_raider.png",
	},
	ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN: {
		"move_speed": 95.0,
		"max_health": 260.0,
		"melee_damage": 20.0,
		"melee_attack_cooldown": 0.9,
		"texture_path": "res://assets/characters/trenchcoat_goblins.png",
	},
	ENEMY_ARCHETYPE_GOBLIN: {
		"move_speed": 102.0,
		"max_health": 95.0,
		"melee_damage": 13.0,
		"melee_attack_cooldown": 0.9,
		"texture_path": "res://assets/characters/goblin.png",
	},
}

const BASE_SUMMON_RUNTIME_CONFIG: Dictionary = {
	"move_speed_multiplier": 1.0,
	"attack_range_multiplier": 1.0,
	"attack_damage_multiplier": 1.0,
	"attack_cooldown_multiplier": 1.0,
	"max_health_multiplier": 1.0,
	"follow_player_distance_multiplier": 1.0,
}

const SUMMON_RUNTIME_OVERRIDES: Dictionary = {
	&"slime": {
		"split_child_count": 2,
		"split_child_scale": 0.72,
		"split_child_health_scale": 0.45,
		"split_child_damage_scale": 0.45,
		"split_child_move_speed_multiplier": 1.25,
	},
	&"tax_collector": {
		"tax_collector_growth_radius": 230.0,
		"tax_collector_bonus_damage_per_enemy": 0.5,
		"tax_collector_bonus_damage_cap": 45.0,
		"tax_collector_gold_drop_scale": 0.45,
		"tax_collector_gold_drop_cap": 12,
	},
}


func get_day_night_setting(key: StringName, fallback: Variant) -> Variant:
	return DAY_NIGHT_DEFAULTS.get(String(key), fallback)


func get_enemy_spawner_setting(key: StringName, fallback: Variant) -> Variant:
	return ENEMY_SPAWNER_DEFAULTS.get(String(key), fallback)


func get_enemy_spawner_spawn_archetype_pool(fallback: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var pool: Variant = ENEMY_SPAWNER_DEFAULTS.get("spawn_archetype_pool", fallback)
	if pool is PackedStringArray:
		return (pool as PackedStringArray).duplicate()
	if pool is Array:
		var result: PackedStringArray = PackedStringArray()
		for raw_entry in pool:
			result.append(String(raw_entry))
		return result
	return fallback.duplicate()


func get_enemy_archetype_stats(archetype: StringName) -> Dictionary:
	var resolved_archetype: StringName = _normalize_enemy_archetype(archetype)
	var stats: Dictionary = BASE_ENEMY_ARCHETYPE_STATS.duplicate(true)
	var overrides: Variant = ENEMY_ARCHETYPE_OVERRIDES.get(resolved_archetype, {})
	if overrides is Dictionary:
		for raw_key in (overrides as Dictionary).keys():
			stats[raw_key] = overrides[raw_key]
	return stats


func get_summon_runtime_config(identity: StringName) -> Dictionary:
	var config: Dictionary = BASE_SUMMON_RUNTIME_CONFIG.duplicate(true)
	var overrides: Variant = SUMMON_RUNTIME_OVERRIDES.get(identity, {})
	if overrides is Dictionary:
		for raw_key in (overrides as Dictionary).keys():
			config[raw_key] = overrides[raw_key]
	return config


func _normalize_enemy_archetype(archetype: StringName) -> StringName:
	if archetype == StringName():
		return ENEMY_ARCHETYPE_BASIC_RAIDER

	match archetype:
		ENEMY_ARCHETYPE_BASIC_RAIDER, ENEMY_ARCHETYPE_FAST_RAIDER, ENEMY_ARCHETYPE_TANK_RAIDER, ENEMY_ARCHETYPE_RANGED_RAIDER, ENEMY_ARCHETYPE_HEALING_RAIDER, ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN, ENEMY_ARCHETYPE_GOBLIN:
			return archetype
		_:
			return ENEMY_ARCHETYPE_BASIC_RAIDER
