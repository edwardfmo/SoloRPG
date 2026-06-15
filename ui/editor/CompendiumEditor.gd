## Compendium editor: browse and edit compendium entries.
## Left panel: tree of compendiums/types/entries. Right panel: entry detail form.
extends HSplitContainer

var _api: ModAPI = null
var _compendiums: Array = []  # Array of loaded compendium data dicts
var _dirty: Dictionary = {}   # compendium_id → true if modified
var _dirty_entries: Dictionary = {}  # "comp_id/template/entry_id" → true
var _selected_comp_id: String = ""
var _selected_template: String = ""
var _selected_entry_id: String = ""
var _is_editor_mode: bool = true  # true = res://, false = user://
var _module_id: String = ""
var _module_entries: Dictionary = {}  # template_id → [entry dicts] from current module

# UI nodes
var _tree: Tree
var _new_comp_btn: Button
var _new_entry_btn: MenuButton
var _detail_panel: VBoxContainer
var _detail_scroll: ScrollContainer
var _entry_fields: VBoxContainer
var _delete_btn: Button
var _duplicate_btn: Button
var _copy_btn: Button
var _paste_btn: Button
var _save_btn: Button
var _clipboard: Dictionary = {}  # empty = nothing copied
var _header_label: Label


func _ready():
	# Determine mode based on whether running from editor
	_is_editor_mode = OS.has_feature("editor")

	# Left panel
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(250, 0)

	_new_comp_btn = Button.new()
	_new_comp_btn.text = "+ New Compendium"
	_new_comp_btn.pressed.connect(_on_new_compendium)
	left_panel.add_child(_new_comp_btn)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_tree_item_selected)
	_tree.hide_root = true
	left_panel.add_child(_tree)

	add_child(left_panel)

	# Right panel
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Top bar: new entry + actions
	var top_bar = HBoxContainer.new()
	_new_entry_btn = MenuButton.new()
	_new_entry_btn.text = "+ New Entry"
	_new_entry_btn.disabled = true
	_new_entry_btn.get_popup().id_pressed.connect(_on_new_entry_type_selected)
	top_bar.add_child(_new_entry_btn)

	_duplicate_btn = Button.new()
	_duplicate_btn.text = "Duplicate"
	_duplicate_btn.disabled = true
	_duplicate_btn.pressed.connect(_on_duplicate)
	top_bar.add_child(_duplicate_btn)

	_copy_btn = Button.new()
	_copy_btn.text = "Copy"
	_copy_btn.disabled = true
	_copy_btn.pressed.connect(_on_copy)
	top_bar.add_child(_copy_btn)

	_paste_btn = Button.new()
	_paste_btn.text = "Paste"
	_paste_btn.disabled = true
	_paste_btn.pressed.connect(_on_paste)
	top_bar.add_child(_paste_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "Delete"
	_delete_btn.disabled = true
	_delete_btn.pressed.connect(_on_delete)
	top_bar.add_child(_delete_btn)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.disabled = true
	save_btn.pressed.connect(_save_selected)
	top_bar.add_child(save_btn)
	_save_btn = save_btn

	right_panel.add_child(top_bar)

	# Header
	_header_label = Label.new()
	_header_label.text = "Select an entry"
	right_panel.add_child(_header_label)

	# Scrollable entry fields
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_entry_fields = VBoxContainer.new()
	_entry_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_entry_fields)
	right_panel.add_child(_detail_scroll)

	add_child(right_panel)


func set_api(api: ModAPI):
	_api = api


func set_module_data(module_id: String, entries: Dictionary):
	_module_id = module_id
	_module_entries = entries


func refresh():
	_load_compendiums()
	_rebuild_tree()
	_update_new_entry_menu()


func _load_compendiums():
	_compendiums.clear()
	var loader = CompendiumLoader.new()
	var loaded = loader.load_all()
	for entry in loaded:
		_compendiums.append(entry["data"])


