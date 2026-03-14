extends Control

signal selection_changed(selected_count: int)
signal move_order_issued(target_world_position: Vector2, summon_count: int)

@export var map_padding: float = 12.0
@export var summon_pick_radius: float = 12.0
@export var background_color: Color = Color(0.05, 0.06, 0.08, 0.96)
@export var map_fill_color: Color = Color(0.18, 0.22, 0.19, 0.95)
@export var map_border_color: Color = Color(0.62, 0.68, 0.66, 1.0)
@export var grid_line_color: Color = Color(1.0, 1.0, 1.0, 0.08)
@export var player_marker_color: Color = Color(0.2, 0.75, 1.0, 1.0)
@export var house_marker_color: Color = Color(0.45, 1.0, 0.45, 1.0)
@export var tower_marker_color: Color = Color(1.0, 0.82, 0.32, 1.0)
@export var enemy_marker_color: Color = Color(1.0, 0.34, 0.34, 0.95)
@export var summon_marker_color: Color = Color(1.0, 1.0, 1.0, 0.92)
@export var selected_summon_marker_color: Color = Color(1.0, 0.95, 0.45, 1.0)
@export var holding_summon_marker_color: Color = Color(0.46, 1.0, 0.48, 0.95)
@export var moving_summon_marker_color: Color = Color(1.0, 0.72, 0.3, 0.95)
@export var selection_box_fill_color: Color = Color(1.0, 0.95, 0.45, 0.14)
@export var selection_box_border_color: Color = Color(1.0, 0.95, 0.45, 0.9)
@export var drag_selection_threshold: float = 6.0
@export var redraw_interval: float = 0.1
@export var world_bounds_refresh_interval: float = 0.5

var _world_bounds: Rect2 = Rect2()
var _has_world_bounds: bool = false
var _selected_summons: Array[Node2D] = []
var _is_left_mouse_down: bool = false
var _is_drag_selecting: bool = false
var _drag_started_inside_map: bool = false
var _drag_additive_selection: bool = false
var _drag_start_position: Vector2 = Vector2.ZERO
var _drag_current_position: Vector2 = Vector2.ZERO
var _time_to_redraw: float = 0.0
var _time_to_world_bounds_refresh: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("summon_selection_controllers")
	_refresh_world_bounds()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_time_to_redraw = maxf(_time_to_redraw - delta, 0.0)
	_time_to_world_bounds_refresh = maxf(_time_to_world_bounds_refresh - delta, 0.0)

	if _time_to_world_bounds_refresh <= 0.0:
		_refresh_world_bounds()
		_time_to_world_bounds_refresh = maxf(world_bounds_refresh_interval, 0.05)

	if _time_to_redraw > 0.0:
		return

	_time_to_redraw = maxf(redraw_interval, 0.03)
	_prune_selected_summons()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _has_world_bounds:
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	var map_rect: Rect2 = _get_map_rect()

	if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		if not mouse_button.pressed:
			return
		if not map_rect.has_point(mouse_button.position):
			return

		_handle_right_click_move(mouse_button.position)
		return

	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_button.pressed:
		if not map_rect.has_point(mouse_button.position):
			_clear_drag_selection_state()
			return

		_is_left_mouse_down = true
		_is_drag_selecting = false
		_drag_started_inside_map = true
		_drag_additive_selection = mouse_button.shift_pressed or mouse_button.ctrl_pressed
		_drag_start_position = mouse_button.position
		_drag_current_position = mouse_button.position
		return

	if not _is_left_mouse_down:
		return
	_is_left_mouse_down = false

	if not _drag_started_inside_map:
		_clear_drag_selection_state()
		return

	if _is_drag_selecting:
		var selection_rect: Rect2 = _get_drag_selection_rect()
		if selection_rect.size.x > 0.0 and selection_rect.size.y > 0.0:
			_select_summons_in_rect(selection_rect, _drag_additive_selection)
		_clear_drag_selection_state()
		return

	_clear_drag_selection_state()

	if not map_rect.has_point(mouse_button.position):
		return

	_handle_left_click_selection(mouse_button.position, mouse_button.shift_pressed or mouse_button.ctrl_pressed)

