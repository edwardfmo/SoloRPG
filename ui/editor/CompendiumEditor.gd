## Compendium editor: browse and edit compendium entries.
## Left panel: tree of compendiums/types/entries. Right panel: entry detail form.
extends HSplitContainer

var _api: ModAPI = null
var _selected_comp_id: String = ""
var _selected_file: String = ""
var _selected_template: String = ""
var _selected_entry_id: String = ""
var _clipboard: Dictionary = {}

# UI nodes (assigned via scene)
@export var _tree: Tree
@export var _new_comp_btn: Button
@export var _new_entry_btn: MenuButton
@export var _detail_scroll: ScrollContainer
@export var _entry_fields: VBoxContainer
@export var _delete_btn: Button
@export var _duplicate_btn: Button
@export var _copy_btn: Button
@export var _paste_btn: Button
@export var _save_btn: Button
@export var _save_all_btn: Button
@export var _header_label: Label
@export var _confirm_dialog: ConfirmationDialog

var _storage: CompendiumStorage
var _comp_tree: CompendiumTree
var _detail_panel: EntryDetailPanel
var _rename_original_text: String = ""


func _ready():
	_storage = CompendiumStorage.new()
	_comp_tree = CompendiumTree.new()
	_detail_panel = EntryDetailPanel.new()

	_comp_tree.setup(_tree, _storage)
	_detail_panel.setup(_entry_fields, _header_label, _storage)
	_detail_panel.entry_field_changed.connect(_on_entry_field_changed)
	_detail_panel.refresh_requested.connect(_on_detail_refresh_requested)

	_new_entry_btn.get_popup().id_pressed.connect(_on_new_entry_type_selected)
	_tree.item_activated.connect(_on_tree_item_activated)
	_tree.item_edited.connect(_on_tree_item_edited)
	_tree.button_clicked.connect(_on_tree_button_clicked)
	_tree.set_drag_forwarding(_tree_get_drag_data, _tree_can_drop_data, _tree_drop_data)


func set_api(api: ModAPI):
	_api = api
	_storage.setup(api)


func set_module_data(module_id: String, entries: Dictionary):
	_storage.set_module_data(module_id, entries)


func refresh():
	_storage.load_compendiums()
	_comp_tree.rebuild()
	_update_new_entry_menu()


# --- Tree Selection ---

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
			_selected_file = ""
			_selected_template = ""
			_selected_entry_id = ""
			_detail_panel.show_compendium_info(meta["id"])
		"file":
			_selected_comp_id = meta["comp_id"]
			_selected_file = meta["file"]
			_selected_template = ""
			_selected_entry_id = ""
			_detail_panel.show_file_info(meta["comp_id"], meta["file"])
		"template":
			_selected_comp_id = meta["comp_id"]
			_selected_file = meta.get("file", "")
			_selected_template = meta["template"]
			_selected_entry_id = ""
			_detail_panel.show_template_info(meta["comp_id"], meta["template"])
		"entry":
			_selected_comp_id = meta["comp_id"]
			_selected_file = meta.get("file", "")
			_selected_template = meta["template"]
			_selected_entry_id = meta["entry_id"]
			_detail_panel.show_entry(meta["comp_id"], meta["template"], meta["entry_id"])

	_update_buttons()


# --- Buttons ---

func _update_buttons():
	var writable = _storage.is_compendium_writable(_selected_comp_id)
	var is_module = _storage.is_module_comp(_selected_comp_id)
	_new_entry_btn.disabled = not writable or _selected_comp_id == "" or _selected_file == ""
	_delete_btn.disabled = not writable or _selected_entry_id == ""
	_duplicate_btn.disabled = _selected_entry_id == ""
	_copy_btn.disabled = _selected_entry_id == ""
	_paste_btn.disabled = _clipboard.is_empty() or not writable or _selected_comp_id == ""
	_save_btn.disabled = not _storage.is_dirty(_selected_comp_id) or is_module
	_save_all_btn.disabled = not _storage.has_unsaved_changes()


func _update_new_entry_menu():
	var popup = _new_entry_btn.get_popup()
	popup.clear()
	if _api == null:
		return
	var templates = _api._templates.keys()
	for i in templates.size():
		popup.add_item(templates[i], i)


# --- Entry Operations ---