func _rebuild_tree(select_comp_id: String = "", select_template: String = "", select_entry_id: String = ""):
	# Save collapsed state before clearing
	var collapsed_state := {}  # "comp_id" or "comp_id/template" → collapsed bool
	var root = _tree.get_root()
	if root:
		var comp_item = root.get_first_child()
		while comp_item:
			var meta = comp_item.get_metadata(0)
			if meta and meta["type"] == "compendium":
				collapsed_state[meta["id"]] = comp_item.collapsed
				var type_item = comp_item.get_first_child()
				while type_item:
					var tmeta = type_item.get_metadata(0)
					if tmeta and tmeta["type"] == "template":
						collapsed_state[tmeta["comp_id"] + "/" + tmeta["template"]] = type_item.collapsed
					type_item = type_item.get_next()
			comp_item = comp_item.get_next()

	_tree.clear()
	root = _tree.create_item()

	var item_to_select: TreeItem = null

	for comp_data in _compendiums:
		var comp_id = comp_data.get("id", "unknown")
		var comp_name = comp_data.get("name", comp_id)
		var is_writable = _is_compendium_writable(comp_id)

		var comp_item = _tree.create_item(root)
		var label = comp_name
		if _dirty.has(comp_id):
			label += " *"
		if not is_writable:
			label += " 🔒"
		comp_item.set_text(0, label)
		comp_item.set_metadata(0, {"type": "compendium", "id": comp_id})
		comp_item.collapsed = collapsed_state.get(comp_id, false)

		# Auto-select compendium if it's the target and no entry specified
		if comp_id == select_comp_id and select_entry_id == "" and select_template == "":
			item_to_select = comp_item

		var entries = comp_data.get("entries", {})
		for template_id in entries:
			var type_item = _tree.create_item(comp_item)
			type_item.set_text(0, template_id)
			type_item.set_metadata(0, {"type": "template", "comp_id": comp_id, "template": template_id})
			type_item.collapsed = collapsed_state.get(comp_id + "/" + template_id, true)

			var entry_list = entries[template_id]
			for entry in entry_list:
				var entry_item = _tree.create_item(type_item)
				var entry_label = entry.get("name", entry.get("id", "?"))
				var entry_key = comp_id + "/" + template_id + "/" + entry.get("id", "")
				if _dirty_entries.has(entry_key):
					entry_label += " *"
				entry_item.set_text(0, entry_label)
				entry_item.set_metadata(0, {"type": "entry", "comp_id": comp_id, "template": template_id, "entry_id": entry.get("id", "")})

				# Auto-select entry if it matches the target
				if comp_id == select_comp_id and template_id == select_template and entry.get("id", "") == select_entry_id:
					item_to_select = entry_item

	# Module entries section (if a module is loaded)
	if _module_id != "":
		var module_comp_id = _module_id
		var comp_item = _tree.create_item(root)
		var label = "📦 " + _module_id
		if _dirty.has(module_comp_id):
			label += " *"
		comp_item.set_text(0, label)
		comp_item.set_metadata(0, {"type": "compendium", "id": module_comp_id, "is_module": true})
		comp_item.collapsed = collapsed_state.get(module_comp_id, false)

		if module_comp_id == select_comp_id and select_entry_id == "" and select_template == "":
			item_to_select = comp_item

		for template_id in _module_entries:
			var type_item = _tree.create_item(comp_item)
			type_item.set_text(0, template_id)
			type_item.set_metadata(0, {"type": "template", "comp_id": module_comp_id, "template": template_id})
			type_item.collapsed = collapsed_state.get(module_comp_id + "/" + template_id, true)

			var entry_list = _module_entries[template_id]
			for entry in entry_list:
				var entry_item = _tree.create_item(type_item)
				var entry_label = entry.get("name", entry.get("id", "?"))
				var entry_key = module_comp_id + "/" + template_id + "/" + entry.get("id", "")
				if _dirty_entries.has(entry_key):
					entry_label += " *"
				entry_item.set_text(0, entry_label)
				entry_item.set_metadata(0, {"type": "entry", "comp_id": module_comp_id, "template": template_id, "entry_id": entry.get("id", "")})

				if module_comp_id == select_comp_id and template_id == select_template and entry.get("id", "") == select_entry_id:
					item_to_select = entry_item

	# Apply selection and ensure parents are expanded
	if item_to_select:
		_expand_to_item(item_to_select)
		item_to_select.select(0)


