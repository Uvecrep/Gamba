extends Node2D

@export var move_speed: float = 420.0
@export var hit_distance: float = 14.0
@export var max_life_time: float = 2.0

var _target: Node2D
var _damage: float = 0.0
var _life_time_left: float = 0.0

func _ready() -> void:
	_life_time_left = max_life_time

func setup(target: Node2D, damage: float) -> void:
	_target = target
	_damage = damage

func _process(delta: float) -> void:
	_life_time_left -= delta
	if _life_time_left <= 0.0:
		queue_free()
		return

	if not is_instance_valid(_target):
		queue_free()
		return

	var to_target := _target.global_position - global_position
	var distance := to_target.length()
	if distance <= hit_distance:
		if _target.has_method("take_damage"):
			_target.call("take_damage", _damage)
		queue_free()
		return

	if distance > 0.0:
		global_position += to_target.normalized() * move_speed * delta
		rotation = to_target.angle()
