extends ThrownObject
class_name ThrownSapling

@export var sapling_tree_packed_scene : PackedScene
@export var pickup_packed_scene : PackedScene

# Meant to be overridden with whatever should happen when the object hits the ground
func on_landed():
	var landed_plantable: PlantableArea = _get_plantable_area_at_landing()
	var to_plant_in : PlantableArea = null
	if landed_plantable != null and not landed_plantable.is_occupied:
		landed_plantable.is_occupied = true
		to_plant_in = landed_plantable
	
	# Spawn pickup if you didn't hit an area
	# TODO maybe I should not let player throw at all in that case | Ian: Yeah, that feels more intuitive to me too
	if not to_plant_in: 
		var new_pickup: Pickup = pickup_packed_scene.instantiate()
		get_parent().add_child(new_pickup)
		new_pickup.global_position = _get_fallback_pickup_position(landed_plantable)
		new_pickup.set_data("sapling")
		queue_free()
		return

	var new_tree: Node = sapling_tree_packed_scene.instantiate()
	get_parent().add_child(new_tree)
	new_tree.global_position = to_plant_in.global_position
	queue_free()

func _get_fallback_pickup_position(blocking_plantable: PlantableArea) -> Vector2:
	if blocking_plantable == null:
		return global_position

	var drop_direction: Vector2 = (target_pos - start_pos).normalized()
	if drop_direction == Vector2.ZERO:
		drop_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))

	var from_center: Vector2 = global_position - blocking_plantable.global_position
	if from_center.length_squared() > 0.0001:
		drop_direction = from_center.normalized()

	var drop_distance: float = 74.0
	return blocking_plantable.global_position + (drop_direction * drop_distance)

func _get_plantable_area_at_landing() -> PlantableArea:
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var collider = result.collider
		if collider is PlantableArea:
			return collider as PlantableArea
	
	return null
