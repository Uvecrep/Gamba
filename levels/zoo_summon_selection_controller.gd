extends Node

class_name ZooSummonSelectionController

const SUMMON_SELECTION_STATE_PATH: String = "res://scripts/summon_selection_state.gd"

@export var summon_pick_radius: float = 72.0

var _selection_state = null

func _ready() -> void:
	_selection_state = load(SUMMON_SELECTION_STATE_PATH).new(self)
	add_to_group("summon_selection_controllers")

func _process(_delta: float) -> void:
	_selection_state.prune_selected_summons()

func select_summons_in_world_circle(world_center: Vector2, radius: float, additive_selection: bool = true) -> int:
	return _selection_state.select_summons_in_world_circle(world_center, radius, additive_selection)

func clear_selection() -> void:
	_selection_state.clear_selection()

func hold_selected_summons() -> int:
	return _selection_state.hold_selected_summons()

func follow_selected_summons() -> int:
	return _selection_state.follow_selected_summons()

func auto_selected_summons() -> int:
	return _selection_state.auto_selected_summons()

func issue_move_order_world(target_world_position: Vector2) -> int:
	return _selection_state.issue_move_order_world(target_world_position)

func get_selected_summon_count() -> int:
	return _selection_state.get_selected_summon_count()

func get_selected_hold_toggled_count() -> int:
	return _selection_state.get_selected_hold_toggled_count()