func _expand_to_item(item: TreeItem):
	var parent = item.get_parent()
	while parent and parent != _tree.get_root():
		parent.collapsed = false
		parent = parent.get_parent()


func _on_tree_item_selected():
	var selected = _tree.get_selected()
	if selected == null:
		return
	var meta = selected.get_metadata(0)
	if meta == null:
		return

	match meta["type"]:
		"compendium":
			_selected_comp_id = meta["id"]
			_selected_template = ""
			_selected_entry_id = ""
			_show_compendium_info(meta["id"])
		"template":
			_selected_comp_id = meta["comp_id"]
			_selected_template = meta["template"]
			_selected_entry_id = ""
			_show_template_info(meta["comp_id"], meta["template"])
		"entry":
			_selected_comp_id = meta["comp_id"]
			_selected_template = meta["template"]
			_selected_entry_id = meta["entry_id"]
			_show_entry(meta["comp_id"], meta["template"], meta["entry_id"])

	_update_buttons()


func _update_buttons():
	var writable = _is_compendium_writable(_selected_comp_id)
	var is_module = _is_module_comp(_selected_comp_id)
	_new_entry_btn.disabled = not writable or _selected_comp_id == ""
	_delete_btn.disabled = not writable or _selected_entry_id == ""
	_duplicate_btn.disabled = _selected_entry_id == ""
	_copy_btn.disabled = _selected_entry_id == ""
	_paste_btn.disabled = _clipboard.is_empty() or not writable or _selected_comp_id == ""
	_save_btn.disabled = not _dirty.has(_selected_comp_id) or is_module


func _update_new_entry_menu():
	var popup = _new_entry_btn.get_popup()
	popup.clear()
	if _api == null:
		return
	var templates = _api._templates.keys()
	for i in templates.size():
		popup.add_item(templates[i], i)


func _show_compendium_info(comp_id: String):
	_clear_detail()
	var comp = _get_compendium(comp_id)
	if comp == null:
		return
	_header_label.text = "%s (%s) v%s" % [comp.get("name", ""), comp_id, comp.get("version", "")]


func _show_template_info(comp_id: String, template_id: String):
	_clear_detail()
	_header_label.text = "%s / %s" % [comp_id, template_id]


func _show_entry(comp_id: String, template_id: String, entry_id: String):
	_clear_detail()
	var entry = _find_entry(comp_id, template_id, entry_id)
	if entry == null:
		_header_label.text = "Entry not found"
		return
	_header_label.text = "%s / %s / %s" % [comp_id, template_id, entry_id]
	var writable = _is_compendium_writable(comp_id)
	_render_entry_fields(entry, comp_id, template_id, entry_id, writable)


