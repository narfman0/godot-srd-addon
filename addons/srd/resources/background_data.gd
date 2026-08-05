extends Resource

@export var background_name: String = ""
@export var feature_name: String = ""
@export var feature_desc: String = ""
@export var skill_proficiencies: Array = []   # Array[int] — SRD.Skill ints

# Skill enum values: ACROBATICS=0 ANIMAL_HANDLING=1 ARCANA=2 ATHLETICS=3
# DECEPTION=4 HISTORY=5 INSIGHT=6 INTIMIDATION=7 INVESTIGATION=8 MEDICINE=9
# NATURE=10 PERCEPTION=11 PERFORMANCE=12 PERSUASION=13 RELIGION=14
# SLEIGHT_OF_HAND=15 STEALTH=16 SURVIVAL=17

static func _make(bg_name: String, s1: int, s2: int, feat: String, feat_desc: String):
	var b = load("res://addons/srd/resources/background_data.gd").new()
	b.background_name = bg_name
	b.skill_proficiencies = [s1, s2]
	b.feature_name = feat
	b.feature_desc = feat_desc
	return b

static func make_acolyte():
	return _make("Acolyte", 6, 14,
		"Shelter of the Faithful",
		"You command the respect of those who share your faith, receiving free lodging and healing at temples.")

static func make_charlatan():
	return _make("Charlatan", 4, 15,
		"False Identity",
		"You have a second identity, complete with documentation, established acquaintances, and disguises.")

static func make_criminal():
	return _make("Criminal", 4, 16,
		"Criminal Contact",
		"You have a reliable contact in the criminal underworld who can pass messages and gather information.")

static func make_entertainer():
	return _make("Entertainer", 0, 12,
		"By Popular Demand",
		"You can always find a place to perform; in exchange you receive free lodging and modest food.")

static func make_folk_hero():
	return _make("Folk Hero", 1, 17,
		"Rustic Hospitality",
		"Common folk will shelter and feed you, since they see you as one of their own.")

static func make_guild_artisan():
	return _make("Guild Artisan", 6, 13,
		"Guild Membership",
		"Your guild provides lodging, legal support, and connections in any city that has a chapter.")

static func make_hermit():
	return _make("Hermit", 9, 14,
		"Discovery",
		"Your solitude granted you a powerful secret or revelation that others would kill to learn.")

static func make_noble():
	return _make("Noble", 5, 13,
		"Position of Privilege",
		"People are inclined to think the best of you; commoners make way and nobles treat you as a peer.")

static func make_outlander():
	return _make("Outlander", 3, 17,
		"Wanderer",
		"You have an excellent memory for terrain and can always find food and fresh water in the wild.")

static func make_sage():
	return _make("Sage", 2, 5,
		"Researcher",
		"When you can't recall a fact, you know where to find it — and who owes you a favor.")

static func make_sailor():
	return _make("Sailor", 3, 11,
		"Ship's Passage",
		"You can secure free passage on sailing vessels for yourself and your companions.")

static func make_soldier():
	return _make("Soldier", 3, 7,
		"Military Rank",
		"Soldiers of your faction recognize your rank and defer to you; you can commandeer simple resources.")

static func make_urchin():
	return _make("Urchin", 15, 16,
		"City Secrets",
		"You know the secret paths and back alleys of any city, letting you move twice as fast as normal.")

static func all_backgrounds() -> Array:
	return [
		make_acolyte(), make_charlatan(), make_criminal(), make_entertainer(),
		make_folk_hero(), make_guild_artisan(), make_hermit(), make_noble(),
		make_outlander(), make_sage(), make_sailor(), make_soldier(), make_urchin(),
	]
