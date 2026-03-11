extends RigidBody2D
class_name Pickup

@export var item_id : StringName

var floating_to : Node2D

func _ready() -> void:
	if not $Area2D: return
	# Pickups should only react to player bodies.
	if not $Area2D.body_entered.is_connected(_on_body_entered):
		$Area2D.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if floating_to != null:
		var float_force = pow(floating_to.position.distance_to(position),2)
		apply_central_force(float_force * position.direction_to(floating_to.position))

func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return

	var player: Player = body as Player
	if apply_pickup(player):
		queue_free()

func apply_pickup(player: Player) -> bool:
	return player.inventory.add_items(item_id,1)
	#push_warning("Pickup: apply_pickup() is not implemented for this pickup type.")
