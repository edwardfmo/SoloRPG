extends RefCounted


func get_templates() -> Array[Dictionary]:
	return [
		{
			"id": "item",
			"name": "Item",
			"fields": [
				{"name": "weight", "type": "float", "mandatory": false},
				{"name": "damage", "type": "string", "mandatory": false},
				{"name": "tags", "type": "array", "mandatory": false},
			]
		}
	]


func get_template_entries() -> Dictionary:
	return {
		"item": [
			{"id": "dagger", "name": "Dagger", "weight": 1.0, "damage": "/r1d4", "tags": ["light", "finesse"]},
			{"id": "shortsword", "name": "Shortsword", "weight": 2.0, "damage": "/r1d6", "tags": ["light", "finesse"]},
		]
	}
