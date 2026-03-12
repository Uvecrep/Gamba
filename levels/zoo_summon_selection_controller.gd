extends Node

class_name ZooSummonSelectionController

@export var summon_pick_radius: float = 72.0

var _selected_summons: Array[Node2D] = []

func _ready() -> void:
	add_to_group("summon_selection_controllers")

func _process(_delta: float) -> void:
	_prune_selected_summons()

func select_summons_in_world_circle(world_center: Vector2, radius: float, additive_selection: bool = true) -> int:
	_prune_selected_summons()
	var previous_selection: Array[Node2D] = _selected_summons.duplicate()

	if not additive_selection:
		_selected_summons.clear()

	var radius_sq: float = maxf(radius, 0.0)
	radius_sq *= radius_sq
	var matched_count: int = 0

	for summon in _get_summons():
		if summon.global_position.distance_squared_to(world_center) > radius_sq:
			continue
		matched_count += 1
		if _selected_summons.has(summon):
			continue
		_selected_summons.append(summon)

	_finalize_selection_change(previous_selection)
	return matched_count

func clear_selection() -> void:
	if _selected_summons.is_empty():
		return

	var previous_selection: Array[Node2D] = _selected_summons.duplicate()
	_selected_summons.clear()
	_finalize_selection_change(previous_selection)

func hold_selected_summons() -> int:
	_prune_selected_summons()
	if _selected_summons.is_empty():
		return 0

	var all_selected_holding: bool = true
	for summon in _selected_summons:
		if not _is_summon_hold_toggle_enabled(summon):
			all_selected_holding = false
			break

	var target_hold_state: bool = not all_selected_holding
	var commanded_count: int = 0
	for summon in _selected_summons:
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
		if summon.has_method("set_auto_behavior"):
			summon.call("set_auto_behavior")
			commanded_count += 1
			continue
		if summon.has_method("clear_manual_command"):
			summon.call("clear_manual_command")
			commanded_count += 1

	return commanded_count

func issue_move_order_world(target_world_position: Vector2) -> int:
	_prune_selected_summons()
	if _selected_summons.is_empty():
		return 0

	var moved_count: int = 0
	for summon in _selected_summons:
		if not summon.has_method("set_move_target"):
			continue
		summon.call("set_move_target", target_world_position)
		moved_count += 1

	return moved_count

func get_selected_summon_count() -> int:
	_prune_selected_summons()
	return _selected_summons.size()

func get_selected_hold_toggled_count() -> int:
	_prune_selected_summons()
	var hold_count: int = 0
	for summon in _selected_summons:
		if _is_summon_hold_toggle_enabled(summon):
			hold_count += 1
	return hold_count

func _get_summons() -> Array[Node2D]:
	var summons: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("summons"):
		if candidate is Node2D:
			summons.append(candidate as Node2D)
	return summons

func _prune_selected_summons() -> void:
	var previous_selection: Array[Node2D] = _selected_summons.duplicate()
	var alive_summons: Array[Node2D] = []
	for summon in _selected_summons:
		if is_instance_valid(summon):
			alive_summons.append(summon)

	if alive_summons.size() == _selected_summons.size():
		return

	_selected_summons = alive_summons
	_finalize_selection_change(previous_selection)

func _finalize_selection_change(previous_selection: Array[Node2D]) -> void:
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
	if not summon.has_method("set_selected_for_command"):
		return
	summon.call("set_selected_for_command", is_selected)

func _is_summon_hold_toggle_enabled(summon: Node2D) -> bool:
	if summon == null:
		return false
	if summon.has_method("is_hold_toggle_enabled"):
		return bool(summon.call("is_hold_toggle_enabled"))
	if summon.has_method("is_holding_position"):
		return bool(summon.call("is_holding_position"))
	return false
