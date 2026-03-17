extends ThrownObject
class_name ThrownPickup

@export var pickup_packed_scene : PackedScene

var pickup_item_id : StringName

# Meant to be overridden with whatever should happen when the object hits the ground
func on_landed():
	var new_pickup: Pickup = pickup_packed_scene.instantiate()
	get_parent().add_child(new_pickup)
	new_pickup.global_position = global_position
	new_pickup.set_data(pickup_item_id)
	queue_free()
