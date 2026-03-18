extends ThrownObject
class_name ThrownSapling

@export var sapling_tree_packed_scene : PackedScene

# Meant to be overridden with whatever should happen when the object hits the ground
func on_landed():
	var new_tree: Node = sapling_tree_packed_scene.instantiate()
	get_parent().add_child(new_tree)
	new_tree.global_position = global_position
	queue_free()
