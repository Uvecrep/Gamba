extends CharacterBody2D

@export var speed = 400

const PHYSICS_LAYER_WORLD := 1 << 0
const PHYSICS_LAYER_PLAYER := 1 << 1

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_PLAYER
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("players")

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed

func _physics_process(_delta):
	get_input()
	move_and_slide()
