extends StaticBody2D
class_name PhoneInteractable

signal first_phone_interaction_completed

@export var interact_action: StringName = &"interact"
@export var interact_range: float = 96.0
@export_multiline var tutorial_text: String = "Survive each night by holding the house and clearing waves.\nBuild up during the day, then prepare for the next night."
@export var prompt_refresh_interval: float = 0.2
@export var indicator_bob_amplitude: float = 6.0
@export var indicator_bob_speed: float = 2.4
@export var reopen_block_seconds: float = 0.18
const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")
const PROXIMITY_PROMPT_UTIL: GDScript = preload("res://scripts/proximity_prompt_util.gd")

var _action_hint_text: String = "E"
var _dialog_open: bool = false
var _tutorial_complete: bool = false
var _prompt_refresh_time_left: float = 0.0
var _spatial_index: SpatialIndex2D
var _indicator_time: float = 0.0
var _indicator_base_position: Vector2 = Vector2.ZERO
var _reopen_block_time_left: float = 0.0

@onready var _prompt_label: Label = get_node_or_null("InteractPrompt") as Label
@onready var _dialog_layer: CanvasLayer = get_node_or_null("DialogLayer") as CanvasLayer
@onready var _dialog_panel: PanelContainer = get_node_or_null("DialogLayer/PhoneDialog") as PanelContainer
@onready var _dialog_text_label: Label = get_node_or_null("DialogLayer/PhoneDialog/MarginContainer/VBoxContainer/DialogText") as Label
@onready var _tutorial_button: Button = get_node_or_null("DialogLayer/PhoneDialog/MarginContainer/VBoxContainer/TutorialButton") as Button
@onready var _close_hint_label: Label = get_node_or_null("DialogLayer/PhoneDialog/MarginContainer/VBoxContainer/CloseHint") as Label
@onready var _tutorial_dialog: AcceptDialog = get_node_or_null("DialogLayer/TutorialDialog") as AcceptDialog
@onready var _tutorial_menu_panel: PanelContainer = get_node_or_null("DialogLayer/TutorialMenuPanel") as PanelContainer
@onready var _tutorial_lootboxes_button: Button = get_node_or_null("DialogLayer/TutorialMenuPanel/MarginContainer/VBoxContainer/LootboxesButton") as Button
@onready var _tutorial_controls_button: Button = get_node_or_null("DialogLayer/TutorialMenuPanel/MarginContainer/VBoxContainer/ControlsButton") as Button
@onready var _tutorial_summons_button: Button = get_node_or_null("DialogLayer/TutorialMenuPanel/MarginContainer/VBoxContainer/SummonsButton") as Button
@onready var _tutorial_day_night_button: Button = get_node_or_null("DialogLayer/TutorialMenuPanel/MarginContainer/VBoxContainer/DayNightButton") as Button
@onready var _tutorial_back_button: Button = get_node_or_null("DialogLayer/TutorialMenuPanel/MarginContainer/VBoxContainer/BackButton") as Button
@onready var _tutorial_indicator: Node2D = get_node_or_null("TutorialIndicator") as Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("phones")
	_action_hint_text = INPUT_HINT_UTIL.resolve_action_hint(interact_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D
	if _tutorial_button != null and not _tutorial_button.pressed.is_connected(_on_tutorial_button_pressed):
		_tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	if _tutorial_lootboxes_button != null and not _tutorial_lootboxes_button.pressed.is_connected(_on_tutorial_lootboxes_pressed):
		_tutorial_lootboxes_button.pressed.connect(_on_tutorial_lootboxes_pressed)
	if _tutorial_controls_button != null and not _tutorial_controls_button.pressed.is_connected(_on_tutorial_controls_pressed):
		_tutorial_controls_button.pressed.connect(_on_tutorial_controls_pressed)
	if _tutorial_summons_button != null and not _tutorial_summons_button.pressed.is_connected(_on_tutorial_summons_pressed):
		_tutorial_summons_button.pressed.connect(_on_tutorial_summons_pressed)
	if _tutorial_day_night_button != null and not _tutorial_day_night_button.pressed.is_connected(_on_tutorial_day_night_pressed):
		_tutorial_day_night_button.pressed.connect(_on_tutorial_day_night_pressed)
	if _tutorial_back_button != null and not _tutorial_back_button.pressed.is_connected(_on_tutorial_back_pressed):
		_tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
	if _tutorial_dialog != null:
		var tutorial_label: Label = _tutorial_dialog.get_label()
		if tutorial_label != null:
			tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _tutorial_indicator != null:
		_indicator_base_position = _tutorial_indicator.position
	_set_dialog_open(false)
	_set_tutorial_menu_open(false)
	_update_indicator_visibility()
	_update_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_update_tutorial_indicator(delta)
	_reopen_block_time_left = maxf(_reopen_block_time_left - delta, 0.0)

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
	_begin_reopen_block()
	get_viewport().set_input_as_handled()

func interact(_player: Node2D) -> void:
	if _reopen_block_time_left > 0.0:
		return

	if _dialog_open:
		_set_dialog_open(false)
		_begin_reopen_block()
		return

	if not _tutorial_complete:
		_tutorial_complete = true
		_update_indicator_visibility()
		emit_signal("first_phone_interaction_completed")

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
	if not should_open:
		_set_tutorial_menu_open(false)
		if _tutorial_dialog != null:
			_tutorial_dialog.hide()
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
	_set_tutorial_menu_open(true)


func _on_tutorial_back_pressed() -> void:
	_set_tutorial_menu_open(false)


func _on_tutorial_lootboxes_pressed() -> void:
	_show_tutorial_topic(
		"Lootboxes",
		"Get lootboxes by harvesting around your base and from objectives. Pick them up, then use them to roll new summons.\n\nSee your boxes on the hotbar and drag them onto the screen to throw them.\n\nMake sure you have some summmons out before night comes, as they are your only defense against ict ncoming waves.\n\nFor more information on the lootboxes and how to get them open the Bestiary with 'B'"
	)


func _on_tutorial_controls_pressed() -> void:
	_show_tutorial_topic(
		"Controls + Throwing",
		"Movement is through WASD, and you can interact with things in the world by pressing 'E'. Use your mouse on your hotbar to select a lootbox, then drag from the hotbar toward the world to throw it where you want.\n\nThrowing lets you place summons quickly during combat, and also lets you plant saplings in the planters near your house.\n\nTry picking up and planting the provided saplings now."
	)


func _on_tutorial_summons_pressed() -> void:
	var hold_hint: String = INPUT_HINT_UTIL.resolve_action_hint(&"summon_command_hold")
	var follow_hint: String = INPUT_HINT_UTIL.resolve_action_hint(&"summon_command_follow")
	var auto_hint: String = INPUT_HINT_UTIL.resolve_action_hint(&"summon_command_auto")
	_show_tutorial_topic(
		"Summon Commands",
		"Select summons by holding middle mouse and dragging.\n\nUse 'H'' to toggle Hold, 'F' to command Follow, and 'R' to return selected summons to Auto behavior. Mix these modes to coordinate your defense and adapt to incoming waves.\n\nCheck the Bestiary with 'B' to see tips on maximizing each summons' effectiveness."
	)


func _on_tutorial_day_night_pressed() -> void:
	_show_tutorial_topic(
		"Day/Night Loop",
		"Day is your setup window: harvest resources, open boxes, and prepare your summons. Night brings enemy waves that scale up over time.\n\nUse the phone for info about upcoming wave composition and time remaining until nightfall. Surviving each night keeps your run alive.\n\nGood Luck!"
	)


func _show_tutorial_topic(title: String, body: String) -> void:
	if _tutorial_dialog == null:
		return
	_tutorial_dialog.title = title
	_tutorial_dialog.dialog_text = body
	_tutorial_dialog.popup_centered()


func _set_tutorial_menu_open(should_open: bool) -> void:
	if _tutorial_menu_panel == null:
		return
	_tutorial_menu_panel.visible = should_open


func _begin_reopen_block() -> void:
	_reopen_block_time_left = maxf(reopen_block_seconds, 0.0)


func _update_tutorial_indicator(delta: float) -> void:
	if _tutorial_indicator == null:
		return
	if _tutorial_complete:
		return

	_indicator_time += delta * indicator_bob_speed
	var bob_offset: float = sin(_indicator_time) * indicator_bob_amplitude
	_tutorial_indicator.position = _indicator_base_position + Vector2(0.0, bob_offset)


func _update_indicator_visibility() -> void:
	if _tutorial_indicator == null:
		return
	_tutorial_indicator.visible = not _tutorial_complete


func has_completed_intro_interaction() -> bool:
	return _tutorial_complete


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
	var minutes: int = int(time_remaining / 60.0)
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
