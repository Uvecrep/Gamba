extends Node

signal catalog_rebuilt
signal bestiary_entry_unlocked(entry_id: StringName, entry_type: StringName, source_tab_id: StringName, prompt_player: bool)
signal bestiary_entry_new_state_changed(entry_id: StringName, is_new: bool)
signal bestiary_entry_updated(entry_id: StringName)

const ENEMY_TAB_ID: StringName = &"enemies"
const ENEMY_ENTRY_IDS: PackedStringArray = [
	&"enemy_basic_raider",
	&"enemy_fast_raider",
	&"enemy_tank_raider",
	&"enemy_ranged_raider",
	&"enemy_healing_raider",
	&"enemy_trenchcoat_goblin",
	&"enemy_goblin",
]

const SUMMON_BLURBS: Dictionary = {
	&"baby_dragon": "Park it near choke points where its combination of AOE and DOT punish tight packs of attackers.",
	&"slime": "Use Slime as an early tank that soaks in damage and distracts allowing other units to get hits on preoccupied enemies.",
	&"ghost": "Send Ghost through walls and fences to swiftly respond to immediate threats with high mobility but be careful about his relatively low attack and defense stats.",
	&"spark_goblin": "Place Spark Goblin behind tanks to finish wounded enemies before they recover, but beware the potential for friendly fire from his shock attacks.",
	&"jack_in_the_box": "Use Jack-In-The-Box to keep enemies at a distance and buy time for other summons to come to his aid.",
	&"mushroom_knight": "Frontline with Mushroom Knight when you need consistent melee uptime and easy automatic positioning.",
	&"acorn_spitter": "Keep Acorn Spitter protected in back lanes so constant shots soften incoming waves.",
	&"bush_boy": "Pair Bush Boy with fragile carries to absorb pressure and stabilize messy fights, but be aware he has no offensive capabilities.",
	&"bee_swarm": "Deploy Bee Swarm on isolated targets to utilize its fast mobility and attack speed.",
	&"rooter": "Open fights with Rooter to lock faster runners in place for focused damage.",
	&"cinder_imp": "Use Cinder Imp in longer fights with enemy tanks where burn damage keeps ticking between attacks.",
	&"frost_wisp": "Position Frost Wisp near approaches to slow dives and buy your backline time.",
	&"magma_beetle": "Use the Magma Beetle's unique trail to punish enemy aggression and defend areas with DOT.",
	&"storm_totem": "Drop Storm Totem into crowded lanes where chain lightning gets maximum value.",
	&"unstable_shard": "Keep the Unstable Shard in your back pocket for use in emergency situations or get maximum utility deploying into large groups of enemies.",
	&"soul_lantern": "Keep Soul Lantern in the back line and ensure it supplies every unit on your battlefield with a shield to help all summons survivability.",
	&"banshee": "Use Banshee to break up enemy swarms and keep your tanks from being dove.",
	&"grave_hound": "Send Grave Hound after low health targets to force pressure and chase down retreaters.",
	&"hex_doll": "Pair Hex Doll with burst units to amplify DPS and minimize time to kill.",
	&"possessor": "Flank with Possessor to disrupt formations and open space for allied movement.",
	&"mimic": "Keep Mimic on the front lines where it can deal large first-hit damage, and surprise attackers.",
	&"coin_sprite": "Utilize Coin Sprite early in safer fights to boost your economy.",
	&"prospector": "Keep your prospector safe in the coin mines unless needed for an emergency to boost your economy.",
	&"golden_gunner": "Protect Golden Gunner and bring him out as the carry in fights when your economy is up to maximize damage potential.",
	&"tax_collector": "Keep the Tax Collector safe and on the front lines so it can scale stats over time.",
}

const LOOTBOX_DESCRIPTION_HINTS: Dictionary = {
	&"chaos": "High-variance box with explosive attackers that reward aggressive play and attacks.",
	&"forest": "Stable box with durable lane control tools suited for steady, defensive setups.",
	&"elemental": "Control-focused box built around status pressure, area denial, and swingy hail mary plays.",
	&"greed": "Economy-centric box that trades some immediate value for long term scaling.",
	&"soul": "Disruption-oriented box with utility summons that thrive in big multi-target fights.",
}

