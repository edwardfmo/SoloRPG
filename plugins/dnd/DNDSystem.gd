extends Plugin


func get_actions() -> Array[String]:
	return ["dnd.take_damage"]


func get_conditions() -> Array[String]:
	return ["dnd.hp_above"]


func get_ui_panels() -> Array[Dictionary]:
	return [
		{"slot": "game_hud", "scene": "res://plugins/dnd/HpBar.tscn", "id": "dnd_hp_bar"},
		{"slot": "game_overlay", "scene": "res://plugins/dnd/CharacterSheet.tscn", "id": "dnd_character_sheet"},
		{"slot": "sidebar_icon", "scene": "res://plugins/dnd/CharacterSheetButton.tscn", "id": "dnd_cs_button"}
	]


func on_game_start(context: Dictionary):
	context["hp"] = 10
	context["max_hp"] = 10


func get_action_params(action_name: String) -> Array[Dictionary]:
	if action_name == "take_damage":
		return [
			{"name": "amount", "mandatory": true, "direction": "input"},
			{"name": "damage_taken", "mandatory": false, "direction": "output"},
		]
	return []


func get_condition_params(cond_name: String) -> Array[Dictionary]:
	if cond_name == "hp_above":
		return [{"name": "value", "mandatory": true}]
	return []


func handle_action(action_name: String, data: Dictionary, context):
	if action_name == "take_damage":
		var dmg = data.get("amount", 1)
		context["hp"] = context.get("hp", 10) - dmg
		data["damage_taken"] = dmg
		print("Player takes", dmg, "damage. HP:", context["hp"])

func check_condition(cond_name: String, data: Dictionary, context) -> bool:
	if cond_name == "hp_above":
		return context.get("hp", 0) > data.get("value", 0)
	push_warning("[DND_system]: " + cond_name + " is not a supported condition")
	return true
