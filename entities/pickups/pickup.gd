extends RigidBody2D
class_name Pickup

@export var item_id : StringName

var floating_towards : Node2D

#func _ready() -> void:
	#if not $Area2D: return
	## Pickups should only react to player bodies.
	#if not $Area2D.body_entered.is_connected(_on_body_entered):
		#$Area2D.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if floating_towards != null:
		var float_force = pow(floating_towards.position.distance_to(position),2)
		apply_central_force(float_force * position.direction_to(floating_towards.position))