const LOOTBOX_SOURCE_HINTS: Dictionary = {
	&"chaos": "Harvest your chaos crystal next to your base regularly to gather Chaos Boxes.",
	&"forest": "Harvest from trees in your base's planters consistently to farm Forest Boxes during the day.",
	&"elemental": "Buy Elemental Boxes with blood currency at the blood confluence in your base.",
	&"greed": "Buy Greed Boxes from the shop with gold gathered from enemies.",
	&"soul": "Claim Soul Boxes from the mysterious moving spirit crystal somewhere around your base each day.",
}

var ENEMY_DATA: Dictionary = {
	&"enemy_basic_raider": {
		"archetype": &"basic_raider",
		"display_name": "Raider",
		"portrait_path": "res://assets/characters/raider.png",
		"blurb": "Standard melee bruiser, so kite briefly and focus it before faster threats arrive.",
		"stats": PackedStringArray(["HP: 100", "Move Speed: 90", "Melee Damage: 15", "Attack Cooldown: 1.0s"]),
	},
	&"enemy_fast_raider": {
		"archetype": &"fast_raider",
		"display_name": "Fast Raider",
		"portrait_path": "res://assets/characters/fast_raider.png",
		"blurb": "Fast flanker that slips past tanks, so body-block lanes and burst it early.",
		"stats": PackedStringArray(["HP: 65", "Move Speed: 145", "Melee Damage: 14", "Attack Cooldown: 0.85s"]),
	},
	&"enemy_tank_raider": {
		"archetype": &"tank_raider",
		"display_name": "Tank Raider",
		"portrait_path": "res://assets/characters/tank_raider.png",
		"blurb": "High-health wall that stalls pushes, so surround it and clear supports first.",
		"stats": PackedStringArray(["HP: 240", "Move Speed: 58", "Melee Damage: 9", "Attack Cooldown: 1.1s"]),
	},
	&"enemy_ranged_raider": {
		"archetype": &"ranged_raider",
		"display_name": "Ranged Raider",
		"portrait_path": "res://assets/characters/ranged_raider.png",
		"blurb": "Backline shooter that repositions often, so collapse angles and deny firing lanes.",
		"stats": PackedStringArray(["HP: 70", "Move Speed: 84", "Ranged Damage: 13", "Ranged Cooldown: 1.35s", "Range: 360"]),
	},
	&"enemy_healing_raider": {
		"archetype": &"healing_raider",
		"display_name": "Healing Raider",
		"portrait_path": "res://assets/characters/healing_raider.png",
		"blurb": "Support raider with massive healing aura, so pick it first to stop sustain snowballs.",
		"stats": PackedStringArray(["HP: 85", "Move Speed: 76", "Heal/s: 14", "Aura Radius: 230"]),
	},
	&"enemy_trenchcoat_goblin": {
		"archetype": &"trenchcoat_goblin",
		"display_name": "Trenchcoat Goblin",
		"portrait_path": "res://assets/characters/trenchcoat_goblins.png",
		"blurb": "Elite brawler that splits on death, so save area damage for the spawn.",
		"stats": PackedStringArray(["HP: 260", "Move Speed: 95", "Melee Damage: 20", "Attack Cooldown: 0.9s", "On Death: Splits into goblins"]),
	},
	&"enemy_goblin": {
		"archetype": &"goblin",
		"display_name": "Goblin",
		"portrait_path": "res://assets/characters/goblin.png",
		"blurb": "Light split-wave pest, so clear it quickly before it chips your backline.",
		"stats": PackedStringArray(["HP: 95", "Move Speed: 102", "Melee Damage: 13", "Attack Cooldown: 0.9s"]),
	},
}

var _tab_definitions: Array[Dictionary] = []
var _tab_entries: Dictionary = {}
var _entries: Dictionary = {}
var _unlocked_entries: Dictionary = {}
var _new_entries: Dictionary = {}
var _seen_summon_quality_tiers: Dictionary = {}


