extends RefCounted

signal selection_updated(selected_count: int)

var _owner_ref: WeakRef
var _selected_summons: Array[Node2D] = []

func _init(owner: Node) -> void:
	_owner_ref = weakref(owner)

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
	prune_selected_summons()
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

func select_summon(summon: Node2D, additive_selection: bool) -> void:
	if not is_instance_valid(summon):
		return

	prune_selected_summons()
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

func clear_selection() -> void:
	if _selected_summons.is_empty():
		return

	var previous_selection: Array[Node2D] = _selected_summons.duplicate()
	_selected_summons.clear()
	_finalize_selection_change(previous_selection)

func hold_selected_summons() -> int:
	prune_selected_summons()
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
		if not summon is SummonUnit:
			continue
		(summon as SummonUnit).set_hold_position(target_hold_state)
		commanded_count += 1

	return commanded_count

func follow_selected_summons() -> int:
	prune_selected_summons()
	if _selected_summons.is_empty():
		return 0

	var commanded_count: int = 0
	for summon in _selected_summons:
		if not summon is SummonUnit:
			continue
		(summon as SummonUnit).set_follow_player()
		commanded_count += 1

	return commanded_count

func auto_selected_summons() -> int:
	prune_selected_summons()
	if _selected_summons.is_empty():
		return 0

	var commanded_count: int = 0
	for summon in _selected_summons:
		if summon is SummonUnit:
			(summon as SummonUnit).set_auto_behavior()
			commanded_count += 1

	return commanded_count

func issue_move_order_world(target_world_position: Vector2) -> int:
	prune_selected_summons()
	if _selected_summons.is_empty():
		return 0

	var moved_count: int = 0
	for summon in _selected_summons:
		if not summon is SummonUnit:
			continue
		(summon as SummonUnit).set_move_target(target_world_position)
		moved_count += 1

	return moved_count

func has_selected_summons() -> bool:
	prune_selected_summons()
	return not _selected_summons.is_empty()

func is_selected_summon(summon: Node2D) -> bool:
	if not is_instance_valid(summon):
		return false
	return _selected_summons.has(summon)

func get_selected_summon_count() -> int:
	prune_selected_summons()
	return _selected_summons.size()

func get_selected_holding_count() -> int:
	prune_selected_summons()
	var holding_count: int = 0
	for summon in _selected_summons:
		if _is_summon_holding(summon):
			holding_count += 1

	return holding_count

func get_selected_hold_toggled_count() -> int:
	prune_selected_summons()
	var hold_toggled_count: int = 0
	for summon in _selected_summons:
		if _is_summon_hold_toggle_enabled(summon):
			hold_toggled_count += 1

	return hold_toggled_count

func prune_selected_summons() -> void:
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

	selection_updated.emit(_selected_summons.size())

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
	if not summon is SummonUnit:
		return
	(summon as SummonUnit).set_selected_for_command(is_selected)

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
	if summon is SummonUnit:
		return (summon as SummonUnit).is_holding_position()
	return false

func _is_summon_hold_toggle_enabled(summon: Node2D) -> bool:
	if summon == null:
		return false
	if summon is SummonUnit:
		return (summon as SummonUnit).is_hold_toggle_enabled()
	return false

func _get_owner_node() -> Node:
	if _owner_ref == null:
		return null
	return _owner_ref.get_ref() as Node

func _get_group_nodes_2d(group_name: StringName) -> Array[Node2D]:
	var owner: Node = _get_owner_node()
	if owner == null:
		return []

	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return []

	var nodes: Array[Node2D] = []
	for candidate in tree.get_nodes_in_group(group_name):
		if candidate is Node2D:
			nodes.append(candidate as Node2D)
	return nodes