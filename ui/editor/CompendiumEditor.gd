## Compendium editor: browse and edit compendium entries.
## Left panel: tree of compendiums/types/entries. Right panel: entry detail form.
extends HSplitContainer

var _api: ModAPI = null
var _selected_comp_id: String = ""
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
@export var _header_label: Label

var _storage: CompendiumStorage
var _comp_tree: CompendiumTree
var _detail_panel: EntryDetailPanel


func _ready():
	_storage = CompendiumStorage.new()
	_comp_tree = CompendiumTree.new()
	_detail_panel = EntryDetailPanel.new()

	_comp_tree.setup(_tree, _storage)
	_detail_panel.setup(_entry_fields, _header_label, _storage)
	_detail_panel.entry_field_changed.connect(_on_entry_field_changed)
	_detail_panel.refresh_requested.connect(_on_detail_refresh_requested)

	_new_entry_btn.get_popup().id_pressed.connect(_on_new_entry_type_selected)


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
			_selected_template = ""
			_selected_entry_id = ""
			_detail_panel.show_compendium_info(meta["id"])
		"template":
			_selected_comp_id = meta["comp_id"]
			_selected_template = meta["template"]
			_selected_entry_id = ""
			_detail_panel.show_template_info(meta["comp_id"], meta["template"])
		"entry":
			_selected_comp_id = meta["comp_id"]
			_selected_template = meta["template"]
			_selected_entry_id = meta["entry_id"]
			_detail_panel.show_entry(meta["comp_id"], meta["template"], meta["entry_id"])

	_update_buttons()


# --- Buttons ---

func _update_buttons():
	var writable = _storage.is_compendium_writable(_selected_comp_id)
	var is_module = _storage.is_module_comp(_selected_comp_id)
	_new_entry_btn.disabled = not writable or _selected_comp_id == ""
	_delete_btn.disabled = not writable or _selected_entry_id == ""
	_duplicate_btn.disabled = _selected_entry_id == ""
	_copy_btn.disabled = _selected_entry_id == ""
	_paste_btn.disabled = _clipboard.is_empty() or not writable or _selected_comp_id == ""
	_save_btn.disabled = not _storage.is_dirty(_selected_comp_id) or is_module


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
	_storage.mark_entry_dirty(_selected_comp_id, template_id, "new_entry")
	_comp_tree.rebuild(_selected_comp_id, template_id, "new_entry")
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
	_storage.mark_entry_dirty(_selected_comp_id, _selected_template, copy["id"])
	_comp_tree.rebuild(_selected_comp_id, _selected_template, copy["id"])
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
	_storage.mark_entry_dirty(_selected_comp_id, template_id, pasted["id"])
	_comp_tree.rebuild(_selected_comp_id, template_id, pasted["id"])
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

	_comp_tree.rebuild(next_comp, next_template, next_entry)
	_selected_entry_id = next_entry
	_selected_template = next_template if next_entry != "" else ""

	if next_entry != "":
		_detail_panel.show_entry(next_comp, next_template, next_entry)
	else:
		_detail_panel.clear()
	_update_buttons()


# --- Save ---

func _save_selected():
	_storage.save_compendium(_selected_comp_id)
	_comp_tree.rebuild(_selected_comp_id, _selected_template, _selected_entry_id)
	_update_buttons()


func _save_all_dirty():
	_storage.save_all_dirty()
	_comp_tree.rebuild()


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