func get_lootbox_description_hint(box_id: StringName) -> String:
	return String(LOOTBOX_DESCRIPTION_HINTS.get(box_id, "Open this lootbox to unlock summons tied to its combat theme."))


func get_lootbox_source_hint(box_id: StringName) -> String:
	return String(LOOTBOX_SOURCE_HINTS.get(box_id, "Acquire this lootbox from combat and progression rewards."))


func _ready() -> void:
	call_deferred("rebuild_catalog")


func rebuild_catalog() -> void:
	_tab_definitions.clear()
	_tab_entries.clear()
	_entries.clear()

	var lootbox_globals: Node = get_node_or_null("/root/LootboxGlobals")
	if lootbox_globals == null:
		push_warning("BestiaryGlobals: LootboxGlobals was missing during catalog rebuild.")
		emit_signal("catalog_rebuilt")
		return

	var lootboxes: Dictionary = lootbox_globals.get("lootboxes")
	var lootbox_ids: Array[StringName] = []
	for raw_id in lootboxes.keys():
		lootbox_ids.append(raw_id as StringName)
	lootbox_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)

	for lootbox_id in lootbox_ids:
		var lootbox: Lootbox = lootboxes.get(lootbox_id) as Lootbox
		if lootbox == null:
			continue

		var tab_id: StringName = StringName("lootbox_" + String(lootbox.id))
		_tab_definitions.append({
			"id": tab_id,
			"display_name": lootbox.name,
			"entry_type": &"summon",
		})
		_tab_entries[tab_id] = []

		for loot_entry in lootbox.lootTable:
			if loot_entry == null:
				continue
			if not (loot_entry.outcome is LootboxOutcomeSpawnSummon):
				continue

			var spawn_outcome: LootboxOutcomeSpawnSummon = loot_entry.outcome as LootboxOutcomeSpawnSummon
			var summon_id: StringName = spawn_outcome.summon_identity
			if summon_id == StringName():
				continue

			var entry_id: StringName = _to_summon_entry_id(summon_id)
			(_tab_entries[tab_id] as Array).append(entry_id)
			_register_summon_entry_if_missing(entry_id, summon_id, loot_entry, spawn_outcome)

	_tab_definitions.append({
		"id": ENEMY_TAB_ID,
		"display_name": "Enemies",
		"entry_type": &"enemy",
	})
	_tab_entries[ENEMY_TAB_ID] = []

	for enemy_entry_id in ENEMY_ENTRY_IDS:
		(_tab_entries[ENEMY_TAB_ID] as Array).append(enemy_entry_id)
		_register_enemy_entry(enemy_entry_id)

	emit_signal("catalog_rebuilt")


func get_tab_definitions() -> Array[Dictionary]:
	return _tab_definitions.duplicate(true)


