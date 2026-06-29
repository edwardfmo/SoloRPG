## Panel for editing module-specific settings and showing dependency status.
## Two modes:
##   - Browse mode (open): Shows Close button only
##   - Confirm mode (open_confirm): Shows Save/Cancel buttons for pre-save validation
## Missing plugins/actions shown in red, version mismatches in yellow.
extends Control

signal closed
signal confirmed_save
signal cancelled_save

@export var _title_label: Label
@export var _settings_container: VBoxContainer
@export var _close_button: Button
@export var _save_button: Button
@export var _cancel_button: Button

var _api: ModAPI = null
var _module_settings: Dictionary = {}
var _section_label_scene = preload("res://ui/shared/SectionLabel.tscn")


func _ready():
	_close_button.pressed.connect(_on_close)
	_save_button.pressed.connect(_on_save)
	_cancel_button.pressed.connect(_on_cancel)
	visible = false


func set_api(api: ModAPI):
	_api = api


## Open in browse mode (Settings button). Close only.
func open(module_nodes: Array, module_settings: Dictionary, module_id: String = "", module_entries: Dictionary = {}):
	_module_settings = module_settings.duplicate()
	_close_button.visible = true
	_save_button.visible = false
	_cancel_button.visible = false
	_title_label.text = "Module Settings"
	_rebuild(module_nodes, module_id, module_entries)
	visible = true


## Open in confirm mode (pre-save). Save/Cancel buttons.
## Returns true if there are issues (caller should wait for signal).
func open_confirm(module_nodes: Array, module_settings: Dictionary, module_id: String = "", module_entries: Dictionary = {}) -> bool:
	_module_settings = module_settings.duplicate()
	_close_button.visible = false
	_save_button.visible = true
	_cancel_button.visible = true
	_title_label.text = "Review & Save"
	var has_issues = _rebuild(module_nodes, module_id, module_entries)
	if has_issues:
		_save_button.text = "Save Anyway"
	else:
		_save_button.text = "Save"
	visible = true
	return has_issues


## Returns the current module settings.
func get_module_settings() -> Dictionary:
	return _module_settings


func _on_close():
	visible = false
	closed.emit()


func _on_save():
	visible = false
	confirmed_save.emit()


func _on_cancel():
	visible = false
	cancelled_save.emit()


## Rebuilds the panel content. Returns true if there are dependency issues.
func _rebuild(module_nodes: Array, module_id: String, module_entries: Dictionary) -> bool:
	for child in _settings_container.get_children():
		child.queue_free()

	if _api == null:
		return false

	var has_issues = _build_dependency_section(module_nodes, module_id, module_entries)
	_build_settings_section(module_nodes)
	return has_issues


# ─── Dependency Section ──────────────────────────────────────────────────────


