extends Label

@export var refresh_interval: float = 0.2
@export var sample_count: int = 240
@export var show_vsync_hint: bool = true

var _time_to_refresh: float = 0.0
var _latest_frame_ms: float = 0.0
var _frame_samples_ms: Array[float] = []
var _last_second_samples_ms: Array[float] = []
var _last_second_duration_s: float = 0.0

func _ready() -> void:
	_update_fps_label()

func _process(delta: float) -> void:
	var frame_ms: float = maxf(delta * 1000.0, 0.0)
	_latest_frame_ms = frame_ms
	_push_sample(frame_ms)

	_time_to_refresh -= delta
	if _time_to_refresh > 0.0:
		return

	_time_to_refresh = maxf(refresh_interval, 0.05)
	_update_fps_label()

func _push_sample(frame_ms: float) -> void:
	_frame_samples_ms.append(frame_ms)
	var target_sample_count: int = maxi(sample_count, 30)
	while _frame_samples_ms.size() > target_sample_count:
		_frame_samples_ms.pop_front()

	_last_second_samples_ms.append(frame_ms)
	_last_second_duration_s += frame_ms * 0.001
	while _last_second_duration_s > 1.0 and _last_second_samples_ms.size() > 1:
		var removed_ms: float = _last_second_samples_ms.pop_front()
		_last_second_duration_s = maxf(_last_second_duration_s - (removed_ms * 0.001), 0.0)

func _compute_one_percent_low_fps() -> int:
	if _frame_samples_ms.is_empty():
		return 0

	# 1% low is derived from the slowest 1% frame-time threshold.
	var sorted_samples: Array[float] = _frame_samples_ms.duplicate()
	sorted_samples.sort()
	var percentile_index: int = int(floor((sorted_samples.size() - 1) * 0.99))
	percentile_index = clampi(percentile_index, 0, sorted_samples.size() - 1)
	var slow_frame_ms: float = maxf(sorted_samples[percentile_index], 0.001)
	return int(roundi(1000.0 / slow_frame_ms))

func _compute_worst_frame_last_second_ms() -> float:
	if _last_second_samples_ms.is_empty():
		return 0.0

	var worst_ms: float = 0.0
	for sample_ms in _last_second_samples_ms:
		if sample_ms > worst_ms:
			worst_ms = sample_ms

	return worst_ms

func _update_fps_label() -> void:
	var avg_fps: int = int(roundi(Engine.get_frames_per_second()))
	var one_percent_low_fps: int = _compute_one_percent_low_fps()
	var worst_frame_ms: float = _compute_worst_frame_last_second_ms()

	text = "FPS %d | 1%% %d\nFT %.2f ms | W1 %.2f ms" % [
		avg_fps,
		one_percent_low_fps,
		_latest_frame_ms,
		worst_frame_ms,
	]

	if show_vsync_hint and DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
		text += "\nVSync On (FPS capped to display Hz)"
