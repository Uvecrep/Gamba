extends StaticBody2D

@export var interact_action: StringName = &"interact"
@export var interact_range: float = 96.0
@export_multiline var dialog_message: String = "Calling the enemy summoner...\n\nEnemy Summoner: The wave timer feed is down right now.\nTry again in a bit for a real ETA."
@export var prompt_refresh_interval: float = 0.2

var _action_hint_text: String = "E"
var _dialog_open: bool = false
var _prompt_refresh_time_left: float = 0.0
var _spatial_index: SpatialIndex2D

@onready var _prompt_label: Label = get_node_or_null("InteractPrompt") as Label
@onready var _dialog_layer: CanvasLayer = get_node_or_null("DialogLayer") as CanvasLayer
@onready var _dialog_panel: PanelContainer = get_node_or_null("DialogLayer/PhoneDialog") as PanelContainer
@onready var _dialog_text_label: Label = get_node_or_null("DialogLayer/PhoneDialog/MarginContainer/VBoxContainer/DialogText") as Label
@onready var _close_hint_label: Label = get_node_or_null("DialogLayer/PhoneDialog/MarginContainer/VBoxContainer/CloseHint") as Label

func _ready() -> void:
	add_to_group("phones")
	_action_hint_text = _resolve_action_hint(interact_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D
	_set_dialog_open(false)
	_update_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = maxf(_prompt_refresh_time_left - delta, 0.0)
	if _prompt_refresh_time_left > 0.0:
		return

	_update_prompt()
	_schedule_prompt_refresh()

func interact(_player: Node2D) -> void:
	if _dialog_open:
		_set_dialog_open(false)
		return

	if _dialog_text_label != null:
		_dialog_text_label.text = dialog_message

	_set_dialog_open(true)

func can_interact_with_player(player: Node2D) -> bool:
	if player == null:
		return false

	return global_position.distance_squared_to(player.global_position) <= interact_range * interact_range

func _set_dialog_open(should_open: bool) -> void:
	_dialog_open = should_open
	if _dialog_layer != null:
		_dialog_layer.visible = should_open
	if _dialog_panel != null:
		_dialog_panel.visible = should_open
	if _close_hint_label != null:
		_close_hint_label.text = "Press %s to end call" % _action_hint_text

func _update_prompt() -> void:
	if _prompt_label == null:
		return

	var is_player_close: bool = _is_any_player_in_range()
	_prompt_label.visible = is_player_close and not _dialog_open
	if not _prompt_label.visible:
		return

	_prompt_label.text = "Press %s to use phone" % _action_hint_text

func _is_any_player_in_range() -> bool:
	if is_instance_valid(_spatial_index):
		var nearby_players: Array[Node2D] = _spatial_index.get_nodes_in_radius(global_position, &"players", interact_range)
		return not nearby_players.is_empty()

	var players: Array = get_tree().get_nodes_in_group("players")
	for player in players:
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
