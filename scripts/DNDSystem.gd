class_name DNDSystem
extends Node

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
