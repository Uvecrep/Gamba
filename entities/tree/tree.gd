extends "res://entities/shared/harvest_node.gd"
class_name FarmTree

signal fruit_count_changed(current: int, maximum: int)

@export var max_fruit: int = 6
@export var starting_fruit: int = 0
@export var pause_growth_at_night: bool = true

var _shown_fruit_indices: Array[int] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
const MAIN_SCENE_SCRIPT: Script = preload("res://levels/main.gd")
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
	super._ready()
	_sync_growth_pause_from_day_night_cycle()

func get_fruit_count() -> int:
	return get_harvest_count()

func _get_starting_harvest_count() -> int:
	return starting_fruit

func _get_harvest_capacity() -> int:
	return max_fruit

func _on_harvest_count_changed(previous_count: int, current_count: int) -> void:
	_update_fruit_visuals(current_count)
	if current_count > previous_count:
		Audio.play_sfx(&"world_fruit_ready", -10.0)
	fruit_count_changed.emit(current_count, max_fruit)

func set_growth_paused(is_paused: bool) -> void:
	if not pause_growth_at_night:
		is_paused = false

	super.set_growth_paused(is_paused)

func _sync_growth_pause_from_day_night_cycle() -> void:
	if not pause_growth_at_night:
		set_growth_paused(false)
		return

	var current_scene: Node = get_tree().current_scene
	if not (current_scene is MAIN_SCENE_SCRIPT):
		set_growth_paused(false)
		return

	set_growth_paused(bool(current_scene.call("is_night_time")))

func _update_fruit_visuals(harvest_count: int) -> void:
	var target_visible_count := mini(harvest_count, _fruit_sprites.size())

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
