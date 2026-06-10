extends Plugin


func get_actions() -> Array[String]:
	return ["system.show_view"]


func get_conditions() -> Array[String]:
	return []


func handle_action(action_name: String, data: Dictionary, _context):
	if action_name == "show_view":
		var view_id = data.get("view", "")
		if view_id == "":
			push_warning("[System] show_view: no view id provided")
			return
		# Pass all remaining params (excluding "type" and "view") to the overlay
		var params := {}
		for key in data:
			if key != "type" and key != "view":
				params[key] = data[key]
		if api:
			api.show_overlay(view_id, params)
