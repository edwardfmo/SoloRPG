class_name EntryDetailPanel
extends RefCounted

var _entry_fields: VBoxContainer
var _header_label: Label
var _storage: CompendiumStorage

var _field_row_scene = preload("res://ui/editor/EntryFieldRow.tscn")
var _add_field_row_scene = preload("res://ui/editor/AddFieldRow.tscn")

signal entry_field_changed(comp_id: String, template_id: String, entry_id: String)
signal entry_id_changed(comp_id: String, template_id: String, old_id: String, new_id: String)
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


func show_file_info(comp_id: String, file_name: String):
	_clear()
	_header_label.text = "%s / %s" % [comp_id, file_name]


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
	var source_file = _storage.get_entry_source_file(comp_id, template_id, entry_id)
	if source_file != "compendium.json":
		_header_label.text += "  (%s)" % source_file
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
		var is_enum = schema.has("enum")
		var is_bool = schema.get("type", "") == "bool"
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

		elif is_enum:
			# Enum field — use OptionButton
			var enum_options: Array = schema["enum"]
			var option_btn = OptionButton.new()
			option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for opt in enum_options:
				option_btn.add_item(str(opt))
			# Select current value
			var current_str = str(val) if has_value else ""
			for i in enum_options.size():
				if str(enum_options[i]) == current_str:
					option_btn.selected = i
					break
			option_btn.disabled = not editable
			if editable:
				option_btn.item_selected.connect(func(idx):
					entry[key] = str(enum_options[idx])
					_on_field_changed(comp_id, template_id, entry_id))
			val_field.replace_by(option_btn)
			val_field.queue_free()
			_entry_fields.add_child(row)

		elif is_bool:
			# Bool field — use CheckBox
			var check = CheckBox.new()
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check.button_pressed = val == true
			check.disabled = not editable
			if editable:
				check.toggled.connect(func(pressed):
					entry[key] = pressed
					_on_field_changed(comp_id, template_id, entry_id))
			val_field.replace_by(check)
			val_field.queue_free()
			_entry_fields.add_child(row)

		elif is_ref_array or val is Array:
			# Array field — check for item_schema (array of objects)
			row.queue_free()
			var arr_val: Array = val if val is Array else []
			var item_schema_def = schema.get("item_schema", [])
			if item_schema_def.size() > 0:
				var header_fmt = schema.get("header_format", "")
				_render_object_array_field(key, arr_val, entry, comp_id, template_id, entry_id, editable, item_schema_def, is_mandatory, header_fmt)
			else:
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
	var hints: Array[String] = []
	if is_ref:
		hints = _get_ref_hints(ref_types)

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


## Render an array-of-objects field using item_schema for each object's sub-fields.
func _render_object_array_field(key: String, arr: Array, entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool, item_schema: Array, is_mandatory: bool, header_format: String = ""):
	# Header
	var header_row = HBoxContainer.new()
	var header_label = Label.new()
	header_label.custom_minimum_size = Vector2(100, 0)
	header_label.text = key + " *" if is_mandatory else key
	header_row.add_child(header_label)
	_entry_fields.add_child(header_row)

	var items_container = VBoxContainer.new()
	_entry_fields.add_child(items_container)

	var _rebuild := [Callable()]
	_rebuild[0] = func():
		for child in items_container.get_children():
			child.queue_free()

		for i in arr.size():
			var item = arr[i]
			if not item is Dictionary:
				continue
			# Collapsible panel for each object
			var panel = _create_object_item_panel(i, item, arr, key, entry, comp_id, template_id, entry_id, editable, item_schema, _rebuild, header_format)
			items_container.add_child(panel)

		# Add button
		if editable:
			var add_btn = Button.new()
			add_btn.text = "+ Add"
			add_btn.pressed.connect(func():
				var new_item := {}
				for field_def in item_schema:
					if field_def.get("mandatory", false):
						var fname = field_def["name"]
						var ftype = field_def.get("type", "string")
						new_item[fname] = _default_for_type(field_def)
				arr.append(new_item)
				entry[key] = arr
				_on_field_changed(comp_id, template_id, entry_id)
				_rebuild[0].call()
				# Auto-expand the last panel (newly added)
				var children = items_container.get_children()
				# The last child before the add button is the new panel
				if children.size() >= 2:
					var new_panel = children[children.size() - 2]
					var toggle = new_panel.get_child(0).get_child(0) as Button
					if toggle and toggle.text == "▶":
						toggle.emit_signal("pressed"))
			items_container.add_child(add_btn)

	_rebuild[0].call()


