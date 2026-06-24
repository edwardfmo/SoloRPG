extends PluginOverlay

signal character_created(data: Dictionary)

var api: ModAPI

@export var _tab_container: TabContainer
@export var _str_spin: SpinBox
@export var _dex_spin: SpinBox
@export var _con_spin: SpinBox
@export var _int_spin: SpinBox
@export var _wis_spin: SpinBox
@export var _cha_spin: SpinBox
@export var _next_btn_1: Button
@export var _background_dropdown: OptionButton
@export var _next_btn_2: Button
@export var _species_dropdown: OptionButton
@export var _next_btn_3: Button
@export var _class_dropdown: OptionButton
@export var _finish_btn: Button

var _background_entries: Array[Dictionary] = []
var _species_entries: Array[Dictionary] = []
var _class_entries: Array[Dictionary] = []
var _context_path: String = ""


func _ready():
	super._ready()
	_next_btn_1.pressed.connect(_on_next_1)
	_next_btn_2.pressed.connect(_on_next_2)
	_next_btn_3.pressed.connect(_on_next_3)
	_finish_btn.pressed.connect(_on_finish)
	_set_tabs_enabled(0)


func _on_open(_params: Dictionary):
	_context_path = _params.get("context_path", "character")
	_set_tabs_enabled(0)
	_tab_container.current_tab = 0
	_reset_spins()
	_populate_dropdowns()


func _reset_spins():
	_str_spin.value = 10
	_dex_spin.value = 10
	_con_spin.value = 10
	_int_spin.value = 10
	_wis_spin.value = 10
	_cha_spin.value = 10


func _populate_dropdowns():
	_background_dropdown.clear()
	_species_dropdown.clear()
	_class_dropdown.clear()

	_background_entries = api.get_entries("background")
	for i in _background_entries.size():
		_background_dropdown.add_item(_background_entries[i].get("name", ""), i)

	_species_entries = api.get_entries("species")
	for i in _species_entries.size():
		_species_dropdown.add_item(_species_entries[i].get("name", ""), i)

	_class_entries = api.get_entries("class")
	for i in _class_entries.size():
		_class_dropdown.add_item(_class_entries[i].get("name", ""), i)


func _set_tabs_enabled(up_to: int):
	for i in _tab_container.get_tab_count():
		_tab_container.set_tab_disabled(i, i > up_to)


func _on_next_1():
	_set_tabs_enabled(1)
	_tab_container.current_tab = 1


func _on_next_2():
	_set_tabs_enabled(2)
	_tab_container.current_tab = 2


func _on_next_3():
	_set_tabs_enabled(3)
	_tab_container.current_tab = 3


func _on_finish(): 
	var data := {
		"characteristics": {
			"str": int(_str_spin.value),
			"dex": int(_dex_spin.value),
			"con": int(_con_spin.value),
			"int": int(_int_spin.value),
			"wis": int(_wis_spin.value),
			"cha": int(_cha_spin.value),
		},
		"background": _get_entry_ref("background", _background_entries, _background_dropdown.selected),
		"species": _get_entry_ref("species", _species_entries, _species_dropdown.selected),
		"class": _get_entry_ref("class", _class_entries, _class_dropdown.selected),
		"max_hp": 10,
		"hp":10
	}
	if _context_path != "" and api:
		api.set_value(_context_path, data)
		api.notify_context_changed()
	character_created.emit(data)
	close()


func _get_entry_ref(template_id: String, entries: Array[Dictionary], idx: int) -> String:
	if idx < 0 or idx >= entries.size():
		return ""
	var entry = entries[idx]
	var entry_id = entry.get("id", "")
	# Find the namespaced id by checking the API entries
	var api_entries = api._entries.get(template_id, {})
	for namespaced_id in api_entries:
		if api_entries[namespaced_id].get("id", "") == entry_id:
			return "@" + template_id + "/" + namespaced_id
	return "@" + template_id + "/" + entry_id
