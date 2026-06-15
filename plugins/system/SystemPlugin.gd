extends Plugin


func get_actions() -> Array[String]:
	return ["system.show_view"]


func get_conditions() -> Array[String]:
	return ["system.check"]


func get_action_params(action_name: String) -> Array[Dictionary]:
	if action_name == "show_view":
		return [{"name": "view", "mandatory": true}]
	return []


func get_condition_params(cond_name: String) -> Array[Dictionary]:
	if cond_name == "check":
		return [
			{"name": "path", "mandatory": true},
			{"name": "op", "mandatory": true, "enum": ["==", "!=", ">", "<", ">=", "<="]},
			{"name": "value", "mandatory": true},
		]
	return []


func handle_action(action_name: String, data: Dictionary, _context):
	if action_name == "show_view":
		var view_id = data.get("view", "")
		if view_id == "":
			return
		var params := {}
		for key in data:
			if key != "type" and key != "view":
				params[key] = data[key]
		if api:
			api.show_overlay(view_id, params)


func check_condition(cond_name: String, data: Dictionary, context) -> bool:
	if cond_name == "check":
		return _check(data, context)
	return false


func _check(data: Dictionary, context) -> bool:
	var path: String = data.get("path", "")
	var op: String = data.get("op", "==")
	var value = data.get("value")

	if path == "":
		return false

	# Read left side from context (raw, no resolve — compare refs directly)
	var left = _read_path(context, path)

	# Resolve right side: supports $path, @entry, /r dice, or literal
	var right = _resolve_value(value, context)

	# If left is a _ref wrapper and right is a string starting with @, compare ref strings
	if left is Dictionary and left.has("_ref") and right is String and right.begins_with("@"):
		return _compare(left["_ref"], op, right)

	# If left is a _ref, resolve it for value comparison
	if left is Dictionary and left.has("_ref") and api != null:
		left = api.evaluate(left["_ref"])

	return _compare(left, op, right)


func _read_path(context, path: String) -> Variant:
	var keys = path.split(".")
	var current: Variant = context
	for k in keys:
		if not current is Dictionary or not current.has(k):
			return null
		current = current[k]
	return current


func _resolve_value(value, context) -> Variant:
	if not value is String:
		return value
	if value.begins_with("$$"):
		var resolved = api.get_context_path(context, value.substr(2))
		return api.evaluate(resolved) if resolved is String else resolved
	if value.begins_with("$"):
		return api.get_context_path(context, value.substr(1))
	return api.evaluate(value)


func _compare(left, op: String, right) -> bool:
	match op:
		"==":
			return left == right
		"!=":
			return left != right
		">":
			return _to_num(left) > _to_num(right)
		"<":
			return _to_num(left) < _to_num(right)
		">=":
			return _to_num(left) >= _to_num(right)
		"<=":
			return _to_num(left) <= _to_num(right)
	return false


func _to_num(val) -> float:
	if val is float or val is int:
		return float(val)
	if val is String and val.is_valid_float():
		return val.to_float()
	return 0.0
