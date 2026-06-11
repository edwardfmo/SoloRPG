extends Plugin

const BACKTRACK_KEY = "_backtrack"


func get_actions() -> Array[String]:
	return []


func get_conditions() -> Array[String]:
	return []


func get_ui_panels() -> Array[Dictionary]:
	return [
		{"slot": "sidebar_icon", "scene": "res://plugins/backtrack/BacktrackButton.tscn", "id": "backtrack_btn"}
	]


func on_game_start(context: Dictionary):
	context.erase(BACKTRACK_KEY)


func on_pre_choice(context: Dictionary):
	# Save current context (without the backtrack entry itself to avoid nesting)
	var snapshot = context.duplicate(true)
	snapshot.erase(BACKTRACK_KEY)
	context[BACKTRACK_KEY] = snapshot
