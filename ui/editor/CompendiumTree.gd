class_name CompendiumTree
extends RefCounted

var _tree: Tree
var _storage: CompendiumStorage


func setup(tree: Tree, storage: CompendiumStorage):
	_tree = tree
	_storage = storage


func rebuild(select_comp_id: String = "", select_file: String = "", select_template: String = "", select_entry_id: String = ""):
	var collapsed_state := _save_collapsed_state()

	_tree.clear()
	var root = _tree.create_item()
	var item_to_select: TreeItem = null

	for comp_data in _storage.get_compendiums():
		var comp_id = comp_data.get("id", "unknown")
		var comp_name = comp_data.get("name", comp_id)
		var is_writable = _storage.is_compendium_writable(comp_id)

		var comp_item = _tree.create_item(root)
		var label = comp_name
		if _storage.is_dirty(comp_id):
			label += " *"
		if not is_writable:
			label += " 🔒"
		comp_item.set_text(0, label)
		comp_item.set_metadata(0, {"type": "compendium", "id": comp_id})
		comp_item.collapsed = collapsed_state.get(comp_id, false)
		if is_writable:
			comp_item.add_button(0, _get_add_icon(), 0, false, "Add file")

		if comp_id == select_comp_id and select_file == "" and select_entry_id == "" and select_template == "":
			item_to_select = comp_item

		# Group entries by source file
		var files = _storage.get_compendium_files(comp_id)
		for file_name in files:
			var file_item = _tree.create_item(comp_item)
			file_item.set_text(0, "📄 " + file_name)
			file_item.set_metadata(0, {"type": "file", "comp_id": comp_id, "file": file_name})
			file_item.collapsed = collapsed_state.get(comp_id + "/" + file_name, true)
			if is_writable and file_name != "compendium.json":
				file_item.add_button(0, _get_remove_icon(), 0, false, "Delete file")

			if comp_id == select_comp_id and file_name == select_file and select_template == "" and select_entry_id == "":
				item_to_select = file_item

			# Get entries belonging to this file, grouped by template
			var file_entries = _storage.get_entries_for_file(comp_id, file_name)
			for template_id in file_entries:
				var type_item = _tree.create_item(file_item)
				type_item.set_text(0, template_id)
				type_item.set_metadata(0, {"type": "template", "comp_id": comp_id, "file": file_name, "template": template_id})
				type_item.collapsed = collapsed_state.get(comp_id + "/" + file_name + "/" + template_id, true)

				for entry in file_entries[template_id]:
					var entry_item = _tree.create_item(type_item)
					var entry_label = entry.get("name", entry.get("id", "?"))
					if _storage.is_entry_dirty(comp_id, template_id, entry.get("id", "")):
						entry_label += " *"
					entry_item.set_text(0, entry_label)
					entry_item.set_metadata(0, {"type": "entry", "comp_id": comp_id, "file": file_name, "template": template_id, "entry_id": entry.get("id", "")})

					if comp_id == select_comp_id and template_id == select_template and entry.get("id", "") == select_entry_id:
						item_to_select = entry_item

	# Module entries section
	var module_id = _storage.get_module_id()
	if module_id != "":
		var module_entries = _storage.get_module_entries()
		var comp_item = _tree.create_item(root)
		var label = "📦 " + module_id
		if _storage.is_dirty(module_id):
			label += " *"
		comp_item.set_text(0, label)
		comp_item.set_metadata(0, {"type": "compendium", "id": module_id, "is_module": true})
		comp_item.collapsed = collapsed_state.get(module_id, false)

		if module_id == select_comp_id and select_entry_id == "" and select_template == "":
			item_to_select = comp_item

		for template_id in module_entries:
			var type_item = _tree.create_item(comp_item)
			type_item.set_text(0, template_id)
			type_item.set_metadata(0, {"type": "template", "comp_id": module_id, "template": template_id})
			type_item.collapsed = collapsed_state.get(module_id + "/" + template_id, true)

			var entry_list = module_entries[template_id]
			for entry in entry_list:
				var entry_item = _tree.create_item(type_item)
				var entry_label = entry.get("name", entry.get("id", "?"))
				if _storage.is_entry_dirty(module_id, template_id, entry.get("id", "")):
					entry_label += " *"
				entry_item.set_text(0, entry_label)
				entry_item.set_metadata(0, {"type": "entry", "comp_id": module_id, "template": template_id, "entry_id": entry.get("id", "")})

				if module_id == select_comp_id and template_id == select_template and entry.get("id", "") == select_entry_id:
					item_to_select = entry_item

	if item_to_select:
		_expand_to_item(item_to_select)
		item_to_select.select(0)


