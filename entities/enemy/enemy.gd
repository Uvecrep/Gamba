extends CharacterBody2D

@export var move_speed: float = 90.0
@export var repath_interval: float = 0.2
@export var target_reach_distance: float = 32.0
@export var target_stop_padding: float = 2.0
@export var nearby_target_groups: PackedStringArray = ["summons", "players"]
@export var fallback_target_group: StringName = &"house"
@export var nearby_target_radius: float = 180.0
@export var max_health: float = 100.0

const PHYSICS_LAYER_WORLD: int = 1 << 0
const PHYSICS_LAYER_ENEMY: int = 1 << 2

var _current_target: Node2D
var _time_to_repath: float = 0.0
var _current_health: float = 0.0

@onready var _health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_ENEMY
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("enemies")
	_current_health = max_health
	_update_health_bar()

func _physics_process(delta: float) -> void:
	_time_to_repath -= delta
	if _time_to_repath <= 0.0:
		var nearby_target := _find_closest_target_in_groups(nearby_target_groups, nearby_target_radius)
		if is_instance_valid(nearby_target):
			_current_target = nearby_target
		else:
			_current_target = _find_closest_target_in_group(fallback_target_group)
		_time_to_repath = repath_interval

	if is_instance_valid(_current_target):
		var target_distance := global_position.distance_to(_current_target.global_position)
		# Use collider size to avoid pushing into targets and causing sticky contact.
		var stop_distance := _get_stop_distance(_current_target)
		if target_distance > stop_distance:
			velocity = global_position.direction_to(_current_target.global_position) * move_speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	_current_health = clampf(_current_health - amount, 0.0, max_health)
	_update_health_bar()

	if _current_health <= 0.0:
		_die()

func _die() -> void:
	queue_free()

func _update_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = max_health
	_health_bar.value = _current_health
	_health_bar.visible = true

func _find_closest_target_in_groups(group_names: PackedStringArray, radius: float) -> Node2D:
	var closest_target: Node2D
	var closest_distance_sq: float = INF
	var has_radius_limit: bool = radius > 0.0
	var radius_sq: float = radius * radius

	for group_name in group_names:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if candidate == self:
				continue
			if not candidate is Node2D:
				continue

			var candidate_2d := candidate as Node2D
			var distance_sq := global_position.distance_squared_to(candidate_2d.global_position)
			if has_radius_limit and distance_sq > radius_sq:
				continue

			if distance_sq < closest_distance_sq:
				closest_distance_sq = distance_sq
				closest_target = candidate_2d

	return closest_target

func _find_closest_target_in_group(group_name: StringName) -> Node2D:
	if group_name == StringName():
		return null

	var closest_target: Node2D
	var closest_distance_sq: float = INF

	for candidate in get_tree().get_nodes_in_group(group_name):
		if candidate == self:
			continue
		if not candidate is Node2D:
			continue

		var candidate_2d := candidate as Node2D
		var distance_sq := global_position.distance_squared_to(candidate_2d.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_target = candidate_2d

	return closest_target

func _get_stop_distance(target: Node2D) -> float:
	var self_radius := _estimate_collision_radius(self)
	var target_radius := _estimate_collision_radius(target)
	var collision_stop_distance := self_radius + target_radius + target_stop_padding
	return maxf(target_reach_distance, collision_stop_distance)

func _estimate_collision_radius(body: Node2D) -> float:
	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 0.0

	var max_scale := maxf(absf(collision_shape.global_scale.x), absf(collision_shape.global_scale.y))

	if collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		return rect_shape.size.length() * 0.5 * max_scale

	if collision_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		return circle_shape.radius * max_scale

	if collision_shape.shape is CapsuleShape2D:
		var capsule_shape: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		return (capsule_shape.height * 0.5 + capsule_shape.radius) * max_scale

	return 0.0