func _handle_mouse_motion(mouse_motion: InputEventMouseMotion) -> void:
	if not _is_left_mouse_down or not _drag_started_inside_map:
		return

	_drag_current_position = _clamp_to_map_rect(mouse_motion.position)
	if not _is_drag_selecting:
		var drag_distance: float = _drag_start_position.distance_to(_drag_current_position)
		if drag_distance >= drag_selection_threshold:
			_is_drag_selecting = true

	if _is_drag_selecting:
		queue_redraw()

func _handle_left_click_selection(click_position: Vector2, additive_selection: bool) -> void:
	var clicked_summon: Node2D = _find_summon_at_minimap_position(click_position)
	if clicked_summon != null:
		_select_summon(clicked_summon, additive_selection)
		return

	if additive_selection:
		return

	clear_selection()

func _handle_right_click_move(click_position: Vector2) -> void:
	if _selected_summons.is_empty():
		return

	var target_world_position: Vector2 = _minimap_to_world(click_position)
	var moved_count: int = _issue_move_order(target_world_position)
	if moved_count > 0:
		move_order_issued.emit(target_world_position, moved_count)

func _clear_drag_selection_state() -> void:
	var was_drag_selecting: bool = _is_drag_selecting
	_is_left_mouse_down = false
	_is_drag_selecting = false
	_drag_started_inside_map = false
	_drag_additive_selection = false
	if was_drag_selecting:
		queue_redraw()

func _get_drag_selection_rect() -> Rect2:
	var min_x: float = minf(_drag_start_position.x, _drag_current_position.x)
	var min_y: float = minf(_drag_start_position.y, _drag_current_position.y)
	var max_x: float = maxf(_drag_start_position.x, _drag_current_position.x)
	var max_y: float = maxf(_drag_start_position.y, _drag_current_position.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _clamp_to_map_rect(local_point: Vector2) -> Vector2:
	var map_rect: Rect2 = _get_map_rect()
	return Vector2(
		clampf(local_point.x, map_rect.position.x, map_rect.end.x),
		clampf(local_point.y, map_rect.position.y, map_rect.end.y)
	)

func _select_summons_in_rect(selection_rect: Rect2, additive_selection: bool) -> void:
	_prune_selected_summons()
	var previous_selection: Array[Node2D] = _selected_summons.duplicate()

	if not additive_selection:
		_selected_summons.clear()

	for summon in _get_group_nodes_2d(&"summons"):
		var marker_position: Vector2 = _world_to_minimap(summon.global_position)
		if not selection_rect.has_point(marker_position):
			continue
		if _selected_summons.has(summon):
			continue

		_selected_summons.append(summon)
	_finalize_selection_change(previous_selection)

func clear_selection() -> void:
	if _selected_summons.is_empty():
		return

	var previous_selection: Array[Node2D] = _selected_summons.duplicate()
	_selected_summons.clear()
	_finalize_selection_change(previous_selection)

func select_summons_in_world_circle(world_center: Vector2, radius: float, additive_selection: bool = true) -> int:
	var radius_sq: float = maxf(radius, 0.0)
	radius_sq *= radius_sq
	var matched_summons: Array[Node2D] = []

	for summon in _get_group_nodes_2d(&"summons"):
		if summon.global_position.distance_squared_to(world_center) > radius_sq:
			continue
		matched_summons.append(summon)

	set_selected_summons(matched_summons, additive_selection)
	return matched_summons.size()

func set_selected_summons(summons: Array[Node2D], additive_selection: bool = true) -> void:
	_prune_selected_summons()
	var previous_selection: Array[Node2D] = _selected_summons.duplicate()

	if not additive_selection:
		_selected_summons.clear()

	for summon in summons:
		if not is_instance_valid(summon):
			continue
		if _selected_summons.has(summon):
			continue
		_selected_summons.append(summon)

	_finalize_selection_change(previous_selection)

func hold_selected_summons() -> int:
	_prune_selected_summons()
	if _selected_summons.is_empty():
		return 0

	var all_selected_holding: bool = true
	for summon in _selected_summons:
		if not is_instance_valid(summon):
			continue
		if not _is_summon_hold_toggle_enabled(summon):
			all_selected_holding = false
			break

	var target_hold_state: bool = not all_selected_holding
	var commanded_count: int = 0
	for summon in _selected_summons:
		if not is_instance_valid(summon):
			continue
		if not summon.has_method("set_hold_position"):
			continue

		summon.call("set_hold_position", target_hold_state)
		commanded_count += 1

	return commanded_count

func follow_selected_summons() -> int:
	_prune_selected_summons()
	if _selected_summons.is_empty():
		return 0

	var commanded_count: int = 0
	for summon in _selected_summons:
		if not is_instance_valid(summon):
			continue
		if not summon.has_method("set_follow_player"):
			continue

		summon.call("set_follow_player")
		commanded_count += 1

	return commanded_count

func auto_selected_summons() -> int:
	_prune_selected_summons()
	if _selected_summons.is_empty():
		return 0

	var commanded_count: int = 0
	for summon in _selected_summons:
		if not is_instance_valid(summon):
			continue

		if summon.has_method("set_auto_behavior"):
			summon.call("set_auto_behavior")
			commanded_count += 1
			continue

		if summon.has_method("clear_manual_command"):
			summon.call("clear_manual_command")
			commanded_count += 1

	return commanded_count

func get_selected_summon_count() -> int:
	_prune_selected_summons()
	return _selected_summons.size()

func get_selected_holding_count() -> int:
	_prune_selected_summons()
	var holding_count: int = 0
	for summon in _selected_summons:
		if _is_summon_holding(summon):
			holding_count += 1

	return holding_count

func get_selected_hold_toggled_count() -> int:
	_prune_selected_summons()
	var hold_toggled_count: int = 0
	for summon in _selected_summons:
		if _is_summon_hold_toggle_enabled(summon):
			hold_toggled_count += 1

	return hold_toggled_count

func _draw() -> void:
	var map_rect: Rect2 = _get_map_rect()
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true)
	draw_rect(map_rect, map_fill_color, true)
	draw_rect(map_rect, map_border_color, false, 2.0)
	_draw_grid(map_rect)

	_draw_group_markers(&"enemies", enemy_marker_color, 2.5)
	_draw_group_markers(&"enemy_towers", tower_marker_color, 4.0)
	_draw_group_markers(&"house", house_marker_color, 4.5)
	_draw_group_markers(&"players", player_marker_color, 4.0)
	_draw_summon_markers()

	if _is_drag_selecting:
		var selection_rect: Rect2 = _get_drag_selection_rect()
		draw_rect(selection_rect, selection_box_fill_color, true)
		draw_rect(selection_rect, selection_box_border_color, false, 2.0)

