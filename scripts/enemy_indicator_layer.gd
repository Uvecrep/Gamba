extends Control
class_name EnemyIndicatorLayer

## Draws directional arrow indicators at the screen edges for off-screen enemies,
## giving the player situational awareness of threats outside the current view.

## Distance from the screen edge at which indicators are drawn.
@export var edge_margin: float = 40.0
## Half-size (tip to base) of each arrow in pixels.
@export var arrow_size: float = 18.0
## Fill colour of each arrow.
@export var indicator_color: Color = Color(1.0, 0.25, 0.2, 0.9)
## Outline colour drawn around each arrow for legibility.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.65)
## Width of the outline stroke in pixels.
@export var outline_width: float = 2.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	# Maps world (canvas) coordinates to viewport pixel coordinates.
	var canvas_xform := get_viewport().get_canvas_transform()

	var screen_rect := Rect2(Vector2.ZERO, viewport_size)
	var margin_rect := Rect2(
		Vector2(edge_margin, edge_margin),
		viewport_size - Vector2(edge_margin, edge_margin) * 2.0
	)

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue

		var screen_pos: Vector2 = canvas_xform * enemy_node.global_position
		if screen_rect.has_point(screen_pos):
			continue  # Enemy is already visible — no indicator needed.

		var dir := screen_pos - center
		if dir.length_squared() < 1.0:
			continue
		dir = dir.normalized()

		var indicator_pos := _clamp_to_rect_border(center, dir, margin_rect)
		_draw_arrow_at(indicator_pos, dir)


## Returns the point where a ray from `origin` along `dir` first hits the border of `rect`.
func _clamp_to_rect_border(origin: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var t_min := INF

	if abs(dir.x) > 0.0001:
		for edge_x: float in [rect.position.x, rect.end.x]:
			var t := (edge_x - origin.x) / dir.x
			if t > 0.0:
				var y := origin.y + t * dir.y
				if y >= rect.position.y and y <= rect.end.y:
					t_min = min(t_min, t)

	if abs(dir.y) > 0.0001:
		for edge_y: float in [rect.position.y, rect.end.y]:
			var t := (edge_y - origin.y) / dir.y
			if t > 0.0:
				var x := origin.x + t * dir.x
				if x >= rect.position.x and x <= rect.end.x:
					t_min = min(t_min, t)

	if t_min == INF:
		return rect.get_center()
	return origin + dir * t_min


## Draws a filled triangle arrow centred on `pos` pointing along `dir`.
func _draw_arrow_at(pos: Vector2, dir: Vector2) -> void:
	var half := arrow_size * 0.5
	var tip := pos + dir * half
	var back := pos - dir * half
	var perp := dir.rotated(PI * 0.5)
	var left := back + perp * half
	var right := back - perp * half

	var points := PackedVector2Array([tip, left, right])
	var loop := PackedVector2Array([tip, left, right, tip])

	draw_colored_polygon(points, indicator_color)
	draw_polyline(loop, outline_color, outline_width, true)
