extends ThrownObject
class_name ThrownSapling

@export var sapling_tree_packed_scene : PackedScene
@export var pickup_packed_scene : PackedScene

# Meant to be overridden with whatever should happen when the object hits the ground
func on_landed():

	var to_plant_in : PlantableArea = _get_plant_location()
	
	# Spawn pickup if you didn't hit an area
	# TODO maybe I should not let player throw at all in that case | Ian: Yeah, that feels more intuitive to me too
	if not to_plant_in: 
		var new_pickup: Pickup = pickup_packed_scene.instantiate()
		get_parent().add_child(new_pickup)
		new_pickup.global_position = global_position
		new_pickup.set_data("sapling")
		queue_free()
		return

	var new_tree: Node = sapling_tree_packed_scene.instantiate()
	get_parent().add_child(new_tree)
	new_tree.global_position = to_plant_in.global_position
	queue_free()

# If the passed in position is on a plantable area, returns the center of that area
func _get_plant_location() -> PlantableArea:
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var collider = result.collider
		if collider is PlantableArea:
			return collider
	
	return null
