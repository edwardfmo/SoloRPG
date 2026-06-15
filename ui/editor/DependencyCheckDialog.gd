## Popup dialog that shows plugin dependencies before saving a module.
## Displays required plugins and flags missing ones or unresolved actions/conditions.
extends AcceptDialog

signal confirmed_save
signal cancelled_save

var _content: RichTextLabel


func _init():
	title = "Plugin Dependencies"
	size = Vector2(500, 400)
	exclusive = false
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
func check_and_show(module_nodes: Array, api: ModAPI, module_id: String = "", module_entries: Dictionary = {}) -> bool:
	var provider_map = api.get_provider_map()
	var all_actions = api.get_all_actions()
	var all_conditions = api.get_all_conditions()
	var loaded_plugins = api.plugins.keys()

	# Collect all used actions, conditions, and entry references from the module
	var used_actions: Array[String] = []
	var used_conditions: Array[String] = []
	var entry_refs: Array[String] = []  # raw @references

	for node_data in module_nodes:
		var on_enter = node_data.get("on_enter", [])
		for action in on_enter:
			var t = action.get("type", "")
			if t != "" and not used_actions.has(t):
				used_actions.append(t)
			_collect_entry_refs(action, entry_refs)

		var choices = node_data.get("choices", [])
		for choice in choices:
			for action in choice.get("actions", []):
				var t = action.get("type", "")
				if t != "" and not used_actions.has(t):
					used_actions.append(t)
				_collect_entry_refs(action, entry_refs)
			var conditions = choice.get("conditions", [])
			for cond in conditions:
				var t = cond.get("type", "")
				if t != "" and not used_conditions.has(t):
					used_conditions.append(t)
				_collect_entry_refs(cond, entry_refs)

	var has_plugins = not used_actions.is_empty() or not used_conditions.is_empty()
	var has_comps = not entry_refs.is_empty()

	if not has_plugins and not has_comps:
		return false

	# Group everything by inferred plugin (prefix before first dot)
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
	var text := ""

	# --- Plugin section ---
	if has_plugins:
		text += "[b]Required Plugins:[/b]\n\n"

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
					text += "[color=yellow]⚠[/color] [b]" + pname + "[/b]"
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
					text += "    [color=yellow]action: " + a + "[/color]\n"
				for a in actions_ok:
					text += "    [color=green]action: " + a + "[/color]\n"
				for c in conds_warn:
					text += "    [color=yellow]condition: " + c + "[/color]\n"
				for c in conds_ok:
					text += "    [color=green]condition: " + c + "[/color]\n"
			else:
				for a in actions_warn + actions_ok:
					text += "    [color=red]action: " + a + "[/color]\n"
				for c in conds_warn + conds_ok:
					text += "    [color=red]condition: " + c + "[/color]\n"
			text += "\n"

	# --- Compendium section ---
	if has_comps:
		text += "[b]Required Compendiums:[/b]\n\n"

		# Parse refs into {compendium_id → [entry_ids]}
		var comp_groups := {}  # comp_id → {entries_ok: [], entries_warn: []}
		var comp_loader = CompendiumLoader.new()
		var all_comp_meta = comp_loader.scan_metadata()
		var installed_comps := {}
		for meta in all_comp_meta:
			installed_comps[meta.get("id", "")] = meta

		for ref in entry_refs:
			var parsed = ModAPI.parse_entry_ref(ref)
			var comp_id = parsed["namespace"]
			var entry_id = parsed["entry_id"]
			# Skip plugin-seeded entries
			if loaded_plugins.has(comp_id):
				continue
			var is_module_local = (comp_id == module_id and module_id != "")
			if not comp_groups.has(comp_id):
				comp_groups[comp_id] = {"entries_ok": [], "entries_warn": [], "installed": installed_comps.has(comp_id) or is_module_local, "is_module_local": is_module_local}
			# Module-local entries: check against module's own entries (yellow if missing, never red)
			if is_module_local:
				var found_in_module = false
				for tmpl_id in module_entries:
					for e in module_entries[tmpl_id]:
						if e.get("id", "") == entry_id:
							found_in_module = true
							break
					if found_in_module:
						break
				if found_in_module:
					comp_groups[comp_id]["entries_ok"].append(entry_id)
				else:
					comp_groups[comp_id]["entries_warn"].append(entry_id)
				continue
			# Check if entry exists in the registry
			var full_id = comp_id + "." + entry_id
			var found = false
			for tmpl_id in api._entries:
				if api._entries[tmpl_id].has(full_id):
					found = true
					break
			if found:
				comp_groups[comp_id]["entries_ok"].append(entry_id)
			else:
				comp_groups[comp_id]["entries_warn"].append(entry_id)

		# Sort: missing first, then warnings, then ok
		var comp_missing := []
		var comp_warn := []
		var comp_ok := []
		for comp_id in comp_groups:
			var info = comp_groups[comp_id]
			if not info["installed"]:
				comp_missing.append(comp_id)
			elif info["entries_warn"].size() > 0:
				comp_warn.append(comp_id)
			else:
				comp_ok.append(comp_id)
		comp_missing.sort()
		comp_warn.sort()
		comp_ok.sort()
		var sorted_comps = comp_missing + comp_warn + comp_ok

		for comp_id in sorted_comps:
			var info = comp_groups[comp_id]
			var is_installed = info["installed"]
			var is_module_local = info.get("is_module_local", false)

			if is_installed:
				var version = ""
				if not is_module_local and installed_comps.has(comp_id):
					version = installed_comps[comp_id].get("version", "")
				var has_warn = info["entries_warn"].size() > 0
				if has_warn:
					text += "[color=yellow]⚠[/color] [b]" + comp_id + "[/b]"
					if is_module_local:
						text += " [color=yellow](module-local)[/color]"
					elif version != "":
						text += " [color=yellow]v" + version + "[/color]"
					text += "\n"
					has_issues = true
				else:
					text += "[color=green]✓[/color] [b]" + comp_id + "[/b]"
					if is_module_local:
						text += " [color=green](module-local)[/color]"
					elif version != "":
						text += " [color=green]v" + version + "[/color]"
					text += "\n"
			else:
				# Never show module-local as red/missing
				text += "[color=red]✗[/color] [b]" + comp_id + "[/b] [color=red](missing)[/color]\n"
				has_issues = true

			var entries_warn = info["entries_warn"].duplicate()
			var entries_ok = info["entries_ok"].duplicate()
			entries_warn.sort()
			entries_ok.sort()

			if is_installed:
				for e in entries_warn:
					text += "    [color=yellow]entry: " + e + "[/color]\n"
				for e in entries_ok:
					text += "    [color=green]entry: " + e + "[/color]\n"
			else:
				for e in entries_warn + entries_ok:
					text += "    [color=red]entry: " + e + "[/color]\n"
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


## Collects @entry references from a data dict's values.
func _collect_entry_refs(data: Dictionary, out_refs: Array[String]):
	for key in data:
		if key == "type":
			continue
		var val = data[key]
		if val is String and val.begins_with("@") and not out_refs.has(val):
			out_refs.append(val)
