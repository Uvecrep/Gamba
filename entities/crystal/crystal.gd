extends "res://entities/shared/harvest_node.gd"
class_name CrystalNode

signal lootbox_ready_changed(has_lootbox: bool)

@export var starting_lootboxes: int = 0
@onready var _lootbox_sprite: Sprite2D = $LootboxSprite

func _ready() -> void:
	add_to_group("crystals")
	super._ready()

func _get_starting_harvest_count() -> int:
	return starting_lootboxes

func _get_harvest_capacity() -> int:
	return 1

func _on_harvest_count_changed(_previous_count: int, current_count: int) -> void:
	_update_lootbox_visual(current_count)
	lootbox_ready_changed.emit(current_count > 0)

func _update_lootbox_visual(current_count: int) -> void:
	if _lootbox_sprite == null:
		return

	_lootbox_sprite.visible = current_count > 0
