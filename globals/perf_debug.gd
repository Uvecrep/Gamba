extends Node
class_name PerfDebugService

@export var enabled: bool = false
@export var summary_interval_seconds: float = 1.5
@export var frame_spike_ms_threshold: float = 24.0
@export var scope_spike_ms_threshold: float = 6.0
@export var max_scope_lines: int = 8
@export var max_counter_lines: int = 6
@export var min_spike_log_interval_seconds: float = 0.15

var _scope_total_us: Dictionary = {}
var _scope_calls: Dictionary = {}
var _scope_max_us: Dictionary = {}
var _counter_totals: Dictionary = {}
var _interval_elapsed: float = 0.0
var _last_physics_frame: int = -1
var _physics_frame_total_us: int = 0
var _last_spike_log_time_s: float = -INF

func _process(delta: float) -> void:
	if not enabled:
		_interval_elapsed = 0.0
		return

	_interval_elapsed += maxf(delta, 0.0)
	if _interval_elapsed < maxf(summary_interval_seconds, 0.2):
		return

	_emit_summary()
	_clear_interval_stats()
	_interval_elapsed = 0.0

func add_scope_time_us(scope_name: StringName, elapsed_us: int, metadata: Dictionary = {}) -> void:
	if not enabled:
		return
	if elapsed_us <= 0:
		return

	var key: StringName = scope_name
	_scope_total_us[key] = int(_scope_total_us.get(key, 0)) + elapsed_us
	_scope_calls[key] = int(_scope_calls.get(key, 0)) + 1
	_scope_max_us[key] = maxi(int(_scope_max_us.get(key, 0)), elapsed_us)

	var spike_threshold_us: int = int(maxf(scope_spike_ms_threshold, 0.5) * 1000.0)
	if elapsed_us >= spike_threshold_us:
		_emit_scope_spike(key, elapsed_us, metadata)

func add_physics_scope_time_us(scope_name: StringName, elapsed_us: int, metadata: Dictionary = {}) -> void:
	if not enabled:
		return

	add_scope_time_us(scope_name, elapsed_us, metadata)

	var current_frame: int = Engine.get_physics_frames()
	if _last_physics_frame < 0:
		_last_physics_frame = current_frame

	if current_frame != _last_physics_frame:
		_emit_physics_frame_spike_if_needed(_last_physics_frame, _physics_frame_total_us)
		_last_physics_frame = current_frame
		_physics_frame_total_us = 0

	_physics_frame_total_us += maxi(elapsed_us, 0)

func increment_counter(counter_name: StringName, amount: int = 1) -> void:
	if not enabled:
		return
	if amount == 0:
		return

	var key: StringName = counter_name
	_counter_totals[key] = int(_counter_totals.get(key, 0)) + amount

func mark_event(event_name: String, metadata: Dictionary = {}) -> void:
	if not enabled:
		return

	var details: String = ""
	if not metadata.is_empty():
		details = " | %s" % [str(metadata)]
	print("[PerfDebug] Event %s%s" % [event_name, details])

func _emit_summary() -> void:
	var scope_lines: Array[String] = _build_top_scope_lines()
	var counter_lines: Array[String] = _build_top_counter_lines()

	var header: String = "[PerfDebug] %.2fs summary" % _interval_elapsed
	header += " | scopes=%d" % _scope_total_us.size()
	header += " | counters=%d" % _counter_totals.size()
	print(header)

	if scope_lines.is_empty():
		print("[PerfDebug]   no scope samples")
	else:
		for line in scope_lines:
			print("[PerfDebug]   %s" % line)

	if not counter_lines.is_empty():
		for line in counter_lines:
			print("[PerfDebug]   %s" % line)

func _build_top_scope_lines() -> Array[String]:
	var lines: Array[String] = []
	if _scope_total_us.is_empty():
		return lines

	var keys: Array = _scope_total_us.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(_scope_total_us.get(a, 0)) > int(_scope_total_us.get(b, 0))
	)

	var max_lines: int = mini(maxi(max_scope_lines, 1), keys.size())
	for i in range(max_lines):
		var key: Variant = keys[i]
		var total_us: int = int(_scope_total_us.get(key, 0))
		var calls: int = int(_scope_calls.get(key, 0))
		var max_us: int = int(_scope_max_us.get(key, 0))
		var avg_us: float = 0.0
		if calls > 0:
			avg_us = float(total_us) / float(calls)

		lines.append("scope=%s total=%.2fms avg=%.2fms max=%.2fms calls=%d" % [
			str(key),
			float(total_us) / 1000.0,
			avg_us / 1000.0,
			float(max_us) / 1000.0,
			calls,
		])

	return lines

func _build_top_counter_lines() -> Array[String]:
	var lines: Array[String] = []
	if _counter_totals.is_empty():
		return lines

	var keys: Array = _counter_totals.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(_counter_totals.get(a, 0)) > int(_counter_totals.get(b, 0))
	)

	var max_lines: int = mini(maxi(max_counter_lines, 1), keys.size())
	for i in range(max_lines):
		var key: Variant = keys[i]
		lines.append("counter=%s value=%d" % [str(key), int(_counter_totals.get(key, 0))])

	return lines

func _emit_physics_frame_spike_if_needed(frame_id: int, frame_total_us: int) -> void:
	if frame_total_us <= 0:
		return

	var frame_threshold_us: int = int(maxf(frame_spike_ms_threshold, 1.0) * 1000.0)
	if frame_total_us < frame_threshold_us:
		return

	if not _can_emit_spike_log():
		return

	print("[PerfDebug] Physics frame spike frame=%d scripted=%.2fms" % [frame_id, float(frame_total_us) / 1000.0])

func _emit_scope_spike(scope_name: StringName, elapsed_us: int, metadata: Dictionary) -> void:
	if not _can_emit_spike_log():
		return

	var details: String = ""
	if not metadata.is_empty():
		details = " | %s" % [str(metadata)]

	print("[PerfDebug] Scope spike scope=%s time=%.2fms%s" % [
		str(scope_name),
		float(elapsed_us) / 1000.0,
		details,
	])

func _can_emit_spike_log() -> bool:
	var now_s: float = Time.get_ticks_msec() * 0.001
	if (now_s - _last_spike_log_time_s) < maxf(min_spike_log_interval_seconds, 0.01):
		return false

	_last_spike_log_time_s = now_s
	return true

func _clear_interval_stats() -> void:
	_scope_total_us.clear()
	_scope_calls.clear()
	_scope_max_us.clear()
	_counter_totals.clear()