func _draw_grid(map_rect: Rect2) -> void:
	for index in range(1, 4):
		var x: float = map_rect.position.x + (map_rect.size.x * float(index) / 4.0)
		var y: float = map_rect.position.y + (map_rect.size.y * float(index) / 4.0)
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), grid_line_color, 1.0)
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), grid_line_color, 1.0)

func _draw_group_markers(group_name: StringName, color: Color, radius: float) -> void:
	for node in _get_group_nodes_2d(group_name):
		var marker_position: Vector2 = _world_to_minimap(node.global_position)
		draw_circle(marker_position, radius, color)

func _draw_summon_markers() -> void:
	for summon in _get_group_nodes_2d(&"summons"):
		var marker_position: Vector2 = _world_to_minimap(summon.global_position)
		var marker_color: Color = summon_marker_color
		if _is_summon_holding(summon):
			marker_color = holding_summon_marker_color
		elif _is_summon_moving(summon):
			marker_color = moving_summon_marker_color

		var is_selected: bool = _selected_summons.has(summon)
		if is_selected:
			draw_circle(marker_position, 6.5, selected_summon_marker_color)
			draw_circle(marker_position, 3.0, marker_color)
		else:
			draw_circle(marker_position, 3.5, marker_color)

func _select_summon(summon: Node2D, additive_selection: bool) -> void:
	if not is_instance_valid(summon):
		return

	_prune_selected_summons()
	var previous_selection: Array[Node2D] = _selected_summons.duplicate()
	var changed: bool = false

	if additive_selection:
		var index: int = _selected_summons.find(summon)
		if index >= 0:
			_selected_summons.remove_at(index)
		else:
			_selected_summons.append(summon)
		changed = true
	else:
		if _selected_summons.size() != 1 or _selected_summons[0] != summon:
			_selected_summons.clear()
			_selected_summons.append(summon)
			changed = true

	if not changed:
		return

	_finalize_selection_change(previous_selection)

