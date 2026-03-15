extends RefCounted
class_name SummonProfileCatalog

const PROFILE_BY_ID: Dictionary = {
	&"baby_dragon": preload("res://entities/summon/profiles/baby_dragon.tres"),
	&"slime": preload("res://entities/summon/profiles/slime.tres"),
	&"ghost": preload("res://entities/summon/profiles/ghost.tres"),
	&"spark_goblin": preload("res://entities/summon/profiles/spark_goblin.tres"),
	&"jack_in_the_box": preload("res://entities/summon/profiles/jack_in_the_box.tres"),
	&"mushroom_knight": preload("res://entities/summon/profiles/mushroom_knight.tres"),
	&"acorn_spitter": preload("res://entities/summon/profiles/acorn_spitter.tres"),
	&"bush_boy": preload("res://entities/summon/profiles/bush_boy.tres"),
	&"bee_swarm": preload("res://entities/summon/profiles/bee_swarm.tres"),
	&"rooter": preload("res://entities/summon/profiles/rooter.tres"),
}

static func get_profile(identity: StringName) -> SummonIdentityProfile:
	var profile: Resource = PROFILE_BY_ID.get(identity, null)
	if profile is SummonIdentityProfile:
		return profile as SummonIdentityProfile
	return null