func _render_entry_fields(entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool):
	for key in entry:
		var row = HBoxContainer.new()

		var key_label = Label.new()
		key_label.text = key
		key_label.custom_minimum_size = Vector2(100, 0)
		row.add_child(key_label)

		var val = entry[key]
		if val is Array:
			var val_field = LineEdit.new()
			val_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			val_field.text = ", ".join(val.map(func(v): return str(v)))
			val_field.editable = editable
			if editable:
				val_field.text_changed.connect(func(new_text):
					entry[key] = new_text.split(", ")
					_mark_entry_dirty(comp_id, template_id, entry_id))
			row.add_child(val_field)
		else:
			var val_field = LineEdit.new()
			val_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			val_field.text = str(val)
			val_field.editable = editable
			if editable:
				val_field.text_changed.connect(func(new_text):
					if new_text.is_valid_float():
						entry[key] = new_text.to_float()
					else:
						entry[key] = new_text
					_mark_entry_dirty(comp_id, template_id, entry_id))
			row.add_child(val_field)

		# Add field button (only for editable and last row)
		_entry_fields.add_child(row)

	if editable:
		var add_field_row = HBoxContainer.new()
		var new_key_field = LineEdit.new()
		new_key_field.placeholder_text = "new field name"
		new_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_field_row.add_child(new_key_field)

		var add_field_btn = Button.new()
		add_field_btn.text = "+ Field"
		add_field_btn.pressed.connect(func():
			var new_key = new_key_field.text.strip_edges()
			if new_key == "" or entry.has(new_key):
				return
			entry[new_key] = ""
			_mark_entry_dirty(comp_id, template_id, entry_id)
			_show_entry(_selected_comp_id, _selected_template, _selected_entry_id))
		add_field_row.add_child(add_field_btn)
		_entry_fields.add_child(add_field_row)


func _clear_detail():
	for child in _entry_fields.get_children():
		child.queue_free()


func _on_new_compendium():
	var comp_data = {
		"id": "new_compendium",
		"name": "New Compendium",
		"version": "1.0.0",
		"author": "",
		"entries": {}
	}
	_compendiums.append(comp_data)
	_mark_dirty("new_compendium")
	_rebuild_tree()


func _on_new_entry_type_selected(idx: int):
	var popup = _new_entry_btn.get_popup()
	var template_id = popup.get_item_text(idx)
	var comp = _get_compendium(_selected_comp_id)
	if comp == null:
		return

	if not comp.has("entries"):
		comp["entries"] = {}
	if not comp["entries"].has(template_id):
		comp["entries"][template_id] = []

	var new_entry = {"id": "new_entry", "name": "New Entry"}
	comp["entries"][template_id].append(new_entry)
	_mark_entry_dirty(_selected_comp_id, template_id, "new_entry")
	_rebuild_tree(_selected_comp_id, template_id, "new_entry")
	_selected_template = template_id
	_selected_entry_id = "new_entry"
	_show_entry(_selected_comp_id, template_id, "new_entry")
	_update_buttons()


func _on_duplicate():
	var entry = _find_entry(_selected_comp_id, _selected_template, _selected_entry_id)
	if entry == null:
		return
	var comp = _get_compendium(_selected_comp_id)
	if comp == null:
		return
	var copy = entry.duplicate(true)
	copy["id"] = entry["id"] + "_copy"
	if copy.has("name"):
		copy["name"] = copy["name"] + " (Copy)"
	comp["entries"][_selected_template].append(copy)
	_mark_entry_dirty(_selected_comp_id, _selected_template, copy["id"])
	_rebuild_tree(_selected_comp_id, _selected_template, copy["id"])
	_selected_entry_id = copy["id"]
	_show_entry(_selected_comp_id, _selected_template, copy["id"])


func _on_copy():
	var entry = _find_entry(_selected_comp_id, _selected_template, _selected_entry_id)
	if entry == null:
		return
	_clipboard = entry.duplicate(true)
	_clipboard["_source_template"] = _selected_template
	_update_buttons()


func _on_paste():
	if _clipboard.is_empty() or _selected_comp_id == "":
		return
	var comp = _get_compendium(_selected_comp_id)
	if comp == null:
		return

	var template_id = _clipboard.get("_source_template", "")
	var pasted = _clipboard.duplicate(true)
	pasted.erase("_source_template")
	pasted["id"] = pasted.get("id", "pasted") + "_paste"
	if pasted.has("name"):
		pasted["name"] = pasted["name"] + " (Pasted)"

	if not comp.has("entries"):
		comp["entries"] = {}
	if not comp["entries"].has(template_id):
		comp["entries"][template_id] = []
	comp["entries"][template_id].append(pasted)
	_mark_entry_dirty(_selected_comp_id, template_id, pasted["id"])
	_rebuild_tree(_selected_comp_id, template_id, pasted["id"])
	_selected_template = template_id
	_selected_entry_id = pasted["id"]
	_show_entry(_selected_comp_id, template_id, pasted["id"])
	_update_buttons()


