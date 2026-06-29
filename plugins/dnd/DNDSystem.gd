extends Plugin

const ALIGNMENTS: Array[String] = [
	"Lawful Good", "Lawful Neutral", "Lawful Evil",
	"Neutral Good", "True Neutral", "Neutral Evil",
	"Chaotic Good", "Chaotic Neutral", "Chaotic Evil",
]

var _character_entries
var _item_entries


func _init_entries():
	if _character_entries == null:
		_character_entries = load(resolve_path("DNDCharacterEntries.gd")).new()
		_item_entries = load(resolve_path("DNDItemEntries.gd")).new()


func get_settings() -> Array[Dictionary]:
	return [
		{
			"path": "dnd.point_buy_sum",
			"label": "Point Buy Total",
			"type": "int",
			"scope": "module",
			"default": 27,
			"min": 0,
			"max": 1000,
		},
		{
			"path": "dnd.min_char",
			"label": "Minimum ability score",
			"type": "int",
			"scope": "module",
			"default": 8,
			"min": 0,
			"max": 40,
		},
		{
			"path": "dnd.max_char",
			"label": "Maximum ability score",
			"type": "int",
			"scope": "module",
			"default": 15,
			"min": 0,
			"max": 40,
		},
	]


func get_actions() -> Array[String]:
	return ["dnd.take_damage", "dnd.equip_item"]


func get_conditions() -> Array[String]:
	return ["dnd.hp_above"]


func get_ui_panels() -> Array[Dictionary]:
	return [
		{"slot": "game_hud", "scene": resolve_path("HpBar.tscn"), "id": "dnd_hp_bar"},
		{"slot": "game_overlay", "scene": resolve_path("CharacterSheet.tscn"), "id": "dnd_character_sheet"},
		{"slot": "game_overlay", "scene": resolve_path("CharacterCreator.tscn"), "id": "dnd_character_creator"},
		{"slot": "sidebar_icon", "scene": resolve_path("CharacterSheetButton.tscn"), "id": "dnd_cs_button"}
	]


func on_game_start():
	api.set_value("character", {})
	api.show_overlay("dnd_character_creator", {"context_path": "character"})
	var overlay = api.get_overlay_node("dnd_character_creator")
	if overlay:
		return overlay.closed


func get_templates() -> Array[Dictionary]:
	_init_entries()
	var templates: Array[Dictionary] = []
	templates.append_array(_character_entries.get_templates())
	templates.append_array(_item_entries.get_templates())
	return templates


func get_template_entries() -> Dictionary:
	_init_entries()
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


## Returns the ability modifier for a given ability score value.
static func get_modifier(score: int) -> int:
	return int(floor(score / 2.0)) - 5


## Returns the point cost to increase TO this score value (modifier at that value, min 1).
static func get_increment_cost(score: int) -> int:
	return max(get_modifier(score), 1)


## Returns the total point buy cost for a score, given the free base value.
static func get_score_cost(score: int, base: int) -> int:
	var total := 0
	for i in range(base + 1, score + 1):
		total += get_increment_cost(i)
	return total


## Returns the ability modifier for a given ability score.
## Accepts flexible naming: "Strength", "STR", "str", "Dexterity", "Dex", etc.
static func get_char_mod(character: Dictionary, ability: String) -> int:
	var key := _normalize_ability(ability)
	var scores = character.get("ability_scores", {})
	var val: int = scores.get(key, 10)
	return get_modifier(val)


static func _normalize_ability(ability: String) -> String:
	match ability.to_lower().substr(0, 3):
		"str":
			return "str"
		"dex":
			return "dex"
		"con":
			return "con"
		"int":
			return "int"
		"wis":
			return "wis"
		"cha":
			return "cha"
	return ability.to_lower()
