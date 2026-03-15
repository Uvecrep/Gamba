extends StaticBody2D

@export var interact_action: StringName = &"interact"
@export var interact_range: float = 96.0
@export var prompt_refresh_interval: float = 0.2

const MAP_STATUS_HINT: String = "Click or drag to select. Right-click to move. Use Hold, Follow, or Auto for selected summons."

var _action_hint_text: String = "E"
var _map_open: bool = false
var _prompt_refresh_time_left: float = 0.0
var _spatial_index: SpatialIndex2D

@onready var _prompt_label: Label = get_node_or_null("InteractPrompt") as Label
@onready var _map_layer: CanvasLayer = get_node_or_null("MapLayer") as CanvasLayer
@onready var _map_panel: PanelContainer = get_node_or_null("MapLayer/MapWindow") as PanelContainer
@onready var _minimap: Control = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/WorldMinimap") as Control
@onready var _selection_label: Label = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/SelectionLabel") as Label
@onready var _status_label: Label = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/StatusLabel") as Label
@onready var _close_hint_label: Label = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/CloseHint") as Label
@onready var _hold_selected_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonRow/HoldSelectedButton") as Button
@onready var _follow_selected_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonRow/FollowSelectedButton") as Button
@onready var _auto_selected_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonRow/AutoSelectedButton") as Button
@onready var _clear_selection_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonRow/ClearSelectionButton") as Button
@onready var _close_button: Button = get_node_or_null("MapLayer/MapWindow/MarginContainer/VBoxContainer/ButtonRow/CloseButton") as Button

func _ready() -> void:
	add_to_group("maps")
	_action_hint_text = _resolve_action_hint(interact_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D

	if is_instance_valid(_hold_selected_button):
		_hold_selected_button.pressed.connect(_on_hold_selected_pressed)
	if is_instance_valid(_follow_selected_button):
		_follow_selected_button.pressed.connect(_on_follow_selected_pressed)
	if is_instance_valid(_auto_selected_button):
		_auto_selected_button.pressed.connect(_on_auto_selected_pressed)
	if is_instance_valid(_clear_selection_button):
		_clear_selection_button.pressed.connect(_on_clear_selection_pressed)
	if is_instance_valid(_close_button):
		_close_button.pressed.connect(_on_close_pressed)

	if _minimap != null:
		if _minimap.has_signal("selection_changed"):
			_minimap.connect("selection_changed", Callable(self, "_on_selection_changed"))
		if _minimap.has_signal("move_order_issued"):
			_minimap.connect("move_order_issued", Callable(self, "_on_move_order_issued"))

	_set_map_open(false)
	_on_selection_changed(_get_selected_count())
	_set_status(MAP_STATUS_HINT)
	_update_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = maxf(_prompt_refresh_time_left - delta, 0.0)
	if _prompt_refresh_time_left > 0.0:
		return

	_update_prompt()
	_schedule_prompt_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not _map_open:
		return
	if not event.is_action_pressed(interact_action) and not event.is_action_pressed(&"ui_cancel"):
		return

	_set_map_open(false)
	get_viewport().set_input_as_handled()

func interact(player: Node2D) -> void:
	if _map_open:
		_set_map_open(false)
		return

	if player != null and not can_interact_with_player(player):
		return

	_set_map_open(true)
	_set_status(MAP_STATUS_HINT)

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

func _on_hold_selected_pressed() -> void:
	if _minimap == null or not _minimap.has_method("hold_selected_summons"):
		return

	var toggled_count: int = int(_minimap.call("hold_selected_summons"))
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
	if _minimap == null or not _minimap.has_method("clear_selection"):
		return

	_minimap.call("clear_selection")
	_set_status("Selection cleared.")

func _on_follow_selected_pressed() -> void:
	if _minimap == null or not _minimap.has_method("follow_selected_summons"):
		return

	var followed_count: int = int(_minimap.call("follow_selected_summons"))
	if followed_count <= 0:
		_set_status("No summons selected.")
		return

	_set_status("Follow enabled for %d summon(s)." % followed_count)
	_on_selection_changed(_get_selected_count())

func _on_auto_selected_pressed() -> void:
	if _minimap == null or not _minimap.has_method("auto_selected_summons"):
		return

	var auto_count: int = int(_minimap.call("auto_selected_summons"))
	if auto_count <= 0:
		_set_status("No summons selected.")
		return

	_set_status("Auto behavior resumed for %d summon(s)." % auto_count)
	_on_selection_changed(_get_selected_count())

func _on_close_pressed() -> void:
	_set_map_open(false)

func _on_selection_changed(selected_count: int) -> void:
	if _selection_label != null:
		var holding_count: int = _get_selected_hold_toggled_count()
		var not_holding_count: int = maxi(selected_count - holding_count, 0)
		_selection_label.text = "Selected summons: %d | Hold Toggled: %d | Auto: %d" % [selected_count, holding_count, not_holding_count]

func _on_move_order_issued(target_world_position: Vector2, summon_count: int) -> void:
	_set_status("Sent %d summon(s) to (%.0f, %.0f)." % [summon_count, target_world_position.x, target_world_position.y])
	_on_selection_changed(_get_selected_count())

func _get_selected_count() -> int:
	if _minimap == null or not _minimap.has_method("get_selected_summon_count"):
		return 0
	return int(_minimap.call("get_selected_summon_count"))

func _get_selected_hold_toggled_count() -> int:
	if _minimap == null or not _minimap.has_method("get_selected_hold_toggled_count"):
		return 0
	return int(_minimap.call("get_selected_hold_toggled_count"))

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
	if is_instance_valid(_spatial_index):
		var nearby_players: Array[Node2D] = _spatial_index.get_nodes_in_radius(global_position, &"players", interact_range)
		return not nearby_players.is_empty()

	for player in get_tree().get_nodes_in_group("players"):
		if not (player is Node2D):
			continue

		var player_node: Node2D = player as Node2D
		if global_position.distance_squared_to(player_node.global_position) <= interact_range * interact_range:
			return true

	return false

func _schedule_prompt_refresh(initial_delay: float = -1.0) -> void:
	if initial_delay >= 0.0:
		_prompt_refresh_time_left = initial_delay
		return

	var base_interval: float = maxf(prompt_refresh_interval, 0.05)
	var jitter: float = randf_range(0.0, base_interval * 0.3)
	_prompt_refresh_time_left = base_interval + jitter

func _resolve_action_hint(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action).to_upper()

	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event in events:
		if event == null:
			continue

		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode != 0:
				return OS.get_keycode_string(key_event.physical_keycode)
			if key_event.keycode != 0:
				return OS.get_keycode_string(key_event.keycode)

		var event_text: String = event.as_text()
		if not event_text.is_empty():
			return event_text

	return String(action).to_upper()
