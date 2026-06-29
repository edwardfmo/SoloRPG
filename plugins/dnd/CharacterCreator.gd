extends PluginOverlay

var _dnd_system_script: GDScript

signal character_created(data: Dictionary)

var api: ModAPI
var _character: Dictionary = {}

@export var _tab_container: TabContainer
@export var _class_dropdown: OptionButton
@export var _class_features_container: VBoxContainer
@export var _next_btn_0: Button
@export var _background_dropdown: OptionButton
@export var _background_features_container: VBoxContainer
@export var _species_dropdown: OptionButton
@export var _species_features_container: VBoxContainer
@export var _next_btn_1: Button
@export var _str_display: AbilityScoreDisplay
@export var _dex_display: AbilityScoreDisplay
@export var _con_display: AbilityScoreDisplay
@export var _int_display: AbilityScoreDisplay
@export var _wis_display: AbilityScoreDisplay
@export var _cha_display: AbilityScoreDisplay
@export var _points_label: Label
@export var _next_btn_2: Button
@export var _name_edit: LineEdit
@export var _alignment_dropdown: OptionButton
@export var _finish_btn: Button

var _background_entries: Array[Dictionary] = []
var _species_entries: Array[Dictionary] = []
var _class_entries: Array[Dictionary] = []
var _context_path: String = ""

# Feature selection state: source_type -> Array of {entries: Array, number_to_choose: int}
var _feature_groups: Dictionary = {}  # "class" -> [...], "species" -> [...]


func _ready():
	super._ready()
	_dnd_system_script = load(get_script().resource_path.get_base_dir().path_join("DNDSystem.gd"))
	_next_btn_0.pressed.connect(_on_next_0)
	_next_btn_1.pressed.connect(_on_next_1)
	_next_btn_2.pressed.connect(_on_next_2)
	_finish_btn.pressed.connect(_on_finish)
	_set_tabs_enabled(0)
	# Connect identity fields to update character dict
	_name_edit.text_changed.connect(func(t): _character["name"] = t)
	_alignment_dropdown.item_selected.connect(func(idx): _character["alignment"] = _alignment_dropdown.get_item_text(idx))
	# Connect ability score changes to update character dict and points display
	_str_display.value_changed.connect(func(_c, v): _character["ability_scores"]["str"] = int(v); _update_points())
	_dex_display.value_changed.connect(func(_c, v): _character["ability_scores"]["dex"] = int(v); _update_points())
	_con_display.value_changed.connect(func(_c, v): _character["ability_scores"]["con"] = int(v); _update_points())
	_int_display.value_changed.connect(func(_c, v): _character["ability_scores"]["int"] = int(v); _update_points())
	_wis_display.value_changed.connect(func(_c, v): _character["ability_scores"]["wis"] = int(v); _update_points())
	_cha_display.value_changed.connect(func(_c, v): _character["ability_scores"]["cha"] = int(v); _update_points())
	# Connect dropdown selections to update character dict
	_background_dropdown.item_selected.connect(_on_background_selected)
	_species_dropdown.item_selected.connect(_on_species_selected)
	_class_dropdown.item_selected.connect(_on_class_selected)


func _on_open(_params: Dictionary):
	_context_path = _params.get("context_path", "character")
	_set_tabs_enabled(0)
	_tab_container.current_tab = 0
	_apply_char_limits()
	_init_character()
	_populate_alignment_dropdown()
	_name_edit.text = ""
	_reset_spins()
	_populate_dropdowns()
	_update_points()


func _populate_alignment_dropdown():
	_alignment_dropdown.clear()
	for alignment in _dnd_system_script.ALIGNMENTS:
		_alignment_dropdown.add_item(alignment)
	_alignment_dropdown.selected = 0
	_character["alignment"] = _dnd_system_script.ALIGNMENTS[0]


