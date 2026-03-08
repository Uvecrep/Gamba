extends CharacterBody2D

@export var speed: float = 400.0
@export var starting_lootboxes: int = 0
@export var harvest_range: float = 96.0
@export var harvest_amount_per_interaction: int = 1
@export var harvest_action: StringName = &"interact"
@export var use_lootbox_action: StringName = &"use_lootbox"
@export var summon_scene: PackedScene = preload("res://entities/summon/summon.tscn")
@export var summon_spawn_distance: float = 48.0

signal lootbox_inventory_changed(current: int, previous: int)

const PHYSICS_LAYER_WORLD: int = 1 << 0
const PHYSICS_LAYER_PLAYER: int = 1 << 1

var inventory: PlayerInventory = PlayerInventory.new()

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PHYSICS_LAYER_PLAYER
	collision_mask = PHYSICS_LAYER_WORLD
	add_to_group("players")

	if not inventory.lootboxes_changed.is_connected(_on_inventory_lootboxes_changed):
		inventory.lootboxes_changed.connect(_on_inventory_lootboxes_changed)

	inventory.set_lootbox_count(starting_lootboxes)

func get_lootbox_count() -> int:
	return inventory.get_lootbox_count()

func add_lootboxes(amount: int) -> int:
	return inventory.add_lootboxes(amount)

func try_spend_lootboxes(amount: int) -> bool:
	return inventory.try_spend_lootboxes(amount)

func _on_inventory_lootboxes_changed(current: int, previous: int) -> void:
	lootbox_inventory_changed.emit(current, previous)

func get_input() -> void:
	var input_direction := Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed

func _physics_process(_delta: float) -> void:
	get_input()
	move_and_slide()

	if Input.is_action_just_pressed(harvest_action):
		var nearest_tree := _find_nearest_harvestable_tree()
		if nearest_tree != null:
			var harvested := int(nearest_tree.call("harvest_fruit", harvest_amount_per_interaction))
			if harvested > 0:
				add_lootboxes(harvested)

	if not Input.is_action_just_pressed(use_lootbox_action):
		return
	if summon_scene == null:
		push_warning("Player: summon_scene is not configured; cannot use lootbox.")
		return
	if not try_spend_lootboxes(1):
		return

	if not _spawn_summon_from_lootbox():
		# Refund on spawn failure so lootboxes are not lost by configuration errors.
		add_lootboxes(1)

func _find_nearest_harvestable_tree() -> Node:
	var trees := get_tree().get_nodes_in_group("trees")
	var nearest_tree: Node = null
	var nearest_distance_sq := harvest_range * harvest_range

	for tree in trees:
		if not (tree is Node2D):
			continue
		if not tree.has_method("can_harvest") or not tree.has_method("harvest_fruit"):
			continue
		if not bool(tree.call("can_harvest")):
			continue

		var tree_node := tree as Node2D
		var distance_sq := global_position.distance_squared_to(tree_node.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		nearest_distance_sq = distance_sq
		nearest_tree = tree

	return nearest_tree

func _spawn_summon_from_lootbox() -> bool:
	var summon_node := summon_scene.instantiate() as Node2D
	if summon_node == null:
		push_warning("Player: summon_scene does not instantiate to a Node2D.")
		return false

	if get_tree().current_scene != null:
		get_tree().current_scene.add_child(summon_node)
	elif get_parent() != null:
		get_parent().add_child(summon_node)
	else:
		add_child(summon_node)

	summon_node.global_position = _pick_summon_spawn_position()
	return true

func _pick_summon_spawn_position() -> Vector2:
	var spawn_direction := Vector2.RIGHT.rotated(randf() * TAU)
	return global_position + (spawn_direction * summon_spawn_distance)
