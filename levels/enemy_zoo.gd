extends Node2D

const SUMMON_SCENE: PackedScene = preload("res://entities/summon/summon.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")

const TEX_BABY_DRAGON: Texture2D = preload("res://assets/characters/summons/chaos/baby_dragon.png")
const TEX_SLIME: Texture2D = preload("res://assets/characters/summons/chaos/slime.png")
const TEX_GHOST: Texture2D = preload("res://assets/characters/summons/chaos/ghost.png")
const TEX_SPARK_GOBLIN: Texture2D = preload("res://assets/characters/summons/chaos/spark_goblin.png")
const TEX_JACK: Texture2D = preload("res://assets/characters/summons/chaos/jack_in_the_box.png")
const TEX_MUSHROOM: Texture2D = preload("res://assets/characters/summons/forest/mushroom_knight.png")
const TEX_ACORN: Texture2D = preload("res://assets/characters/summons/forest/acorn_spitter.png")
const TEX_BUSH: Texture2D = preload("res://assets/characters/summons/forest/bush_boy.png")
const TEX_BEE: Texture2D = preload("res://assets/characters/summons/forest/bee_swarm.png")
const TEX_ROOTER: Texture2D = preload("res://assets/characters/summons/forest/rooter.png")

const ENEMY_LAYOUT: Array[Dictionary] = [
	{"archetype": EnemyUnit.ENEMY_ARCHETYPE_BASIC_RAIDER, "position": Vector2(-520, -180)},
	{"archetype": EnemyUnit.ENEMY_ARCHETYPE_FAST_RAIDER, "position": Vector2(-360, -180)},
	{"archetype": EnemyUnit.ENEMY_ARCHETYPE_TANK_RAIDER, "position": Vector2(-200, -180)},
	{"archetype": EnemyUnit.ENEMY_ARCHETYPE_RANGED_RAIDER, "position": Vector2(-40, -180)},
	{"archetype": EnemyUnit.ENEMY_ARCHETYPE_HEALING_RAIDER, "position": Vector2(120, -180)},
	{"archetype": EnemyUnit.ENEMY_ARCHETYPE_TRENCHCOAT_GOBLIN, "position": Vector2(-280, 60)},
	{"archetype": EnemyUnit.ENEMY_ARCHETYPE_GOBLIN, "position": Vector2(-120, 60)},
]

const SUMMON_SPAWN_OPTIONS: Array[Dictionary] = [
	{"identity": &"baby_dragon", "texture": TEX_BABY_DRAGON},
	{"identity": &"slime", "texture": TEX_SLIME},
	{"identity": &"ghost", "texture": TEX_GHOST},
	{"identity": &"spark_goblin", "texture": TEX_SPARK_GOBLIN},
	{"identity": &"jack_in_the_box", "texture": TEX_JACK},
	{"identity": &"mushroom_knight", "texture": TEX_MUSHROOM},
	{"identity": &"acorn_spitter", "texture": TEX_ACORN},
	{"identity": &"bush_boy", "texture": TEX_BUSH},
	{"identity": &"bee_swarm", "texture": TEX_BEE},
	{"identity": &"rooter", "texture": TEX_ROOTER},
]

@export var summon_spawn_cooldown_seconds: float = 0.18

@onready var _player: Node2D = get_node_or_null("player") as Node2D
@onready var _selection_controller: Node = get_node_or_null("SummonSelectionController")

var _summon_spawn_cooldown_left: float = 0.0
var _is_shutting_down: bool = false
var _tracked_enemy_instance_ids: Dictionary = {}

func _ready() -> void:
	randomize()
	_is_shutting_down = false
	_ensure_navigation_region()
	_spawn_all_showcase_enemies()

func _exit_tree() -> void:
	_is_shutting_down = true

