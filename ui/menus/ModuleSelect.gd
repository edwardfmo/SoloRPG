extends Control

signal module_selected(path: String)
signal back_pressed

@export var module_list: VBoxContainer
@export var back_button: Button

var ModuleEntryScene = preload("res://ui/menus/ModuleEntry.tscn")
var api: ModAPI = null
var _confirm_dialog: ConfirmationDialog = null
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
	var seen_files: Array[String] = []

	for dir_path in search_dirs:
		var dir = DirAccess.open(dir_path)
		if dir == null:
			continue

		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and file_name not in seen_files:
				seen_files.append(file_name)
				var path = dir_path + "/" + file_name
				var json_text = FileAccess.get_file_as_string(path)
				var data = JSON.parse_string(json_text)
				if data != null:
					_add_module_entry(data, path)
			file_name = dir.get_next()
		dir.list_dir_end()


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
	if _confirm_dialog:
		_confirm_dialog.queue_free()

	_pending_path = path
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Plugin Issues"
	_confirm_dialog.dialog_text = "This module has plugin issues:\n\n" + entry.dep_issues_label.get_parsed_text() + "\n\nProceed anyway?"
	_confirm_dialog.ok_button_text = "Play Anyway"
	_confirm_dialog.cancel_button_text = "Cancel"
	add_child(_confirm_dialog)

	_confirm_dialog.confirmed.connect(_on_confirm_play)
	_confirm_dialog.canceled.connect(_on_cancel_play)
	_confirm_dialog.popup_centered()


func _on_confirm_play():
	var path = _pending_path
	if _confirm_dialog:
		_confirm_dialog.queue_free()
		_confirm_dialog = null
	module_selected.emit(path)


func _on_cancel_play():
	if _confirm_dialog:
		_confirm_dialog.queue_free()
		_confirm_dialog = null
