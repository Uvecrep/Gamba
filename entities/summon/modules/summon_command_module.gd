extends RefCounted

var unit

func _init(owner) -> void:
	unit = owner

func set_move_target(target_position: Vector2) -> void:
	unit._move_target_position = target_position
	unit._command_mode = unit.CommandMode.MOVE
	unit._set_navigation_target(target_position)

func set_hold_position(should_hold: bool) -> void:
	unit._hold_toggle_enabled = should_hold

	if unit._command_mode == unit.CommandMode.MOVE:
		return

	if should_hold:
		unit._command_mode = unit.CommandMode.HOLD
		unit.velocity = Vector2.ZERO
		return

	unit._command_mode = unit.CommandMode.AUTO

func clear_manual_command() -> void:
	if unit._hold_toggle_enabled:
		unit._command_mode = unit.CommandMode.HOLD
	else:
		unit._command_mode = unit.CommandMode.AUTO

func set_follow_player() -> void:
	if not is_instance_valid(unit._player_target):
		unit._player_target = unit._find_player()

	if not is_instance_valid(unit._player_target):
		unit._command_mode = unit.CommandMode.AUTO
		return

	unit._hold_toggle_enabled = false
	unit._command_mode = unit.CommandMode.FOLLOW
	unit._time_to_follow_nav_refresh = 0.0
	unit._time_to_follow_enemy_scan = 0.0
	unit._follow_snapshot_target = Vector2.INF
	unit._last_follow_nav_target = Vector2.INF

func set_auto_behavior() -> void:
	unit._hold_toggle_enabled = false
	unit._command_mode = unit.CommandMode.AUTO
	unit._clear_navigation_target()

func is_holding_position() -> bool:
	return unit._command_mode == unit.CommandMode.HOLD

func is_hold_toggle_enabled() -> bool:
	return unit._hold_toggle_enabled

func get_command_mode_name() -> String:
	match unit._command_mode:
		unit.CommandMode.MOVE:
			return "MOVE"
		unit.CommandMode.FOLLOW:
			return "FOLLOW"
		unit.CommandMode.HOLD:
			return "HOLD"
		_:
			return "AUTO"
