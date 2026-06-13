extends Plugin


func get_actions() -> Array[String]:
	return ["dnd.take_damage", "dnd.equip_item"]


func get_conditions() -> Array[String]:
	return ["dnd.hp_above"]


func get_ui_panels() -> Array[Dictionary]:
	return [
		{"slot": "game_hud", "scene": "res://plugins/dnd/HpBar.tscn", "id": "dnd_hp_bar"},
		{"slot": "game_overlay", "scene": "res://plugins/dnd/CharacterSheet.tscn", "id": "dnd_character_sheet"},
		{"slot": "sidebar_icon", "scene": "res://plugins/dnd/CharacterSheetButton.tscn", "id": "dnd_cs_button"}
	]


func on_game_start(context: Dictionary):
	context["character"] = {
		"hp": 10,
		"max_hp": 10,
		"equipment": {
			"weapon": {},
			"armor": {},
		}
	}


func get_templates() -> Array[Dictionary]:
	return [
		{
			"id": "item",
			"name": "Item",
			"fields": [
				{"name": "id", "type": "string", "mandatory": true},
				{"name": "name", "type": "string", "mandatory": true},
				{"name": "weight", "type": "float", "mandatory": false},
				{"name": "damage", "type": "string", "mandatory": false},
				{"name": "tags", "type": "array", "mandatory": false},
			]
		},
		{
			"id": "skill",
			"name": "Skill",
			"fields": [
				{"name": "id", "type": "string", "mandatory": true},
				{"name": "name", "type": "string", "mandatory": true},
				{"name": "ability", "type": "string", "mandatory": true},
			]
		}
	]


func get_template_entries() -> Dictionary:
	return {
		"item": [
			{"id": "dagger", "name": "Dagger", "weight": 1.0, "damage": "/r1d4", "tags": ["light", "finesse"]},
			{"id": "shortsword", "name": "Shortsword", "weight": 2.0, "damage": "/r1d6", "tags": ["light", "finesse"]},
		],
		"skill": [
			{"id": "athletics", "name": "Athletics", "ability": "str"},
			{"id": "acrobatics", "name": "Acrobatics", "ability": "dex"},
			{"id": "perception", "name": "Perception", "ability": "wis"},
		]
	}


func get_action_params(action_name: String) -> Array[Dictionary]:
	if action_name == "take_damage":
		return [
			{"name": "amount", "mandatory": true, "direction": "input"},
			{"name": "damage_taken", "mandatory": false, "direction": "output"},
		]
	if action_name == "equip_item":
		return [
			{"name": "item", "mandatory": true, "direction": "input"},
			{"name": "slot", "mandatory": true, "direction": "input"},
		]
	return []


func get_condition_params(cond_name: String) -> Array[Dictionary]:
	if cond_name == "hp_above":
		return [{"name": "value", "mandatory": true}]
	return []


func handle_action(action_name: String, data: Dictionary, context):
	if action_name == "take_damage":
		var dmg = data.get("amount", 1)
		var character = context.get("character", {})
		character["hp"] = character.get("hp", 10) - dmg
		context["character"] = character
		data["damage_taken"] = dmg
		print("Player takes", dmg, "damage. HP:", character["hp"])
	elif action_name == "equip_item":
		var item = data.get("item", {})
		var slot: String = data.get("slot", "")
		if not item is Dictionary or slot == "":
			push_warning("[DND] equip_item: invalid item or missing slot")
			return
		# Store as reference if the original was an entry ref
		var raw_refs = data.get("_raw_refs", {})
		var stored_value
		if raw_refs.has("item"):
			stored_value = ModAPI.make_ref(raw_refs["item"])
		else:
			stored_value = item
		# Equip to slot
		if not context.has("character"):
			context["character"] = {"hp": 10, "max_hp": 10, "equipment": {"weapon": {}, "armor": {}}}
		var equipment = context["character"].get("equipment", {})
		equipment[slot] = stored_value
		context["character"]["equipment"] = equipment
		print("[DND] Equipped ", item.get("name", "unknown"), " to ", slot)

func check_condition(cond_name: String, data: Dictionary, context) -> bool:
	if cond_name == "hp_above":
		var character = context.get("character", {})
		return character.get("hp", 0) > data.get("value", 0)
	push_warning("[DND_system]: " + cond_name + " is not a supported condition")
	return true
