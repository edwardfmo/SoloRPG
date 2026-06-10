extends Plugin


func get_actions() -> Array[String]:
	return ["dnd.damage"]


func get_conditions() -> Array[String]:
	return ["dnd.hp_above"]


func get_ui_panels() -> Array[Dictionary]:
	return [
		{"slot": "game_hud", "scene": "res://plugins/dnd/HpBar.tscn", "id": "dnd_hp_bar"},
		{"slot": "game_overlay", "scene": "res://plugins/dnd/CharacterSheet.tscn", "id": "dnd_character_sheet"},
		{"slot": "sidebar_icon", "scene": "res://plugins/dnd/CharacterSheetButton.tscn", "id": "dnd_cs_button"}
	]


func handle_action(action_name: String, data: Dictionary, context):
	if action_name == "damage":
		var dmg = data.get("amount", 1)
		context["hp"] = context.get("hp", 10) - dmg
		print("Player takes", dmg, "damage. HP:", context["hp"])

func check_condition(cond_name: String, data: Dictionary, context) -> bool:
	if cond_name == "hp_above":
		return context.get("hp", 0) > data.get("value", 0)
	push_warning("[DND_system]: " + cond_name + " is not a supported condition")
	return true