func _process(delta: float) -> void:
	_summon_spawn_cooldown_left = maxf(_summon_spawn_cooldown_left - delta, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_issue_world_move_order(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return

	if not event.is_action_pressed(&"use_lootbox"):
		return
	if _summon_spawn_cooldown_left > 0.0:
		return

	_spawn_summon()
	_summon_spawn_cooldown_left = summon_spawn_cooldown_seconds
	get_viewport().set_input_as_handled()

func _issue_world_move_order(world_position: Vector2) -> void:
	if not is_instance_valid(_selection_controller):
		return
	if not _selection_controller is ZooSummonSelectionController:
		return

	(_selection_controller as ZooSummonSelectionController).issue_move_order_world(world_position)

func _ensure_navigation_region() -> void:
	var existing_region: NavigationRegion2D = get_node_or_null("WorldNavigationRegion") as NavigationRegion2D
	if existing_region != null:
		return

	var region := NavigationRegion2D.new()
	region.name = "WorldNavigationRegion"

	var nav_polygon := NavigationPolygon.new()
	var vertices := PackedVector2Array([
		Vector2(-1800.0, -1000.0),
		Vector2(1800.0, -1000.0),
		Vector2(1800.0, 1000.0),
		Vector2(-1800.0, 1000.0),
	])
	nav_polygon.set_vertices(vertices)
	nav_polygon.add_polygon(PackedInt32Array([0, 1, 2]))
	nav_polygon.add_polygon(PackedInt32Array([0, 2, 3]))

	region.navigation_polygon = nav_polygon
	add_child(region)

func _spawn_all_showcase_enemies() -> void:
	for entry in ENEMY_LAYOUT:
		var archetype: StringName = StringName(entry.get("archetype", EnemyUnit.ENEMY_ARCHETYPE_BASIC_RAIDER))
		var spawn_position: Vector2 = entry.get("position", Vector2.ZERO)
		_spawn_zoo_enemy(archetype, spawn_position)

func _spawn_zoo_enemy(archetype: StringName, spawn_position: Vector2) -> Node2D:
	if ENEMY_SCENE == null:
		return null

	var enemy := ENEMY_SCENE.instantiate() as Node2D
	if enemy == null:
		return null

	if enemy is EnemyUnit:
		(enemy as EnemyUnit).set_enemy_archetype(archetype)

	add_child(enemy)
	enemy.global_position = spawn_position
	_register_spawned_enemy(enemy, archetype, spawn_position)
	return enemy

func _register_spawned_enemy(enemy: Node2D, archetype: StringName, spawn_position: Vector2) -> void:
	if not is_instance_valid(enemy):
		return

	var instance_id: int = enemy.get_instance_id()
	if _tracked_enemy_instance_ids.has(instance_id):
		return

	_tracked_enemy_instance_ids[instance_id] = true
	enemy.set_meta("zoo_enemy_archetype", archetype)
	enemy.set_meta("zoo_spawn_position", spawn_position)

	var on_exit: Callable = Callable(self, "_on_zoo_enemy_tree_exiting").bind(enemy, instance_id)
	if not enemy.tree_exiting.is_connected(on_exit):
		enemy.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)

func _on_zoo_enemy_tree_exiting(enemy: Node2D, instance_id: int) -> void:
	_tracked_enemy_instance_ids.erase(instance_id)
	if _is_shutting_down or not is_inside_tree():
		return
	if not is_instance_valid(enemy):
		return

	var archetype: StringName = _resolve_enemy_archetype(enemy)
	var spawn_position: Vector2 = enemy.global_position
	if enemy.has_meta("zoo_spawn_position"):
		var spawn_position_meta: Variant = enemy.get_meta("zoo_spawn_position")
		if spawn_position_meta is Vector2:
			spawn_position = spawn_position_meta as Vector2

	call_deferred("_respawn_zoo_enemy", archetype, spawn_position)

func _resolve_enemy_archetype(enemy: Node2D) -> StringName:
	if enemy.has_meta("zoo_enemy_archetype"):
		return StringName(enemy.get_meta("zoo_enemy_archetype"))

	var archetype_variant: Variant = enemy.get("enemy_archetype")
	if archetype_variant is StringName:
		return archetype_variant as StringName
	if archetype_variant is String:
		return StringName(archetype_variant)

	return EnemyUnit.ENEMY_ARCHETYPE_BASIC_RAIDER

func _respawn_zoo_enemy(archetype: StringName, spawn_position: Vector2) -> void:
	if _is_shutting_down or not is_inside_tree():
		return

	_spawn_zoo_enemy(archetype, spawn_position)

func _spawn_summon() -> void:
	if SUMMON_SCENE == null:
		return
	if not is_instance_valid(_player):
		return
	if SUMMON_SPAWN_OPTIONS.is_empty():
		return

	var random_profile: Dictionary = SUMMON_SPAWN_OPTIONS[randi() % SUMMON_SPAWN_OPTIONS.size()]
	var summon_identity: StringName = StringName(random_profile.get("identity", &"mushroom_knight"))
	var summon_texture: Texture2D = random_profile.get("texture") as Texture2D

	var summon := SUMMON_SCENE.instantiate() as Node2D
	if summon == null:
		return

	if summon is SummonUnit:
		(summon as SummonUnit).set_summon_identity(summon_identity)
	else:
		summon.set("summon_identity", summon_identity)

	if summon_texture != null:
		summon.set("sprite_texture_override", summon_texture)

	add_child(summon)
	var spawn_offset := Vector2(randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
	summon.global_position = _player.global_position + spawn_offset
