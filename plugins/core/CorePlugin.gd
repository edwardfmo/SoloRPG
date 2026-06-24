extends Plugin


func get_actions() -> Array[String]:
	return ["core.show_view", "core.set", "core.clear"]


func get_conditions() -> Array[String]:
	return ["core.check", "core.exists"]


func get_action_params(action_name: String) -> Array[Dictionary]:
	if action_name == "show_view":
		return [{"name": "view", "mandatory": true}]
	if action_name == "set":
		return [{"name": "path", "mandatory": true}, {"name": "value", "mandatory": false}]
	if action_name == "clear":
		return [{"name": "path", "mandatory": true}]
	return []


func get_condition_params(cond_name: String) -> Array[Dictionary]:
	if cond_name == "check":
		return [
			{"name": "path", "mandatory": true},
			{"name": "op", "mandatory": true, "enum": ["==", "!=", ">", "<", ">=", "<="]},
			{"name": "value", "mandatory": true},
		]
	if cond_name == "exists":
		return [{"name": "path", "mandatory": true}]
	return []


func handle_action(action_name: String, data: Dictionary):
	if action_name == "show_view":
		var view_id = data.get("view", "")
		if view_id == "":
			return
		var params := {}
		for key in data:
			if key != "type" and key != "view" and not key.begins_with("_"):
				params[key] = data[key]
		if api:
			api.show_overlay(view_id, params)
	elif action_name == "set":
		var path: String = data.get("path", "")
		if path == "":
			return
		var value = data.get("value", "")
		if value is String:
			value = _resolve_value(value)
		api.set_value(path, value)
	elif action_name == "clear":
		var path: String = data.get("path", "")
		if path == "":
			return
		api.erase_value(path)


func check_condition(cond_name: String, data: Dictionary) -> bool:
	if cond_name == "check":
		return _check(data)
	if cond_name == "exists":
		return _exists(data)
	return false


func _check(data: Dictionary) -> bool:
	var path: String = data.get("path", "")
	var op: String = data.get("op", "==")
	var value = data.get("value")

	if path == "":
		return false

	# Read left side from context (raw, no resolve — compare refs directly)
	var left = _read_path(path)

	# Resolve right side: supports $path, @entry, /r dice, or literal
	var right = _resolve_value(value)

	# If left is a _ref wrapper and right is a string starting with @, compare ref strings
	if left is Dictionary and left.has("_ref") and right is String and right.begins_with("@"):
		return _compare(left["_ref"], op, right)

	# If left is a _ref, resolve it for value comparison
	if left is Dictionary and left.has("_ref") and api != null:
		left = api.evaluate(left["_ref"])

	return _compare(left, op, right)


func _read_path(path: String) -> Variant:
	var keys = path.split(".")
	var current: Variant = api.context
	for k in keys:
		if not current is Dictionary or not current.has(k):
			return null
		current = current[k]
	return current


func _resolve_value(value) -> Variant:
	if not value is String:
		return value
	if value.begins_with("$$"):
		var resolved = api.get_value(value.substr(2))
		return api.evaluate(resolved) if resolved is String else resolved
	if value.begins_with("$"):
		return api.get_value(value.substr(1))
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


func _exists(data: Dictionary) -> bool:
	var path: String = data.get("path", "")
	if path == "":
		return false
	var keys = path.split(".")
	var current: Variant = api.context
	for k in keys:
		if not current is Dictionary or not current.has(k):
			return false
		current = current[k]
	return true
