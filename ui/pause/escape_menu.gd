extends CanvasLayer

@onready var _pause_badge: Control = get_node_or_null("PauseBadge") as Control
@onready var _backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
@onready var _menu_panel: PanelContainer = get_node_or_null("EscapeMenuPanel") as PanelContainer
@onready var _settings_panel: PanelContainer = get_node_or_null("SettingsPanel") as PanelContainer
@onready var _resume_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/ResumeButton") as Button
@onready var _bestiary_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/BestiaryButton") as Button
@onready var _settings_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/SettingsButton") as Button
@onready var _quit_to_menu_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/QuitToMenuButton") as Button
@onready var _quit_button: Button = get_node_or_null("EscapeMenuPanel/MarginContainer/VBoxContainer/QuitButton") as Button
@onready var _settings_back_button: Button = get_node_or_null("SettingsPanel/MarginContainer/VBoxContainer/BackButton") as Button
@onready var _settings_vbox: VBoxContainer = get_node_or_null("SettingsPanel/MarginContainer/VBoxContainer") as VBoxContainer
@onready var _settings_body_label: Label = get_node_or_null("SettingsPanel/MarginContainer/VBoxContainer/BodyLabel") as Label

var _is_escape_menu_open: bool = false
var _is_settings_open: bool = false
var _is_audio_debug_open: bool = false
var _menu_pause_active: bool = false
var _paused_before_menu: bool = false
var _audio_debug_panel: PanelContainer
var _audio_debug_label: RichTextLabel
var _audio_debug_grant_gold_button: Button
var _audio_debug_damage_house_button: Button
var _bus_sliders: Dictionary = {}
var _bus_value_labels: Dictionary = {}

const SETTINGS_AUDIO_BUSES: PackedStringArray = ["Master", "Music", "Ambience", "SFX", "UI"]
const BUS_MIN_PCT: float = 0.0
const BUS_MAX_PCT: float = 100.0
const BUS_DEFAULT_PCT: Dictionary = {
	"Master": 100.0,
	"Music": 50.0,
	"Ambience": 50.0,
	"SFX": 50.0,
	"UI": 50.0,
}
const AUDIO_SETTINGS_PATH: String = "user://settings.cfg"
const AUDIO_SETTINGS_SECTION: String = "audio"
const AUDIO_DEBUG_GOLD_GRANT_AMOUNT: int = 100
const AUDIO_DEBUG_HOUSE_DAMAGE_FRACTION: float = 0.25


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_debug_overlay()
	_setup_audio_settings_controls()
	if _resume_button != null:
		_resume_button.pressed.connect(_on_resume_pressed)
	if _bestiary_button != null:
		_bestiary_button.pressed.connect(_on_bestiary_pressed)
	if _settings_button != null:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _quit_to_menu_button != null:
		_quit_to_menu_button.pressed.connect(_on_quit_to_menu_pressed)
	if _quit_button != null:
		_quit_button.pressed.connect(_on_quit_pressed)
	if _settings_back_button != null:
		_settings_back_button.pressed.connect(_on_settings_back_pressed)

	_load_audio_settings()
	_refresh_audio_settings_controls()
	_set_escape_menu_open(false)


func _process(_delta: float) -> void:
	_sync_pause_state()
	if _pause_badge != null:
		_pause_badge.visible = _is_any_pause_menu_open()
	_refresh_audio_debug_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F12:
			_is_audio_debug_open = not _is_audio_debug_open
			if _audio_debug_panel != null:
				_audio_debug_panel.visible = _is_audio_debug_open
			get_viewport().set_input_as_handled()
			return

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
	_refresh_audio_settings_controls()
	_update_menu_visibility()
	if _settings_back_button != null:
		_settings_back_button.grab_focus()


func _on_settings_back_pressed() -> void:
	_is_settings_open = false
	_update_menu_visibility()
	if _resume_button != null:
		_resume_button.grab_focus()


