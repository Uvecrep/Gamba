extends Area2D
class_name Pickup

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		apply_pickup(body)

func apply_pickup(player : Player) -> void:
		push_warning("pickup.apply_pickup() called on base class.")
