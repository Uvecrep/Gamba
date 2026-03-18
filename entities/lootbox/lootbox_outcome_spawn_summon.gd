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

	var spawn_parent: Node = opener.get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = opener.get_parent()
	if spawn_parent == null:
		spawn_parent = opener

	spawn_parent.add_child(summon_node)
	summon_node.global_position = opener.global_position
	return true

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
