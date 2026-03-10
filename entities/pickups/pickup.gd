extends Area2D
class_name Pickup

func _ready():
	connect("body_entered", _on_body_entered)
	print("helloooooo")

# TODO, can't collide with player???

func _on_body_entered(body):
	if body is Player:
		apply_pickup()

func apply_pickup():
	push_warning("Pickup.apply_Pickup() called on base class.")
	
func dummy_on_entered(body):
	print("helloooooo")