func _build_new_entry(template_id: String) -> Dictionary:
	var entry := {"id": "new_entry", "name": "New Entry"}
	if _api == null:
		return entry
	var tmpl = _api.get_template(template_id)
	for field in tmpl.get("fields", []):
		if field.get("mandatory", false) and field["name"] != "id" and field["name"] != "name":
			match field.get("type", "string"):
				"float":
					entry[field["name"]] = 0.0
				"int":
					entry[field["name"]] = 0
				"array":
					entry[field["name"]] = []
				_:
					entry[field["name"]] = ""
	return entry


func _on_new_compendium():
	_storage.add_compendium()
	_comp_tree.rebuild()


func _on_new_entry_type_selected(idx: int):
	var popup = _new_entry_btn.get_popup()
	var template_id = popup.get_item_text(idx)
	var comp = _storage.get_compendium(_selected_comp_id)
	if comp == null:
		return

	if not comp.has("entries"):
		comp["entries"] = {}
	if not comp["entries"].has(template_id):
		comp["entries"][template_id] = []

	var new_entry = _build_new_entry(template_id)
	comp["entries"][template_id].append(new_entry)
	var target_file = _selected_file if _selected_file != "" else "compendium.json"
	_storage.set_entry_source_file(_selected_comp_id, template_id, "new_entry", target_file)
	_storage.mark_entry_dirty(_selected_comp_id, template_id, "new_entry")
	_comp_tree.rebuild(_selected_comp_id, target_file, template_id, "new_entry")
	_selected_template = template_id
	_selected_entry_id = "new_entry"
	_detail_panel.show_entry(_selected_comp_id, template_id, "new_entry")
	_update_buttons()


func _on_duplicate():
	var entry = _storage.find_entry(_selected_comp_id, _selected_template, _selected_entry_id)
	if entry == null:
		return
	var comp = _storage.get_compendium(_selected_comp_id)
	if comp == null:
		return
	var copy = entry.duplicate(true)
	copy["id"] = entry["id"] + "_copy"
	if copy.has("name"):
		copy["name"] = copy["name"] + " (Copy)"
	comp["entries"][_selected_template].append(copy)
	var target_file = _selected_file if _selected_file != "" else "compendium.json"
	_storage.set_entry_source_file(_selected_comp_id, _selected_template, copy["id"], target_file)
	_storage.mark_entry_dirty(_selected_comp_id, _selected_template, copy["id"])
	_comp_tree.rebuild(_selected_comp_id, target_file, _selected_template, copy["id"])
	_selected_entry_id = copy["id"]
	_detail_panel.show_entry(_selected_comp_id, _selected_template, copy["id"])


func _on_copy():
	var entry = _storage.find_entry(_selected_comp_id, _selected_template, _selected_entry_id)
	if entry == null:
		return
	_clipboard = entry.duplicate(true)
	_clipboard["_source_template"] = _selected_template
	_update_buttons()


func _on_paste():
	if _clipboard.is_empty() or _selected_comp_id == "":
		return
	var comp = _storage.get_compendium(_selected_comp_id)
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
	var target_file = _selected_file if _selected_file != "" else "compendium.json"
	_storage.set_entry_source_file(_selected_comp_id, template_id, pasted["id"], target_file)
	_storage.mark_entry_dirty(_selected_comp_id, template_id, pasted["id"])
	_comp_tree.rebuild(_selected_comp_id, target_file, template_id, pasted["id"])
	_selected_template = template_id
	_selected_entry_id = pasted["id"]
	_detail_panel.show_entry(_selected_comp_id, template_id, pasted["id"])
	_update_buttons()


func _on_delete():
	var comp = _storage.get_compendium(_selected_comp_id)
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
	_storage.mark_dirty(_selected_comp_id)

	var next_comp := _selected_comp_id
	var next_template := _selected_template
	var next_entry := ""
	if del_idx < entries.size():
		next_entry = entries[del_idx].get("id", "")
	elif del_idx > 0:
		next_entry = entries[del_idx - 1].get("id", "")
	else:
		next_template = ""

	_comp_tree.rebuild(next_comp, _selected_file, next_template, next_entry)
	_selected_entry_id = next_entry
	_selected_template = next_template if next_entry != "" else ""

	if next_entry != "":
		_detail_panel.show_entry(next_comp, next_template, next_entry)
	else:
		_detail_panel.clear()
	_update_buttons()


