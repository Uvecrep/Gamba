extends Control

@export var box_sprites: Array[Texture2D]

@onready var _main_panel: PanelContainer = get_node_or_null("MainMenuPanel") as PanelContainer
@onready var _settings_panel: PanelContainer = get_node_or_null("SettingsPanel") as PanelContainer
@onready var _credits_panel: PanelContainer = get_node_or_null("CreditsPanel") as PanelContainer

@onready var _play_button: Button = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer/PlayButton") as Button
@onready var _settings_button: Button = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer/SettingsButton") as Button
@onready var _credits_button: Button = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer/CreditsButton") as Button
@onready var _quit_button: Button = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer/QuitButton") as Button

@onready var _settings_back_button: Button = get_node_or_null("SettingsPanel/MarginContainer/VBoxContainer/BackButton") as Button
@onready var _settings_vbox: VBoxContainer = get_node_or_null("SettingsPanel/MarginContainer/VBoxContainer") as VBoxContainer
@onready var _main_menu_vbox: VBoxContainer = get_node_or_null("MainMenuPanel/MarginContainer/VBoxContainer") as VBoxContainer

@onready var _credits_back_button: Button = get_node_or_null("CreditsPanel/MarginContainer/VBoxContainer/BackButton") as Button

var spawned_boxes: Array[TextureRect]
var spawned_box_rotation_speed: Array[float]
var spawned_box_speed: Array[float]

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
const MAIN_MENU_SETTINGS_SECTION: String = "main_menu"
const GAMBLE_MODE_KEY: String = "gamble_mode"

const GAMBLE_BUTTON_TEXT: String = "I'm Feeling Lucky"
const GAMBLE_SETTINGS_LABEL_TEXT: String = "Gamble Mode"
const ROULETTE_BASE_TICK_DELAY: float = 0.05
const ROULETTE_END_DELAY_STEP: float = 0.02
const ROULETTE_END_SLOWDOWN_STEPS: int = 6
const GAMBLE_LAND_HOLD_SECONDS: float = 1.0
const GAMBLE_PULSE_SCALE: Vector2 = Vector2(1.05, 1.05)
const GAMBLE_PULSE_STEP_SECONDS: float = 0.2
const GAMBLE_SHAKE_MAX_PIXELS: float = 3.0
const GAMBLE_SHAKE_STEP_SECONDS: float = 0.05
const GAMBLE_SHAKE_DURATION_SECONDS: float = 0.35
const GAMBLE_OUTCOME_SOUND_DELAY_SECONDS: float = 0.2
const GAMBLE_CREDITS_DELAY_MULTIPLIER: float = 0.5
const GAMBLE_QUIT_SOUND_PATH: String = "res://assets/sounds/world/game_over_stinger.ogg"
const GAMBLE_QUIT_SOUND_FALLBACK_SECONDS: float = 1.5
const GAMBLE_CREDITS_SOUND_PATH: String = "res://assets/sounds/ui/bestiary_new_entry.ogg"
const GAMBLE_CREDITS_SOUND_FALLBACK_SECONDS: float = 1.0
const GAMBLE_NEW_GAME_SOUND_PATH: String = "res://assets/sounds/ui/lootbox_reward_cue.ogg"
const GAMBLE_NEW_GAME_SOUND_FALLBACK_SECONDS: float = 0.8

var _bus_sliders: Dictionary = {}
var _bus_value_labels: Dictionary = {}
var _gamble_button: Button
var _gamble_mode_toggle: CheckButton
var _gamble_mode_enabled: bool = true
var _is_gamble_spinning: bool = false
var _main_menu_mouse_locked: bool = false


func _ready() -> void:
	get_tree().paused = false
	randomize()
	Audio.play_music(&"music_main_menu")
	_setup_audio_settings_controls()
	_setup_gamble_mode_controls()
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

	_load_settings()
	_refresh_audio_settings_controls()
	_refresh_gamble_controls()
	_show_panel(&"main")
	if _play_button != null:
		_play_button.grab_focus()
	
	_spawn_inital_boxes()

