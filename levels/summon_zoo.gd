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
const TEX_CINDER_IMP: Texture2D = preload("res://assets/characters/summons/elemental/cinder_imp.png")
const TEX_FROST_WISP: Texture2D = preload("res://assets/characters/summons/elemental/frost_wisp.png")
const TEX_MAGMA_BEETLE: Texture2D = preload("res://assets/characters/summons/elemental/magma_beetle.png")
const TEX_STORM_TOTEM: Texture2D = preload("res://assets/characters/summons/elemental/storm_totem.png")
const TEX_UNSTABLE_SHARD: Texture2D = preload("res://assets/characters/summons/elemental/unstable_shard.png")
const TEX_SOUL_LANTERN: Texture2D = preload("res://assets/characters/summons/spirit/soul_lantern.png")
const TEX_BANSHEE: Texture2D = preload("res://assets/characters/summons/spirit/banshee.png")
const TEX_GRAVE_HOUND: Texture2D = preload("res://assets/characters/summons/spirit/grave_hound.png")
const TEX_HEX_DOLL: Texture2D = preload("res://assets/characters/summons/spirit/hex_doll.png")
const TEX_POSSESSOR: Texture2D = preload("res://assets/characters/summons/spirit/possessor.png")
const TEX_MIMIC: Texture2D = preload("res://assets/characters/summons/greed/mimic.png")
const TEX_COIN_SPRITE: Texture2D = preload("res://assets/characters/summons/greed/coin_sprite.png")
const TEX_PROSPECTOR: Texture2D = preload("res://assets/characters/summons/greed/prospector.png")
const TEX_GOLDEN_GUNNER: Texture2D = preload("res://assets/characters/summons/greed/golden_gunner.png")
const TEX_TAX_COLLECTOR: Texture2D = preload("res://assets/characters/summons/greed/tax_collector.png")
const ID_SLIME: StringName = &"slime"

const SUMMON_LAYOUT: Array[Dictionary] = [
	{"identity": &"baby_dragon", "texture": TEX_BABY_DRAGON, "position": Vector2(-520, -360)},
	{"identity": &"slime", "texture": TEX_SLIME, "position": Vector2(-360, -360)},
	{"identity": &"ghost", "texture": TEX_GHOST, "position": Vector2(-200, -360)},
	{"identity": &"spark_goblin", "texture": TEX_SPARK_GOBLIN, "position": Vector2(-40, -360)},
	{"identity": &"jack_in_the_box", "texture": TEX_JACK, "position": Vector2(120, -360)},
	{"identity": &"mushroom_knight", "texture": TEX_MUSHROOM, "position": Vector2(-520, -180)},
	{"identity": &"acorn_spitter", "texture": TEX_ACORN, "position": Vector2(-360, -180)},
	{"identity": &"bush_boy", "texture": TEX_BUSH, "position": Vector2(-200, -180)},
	{"identity": &"bee_swarm", "texture": TEX_BEE, "position": Vector2(-40, -180)},
	{"identity": &"rooter", "texture": TEX_ROOTER, "position": Vector2(120, -180)},
	{"identity": &"cinder_imp", "texture": TEX_CINDER_IMP, "position": Vector2(-520, 0)},
	{"identity": &"frost_wisp", "texture": TEX_FROST_WISP, "position": Vector2(-360, 0)},
	{"identity": &"magma_beetle", "texture": TEX_MAGMA_BEETLE, "position": Vector2(-200, 0)},
	{"identity": &"storm_totem", "texture": TEX_STORM_TOTEM, "position": Vector2(-40, 0)},
	{"identity": &"unstable_shard", "texture": TEX_UNSTABLE_SHARD, "position": Vector2(120, 0)},
	{"identity": &"soul_lantern", "texture": TEX_SOUL_LANTERN, "position": Vector2(-520, 180)},
	{"identity": &"banshee", "texture": TEX_BANSHEE, "position": Vector2(-360, 180)},
	{"identity": &"grave_hound", "texture": TEX_GRAVE_HOUND, "position": Vector2(-200, 180)},
	{"identity": &"hex_doll", "texture": TEX_HEX_DOLL, "position": Vector2(-40, 180)},
	{"identity": &"possessor", "texture": TEX_POSSESSOR, "position": Vector2(120, 180)},
	{"identity": &"mimic", "texture": TEX_MIMIC, "position": Vector2(-520, 360)},
	{"identity": &"coin_sprite", "texture": TEX_COIN_SPRITE, "position": Vector2(-360, 360)},
	{"identity": &"prospector", "texture": TEX_PROSPECTOR, "position": Vector2(-200, 360)},
	{"identity": &"golden_gunner", "texture": TEX_GOLDEN_GUNNER, "position": Vector2(-40, 360)},
	{"identity": &"tax_collector", "texture": TEX_TAX_COLLECTOR, "position": Vector2(120, 360)},
]

