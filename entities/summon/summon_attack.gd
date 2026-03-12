extends Node2D

@export var move_speed: float = 420.0
@export var hit_distance: float = 14.0
@export var max_life_time: float = 2.0

var _target: Node2D
var _damage: float = 0.0
var _life_time_left: float = 0.0
var _source: Node2D
var _hit_options: Dictionary = {}
var _rotation_offset_radians: float = 0.0

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	_life_time_left = max_life_time
	_apply_projectile_visual()

func setup(target: Node2D, damage: float, source: Node2D = null, hit_options: Dictionary = {}) -> void:
	_target = target
	_damage = damage
	_source = source
	_hit_options = hit_options
	_rotation_offset_radians = float(_hit_options.get("projectile_rotation_offset", 0.0))
	_apply_projectile_visual()

func _apply_projectile_visual() -> void:
	if _sprite == null:
		return
	if not _hit_options.has("projectile_texture"):
		return

	var texture_override: Variant = _hit_options.get("projectile_texture")
	if texture_override is Texture2D:
		_sprite.texture = texture_override as Texture2D

func _process(delta: float) -> void:
	_life_time_left -= delta
	if _life_time_left <= 0.0:
		queue_free()
		return

	if not is_instance_valid(_target):
		queue_free()
		return

	var to_target: Vector2 = _target.global_position - global_position
	var distance: float = to_target.length()
	if distance <= hit_distance:
		if _target.has_method("take_hit"):
			_target.call("take_hit", _damage, _source, _hit_options)
		elif _target.has_method("take_damage"):
			_target.call("take_damage", _damage)
		queue_free()
		return

	if distance > 0.0:
		global_position += to_target.normalized() * move_speed * delta
		rotation = to_target.angle() + _rotation_offset_radians