func _process(_delta: float) -> void:
	for i in range(spawned_boxes.size()):
		var box: TextureRect = spawned_boxes[i]
		box.position.y += spawned_box_speed[i]
		if box.position.y > get_viewport_rect().size.y + 64:
			box.position = _random_box_start_pos()
		box.rotation += spawned_box_rotation_speed[i]
	

func _spawn_inital_boxes() -> void:
	for i in range(25):
		var new_box: TextureRect = TextureRect.new()
		new_box.texture = box_sprites[randi_range(0,box_sprites.size()-1)]
		new_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		new_box.size = Vector2(64,64)
		new_box.position = _random_box_start_pos()
		new_box.pivot_offset = Vector2(32,32)
		add_child(new_box)
		move_child(new_box,1)
		spawned_boxes.append(new_box)
		spawned_box_speed.append(5)
		spawned_box_rotation_speed.append(.1 + randf_range(-1,1)*0.02)
	
func _random_box_start_pos() -> Vector2:
	return Vector2(randf() * get_viewport_rect().size.x,-1 * randf() * get_viewport_rect().size.y - 64)

func _on_play_pressed() -> void:
	if _is_gamble_spinning:
		return
	_start_new_game()


func _on_settings_pressed() -> void:
	if _is_gamble_spinning:
		return
	Audio.play_ui(&"ui_button_click")
	_refresh_audio_settings_controls()
	_show_panel(&"settings")
	if _settings_back_button != null:
		_settings_back_button.grab_focus()


func _on_credits_pressed() -> void:
	if _is_gamble_spinning:
		return
	Audio.play_ui(&"ui_button_click")
	_show_panel(&"credits")
	if _credits_back_button != null:
		_credits_back_button.grab_focus()


func _on_quit_pressed() -> void:
	if _is_gamble_spinning:
		return
	_quit_game()


func _start_new_game() -> void:
	Audio.play_ui(&"ui_button_click")
	Audio.stop_music()
	get_tree().change_scene_to_file("res://levels/main.tscn")


func _quit_game() -> void:
	Audio.play_ui(&"ui_button_click")
	get_tree().quit()