func _build_dependency_section(module_nodes: Array, module_id: String, module_entries: Dictionary) -> bool:
	var provider_map = _api.get_provider_map()
	var all_actions = _api.get_all_actions()
	var all_conditions = _api.get_all_conditions()
	var loaded_plugins = _api.plugins.keys()

	# Collect used types and entry refs
	var used_actions: Array[String] = []
	var used_conditions: Array[String] = []
	var entry_refs: Array[String] = []

	for node_data in module_nodes:
		for action in node_data.get("on_enter", []):
			var t = action.get("type", "")
			if t != "" and not used_actions.has(t):
				used_actions.append(t)
			_collect_entry_refs(action, entry_refs)
		for choice in node_data.get("choices", []):
			for action in choice.get("actions", []):
				var t = action.get("type", "")
				if t != "" and not used_actions.has(t):
					used_actions.append(t)
				_collect_entry_refs(action, entry_refs)
			for cond in choice.get("conditions", []):
				var t = cond.get("type", "")
				if t != "" and not used_conditions.has(t):
					used_conditions.append(t)
				_collect_entry_refs(cond, entry_refs)

	var has_plugins = not used_actions.is_empty() or not used_conditions.is_empty()
	var has_comps = not entry_refs.is_empty()

	if not has_plugins and not has_comps:
		return false

	var has_issues := false

	# --- Plugin Dependencies ---
	if has_plugins:
		_add_section("Plugin Dependencies")

		# Group by plugin
		var plugin_groups := {}
		for action in used_actions:
			var pname = _infer_plugin(action)
			if not plugin_groups.has(pname):
				plugin_groups[pname] = {"actions_warn": [], "conditions_warn": [], "loaded": loaded_plugins.has(pname)}
			if not all_actions.has(action):
				plugin_groups[pname]["actions_warn"].append(action)

		for cond in used_conditions:
			var pname = _infer_plugin(cond)
			if not plugin_groups.has(pname):
				plugin_groups[pname] = {"actions_warn": [], "conditions_warn": [], "loaded": loaded_plugins.has(pname)}
			if not all_conditions.has(cond):
				plugin_groups[pname]["conditions_warn"].append(cond)

		# Sort: missing first, then warnings, then ok
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

		for pname in missing_names:
			var info = plugin_groups[pname]
			_add_status_label(pname + " (missing)", Color(1, 0.3, 0.3))
			has_issues = true
			for a in info["actions_warn"]:
				_add_detail_label("action: " + a, Color(1, 0.3, 0.3))
			for c in info["conditions_warn"]:
				_add_detail_label("condition: " + c, Color(1, 0.3, 0.3))

		for pname in warn_names:
			var info = plugin_groups[pname]
			var meta = _api.plugin_metadata.get(pname, {})
			var version = meta.get("version", "")
			_add_status_label(pname + (" v" + version if version != "" else ""), Color(1, 0.85, 0.2))
			has_issues = true
			for a in info["actions_warn"]:
				_add_detail_label("action: " + a + " (unresolved)", Color(1, 0.85, 0.2))
			for c in info["conditions_warn"]:
				_add_detail_label("condition: " + c + " (unresolved)", Color(1, 0.85, 0.2))

		for pname in ok_names:
			var meta = _api.plugin_metadata.get(pname, {})
			var version = meta.get("version", "")
			_add_info_label("  ✓ " + pname + (" v" + version if version != "" else ""))

	# --- Compendium Dependencies ---
	if has_comps:
		var comp_loader = CompendiumLoader.new()
		var all_comp_meta = comp_loader.scan_metadata()
		var installed_comps := {}
		for meta in all_comp_meta:
			installed_comps[meta.get("id", "")] = meta

		var comp_groups := {}
		for ref in entry_refs:
			var parsed = ModAPI.parse_entry_ref(ref)
			var comp_id = parsed["namespace"]
			var entry_id = parsed["entry_id"]
			if loaded_plugins.has(comp_id):
				continue
			var is_module_local = (comp_id == module_id and module_id != "")
			if not comp_groups.has(comp_id):
				comp_groups[comp_id] = {"entries_warn": [], "installed": installed_comps.has(comp_id) or is_module_local, "is_module_local": is_module_local}

			if is_module_local:
				var found := false
				for tmpl_id in module_entries:
					for e in module_entries[tmpl_id]:
						if e.get("id", "") == entry_id:
							found = true
							break
					if found:
						break
				if not found:
					comp_groups[comp_id]["entries_warn"].append(entry_id)
			else:
				var full_id = comp_id + "." + entry_id
				var found := false
				for tmpl_id in _api._entries:
					if _api._entries[tmpl_id].has(full_id):
						found = true
						break
				if not found:
					comp_groups[comp_id]["entries_warn"].append(entry_id)

		if not comp_groups.is_empty():
			_add_section("Compendium Dependencies")

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

			for comp_id in comp_missing:
				var info = comp_groups[comp_id]
				_add_status_label(comp_id + " (missing)", Color(1, 0.3, 0.3))
				has_issues = true
				for e in info["entries_warn"]:
					_add_detail_label("entry: " + e, Color(1, 0.3, 0.3))

			for comp_id in comp_warn:
				var info = comp_groups[comp_id]
				var is_module_local = info.get("is_module_local", false)
				var suffix = " (module-local)" if is_module_local else ""
				_add_status_label(comp_id + suffix, Color(1, 0.85, 0.2))
				has_issues = true
				for e in info["entries_warn"]:
					_add_detail_label("entry: " + e + " (not found)", Color(1, 0.85, 0.2))

			for comp_id in comp_ok:
				var info = comp_groups[comp_id]
				var is_module_local = info.get("is_module_local", false)
				var suffix = " (module-local)" if is_module_local else ""
				_add_info_label("  ✓ " + comp_id + suffix)

	return has_issues


# ─── Settings Section ────────────────────────────────────────────────────────


func _build_settings_section(module_nodes: Array):
	var module_defs = _api.get_module_setting_defs()
	if module_defs.is_empty():
		return

	# Determine which plugins are used
	var used_plugin_ids := {}
	for node_data in module_nodes:
		for action in node_data.get("on_enter", []):
			var pname = _infer_plugin(action.get("type", ""))
			if pname != "":
				used_plugin_ids[pname] = true
		for choice in node_data.get("choices", []):
			for action in choice.get("actions", []):
				var pname = _infer_plugin(action.get("type", ""))
				if pname != "":
					used_plugin_ids[pname] = true
			for cond in choice.get("conditions", []):
				var pname = _infer_plugin(cond.get("type", ""))
				if pname != "":
					used_plugin_ids[pname] = true

	_add_section("Module Settings")

	# Group by plugin
	var by_plugin := {}
	for def in module_defs:
		var plugin_id = def.get("plugin", "")
		if not by_plugin.has(plugin_id):
			by_plugin[plugin_id] = []
		by_plugin[plugin_id].append(def)

	var any_shown := false
	for plugin_id in by_plugin:
		if plugin_id != "" and not used_plugin_ids.has(plugin_id):
			continue
		if plugin_id != "":
			_add_plugin_header(plugin_id)
		for def in by_plugin[plugin_id]:
			_add_setting_row(def)
		any_shown = true

	if not any_shown:
		_add_info_label("No module settings for referenced plugins.")