func _on_quit_to_menu_pressed() -> void:
	Audio.stop_all_playback()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")


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
		Audio.set_sfx_paused(true)
		get_tree().paused = true
		_menu_pause_active = true
	elif not should_pause and _menu_pause_active:
		Audio.set_sfx_paused(false)
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


func _setup_audio_debug_overlay() -> void:
	_audio_debug_panel = PanelContainer.new()
	_audio_debug_panel.name = "AudioDebugOverlay"
	_audio_debug_panel.visible = false
	_audio_debug_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_audio_debug_panel.anchors_preset = Control.PRESET_CENTER_RIGHT
	_audio_debug_panel.anchor_left = 1.0
	_audio_debug_panel.anchor_right = 1.0
	_audio_debug_panel.anchor_top = 0.5
	_audio_debug_panel.anchor_bottom = 0.5
	_audio_debug_panel.offset_left = -520.0
	_audio_debug_panel.offset_top = -210.0
	_audio_debug_panel.offset_right = -24.0
	_audio_debug_panel.offset_bottom = 210.0
	add_child(_audio_debug_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_audio_debug_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	_audio_debug_label = RichTextLabel.new()
	_audio_debug_label.bbcode_enabled = false
	_audio_debug_label.fit_content = false
	_audio_debug_label.scroll_active = true
	_audio_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_audio_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio_debug_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_audio_debug_label)

	var button_row := HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)

	_audio_debug_grant_gold_button = Button.new()
	_audio_debug_grant_gold_button.text = "Grant 100 Gold"
	_audio_debug_grant_gold_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_debug_grant_gold_button.pressed.connect(_on_audio_debug_grant_gold_pressed)
	button_row.add_child(_audio_debug_grant_gold_button)

	_audio_debug_damage_house_button = Button.new()
	_audio_debug_damage_house_button.text = "Damage House 25%"
	_audio_debug_damage_house_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_debug_damage_house_button.pressed.connect(_on_audio_debug_damage_house_pressed)
	button_row.add_child(_audio_debug_damage_house_button)


func _refresh_audio_debug_overlay() -> void:
	if _audio_debug_panel == null or _audio_debug_label == null:
		return
	if not _audio_debug_panel.visible:
		return

	var audio_service: Node = get_node_or_null("/root/Audio")
	if audio_service == null or not audio_service.has_method("get_currently_playing_sounds"):
		_audio_debug_label.text = "Audio Debug\nAudio service unavailable."
		return

	var playing: Variant = audio_service.call("get_currently_playing_sounds")
	if not (playing is Array):
		_audio_debug_label.text = "Audio Debug\nUnexpected audio debug payload."
		return

	var lines: PackedStringArray = []
	var sound_entries: Array = playing as Array
	lines.append("Audio Debug")
	lines.append("Overlay: F12 toggled")
	lines.append("Escape menu open: %s" % str(_is_escape_menu_open))
	lines.append("Now playing: %d" % sound_entries.size())
	lines.append("------------------------------")

	for entry in sound_entries:
		if not (entry is Dictionary):
			continue
		var sound_info: Dictionary = entry as Dictionary
		var kind: String = String(sound_info.get("kind", "unknown"))
		var key: String = String(sound_info.get("key", ""))
		var bus_name: String = String(sound_info.get("bus", ""))
		var volume_db: float = float(sound_info.get("volume_db", 0.0))
		var pitch_scale: float = float(sound_info.get("pitch_scale", 1.0))
		if key == "":
			key = "<unknown_key>"
		lines.append("%s | %s" % [kind, key])
		lines.append("  bus=%s  vol=%.1f dB  pitch=%.2f" % [bus_name, volume_db, pitch_scale])

	_audio_debug_label.text = "\n".join(lines)


func _on_audio_debug_grant_gold_pressed() -> void:
	var players: Array = get_tree().get_nodes_in_group("players")
	for player_node in players:
		if not (player_node is Player):
			continue

		var player: Player = player_node as Player
		if player == null or player.player_inventory == null:
			continue

		player.player_inventory.add_gold(AUDIO_DEBUG_GOLD_GRANT_AMOUNT)
		Audio.play_ui(&"ui_button_click")
		return

	Audio.play_ui(&"ui_inventory_invalid")