func _on_delete():
	var comp = _get_compendium(_selected_comp_id)
	if comp == null:
		return
	var entries = comp["entries"].get(_selected_template, [])
	var del_idx := -1
	for i in entries.size():
		if entries[i].get("id", "") == _selected_entry_id:
			del_idx = i
			break
	if del_idx == -1:
		return

	entries.remove_at(del_idx)
	_mark_dirty(_selected_comp_id)

	# Determine what to select next
	var next_comp := _selected_comp_id
	var next_template := _selected_template
	var next_entry := ""
	if del_idx < entries.size():
		# Select the one below (same index after removal)
		next_entry = entries[del_idx].get("id", "")
	elif del_idx > 0:
		# Select the one above
		next_entry = entries[del_idx - 1].get("id", "")
	else:
		# Category is empty — select compendium
		next_template = ""

	_rebuild_tree(next_comp, next_template, next_entry)
	_selected_entry_id = next_entry
	_selected_template = next_template if next_entry != "" else ""

	if next_entry != "":
		_show_entry(next_comp, next_template, next_entry)
	else:
		_clear_detail()
		_header_label.text = "Select an entry"
	_update_buttons()


func _save_selected():
	if _selected_comp_id == "" or _is_module_comp(_selected_comp_id):
		return
	if not _dirty.has(_selected_comp_id):
		return
	var comp = _get_compendium(_selected_comp_id)
	if comp == null:
		return
	_save_compendium(comp)
	_dirty.erase(_selected_comp_id)
	# Clear entry-level dirty for this compendium
	var keys_to_erase := []
	for key in _dirty_entries:
		if key.begins_with(_selected_comp_id + "/"):
			keys_to_erase.append(key)
	for key in keys_to_erase:
		_dirty_entries.erase(key)
	_rebuild_tree(_selected_comp_id, _selected_template, _selected_entry_id)
	_update_buttons()
	# Reload into API
	if _api:
		_api._entries.clear()
		var loader = CompendiumLoader.new()
		var loaded = loader.load_all()
		for entry in loaded:
			_api.register_compendium(entry["id"], entry["data"])


func _save_all_dirty():
	for comp_data in _compendiums:
		var comp_id = comp_data.get("id", "")
		if not _dirty.has(comp_id):
			continue
		_save_compendium(comp_data)
	# Clear only non-module dirty state
	var module_dirty = _dirty.has(_module_id) if _module_id != "" else false
	_dirty.clear()
	if module_dirty:
		_dirty[_module_id] = true
	# Clear non-module entry dirt
	var module_entry_keys := []
	for key in _dirty_entries:
		if _module_id != "" and key.begins_with(_module_id + "/"):
			module_entry_keys.append(key)
	_dirty_entries.clear()
	for key in module_entry_keys:
		_dirty_entries[key] = true
	_rebuild_tree()
	# Reload into API
	if _api:
		_api._entries.clear()
		var loader = CompendiumLoader.new()
		var loaded = loader.load_all()
		for entry in loaded:
			_api.register_compendium(entry["id"], entry["data"])


func _save_compendium(comp_data: Dictionary):
	var comp_id = comp_data.get("id", "new_compendium")
	var base_dir: String
	if _is_editor_mode:
		base_dir = SystemUtils.BUNDLED_COMPENDIUMS_DIR
	else:
		base_dir = SystemUtils.COMPENDIUMS_DIR

	var dir_path = base_dir + "/" + comp_id
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file_path = dir_path + "/compendium.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("[CompendiumEditor] Failed to save: " + file_path)
		return
	file.store_string(JSON.stringify(comp_data, "\t"))
	file.close()
	print("[CompendiumEditor] Saved: " + file_path)


