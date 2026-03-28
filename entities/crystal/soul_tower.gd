extends Node2D
class_name SoulTower


@export var _lootbox_sprite: Sprite2D
@export var pickup_scene: PackedScene
@export var _harvest_prompt_label: Label

var produced_lootbox_id: StringName = "lootbox_soul"
var has_interacted: bool = false


func _ready() -> void:
	add_to_group("soul_tower")
	add_to_group("interactable")
	_refresh_lootbox_sprite_texture()
	_update_visuals()

func interact(player : Player) -> void:
	if has_interacted: return
	has_interacted = true
	
	_update_visuals()

	_spawn_boxes(player)

func _set_blood(_new_blood: float) -> void:
	_update_visuals()

func _update_visuals() -> void:
	if _lootbox_sprite != null:
		_lootbox_sprite.visible = !has_interacted
	if _harvest_prompt_label != null:
		_harvest_prompt_label.visible = !has_interacted

func _spawn_boxes(player : Player) -> void:
	for _i in range(0,3):
		await get_tree().create_timer(0.04).timeout
		var new_box: Pickup = pickup_scene.instantiate() as Pickup
		new_box.set_data(produced_lootbox_id)
		var drop_angle: float = randf_range(0.0, TAU)
		var drop_distance: float = randf_range(34.0, 52.0)
		var spawn_offset: Vector2 = Vector2.RIGHT.rotated(drop_angle) * drop_distance

		get_parent().add_child(new_box)
		new_box.global_position = global_position + spawn_offset
		new_box.apply_central_impulse((spawn_offset.normalized() * 220.0) + (Vector2.UP * 420.0))
		new_box.floating_towards = player
		new_box.item_id = produced_lootbox_id


func _refresh_lootbox_sprite_texture() -> void:
	if _lootbox_sprite == null:
		return
	if produced_lootbox_id == StringName():
		return
	if ItemGlobals == null:
		return

	var item: ItemData = ItemGlobals.items.get(produced_lootbox_id, null) as ItemData
	if item == null:
		return
	if item.texture == null:
		return

	_lootbox_sprite.texture = item.texture
