extends StaticBody2D
class_name FarmTree

signal fruit_count_changed(current: int, maximum: int)

@export var growth_interval_seconds: float = 10.0
@export var max_fruit: int = 6
@export var starting_fruit: int = 0
@export var harvest_prompt_action: StringName = &"interact"
@export var default_harvest_range: float = 96.0
@export var pause_growth_at_night: bool = true
@export var prompt_refresh_interval: float = 0.25
const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")
const PROXIMITY_PROMPT_UTIL: GDScript = preload("res://scripts/proximity_prompt_util.gd")
var box_pickup_scene : PackedScene = preload("res://entities/pickups/box_pickup.tscn")

@export var produced_lootbox_id: StringName

var _fruit_count: int = 0
var _shown_fruit_indices: Array[int] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _harvest_hint_text: String = "E"
var _is_growth_paused: bool = false
var _prompt_refresh_time_left: float = 0.0
var _spatial_index: SpatialIndex2D


@onready var _growth_timer: Timer = $GrowthTimer
@onready var _harvest_prompt_label: Label = $HarvestPromptLabel
@onready var _fruit_sprites: Array[Sprite2D] = [
	get_node_or_null("FruitSprites/Fruit1") as Sprite2D,
	get_node_or_null("FruitSprites/Fruit2") as Sprite2D,
	get_node_or_null("FruitSprites/Fruit3") as Sprite2D,
	get_node_or_null("FruitSprites/Fruit4") as Sprite2D,
	get_node_or_null("FruitSprites/Fruit5") as Sprite2D,
	get_node_or_null("FruitSprites/Fruit6") as Sprite2D,
]

func _ready() -> void:
	add_to_group("trees")
	_rng.randomize()
	_initialize_fruit_visuals()
	_harvest_hint_text = INPUT_HINT_UTIL.resolve_action_hint(harvest_prompt_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D

	_growth_timer.wait_time = maxf(growth_interval_seconds, 0.01)
	if not _growth_timer.timeout.is_connected(_on_growth_timer_timeout):
		_growth_timer.timeout.connect(_on_growth_timer_timeout)

	_set_fruit_count(starting_fruit)
	_refresh_growth_timer()
	_sync_growth_pause_from_day_night_cycle()
	_update_harvest_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.tick_refresh_time_left(_prompt_refresh_time_left, delta)
	if _prompt_refresh_time_left > 0.0:
		return

	_update_harvest_prompt()
	_schedule_prompt_refresh()

func get_fruit_count() -> int:
	return _fruit_count

func can_harvest() -> bool:
	return _fruit_count > 0

func harvest_fruit(amount: int = 1) -> int:
	if amount <= 0:return 0

	var harvested := mini(amount, _fruit_count)
	if harvested <= 0: return 0
	
	for i in range(harvested):
		var new_box: Pickup = box_pickup_scene.instantiate()
		$"..".add_child(new_box)
		new_box.position = position
		new_box.apply_central_impulse(Vector2.UP * 600)
		new_box.floating_towards=$"../player"
		new_box.item_id=produced_lootbox_id

	_set_fruit_count(_fruit_count - harvested)
	_refresh_growth_timer()
	return harvested

func _on_growth_timer_timeout() -> void:
	if _is_growth_paused:
		_refresh_growth_timer()
		return

	if _fruit_count >= max_fruit:
		_refresh_growth_timer()
		return

	_set_fruit_count(_fruit_count + 1)
	if _fruit_count >= max_fruit:
		_refresh_growth_timer()

func _set_fruit_count(value: int) -> void:
	_fruit_count = clampi(value, 0, maxi(max_fruit, 0))
	_update_fruit_visuals()
	_update_harvest_prompt()
	fruit_count_changed.emit(_fruit_count, max_fruit)

func _refresh_growth_timer() -> void:
	if _is_growth_paused or max_fruit <= 0 or _fruit_count >= max_fruit:
		_growth_timer.stop()
		return

	if _growth_timer.is_stopped():
		_growth_timer.start()

func set_growth_paused(is_paused: bool) -> void:
	if not pause_growth_at_night:
		is_paused = false

	if _is_growth_paused == is_paused:
		return

	_is_growth_paused = is_paused
	_refresh_growth_timer()

func is_growth_paused() -> bool:
	return _is_growth_paused

func _sync_growth_pause_from_day_night_cycle() -> void:
	if not pause_growth_at_night:
		set_growth_paused(false)
		return

	var current_scene: Node = get_tree().current_scene
	if not current_scene is MainScene:
		set_growth_paused(false)
		return

	set_growth_paused((current_scene as MainScene).is_night_time())

func _update_fruit_visuals() -> void:
	var target_visible_count := mini(_fruit_count, _fruit_sprites.size())

	while _shown_fruit_indices.size() < target_visible_count:
		var hidden_indices: Array[int] = []
		for i in _fruit_sprites.size():
			if _fruit_sprites[i] == null:
				continue
			if _shown_fruit_indices.has(i):
				continue

			hidden_indices.append(i)

		if hidden_indices.is_empty():
			break

		var hidden_index := hidden_indices[_rng.randi_range(0, hidden_indices.size() - 1)]

		_shown_fruit_indices.append(hidden_index)
		var fruit_to_show := _fruit_sprites[hidden_index]
		if fruit_to_show != null:
			fruit_to_show.visible = true

	while _shown_fruit_indices.size() > target_visible_count:
		var shown_index := int(_shown_fruit_indices.pop_back())
		var fruit_to_hide := _fruit_sprites[shown_index]
		if fruit_to_hide != null:
			fruit_to_hide.visible = false

func _initialize_fruit_visuals() -> void:
	_shown_fruit_indices.clear()
	for fruit_sprite in _fruit_sprites:
		if fruit_sprite != null:
			fruit_sprite.visible = false

func _update_harvest_prompt() -> void:
	if _harvest_prompt_label == null:
		return

	var should_show := can_harvest() and _is_any_player_in_harvest_range()
	_harvest_prompt_label.visible = should_show
	if not should_show:
		return

	_harvest_prompt_label.text = "Press %s to harvest" % _harvest_hint_text

func _is_any_player_in_harvest_range() -> bool:
	return PROXIMITY_PROMPT_UTIL.is_any_player_in_dynamic_range(
		self,
		global_position,
		default_harvest_range,
		_spatial_index
	)

func _schedule_prompt_refresh(initial_delay: float = -1.0) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.schedule_next_refresh(
		prompt_refresh_interval,
		0.06,
		0.4,
		initial_delay
	)
