extends StaticBody2D
class_name MapInteractable

@export var interact_action: StringName = &"interact"
@export var interact_range: float = 96.0
@export var prompt_refresh_interval: float = 0.2

const MAP_CONTROL_HINT: String = "LMB select/drag | Shift/Ctrl add | RMB move"
const MAP_HELP_TEXT: String = "Left-click summon: Select one\nLeft-click drag: Box select\nShift/Ctrl + left-click: Add to selection\nRight-click map: Move selected summons\n\nButtons:\nToggle Hold: Toggle hold position for selected summons\nFollow: Make selected summons follow players\nAuto: Return selected summons to auto behavior\nClear Selection: Deselect all summons"
const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")
const PROXIMITY_PROMPT_UTIL: GDScript = preload("res://scripts/proximity_prompt_util.gd")
const INTERACT_REOPEN_BLOCK_MS: int = 150

var _action_hint_text: String = "E"
var _map_open: bool = false
var _reopen_block_until_msec: int = 0
var _prompt_refresh_time_left: float = 0.0
var _spatial_index: SpatialIndex2D

@onready var _prompt_label: Label = get_node_or_null("InteractPrompt") as Label
@onready var _map_layer: CanvasLayer = get_node_or_null("MapLayer") as CanvasLayer
@onready var _map_panel: PanelContainer = get_node_or_null("MapLayer/MapWindow") as PanelContainer
@onready var _minimap: WorldMinimap = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/WorldMinimap") as WorldMinimap
@onready var _selection_label: Label = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/SelectionLabel") as Label
@onready var _status_label: Label = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/StatusLabel") as Label
@onready var _close_hint_label: Label = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/CloseHint") as Label
@onready var _help_dialog: AcceptDialog = get_node_or_null("MapLayer/MapHelpDialog") as AcceptDialog
@onready var _hold_selected_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonStack/TopButtonRow/HoldSelectedButton") as Button
@onready var _follow_selected_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonStack/TopButtonRow/FollowSelectedButton") as Button
@onready var _auto_selected_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonStack/TopButtonRow/AutoSelectedButton") as Button
@onready var _clear_selection_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonStack/BottomButtonRow/ClearSelectionButton") as Button
@onready var _help_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonStack/BottomButtonRow/HelpButton") as Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("maps")
	_action_hint_text = INPUT_HINT_UTIL.resolve_action_hint(interact_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D

	if is_instance_valid(_hold_selected_button):
		_hold_selected_button.pressed.connect(_on_hold_selected_pressed)
	if is_instance_valid(_follow_selected_button):
		_follow_selected_button.pressed.connect(_on_follow_selected_pressed)
	if is_instance_valid(_auto_selected_button):
		_auto_selected_button.pressed.connect(_on_auto_selected_pressed)
	if is_instance_valid(_clear_selection_button):
		_clear_selection_button.pressed.connect(_on_clear_selection_pressed)
	if is_instance_valid(_help_button):
		_help_button.pressed.connect(_on_help_pressed)

	if is_instance_valid(_help_dialog):
		_help_dialog.dialog_text = MAP_HELP_TEXT

	if _minimap != null:
		if _minimap.has_signal("selection_changed"):
			_minimap.connect("selection_changed", Callable(self, "_on_selection_changed"))
		if _minimap.has_signal("move_order_issued"):
			_minimap.connect("move_order_issued", Callable(self, "_on_move_order_issued"))

	_set_map_open(false)
	_on_selection_changed(_get_selected_count())
	_set_status(MAP_CONTROL_HINT)
	_update_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.tick_refresh_time_left(_prompt_refresh_time_left, delta)
	if _prompt_refresh_time_left > 0.0:
		return

	_update_prompt()
	_schedule_prompt_refresh()

func _input(event: InputEvent) -> void:
	if _try_handle_close_input(event):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _try_handle_close_input(event):
		get_viewport().set_input_as_handled()

func interact(player: Node2D) -> void:
	if _map_open:
		_close_map_with_reopen_guard()
		return

	if Time.get_ticks_msec() < _reopen_block_until_msec:
		return

	if player != null and not can_interact_with_player(player):
		return

	_set_map_open(true)
	_set_status(MAP_CONTROL_HINT)

func can_interact_with_player(player: Node2D) -> bool:
	if player == null:
		return false

	return global_position.distance_squared_to(player.global_position) <= interact_range * interact_range

func is_map_open() -> bool:
	return _map_open

func get_minimap_control() -> Control:
	return _minimap

func _set_map_open(should_open: bool) -> void:
	_map_open = should_open
	if _map_layer != null:
		_map_layer.visible = should_open
	if _map_panel != null:
		_map_panel.visible = should_open

	if _close_hint_label != null:
		_close_hint_label.text = "Press %s to close map" % _action_hint_text

	if should_open and is_instance_valid(_hold_selected_button):
		_hold_selected_button.grab_focus()

func _try_handle_close_input(event: InputEvent) -> bool:
	if not _map_open:
		return false
	if not event.is_action_pressed(interact_action) and not event.is_action_pressed(&"ui_cancel"):
		return false

	_close_map_with_reopen_guard()
	return true

func _close_map_with_reopen_guard() -> void:
	_reopen_block_until_msec = Time.get_ticks_msec() + INTERACT_REOPEN_BLOCK_MS
	_set_map_open(false)

func _on_hold_selected_pressed() -> void:
	if _minimap == null:
		return

	var toggled_count: int = _minimap.hold_selected_summons()
	if toggled_count <= 0:
		_set_status("No summons selected.")
		return

	var selected_count: int = _get_selected_count()
	var holding_count: int = _get_selected_hold_toggled_count()
	if selected_count > 0 and holding_count == selected_count:
		_set_status("Hold enabled for %d summon(s)." % toggled_count)
	else:
		_set_status("Auto mode enabled for %d summon(s)." % toggled_count)

	_on_selection_changed(_get_selected_count())

func _on_clear_selection_pressed() -> void:
	if _minimap == null:
		return

	_minimap.clear_selection()
	_set_status("Selection cleared.")

func _on_follow_selected_pressed() -> void:
	if _minimap == null:
		return

	var followed_count: int = _minimap.follow_selected_summons()
	if followed_count <= 0:
		_set_status("No summons selected.")
		return

	_set_status("Follow enabled for %d summon(s)." % followed_count)
	_on_selection_changed(_get_selected_count())

func _on_auto_selected_pressed() -> void:
	if _minimap == null:
		return

	var auto_count: int = _minimap.auto_selected_summons()
	if auto_count <= 0:
		_set_status("No summons selected.")
		return

	_set_status("Auto behavior resumed for %d summon(s)." % auto_count)
	_on_selection_changed(_get_selected_count())

func _on_help_pressed() -> void:
	if not is_instance_valid(_help_dialog):
		return

	_help_dialog.popup_centered_clamped(Vector2(620, 420), 0.9)

func _on_selection_changed(selected_count: int) -> void:
	if _selection_label != null:
		var holding_count: int = _get_selected_hold_toggled_count()
		var not_holding_count: int = maxi(selected_count - holding_count, 0)
		_selection_label.text = "Selected summons: %d | Hold Toggled: %d | Auto: %d" % [selected_count, holding_count, not_holding_count]

func _on_move_order_issued(target_world_position: Vector2, summon_count: int) -> void:
	_set_status("Sent %d summon(s) to (%.0f, %.0f)." % [summon_count, target_world_position.x, target_world_position.y])
	_on_selection_changed(_get_selected_count())

func _get_selected_count() -> int:
	if _minimap == null:
		return 0
	return _minimap.get_selected_summon_count()

func _get_selected_hold_toggled_count() -> int:
	if _minimap == null:
		return 0
	return _minimap.get_selected_hold_toggled_count()

func _set_status(status_text: String) -> void:
	if _status_label == null:
		return
	_status_label.text = status_text

func _update_prompt() -> void:
	if _prompt_label == null:
		return

	var is_player_close: bool = _is_any_player_in_range()
	_prompt_label.visible = is_player_close and not _map_open
	if not _prompt_label.visible:
		return

	_prompt_label.text = "Press %s to open map" % _action_hint_text

func _is_any_player_in_range() -> bool:
	return PROXIMITY_PROMPT_UTIL.is_any_player_in_fixed_range(self, global_position, interact_range, _spatial_index)

func _schedule_prompt_refresh(initial_delay: float = -1.0) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.schedule_next_refresh(
		prompt_refresh_interval,
		0.05,
		0.3,
		initial_delay
	)