func update_labels():
	var root = _tree.get_root()
	if root == null:
		return
	_update_labels_recursive(root)


func _update_labels_recursive(item: TreeItem):
	var meta = item.get_metadata(0)
	if meta:
		match meta.get("type", ""):
			"compendium":
				var comp_id = meta["id"]
				var comp = _storage.get_compendium(comp_id)
				var comp_name = comp.get("name", comp_id) if comp else comp_id
				var label = ""
				if _storage.is_module_comp(comp_id):
					label = "📦 " + comp_id
				else:
					label = comp_name
				if _storage.is_dirty(comp_id):
					label += " *"
				if not _storage.is_compendium_writable(comp_id):
					label += " 🔒"
				item.set_text(0, label)
			"entry":
				var comp_id = meta["comp_id"]
				var template_id = meta["template"]
				var entry_id = meta["entry_id"]
				var entry = _storage.find_entry(comp_id, template_id, entry_id)
				var entry_label = entry.get("name", entry.get("id", "?")) if entry else "?"
				if _storage.is_entry_dirty(comp_id, template_id, entry_id):
					entry_label += " *"
				item.set_text(0, entry_label)

	var child = item.get_first_child()
	while child:
		_update_labels_recursive(child)
		child = child.get_next()


func _save_collapsed_state() -> Dictionary:
	var collapsed_state := {}
	_save_collapsed_recursive(_tree.get_root(), collapsed_state)
	return collapsed_state


func _save_collapsed_recursive(item: TreeItem, state: Dictionary):
	if item == null:
		return
	var meta = item.get_metadata(0)
	if meta:
		match meta.get("type", ""):
			"compendium":
				state[meta["id"]] = item.collapsed
			"file":
				state[meta["comp_id"] + "/" + meta["file"]] = item.collapsed
			"template":
				var file_key = meta.get("file", "")
				if file_key != "":
					state[meta["comp_id"] + "/" + file_key + "/" + meta["template"]] = item.collapsed
				else:
					state[meta["comp_id"] + "/" + meta["template"]] = item.collapsed
	var child = item.get_first_child()
	while child:
		_save_collapsed_recursive(child, state)
		child = child.get_next()


func _expand_to_item(item: TreeItem):
	var parent = item.get_parent()
	while parent and parent != _tree.get_root():
		parent.collapsed = false
		parent = parent.get_parent()


var _add_icon: Texture2D = null
var _remove_icon: Texture2D = null

func _get_add_icon() -> Texture2D:
	if _add_icon == null:
		_add_icon = _create_text_texture("+", Color.GREEN)
	return _add_icon


func _get_remove_icon() -> Texture2D:
	if _remove_icon == null:
		_remove_icon = _create_text_texture("x", Color.RED)
	return _remove_icon


func _create_text_texture(text: String, color: Color) -> Texture2D:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	# Draw a simple shape: + or x
	if text == "+":
		for i in range(4, 12):
			img.set_pixel(i, 7, color)
			img.set_pixel(i, 8, color)
			img.set_pixel(7, i, color)
			img.set_pixel(8, i, color)
	else:
		for i in range(4, 12):
			img.set_pixel(i, i, color)
			img.set_pixel(i, 15 - i, color)
			if i + 1 < size:
				img.set_pixel(i + 1, i, color)
				img.set_pixel(i + 1, 15 - i, color)
	return ImageTexture.create_from_image(img)