func _on_gamble_pressed() -> void:
	if _is_gamble_spinning:
		return
	if _gamble_button == null or _main_menu_vbox == null:
		return

	Audio.play_ui(&"ui_button_click")
	_is_gamble_spinning = true
	_set_main_menu_mouse_interaction_enabled(false)

	var roulette_buttons: Array[Button] = _get_visible_main_menu_buttons()
	if roulette_buttons.is_empty():
		_set_main_menu_mouse_interaction_enabled(true)
		_is_gamble_spinning = false
		return

	var roll: int = randi() % 3
	var target_button: Button = _play_button
	if roll == 1:
		target_button = _quit_button
	elif roll == 2:
		target_button = _credits_button
	if target_button == null:
		target_button = _play_button if _play_button != null else _quit_button
	if target_button == null:
		target_button = _credits_button
	if target_button == null:
		_set_main_menu_mouse_interaction_enabled(true)
		_is_gamble_spinning = false
		return

	var current_index: int = 0
	var target_index: int = roulette_buttons.find(target_button)
	if target_index < 0:
		target_index = roulette_buttons.find(_play_button)
	if target_index < 0:
		target_index = roulette_buttons.find(_quit_button)
	if target_index < 0:
		target_index = roulette_buttons.find(_credits_button)
	if target_index < 0:
		target_index = 0

	var spin_steps: int = 18 + randi() % 9
	spin_steps += (target_index - (spin_steps % roulette_buttons.size()) + roulette_buttons.size()) % roulette_buttons.size()

	for step_index in range(spin_steps):
		if roulette_buttons.is_empty():
			break
		var selected_button: Button = roulette_buttons[current_index]
		if selected_button != null:
			selected_button.grab_focus()
		Audio.play_ui_tick_throttled(25)

		var delay: float = ROULETTE_BASE_TICK_DELAY
		if step_index >= spin_steps - ROULETTE_END_SLOWDOWN_STEPS:
			delay += ROULETTE_END_DELAY_STEP * float(step_index - (spin_steps - ROULETTE_END_SLOWDOWN_STEPS) + 1)
		await get_tree().create_timer(delay).timeout
		current_index = (current_index + 1) % roulette_buttons.size()

	var outcome_sound_seconds: float = 0.0
	var credits_total_delay_seconds: float = 0.0
	if target_button == _quit_button:
		Audio.play_sfx(&"world_game_over", -6.0)
		outcome_sound_seconds = _get_audio_stream_length_seconds(
				GAMBLE_QUIT_SOUND_PATH,
				GAMBLE_QUIT_SOUND_FALLBACK_SECONDS
		)
	elif target_button == _credits_button:
		Audio.play_ui(&"ui_bestiary_new", -3.0)
		outcome_sound_seconds = _get_audio_stream_length_seconds(
				GAMBLE_CREDITS_SOUND_PATH,
				GAMBLE_CREDITS_SOUND_FALLBACK_SECONDS
		)
		credits_total_delay_seconds = maxf(GAMBLE_LAND_HOLD_SECONDS, outcome_sound_seconds) * GAMBLE_CREDITS_DELAY_MULTIPLIER
	else:
		Audio.play_ui(&"ui_lootbox_reward", -3.0)
		outcome_sound_seconds = _get_audio_stream_length_seconds(
				GAMBLE_NEW_GAME_SOUND_PATH,
				GAMBLE_NEW_GAME_SOUND_FALLBACK_SECONDS
		)

	var outcome_start_msec: int = Time.get_ticks_msec()
	await _play_gamble_landing_fx(target_button)
	var elapsed_after_fx_seconds: float = float(Time.get_ticks_msec() - outcome_start_msec) / 1000.0

	if target_button == _quit_button:
		var quit_remaining_seconds: float = maxf(0.0, outcome_sound_seconds - elapsed_after_fx_seconds)
		if quit_remaining_seconds > 0.0:
			await get_tree().create_timer(quit_remaining_seconds).timeout
		_is_gamble_spinning = false
		get_tree().quit()
		return

	if target_button == _credits_button:
		var credits_remaining_seconds: float = maxf(0.0, credits_total_delay_seconds - elapsed_after_fx_seconds)
		if credits_remaining_seconds > 0.0:
			await get_tree().create_timer(credits_remaining_seconds).timeout
		_is_gamble_spinning = false
		_on_credits_pressed()
		_set_main_menu_mouse_interaction_enabled(true)
		return

	var new_game_delay_seconds: float = maxf(GAMBLE_OUTCOME_SOUND_DELAY_SECONDS, outcome_sound_seconds)
	var new_game_remaining_seconds: float = maxf(0.0, new_game_delay_seconds - elapsed_after_fx_seconds)
	if new_game_remaining_seconds > 0.0:
		await get_tree().create_timer(new_game_remaining_seconds).timeout
	_is_gamble_spinning = false
	_set_main_menu_mouse_interaction_enabled(true)
	_start_new_game()


func _play_gamble_landing_fx(target_button: Button) -> void:
	if target_button == null:
		return
	target_button.grab_focus()

	var pulse_tween: Tween = create_tween()
	pulse_tween.set_loops(2)
	pulse_tween.tween_property(target_button, "scale", GAMBLE_PULSE_SCALE, GAMBLE_PULSE_STEP_SECONDS)
	pulse_tween.tween_property(target_button, "scale", Vector2.ONE, GAMBLE_PULSE_STEP_SECONDS)

	var shake_time_left: float = GAMBLE_SHAKE_DURATION_SECONDS
	var base_position: Vector2 = _main_panel.position if _main_panel != null else Vector2.ZERO
	while shake_time_left > 0.0:
		if _main_panel != null:
			var t: float = 1.0 - (shake_time_left / GAMBLE_SHAKE_DURATION_SECONDS)
			var strength: float = lerpf(GAMBLE_SHAKE_MAX_PIXELS, 0.0, t)
			_main_panel.position = base_position + Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength)
			)
		await get_tree().create_timer(GAMBLE_SHAKE_STEP_SECONDS).timeout
		shake_time_left -= GAMBLE_SHAKE_STEP_SECONDS

	if _main_panel != null:
		_main_panel.position = base_position

	if pulse_tween != null:
		pulse_tween.kill()
	target_button.scale = Vector2.ONE


