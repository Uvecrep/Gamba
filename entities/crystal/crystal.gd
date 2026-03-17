extends StaticBody2D
class_name CrystalNode

signal lootbox_ready_changed(has_lootbox: bool)

@export var growth_interval_seconds: float = 10.0
@export var starting_lootboxes: int = 0
@export var harvest_prompt_action: StringName = &"interact"
@export var default_harvest_range: float = 96.0
@export var prompt_refresh_interval: float = 0.25
const INPUT_HINT_UTIL: GDScript = preload("res://scripts/input_hint.gd")
const PROXIMITY_PROMPT_UTIL: GDScript = preload("res://scripts/proximity_prompt_util.gd")
var box_pickup_scene : PackedScene = preload("res://entities/pickups/box_pickup.tscn")


@export var produced_lootbox_id: StringName

var _lootboxes: int = 0
var _harvest_hint_text: String = "E"
var _prompt_refresh_time_left: float = 0.0
var _spatial_index: SpatialIndex2D

@onready var _growth_timer: Timer = $GrowthTimer
@onready var _harvest_prompt_label: Label = $HarvestPromptLabel
@onready var _lootbox_sprite: Sprite2D = $LootboxSprite

func _ready() -> void:
	add_to_group("crystals")
	_harvest_hint_text = INPUT_HINT_UTIL.resolve_action_hint(harvest_prompt_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D

	_growth_timer.wait_time = maxf(growth_interval_seconds, 0.01)
	if not _growth_timer.timeout.is_connected(_on_growth_timer_timeout):
		_growth_timer.timeout.connect(_on_growth_timer_timeout)

	_set_lootboxes(starting_lootboxes)
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
	return _lootboxes > 0

func harvest_fruit(amount: int = 1) -> int:
	if amount <= 0: return 0

	var harvested: int = mini(amount, _lootboxes)
	if harvested <= 0: return 0
	
	for i in range(harvested):
		var new_box: Pickup = box_pickup_scene.instantiate()
		$"..".add_child(new_box)
		new_box.position = position
		new_box.apply_central_impulse(Vector2.UP * 600)
		new_box.floating_towards=$"../player"
		new_box.item_id=produced_lootbox_id
		
	
	_set_lootboxes(_lootboxes - harvested)
	_refresh_growth_timer()
	return harvested

func _on_growth_timer_timeout() -> void:
	if _lootboxes >= 1:
		_refresh_growth_timer()
		return

	_set_lootboxes(1)
	_refresh_growth_timer()

func _set_lootboxes(value: int) -> void:
	_lootboxes = clampi(value, 0, 1)
	_update_lootbox_visual()
	_update_harvest_prompt()
	lootbox_ready_changed.emit(_lootboxes > 0)

func _update_lootbox_visual() -> void:
	if _lootbox_sprite == null:
		return

	_lootbox_sprite.visible = _lootboxes > 0

func _refresh_growth_timer() -> void:
	if _lootboxes >= 1:
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