func _on_audio_debug_damage_house_pressed() -> void:
	var houses: Array = get_tree().get_nodes_in_group("house")
	for house_node in houses:
		if not (house_node is House):
			continue

		var house: House = house_node as House
		if house == null:
			continue

		house.take_damage(maxf(house.max_health * AUDIO_DEBUG_HOUSE_DAMAGE_FRACTION, 1.0))
		Audio.play_ui(&"ui_button_click")
		return

	Audio.play_ui(&"ui_inventory_invalid")


func is_audio_debug_open() -> bool:
	return _is_audio_debug_open


func _setup_audio_settings_controls() -> void:
	if _settings_vbox == null:
		return

	if _settings_body_label != null:
		_settings_body_label.visible = false

	var insert_index: int = 0
	if _settings_body_label != null:
		insert_index = _settings_body_label.get_index() + 1

	for bus_name in SETTINGS_AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			continue

		var row := HBoxContainer.new()
		row.name = "%sVolumeRow" % bus_name
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)

		var name_label := Label.new()
		name_label.text = "%s" % bus_name
		name_label.custom_minimum_size = Vector2(82.0, 0.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)

		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(150.0, 0.0)
		slider.min_value = BUS_MIN_PCT
		slider.max_value = BUS_MAX_PCT
		slider.step = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_bus_slider_changed.bind(bus_name))
		row.add_child(slider)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(72.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		_settings_vbox.add_child(row)
		_settings_vbox.move_child(row, insert_index)
		insert_index += 1

		_bus_sliders[bus_name] = slider
		_bus_value_labels[bus_name] = value_label

	_refresh_audio_settings_controls()


func _refresh_audio_settings_controls() -> void:
	for bus_name in _bus_sliders.keys():
		var bus_index: int = AudioServer.get_bus_index(String(bus_name))
		if bus_index < 0:
			continue

		var slider: HSlider = _bus_sliders[bus_name] as HSlider
		if slider == null:
			continue

		var volume_db: float = AudioServer.get_bus_volume_db(bus_index)
		var pct: float = clampf(db_to_linear(volume_db) * 100.0, BUS_MIN_PCT, BUS_MAX_PCT)
		slider.set_value_no_signal(pct)
		_update_bus_value_label(String(bus_name), pct)


func _on_bus_slider_changed(value: float, bus_name: String) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	var db: float = -80.0 if value <= 0.0 else linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(bus_index, db)
	_update_bus_value_label(bus_name, value)
	_save_audio_settings()


func _save_audio_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	for bus_name: String in SETTINGS_AUDIO_BUSES:
		var slider: HSlider = _bus_sliders.get(bus_name, null) as HSlider
		if slider == null:
			continue
		config.set_value(AUDIO_SETTINGS_SECTION, bus_name, slider.value)
	config.save(AUDIO_SETTINGS_PATH)


func _load_audio_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(AUDIO_SETTINGS_PATH) != OK:
		_apply_default_audio_settings()
		return
	for bus_name: String in SETTINGS_AUDIO_BUSES:
		var pct: float = config.get_value(AUDIO_SETTINGS_SECTION, bus_name,
				BUS_DEFAULT_PCT.get(bus_name, 100.0))
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		var db: float = -80.0 if pct <= 0.0 else linear_to_db(pct / 100.0)
		AudioServer.set_bus_volume_db(bus_index, db)


func _apply_default_audio_settings() -> void:
	for bus_name: String in SETTINGS_AUDIO_BUSES:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		var pct: float = BUS_DEFAULT_PCT.get(bus_name, 100.0)
		var db: float = -80.0 if pct <= 0.0 else linear_to_db(pct / 100.0)
		AudioServer.set_bus_volume_db(bus_index, db)


func _update_bus_value_label(bus_name: String, value: float) -> void:
	var label: Label = _bus_value_labels.get(bus_name, null) as Label
	if label == null:
		return
	label.text = "%d%%" % int(value)