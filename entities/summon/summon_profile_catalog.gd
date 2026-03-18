extends RefCounted
class_name SummonProfileCatalog

const PROFILE_BY_ID: Dictionary = {
	&"baby_dragon": "res://entities/summon/profiles/baby_dragon.tres",
	&"slime": "res://entities/summon/profiles/slime.tres",
	&"ghost": "res://entities/summon/profiles/ghost.tres",
	&"spark_goblin": "res://entities/summon/profiles/spark_goblin.tres",
	&"jack_in_the_box": "res://entities/summon/profiles/jack_in_the_box.tres",
	&"mushroom_knight": "res://entities/summon/profiles/mushroom_knight.tres",
	&"acorn_spitter": "res://entities/summon/profiles/acorn_spitter.tres",
	&"bush_boy": "res://entities/summon/profiles/bush_boy.tres",
	&"bee_swarm": "res://entities/summon/profiles/bee_swarm.tres",
	&"rooter": "res://entities/summon/profiles/rooter.tres",
	&"cinder_imp": "res://entities/summon/profiles/cinder_imp.tres",
	&"frost_wisp": "res://entities/summon/profiles/frost_wisp.tres",
	&"magma_beetle": "res://entities/summon/profiles/magma_beetle.tres",
	&"storm_totem": "res://entities/summon/profiles/storm_totem.tres",
	&"unstable_shard": "res://entities/summon/profiles/unstable_shard.tres",
	&"soul_lantern": "res://entities/summon/profiles/soul_lantern.tres",
	&"banshee": "res://entities/summon/profiles/banshee.tres",
	&"grave_hound": "res://entities/summon/profiles/grave_hound.tres",
	&"hex_doll": "res://entities/summon/profiles/hex_doll.tres",
	&"possessor": "res://entities/summon/profiles/possessor.tres",
	&"mimic": "res://entities/summon/profiles/mimic.tres",
	&"coin_sprite": "res://entities/summon/profiles/coin_sprite.tres",
	&"prospector": "res://entities/summon/profiles/prospector.tres",
	&"golden_gunner": "res://entities/summon/profiles/golden_gunner.tres",
	&"tax_collector": "res://entities/summon/profiles/tax_collector.tres",
}

static func get_profile(identity: StringName) -> SummonIdentityProfile:
	var profile_path: Variant = PROFILE_BY_ID.get(identity, null)
	if not (profile_path is String):
		return null

	var profile: Resource = load(profile_path as String)
	if profile is SummonIdentityProfile:
		return profile as SummonIdentityProfile
	return null
