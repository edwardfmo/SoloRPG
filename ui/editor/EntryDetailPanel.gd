class_name EntryDetailPanel
extends RefCounted

var _entry_fields: VBoxContainer
var _header_label: Label
var _storage: CompendiumStorage

var _field_row_scene = preload("res://ui/editor/EntryFieldRow.tscn")
var _add_field_row_scene = preload("res://ui/editor/AddFieldRow.tscn")

signal entry_field_changed(comp_id: String, template_id: String, entry_id: String)
signal refresh_requested()


func setup(entry_fields: VBoxContainer, header_label: Label, storage: CompendiumStorage):
	_entry_fields = entry_fields
	_header_label = header_label
	_storage = storage


func show_compendium_info(comp_id: String):
	_clear()
	var comp = _storage.get_compendium(comp_id)
	if comp == null:
		return
	_header_label.text = "%s (%s) v%s" % [comp.get("name", ""), comp_id, comp.get("version", "")]


func show_template_info(comp_id: String, template_id: String):
	_clear()
	_header_label.text = "%s / %s" % [comp_id, template_id]


func show_entry(comp_id: String, template_id: String, entry_id: String):
	_clear()
	var entry = _storage.find_entry(comp_id, template_id, entry_id)
	if entry == null:
		_header_label.text = "Entry not found"
		return
	_header_label.text = "%s / %s / %s" % [comp_id, template_id, entry_id]
	var writable = _storage.is_compendium_writable(comp_id)
	var field_schema := _get_field_schema(template_id)
	_render_fields(entry, comp_id, template_id, entry_id, writable, field_schema)


func clear():
	_clear()
	_header_label.text = "Select an entry"


func _clear():
	for child in _entry_fields.get_children():
		child.queue_free()


func _render_fields(entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool, field_schema: Dictionary):
	# Build ordered list of keys: id and name always first, then schema fields, then extras
	var ordered_keys: Array[String] = ["id", "name"]
	var schema_order := _get_field_order(template_id)
	for key in schema_order:
		if key not in ordered_keys:
			ordered_keys.append(key)
	for key in entry:
		if key not in ordered_keys:
			ordered_keys.append(key)

	for key in ordered_keys:
		var schema = field_schema.get(key, {})
		var ref_types = schema.get("entry_ref_types", [])
		var is_entry_ref = schema.get("type", "") == "entry_ref"
		var is_ref_array = ref_types.size() > 0 and schema.get("type", "") == "array"
		var is_mandatory = schema.get("mandatory", false) or key == "id" or key == "name"
		var has_value = entry.has(key)

		var val = entry.get(key, _default_for_type(schema))

		var row = _field_row_scene.instantiate()
		var key_label: Label = row.get_node("KeyLabel")
		var val_field: LineEdit = row.get_node("ValueField")

		key_label.text = key + " *" if is_mandatory else key

		if is_entry_ref:
			# Single entry reference — use HintedLineEdit
			var hinted = HintedLineEdit.new()
			hinted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hinted.text = str(val) if val else ""
			hinted.editable = editable
			hinted.placeholder_text = "(required)" if is_mandatory else "(optional)"
			hinted.hints = _get_ref_hints(ref_types)
			if editable:
				hinted.text_changed.connect(_make_field_setter(entry, key, comp_id, template_id, entry_id, "entry_ref"))
			val_field.replace_by(hinted)
			val_field.queue_free()
			_entry_fields.add_child(row)

		elif is_ref_array or val is Array:
			# Array field — render each value in its own row with remove button
			row.queue_free()
			var arr_val: Array = val if val is Array else []
			_render_array_field(key, arr_val, entry, comp_id, template_id, entry_id, editable, ref_types, is_mandatory)

		else:
			val_field.text = str(val) if has_value else ""
			val_field.editable = editable
			val_field.placeholder_text = "(required)" if is_mandatory else "(optional)"
			if editable:
				val_field.text_changed.connect(_make_field_setter(entry, key, comp_id, template_id, entry_id, schema.get("type", "string")))
			_entry_fields.add_child(row)

	if editable:
		var add_field_row = _add_field_row_scene.instantiate()
		var new_key_field: LineEdit = add_field_row.get_node("NewKeyField")
		var add_field_btn: Button = add_field_row.get_node("AddButton")

		add_field_btn.pressed.connect(func():
			var new_key = new_key_field.text.strip_edges()
			if new_key == "" or entry.has(new_key):
				return
			entry[new_key] = ""
			_on_field_changed(comp_id, template_id, entry_id)
			refresh_requested.emit())
		_entry_fields.add_child(add_field_row)


func _on_field_changed(comp_id: String, template_id: String, entry_id: String):
	_storage.mark_entry_dirty(comp_id, template_id, entry_id)
	entry_field_changed.emit(comp_id, template_id, entry_id)


