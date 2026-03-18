extends StaticBody2D
class_name HarvestNode

@export var growth_interval_seconds: float = 10.0
@export var harvest_prompt_action: StringName = &"interact"
@export var default_harvest_range: float = 96.0
@export var prompt_refresh_interval: float = 0.25
@export var produced_lootbox_id: StringName
@export var pickup_scene: PackedScene = preload("res://entities/pickups/pickup.tscn")
@export var pickup_parent_path: NodePath = ^".."
@export var pickup_follow_target_path: NodePath = ^"../player"
@export var pickup_impulse: Vector2 = Vector2.UP * 600.0

const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")
const PROXIMITY_PROMPT_UTIL: GDScript = preload("res://scripts/proximity_prompt_util.gd")

var _harvest_count: int = 0
var _harvest_hint_text: String = "E"
var _prompt_refresh_time_left: float = 0.0
var _is_growth_paused: bool = false
var _spatial_index: SpatialIndex2D

@onready var _growth_timer: Timer = $GrowthTimer
@onready var _harvest_prompt_label: Label = $HarvestPromptLabel

func _ready() -> void:
	add_to_group("harvest_nodes")
	_harvest_hint_text = INPUT_HINT_UTIL.resolve_action_hint(harvest_prompt_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D

	if _growth_timer != null:
		_growth_timer.wait_time = maxf(growth_interval_seconds, 0.01)
		if not _growth_timer.timeout.is_connected(_on_growth_timer_timeout):
			_growth_timer.timeout.connect(_on_growth_timer_timeout)

	_set_harvest_count(_get_starting_harvest_count())
	_refresh_growth_timer()
	_update_harvest_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = PROXIMITY_PROMPT_UTIL.tick_refresh_time_left(_prompt_refresh_time_left, delta)
	if _prompt_refresh_time_left > 0.0:
		return

	_update_harvest_prompt()
	_schedule_prompt_refresh()

func can_harvest() -> bool:
	return _harvest_count > 0

func harvest_fruit(amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var harvested: int = mini(amount, _harvest_count)
	if harvested <= 0:
		return 0

	_spawn_lootbox_pickups(harvested)
	_set_harvest_count(_harvest_count - harvested)
	_refresh_growth_timer()
	return harvested

func get_harvest_count() -> int:
	return _harvest_count

func set_growth_paused(is_paused: bool) -> void:
	if _is_growth_paused == is_paused:
		return

	_is_growth_paused = is_paused
	_refresh_growth_timer()

func is_growth_paused() -> bool:
	return _is_growth_paused

func _on_growth_timer_timeout() -> void:
	if _is_growth_paused:
		_refresh_growth_timer()
		return

	if _harvest_count >= _get_harvest_capacity():
		_refresh_growth_timer()
		return

	var growth_amount: int = maxi(_get_growth_amount_per_tick(), 0)
	if growth_amount <= 0:
		_refresh_growth_timer()
		return

	_set_harvest_count(_harvest_count + growth_amount)
	if _harvest_count >= _get_harvest_capacity():
		_refresh_growth_timer()

func _get_starting_harvest_count() -> int:
	return 0

func _get_harvest_capacity() -> int:
	return 1

func _get_growth_amount_per_tick() -> int:
	return 1

func _on_harvest_count_changed(_previous_count: int, _current_count: int) -> void:
	pass

func _set_harvest_count(value: int) -> void:
	var previous_count: int = _harvest_count
	_harvest_count = clampi(value, 0, maxi(_get_harvest_capacity(), 0))
	_on_harvest_count_changed(previous_count, _harvest_count)
	_update_harvest_prompt()

func _refresh_growth_timer() -> void:
	if _growth_timer == null:
		return

	if _is_growth_paused or _get_harvest_capacity() <= 0 or _harvest_count >= _get_harvest_capacity():
		_growth_timer.stop()
		return

	if _growth_timer.is_stopped():
		_growth_timer.start()

func _update_harvest_prompt() -> void:
	if _harvest_prompt_label == null:
		return

	var should_show: bool = can_harvest() and _is_any_player_in_harvest_range()
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

func _spawn_lootbox_pickups(amount: int) -> void:
	if pickup_scene == null:
		return

	var pickup_parent: Node = get_node_or_null(pickup_parent_path)
	if pickup_parent == null:
		pickup_parent = get_parent()
	if pickup_parent == null:
		return

	var follow_target: Node2D = null
	if not pickup_follow_target_path.is_empty():
		follow_target = get_node_or_null(pickup_follow_target_path) as Node2D

	for _i in range(amount):
		var new_box: Pickup = pickup_scene.instantiate() as Pickup
		new_box.set_data(produced_lootbox_id)
		if new_box == null:
			continue

		new_box.set_data(produced_lootbox_id)
		new_box.floating_towards = follow_target
		pickup_parent.add_child(new_box)
		new_box.global_position = global_position
		new_box.apply_central_impulse(pickup_impulse)
