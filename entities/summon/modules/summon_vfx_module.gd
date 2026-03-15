extends RefCounted

var unit

func _init(owner) -> void:
	unit = owner

func launch_projectile_attack(target: Node2D, hit_options: Dictionary = {}) -> void:
	if unit.attack_projectile_scene == null:
		unit._deal_damage_to_target(target, unit.attack_damage, hit_options)
		return
	if not can_spawn_projectile_this_frame():
		unit._deal_damage_to_target(target, unit.attack_damage, hit_options)
		return

	var parent_node: Node = unit.get_tree().current_scene
	if parent_node == null:
		parent_node = unit.get_parent()
	if parent_node == null:
		unit._deal_damage_to_target(target, unit.attack_damage, hit_options)
		return

	var projectile: SummonAttackProjectile = SummonAttackProjectile.spawn(
		unit.attack_projectile_scene,
		parent_node,
		unit.global_position,
		target,
		unit.attack_damage,
		unit,
		hit_options
	)
	if projectile == null:
		unit._deal_damage_to_target(target, unit.attack_damage, hit_options)
		return

func spawn_chain_lightning_vfx(from_position: Vector2, to_position: Vector2) -> void:
	var chain_delta: Vector2 = to_position - from_position
	if chain_delta.length_squared() <= 0.0001:
		return

	var midpoint: Vector2 = from_position + (chain_delta * 0.5)
	var scale_x: float = maxf(chain_delta.length() / 64.0, 0.6)
	spawn_world_vfx(unit._vfx_chain_lightning, midpoint, chain_delta.angle(), Vector2(scale_x, 1.0), 0.12)

func load_vfx_assets() -> void:
	unit._vfx_fire_cone = load(unit.VFX_FIRE_CONE_PATH) as Texture2D
	unit._vfx_chain_lightning = load(unit.VFX_CHAIN_LIGHTNING_PATH) as Texture2D
	unit._vfx_acorn_projectile = load(unit.VFX_ACORN_PROJECTILE_PATH) as Texture2D
	unit._vfx_spring_projectile = load(unit.VFX_SPRING_PROJECTILE_PATH) as Texture2D

func spawn_world_vfx(texture: Texture2D, world_position: Vector2, rotation_radians: float = 0.0, sprite_scale: Vector2 = Vector2.ONE, lifetime: float = 0.2, use_corner_anchor: bool = false, corner_anchor_uv: Vector2 = Vector2.ZERO) -> void:
	if texture == null:
		return
	if not can_spawn_world_vfx_this_frame():
		return

	var parent_node: Node = unit.get_tree().current_scene
	if parent_node == null:
		parent_node = unit.get_parent()
	if parent_node == null:
		return

	var resolved_world_position: Vector2 = world_position
	if use_corner_anchor:
		var clamped_anchor_uv: Vector2 = Vector2(clampf(corner_anchor_uv.x, 0.0, 1.0), clampf(corner_anchor_uv.y, 0.0, 1.0))
		var texture_size: Vector2 = texture.get_size() * sprite_scale
		var local_anchor_offset: Vector2 = Vector2(texture_size.x * clamped_anchor_uv.x, texture_size.y * clamped_anchor_uv.y)
		resolved_world_position = world_position - local_anchor_offset.rotated(rotation_radians)

	if is_instance_valid(unit._vfx_pool):
		unit._vfx_pool.spawn_world_fade(parent_node, texture, resolved_world_position, rotation_radians, sprite_scale, 30, lifetime, 0.96, not use_corner_anchor)
		return

	var vfx_sprite := Sprite2D.new()
	vfx_sprite.texture = texture
	vfx_sprite.centered = not use_corner_anchor
	vfx_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if use_corner_anchor:
		vfx_sprite.global_position = resolved_world_position
	else:
		vfx_sprite.global_position = resolved_world_position
	vfx_sprite.rotation = rotation_radians
	vfx_sprite.scale = sprite_scale
	vfx_sprite.z_index = 30
	vfx_sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
	parent_node.add_child(vfx_sprite)

	var fade_tween: Tween = vfx_sprite.create_tween()
	fade_tween.tween_property(vfx_sprite, "modulate:a", 0.0, maxf(lifetime, 0.05))
	fade_tween.tween_callback(Callable(vfx_sprite, "queue_free"))

func can_spawn_world_vfx_this_frame() -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != unit._world_vfx_spawn_frame:
		unit._world_vfx_spawn_frame = frame
		unit._world_vfx_spawn_count = 0

	if unit._world_vfx_spawn_count >= unit.MAX_WORLD_VFX_SPAWNS_PER_FRAME:
		return false

	unit._world_vfx_spawn_count += 1
	return true

func can_spawn_projectile_this_frame() -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != unit._projectile_spawn_frame:
		unit._projectile_spawn_frame = frame
		unit._projectile_spawn_count = 0

	if unit._projectile_spawn_count >= unit.MAX_PROJECTILE_SPAWNS_PER_FRAME:
		return false

	unit._projectile_spawn_count += 1
	return true
