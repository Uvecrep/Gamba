extends StaticBody2D
class_name CrystalNode

signal lootbox_ready_changed(has_lootbox: bool)

@export var growth_interval_seconds: float = 10.0
@export var starting_lootboxes: int = 0
@export var harvest_prompt_action: StringName = &"interact"
@export var default_harvest_range: float = 96.0
@export var prompt_refresh_interval: float = 0.25
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
	_harvest_hint_text = _resolve_action_hint(harvest_prompt_action)
	_spatial_index = get_node_or_null("/root/SpatialIndex") as SpatialIndex2D

	_growth_timer.wait_time = maxf(growth_interval_seconds, 0.01)
	if not _growth_timer.timeout.is_connected(_on_growth_timer_timeout):
		_growth_timer.timeout.connect(_on_growth_timer_timeout)

	_set_lootboxes(starting_lootboxes)
	_refresh_growth_timer()
	_update_harvest_prompt()
	_schedule_prompt_refresh(0.0)

func _process(delta: float) -> void:
	_prompt_refresh_time_left = maxf(_prompt_refresh_time_left - delta, 0.0)
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
	if is_instance_valid(_spatial_index):
		var nearest_player: Node2D = _spatial_index.find_closest_in_group(global_position, &"players")
		if nearest_player != null:
			var nearest_range: float = maxf(default_harvest_range, 0.0)
			var nearest_player_harvest_range: Variant = nearest_player.get("harvest_range")
			if typeof(nearest_player_harvest_range) == TYPE_FLOAT or typeof(nearest_player_harvest_range) == TYPE_INT:
				nearest_range = maxf(float(nearest_player_harvest_range), 0.0)

			var nearest_distance_sq: float = global_position.distance_squared_to(nearest_player.global_position)
			if nearest_distance_sq <= nearest_range * nearest_range:
				return true

	var players: Array = get_tree().get_nodes_in_group("players")
	for player in players:
		if not (player is Node2D):
			continue

		var harvest_range: float = maxf(default_harvest_range, 0.0)
		var player_harvest_range: Variant = player.get("harvest_range")
		if typeof(player_harvest_range) == TYPE_FLOAT or typeof(player_harvest_range) == TYPE_INT:
			harvest_range = maxf(float(player_harvest_range), 0.0)

		var player_node: Node2D = player as Node2D
		var distance_sq: float = global_position.distance_squared_to(player_node.global_position)
		if distance_sq <= harvest_range * harvest_range:
			return true

	return false

func _schedule_prompt_refresh(initial_delay: float = -1.0) -> void:
	if initial_delay >= 0.0:
		_prompt_refresh_time_left = initial_delay
		return

	var base_interval: float = maxf(prompt_refresh_interval, 0.06)
	var jitter: float = randf_range(0.0, base_interval * 0.4)
	_prompt_refresh_time_left = base_interval + jitter

func _resolve_action_hint(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action).to_upper()

	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event in events:
		if event == null:
			continue

		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode != 0:
				return OS.get_keycode_string(key_event.physical_keycode)
			if key_event.keycode != 0:
				return OS.get_keycode_string(key_event.keycode)

		var event_text: String = event.as_text()
		if not event_text.is_empty():
			return event_text

	return String(action).to_upper()