# --- File Operations ---

func _on_tree_button_clicked(item: TreeItem, _column: int, _id: int, _mouse_button: int):
	var meta = item.get_metadata(0)
	if meta == null:
		return
	var item_type = meta.get("type", "")
	if item_type == "compendium":
		_on_new_file(meta["id"])
	elif item_type == "file":
		_selected_comp_id = meta["comp_id"]
		_selected_file = meta["file"]
		_on_delete_file_pressed()


func _on_new_file(comp_id: String = ""):
	if comp_id == "":
		comp_id = _selected_comp_id
	if comp_id == "":
		return
	var base_name = "new_file"
	var file_name = base_name + ".json"
	var existing = _storage.get_compendium_files(comp_id)
	var counter = 2
	while file_name in existing:
		file_name = base_name + "_" + str(counter) + ".json"
		counter += 1
	_storage.add_file(comp_id, file_name)
	_selected_comp_id = comp_id
	_selected_file = file_name
	_comp_tree.rebuild(comp_id, file_name)
	_update_buttons()


func _on_delete_file_pressed():
	if _selected_file == "" or _selected_file == "compendium.json":
		return
	if _storage.file_has_entries(_selected_comp_id, _selected_file):
		_confirm_dialog.dialog_text = "File '%s' contains entries. Delete it and all its entries?" % _selected_file
		_confirm_dialog.confirmed.connect(_on_delete_file_confirmed, CONNECT_ONE_SHOT)
		_confirm_dialog.popup_centered()
	else:
		_on_delete_file_confirmed()


func _on_delete_file_confirmed():
	_storage.delete_file(_selected_comp_id, _selected_file)
	_selected_file = ""
	_selected_template = ""
	_selected_entry_id = ""
	_comp_tree.rebuild(_selected_comp_id)
	_detail_panel.clear()
	_update_buttons()


# --- Rename (double-click) ---

func _on_tree_item_activated():
	var item = _tree.get_selected()
	if item == null:
		return
	var meta = item.get_metadata(0)
	if meta == null:
		return
	var item_type = meta.get("type", "")
	if item_type != "compendium" and item_type != "file":
		return
	if item_type == "compendium" and not _storage.is_compendium_writable(meta["id"]):
		return
	if item_type == "file" and meta.get("file", "") == "compendium.json":
		return
	# Store original text and start editing
	if item_type == "compendium":
		var comp = _storage.get_compendium(meta["id"])
		_rename_original_text = comp.get("name", meta["id"]) if comp else meta["id"]
	else:
		_rename_original_text = meta["file"]
	item.set_text(0, _rename_original_text)
	item.set_editable(0, true)
	_tree.edit_selected(true)


func _on_tree_item_edited():
	var item = _tree.get_selected()
	if item == null:
		return
	item.set_editable(0, false)
	var meta = item.get_metadata(0)
	if meta == null:
		return
	var new_text = item.get_text(0).strip_edges()
	var item_type = meta.get("type", "")

	if item_type == "compendium":
		var comp_id = meta["id"]
		if new_text == "" or new_text == _rename_original_text:
			_comp_tree.rebuild(_selected_comp_id, _selected_file, _selected_template, _selected_entry_id)
			return
		var err = _storage.rename_compendium(comp_id, new_text)
		if err != "":
			push_warning("[CompendiumEditor] Rename failed: " + err)
			_comp_tree.rebuild(_selected_comp_id, _selected_file, _selected_template, _selected_entry_id)
			return
		var new_id = new_text.to_lower().replace(" ", "_").validate_filename().replace(" ", "_")
		_selected_comp_id = new_id
		_comp_tree.rebuild(new_id, _selected_file, _selected_template, _selected_entry_id)
	elif item_type == "file":
		var comp_id = meta["comp_id"]
		var old_name = meta["file"]
		if new_text == "" or new_text == _rename_original_text:
			_comp_tree.rebuild(_selected_comp_id, _selected_file, _selected_template, _selected_entry_id)
			return
		var err = _storage.rename_file(comp_id, old_name, new_text)
		if err != "":
			push_warning("[CompendiumEditor] Rename failed: " + err)
			_comp_tree.rebuild(_selected_comp_id, _selected_file, _selected_template, _selected_entry_id)
			return
		var final_name = new_text if new_text.ends_with(".json") else new_text + ".json"
		_selected_file = final_name.validate_filename()
		_comp_tree.rebuild(_selected_comp_id, _selected_file, _selected_template, _selected_entry_id)

	_update_buttons()


