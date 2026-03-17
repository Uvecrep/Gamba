extends RigidBody2D
class_name Pickup

var start_pos: Vector2
var target_pos: Vector2
var duration: float = 0.6
var max_height: float = 80.0

var time := 0.0
var is_being_thrown := false

@export var item_id : StringName

@export var debug_item_id_label : Label
@export var texture_rect : TextureRect

var floating_towards : Node2D

func _ready() -> void:
	_refresh_visuals()

func set_data(new_item_id : StringName) -> void:
	item_id = new_item_id
	debug_item_id_label.text = new_item_id
	_refresh_visuals()

func _physics_process(_delta: float) -> void:
	if is_being_thrown: return

	apply_force(-linear_velocity * .2) # Apply drag
	
	if floating_towards != null:
		var float_force = pow(floating_towards.position.distance_to(position),2)
		apply_central_force(float_force * position.direction_to(floating_towards.position))

func _refresh_visuals() -> void:
	if not ItemGlobals.items.has(item_id):
		return
	
	var item_data : ItemData = ItemGlobals.items[item_id]

	texture_rect.texture = item_data.texture

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

func on_landed():
	sleeping = false
	print("Landed!")
