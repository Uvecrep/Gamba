extends TextureRect

@export var line_to_follow: Line2D

func _process(delta: float) -> void:
	var rot = (line_to_follow.points[1] - position).angle() - PI/2

	rotation = rot

	size.y = (line_to_follow.points[1] - position).length()
