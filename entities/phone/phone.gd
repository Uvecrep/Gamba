extends StaticBody2D
class_name PhoneInteractable

@export var interact_action: StringName = &"interact"
@export var interact_range: float = 96.0
@export_multiline var dialog_message: String = "Calling the enemy summoner...\n\nEnemy Summoner: The wave timer feed is down right now.\nTry again in a bit for a real ETA."
@export var prompt_refresh_interval: float = 0.2
const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")
const PROXIMITY_PROMPT_UTIL: GDScript = preload("res://scripts/proximity_prompt_util.gd")

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
	_action_hint_text = INPUT_HINT_UTIL.resolve_action_hint(interact_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D
	_set_dialog_open(false)
	_update_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.tick_refresh_time_left(_prompt_refresh_time_left, delta)
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
	return PROXIMITY_PROMPT_UTIL.is_any_player_in_fixed_range(self, global_position, interact_range, _spatial_index)

func _schedule_prompt_refresh(initial_delay: float = -1.0) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.schedule_next_refresh(
		prompt_refresh_interval,
		0.05,
		0.3,
		initial_delay
	)