@export var enemy_spawn_cooldown_seconds: float = 0.18

@onready var _player: Node2D = get_node_or_null("player") as Node2D
@onready var _selection_controller: Node = get_node_or_null("SummonSelectionController")

var _enemy_spawn_cooldown_left: float = 0.0
var _is_shutting_down: bool = false
var _tracked_summon_instance_ids: Dictionary = {}
var _summon_profile_by_identity: Dictionary = {}

func _ready() -> void:
	randomize()
	_is_shutting_down = false
	_initialize_summon_profile_lookup()
	_ensure_navigation_region()
	_spawn_all_showcase_summons()
	_connect_untracked_summons()

func _exit_tree() -> void:
	_is_shutting_down = true

func _process(delta: float) -> void:
	_enemy_spawn_cooldown_left = maxf(_enemy_spawn_cooldown_left - delta, 0.0)
	_connect_untracked_summons()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_issue_world_move_order(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return

	if not event.is_action_pressed(&"use_lootbox"):
		return
	if _enemy_spawn_cooldown_left > 0.0:
		return

	_spawn_enemy()
	_enemy_spawn_cooldown_left = enemy_spawn_cooldown_seconds
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

func _spawn_all_showcase_summons() -> void:
	for entry in SUMMON_LAYOUT:
		_create_showcase_summon(entry)

func _create_showcase_summon(entry: Dictionary) -> void:
	var identity: StringName = StringName(entry.get("identity", &"mushroom_knight"))
	var texture: Texture2D = entry.get("texture") as Texture2D
	var spawn_position: Vector2 = entry.get("position", Vector2.ZERO)
	_spawn_zoo_summon(identity, texture, spawn_position)

func _spawn_zoo_summon(identity: StringName, texture: Texture2D, spawn_position: Vector2) -> Node2D:
	if SUMMON_SCENE == null:
		return null

	var summon := SUMMON_SCENE.instantiate() as Node2D
	if summon == null:
		return null

	if summon is SummonUnit:
		(summon as SummonUnit).set_summon_identity(identity)
	else:
		summon.set("summon_identity", identity)

	summon.set("sprite_texture_override", texture)
	add_child(summon)
	summon.global_position = spawn_position

	if summon is SummonUnit:
		(summon as SummonUnit).set_hold_position(true)

	_register_spawned_summon(summon, identity, texture, spawn_position)
	return summon

func _register_spawned_summon(summon: Node2D, identity: StringName, texture: Texture2D, spawn_position: Vector2) -> void:
	if not is_instance_valid(summon):
		return

	var instance_id: int = summon.get_instance_id()
	if _tracked_summon_instance_ids.has(instance_id):
		return

	_tracked_summon_instance_ids[instance_id] = true
	summon.set_meta("zoo_identity", identity)
	summon.set_meta("zoo_spawn_position", spawn_position)
	if texture != null:
		summon.set_meta("zoo_texture", texture)

	var on_exit: Callable = Callable(self, "_on_zoo_summon_tree_exiting").bind(summon, instance_id)
	if not summon.tree_exiting.is_connected(on_exit):
		summon.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)

func _connect_untracked_summons() -> void:
	for candidate in get_tree().get_nodes_in_group("summons"):
		if not (candidate is Node2D):
			continue

		var summon: Node2D = candidate as Node2D
		var instance_id: int = summon.get_instance_id()
		if _tracked_summon_instance_ids.has(instance_id):
			continue

		var identity: StringName = _resolve_summon_identity(summon)
		var texture: Texture2D = _resolve_summon_texture(summon, identity)
		_register_spawned_summon(summon, identity, texture, summon.global_position)

