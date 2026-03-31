extends RigidBody2D
class_name Pickup

const PICKUP_OUTLINE_SHADER: Shader = preload("res://entities/pickups/pickup_outline_white.gdshader")


@export var item_id : StringName
@export var can_be_magnetized: bool = true

@export var debug_item_id_label : Label
@export var texture_rect : TextureRect
@export var sprite_2d : Sprite2D

var _interaction_collision_shape: CollisionShape2D
var _base_interaction_shape_scale: Vector2 = Vector2.ONE

var bob_amplitude: float = 2.3
var bob_speed: float = 0.4
var bob_start_position: Vector2
var bob_time: float
var should_bob: bool = true

var floating_towards : Node2D

func _ready() -> void:
	_resolve_visual_nodes()
	_resolve_interaction_collision_shape()
	_refresh_visuals()

func set_interaction_radius_multiplier(multiplier: float) -> void:
	_resolve_interaction_collision_shape()
	if _interaction_collision_shape == null:
		return

	var safe_multiplier: float = maxf(multiplier, 0.1)
	_interaction_collision_shape.scale = _base_interaction_shape_scale * safe_multiplier

func set_data(new_item_id : StringName) -> void:
	_resolve_visual_nodes()
	item_id = new_item_id
	if debug_item_id_label != null:
		debug_item_id_label.text = String(new_item_id)
	_refresh_visuals()

func _process(_delta: float) -> void:
	if not should_bob: return
	if bob_time == 0: bob_start_position = position
	bob_time += _delta
	var offset_y = sin(bob_time * bob_speed * PI * 2) * bob_amplitude
	position.y = bob_start_position.y + offset_y

func _physics_process(_delta: float) -> void:
	apply_force(-linear_velocity * .2) # Apply drag
	
	if floating_towards != null:
		var target_global_position: Vector2 = floating_towards.global_position
		var float_force: float = pow(global_position.distance_to(target_global_position), 2)
		apply_central_force(float_force * global_position.direction_to(target_global_position))

func _refresh_visuals() -> void:
	if not ItemGlobals.items.has(item_id):
		return
	
	var item_data : ItemData = ItemGlobals.items[item_id]

	if texture_rect != null:
		texture_rect.visible = false
		texture_rect.texture = item_data.texture
	if sprite_2d != null:
		sprite_2d.visible = true
		sprite_2d.texture = item_data.texture

# This is a goofy pattern. If a variable is marked as an export and not properly set in scene it should be expected to fail, cause errors, etc
# Having this kind of fallback code is basically writing the node path in two seperate places
func _resolve_visual_nodes() -> void:
	if debug_item_id_label == null:
		debug_item_id_label = get_node_or_null("Label") as Label
	if texture_rect == null:
		texture_rect = get_node_or_null("TextureRect") as TextureRect
	if texture_rect != null:
		texture_rect.visible = false
	if sprite_2d == null:
		sprite_2d = get_node_or_null("Sprite2D") as Sprite2D
	_ensure_outline_material()

func _ensure_outline_material() -> void:
	if sprite_2d == null:
		return

	var existing_material := sprite_2d.material as ShaderMaterial
	if existing_material != null and existing_material.shader == PICKUP_OUTLINE_SHADER:
		return

	var outline_material := ShaderMaterial.new()
	outline_material.shader = PICKUP_OUTLINE_SHADER
	sprite_2d.material = outline_material

func _resolve_interaction_collision_shape() -> void:
	if _interaction_collision_shape != null:
		return

	_interaction_collision_shape = get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if _interaction_collision_shape != null:
		_base_interaction_shape_scale = _interaction_collision_shape.scale
