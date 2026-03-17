extends Node2D
class_name ThrownObject

var start_pos: Vector2
var target_pos: Vector2
var duration: float = 0.6
var max_height: float = 80.0

var time := 0.0


# Meant to be overridden with whatever should happen when the object hits the ground
func on_landed():
	print("Landed!")

func _process(delta):
	time += delta
	var t = clamp(time / duration, 0.0, 1.0)

	var ground_pos = start_pos.lerp(target_pos, t)

	var height = 4.0 * max_height * t * (1.0 - t)

	position = ground_pos - Vector2(0, height)

	if t >= 1.0:
		on_landed()
		queue_free()

