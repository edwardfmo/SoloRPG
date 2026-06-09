extends Control

signal module_selected(path: String)
signal back_pressed

@export var module_list: VBoxContainer
@export var back_button: Button

var ModuleEntryScene = preload("res://scenes/ModuleEntry.tscn")

func _ready():
	back_button.pressed.connect(func(): back_pressed.emit())
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		_refresh_list()


func _refresh_list():
	for child in module_list.get_children():
		child.queue_free()

	var dir = DirAccess.open("res://modules")
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path = "res://modules/" + file_name
			var json_text = FileAccess.get_file_as_string(path)
			var data = JSON.parse_string(json_text)
			if data != null:
				_add_module_entry(data, path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _add_module_entry(data: Dictionary, path: String):
	var entry = ModuleEntryScene.instantiate()
	module_list.add_child(entry)
	entry.setup(data, path)
	entry.play_pressed.connect(func(p): module_selected.emit(p))
