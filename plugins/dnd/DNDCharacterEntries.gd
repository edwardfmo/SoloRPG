extends RefCounted


func get_templates() -> Array[Dictionary]:
	return [
		{
			"id": "character_feature",
			"name": "Character Feature",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
			]
		},
		{
			"id": "background",
			"name": "Background",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
				{"name": "skill_proficiencies", "type": "array", "entry_ref_types": ["skill"], "mandatory": false},
			]
		},
		{
			"id": "species",
			"name": "Species",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
				{"name": "skill_proficiencies", "type": "array", "entry_ref_types": ["skill"], "mandatory": false},
			]
		},
		{
			"id": "class",
			"name": "Class",
			"fields": [
				{"name": "description", "type": "string", "mandatory": false},
				{"name": "skill_proficiencies", "type": "array", "entry_ref_types": ["skill"], "mandatory": true},
				{"name": "number_of_skills", "type": "int", "mandatory": true},
				{"name": "hit_die", "type": "string", "enum": ["d4", "d6", "d8", "d10", "d12"], "mandatory": true},
			]
		},
		{
			"id": "skill",
			"name": "Skill",
			"fields": [
				{"name": "ability", "type": "string", "mandatory": true},
			]
		}
	]


func get_template_entries() -> Dictionary:
	return {
		"character_feature": [],
		"background": [
			{"id": "acolyte", "name": "Acolyte", "description": "You have spent your life in service to a temple.", "skill_proficiencies": ["@skill/dnd.athletics", "@skill/dnd.perception"]},
			{"id": "criminal", "name": "Criminal", "description": "You have a history of breaking the law.", "skill_proficiencies": ["@skill/dnd.acrobatics", "@skill/dnd.perception"]},
		],
		"species": [
			{"id": "human", "name": "Human", "description": "Humans are the most adaptable and ambitious people.", "skill_proficiencies": ["@skill/dnd.athletics"]},
			{"id": "elf", "name": "Elf", "description": "Elves are a magical people of otherworldly grace.", "skill_proficiencies": ["@skill/dnd.perception"]},
		],
		"class": [
			{"id": "fighter", "name": "Fighter", "description": "A master of martial combat.", "skill_proficiencies": ["@skill/dnd.athletics", "@skill/dnd.acrobatics", "@skill/dnd.perception"], "number_of_skills": 2, "hit_dice": "d10"},
			{"id": "rogue", "name": "Rogue", "description": "A scoundrel who uses stealth and trickery.", "skill_proficiencies": ["@skill/dnd.acrobatics", "@skill/dnd.athletics", "@skill/dnd.perception"], "number_of_skills": 4, "hit_dice": "d8"},
		],
		"skill": [
			{"id": "athletics", "name": "Athletics", "ability": "str"},
			{"id": "acrobatics", "name": "Acrobatics", "ability": "dex"},
			{"id": "perception", "name": "Perception", "ability": "wis"},
		]
	}
