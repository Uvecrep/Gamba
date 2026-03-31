extends StaticBody2D
class_name PhoneInteractable

@export var interact_action: StringName = &"interact"
@export var interact_range: float = 96.0
@export_multiline var tutorial_text: String = "Survive each night by holding the house and clearing waves.\nBuild up during the day, then prepare for the next night."
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
@onready var _tutorial_button: Button = get_node_or_null("DialogLayer/PhoneDialog/MarginContainer/VBoxContainer/TutorialButton") as Button
@onready var _close_hint_label: Label = get_node_or_null("DialogLayer/PhoneDialog/MarginContainer/VBoxContainer/CloseHint") as Label
@onready var _tutorial_dialog: AcceptDialog = get_node_or_null("DialogLayer/TutorialDialog") as AcceptDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("phones")
	_action_hint_text = INPUT_HINT_UTIL.resolve_action_hint(interact_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D
	if _tutorial_button != null and not _tutorial_button.pressed.is_connected(_on_tutorial_button_pressed):
		_tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	_set_dialog_open(false)
	_update_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.tick_refresh_time_left(_prompt_refresh_time_left, delta)
	if _prompt_refresh_time_left > 0.0:
		return

	_update_prompt()
	_schedule_prompt_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not _dialog_open:
		return
	if not event.is_action_pressed(interact_action) and not event.is_action_pressed(&"ui_cancel"):
		return

	_set_dialog_open(false)
	get_viewport().set_input_as_handled()

func interact(_player: Node2D) -> void:
	if _dialog_open:
		_set_dialog_open(false)
		return

	if _dialog_text_label != null:
		_dialog_text_label.text = _build_wave_report_text()
	if _tutorial_dialog != null:
		_tutorial_dialog.dialog_text = tutorial_text

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

func is_dialog_open() -> bool:
	return _dialog_open

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


func _on_tutorial_button_pressed() -> void:
	if _tutorial_dialog == null:
		return
	_tutorial_dialog.dialog_text = tutorial_text
	_tutorial_dialog.popup_centered()


func _build_wave_report_text() -> String:
	var day_night_controller: DayNightController = _find_day_night_controller()
	if day_night_controller == null:
		return "Tonight's wave intel is unavailable right now."

	var target_night_number: int = maxi(day_night_controller.get_incoming_night_number(), 1)
	var wave_sizes: Array[int] = day_night_controller.get_wave_sizes_for_night(target_night_number)
	var line_items: PackedStringArray = PackedStringArray()
	line_items.append("Night %d forecast" % target_night_number)
	line_items.append("Waves tonight: %d" % wave_sizes.size())
	for wave_index in wave_sizes.size():
		line_items.append("Wave %d: %d enemies" % [wave_index + 1, wave_sizes[wave_index]])

	# Add time remaining
	var time_remaining: float = day_night_controller.get_time_remaining_seconds()
	var minutes: int = int(time_remaining) / 60
	var seconds: int = int(time_remaining) % 60
	
	if day_night_controller.is_night_time():
		line_items.append("---")
		line_items.append("Night time remaining: %d:%02d" % [minutes, seconds])
	else:
		line_items.append("---")
		line_items.append("Until night: %d:%02d" % [minutes, seconds])

	return "\n".join(line_items)


func _find_day_night_controller() -> DayNightController:
	var cycle_owner: Node = get_tree().get_first_node_in_group("day_night_cycle_controllers")
	if cycle_owner == null:
		return null

	var controller: DayNightController = cycle_owner.get_node_or_null("DayNightController") as DayNightController
	return controller
