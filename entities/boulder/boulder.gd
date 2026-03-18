extends "res://entities/shared/harvest_node.gd"
class_name BoulderResource

signal gold_ready_changed(has_gold: bool)

@export var starting_gold: int = 3
@export var max_gold: int = 3

@onready var _gold_ready_sprite: Sprite2D = $GoldReadySprite

func _ready() -> void:
	add_to_group("boulders")
	super._ready()

func _get_starting_harvest_count() -> int:
	return starting_gold

func _get_harvest_capacity() -> int:
	return max_gold

func _on_harvest_count_changed(_previous_count: int, current_count: int) -> void:
	_update_gold_visual(current_count)
	gold_ready_changed.emit(current_count > 0)

func _update_gold_visual(current_count: int) -> void:
	if _gold_ready_sprite == null:
		return

	_gold_ready_sprite.visible = current_count > 0
