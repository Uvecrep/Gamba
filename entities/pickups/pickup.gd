extends RigidBody2D
class_name Pickup


@export var item_id : StringName
@export var can_be_magnetized: bool = true

@export var debug_item_id_label : Label
@export var texture_rect : TextureRect
@export var sprite_2d : Sprite2D

var floating_towards : Node2D

func _ready() -> void:
	_resolve_visual_nodes()
	_refresh_visuals()

func set_data(new_item_id : StringName) -> void:
	_resolve_visual_nodes()
	item_id = new_item_id
	if debug_item_id_label != null:
		debug_item_id_label.text = String(new_item_id)
	_refresh_visuals()

func _physics_process(_delta: float) -> void:
	apply_force(-linear_velocity * .2) # Apply drag
	
	if floating_towards != null:
		var float_force = pow(floating_towards.position.distance_to(position),2)
		apply_central_force(float_force * position.direction_to(floating_towards.position))

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

func _resolve_visual_nodes() -> void:
	if debug_item_id_label == null:
		debug_item_id_label = get_node_or_null("Label") as Label
	if texture_rect == null:
		texture_rect = get_node_or_null("TextureRect") as TextureRect
	if texture_rect != null:
		texture_rect.visible = false
	if sprite_2d == null:
		sprite_2d = get_node_or_null("Sprite2D") as Sprite2D