## Create a collapsible panel for one object inside an array-of-objects field.
func _create_object_item_panel(index: int, item: Dictionary, arr: Array, key: String, entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool, item_schema: Array, _rebuild: Array, header_format: String = "") -> VBoxContainer:
	var panel = VBoxContainer.new()

	# Header row: summary + collapse toggle + remove button
	var header_hbox = HBoxContainer.new()
	var summary_label = _get_object_summary(index, item, item_schema, header_format, template_id, key)
	var toggle_btn = Button.new()
	toggle_btn.text = "▶"
	toggle_btn.custom_minimum_size = Vector2(24, 0)
	header_hbox.add_child(toggle_btn)
	header_hbox.add_child(summary_label)

	if editable:
		var remove_btn = Button.new()
		remove_btn.text = "X"
		remove_btn.custom_minimum_size = Vector2(24, 0)
		remove_btn.pressed.connect(func():
			arr.remove_at(index)
			entry[key] = arr
			_on_field_changed(comp_id, template_id, entry_id)
			_rebuild[0].call())
		header_hbox.add_child(remove_btn)

	panel.add_child(header_hbox)

	# Detail container (sub-fields)
	var detail_container = VBoxContainer.new()
	detail_container.visible = false

	# Indent wrapper
	var indent = MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 20)
	indent.add_child(detail_container)
	panel.add_child(indent)

	# Toggle visibility
	toggle_btn.pressed.connect(func():
		detail_container.visible = not detail_container.visible
		toggle_btn.text = "▶" if not detail_container.visible else "▼")

	# Try plugin-provided custom panel first
	var custom_panel: Control = null
	if _storage._api != null:
		var ctx := {
			"entry": entry,
			"comp_id": comp_id,
			"entry_id": entry_id,
			"editable": editable,
			"on_changed": func():
				entry[key] = arr
				_on_field_changed(comp_id, template_id, entry_id)
				_rebuild[0].call(),
			"get_ref_hints": func(type_ids: Array) -> Array[String]:
				return _get_ref_hints(type_ids),
			"resolve_ref_display": func(ref: String) -> String:
				return _storage._api.resolve_ref_display(ref),
		}
		custom_panel = _storage._api.create_item_panel(template_id, key, item, ctx)

	if custom_panel != null:
		detail_container.add_child(custom_panel)
	else:
		# Generic sub-field rendering
		_render_generic_item_fields(item, item_schema, arr, key, entry, comp_id, template_id, entry_id, editable, detail_container)

	return panel


## Render generic sub-fields for an item_schema object.
func _render_generic_item_fields(item: Dictionary, item_schema: Array, arr: Array, key: String, entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool, detail_container: VBoxContainer):
	for field_def in item_schema:
		var fname = field_def["name"]
		var ftype = field_def.get("type", "string")
		var fmandatory = field_def.get("mandatory", false)
		var fenum = field_def.get("enum", [])
		var fref_types = field_def.get("entry_ref_types", [])

		var fval = item.get(fname, _default_for_type(field_def))

		var field_row = HBoxContainer.new()
		var label = Label.new()
		label.custom_minimum_size = Vector2(100, 0)
		label.text = fname + " *" if fmandatory else fname
		field_row.add_child(label)

		if fref_types.size() > 0 and ftype == "array":
			# Array of refs — render sub-array inline
			field_row.queue_free()
			var sub_arr: Array = fval if fval is Array else []
			_render_sub_ref_array(fname, sub_arr, item, key, entry, comp_id, template_id, entry_id, editable, fref_types, detail_container)
		elif fenum.size() > 0:
			var option_btn = OptionButton.new()
			option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for opt in fenum:
				option_btn.add_item(str(opt))
			var current_str = str(fval)
			for j in fenum.size():
				if str(fenum[j]) == current_str:
					option_btn.selected = j
					break
			option_btn.disabled = not editable
			if editable:
				var fn = fname
				option_btn.item_selected.connect(func(idx):
					item[fn] = str(fenum[idx])
					entry[key] = arr
					_on_field_changed(comp_id, template_id, entry_id))
			field_row.add_child(option_btn)
			detail_container.add_child(field_row)
		elif ftype == "bool":
			var check = CheckBox.new()
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check.button_pressed = fval == true
			check.disabled = not editable
			if editable:
				var fn = fname
				check.toggled.connect(func(pressed):
					item[fn] = pressed
					entry[key] = arr
					_on_field_changed(comp_id, template_id, entry_id))
			field_row.add_child(check)
			detail_container.add_child(field_row)
		elif ftype == "array":
			# Plain array sub-field
			field_row.queue_free()
			var sub_arr: Array = fval if fval is Array else []
			_render_sub_plain_array(fname, sub_arr, item, key, entry, comp_id, template_id, entry_id, editable, detail_container)
		else:
			# String, int, float
			var field = LineEdit.new()
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			field.text = str(fval) if item.has(fname) else ""
			field.editable = editable
			field.placeholder_text = "(required)" if fmandatory else "(optional)"
			if editable:
				var fn = fname
				var ft = ftype
				field.text_submitted.connect(func(new_text: String):
					_set_sub_field(item, fn, ft, new_text)
					entry[key] = arr
					_on_field_changed(comp_id, template_id, entry_id))
				field.focus_exited.connect(func():
					_set_sub_field(item, fn, ft, field.text)
					entry[key] = arr
					_on_field_changed(comp_id, template_id, entry_id))
			field_row.add_child(field)
			detail_container.add_child(field_row)


