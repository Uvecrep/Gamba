extends LootboxOutcome
class_name LootboxOutcomeSpawnSummon

@export var summon_scene: PackedScene = preload("res://entities/summon/summon.tscn")
@export var spawn_distance: float = 48.0
@export var damage_multiplier: float = 1.0
@export var max_health_multiplier: float = 1.0
@export var summon_texture_override: Texture2D
@export var summon_identity: StringName

func execute(context: Dictionary = {}) -> bool:
	var opener := context.get("opener") as Node2D
	if opener == null:
		push_warning("LootboxOutcomeSpawnSummon: missing Node2D opener in context.")
		return false
	if summon_scene == null:
		push_warning("LootboxOutcomeSpawnSummon: summon_scene is not configured.")
		return false

	var summon_node := summon_scene.instantiate() as Node2D
	if summon_node == null:
		push_warning("LootboxOutcomeSpawnSummon: summon_scene does not instantiate to Node2D.")
		return false

	_apply_identity_modifiers(summon_node)
	_apply_stat_modifiers(summon_node)
	_apply_visual_modifiers(summon_node)
	_register_bestiary_unlock(context, summon_node)

	var spawn_parent: Node = opener.get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = opener.get_parent()
	if spawn_parent == null:
		spawn_parent = opener

	spawn_parent.add_child(summon_node)
	summon_node.global_position = opener.global_position
	return true

func _register_bestiary_unlock(context: Dictionary, summon_node: Node) -> void:
	var lookup_node: Node = context.get("opener", null) as Node
	if lookup_node == null:
		lookup_node = context.get("current_scene", null) as Node

	var bestiary_globals: Node = null
	if lookup_node != null and lookup_node.is_inside_tree():
		bestiary_globals = lookup_node.get_node_or_null("/root/BestiaryGlobals")

	if bestiary_globals == null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			bestiary_globals = tree.root.get_node_or_null("BestiaryGlobals")

	if bestiary_globals == null:
		return

	var resolved_identity: StringName = summon_identity
	if resolved_identity == StringName() and _has_property(summon_node, "summon_identity"):
		resolved_identity = summon_node.get("summon_identity") as StringName
	if resolved_identity == StringName():
		return

	var source_lootbox_id: StringName = context.get("lootbox_id", StringName()) as StringName
	bestiary_globals.call("unlock_summon_entry", resolved_identity, source_lootbox_id)

func _pick_spawn_position(origin: Vector2) -> Vector2:
	var spawn_direction := Vector2.RIGHT.rotated(randf() * TAU)
	return origin + (spawn_direction * spawn_distance)

func _apply_stat_modifiers(summon_node: Node) -> void:
	if _has_property(summon_node, "attack_damage"):
		var current_damage := float(summon_node.get("attack_damage"))
		summon_node.set("attack_damage", current_damage * maxf(damage_multiplier, 0.01))

	if _has_property(summon_node, "max_health"):
		var current_health := float(summon_node.get("max_health"))
		summon_node.set("max_health", current_health * maxf(max_health_multiplier, 0.01))

func _apply_identity_modifiers(summon_node: Node) -> void:
	if summon_identity == StringName():
		return

	if summon_node is SummonUnit:
		(summon_node as SummonUnit).set_summon_identity(summon_identity)
		return

	if _has_property(summon_node, "summon_identity"):
		summon_node.set("summon_identity", summon_identity)

func _apply_visual_modifiers(summon_node: Node2D) -> void:
	if summon_texture_override == null:
		return

	if _has_property(summon_node, "sprite_texture_override"):
		summon_node.set("sprite_texture_override", summon_texture_override)

	var sprite := summon_node.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		var fallback := summon_node.find_child("Sprite2D", true, false)
		sprite = fallback as Sprite2D

	if sprite == null:
		push_warning("LootboxOutcomeSpawnSummon: summon has no Sprite2D to override texture.")
		return

	sprite.texture = summon_texture_override

func _has_property(node: Object, property_name: StringName) -> bool:
	for property_data in node.get_property_list():
		if StringName(property_data.get("name", "")) == property_name:
			return true
	return false
