extends Sprite2D
class_name ThrownGroundShadow

@export var y_offset: float = 14.0
@export var min_scale_multiplier: float = 1.0
@export var max_scale_multiplier: float = 1.35
@export var scale_per_height: float = 0.003

var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_base_scale = scale

func _process(_delta: float) -> void:
	var thrown: ThrownObject = get_parent() as ThrownObject
	if thrown == null:
		return

	if thrown.duration <= 0.0:
		global_position = thrown.global_position + Vector2(0.0, y_offset)
		scale = _base_scale
		return

	var t: float = clampf(thrown.time / thrown.duration, 0.0, 1.0)
	var ground_pos: Vector2 = thrown.start_pos.lerp(thrown.target_pos, t)
	global_position = ground_pos + Vector2(0.0, y_offset)

	var height: float = 4.0 * thrown.max_height * t * (1.0 - t)
	var scale_multiplier: float = clampf(min_scale_multiplier + (height * scale_per_height), min_scale_multiplier, max_scale_multiplier)
	scale = _base_scale * scale_multiplier
