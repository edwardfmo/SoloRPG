class_name EntryDetailPanel
extends RefCounted

var _entry_fields: VBoxContainer
var _header_label: Label
var _storage: CompendiumStorage

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
	_render_fields(entry, comp_id, template_id, entry_id, writable)


func clear():
	_clear()
	_header_label.text = "Select an entry"


func _clear():
	for child in _entry_fields.get_children():
		child.queue_free()


func _render_fields(entry: Dictionary, comp_id: String, template_id: String, entry_id: String, editable: bool):
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
					_on_field_changed(comp_id, template_id, entry_id))
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
					_on_field_changed(comp_id, template_id, entry_id))
			row.add_child(val_field)

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
			_on_field_changed(comp_id, template_id, entry_id)
			refresh_requested.emit())
		add_field_row.add_child(add_field_btn)
		_entry_fields.add_child(add_field_row)


func _on_field_changed(comp_id: String, template_id: String, entry_id: String):
	_storage.mark_entry_dirty(comp_id, template_id, entry_id)
	entry_field_changed.emit(comp_id, template_id, entry_id)
