extends RefCounted
class_name PlayerWorldBoundsComponent

const WORLD_BOUNDS_UTIL_PATH: String = "res://scripts/world_bounds_util.gd"

func initialize(player: Player) -> void:
	player.player_bounds_padding = _get_player_bounds_padding(player)
	configure_world_bounds(player)

func configure_world_bounds(player: Player) -> void:
	var tile_map_layer_node: Node = _find_world_tile_map_layer(player)
	if not tile_map_layer_node is TileMapLayer:
		return

	var tile_map_layer: TileMapLayer = tile_map_layer_node as TileMapLayer
	var world_bounds_util: Variant = load(WORLD_BOUNDS_UTIL_PATH)
	if world_bounds_util == null:
		push_warning("Player: world bounds utility could not be loaded.")
		return

	var world_bounds: Rect2 = world_bounds_util.get_used_rect_world_rect(tile_map_layer)
	if world_bounds.size.x <= 0.0 or world_bounds.size.y <= 0.0:
		push_warning("Player: world TileMapGround has no used cells; bounds not applied.")
		return

	player.world_bounds = world_bounds
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
