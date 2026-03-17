extends Node2D
class_name ThrownObject

var start_pos: Vector2
var target_pos: Vector2
var duration: float = 0.6
var max_height: float = 80.0

var time := 0.0
var is_being_thrown := false

# Meant to be overridden with whatever should happen when the object hits the ground
func on_landed():
	print("Landed!")
	queue_free()

func throw(from: Vector2, to: Vector2, arc_height: float = 80.0, travel_time: float = 0.6):
	start_pos = from
	target_pos = to
	max_height = arc_height
	duration = travel_time
	time = 0.0
	is_being_thrown = true

func _process(delta):
	if not is_being_thrown:return

	time += delta
	var t = clamp(time / duration, 0.0, 1.0)

	var ground_pos = start_pos.lerp(target_pos, t)

	var height = 4.0 * max_height * t * (1.0 - t)

	position = ground_pos - Vector2(0, height)

	if t >= 1.0:
		is_being_thrown = false
		on_landed()