# --- Drag & Drop ---

func _tree_get_drag_data(at_position: Vector2) -> Variant:
	var item = _tree.get_item_at_position(at_position)
	if item == null:
		return null
	var meta = item.get_metadata(0)
	if meta == null or meta.get("type", "") != "entry":
		return null
	# Don't allow dragging from module entries
	if _storage.is_module_comp(meta.get("comp_id", "")):
		return null
	# Visual preview
	var label = Label.new()
	label.text = item.get_text(0)
	_tree.set_drag_preview(label)
	return meta


func _tree_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("type", "") != "entry":
		return false
	var drop_item = _tree.get_item_at_position(at_position)
	if drop_item == null:
		return false
	var drop_meta = drop_item.get_metadata(0)
	if drop_meta == null:
		return false
	var drop_type = drop_meta.get("type", "")
	# Can drop on file or compendium nodes
	if drop_type != "file" and drop_type != "compendium":
		return false
	var dst_comp_id: String
	var dst_file: String
	if drop_type == "file":
		dst_comp_id = drop_meta["comp_id"]
		dst_file = drop_meta["file"]
	else:
		dst_comp_id = drop_meta["id"]
		dst_file = "compendium.json"
	# Don't allow dropping on non-writable compendiums
	if not _storage.is_compendium_writable(dst_comp_id):
		return false
	# Don't allow dropping on module compendiums
	if _storage.is_module_comp(dst_comp_id):
		return false
	# Don't allow dropping on same file
	var src_comp_id = data.get("comp_id", "")
	var src_file = data.get("file", "compendium.json")
	if src_comp_id == dst_comp_id and src_file == dst_file:
		return false
	return true


func _tree_drop_data(at_position: Vector2, data: Variant):
	if not data is Dictionary:
		return
	var drop_item = _tree.get_item_at_position(at_position)
	if drop_item == null:
		return
	var drop_meta = drop_item.get_metadata(0)
	if drop_meta == null:
		return
	var drop_type = drop_meta.get("type", "")
	var dst_comp_id: String
	var dst_file: String
	if drop_type == "file":
		dst_comp_id = drop_meta["comp_id"]
		dst_file = drop_meta["file"]
	elif drop_type == "compendium":
		dst_comp_id = drop_meta["id"]
		dst_file = "compendium.json"
	else:
		return

	var src_comp_id: String = data["comp_id"]
	var template_id: String = data["template"]
	var entry_id: String = data["entry_id"]

	var err = _storage.move_entry(src_comp_id, template_id, entry_id, dst_comp_id, dst_file)
	if err != "":
		push_warning("[CompendiumEditor] Move failed: " + err)
		return

	# Mark source dirty if cross-compendium (move_entry already did this, but ensure label update)
	_selected_comp_id = dst_comp_id
	_selected_file = dst_file
	_selected_template = template_id
	_selected_entry_id = entry_id
	_comp_tree.rebuild(dst_comp_id, dst_file, template_id, entry_id)
	_detail_panel.show_entry(dst_comp_id, template_id, entry_id)
	_update_buttons()


# --- Save ---

func _save_selected():
	_storage.save_compendium(_selected_comp_id)
	_comp_tree.rebuild(_selected_comp_id, _selected_file, _selected_template, _selected_entry_id)
	_update_buttons()


func _save_all_dirty():
	_storage.save_all_dirty()
	_comp_tree.rebuild(_selected_comp_id, _selected_file, _selected_template, _selected_entry_id)
	_update_buttons()


# --- Callbacks from detail panel ---

func _on_entry_field_changed(_comp_id: String, _template_id: String, _entry_id: String):
	_comp_tree.update_labels()
	_update_buttons()


func _on_detail_refresh_requested():
	_detail_panel.show_entry(_selected_comp_id, _selected_template, _selected_entry_id)


# --- Public API ---

func has_unsaved_changes() -> bool:
	return _storage.has_unsaved_changes()


func save_all():
	_save_all_dirty()


func discard_changes():
	_storage.discard_changes()
	refresh()
