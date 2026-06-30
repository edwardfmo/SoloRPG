extends RefCounted


func get_templates() -> Array[Dictionary]:
	return [
		{
			"id": "group",
			"name": "Group",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
			]
		},
		{
			"id": "character_feature",
			"name": "Character Feature",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
				{"name": "groups", "type": "array", "mandatory": false},
				{"name": "params", "type": "array", "mandatory": false},
			]
		},
		{
			"id": "skill",
			"name": "Skill",
			"fields": [
				{"name": "ability", "type": "string", "mandatory": true, "enum": ["str", "dex", "con", "int", "wis", "cha"]},
				{"name": "groups", "type": "array", "mandatory": false},
			]
		},
		{
			"id": "background",
			"name": "Background",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
				{"name": "features", "type": "array", "mandatory": false, "header_format": "Lv@level - @feature_name(Feature)", "item_schema": [
					{"name": "feature_name", "type": "string", "mandatory": false},
					{"name": "entries", "type": "array", "mandatory": false, "entry_ref_types": ["character_feature", "skill", "weapon", "armor", "tool", "group"]},
					{"name": "level", "type": "int", "mandatory": true},
					{"name": "number_to_choose", "type": "int", "mandatory": false}
				]},
			]
		},
		{
			"id": "species",
			"name": "Species",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
				{"name": "features", "type": "array", "mandatory": false, "header_format": "Lv@level - @feature_name(Feature)", "item_schema": [
					{"name": "feature_name", "type": "string", "mandatory": false},
					{"name": "entries", "type": "array", "mandatory": false, "entry_ref_types": ["character_feature", "skill", "weapon", "armor", "tool", "group"]},
					{"name": "level", "type": "int", "mandatory": true},
					{"name": "number_to_choose", "type": "int", "mandatory": false}
				]},
			]
		},
		{
			"id": "class",
			"name": "Class",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
				{"name": "hit_die", "type": "string", "enum": ["d4", "d6", "d8", "d10", "d12"], "mandatory": true},
				{"name": "features", "type": "array", "mandatory": false, "header_format": "Lv@level - @feature_name(Feature)", "item_schema": [
					{"name": "feature_name", "type": "string", "mandatory": false},
					{"name": "entries", "type": "array", "mandatory": false, "entry_ref_types": ["character_feature", "skill", "weapon", "armor", "tool", "group"]},
					{"name": "level", "type": "int", "mandatory": true},
					{"name": "number_to_choose", "type": "int", "mandatory": false}
				]},
			]
		},
	]


func get_template_entries() -> Dictionary:
	return {
		"group": [],
		"character_feature": [],
		"skill": [],
		"background": [],
		"species": [],
		"class": [],
	}