## Render an array field as multiple rows: one per existing value + a blank "add" row.
func _render_array_field(key: String, arr: Array, entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool, ref_types: Array, is_mandatory: bool):
	var is_ref = ref_types.size() > 0
	var hints := _get_ref_hints(ref_types) if is_ref else [] as Array[String]

	# Header label row
	var header_row = HBoxContainer.new()
	var header_label = Label.new()
	header_label.custom_minimum_size = Vector2(100, 0)
	header_label.text = key + " *" if is_mandatory else key
	header_row.add_child(header_label)
	_entry_fields.add_child(header_row)

	# Container for array item rows (for easy refresh)
	var items_container = VBoxContainer.new()
	_entry_fields.add_child(items_container)

	var _rebuild := [Callable()]
	_rebuild[0] = func():
		for child in items_container.get_children():
			child.queue_free()

		for i in arr.size():
			var item_row = HBoxContainer.new()
			# Indent
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(100, 0)
			item_row.add_child(spacer)

			var field: LineEdit
			if is_ref:
				var hinted = HintedLineEdit.new()
				hinted.hints = hints
				field = hinted
			else:
				field = LineEdit.new()
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			field.text = str(arr[i])
			field.editable = editable

			if editable:
				var idx = i
				field.text_submitted.connect(func(new_text: String):
					if new_text.strip_edges() == "":
						arr.remove_at(idx)
					else:
						arr[idx] = new_text
					entry[key] = arr
					_on_field_changed(comp_id, template_id, entry_id)
					_rebuild[0].call())
				field.focus_exited.connect(func():
					var current = field.text.strip_edges()
					if current == "":
						arr.remove_at(idx)
						entry[key] = arr
						_on_field_changed(comp_id, template_id, entry_id)
						_rebuild[0].call()
					elif current != str(arr[idx]):
						arr[idx] = current
						entry[key] = arr
						_on_field_changed(comp_id, template_id, entry_id))

			item_row.add_child(field)

			if editable:
				var remove_btn = Button.new()
				remove_btn.text = "X"
				remove_btn.custom_minimum_size = Vector2(24, 0)
				var idx = i
				remove_btn.pressed.connect(func():
					arr.remove_at(idx)
					entry[key] = arr
					_on_field_changed(comp_id, template_id, entry_id)
					_rebuild[0].call())
				item_row.add_child(remove_btn)

			items_container.add_child(item_row)

		# Blank "add new" row
		if editable:
			var add_row = HBoxContainer.new()
			var add_spacer = Control.new()
			add_spacer.custom_minimum_size = Vector2(100, 0)
			add_row.add_child(add_spacer)

			var add_field: LineEdit
			if is_ref:
				var hinted = HintedLineEdit.new()
				hinted.hints = hints
				hinted.hint_selected.connect(func(value: String):
					arr.append(value)
					entry[key] = arr
					_on_field_changed(comp_id, template_id, entry_id)
					_rebuild[0].call())
				add_field = hinted
			else:
				add_field = LineEdit.new()
			add_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_field.placeholder_text = "Add new..."
			add_field.editable = true

			add_field.text_submitted.connect(func(new_text: String):
				var val = new_text.strip_edges()
				if val == "":
					return
				arr.append(val)
				entry[key] = arr
				_on_field_changed(comp_id, template_id, entry_id)
				_rebuild[0].call())

			add_row.add_child(add_field)
			items_container.add_child(add_row)

	_rebuild[0].call()


## Build a lookup dict of field_name → field_schema from the template definition.
func _get_field_schema(template_id: String) -> Dictionary:
	if _storage._api == null:
		return {}
	var tmpl = _storage._api.get_template(template_id)
	if tmpl.is_empty():
		return {}
	var schema := {}
	for field in tmpl.get("fields", []):
		schema[field["name"]] = field
	return schema


## Return ordered field names from the template definition.
func _get_field_order(template_id: String) -> Array[String]:
	if _storage._api == null:
		return []
	var tmpl = _storage._api.get_template(template_id)
	if tmpl.is_empty():
		return []
	var order: Array[String] = []
	for field in tmpl.get("fields", []):
		order.append(field["name"])
	return order


## Return a type-appropriate default value for a field schema.
static func _default_for_type(schema: Dictionary) -> Variant:
	var type = schema.get("type", "string")
	match type:
		"float":
			return 0.0
		"int":
			return 0
		"array":
			return []
		_:
			return ""


## Create a callable that writes edited values into the entry dict.
## For optional fields not yet in the entry, the value is only written on first edit.
func _make_field_setter(entry: Dictionary, key: String, comp_id: String, template_id: String, entry_id: String, type: String) -> Callable:
	match type:
		"entry_ref":
			return func(new_text: String):
				entry[key] = new_text
				_on_field_changed(comp_id, template_id, entry_id)
		"float":
			return func(new_text: String):
				if new_text == "":
					entry.erase(key)
				elif new_text.is_valid_float():
					entry[key] = new_text.to_float()
				else:
					entry[key] = new_text
				_on_field_changed(comp_id, template_id, entry_id)
		"int":
			return func(new_text: String):
				if new_text == "":
					entry.erase(key)
				elif new_text.is_valid_int():
					entry[key] = new_text.to_int()
				else:
					entry[key] = new_text
				_on_field_changed(comp_id, template_id, entry_id)
		_:
			return func(new_text: String):
				if new_text == "":
					entry.erase(key)
				else:
					entry[key] = new_text
				_on_field_changed(comp_id, template_id, entry_id)


## Get hint strings for entry reference fields from the API.
func _get_ref_hints(type_ids: Array) -> Array[String]:
	if _storage._api == null:
		return []
	return _storage._api.get_entry_ref_hints(type_ids)