## Render a sub-array of entry refs inside an object item.
func _render_sub_ref_array(fname: String, sub_arr: Array, item: Dictionary, parent_key: String, entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool, ref_types: Array, container: VBoxContainer):
	var hints := _get_ref_hints(ref_types)

	var sub_header = HBoxContainer.new()
	var sub_label = Label.new()
	sub_label.custom_minimum_size = Vector2(100, 0)
	sub_label.text = fname
	sub_header.add_child(sub_label)
	container.add_child(sub_header)

	var sub_container = VBoxContainer.new()
	container.add_child(sub_container)

	var _sub_rebuild := [Callable()]
	_sub_rebuild[0] = func():
		for child in sub_container.get_children():
			child.queue_free()

		for i in sub_arr.size():
			var row = HBoxContainer.new()
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(100, 0)
			row.add_child(spacer)

			var hinted = HintedLineEdit.new()
			hinted.hints = hints
			hinted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hinted.text = str(sub_arr[i])
			hinted.editable = editable

			if editable:
				var idx = i
				hinted.text_submitted.connect(func(new_text: String):
					if new_text.strip_edges() == "":
						sub_arr.remove_at(idx)
					else:
						sub_arr[idx] = new_text
					item[fname] = sub_arr
					_on_field_changed(comp_id, template_id, entry_id)
					_sub_rebuild[0].call())
				hinted.hint_selected.connect(func(value: String):
					sub_arr[idx] = value
					item[fname] = sub_arr
					_on_field_changed(comp_id, template_id, entry_id)
					_sub_rebuild[0].call())

			row.add_child(hinted)

			if editable:
				var rm_btn = Button.new()
				rm_btn.text = "X"
				rm_btn.custom_minimum_size = Vector2(24, 0)
				var idx = i
				rm_btn.pressed.connect(func():
					sub_arr.remove_at(idx)
					item[fname] = sub_arr
					_on_field_changed(comp_id, template_id, entry_id)
					_sub_rebuild[0].call())
				row.add_child(rm_btn)

			sub_container.add_child(row)

		if editable:
			var add_row = HBoxContainer.new()
			var add_spacer = Control.new()
			add_spacer.custom_minimum_size = Vector2(100, 0)
			add_row.add_child(add_spacer)

			var add_hinted = HintedLineEdit.new()
			add_hinted.hints = hints
			add_hinted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_hinted.placeholder_text = "Add ref..."
			add_hinted.hint_selected.connect(func(value: String):
				sub_arr.append(value)
				item[fname] = sub_arr
				_on_field_changed(comp_id, template_id, entry_id)
				_sub_rebuild[0].call())
			add_hinted.text_submitted.connect(func(new_text: String):
				var val = new_text.strip_edges()
				if val == "":
					return
				sub_arr.append(val)
				item[fname] = sub_arr
				_on_field_changed(comp_id, template_id, entry_id)
				_sub_rebuild[0].call())
			add_row.add_child(add_hinted)
			sub_container.add_child(add_row)

	_sub_rebuild[0].call()


