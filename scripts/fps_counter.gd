extends Label

@export var refresh_interval: float = 0.25

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
	text = "FPS: %d" % int(roundi(Engine.get_frames_per_second()))
