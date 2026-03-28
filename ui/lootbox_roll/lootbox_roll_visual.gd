extends Control
class_name LootboxRollVisual

const RewardDataScript = preload("res://entities/lootbox/reward_data.gd")

signal roll_finished(winning_entry: LootEntry, reward_data: Resource)

@export var card_scene: PackedScene = preload("res://ui/lootbox_roll/reward_card.tscn")
@export var roll_duration: float = 2.1
@export var settle_hold_time: float = 0.5
@export var world_offset: Vector2 = Vector2(0.0, -82.0)
@export var strip_item_count: int = 28
@export var winner_index_from_end: int = 4
@export var card_width: float = 102.0
@export var card_height: float = 120.0
@export var card_spacing: float = 10.0

const LUCKY_DRAMA_TIME_SCALE: float = 0.22
const LUCKY_DRAMA_ZOOM_FACTOR: float = 1.35
const LUCKY_DRAMA_ZOOM_RETURN_SECONDS: float = 0.18

@onready var _panel: Panel = $Panel
@onready var _clip: Control = $Panel/MarginContainer/Clip
@onready var _strip: Control = $Panel/MarginContainer/Clip/Strip
@onready var _center_marker: ColorRect = $Panel/CenterMarker
@onready var _result_label: Label = $Panel/ResultLabel
@onready var _title_label: Label = $Panel/TitleLabel
@onready var _win_flash: ColorRect = $Panel/WinFlash

var _anchor_node: Node2D
var _source_lootbox: Lootbox
var _winning_entry: LootEntry
var _winning_reward_data: Resource

var _strip_entries: Array[LootEntry] = []
var _strip_cards: Array[Control] = []
var _winning_strip_index: int = -1

var _scroll_offset: float = 0.0
var _last_center_index: int = -1
var _is_running: bool = false
var _is_finished: bool = false
var _active_tween: Tween
var _drama_camera_tween: Tween
var _drama_return_tween: Tween
var _lucky_drama_active: bool = false
var _time_scale_overridden: bool = false
var _previous_time_scale: float = 1.0
var _drama_camera: Camera2D
var _drama_camera_base_zoom: Vector2 = Vector2.ONE

var scroll_offset: float:
	set(value):
		_set_scroll_offset(value)
	get:
		return _scroll_offset


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_flash.visible = false
	_result_label.visible = false
	_apply_panel_style()


func _process(_delta: float) -> void:
	if _is_finished:
		return
	_update_screen_position()


func begin(anchor_node: Node2D, source_lootbox: Lootbox, winning_entry: LootEntry, winning_reward_data: Resource = null, screen_offset: Vector2 = Vector2(0.0, -82.0)) -> void:
	_anchor_node = anchor_node
	_source_lootbox = source_lootbox
	_winning_entry = winning_entry
	_winning_reward_data = winning_reward_data
	world_offset = screen_offset

	if is_node_ready():
		_start_roll_if_possible()
	else:
		call_deferred("_start_roll_if_possible")


func _start_roll_if_possible() -> void:
	if _clip.size.x <= 1.0:
		call_deferred("_start_roll_if_possible")
		return

	if _winning_entry == null:
		queue_free()
		return

	if _winning_reward_data == null:
		_winning_reward_data = _winning_entry.get_reward_data_with_quality_roll()
	Audio.play_sfx(&"lootbox_open_start")
	_title_label.text = _source_lootbox.name if _source_lootbox != null else "Summoner Sorting Machine"
	_result_label.text = ""
	_build_visual_strip()
	_update_screen_position()
	_start_roll_animation()


func _build_visual_strip() -> void:
	_clear_strip_cards()
	_strip_entries.clear()
	_strip_cards.clear()

	var source_entries: Array[LootEntry] = []
	if _source_lootbox != null:
		source_entries = _source_lootbox.get_rollable_entries()

	if source_entries.is_empty():
		source_entries.append(_winning_entry)

	var total_cards: int = maxi(strip_item_count, 14)
	var winner_padding_from_end: int = clampi(winner_index_from_end, 2, total_cards - 2)
	_winning_strip_index = maxi(2, total_cards - winner_padding_from_end)
	_winning_strip_index = mini(_winning_strip_index, total_cards - 2)

	for i in range(total_cards):
		var entry: LootEntry = _winning_entry if i == _winning_strip_index else _pick_filler_entry(source_entries)
		_strip_entries.append(entry)
		var card_reward_data: Resource = _winning_reward_data if i == _winning_strip_index else null
		_add_card(entry, i, card_reward_data)

	_strip.size = Vector2((card_width + card_spacing) * float(total_cards), card_height)