## Render a plain sub-array inside an object item.
func _render_sub_plain_array(fname: String, sub_arr: Array, item: Dictionary, parent_key: String, entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool, container: VBoxContainer):
	var sub_header = HBoxContainer.new()
	var sub_label = Label.new()
	sub_label.custom_minimum_size = Vector2(100, 0)
	sub_label.text = fname
	sub_header.add_child(sub_label)
	container.add_child(sub_header)

	var sub_container = VBoxContainer.new()
	container.add_child(sub_container)

	var _sub_rebuild := [Callable()]
	_sub_rebuild[0] = func():
		for child in sub_container.get_children():
			child.queue_free()

		for i in sub_arr.size():
			var row = HBoxContainer.new()
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(100, 0)
			row.add_child(spacer)

			var field = LineEdit.new()
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			field.text = str(sub_arr[i])
			field.editable = editable

			if editable:
				var idx = i
				field.text_submitted.connect(func(new_text: String):
					if new_text.strip_edges() == "":
						sub_arr.remove_at(idx)
					else:
						sub_arr[idx] = new_text
					item[fname] = sub_arr
					_on_field_changed(comp_id, template_id, entry_id)
					_sub_rebuild[0].call())

			row.add_child(field)

			if editable:
				var rm_btn = Button.new()
				rm_btn.text = "X"
				rm_btn.custom_minimum_size = Vector2(24, 0)
				var idx = i
				rm_btn.pressed.connect(func():
					sub_arr.remove_at(idx)
					item[fname] = sub_arr
					_on_field_changed(comp_id, template_id, entry_id)
					_sub_rebuild[0].call())
				row.add_child(rm_btn)

			sub_container.add_child(row)

		if editable:
			var add_row = HBoxContainer.new()
			var add_spacer = Control.new()
			add_spacer.custom_minimum_size = Vector2(100, 0)
			add_row.add_child(add_spacer)
			var add_field = LineEdit.new()
			add_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_field.placeholder_text = "Add..."
			add_field.text_submitted.connect(func(new_text: String):
				var val = new_text.strip_edges()
				if val == "":
					return
				sub_arr.append(val)
				item[fname] = sub_arr
				_on_field_changed(comp_id, template_id, entry_id)
				_sub_rebuild[0].call())
			add_row.add_child(add_field)
			sub_container.add_child(add_row)

	_sub_rebuild[0].call()


## Set a sub-field value with type coercion.
func _set_sub_field(item: Dictionary, fname: String, ftype: String, text: String):
	var val = text.strip_edges()
	if val == "":
		item.erase(fname)
		return
	match ftype:
		"int":
			if val.is_valid_int():
				item[fname] = val.to_int()
			else:
				item[fname] = val
		"float":
			if val.is_valid_float():
				item[fname] = val.to_float()
			else:
				item[fname] = val
		_:
			item[fname] = val


## Get a summary label for an object in an array-of-objects field.
func _get_object_summary(index: int, item: Dictionary, item_schema: Array, header_format: String = "", template_id: String = "", field_name: String = "") -> Label:
	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var summary: String = ""
	# Try plugin-provided summary first
	if template_id != "" and field_name != "" and _storage._api != null:
		summary = _storage._api.get_item_summary(template_id, field_name, item)
	if summary == "" and header_format != "":
		summary = _interpolate_header(header_format, item)
	if summary == "":
		# Fallback: show index and first non-empty string field
		summary = "[%d]" % index
		for field_def in item_schema:
			var fname = field_def["name"]
			if item.has(fname) and item[fname] is String and item[fname] != "":
				summary = item[fname]
				break
	label.text = summary
	return label


## Interpolate a header format string, replacing @field with values from the item.
## Supports @field(fallback) syntax — uses fallback when value is missing, empty, or 0.
func _interpolate_header(format: String, item: Dictionary) -> String:
	var result := ""
	var i := 0
	while i < format.length():
		if format[i] == "@":
			i += 1
			# Read field name (alphanumeric + underscore)
			var fname := ""
			while i < format.length() and (format[i] == "_" or format[i].is_valid_identifier()):
				fname += format[i]
				i += 1
			# Read optional fallback in parens
			var fallback := ""
			var has_fallback := false
			if i < format.length() and format[i] == "(":
				has_fallback = true
				i += 1
				while i < format.length() and format[i] != ")":
					fallback += format[i]
					i += 1
				if i < format.length():
					i += 1  # skip ')'
			# Resolve value
			var val = item.get(fname, null)
			var val_str := ""
			var is_empty = val == null or (val is String and val == "") or (val is int and val == 0) or (val is float and val == 0.0) or (val is Array and val.is_empty())
			if is_empty:
				val_str = fallback if has_fallback else ""
			else:
				val_str = str(val)
			result += val_str
		else:
			result += format[i]
			i += 1
	return result.strip_edges()


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
		"bool":
			return false
		"array":
			return []
		_:
			return ""


## Create a callable that writes edited values into the entry dict.
## For optional fields not yet in the entry, the value is only written on first edit.
func _make_field_setter(entry: Dictionary, key: String, comp_id: String, template_id: String, entry_id: String, type: String) -> Callable:
	if key == "id":
		return func(new_text: String):
			var old_id = entry.get("id", entry_id)
			var new_id = new_text.strip_edges()
			if new_id == "" or new_id == old_id:
				return
			entry["id"] = new_id
			_storage.rename_entry_id(comp_id, template_id, old_id, new_id)
			entry_id_changed.emit(comp_id, template_id, old_id, new_id)
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
