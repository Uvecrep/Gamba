extends CanvasLayer

@onready var _pause_badge: Control = get_node_or_null("PauseBadge") as Control
@onready var _backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
@onready var _menu_panel: PanelContainer = get_node_or_null("EscapeMenuPanel") as PanelContainer
@onready var _settings_panel: PanelContainer = get_node_or_null("SettingsPanel") as PanelContainer
@onready var _resume_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/ResumeButton") as Button
@onready var _bestiary_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/BestiaryButton") as Button
@onready var _settings_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/SettingsButton") as Button
@onready var _quit_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/QuitButton") as Button
@onready var _settings_back_button: Button = get_node_or_null("SettingsPanel/MarginContainer/VBoxContainer/BackButton") as Button

var _is_escape_menu_open: bool = false
var _is_settings_open: bool = false
var _menu_pause_active: bool = false
var _paused_before_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _resume_button != null:
		_resume_button.pressed.connect(_on_resume_pressed)
	if _bestiary_button != null:
		_bestiary_button.pressed.connect(_on_bestiary_pressed)
	if _settings_button != null:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _quit_button != null:
		_quit_button.pressed.connect(_on_quit_pressed)
	if _settings_back_button != null:
		_settings_back_button.pressed.connect(_on_settings_back_pressed)

	_set_escape_menu_open(false)


func _process(_delta: float) -> void:
	_sync_pause_state()
	if _pause_badge != null:
		_pause_badge.visible = _is_any_pause_menu_open()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return

	if _is_escape_menu_open:
		_set_escape_menu_open(false)
		get_viewport().set_input_as_handled()
		return

	if _is_any_non_escape_menu_open():
		return

	_set_escape_menu_open(true)
	get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	_set_escape_menu_open(false)


func _on_bestiary_pressed() -> void:
	_set_escape_menu_open(false)
	var panels: Array = get_tree().get_nodes_in_group("bestiary_panels")
	for panel in panels:
		if panel != null and panel.has_method("set_panel_open"):
			panel.call("set_panel_open", true)
			return


func _on_settings_pressed() -> void:
	_is_settings_open = true
	_update_menu_visibility()
	if _settings_back_button != null:
		_settings_back_button.grab_focus()


func _on_settings_back_pressed() -> void:
	_is_settings_open = false
	_update_menu_visibility()
	if _resume_button != null:
		_resume_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _set_escape_menu_open(open: bool) -> void:
	_is_escape_menu_open = open
	if not open:
		_is_settings_open = false
	_update_menu_visibility()

	if _is_escape_menu_open and _resume_button != null:
		_resume_button.grab_focus()


func _update_menu_visibility() -> void:
	if _backdrop != null:
		_backdrop.visible = _is_escape_menu_open
	if _menu_panel != null:
		_menu_panel.visible = _is_escape_menu_open and not _is_settings_open
	if _settings_panel != null:
		_settings_panel.visible = _is_escape_menu_open and _is_settings_open


func _sync_pause_state() -> void:
	var should_pause: bool = _is_any_pause_menu_open()
	if should_pause and not _menu_pause_active:
		_paused_before_menu = get_tree().paused
		get_tree().paused = true
		_menu_pause_active = true
	elif not should_pause and _menu_pause_active:
		get_tree().paused = _paused_before_menu
		_menu_pause_active = false


func _is_any_pause_menu_open() -> bool:
	if _is_escape_menu_open:
		return true
	if _is_any_shop_open():
		return true
	if _is_any_phone_open():
		return true
	if _is_any_bestiary_open():
		return true
	return false


func _is_any_non_escape_menu_open() -> bool:
	if _is_any_map_open():
		return true
	if _is_any_shop_open():
		return true
	if _is_any_phone_open():
		return true
	if _is_any_bestiary_open():
		return true
	return false


func _is_any_shop_open() -> bool:
	var shops: Array = get_tree().get_nodes_in_group("shops")
	for shop in shops:
		if shop != null and shop.has_method("is_shop_open") and bool(shop.call("is_shop_open")):
			return true
	return false


func _is_any_phone_open() -> bool:
	var phones: Array = get_tree().get_nodes_in_group("phones")
	for phone in phones:
		if phone != null and phone.has_method("is_dialog_open") and bool(phone.call("is_dialog_open")):
			return true
	return false


func _is_any_bestiary_open() -> bool:
	var panels: Array = get_tree().get_nodes_in_group("bestiary_panels")
	for panel in panels:
		if panel != null and panel.has_method("is_panel_open") and bool(panel.call("is_panel_open")):
			return true
	return false


func _is_any_map_open() -> bool:
	var maps: Array = get_tree().get_nodes_in_group("maps")
	for map_node in maps:
		if map_node != null and map_node.has_method("is_map_open") and bool(map_node.call("is_map_open")):
			return true
	return false