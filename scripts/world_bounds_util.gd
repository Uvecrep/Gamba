extends RefCounted


static func get_used_rect_world_rect(tile_map_layer: TileMapLayer) -> Rect2:
	if tile_map_layer == null:
		return Rect2()

	var used_rect: Rect2i = tile_map_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return Rect2()

	var tile_size: Vector2 = Vector2(32.0, 32.0)
	if tile_map_layer.tile_set != null:
		tile_size = Vector2(tile_map_layer.tile_set.tile_size)

	var top_left_local: Vector2 = tile_map_layer.map_to_local(used_rect.position) - (tile_size * 0.5)
	var bottom_right_local: Vector2 = top_left_local + (Vector2(used_rect.size) * tile_size)
	var top_left_global: Vector2 = tile_map_layer.to_global(top_left_local)
	var bottom_right_global: Vector2 = tile_map_layer.to_global(bottom_right_local)
	var min_point: Vector2 = Vector2(min(top_left_global.x, bottom_right_global.x), min(top_left_global.y, bottom_right_global.y))
	var max_point: Vector2 = Vector2(max(top_left_global.x, bottom_right_global.x), max(top_left_global.y, bottom_right_global.y))

	return Rect2(min_point, max_point - min_point)