func _mark_dirty(comp_id: String):
	var was_dirty = _dirty.has(comp_id)
	_dirty[comp_id] = true
	if not was_dirty:
		_update_tree_labels()


func _mark_entry_dirty(comp_id: String, template_id: String, entry_id: String):
	_dirty[comp_id] = true
	var entry_key = comp_id + "/" + template_id + "/" + entry_id
	var was_dirty = _dirty_entries.has(entry_key)
	_dirty_entries[entry_key] = true
	if not was_dirty:
		_update_tree_labels()


func _is_module_comp(comp_id: String) -> bool:
	return _module_id != "" and comp_id == _module_id


func _is_compendium_writable(comp_id: String) -> bool:
	# Module entries are always editable
	if _is_module_comp(comp_id):
		return true
	# In editor mode everything is writable, in deployed mode only user:// compendiums
	if _is_editor_mode:
		return true
	# Check if compendium exists in user:// dir
	var user_path = SystemUtils.COMPENDIUMS_DIR + "/" + comp_id
	return DirAccess.dir_exists_absolute(user_path) or not _comp_exists_in_bundled(comp_id)


func _comp_exists_in_bundled(comp_id: String) -> bool:
	var bundled_path = SystemUtils.BUNDLED_COMPENDIUMS_DIR + "/" + comp_id
	return DirAccess.dir_exists_absolute(bundled_path)


func _get_compendium(comp_id: String):
	if _is_module_comp(comp_id):
		return {"id": _module_id, "name": _module_id, "entries": _module_entries}
	for comp in _compendiums:
		if comp.get("id", "") == comp_id:
			return comp
	return null


func _find_entry(comp_id: String, template_id: String, entry_id: String):
	if _is_module_comp(comp_id):
		var entries = _module_entries.get(template_id, [])
		for entry in entries:
			if entry.get("id", "") == entry_id:
				return entry
		return null
	var comp = _get_compendium(comp_id)
	if comp == null:
		return null
	var entries = comp.get("entries", {}).get(template_id, [])
	for entry in entries:
		if entry.get("id", "") == entry_id:
			return entry
	return null


func has_unsaved_changes() -> bool:
	for comp_id in _dirty:
		if not _is_module_comp(comp_id):
			return true
	return false


func save_all():
	_save_all_dirty()


func discard_changes():
	_dirty.clear()
	_dirty_entries.clear()
	refresh()


func _update_tree_labels():
	var root = _tree.get_root()
	if root == null:
		return
	var comp_item = root.get_first_child()
	while comp_item:
		var meta = comp_item.get_metadata(0)
		if meta and meta["type"] == "compendium":
			var comp_id = meta["id"]
			var comp = _get_compendium(comp_id)
			var comp_name = comp.get("name", comp_id) if comp else comp_id
			var label = ""
			if _is_module_comp(comp_id):
				label = "📦 " + comp_id
			else:
				label = comp_name
			if _dirty.has(comp_id):
				label += " *"
			if not _is_compendium_writable(comp_id):
				label += " 🔒"
			comp_item.set_text(0, label)

			# Walk entry children
			var type_item = comp_item.get_first_child()
			while type_item:
				var tmeta = type_item.get_metadata(0)
				if tmeta and tmeta["type"] == "template":
					var template_id = tmeta["template"]
					var entry_item = type_item.get_first_child()
					while entry_item:
						var emeta = entry_item.get_metadata(0)
						if emeta and emeta["type"] == "entry":
							var entry_id = emeta["entry_id"]
							var entry = _find_entry(comp_id, template_id, entry_id)
							var entry_label = entry.get("name", entry.get("id", "?")) if entry else "?"
							var entry_key = comp_id + "/" + template_id + "/" + entry_id
							if _dirty_entries.has(entry_key):
								entry_label += " *"
							entry_item.set_text(0, entry_label)
						entry_item = entry_item.get_next()
				type_item = type_item.get_next()
		comp_item = comp_item.get_next()
