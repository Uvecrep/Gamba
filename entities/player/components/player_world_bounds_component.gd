extends RefCounted
class_name PlayerWorldBoundsComponent

func initialize(player: Player) -> void:
	player.player_bounds_padding = _get_player_bounds_padding(player)
	configure_world_bounds(player)

func configure_world_bounds(player: Player) -> void:
	var tile_map_layer: Node = _find_world_tile_map_layer(player)
	if tile_map_layer == null:
		return
	if not tile_map_layer.has_method("get_used_rect") or not tile_map_layer.has_method("map_to_local"):
		push_warning("Player: world TileMapGround is missing required bounds methods.")
		return

	var used_rect: Rect2i = tile_map_layer.call("get_used_rect")
	if used_rect.size == Vector2i.ZERO:
		push_warning("Player: world TileMapGround has no used cells; bounds not applied.")
		return

	var tile_size: Vector2 = Vector2(32.0, 32.0)
	var tile_set: Variant = tile_map_layer.get("tile_set")
	if tile_set is TileSet:
		tile_size = Vector2((tile_set as TileSet).tile_size)

	var top_left_local: Vector2 = tile_map_layer.call("map_to_local", used_rect.position) - (tile_size * 0.5)
	var bottom_right_local: Vector2 = top_left_local + (Vector2(used_rect.size) * tile_size)

	var top_left_global: Vector2 = tile_map_layer.to_global(top_left_local)
	var bottom_right_global: Vector2 = tile_map_layer.to_global(bottom_right_local)
	var min_point: Vector2 = Vector2(min(top_left_global.x, bottom_right_global.x), min(top_left_global.y, bottom_right_global.y))
	var max_point: Vector2 = Vector2(max(top_left_global.x, bottom_right_global.x), max(top_left_global.y, bottom_right_global.y))

	player.world_bounds = Rect2(min_point, max_point - min_point)
	player.has_world_bounds = true
	apply_camera_world_limits(player)
	clamp_player_to_world_bounds(player)

func apply_camera_world_limits(player: Player) -> void:
	if player.camera == null or not player.has_world_bounds:
		return

	player.camera.limit_left = int(floor(player.world_bounds.position.x))
	player.camera.limit_top = int(floor(player.world_bounds.position.y))
	player.camera.limit_right = int(ceil(player.world_bounds.end.x))
	player.camera.limit_bottom = int(ceil(player.world_bounds.end.y))
	player.camera.limit_smoothed = true
	player.camera.reset_smoothing()

func clamp_player_to_world_bounds(player: Player) -> void:
	if not player.has_world_bounds:
		return

	var min_position: Vector2 = player.world_bounds.position + player.player_bounds_padding
	var max_position: Vector2 = player.world_bounds.end - player.player_bounds_padding

	if min_position.x > max_position.x:
		var center_x: float = (player.world_bounds.position.x + player.world_bounds.end.x) * 0.5
		min_position.x = center_x
		max_position.x = center_x
	if min_position.y > max_position.y:
		var center_y: float = (player.world_bounds.position.y + player.world_bounds.end.y) * 0.5
		min_position.y = center_y
		max_position.y = center_y

	var clamped_position: Vector2 = player.global_position.clamp(min_position, max_position)
	if clamped_position.is_equal_approx(player.global_position):
		return

	if not is_equal_approx(clamped_position.x, player.global_position.x):
		player.velocity.x = 0.0
	if not is_equal_approx(clamped_position.y, player.global_position.y):
		player.velocity.y = 0.0
	player.global_position = clamped_position

func get_node_bounds_padding(node_2d: Node2D) -> Vector2:
	if node_2d == null:
		return Vector2(24.0, 24.0)

	var collision_shape: CollisionShape2D = node_2d.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return Vector2(24.0, 24.0)

	var shape: Shape2D = collision_shape.shape
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size * 0.5
	if shape is CircleShape2D:
		var radius: float = (shape as CircleShape2D).radius
		return Vector2(radius, radius)
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return Vector2(capsule.radius, capsule.height * 0.5)

	return Vector2(24.0, 24.0)

func _get_player_bounds_padding(player: Player) -> Vector2:
	if player.collision_shape_2d == null or player.collision_shape_2d.shape == null:
		return Vector2.ZERO

	var shape: Shape2D = player.collision_shape_2d.shape
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size * 0.5
	if shape is CircleShape2D:
		var radius: float = (shape as CircleShape2D).radius
		return Vector2(radius, radius)
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return Vector2(capsule.radius, capsule.height * 0.5)

	return Vector2.ZERO

func _find_world_tile_map_layer(player: Player) -> Node:
	var current_scene: Node = player.get_tree().current_scene
	if current_scene == null:
		return null

	var world_node: Node = current_scene.get_node_or_null("World")
	if world_node != null:
		var world_tile_map: Node = world_node.get_node_or_null("TileMapGround")
		if world_tile_map != null:
			return world_tile_map

	var fallback: Node = current_scene.find_child("TileMapGround", true, false)
	if fallback != null:
		return fallback

	return null
