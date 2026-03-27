extends Sprite2D
class_name GroundShadow

@export var target_sprite_path: NodePath
@export var y_offset: float = 0.0
@export var animate_with_bounce: bool = true
@export var bounce_from_parent_motion: bool = false
@export var bounce_position_factor: float = 0.18

var _target_sprite: Sprite2D
var _base_target_position: Vector2 = Vector2.ZERO
var _base_entity_position: Vector2 = Vector2.ZERO
var _base_position_initialized: bool = false
var _base_shadow_scale: Vector2 = Vector2.ONE
var _base_alpha: float = 1.0

func _ready() -> void:
	_target_sprite = get_node_or_null(target_sprite_path) as Sprite2D
	if _target_sprite != null:
		_base_target_position = _target_sprite.position
	if get_parent() != null:
		_base_entity_position = get_parent().global_position
	_base_shadow_scale = scale
	_base_alpha = modulate.a
	# Only mark as initialized if entity is not at origin (spawning at 0,0 is skipped for lazy init)
	_base_position_initialized = _base_entity_position != Vector2.ZERO
	_update_shadow_position()

func _process(_delta: float) -> void:
	_update_shadow_position()

func _update_shadow_position() -> void:
	var target: Sprite2D = _target_sprite
	if target == null:
		target = get_node_or_null(target_sprite_path) as Sprite2D
		_target_sprite = target
	if target == null:
		return

	var texture_size: Vector2 = target.texture.get_size() if target.texture != null else Vector2(24.0, 24.0)
	if target.hframes > 1:
		texture_size.x /= float(target.hframes)
	if target.vframes > 1:
		texture_size.y /= float(target.vframes)

	var base_bottom_y: float = _base_target_position.y + (texture_size.y * absf(target.scale.y) * 0.5)
	var entity_current_pos: Vector2 = get_parent().global_position if get_parent() != null else Vector2.ZERO
	
	# Lazy initialization: if base position was (0,0) at startup, capture it now when entity is placed
	if not _base_position_initialized and entity_current_pos != Vector2.ZERO:
		_base_entity_position = entity_current_pos
		_base_target_position = target.position
		_base_position_initialized = true
	
	if animate_with_bounce:
		# Detect sprite animation movement (relative to parent) - this is the bounce we want to inverse
		var sprite_delta_y: float = target.position.y - _base_target_position.y
		var parent_delta_y: float = 0.0
		if bounce_from_parent_motion:
			parent_delta_y = entity_current_pos.y - _base_entity_position.y
		var bounce_delta_y: float = sprite_delta_y + parent_delta_y
		
		# Use current entity position so shadow follows the entity around, then apply inverse bounce to Y
		var shadow_world_x: float = entity_current_pos.x + target.position.x
		var shadow_world_y: float = entity_current_pos.y + base_bottom_y + y_offset - (bounce_delta_y * bounce_position_factor) + 2.0
		
		global_position = Vector2(shadow_world_x, shadow_world_y)

		var shadow_squash: float = clampf(1.0 + (absf(bounce_delta_y) * 0.06), 1.0, 1.35)
		scale = Vector2(_base_shadow_scale.x * shadow_squash, _base_shadow_scale.y * shadow_squash)
	else:
		# Static shadow that just follows the entity normally
		var shadow_world_x: float = entity_current_pos.x + target.position.x
		var shadow_world_y: float = entity_current_pos.y + base_bottom_y + y_offset
		
		global_position = Vector2(shadow_world_x, shadow_world_y)
		scale = _base_shadow_scale
	
	modulate.a = _base_alpha