# ─── UI Builders ─────────────────────────────────────────────────────────────


func _add_section(text: String):
	var label = _section_label_scene.instantiate()
	label.text = text
	_settings_container.add_child(label)


func _add_plugin_header(plugin_id: String):
	var label = Label.new()
	label.text = "  " + plugin_id
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(0.8, 0.9, 1.0)
	_settings_container.add_child(label)


func _add_info_label(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.5, 0.5, 0.5)
	_settings_container.add_child(label)


func _add_status_label(text: String, color: Color):
	var label = Label.new()
	label.text = "  ⚠ " + text
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = color
	_settings_container.add_child(label)


func _add_detail_label(text: String, color: Color):
	var label = Label.new()
	label.text = "      " + text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = color
	_settings_container.add_child(label)


func _add_setting_row(def: Dictionary):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label = Label.new()
	label.text = def.get("label", def.get("path", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var path = def.get("path", "")
	var current_value = _module_settings.get(path, _api.get_module_setting(path))
	var type = def.get("type", "string")

	var reset_btn = Button.new()
	reset_btn.text = "↺"
	reset_btn.tooltip_text = "Reset to default"
	reset_btn.disabled = not _module_settings.has(path)
	var default_value = def.get("default")
	var input_widget: Control = null

	match type:
		"bool":
			var checkbox = CheckBox.new()
			checkbox.button_pressed = bool(current_value) if current_value != null else false
			checkbox.toggled.connect(func(pressed):
				_set_module_setting(path, pressed)
				reset_btn.disabled = false
			)
			input_widget = checkbox
			row.add_child(checkbox)
		"int":
			var spin = SpinBox.new()
			spin.min_value = def.get("min", -999999)
			spin.max_value = def.get("max", 999999)
			spin.step = 1
			spin.value = int(current_value) if current_value != null else 0
			spin.custom_minimum_size.x = 100
			spin.value_changed.connect(func(val):
				_set_module_setting(path, int(val))
				reset_btn.disabled = false
			)
			input_widget = spin
			row.add_child(spin)
		"float":
			var spin = SpinBox.new()
			spin.min_value = def.get("min", -999999.0)
			spin.max_value = def.get("max", 999999.0)
			spin.step = def.get("step", 0.1)
			spin.value = float(current_value) if current_value != null else 0.0
			spin.custom_minimum_size.x = 100
			spin.value_changed.connect(func(val):
				_set_module_setting(path, val)
				reset_btn.disabled = false
			)
			input_widget = spin
			row.add_child(spin)
		"string":
			var line_edit = LineEdit.new()
			line_edit.text = str(current_value) if current_value != null else ""
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_edit.text_submitted.connect(func(txt):
				_set_module_setting(path, txt)
				reset_btn.disabled = false
			)
			input_widget = line_edit
			row.add_child(line_edit)
		"enum":
			var option_btn = OptionButton.new()
			var options = def.get("options", [])
			for opt in options:
				option_btn.add_item(opt)
			var idx = options.find(current_value) if current_value != null else 0
			if idx >= 0:
				option_btn.selected = idx
			option_btn.item_selected.connect(func(i):
				_set_module_setting(path, options[i])
				reset_btn.disabled = false
			)
			input_widget = option_btn
			row.add_child(option_btn)

	reset_btn.pressed.connect(func():
		_module_settings.erase(path)
		reset_btn.disabled = true
		_reset_widget(input_widget, type, default_value, def.get("options", []))
	)
	row.add_child(reset_btn)

	_settings_container.add_child(row)


func _set_module_setting(path: String, value):
	_module_settings[path] = value


func _reset_widget(widget: Control, type: String, default_value, options: Array):
	if widget == null:
		return
	match type:
		"bool":
			(widget as CheckBox).set_pressed_no_signal(bool(default_value) if default_value != null else false)
		"int":
			(widget as SpinBox).set_value_no_signal(int(default_value) if default_value != null else 0)
		"float":
			(widget as SpinBox).set_value_no_signal(float(default_value) if default_value != null else 0.0)
		"string":
			(widget as LineEdit).text = str(default_value) if default_value != null else ""
		"enum":
			var idx = options.find(default_value) if default_value != null else 0
			if idx >= 0:
				(widget as OptionButton).selected = idx


# ─── Helpers ─────────────────────────────────────────────────────────────────


func _infer_plugin(type_string: String) -> String:
	var dot_idx = type_string.find(".")
	if dot_idx > 0:
		return type_string.substr(0, dot_idx)
	return type_string


func _collect_entry_refs(data: Dictionary, out_refs: Array[String]):
	for key in data:
		if key == "type":
			continue
		var val = data[key]
		if val is String and val.begins_with("@") and not out_refs.has(val):
			out_refs.append(val)
