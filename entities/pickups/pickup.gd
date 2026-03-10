extends Area2D
class_name Pickup

func _ready() -> void:
	# Pickups should only react to player bodies.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		apply_pickup()

func apply_pickup() -> void:
	push_warning("Collision Detected")