func _add_card(entry: LootEntry, index: int, reward_data_override: Resource = null) -> void:
	if card_scene == null:
		return

	var card: Control = card_scene.instantiate() as Control
	if card == null:
		return

	_strip.add_child(card)
	card.position = Vector2(float(index) * _slot_width(), 0.0)
	card.custom_minimum_size = Vector2(card_width, card_height)
	card.size = Vector2(card_width, card_height)
	if card.has_method("set_reward_data"):
		var reward_data: Resource = reward_data_override if reward_data_override != null else entry.get_reward_data()
		card.call("set_reward_data", reward_data)
	_strip_cards.append(card)


func _pick_filler_entry(source_entries: Array[LootEntry]) -> LootEntry:
	if source_entries.is_empty():
		return _winning_entry
	if source_entries.size() == 1:
		return source_entries[0]

	var candidate: LootEntry = source_entries[randi() % source_entries.size()]
	if candidate == _winning_entry and randf() < 0.72:
		candidate = source_entries[(randi() + 1) % source_entries.size()]
	return candidate


func _start_roll_animation() -> void:
	if _strip_entries.is_empty() or _winning_strip_index < 0:
		_finish_roll()
		return

	_is_running = true
	_last_center_index = -1

	var start_index: int = 1
	var start_offset: float = clampf(_compute_scroll_offset_for_index(start_index), 0.0, _max_scroll_offset())
	var target_offset: float = clampf(_compute_scroll_offset_for_index(_winning_strip_index), 0.0, _max_scroll_offset())

	if target_offset <= start_offset:
		start_offset = maxf(0.0, target_offset - (_slot_width() * 10.0))

	scroll_offset = start_offset

	if _active_tween != null:
		_active_tween.kill()

	var first_leg_target: float = lerpf(start_offset, target_offset, 0.84)
	var use_lucky_drama: bool = _is_lucky_roll()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "scroll_offset", first_leg_target, roll_duration * 0.58).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	if use_lucky_drama:
		var second_leg_duration: float = roll_duration * 0.42
		var pre_landing_duration: float = second_leg_duration * 0.56
		var dramatic_landing_duration: float = maxf(second_leg_duration - pre_landing_duration, 0.05)
		var pre_landing_target: float = lerpf(first_leg_target, target_offset, 0.72)
		_active_tween.tween_property(self, "scroll_offset", pre_landing_target, pre_landing_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_active_tween.tween_callback(func() -> void:
			_enter_lucky_landing_drama(dramatic_landing_duration)
		)
		_active_tween.tween_property(self, "scroll_offset", target_offset, dramatic_landing_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		_active_tween.tween_property(self, "scroll_offset", target_offset, roll_duration * 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_active_tween.finished.connect(_on_roll_tween_finished, CONNECT_ONE_SHOT)


func _on_roll_tween_finished() -> void:
	_is_running = false
	_exit_lucky_landing_drama()
	Audio.play_sfx(&"lootbox_settle")
	var winner_card: Control = _get_card(_winning_strip_index)
	if winner_card != null:
		if winner_card.has_method("play_win_pop"):
			winner_card.call("play_win_pop")

	_result_label.visible = true
	if _winning_reward_data != null and _winning_reward_data.has_method("get_display_name_or_fallback"):
		_result_label.text = "Awarded: %s" % String(_winning_reward_data.call("get_display_name_or_fallback"))
	else:
		_result_label.text = "Awarded: Mystery Reward"

	var rarity_value: int = int(_winning_reward_data.get("rarity")) if _winning_reward_data != null else 0
	Audio.play_lootbox_reveal_for_rarity(rarity_value)
	if rarity_value >= 3:
		Audio.play_ui(&"ui_bestiary_new", -4.0)
	else:
		Audio.play_ui(&"ui_lootbox_reward")
	_play_win_flash()

	var settle_timer: SceneTreeTimer = get_tree().create_timer(maxf(settle_hold_time, 0.05))
	settle_timer.timeout.connect(_finish_roll, CONNECT_ONE_SHOT)


func _finish_roll() -> void:
	if _is_finished:
		return
	_is_finished = true
	if _active_tween != null:
		_active_tween.kill()
	_exit_lucky_landing_drama()
	roll_finished.emit(_winning_entry, _winning_reward_data)
	queue_free()


func _is_lucky_roll() -> bool:
	if _winning_reward_data == null:
		return false
	var rarity_value: int = int(_winning_reward_data.get("rarity"))
	return rarity_value >= RewardDataScript.Rarity.EPIC


func _enter_lucky_landing_drama(duration: float) -> void:
	if _lucky_drama_active:
		return

	_previous_time_scale = Engine.time_scale
	Engine.time_scale = LUCKY_DRAMA_TIME_SCALE
	_time_scale_overridden = true

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and is_instance_valid(camera):
		_drama_camera = camera
		_drama_camera_base_zoom = camera.zoom
		if _drama_camera_tween != null:
			_drama_camera_tween.kill()
		if _drama_return_tween != null:
			_drama_return_tween.kill()
		_drama_camera_tween = create_tween()
		_drama_camera_tween.tween_property(
			_drama_camera,
			"zoom",
			_drama_camera_base_zoom * LUCKY_DRAMA_ZOOM_FACTOR,
			maxf(duration * 0.72, 0.08)
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	_lucky_drama_active = true


func _exit_lucky_landing_drama() -> void:
	if not _lucky_drama_active and not _time_scale_overridden:
		return

	if _drama_camera_tween != null:
		_drama_camera_tween.kill()

	if _time_scale_overridden:
		Engine.time_scale = _previous_time_scale
		_time_scale_overridden = false

	if _drama_camera != null and is_instance_valid(_drama_camera):
		if _drama_return_tween != null:
			_drama_return_tween.kill()
		_drama_return_tween = create_tween()
		_drama_return_tween.tween_property(
			_drama_camera,
			"zoom",
			_drama_camera_base_zoom,
			LUCKY_DRAMA_ZOOM_RETURN_SECONDS
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	_drama_camera = null
	_lucky_drama_active = false


func _set_scroll_offset(value: float) -> void:
	_scroll_offset = value
	_strip.position.x = -_scroll_offset
	_update_center_tick()


func _compute_scroll_offset_for_index(index: int) -> float:
	var card_center_x: float = (float(index) * _slot_width()) + (card_width * 0.5)
	var viewport_center_x: float = _clip.size.x * 0.5
	return card_center_x - viewport_center_x


func _slot_width() -> float:
	return card_width + card_spacing


func _max_scroll_offset() -> float:
	return maxf(_strip.size.x - _clip.size.x, 0.0)


func _get_center_index() -> int:
	if _strip_entries.is_empty():
		return -1

	var center_x: float = _scroll_offset + (_clip.size.x * 0.5)
	var slot: float = _slot_width()
	if slot <= 0.0:
		return -1

	var index: int = int(round((center_x - (card_width * 0.5)) / slot))
	return clampi(index, 0, _strip_entries.size() - 1)


func _update_center_tick() -> void:
	var centered_index: int = _get_center_index()
	if centered_index < 0:
		return

	if centered_index == _last_center_index:
		return

	if _last_center_index >= 0 and _is_running:
		# Tiny marker pulse each time a card crosses center.
		Audio.play_ui_tick_throttled(38)
		_center_marker.scale = Vector2(1.0, 1.22)
		var pulse_tween: Tween = create_tween()
		pulse_tween.tween_property(_center_marker, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_last_center_index = centered_index


func _play_win_flash() -> void:
	_win_flash.visible = true
	_win_flash.modulate = Color(1, 1, 1, 0.0)

	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(_win_flash, "modulate:a", 0.4, 0.08)
	flash_tween.tween_property(_win_flash, "modulate:a", 0.0, 0.24)
	flash_tween.finished.connect(func() -> void:
		_win_flash.visible = false
	)


func _update_screen_position() -> void:
	if _anchor_node == null or not is_instance_valid(_anchor_node):
		if not _is_finished:
			_finish_roll()
		return

	var anchor_screen_position: Vector2 = _anchor_node.get_global_transform_with_canvas().origin
	position = anchor_screen_position + world_offset - Vector2(size.x * 0.5, size.y)


func _apply_panel_style() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.11, 0.88)
	panel_style.border_color = Color(0.97, 0.77, 0.26, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3

	_panel.add_theme_stylebox_override("panel", panel_style)
	_title_label.modulate = Color(1.0, 0.93, 0.56, 1.0)
	_result_label.modulate = Color(1.0, 0.95, 0.82, 1.0)


func _clear_strip_cards() -> void:
	for child in _strip.get_children():
		child.queue_free()


func _get_card(index: int) -> Control:
	if index < 0 or index >= _strip_cards.size():
		return null
	return _strip_cards[index]
