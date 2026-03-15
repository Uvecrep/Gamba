extends RigidBody2D
class_name Pickup

@export var item_id : StringName
@export var debug_item_id_label : Label

var floating_towards : Node2D

#func _ready() -> void:
	#if not $Area2D: return
	## Pickups should only react to player bodies.
	#if not $Area2D.body_entered.is_connected(_on_body_entered):
		#$Area2D.body_entered.connect(_on_body_entered)

func set_data(new_item_id : StringName) -> void:
	item_id = new_item_id
	debug_item_id_label.text = new_item_id
	# apply visuals and stuff

func _physics_process(_delta: float) -> void:
	
	apply_force(-linear_velocity * .2) # Apply drag
	
	if floating_towards != null:
		var float_force = pow(floating_towards.position.distance_to(position),2)
		apply_central_force(float_force * position.direction_to(floating_towards.position))
