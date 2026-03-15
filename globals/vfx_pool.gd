extends Node
class_name VfxPool2D

@export var max_pool_size: int = 320

var _pool: Array[Sprite2D] = []

func spawn_world_fade(
	parent_node: Node,
	texture: Texture2D,
	world_position: Vector2,
	rotation_radians: float = 0.0,
	sprite_scale: Vector2 = Vector2.ONE,
	z_index: int = 0,
	lifetime: float = 0.2,
	alpha: float = 0.95,
	centered: bool = true
) -> void:
	if parent_node == null or texture == null:
		return

	var sprite: Sprite2D = _acquire_sprite()
	if sprite.get_parent() != null:
		sprite.get_parent().remove_child(sprite)

	sprite.texture = texture
	sprite.centered = centered
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = world_position
	sprite.rotation = rotation_radians
	sprite.scale = sprite_scale
	sprite.z_index = z_index
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	sprite.visible = true
	parent_node.add_child(sprite)

	var fade_tween: Tween = sprite.create_tween()
	sprite.set_meta("vfx_tween", fade_tween)
	fade_tween.tween_property(sprite, "modulate:a", 0.0, maxf(lifetime, 0.05))
	fade_tween.tween_callback(Callable(self, "_recycle_sprite").bind(sprite))

func spawn_local_fade(
	parent_node: Node2D,
	texture: Texture2D,
	local_position: Vector2,
	rotation_radians: float = 0.0,
	sprite_scale: Vector2 = Vector2.ONE,
	z_index: int = 0,
	lifetime: float = 0.2,
	alpha: float = 0.95,
	centered: bool = true
) -> void:
	if parent_node == null or texture == null:
		return

	var sprite: Sprite2D = _acquire_sprite()
	if sprite.get_parent() != null:
		sprite.get_parent().remove_child(sprite)

	sprite.texture = texture
	sprite.centered = centered
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = local_position
	sprite.rotation = rotation_radians
	sprite.scale = sprite_scale
	sprite.z_index = z_index
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	sprite.visible = true
	parent_node.add_child(sprite)

	var fade_tween: Tween = sprite.create_tween()
	sprite.set_meta("vfx_tween", fade_tween)
	fade_tween.tween_property(sprite, "modulate:a", 0.0, maxf(lifetime, 0.05))
	fade_tween.tween_callback(Callable(self, "_recycle_sprite").bind(sprite))

func _acquire_sprite() -> Sprite2D:
	while not _pool.is_empty():
		var pooled: Sprite2D = _pool.pop_back()
		if not is_instance_valid(pooled):
			continue

		var previous_tween_variant: Variant = pooled.get_meta("vfx_tween", null)
		if previous_tween_variant is Tween and is_instance_valid(previous_tween_variant):
			(previous_tween_variant as Tween).kill()
		pooled.set_meta("vfx_tween", null)
		return pooled

	return Sprite2D.new()

func _recycle_sprite(sprite: Sprite2D) -> void:
	if not is_instance_valid(sprite):
		return

	var existing_tween_variant: Variant = sprite.get_meta("vfx_tween", null)
	if existing_tween_variant is Tween and is_instance_valid(existing_tween_variant):
		(existing_tween_variant as Tween).kill()
	sprite.set_meta("vfx_tween", null)

	sprite.visible = false
	sprite.texture = null
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	sprite.position = Vector2.ZERO
	sprite.global_position = Vector2.ZERO

	if sprite.get_parent() != null:
		sprite.get_parent().remove_child(sprite)

	if _pool.size() >= max_pool_size:
		sprite.queue_free()
		return

	_pool.append(sprite)