func get_entry_ids_for_tab(tab_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw_entries: Array = _tab_entries.get(tab_id, [])
	for raw_entry_id in raw_entries:
		result.append(raw_entry_id as StringName)
	return result


func get_entry(entry_id: StringName) -> Dictionary:
	var raw_entry: Dictionary = _entries.get(entry_id, {})
	return raw_entry.duplicate(true)


func is_entry_unlocked(entry_id: StringName) -> bool:
	return bool(_unlocked_entries.get(entry_id, false))


func is_entry_new(entry_id: StringName) -> bool:
	return bool(_new_entries.get(entry_id, false))


func mark_entry_viewed(entry_id: StringName) -> bool:
	if not is_entry_new(entry_id):
		return false

	_new_entries[entry_id] = false
	emit_signal("bestiary_entry_new_state_changed", entry_id, false)
	return true


func tab_has_new_entries(tab_id: StringName) -> bool:
	var raw_entries: Array = _tab_entries.get(tab_id, [])
	for raw_entry_id in raw_entries:
		var entry_id: StringName = raw_entry_id as StringName
		if is_entry_new(entry_id):
			return true
	return false


func unlock_summon_entry(summon_identity: StringName, source_lootbox_id: StringName = StringName()) -> bool:
	return unlock_summon_entry_with_quality(summon_identity, source_lootbox_id, 0)


func unlock_summon_entry_with_quality(summon_identity: StringName, source_lootbox_id: StringName = StringName(), quality_tier: int = 0) -> bool:
	if summon_identity == StringName():
		return false

	var entry_id: StringName = _to_summon_entry_id(summon_identity)
	if not _entries.has(entry_id):
		return false

	var tier_marked: bool = _mark_summon_quality_tier_seen(entry_id, quality_tier)
	if is_entry_unlocked(entry_id):
		if tier_marked:
			emit_signal("bestiary_entry_updated", entry_id)
		return false

	_unlocked_entries[entry_id] = true
	_new_entries[entry_id] = true
	var source_tab_id: StringName = StringName("lootbox_" + String(source_lootbox_id)) if source_lootbox_id != StringName() else StringName()
	var should_prompt: bool = source_lootbox_id != StringName()
	emit_signal("bestiary_entry_unlocked", entry_id, &"summon", source_tab_id, should_prompt)
	emit_signal("bestiary_entry_new_state_changed", entry_id, true)
	return true


func unlock_enemy_entry(enemy_archetype: StringName) -> bool:
	if enemy_archetype == StringName():
		return false

	var entry_id: StringName = _enemy_entry_id_from_archetype(enemy_archetype)
	if entry_id == StringName():
		return false
	if not _entries.has(entry_id):
		return false
	if is_entry_unlocked(entry_id):
		return false

	_unlocked_entries[entry_id] = true
	_new_entries[entry_id] = true
	emit_signal("bestiary_entry_unlocked", entry_id, &"enemy", ENEMY_TAB_ID, false)
	emit_signal("bestiary_entry_new_state_changed", entry_id, true)
	return true


func _register_summon_entry_if_missing(entry_id: StringName, summon_identity: StringName, loot_entry: LootEntry, spawn_outcome: LootboxOutcomeSpawnSummon) -> void:
	if not _entries.has(entry_id):
		_entries[entry_id] = _build_summon_entry(entry_id, summon_identity, loot_entry, spawn_outcome)
		return

	var existing_entry: Dictionary = _entries[entry_id]
	if existing_entry.get("portrait", null) == null and spawn_outcome.summon_texture_override != null:
		existing_entry["portrait"] = spawn_outcome.summon_texture_override
	if String(existing_entry.get("display_name", "")).is_empty() and not loot_entry.name.is_empty():
		existing_entry["display_name"] = loot_entry.name


func _build_summon_entry(entry_id: StringName, summon_identity: StringName, loot_entry: LootEntry, spawn_outcome: LootboxOutcomeSpawnSummon) -> Dictionary:
	var profile: SummonIdentityProfile = SummonProfileCatalog.get_profile(summon_identity)
	var display_name: String = loot_entry.name if not loot_entry.name.is_empty() else _humanize_identity(summon_identity)
	var blurb: String = String(SUMMON_BLURBS.get(summon_identity, "A versatile summon that supports your lineup once unlocked."))

	var stats_lines: PackedStringArray = []
	if profile != null:
		stats_lines.append("HP: %d" % int(round(profile.max_health)))
		stats_lines.append("Move Speed: %d" % int(round(profile.move_speed)))
		stats_lines.append("Attack Damage: %d" % int(round(profile.attack_damage)))
		stats_lines.append("Attack Range: %d" % int(round(profile.attack_range)))
		stats_lines.append("Attack Cooldown: %.2fs" % profile.attack_cooldown)
	else:
		stats_lines.append("Base stats unavailable")

	return {
		"id": entry_id,
		"entry_type": &"summon",
		"summon_identity": summon_identity,
		"display_name": display_name,
		"portrait": spawn_outcome.summon_texture_override,
		"blurb": blurb,
		"stats_lines": stats_lines,
		"quality_stats_by_tier": _build_summon_quality_stats(profile),
		"seen_quality_tiers": {
			0: false,
			1: false,
			2: false,
		},
	}


func _register_enemy_entry(entry_id: StringName) -> void:
	var source_data: Dictionary = ENEMY_DATA.get(entry_id, {})
	if source_data.is_empty():
		return

	var portrait_path: String = String(source_data.get("portrait_path", ""))
	var portrait: Texture2D = null
	if not portrait_path.is_empty():
		portrait = load(portrait_path) as Texture2D

	_entries[entry_id] = {
		"id": entry_id,
		"entry_type": &"enemy",
		"enemy_archetype": source_data.get("archetype", StringName()),
		"display_name": String(source_data.get("display_name", "Unknown Enemy")),
		"portrait": portrait,
		"blurb": String(source_data.get("blurb", "A dangerous enemy.")),
		"stats_lines": source_data.get("stats", PackedStringArray(["Base stats unavailable"])),
	}


func _to_summon_entry_id(summon_identity: StringName) -> StringName:
	return StringName("summon_" + String(summon_identity))


func _enemy_entry_id_from_archetype(archetype: StringName) -> StringName:
	match archetype:
		&"basic_raider":
			return &"enemy_basic_raider"
		&"fast_raider":
			return &"enemy_fast_raider"
		&"tank_raider":
			return &"enemy_tank_raider"
		&"ranged_raider":
			return &"enemy_ranged_raider"
		&"healing_raider":
			return &"enemy_healing_raider"
		&"trenchcoat_goblin":
			return &"enemy_trenchcoat_goblin"
		&"goblin":
			return &"enemy_goblin"
		_:
			return StringName()


func _humanize_identity(identity: StringName) -> String:
	var raw: String = String(identity)
	if raw.is_empty():
		return "Unknown"
	var words: PackedStringArray = raw.split("_", false)
	var result_words: PackedStringArray = []
	for word in words:
		if word.is_empty():
			continue
		result_words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(result_words)


func _build_summon_quality_stats(profile: SummonIdentityProfile) -> Dictionary:
	if profile == null:
		return {
			0: PackedStringArray(["Base stats unavailable"]),
			1: PackedStringArray(["Base stats unavailable"]),
			2: PackedStringArray(["Base stats unavailable"]),
		}

	return {
		0: _build_quality_stats_lines(profile, 1.0),
		1: _build_quality_stats_lines(profile, 1.2),
		2: _build_quality_stats_lines(profile, 1.4),
	}


func _build_quality_stats_lines(profile: SummonIdentityProfile, multiplier: float) -> PackedStringArray:
	var scaled_hp: float = profile.max_health * multiplier
	var scaled_move_speed: float = profile.move_speed * multiplier
	var scaled_attack_damage: float = profile.attack_damage * multiplier
	var scaled_attack_range: float = profile.attack_range * multiplier
	var scaled_attack_cooldown: float = profile.attack_cooldown

	return PackedStringArray([
		"HP: %d" % int(round(scaled_hp)),
		"Move: %d" % int(round(scaled_move_speed)),
		"Damage: %d" % int(round(scaled_attack_damage)),
		"Range: %d" % int(round(scaled_attack_range)),
		"Cooldown: %.2fs" % scaled_attack_cooldown,
	])


func _mark_summon_quality_tier_seen(entry_id: StringName, quality_tier: int) -> bool:
	var clamped_tier: int = clampi(quality_tier, 0, 2)
	var seen_map: Dictionary = _seen_summon_quality_tiers.get(entry_id, {
		0: false,
		1: false,
		2: false,
	})
	if bool(seen_map.get(clamped_tier, false)):
		_entries[entry_id]["seen_quality_tiers"] = seen_map.duplicate(true)
		_seen_summon_quality_tiers[entry_id] = seen_map
		return false

	seen_map[clamped_tier] = true
	_seen_summon_quality_tiers[entry_id] = seen_map

	if _entries.has(entry_id):
		var entry: Dictionary = _entries[entry_id]
		entry["seen_quality_tiers"] = seen_map.duplicate(true)
		_entries[entry_id] = entry

	return true
