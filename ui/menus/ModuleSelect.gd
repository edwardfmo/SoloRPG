extends Control

signal module_selected(path: String)
signal back_pressed

@export var module_list: VBoxContainer
@export var back_button: Button
@export var confirm_dialog: ConfirmationDialog

var ModuleEntryScene = preload("res://ui/menus/ModuleEntry.tscn")
var api: ModAPI = null
var _pending_path: String = ""

func _ready():
	back_button.pressed.connect(func(): back_pressed.emit())
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		_refresh_list()


func _refresh_list():
	for child in module_list.get_children():
		child.queue_free()

	var search_dirs = [SystemUtils.MODULES_DIR, SystemUtils.BUNDLED_MODULES_DIR]
	var seen_ids: Array[String] = []
	# First pass: collect directories and standalone jsons (they take priority over .rpgmod)
	var pending_rpgmods: Array[Dictionary] = []

	for dir_path in search_dirs:
		var dir = DirAccess.open(dir_path)
		if dir == null:
			continue

		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = dir_path + "/" + file_name
			if dir.current_is_dir():
				# Check if directory contains module.json
				var module_json_path = full_path + "/module.json"
				if FileAccess.file_exists(module_json_path):
					var json_text = FileAccess.get_file_as_string(module_json_path)
					var data = JSON.parse_string(json_text)
					if data != null:
						var mid = data.get("id", file_name)
						if mid not in seen_ids:
							seen_ids.append(mid)
							data["_dir_path"] = full_path
							_add_module_entry(data, full_path)
			elif file_name.ends_with(".json"):
				var json_text = FileAccess.get_file_as_string(full_path)
				var data = JSON.parse_string(json_text)
				if data != null:
					var mid = data.get("id", file_name)
					if mid not in seen_ids:
						seen_ids.append(mid)
						_add_module_entry(data, full_path)
			elif file_name.ends_with(".rpgmod"):
				pending_rpgmods.append({"file_name": file_name, "full_path": full_path})
			file_name = dir.get_next()
		dir.list_dir_end()

	# Second pass: add .rpgmod files only if their module id isn't already listed
	for rpgmod in pending_rpgmods:
		var mid = rpgmod["file_name"].get_basename()
		if mid not in seen_ids:
			seen_ids.append(mid)
			# Read metadata from the archive
			var zip = ZIPReader.new()
			if zip.open(rpgmod["full_path"]) == OK:
				var json_data = zip.read_file("module.json")
				zip.close()
				if not json_data.is_empty():
					var data = JSON.parse_string(json_data.get_string_from_utf8())
					if data != null:
						mid = data.get("id", mid)
						if mid not in seen_ids:
							seen_ids.append(mid)
						_add_module_entry(data, rpgmod["full_path"])
						continue
			# Fallback if we can't read metadata
			_add_module_entry({"id": mid, "name": mid}, rpgmod["full_path"])


func _add_module_entry(data: Dictionary, path: String):
	var entry = ModuleEntryScene.instantiate()
	module_list.add_child(entry)
	entry.setup(data, path, api)
	entry.play_pressed.connect(_on_play_pressed.bind(entry))


func _on_play_pressed(path: String, entry: ModuleEntry):
	if entry.has_dep_issues:
		_show_dep_confirm(path, entry)
	else:
		module_selected.emit(path)


func _show_dep_confirm(path: String, entry: ModuleEntry):
	_pending_path = path
	confirm_dialog.dialog_text = "This module has plugin issues:\n\n" + entry.dep_issues_label.get_parsed_text() + "\n\nProceed anyway?"
	if not confirm_dialog.confirmed.is_connected(_on_confirm_play):
		confirm_dialog.confirmed.connect(_on_confirm_play)
	if not confirm_dialog.canceled.is_connected(_on_cancel_play):
		confirm_dialog.canceled.connect(_on_cancel_play)
	confirm_dialog.popup_centered()


func _on_confirm_play():
	var path = _pending_path
	confirm_dialog.hide()
	module_selected.emit(path)


func _on_cancel_play():
	confirm_dialog.hide()
