class_name ModuleEntry
extends VBoxContainer

signal play_pressed(path: String)

var module_path: String = ""

@export var display_name_label: Label
@export var author_label: Label
@export var play_button: Button
@export var file_version_label: Label

func _ready():
	play_button.pressed.connect(func(): play_pressed.emit(module_path))


func setup(data: Dictionary, path: String):
	module_path = path

	var display_name = data.get("name", data.get("id", "Unknown"))
	var author = data.get("author", "")
	var version = data.get("version", "")
	var file_name = path.get_file()

	display_name_label.text = display_name

	if author != "":
		author_label.text = "by: " + author
	else:
		author_label.text = ""

	var bottom_text = file_name
	if version != "":
		bottom_text += "  •  v" + version
	file_version_label.text = bottom_text