func _issue_move_order(target_world_position: Vector2) -> int:
	_prune_selected_summons()
	var moved_count: int = 0
	for summon in _selected_summons:
		if not is_instance_valid(summon):
			continue
		if not summon.has_method("set_move_target"):
			continue

		summon.call("set_move_target", target_world_position)
		moved_count += 1

	return moved_count

func _find_summon_at_minimap_position(minimap_position: Vector2) -> Node2D:
	var closest_summon: Node2D = null
	var closest_distance_sq: float = summon_pick_radius * summon_pick_radius

	for summon in _get_group_nodes_2d(&"summons"):
		var marker_position: Vector2 = _world_to_minimap(summon.global_position)
		var distance_sq: float = marker_position.distance_squared_to(minimap_position)
		if distance_sq > closest_distance_sq:
			continue

		closest_distance_sq = distance_sq
		closest_summon = summon

	return closest_summon

func _prune_selected_summons() -> void:
	var previous_selection: Array[Node2D] = _selected_summons.duplicate()
	var previous_count: int = _selected_summons.size()
	var alive_summons: Array[Node2D] = []
	for summon in _selected_summons:
		if is_instance_valid(summon):
			alive_summons.append(summon)

	if alive_summons.size() == previous_count:
		return

	_selected_summons = alive_summons
	_finalize_selection_change(previous_selection)

func _finalize_selection_change(previous_selection: Array[Node2D]) -> void:
	_sync_summon_selection_visuals(previous_selection)
	if _selected_summons.size() == previous_selection.size() and _same_node_selection(previous_selection, _selected_summons):
		return

	selection_changed.emit(_selected_summons.size())
	queue_redraw()

func _sync_summon_selection_visuals(previous_selection: Array[Node2D]) -> void:
	for previous_summon in previous_selection:
		if not is_instance_valid(previous_summon):
			continue
		if _selected_summons.has(previous_summon):
			continue
		_set_summon_selected_visual(previous_summon, false)

	for selected_summon in _selected_summons:
		if not is_instance_valid(selected_summon):
			continue
		_set_summon_selected_visual(selected_summon, true)

func _set_summon_selected_visual(summon: Node2D, is_selected: bool) -> void:
	if summon == null:
		return
	if not summon.has_method("set_selected_for_command"):
		return
	summon.call("set_selected_for_command", is_selected)

func _same_node_selection(previous_selection: Array[Node2D], current_selection: Array[Node2D]) -> bool:
	if previous_selection.size() != current_selection.size():
		return false

	for selected_node in previous_selection:
		if not current_selection.has(selected_node):
			return false

	return true

func _is_summon_holding(summon: Node2D) -> bool:
	if summon == null:
		return false
	if summon.has_method("is_holding_position"):
		return bool(summon.call("is_holding_position"))
	if summon.has_method("get_command_mode_name"):
		return String(summon.call("get_command_mode_name")) == "HOLD"
	return false

func _is_summon_hold_toggle_enabled(summon: Node2D) -> bool:
	if summon == null:
		return false
	if summon.has_method("is_hold_toggle_enabled"):
		return bool(summon.call("is_hold_toggle_enabled"))
	# Backwards compatibility for older summon scripts where hold toggle equals current hold mode.
	return _is_summon_holding(summon)

func _is_summon_moving(summon: Node2D) -> bool:
	if summon == null or not summon.has_method("get_command_mode_name"):
		return false
	return String(summon.call("get_command_mode_name")) == "MOVE"

func _get_map_rect() -> Rect2:
	var constrained_padding: float = clampf(map_padding, 0.0, minf(size.x, size.y) * 0.45)
	var map_size: Vector2 = size - Vector2(constrained_padding * 2.0, constrained_padding * 2.0)
	if map_size.x < 1.0:
		map_size.x = 1.0
	if map_size.y < 1.0:
		map_size.y = 1.0

	return Rect2(Vector2(constrained_padding, constrained_padding), map_size)

