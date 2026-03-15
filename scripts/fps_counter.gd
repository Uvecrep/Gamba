extends Label

@export var refresh_interval: float = 0.2

var _time_to_refresh: float = 0.0

func _ready() -> void:
	_update_fps_label()

func _process(delta: float) -> void:
	_time_to_refresh -= delta
	if _time_to_refresh > 0.0:
		return

	_time_to_refresh = maxf(refresh_interval, 0.05)
	_update_fps_label()

func _update_fps_label() -> void:
	var avg_fps: int = int(roundi(Engine.get_frames_per_second()))
	text = "FPS: %d" % avg_fps