func _init_character():
	var min_val = api.get_module_setting("dnd.min_char") if api else 8
	_character = {
		"name": "",
		"alignment": "",
		"ability_scores": {
			"str": min_val,
			"dex": min_val,
			"con": min_val,
			"int": min_val,
			"wis": min_val,
			"cha": min_val,
		},
		"background": "",
		"species": "",
		"class": "",
		"features": [],
		"max_hp": 0,
		"hp": 0,
		"equipment": {"weapon": {}, "armor": {}},
	}


func _apply_char_limits():
	var min_val = api.get_module_setting("dnd.min_char") if api else 8
	var max_val = api.get_module_setting("dnd.max_char") if api else 15
	for display in [_str_display, _dex_display, _con_display, _int_display, _wis_display, _cha_display]:
		display.min_value = min_val
		display.max_value = max_val


func _get_total_cost() -> int:
	var total := 0
	for display in [_str_display, _dex_display, _con_display, _int_display, _wis_display, _cha_display]:
		total += display.cost
	return total


func _get_allowed_points() -> int:
	if api:
		return api.get_module_setting("dnd.point_buy_sum")
	return 27


func _update_points():
	var spent = _get_total_cost()
	var allowed = _get_allowed_points()
	_points_label.text = str(spent) + " / " + str(allowed)
	if spent == allowed:
		_points_label.modulate = Color(0.3, 1.0, 0.3)
	elif spent > allowed:
		_points_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		_points_label.modulate = Color(1.0, 1.0, 1.0)


func _reset_spins():
	var min_val = api.get_module_setting("dnd.min_char") if api else 8
	_str_display.ability_score = "Strength"
	_str_display.value = min_val
	_dex_display.ability_score = "Dexterity"
	_dex_display.value = min_val
	_con_display.ability_score = "Constitution"
	_con_display.value = min_val
	_int_display.ability_score = "Intelligence"
	_int_display.value = min_val
	_wis_display.ability_score = "Wisdom"
	_wis_display.value = min_val
	_cha_display.ability_score = "Charisma"
	_cha_display.value = min_val


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

	# Initialize character dict with first selections
	if _background_entries.size() > 0:
		_on_background_selected(0)
	if _species_entries.size() > 0:
		_on_species_selected(0)
	if _class_entries.size() > 0:
		_on_class_selected(0)


func _on_background_selected(idx: int):
	_character["background"] = _get_entry_ref("background", _background_entries, idx)
	if idx >= 0 and idx < _background_entries.size():
		_populate_features_container(_background_features_container, _background_entries[idx], "background")
	else:
		_clear_features_container(_background_features_container, "background")


func _on_species_selected(idx: int):
	_character["species"] = _get_entry_ref("species", _species_entries, idx)
	if idx >= 0 and idx < _species_entries.size():
		_populate_features_container(_species_features_container, _species_entries[idx], "species")
	else:
		_clear_features_container(_species_features_container, "species")


func _on_class_selected(idx: int):
	_character["class"] = _get_entry_ref("class", _class_entries, idx)
	if idx >= 0 and idx < _class_entries.size():
		_populate_features_container(_class_features_container, _class_entries[idx], "class")
	else:
		_clear_features_container(_class_features_container, "class")


func _populate_features_container(container: VBoxContainer, entry: Dictionary, source_type: String):
	_revoke_features(source_type)
	for child in container.get_children():
		child.queue_free()
	var feature_groups = entry.get("features", [])
	_feature_groups[source_type] = []
	var feature_group_scene = load(get_script().resource_path.get_base_dir().path_join("FeatureGroupDisplay.tscn"))
	for group in feature_groups:
		var level_req: int = group.get("level", 0)
		if level_req > 1:
			continue
		var entries_list: Array = _resolve_feature_entries(group)
		if entries_list.is_empty():
			continue
		var num_to_choose: int = group.get("number_to_choose", entries_list.size())
		var feature_name: String = group.get("feature_name", "")
		if feature_name == "":
			feature_name = "Feature" if entries_list.size() == 1 else "Features"
		if level_req > 0:
			feature_name = "Level " + str(level_req) + " - " + feature_name
		var names := []
		for ref in entries_list:
			names.append(_resolve_feature_name(ref))
		var display: FeatureGroupDisplay = feature_group_scene.instantiate()
		container.add_child(display)
		display.setup(feature_name, entries_list, names, num_to_choose)
		display.selection_changed.connect(func(): _sync_all_features(source_type))
		_feature_groups[source_type].append(display)
	_sync_all_features(source_type)
	container.visible = container.get_child_count() > 0


