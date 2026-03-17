extends RefCounted
class_name PlayerSummonCommandComponent

var _is_middle_mouse_selecting: bool = false
var _middle_select_last_world_point: Vector2 = Vector2.ZERO
var _middle_select_found_summon: bool = false
var _middle_select_preview_world_point: Vector2 = Vector2.ZERO
var _summon_selection_controller: Node

func physics_update(player: Player) -> void:
	if not _is_middle_mouse_selecting:
		return

	_middle_select_preview_world_point = player.get_global_mouse_position()
	player.queue_redraw()

func handle_input(player: Player, event: InputEvent) -> void:
	if is_map_open(player):
		if event is InputEventMouseButton:
			var map_mouse_button: InputEventMouseButton = event as InputEventMouseButton
			if map_mouse_button.button_index == MOUSE_BUTTON_MIDDLE and not map_mouse_button.pressed:
				reset_middle_mouse_selection_state(player)
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_MIDDLE:
			return

		if mouse_button.pressed:
			begin_middle_mouse_selection(player)
		else:
			end_middle_mouse_selection(player)
		return

	if event is InputEventMouseMotion:
		update_middle_mouse_drag_selection(player)

func handle_summon_command_shortcuts(player: Player) -> void:
	if is_map_open(player):
		return

	var selection_controller: Node = _get_summon_selection_controller(player)
	if selection_controller == null:
		return

	if Input.is_action_just_pressed(player.summon_command_hold_action):
		_apply_hold_command(selection_controller)

	if Input.is_action_just_pressed(player.summon_command_follow_action):
		_apply_follow_command(selection_controller)

	if Input.is_action_just_pressed(player.summon_command_auto_action):
		_apply_auto_command(selection_controller)

func draw(player: Player) -> void:
	if not _is_middle_mouse_selecting:
		return

	var local_center: Vector2 = player.to_local(_middle_select_preview_world_point)
	player.draw_circle(local_center, player.summon_selection_radius, player.summon_selection_preview_fill_color)
	player.draw_arc(local_center, player.summon_selection_radius, 0.0, TAU, 48, player.summon_selection_preview_line_color, player.summon_selection_preview_line_width, true)

func begin_middle_mouse_selection(player: Player) -> void:
	if is_map_open(player):
		return

	_is_middle_mouse_selecting = true
	_middle_select_found_summon = false
	_middle_select_last_world_point = player.get_global_mouse_position()
	_middle_select_preview_world_point = _middle_select_last_world_point
	player.queue_redraw()
	if _select_summons_in_world_radius(player, _middle_select_last_world_point):
		_middle_select_found_summon = true

func end_middle_mouse_selection(player: Player) -> void:
	if not _is_middle_mouse_selecting:
		return

	if not _middle_select_found_summon:
		clear_selected_summons(player)

	reset_middle_mouse_selection_state(player)

func update_middle_mouse_drag_selection(player: Player) -> void:
	if not _is_middle_mouse_selecting:
		return
	if is_map_open(player):
		return

	var mouse_world_position: Vector2 = player.get_global_mouse_position()
	if _middle_select_last_world_point.distance_to(mouse_world_position) < maxf(player.summon_selection_drag_step, 1.0):
		return

	_middle_select_last_world_point = mouse_world_position
	_middle_select_preview_world_point = mouse_world_position
	if _select_summons_in_world_radius(player, mouse_world_position):
		_middle_select_found_summon = true

func reset_middle_mouse_selection_state(player: Player) -> void:
	_is_middle_mouse_selecting = false
	_middle_select_found_summon = false
	player.queue_redraw()

func is_map_open(player: Player) -> bool:
	for map_node in player.get_tree().get_nodes_in_group("maps"):
		if map_node != null and map_node.has_method("is_map_open") and map_node.is_map_open():
			return true

	return false

func _select_summons_in_world_radius(player: Player, world_position: Vector2) -> bool:
	var selection_controller: Node = _get_summon_selection_controller(player)
	if selection_controller is ZooSummonSelectionController:
		var zoo_controller: ZooSummonSelectionController = selection_controller as ZooSummonSelectionController
		var zoo_matched_count: int = zoo_controller.select_summons_in_world_circle(world_position, player.summon_selection_radius, true)
		return zoo_matched_count > 0

	if selection_controller is WorldMinimap:
		var minimap_controller: WorldMinimap = selection_controller as WorldMinimap
		var minimap_matched_count: int = minimap_controller.select_summons_in_world_circle(world_position, player.summon_selection_radius, true)
		return minimap_matched_count > 0

	return false

func clear_selected_summons(player: Player) -> void:
	var selection_controller: Node = _get_summon_selection_controller(player)
	if selection_controller == null:
		return

	if selection_controller is ZooSummonSelectionController:
		(selection_controller as ZooSummonSelectionController).clear_selection()
		return

	if selection_controller is WorldMinimap:
		(selection_controller as WorldMinimap).clear_selection()

func _get_summon_selection_controller(player: Player) -> Node:
	if is_instance_valid(_summon_selection_controller) and _is_supported_selection_controller(_summon_selection_controller):
		return _summon_selection_controller

	var controllers: Array = player.get_tree().get_nodes_in_group("summon_selection_controllers")
	var minimap_fallback: Node = null
	for controller in controllers:
		if not is_instance_valid(controller):
			continue
		if controller is ZooSummonSelectionController:
			_summon_selection_controller = controller
			return _summon_selection_controller
		if controller is WorldMinimap and minimap_fallback == null:
			minimap_fallback = controller

	if is_instance_valid(minimap_fallback):
		_summon_selection_controller = minimap_fallback
		return _summon_selection_controller

	return null

func _is_supported_selection_controller(controller: Node) -> bool:
	return controller is ZooSummonSelectionController or controller is WorldMinimap

func _apply_hold_command(selection_controller: Node) -> void:
	if selection_controller is ZooSummonSelectionController:
		(selection_controller as ZooSummonSelectionController).hold_selected_summons()
		return
	if selection_controller is WorldMinimap:
		(selection_controller as WorldMinimap).hold_selected_summons()

func _apply_follow_command(selection_controller: Node) -> void:
	if selection_controller is ZooSummonSelectionController:
		(selection_controller as ZooSummonSelectionController).follow_selected_summons()
		return
	if selection_controller is WorldMinimap:
		(selection_controller as WorldMinimap).follow_selected_summons()

func _apply_auto_command(selection_controller: Node) -> void:
	if selection_controller is ZooSummonSelectionController:
		(selection_controller as ZooSummonSelectionController).auto_selected_summons()
		return
	if selection_controller is WorldMinimap:
		(selection_controller as WorldMinimap).auto_selected_summons()
