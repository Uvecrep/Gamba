extends Node2D
class_name SummonAttackProjectile

@export var move_speed: float = 420.0
@export var hit_distance: float = 14.0
@export var max_life_time: float = 2.0

const POOL_MAX_SIZE: int = 256
const MAX_SPAWNS_PER_FRAME: int = 64

static var _pool: Array[SummonAttackProjectile] = []
static var _spawn_frame: int = -1
static var _spawn_count: int = 0

var _target: Node2D
var _damage: float = 0.0
var _life_time_left: float = 0.0
var _source: Node2D
var _hit_options: Dictionary = {}
var _rotation_offset_radians: float = 0.0
var _is_active: bool = false
var _default_texture: Texture2D

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

static func spawn(projectile_scene: PackedScene, parent_node: Node, origin: Vector2, target: Node2D, damage: float, source: Node2D = null, hit_options: Dictionary = {}) -> SummonAttackProjectile:
	if projectile_scene == null or parent_node == null:
		return null

	var frame: int = Engine.get_process_frames()
	if frame != _spawn_frame:
		_spawn_frame = frame
		_spawn_count = 0

	if _spawn_count >= MAX_SPAWNS_PER_FRAME:
		return null

	_spawn_count += 1

	var projectile: SummonAttackProjectile = _acquire(projectile_scene)
	if projectile == null:
		return null

	if projectile.get_parent() != null:
		projectile.get_parent().remove_child(projectile)

	parent_node.add_child(projectile)
	projectile.global_position = origin
	projectile.setup(target, damage, source, hit_options)
	projectile._activate()
	return projectile

static func _acquire(projectile_scene: PackedScene) -> SummonAttackProjectile:
	while not _pool.is_empty():
		var pooled: SummonAttackProjectile = _pool.pop_back()
		if is_instance_valid(pooled):
			return pooled

	var fresh: Node = projectile_scene.instantiate()
	if fresh is SummonAttackProjectile:
		return fresh as SummonAttackProjectile

	if is_instance_valid(fresh):
		fresh.queue_free()
	return null

func _ready() -> void:
	if _sprite != null:
		_default_texture = _sprite.texture
	set_process(false)

func setup(target: Node2D, damage: float, source: Node2D = null, hit_options: Dictionary = {}) -> void:
	_target = target
	_damage = damage
	_source = source
	_hit_options = hit_options.duplicate()
	_rotation_offset_radians = float(_hit_options.get("projectile_rotation_offset", 0.0))
	_life_time_left = max_life_time
	_apply_projectile_visual()

func _activate() -> void:
	_is_active = true
	visible = true
	set_process(true)

func _deactivate() -> void:
	if not _is_active:
		return

	_is_active = false
	set_process(false)
	visible = false
	_target = null
	_source = null
	_hit_options.clear()
	_rotation_offset_radians = 0.0

	if get_parent() != null:
		get_parent().remove_child(self)

	if _pool.size() >= POOL_MAX_SIZE:
		queue_free()
		return

	_pool.append(self)

func _apply_projectile_visual() -> void:
	if _sprite == null:
		return
	_sprite.texture = _default_texture
	if not _hit_options.has("projectile_texture"):
		return

	var texture_override: Variant = _hit_options.get("projectile_texture")
	if texture_override is Texture2D:
		_sprite.texture = texture_override as Texture2D

func _process(delta: float) -> void:
	if not _is_active:
		return

	_life_time_left -= delta
	if _life_time_left <= 0.0:
		_deactivate()
		return

	if not is_instance_valid(_target):
		_deactivate()
		return

	var target_node: Node2D = _target
	if not is_instance_valid(target_node):
		_deactivate()
		return

	var to_target: Vector2 = target_node.global_position - global_position
	var distance: float = to_target.length()
	if distance <= hit_distance:
		var source_node: Node2D = _resolve_valid_source()
		if target_node is EnemyUnit:
			(target_node as EnemyUnit).take_hit(_damage, source_node, _hit_options)
		elif target_node is Player:
			(target_node as Player).take_hit(_damage, source_node, _hit_options)
		elif target_node is SummonUnit:
			(target_node as SummonUnit).take_hit(_damage, source_node, _hit_options)
		elif target_node is House:
			(target_node as House).take_damage(_damage)
		_deactivate()
		return

	if distance > 0.0:
		global_position += to_target.normalized() * move_speed * delta
		rotation = to_target.angle() + _rotation_offset_radians

func _resolve_valid_source() -> Node2D:
	if not is_instance_valid(_source):
		return null

	return _source
