# TODO: I'm not extending harvestnode, this might be weird
extends Node2D
class_name BloodConfluence


@export var _lootbox_sprite: Sprite2D
@export var _harvest_prompt_label: Label
@export var _blood_count_label: Label
@export var _box_cost_label: Label
@export var pickup_scene: PackedScene

var produced_lootbox_id: StringName = "lootbox_elemental"

var blood : float = 0
var lootbox_cost_in_blood : float = 5

func _ready() -> void:
	add_to_group("blood_confluence")
	add_to_group("interactable")
	_update_visuals()

func try_purchase_lootbox(player : Player) -> bool:
	if blood < lootbox_cost_in_blood: return false
	
	_set_blood(blood - lootbox_cost_in_blood)

	var new_box: Pickup = pickup_scene.instantiate() as Pickup
	new_box.set_data(produced_lootbox_id)

	get_parent().add_child(new_box)
	new_box.global_position = global_position
	new_box.apply_central_impulse(Vector2.UP * 600.0)
	new_box.floating_towards = player
	new_box.item_id = produced_lootbox_id

	return true

func _set_blood(_new_blood: float) -> void:
	blood = _new_blood
	_update_visuals()

func _update_visuals() -> void:
	if _lootbox_sprite != null:
		_lootbox_sprite.visible = blood >= lootbox_cost_in_blood
	if _harvest_prompt_label != null:
		_harvest_prompt_label.visible = blood >= lootbox_cost_in_blood

	_blood_count_label.text = "blood: " + str(blood)
	_box_cost_label.text = "box cost: " + str(lootbox_cost_in_blood)
