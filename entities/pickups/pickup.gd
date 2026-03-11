extends Area2D
class_name Pickup

@export var item_id : StringName

func _ready() -> void:
	# Pickups should only react to player bodies.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return

	var player: Player = body as Player
	if apply_pickup(player):
		queue_free()

func apply_pickup(player: Player) -> bool:
	return player.inventory.add_items(item_id,1)
	#push_warning("Pickup: apply_pickup() is not implemented for this pickup type.")
