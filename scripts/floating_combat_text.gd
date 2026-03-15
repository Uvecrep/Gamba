extends Node2D
class_name FloatingCombatText

const DAMAGE_COLOR: Color = Color(1.0, 0.24, 0.24, 1.0)
const HEAL_COLOR: Color = Color(0.28, 0.95, 0.45, 1.0)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.92)
const POOL_MAX_SIZE: int = 200
const MAX_SPAWNS_PER_FRAME: int = 48

static var _pool: Array[FloatingCombatText] = []
static var _spawn_frame: int = -1
static var _spawn_count: int = 0

var _text: String = ""
var _text_color: Color = DAMAGE_COLOR
var _font_size: int = 24
var _motion_tween: Tween
var _fade_tween: Tween

static func _acquire() -> FloatingCombatText:
	while not _pool.is_empty():
		var pooled: FloatingCombatText = _pool.pop_back()
		if is_instance_valid(pooled):
			return pooled

	return FloatingCombatText.new()

static func spawn_damage(target: Node2D, amount: float) -> void:
	_spawn_text(target, amount, false)

static func spawn_heal(target: Node2D, amount: float) -> void:
	_spawn_text(target, amount, true)

static func _spawn_text(target: Node2D, amount: float, is_heal: bool) -> void:
	if target == null or amount <= 0.0:
		return

	var tree: SceneTree = target.get_tree()
	if tree == null:
		return

	var parent_node: Node = tree.current_scene
	if parent_node == null:
		parent_node = target.get_parent()
	if parent_node == null:
		return

	var frame: int = Engine.get_process_frames()
	if frame != _spawn_frame:
		_spawn_frame = frame
		_spawn_count = 0

	if _spawn_count >= MAX_SPAWNS_PER_FRAME:
		return

	_spawn_count += 1

	var text_node: FloatingCombatText = _acquire()
	if text_node.get_parent() != null:
		text_node.get_parent().remove_child(text_node)
	text_node._text = str(int(ceili(amount)))
	text_node._text_color = HEAL_COLOR if is_heal else DAMAGE_COLOR
	text_node.global_position = target.global_position + Vector2(randf_range(-10.0, 10.0), -34.0)
	text_node.visible = true
	parent_node.add_child(text_node)
	text_node._play_animation()

func _draw() -> void:
	if _text.is_empty():
		return

	var draw_font: Font = ThemeDB.fallback_font
	if draw_font == null:
		return

	var text_size: Vector2 = draw_font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size)
	var baseline_offset: float = text_size.y * 0.35
	var draw_position: Vector2 = Vector2(-text_size.x * 0.5, baseline_offset)

	draw_string_outline(draw_font, draw_position, _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size, 3, OUTLINE_COLOR)
	draw_string(draw_font, draw_position, _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size, _text_color)

func _play_animation() -> void:
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()

	modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_redraw()

	var start_position: Vector2 = global_position
	var bounce_peak: Vector2 = start_position + Vector2(randf_range(-8.0, 8.0), -22.0)
	var end_position: Vector2 = start_position + Vector2(randf_range(-10.0, 10.0), -42.0)

	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "global_position", bounce_peak, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "global_position", end_position, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_fade_tween = create_tween()
	_fade_tween.tween_interval(0.45)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.55)
	_fade_tween.tween_callback(Callable(self, "_recycle"))

func _recycle() -> void:
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()

	_motion_tween = null
	_fade_tween = null
	_text = ""
	visible = false

	if get_parent() != null:
		get_parent().remove_child(self)

	if _pool.size() >= POOL_MAX_SIZE:
		queue_free()
		return

	_pool.append(self)
