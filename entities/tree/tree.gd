extends StaticBody2D

signal fruit_count_changed(current: int, maximum: int)

@export var growth_interval_seconds: float = 30.0
@export var max_fruit: int = 6
@export var starting_fruit: int = 0

var _fruit_count: int = 0
var _shown_fruit_indices: Array[int] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _growth_timer: Timer = $GrowthTimer
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

	_growth_timer.wait_time = maxf(growth_interval_seconds, 0.01)
	if not _growth_timer.timeout.is_connected(_on_growth_timer_timeout):
		_growth_timer.timeout.connect(_on_growth_timer_timeout)

	_set_fruit_count(starting_fruit)
	_refresh_growth_timer()

func get_fruit_count() -> int:
	return _fruit_count

func can_harvest() -> bool:
	return _fruit_count > 0

func harvest_fruit(amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var harvested: int = mini(amount, _fruit_count)
	if harvested <= 0:
		return 0

	_set_fruit_count(_fruit_count - harvested)
	_refresh_growth_timer()
	return harvested

func _on_growth_timer_timeout() -> void:
	if _fruit_count >= max_fruit:
		_refresh_growth_timer()
		return

	_set_fruit_count(_fruit_count + 1)
	if _fruit_count >= max_fruit:
		_refresh_growth_timer()

func _set_fruit_count(value: int) -> void:
	_fruit_count = clampi(value, 0, maxi(max_fruit, 0))
	_update_fruit_visuals()
	fruit_count_changed.emit(_fruit_count, max_fruit)

func _refresh_growth_timer() -> void:
	if max_fruit <= 0 or _fruit_count >= max_fruit:
		_growth_timer.stop()
		return

	if _growth_timer.is_stopped():
		_growth_timer.start()

func _update_fruit_visuals() -> void:
	var target_visible_count: int = mini(_fruit_count, _fruit_sprites.size())

	while _shown_fruit_indices.size() < target_visible_count:
		var hidden_index: int = _pick_random_hidden_fruit_index()
		if hidden_index < 0:
			break

		_shown_fruit_indices.append(hidden_index)
		var fruit_to_show: Sprite2D = _fruit_sprites[hidden_index]
		if fruit_to_show != null:
			fruit_to_show.visible = true

	while _shown_fruit_indices.size() > target_visible_count:
		var shown_index: int = int(_shown_fruit_indices.pop_back())
		var fruit_to_hide: Sprite2D = _fruit_sprites[shown_index]
		if fruit_to_hide != null:
			fruit_to_hide.visible = false

func _pick_random_hidden_fruit_index() -> int:
	var hidden_indices: Array[int] = []
	for i in _fruit_sprites.size():
		if _fruit_sprites[i] == null:
			continue
		if _shown_fruit_indices.has(i):
			continue

		hidden_indices.append(i)

	if hidden_indices.is_empty():
		return -1

	var random_hidden_index: int = _rng.randi_range(0, hidden_indices.size() - 1)
	return hidden_indices[random_hidden_index]

func _initialize_fruit_visuals() -> void:
	_shown_fruit_indices.clear()
	for fruit_sprite in _fruit_sprites:
		if fruit_sprite != null:
			fruit_sprite.visible = false
