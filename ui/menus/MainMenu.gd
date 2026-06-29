extends Control

signal new_game_pressed
signal continue_pressed
signal load_game_pressed
signal content_editor_pressed
signal settings_pressed
signal exit_pressed

@export var new_game_button: Button
@export var continue_button: Button
@export var load_game_button: Button
@export var content_editor_button: Button
@export var settings_button: Button
@export var exit_button: Button

func _ready():
	new_game_button.pressed.connect(func():
		new_game_pressed.emit()
	)

	continue_button.pressed.connect(func():
		continue_pressed.emit()
	)

	load_game_button.pressed.connect(func():
		load_game_pressed.emit()
	)

	content_editor_button.pressed.connect(func():
		content_editor_pressed.emit()
	)

	settings_button.pressed.connect(func():
		settings_pressed.emit()
	)

	exit_button.pressed.connect(func():
		exit_pressed.emit()
	)

	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		var has_saves = DirAccess.dir_exists_absolute(SystemUtils.SAVE_DIR) and not DirAccess.open(SystemUtils.SAVE_DIR).get_files().is_empty()
		load_game_button.disabled = not has_saves
		continue_button.disabled = _find_last_save().is_empty()


func _find_last_save() -> String:
	if not DirAccess.dir_exists_absolute(SystemUtils.SAVE_DIR):
		return ""
	var dir = DirAccess.open(SystemUtils.SAVE_DIR)
	if dir == null:
		return ""
	var latest_path := ""
	var latest_time := 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".sav"):
			var full_path = SystemUtils.SAVE_DIR + file_name
			var mod_time = FileAccess.get_modified_time(full_path)
			if mod_time > latest_time:
				latest_time = mod_time
				latest_path = full_path
		file_name = dir.get_next()
	dir.list_dir_end()
	return latest_path
