extends Node2D
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var use_balance_defaults: bool = true
@export var spawn_interval: float = 15
@export var max_alive_enemies: int = 8
@export var auto_start: bool = true
@export var randomize_enemy_archetypes: bool = true
@export var snap_spawn_to_navigation: bool = true

@export var wave_spawn_points: Array[Node2D]
var wave_spawn_point_radius: float = 200

@export var spawn_archetype_pool: PackedStringArray = [
	"basic_raider",
	"basic_raider",
	"basic_raider",
	"fast_raider",
	"fast_raider",
	"tank_raider",
	"ranged_raider",
	"healing_raider",
	"trenchcoat_goblin",
]

@onready var _spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	add_to_group("enemy_towers")
	if use_balance_defaults:
		spawn_interval = float(Balance.get_enemy_spawner_setting(&"spawn_interval", spawn_interval))
		max_alive_enemies = int(Balance.get_enemy_spawner_setting(&"max_alive_enemies", max_alive_enemies))
		wave_spawn_point_radius = float(Balance.get_enemy_spawner_setting(&"wave_spawn_point_radius", wave_spawn_point_radius))
		spawn_archetype_pool = Balance.get_enemy_spawner_spawn_archetype_pool(spawn_archetype_pool)

	if enemy_scene == null:
		push_warning("EnemySpawner needs enemy_scene set for wave spawns.")
	if wave_spawn_points == null or wave_spawn_points.is_empty():
		push_warning("EnemySpawner needs wave spawn points to be set")

	_spawn_timer.wait_time = spawn_interval
	if not _spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
		_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_spawn_timer.autostart = false
	if auto_start:
		start_spawning()
	else:
		_spawn_timer.stop()

func start_spawning() -> void:
	if _spawn_timer == null:
		return

	_spawn_timer.wait_time = spawn_interval
	if _spawn_timer.is_stopped():
		_spawn_timer.start()

func stop_spawning() -> void:
	if _spawn_timer == null:
		return

	_spawn_timer.stop()

func spawn_wave(enemy_count: int, ignore_alive_cap: bool = false) -> int:
	if enemy_scene == null:
		return 0

	var requested_count: int = maxi(enemy_count, 0)
	if requested_count <= 0:
		return 0

	var wave_spawn_point = _pick_spawn_position()


	var spawned_count: int = 0
	var alive_count: int = _get_alive_enemy_count()
	for _i in requested_count:
		if not ignore_alive_cap and alive_count >= max_alive_enemies:
			break

		if _spawn_single_enemy(random_point_in_circle(wave_spawn_point, wave_spawn_point_radius)):
			spawned_count += 1
			alive_count += 1

	return spawned_count

func _on_spawn_timer_timeout() -> void:
	if enemy_scene == null:
		return

	# Keep early waves readable by capping total active enemies.
	if _get_alive_enemy_count() >= max_alive_enemies:
		return

	_spawn_single_enemy(global_position)

func _get_alive_enemy_count() -> int:
	var alive_count: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			alive_count += 1

	return alive_count

func _spawn_single_enemy(spawn_position : Vector2) -> bool:
	if enemy_scene == null:
		return false

	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		return false
	if enemy is EnemyUnit:
		(enemy as EnemyUnit).set_enemy_archetype(_pick_spawn_archetype())

	enemy.global_position = _resolve_spawn_position(spawn_position)

	get_parent().add_child(enemy)

	return true


func _resolve_spawn_position(requested_position: Vector2) -> Vector2:
	if not snap_spawn_to_navigation:
		return requested_position

	var world_2d: World2D = get_world_2d()
	if world_2d == null:
		return requested_position

	var navigation_map: RID = world_2d.navigation_map
	if not navigation_map.is_valid():
		return requested_position

	var snapped_position: Vector2 = NavigationServer2D.map_get_closest_point(navigation_map, requested_position)
	if not snapped_position.is_finite():
		return requested_position

	return snapped_position

func _pick_spawn_archetype() -> StringName:
	if not randomize_enemy_archetypes:
		return EnemyUnit.ENEMY_ARCHETYPE_BASIC_RAIDER
	if spawn_archetype_pool.is_empty():
		return EnemyUnit.ENEMY_ARCHETYPE_BASIC_RAIDER

	var entry: String = spawn_archetype_pool[randi() % spawn_archetype_pool.size()]
	if entry == "":
		return EnemyUnit.ENEMY_ARCHETYPE_BASIC_RAIDER
	return StringName(entry)

func _pick_spawn_position() -> Vector2:
	if wave_spawn_points == null or wave_spawn_points.is_empty(): return global_position

	var random_point: Node = wave_spawn_points[randi() % wave_spawn_points.size()]
	return random_point.global_position
	
func random_point_in_circle(center: Vector2, radius: float) -> Vector2:
	var angle = randf() * TAU
	var distance = sqrt(randf()) * radius
	return center + Vector2(cos(angle), sin(angle)) * distance