func _resolve_summon_identity(summon: Node2D) -> StringName:
	if summon.has_meta("zoo_identity"):
		return StringName(summon.get_meta("zoo_identity"))

	var identity_variant: Variant = summon.get("summon_identity")
	if identity_variant is StringName:
		return identity_variant as StringName
	if identity_variant is String:
		return StringName(identity_variant)

	return &"mushroom_knight"

func _resolve_summon_texture(summon: Node2D, identity: StringName) -> Texture2D:
	if summon.has_meta("zoo_texture"):
		var meta_texture: Variant = summon.get_meta("zoo_texture")
		if meta_texture is Texture2D:
			return meta_texture as Texture2D

	var sprite: Sprite2D = summon.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.texture != null:
		return sprite.texture

	if _summon_profile_by_identity.has(identity):
		var profile: Dictionary = _summon_profile_by_identity[identity]
		var profile_texture: Variant = profile.get("texture")
		if profile_texture is Texture2D:
			return profile_texture as Texture2D

	return null

func _on_zoo_summon_tree_exiting(summon: Node2D, instance_id: int) -> void:
	_tracked_summon_instance_ids.erase(instance_id)
	if _is_shutting_down or not is_inside_tree():
		return
	if not is_instance_valid(summon):
		return

	var identity: StringName = _resolve_summon_identity(summon)
	var texture: Texture2D = _resolve_summon_texture(summon, identity)
	var spawn_position: Vector2 = summon.global_position
	if summon.has_meta("zoo_spawn_position"):
		var spawn_position_meta: Variant = summon.get_meta("zoo_spawn_position")
		if spawn_position_meta is Vector2:
			spawn_position = spawn_position_meta as Vector2

	if identity == ID_SLIME:
		call_deferred("_respawn_slime_when_lineage_cleared", texture, spawn_position)
		return

	call_deferred("_respawn_zoo_summon", identity, texture, spawn_position)

func _respawn_zoo_summon(identity: StringName, texture: Texture2D, spawn_position: Vector2) -> void:
	if _is_shutting_down or not is_inside_tree():
		return

	_spawn_zoo_summon(identity, texture, spawn_position)

func _respawn_slime_when_lineage_cleared(texture: Texture2D, fallback_spawn_position: Vector2) -> void:
	if _is_shutting_down or not is_inside_tree():
		return
	if _has_alive_summon_identity(ID_SLIME):
		return

	var spawn_position: Vector2 = fallback_spawn_position
	var respawn_texture: Texture2D = texture
	if _summon_profile_by_identity.has(ID_SLIME):
		var profile: Dictionary = _summon_profile_by_identity[ID_SLIME]
		var profile_spawn_position: Variant = profile.get("spawn_position")
		if profile_spawn_position is Vector2:
			spawn_position = profile_spawn_position as Vector2

		var profile_texture: Variant = profile.get("texture")
		if profile_texture is Texture2D:
			respawn_texture = profile_texture as Texture2D

	_spawn_zoo_summon(ID_SLIME, respawn_texture, spawn_position)

func _has_alive_summon_identity(identity: StringName) -> bool:
	for candidate in get_tree().get_nodes_in_group("summons"):
		if not (candidate is Node2D):
			continue

		var summon: Node2D = candidate as Node2D
		if _resolve_summon_identity(summon) != identity:
			continue

		return true

	return false

func _initialize_summon_profile_lookup() -> void:
	_summon_profile_by_identity.clear()
	for entry in SUMMON_LAYOUT:
		var identity: StringName = StringName(entry.get("identity", &"mushroom_knight"))
		_summon_profile_by_identity[identity] = {
			"texture": entry.get("texture") as Texture2D,
			"spawn_position": entry.get("position", Vector2.ZERO),
		}

func _spawn_enemy() -> void:
	if ENEMY_SCENE == null:
		return
	if not is_instance_valid(_player):
		return

	var enemy := ENEMY_SCENE.instantiate() as Node2D
	if enemy == null:
		return

	add_child(enemy)
	enemy.global_position = _player.global_position
