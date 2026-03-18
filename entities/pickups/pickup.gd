extends RigidBody2D
class_name Pickup


@export var item_id : StringName

@export var debug_item_id_label : Label
@export var texture_rect : TextureRect

var floating_towards : Node2D

func _ready() -> void:
	_refresh_visuals()

func set_data(new_item_id : StringName) -> void:
	item_id = new_item_id
	debug_item_id_label.text = new_item_id
	_refresh_visuals()

func _physics_process(_delta: float) -> void:
	apply_force(-linear_velocity * .2) # Apply drag
	
	if floating_towards != null:
		var float_force = pow(floating_towards.position.distance_to(position),2)
		apply_central_force(float_force * position.direction_to(floating_towards.position))

func _refresh_visuals() -> void:
	if not ItemGlobals.items.has(item_id):
		return
	
	var item_data : ItemData = ItemGlobals.items[item_id]

	texture_rect.texture = item_data.texture
