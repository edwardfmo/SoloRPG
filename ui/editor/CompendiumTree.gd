class_name CompendiumTree
extends RefCounted

var _tree: Tree
var _storage: CompendiumStorage


func setup(tree: Tree, storage: CompendiumStorage):
	_tree = tree
	_storage = storage


func rebuild(select_comp_id: String = "", select_template: String = "", select_entry_id: String = ""):
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
				if _storage.is_entry_dirty(comp_id, template_id, entry.get("id", "")):
					entry_label += " *"
				entry_item.set_text(0, entry_label)
				entry_item.set_metadata(0, {"type": "entry", "comp_id": comp_id, "template": template_id, "entry_id": entry.get("id", "")})

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
	var comp_item = root.get_first_child()
	while comp_item:
		var meta = comp_item.get_metadata(0)
		if meta and meta["type"] == "compendium":
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
			comp_item.set_text(0, label)

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
							var entry = _storage.find_entry(comp_id, template_id, entry_id)
							var entry_label = entry.get("name", entry.get("id", "?")) if entry else "?"
							if _storage.is_entry_dirty(comp_id, template_id, entry_id):
								entry_label += " *"
							entry_item.set_text(0, entry_label)
						entry_item = entry_item.get_next()
				type_item = type_item.get_next()
		comp_item = comp_item.get_next()


func _save_collapsed_state() -> Dictionary:
	var collapsed_state := {}
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
	return collapsed_state


func _expand_to_item(item: TreeItem):
	var parent = item.get_parent()
	while parent and parent != _tree.get_root():
		parent.collapsed = false
		parent = parent.get_parent()