func _get_audio_stream_length_seconds(path: String, fallback_seconds: float) -> float:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return fallback_seconds
	var length: float = stream.get_length()
	if length <= 0.0:
		return fallback_seconds
	return length


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


func _setup_gamble_mode_controls() -> void:
	if _main_menu_vbox != null:
		_gamble_button = Button.new()
		_gamble_button.name = "GambleButton"
		_gamble_button.text = GAMBLE_BUTTON_TEXT
		_gamble_button.visible = false
		_gamble_button.pressed.connect(_on_gamble_pressed)
		_main_menu_vbox.add_child(_gamble_button)
		_main_menu_vbox.move_child(_gamble_button, 0)

	if _settings_vbox != null:
		var row := HBoxContainer.new()
		row.name = "GambleModeRow"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)

		var name_label := Label.new()
		name_label.text = GAMBLE_SETTINGS_LABEL_TEXT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)

		_gamble_mode_toggle = CheckButton.new()
		_gamble_mode_toggle.text = ""
		_gamble_mode_toggle.toggled.connect(_on_gamble_mode_toggled)
		row.add_child(_gamble_mode_toggle)

		_settings_vbox.add_child(row)
		var back_index: int = max(0, _settings_vbox.get_child_count() - 2)
		_settings_vbox.move_child(row, back_index)


func _refresh_gamble_controls() -> void:
	if _gamble_mode_toggle != null:
		_gamble_mode_toggle.set_pressed_no_signal(_gamble_mode_enabled)
	if _gamble_button != null:
		_gamble_button.visible = _gamble_mode_enabled


func _on_gamble_mode_toggled(enabled: bool) -> void:
	_gamble_mode_enabled = enabled
	_refresh_gamble_controls()
	_save_settings()


func _get_visible_main_menu_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	if _main_menu_vbox == null:
		return buttons
	for child in _main_menu_vbox.get_children():
		var button: Button = child as Button
		if button == null or not button.visible:
			continue
		buttons.append(button)
	return buttons


func _set_main_menu_mouse_interaction_enabled(enabled: bool) -> void:
	if enabled:
		if not _main_menu_mouse_locked:
			return
		for button in _get_visible_main_menu_buttons():
			button.mouse_filter = Control.MOUSE_FILTER_STOP
		_main_menu_mouse_locked = false
		return

	if _main_menu_mouse_locked:
		return
	for button in _get_visible_main_menu_buttons():
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_menu_mouse_locked = true


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
	_save_settings()


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	for bus_name: String in SETTINGS_AUDIO_BUSES:
		var slider: HSlider = _bus_sliders.get(bus_name, null) as HSlider
		if slider == null:
			continue
		config.set_value(AUDIO_SETTINGS_SECTION, bus_name, slider.value)
	config.set_value(MAIN_MENU_SETTINGS_SECTION, GAMBLE_MODE_KEY, _gamble_mode_enabled)
	config.save(AUDIO_SETTINGS_PATH)


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(AUDIO_SETTINGS_PATH) != OK:
		_apply_default_audio_settings()
		_gamble_mode_enabled = false
		return
	for bus_name: String in SETTINGS_AUDIO_BUSES:
		var pct: float = config.get_value(AUDIO_SETTINGS_SECTION, bus_name,
				BUS_DEFAULT_PCT.get(bus_name, 100.0))
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		var db: float = -80.0 if pct <= 0.0 else linear_to_db(pct / 100.0)
		AudioServer.set_bus_volume_db(bus_index, db)
	_gamble_mode_enabled = bool(config.get_value(MAIN_MENU_SETTINGS_SECTION, GAMBLE_MODE_KEY, false))


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
