extends Control

signal back_pressed
signal plugins_changed

@export var _tab_container: TabContainer
@export var _system_settings_container: VBoxContainer
@export var _plugin_list: VBoxContainer
@export var _back_button: Button

var PluginEntryScene = preload("res://ui/menus/PluginEntry.tscn")
var _section_label_scene = preload("res://ui/shared/SectionLabel.tscn")
var config := PluginConfig.new()
var _api: ModAPI


func set_api(api: ModAPI):
	_api = api


func _ready():
	_back_button.pressed.connect(func(): back_pressed.emit())
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		_refresh_system_settings()
		_refresh_plugin_list()


# ─── System Settings Tab ─────────────────────────────────────────────────────


func _refresh_system_settings():
	for child in _system_settings_container.get_children():
		child.queue_free()

	if _api == null:
		return

	var settings = _api.get_system_settings()
	if settings.is_empty():
		var label = Label.new()
		label.text = "No system settings available."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(0.6, 0.6, 0.6)
		_system_settings_container.add_child(label)
		return

	for def in settings:
		_add_setting_row(_system_settings_container, def)


# ─── Plugins Tab ─────────────────────────────────────────────────────────────


func _refresh_plugin_list():
	for child in _plugin_list.get_children():
		child.queue_free()

	var loader = PluginLoader.new()
	var plugins = loader.scan_metadata()

	var optional_plugins := []
	var module_required_plugins := []
	var core_plugins := []

	for data in plugins:
		var ptype = SystemUtils.get_plugin_type(data)
		if ptype == "optional":
			optional_plugins.append(data)
		elif ptype == "module_required":
			module_required_plugins.append(data)
		else:
			core_plugins.append(data)

	_add_section_label("Optional")
	if optional_plugins.is_empty():
		_add_empty_label()
	else:
		for data in optional_plugins:
			_add_plugin_entry(data, true)

	_add_section_label("Module Required")
	if module_required_plugins.is_empty():
		_add_empty_label()
	else:
		for data in module_required_plugins:
			_add_plugin_entry(data, false)

	_add_section_label("Core")
	if core_plugins.is_empty():
		_add_empty_label()
	else:
		for data in core_plugins:
			_add_plugin_entry(data, false)


func _add_section_label(text: String):
	var label = _section_label_scene.instantiate()
	label.text = text
	_plugin_list.add_child(label)


func _add_empty_label():
	var label = _section_label_scene.instantiate()
	label.text = "None installed"
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.5, 0.5, 0.5)
	_plugin_list.add_child(label)


func _add_plugin_entry(data: Dictionary, show_toggle: bool):
	var entry = PluginEntryScene.instantiate()
	_plugin_list.add_child(entry)
	var plugin_id = data.get("id", "")
	entry.setup(data, config.is_enabled(plugin_id), show_toggle)
	if show_toggle:
		entry.toggled.connect(_on_plugin_toggled)

	# Add plugin-specific settings below the entry
	if _api:
		var plugin_settings = _api.get_plugin_settings(plugin_id)
		if not plugin_settings.is_empty():
			var settings_box = VBoxContainer.new()
			settings_box.add_theme_constant_override("margin_left", 20)
			for def in plugin_settings:
				_add_setting_row(settings_box, def)
			_plugin_list.add_child(settings_box)


func _on_plugin_toggled(plugin_id: String, enabled: bool):
	config.set_enabled(plugin_id, enabled)
	plugins_changed.emit()


# ─── Setting Row Builder ─────────────────────────────────────────────────────


func _add_setting_row(container: Control, def: Dictionary):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label = Label.new()
	label.text = def.get("label", def.get("path", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var path = def.get("path", "")
	var current_value = _api.get_setting(path)
	var type = def.get("type", "string")

	match type:
		"bool":
			var checkbox = CheckBox.new()
			checkbox.button_pressed = bool(current_value) if current_value != null else false
			checkbox.toggled.connect(func(pressed): _api.set_setting(path, pressed))
			row.add_child(checkbox)
		"int":
			var spin = SpinBox.new()
			spin.min_value = def.get("min", -999999)
			spin.max_value = def.get("max", 999999)
			spin.step = 1
			spin.value = int(current_value) if current_value != null else 0
			spin.custom_minimum_size.x = 100
			spin.value_changed.connect(func(val): _api.set_setting(path, int(val)))
			row.add_child(spin)
		"float":
			var spin = SpinBox.new()
			spin.min_value = def.get("min", -999999.0)
			spin.max_value = def.get("max", 999999.0)
			spin.step = def.get("step", 0.1)
			spin.value = float(current_value) if current_value != null else 0.0
			spin.custom_minimum_size.x = 100
			spin.value_changed.connect(func(val): _api.set_setting(path, val))
			row.add_child(spin)
		"string":
			var line_edit = LineEdit.new()
			line_edit.text = str(current_value) if current_value != null else ""
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_edit.text_submitted.connect(func(txt): _api.set_setting(path, txt))
			row.add_child(line_edit)
		"enum":
			var option_btn = OptionButton.new()
			var options = def.get("options", [])
			for opt in options:
				option_btn.add_item(opt)
			var idx = options.find(current_value) if current_value != null else 0
			if idx >= 0:
				option_btn.selected = idx
			option_btn.item_selected.connect(func(i): _api.set_setting(path, options[i]))
			row.add_child(option_btn)

	container.add_child(row)
