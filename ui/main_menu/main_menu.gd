extends Control

@onready var _main_panel: PanelContainer = get_node_or_null("MainMenuPanel") as PanelContainer
@onready var _settings_panel: PanelContainer = get_node_or_null("SettingsPanel") as PanelContainer
@onready var _credits_panel: PanelContainer = get_node_or_null("CreditsPanel") as PanelContainer

@onready var _play_button: Button = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer/PlayButton") as Button
@onready var _settings_button: Button = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer/SettingsButton") as Button
@onready var _credits_button: Button = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer/CreditsButton") as Button
@onready var _quit_button: Button = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer/QuitButton") as Button

@onready var _settings_back_button: Button = get_node_or_null("SettingsPanel/MarginContainer/VBoxContainer/BackButton") as Button
@onready var _settings_vbox: VBoxContainer = get_node_or_null("SettingsPanel/MarginContainer/VBoxContainer") as VBoxContainer

@onready var _credits_back_button: Button = get_node_or_null("CreditsPanel/MarginContainer/VBoxContainer/BackButton") as Button

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

var _bus_sliders: Dictionary = {}
var _bus_value_labels: Dictionary = {}


func _ready() -> void:
	get_tree().paused = false
	Audio.play_music(&"music_main_menu")
	_setup_audio_settings_controls()
	if _play_button != null:
		_play_button.pressed.connect(_on_play_pressed)
	if _settings_button != null:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _credits_button != null:
		_credits_button.pressed.connect(_on_credits_pressed)
	if _quit_button != null:
		_quit_button.pressed.connect(_on_quit_pressed)
	if _settings_back_button != null:
		_settings_back_button.pressed.connect(_on_settings_back_pressed)
	if _credits_back_button != null:
		_credits_back_button.pressed.connect(_on_credits_back_pressed)

	_load_audio_settings()
	_refresh_audio_settings_controls()
	_show_panel(&"main")
	if _play_button != null:
		_play_button.grab_focus()


func _on_play_pressed() -> void:
	Audio.play_ui(&"ui_button_click")
	get_tree().change_scene_to_file("res://levels/main.tscn")


func _on_settings_pressed() -> void:
	Audio.play_ui(&"ui_button_click")
	_refresh_audio_settings_controls()
	_show_panel(&"settings")
	if _settings_back_button != null:
		_settings_back_button.grab_focus()


func _on_credits_pressed() -> void:
	Audio.play_ui(&"ui_button_click")
	_show_panel(&"credits")
	if _credits_back_button != null:
		_credits_back_button.grab_focus()


func _on_quit_pressed() -> void:
	Audio.play_ui(&"ui_button_click")
	get_tree().quit()


func _on_settings_back_pressed() -> void:
	Audio.play_ui(&"ui_button_click")
	_show_panel(&"main")
	if _settings_button != null:
		_settings_button.grab_focus()


func _on_credits_back_pressed() -> void:
	Audio.play_ui(&"ui_button_click")
	_show_panel(&"main")
	if _credits_button != null:
		_credits_button.grab_focus()


func _show_panel(panel_name: StringName) -> void:
	if _main_panel != null:
		_main_panel.visible = (panel_name == &"main")
	if _settings_panel != null:
		_settings_panel.visible = (panel_name == &"settings")
	if _credits_panel != null:
		_credits_panel.visible = (panel_name == &"credits")


func _setup_audio_settings_controls() -> void:
	if _settings_vbox == null:
		return

	# Insert audio rows after TitleLabel (index 0), before BackButton
	var insert_index: int = 1

	for bus_name: String in SETTINGS_AUDIO_BUSES:
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


func _refresh_audio_settings_controls() -> void:
	for bus_name: String in _bus_sliders.keys():
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue

		var slider: HSlider = _bus_sliders[bus_name] as HSlider
		if slider == null:
			continue

		var volume_db: float = AudioServer.get_bus_volume_db(bus_index)
		var pct: float = clampf(db_to_linear(volume_db) * 100.0, BUS_MIN_PCT, BUS_MAX_PCT)
		slider.set_value_no_signal(pct)
		_update_bus_value_label(bus_name, pct)


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