func _sync_all_features(source_type: String):
	_revoke_features(source_type)
	var displays: Array = _feature_groups.get(source_type, [])
	var source_ref = _character.get(source_type, "")
	for display in displays:
		for ref in display.get_selected_refs():
			_character["features"].append({
				"ref": ref,
				"granted_by": source_ref,
				"source_type": source_type,
				"level": 0,
			})


func _clear_features_container(container: VBoxContainer, source_type: String):
	_revoke_features(source_type)
	for child in container.get_children():
		child.queue_free()
	container.visible = false
	_feature_groups.erase(source_type)


func _resolve_feature_entries(group: Dictionary) -> Array:
	var result := []
	# Add explicit entries
	if group.has("entries"):
		result.append_array(group["entries"])
	# Add entries matching types filter
	var types: Array = group.get("types", [])
	if not types.is_empty() and api:
		var all_features = api._entries.get("character_feature", {})
		for key in all_features:
			var feat = all_features[key]
			var feat_type = feat.get("feature_type", "")
			if feat_type in types:
				var ref = "@character_feature/" + key
				if ref not in result:
					result.append(ref)
	return result


func _revoke_features(source_type: String):
	var features: Array = _character["features"]
	var i := features.size() - 1
	while i >= 0:
		if features[i].get("source_type", "") == source_type:
			features.remove_at(i)
		i -= 1


func _resolve_feature_name(ref: String) -> String:
	if not api or not ref.begins_with("@"):
		return ref
	# ref format: @character_feature/namespace.id
	var parts = ref.substr(1).split("/", true, 1)
	if parts.size() < 2:
		return ref
	var template_id = parts[0]
	var entry_key = parts[1]
	var entries = api._entries.get(template_id, {})
	if entries.has(entry_key):
		return entries[entry_key].get("name", ref)
	return ref


func _set_tabs_enabled(up_to: int):
	for i in _tab_container.get_tab_count():
		_tab_container.set_tab_disabled(i, i > up_to)


func _on_next_0():
	_set_tabs_enabled(1)
	_tab_container.current_tab = 1


func _on_next_1():
	_set_tabs_enabled(2)
	_tab_container.current_tab = 2


func _on_next_2():
	_set_tabs_enabled(3)
	_tab_container.current_tab = 3


func _on_finish():
	# Calculate HP: hit die max + CON modifier
	var con_mod = _dnd_system_script.get_char_mod(_character, "con")
	var hit_die_value = _get_hit_die_value()
	var max_hp = hit_die_value + con_mod
	_character["max_hp"] = max_hp
	_character["hp"] = max_hp

	if _context_path != "" and api:
		api.set_value(_context_path, _character)
		api.notify_context_changed()
	character_created.emit(_character)
	close()


func _get_hit_die_value() -> int:
	var idx = _class_dropdown.selected
	if idx < 0 or idx >= _class_entries.size():
		return 6
	var hit_die: String = _class_entries[idx].get("hit_die", "d6")
	return hit_die.substr(1).to_int() if hit_die.begins_with("d") else 6


func _get_entry_ref(template_id: String, entries: Array[Dictionary], idx: int) -> String:
	if idx < 0 or idx >= entries.size():
		return ""
	var entry = entries[idx]
	var entry_id = entry.get("id", "")
	var api_entries = api._entries.get(template_id, {})
	for namespaced_id in api_entries:
		if api_entries[namespaced_id].get("id", "") == entry_id:
			return "@" + template_id + "/" + namespaced_id
	return "@" + template_id + "/" + entry_id
