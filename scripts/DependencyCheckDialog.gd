## Popup dialog that shows plugin dependencies before saving a module.
## Displays required plugins and flags missing ones or unresolved actions/conditions.
extends AcceptDialog

signal confirmed_save
signal cancelled_save

var _content: RichTextLabel


func _init():
	title = "Plugin Dependencies"
	size = Vector2(500, 400)
	get_ok_button().text = "Save Anyway"
	add_cancel_button("Cancel")

	_content = RichTextLabel.new()
	_content.bbcode_enabled = true
	_content.custom_minimum_size = Vector2(480, 300)
	_content.fit_content = true
	add_child(_content)

	confirmed.connect(func(): confirmed_save.emit())
	canceled.connect(func(): cancelled_save.emit())


## Checks module nodes against available plugins and shows the result.
## Returns true if there are issues, false if everything is clean (auto-saves).
func check_and_show(module_nodes: Array, api: ModAPI) -> bool:
	var provider_map = api.get_provider_map()
	var all_actions = api.get_all_actions()
	var all_conditions = api.get_all_conditions()
	var loaded_plugins = api.plugins.keys()

	# Collect all used actions and conditions from the module
	var used_actions: Array[String] = []
	var used_conditions: Array[String] = []

	for node_data in module_nodes:
		var on_enter = node_data.get("on_enter", [])
		for action in on_enter:
			var t = action.get("type", "")
			if t != "" and not used_actions.has(t):
				used_actions.append(t)

		var choices = node_data.get("choices", [])
		for choice in choices:
			var conditions = choice.get("conditions", [])
			for cond in conditions:
				var t = cond.get("type", "")
				if t != "" and not used_conditions.has(t):
					used_conditions.append(t)

	if used_actions.is_empty() and used_conditions.is_empty():
		return false

	# Group everything by inferred plugin (prefix before first dot)
	# Each entry: {actions_provided: [], actions_missing: [], conditions_provided: [], conditions_missing: [], loaded: bool}
	var plugin_groups := {}

	for action in used_actions:
		var pname = _infer_plugin(action)
		if not plugin_groups.has(pname):
			plugin_groups[pname] = {"actions_ok": [], "actions_warn": [], "conditions_ok": [], "conditions_warn": [], "loaded": loaded_plugins.has(pname)}
		if all_actions.has(action):
			plugin_groups[pname]["actions_ok"].append(action)
		else:
			plugin_groups[pname]["actions_warn"].append(action)

	for cond in used_conditions:
		var pname = _infer_plugin(cond)
		if not plugin_groups.has(pname):
			plugin_groups[pname] = {"actions_ok": [], "actions_warn": [], "conditions_ok": [], "conditions_warn": [], "loaded": loaded_plugins.has(pname)}
		if all_conditions.has(cond):
			plugin_groups[pname]["conditions_ok"].append(cond)
		else:
			plugin_groups[pname]["conditions_warn"].append(cond)

	# Build display
	var has_issues = false
	var text := "[b]Required Plugins:[/b]\n\n"

	# Sort plugins: missing first, then with warnings, then clean — alphabetical within each
	var missing_names := []
	var warn_names := []
	var ok_names := []
	for pname in plugin_groups:
		var info = plugin_groups[pname]
		if not info["loaded"]:
			missing_names.append(pname)
		elif info["actions_warn"].size() > 0 or info["conditions_warn"].size() > 0:
			warn_names.append(pname)
		else:
			ok_names.append(pname)
	missing_names.sort()
	warn_names.sort()
	ok_names.sort()
	var sorted_names = missing_names + warn_names + ok_names

	for pname in sorted_names:
		var info = plugin_groups[pname]
		var is_loaded = info["loaded"]
		var has_missing_types = info["actions_warn"].size() > 0 or info["conditions_warn"].size() > 0

		if is_loaded:
			var version = ""
			var meta = api.plugin_metadata.get(pname, {})
			if meta.has("version"):
				version = meta["version"]
			if has_missing_types:
				text += "[color=green]✓[/color] [b]" + pname + "[/b]"
				if version != "":
					text += " [color=yellow]v" + version + "[/color]"
				text += "\n"
				has_issues = true
			else:
				text += "[color=green]✓[/color] [b]" + pname + "[/b]"
				if version != "":
					text += " [color=green]v" + version + "[/color]"
				text += "\n"
		else:
			text += "[color=red]✗[/color] [b]" + pname + "[/b] [color=red](missing)[/color]\n"
			has_issues = true

		# Sort actions/conditions: warnings first, then ok — alphabetical within each
		var actions_warn = info["actions_warn"].duplicate()
		var actions_ok = info["actions_ok"].duplicate()
		var conds_warn = info["conditions_warn"].duplicate()
		var conds_ok = info["conditions_ok"].duplicate()
		actions_warn.sort()
		actions_ok.sort()
		conds_warn.sort()
		conds_ok.sort()

		if is_loaded:
			for a in actions_warn:
				text += "    [color=yellow]⚠ action: " + a + "[/color]\n"
			for a in actions_ok:
				text += "    [color=green]action: " + a + "[/color]\n"
			for c in conds_warn:
				text += "    [color=yellow]⚠ condition: " + c + "[/color]\n"
			for c in conds_ok:
				text += "    [color=green]condition: " + c + "[/color]\n"
		else:
			for a in actions_warn + actions_ok:
				text += "    [color=red]action: " + a + "[/color]\n"
			for c in conds_warn + conds_ok:
				text += "    [color=red]condition: " + c + "[/color]\n"
		text += "\n"

	if not has_issues:
		text += "[color=green]All dependencies satisfied.[/color]"
		get_ok_button().text = "Save"
	else:
		get_ok_button().text = "Save Anyway"

	_content.text = text
	popup_centered()
	return true


## Infers plugin name from a type string (e.g. "dnd.take_damage" → "dnd").
func _infer_plugin(type_string: String) -> String:
	var dot_idx = type_string.find(".")
	if dot_idx > 0:
		return type_string.substr(0, dot_idx)
	return type_string