func _world_to_minimap(world_position: Vector2) -> Vector2:
	var map_rect: Rect2 = _get_map_rect()
	if not _has_world_bounds:
		return map_rect.get_center()

	var bounds_size: Vector2 = _world_bounds.size
	if is_zero_approx(bounds_size.x) or is_zero_approx(bounds_size.y):
		return map_rect.get_center()

	var relative: Vector2 = (world_position - _world_bounds.position) / bounds_size
	relative = Vector2(clampf(relative.x, 0.0, 1.0), clampf(relative.y, 0.0, 1.0))
	return map_rect.position + (relative * map_rect.size)

func _minimap_to_world(minimap_position: Vector2) -> Vector2:
	var map_rect: Rect2 = _get_map_rect()
	if not _has_world_bounds:
		return Vector2.ZERO

	var bounds_size: Vector2 = _world_bounds.size
	if is_zero_approx(bounds_size.x) or is_zero_approx(bounds_size.y):
		return _world_bounds.position

	var relative: Vector2 = (minimap_position - map_rect.position) / map_rect.size
	relative = Vector2(clampf(relative.x, 0.0, 1.0), clampf(relative.y, 0.0, 1.0))
	return _world_bounds.position + (relative * bounds_size)

func _refresh_world_bounds() -> void:
	if _try_build_bounds_from_world_tile_map():
		_has_world_bounds = true
		return

	if _try_build_bounds_from_entities():
		_has_world_bounds = true
		return

	_has_world_bounds = false

func _try_build_bounds_from_world_tile_map() -> bool:
	var tile_map_layer: Node = _find_world_tile_map_layer()
	if tile_map_layer == null:
		return false
	if not tile_map_layer.has_method("get_used_rect") or not tile_map_layer.has_method("map_to_local"):
		return false
	if not (tile_map_layer is Node2D):
		return false

	var used_rect: Rect2i = tile_map_layer.call("get_used_rect")
	if used_rect.size == Vector2i.ZERO:
		return false

	var tile_size: Vector2 = Vector2(32.0, 32.0)
	var tile_set_variant: Variant = tile_map_layer.get("tile_set")
	if tile_set_variant is TileSet:
		tile_size = Vector2((tile_set_variant as TileSet).tile_size)

	var top_left_local: Vector2 = tile_map_layer.call("map_to_local", used_rect.position) - (tile_size * 0.5)
	var bottom_right_local: Vector2 = top_left_local + (Vector2(used_rect.size) * tile_size)

	var world_node: Node2D = tile_map_layer as Node2D
	var top_left_global: Vector2 = world_node.to_global(top_left_local)
	var bottom_right_global: Vector2 = world_node.to_global(bottom_right_local)
	var min_point: Vector2 = Vector2(min(top_left_global.x, bottom_right_global.x), min(top_left_global.y, bottom_right_global.y))
	var max_point: Vector2 = Vector2(max(top_left_global.x, bottom_right_global.x), max(top_left_global.y, bottom_right_global.y))

	_world_bounds = Rect2(min_point, max_point - min_point)
	return _world_bounds.size.x > 0.0 and _world_bounds.size.y > 0.0

func _try_build_bounds_from_entities() -> bool:
	var points: Array[Vector2] = []
	for group_name in [&"players", &"summons", &"enemies", &"house", &"enemy_towers"]:
		for node in _get_group_nodes_2d(group_name):
			points.append(node.global_position)

	if points.is_empty():
		return false

	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)

	var padding: Vector2 = Vector2(160.0, 160.0)
	_world_bounds = Rect2(min_point - padding, (max_point - min_point) + (padding * 2.0))
	return _world_bounds.size.x > 0.0 and _world_bounds.size.y > 0.0

func _find_world_tile_map_layer() -> Node:
	var current_scene: Node = get_tree().current_scene
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

func _get_group_nodes_2d(group_name: StringName) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group(group_name):
		if candidate is Node2D:
			nodes.append(candidate as Node2D)
	return nodes
