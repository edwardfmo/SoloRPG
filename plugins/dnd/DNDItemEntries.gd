extends RefCounted


func get_templates() -> Array[Dictionary]:
	return [
		{
			"id": "item",
			"name": "Item",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
				{"name": "weight", "type": "float", "mandatory": false},
				{"name": "value", "type": "int", "mandatory": false},
				{"name": "rarity", "type": "string", "mandatory": false, "enum": ["-", "common", "uncommon", "rare", "very rare", "legendary", "artifact"]},
			]
		},
		{
			"id": "weapon",
			"name": "Weapon",
			"extends": "item",
			"fields": [
				{"name": "damage", "type": "string", "mandatory": false},
				{"name": "damage_type", "type": "string", "mandatory": false},
				{"name": "class", "type": "string", "mandatory": false, "enum": ["simple", "martial", "other"]},
				{"name": "range", "type": "string", "mandatory": false},
				{"name": "keywords", "type": "array", "mandatory": false},
			]
		},
		{
			"id": "armor",
			"name": "Armor",
			"extends": "item",
			"fields": [
				{"name": "class", "type": "string", "mandatory": false, "enum": ["light", "medium", "heavy", "shield", "unarmored"]},
				{"name": "ac", "type": "int", "mandatory": true},
				{"name": "min_str", "type": "int", "mandatory": false},
				{"name": "stealth_disadvantage", "type": "bool", "mandatory": false},
			]
		},
	]


func get_template_entries() -> Dictionary:
	return {
		"item": [],
		"weapon": [
			{"id": "dagger", "name": "Dagger", "weight": 1.0, "value": 200, "rarity": "common", "damage": "/r1d4", "damage_type": "piercing", "class": "simple", "range": "melee", "keywords": ["light", "finesse", "thrown(20/60)"], "groups": ["simple_weapons"]},
			{"id": "shortsword", "name": "Shortsword", "weight": 2.0, "value": 1000, "rarity": "common", "damage": "/r1d6", "damage_type": "piercing", "class": "martial", "range": "melee", "keywords": ["light", "finesse"], "groups": ["martial_weapons"]},
		],
		"armor": [],
	}
