extends Plugin

var _character_entries = preload("res://plugins/dnd/DNDCharacterEntries.gd").new()
var _item_entries = preload("res://plugins/dnd/DNDItemEntries.gd").new()


func get_actions() -> Array[String]:
	return ["dnd.take_damage", "dnd.equip_item"]


func get_conditions() -> Array[String]:
	return ["dnd.hp_above"]


func get_ui_panels() -> Array[Dictionary]:
	return [
		{"slot": "game_hud", "scene": "res://plugins/dnd/HpBar.tscn", "id": "dnd_hp_bar"},
		{"slot": "game_overlay", "scene": "res://plugins/dnd/CharacterSheet.tscn", "id": "dnd_character_sheet"},
		{"slot": "game_overlay", "scene": "res://plugins/dnd/CharacterCreator.tscn", "id": "dnd_character_creator"},
		{"slot": "sidebar_icon", "scene": "res://plugins/dnd/CharacterSheetButton.tscn", "id": "dnd_cs_button"}
	]


func on_game_start():
	api.set_value("character", {
		"hp": 10,
		"max_hp": 10,
		"equipment": {
			"weapon": {},
			"armor": {},
		}
	})
	api.show_overlay("dnd_character_creator", {"context_path": "character"})
	var overlay = api.get_overlay_node("dnd_character_creator")
	if overlay:
		return overlay.closed


func get_templates() -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	templates.append_array(_character_entries.get_templates())
	templates.append_array(_item_entries.get_templates())
	return templates


func get_template_entries() -> Dictionary:
	var entries := {}
	entries.merge(_character_entries.get_template_entries())
	entries.merge(_item_entries.get_template_entries())
	return entries


func get_action_params(action_name: String) -> Array[Dictionary]:
	if action_name == "take_damage":
		return [
			{"name": "amount", "mandatory": true, "direction": "input"},
			{"name": "damage_taken", "mandatory": false, "direction": "output"},
		]
	if action_name == "equip_item":
		return [
			{"name": "item", "mandatory": true, "direction": "input"},
			{"name": "slot", "mandatory": true, "direction": "input", "enum": ["weapon", "armor"]},
		]
	return []


func get_condition_params(cond_name: String) -> Array[Dictionary]:
	if cond_name == "hp_above":
		return [{"name": "value", "mandatory": true}]
	return []


func handle_action(action_name: String, data: Dictionary):
	if action_name == "take_damage":
		var character = api.get_value("character")
		if character == null:
			return
		var dmg = data.get("amount", 0)
		character["hp"] -= dmg
		data["damage_taken"] = dmg
		print("[DND] Player takes ", dmg, " damage. HP: ", character["hp"])

	elif action_name == "equip_item":
		var item = data.get("item")
		var slot: String = data.get("slot", "")
		if not item is Dictionary or slot == "":
			return
		var character = api.get_value("character")
		if character == null:
			return
		var raw_refs = data.get("_raw_refs", {})
		var stored_value = ModAPI.make_ref(raw_refs["item"]) if raw_refs.has("item") else item
		character["equipment"][slot] = stored_value
		print("[DND] Equipped ", item.get("name", "unknown"), " to ", slot)

func check_condition(cond_name: String, data: Dictionary) -> bool:
	if cond_name == "hp_above":
		var character = api.get_value("character")
		if character == null:
			return false
		return character.get("hp", 0) > data.get("value", 0)
	push_warning("[DND_system]: " + cond_name + " is not a supported condition")
	return true
