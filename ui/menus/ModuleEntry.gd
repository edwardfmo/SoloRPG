class_name ModuleEntry
extends VBoxContainer

signal play_pressed(path: String)

var module_path: String = ""
var has_dep_issues: bool = false

@export var display_name_label: Label
@export var author_label: Label
@export var play_button: Button
@export var file_version_label: Label
@export var dep_issues_label: RichTextLabel

func _ready():
	play_button.pressed.connect(func(): play_pressed.emit(module_path))


func setup(data: Dictionary, path: String, api: ModAPI = null):
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

	# Check dependencies
	has_dep_issues = false
	dep_issues_label.text = ""
	dep_issues_label.visible = false

	var deps = data.get("dependencies", [])
	if deps.is_empty() or api == null:
		return

	var result = DependencyChecker.check(deps)
	if not result["has_issues"]:
		return

	has_dep_issues = result["has_missing"]
	var issues := ""
	for issue in result["issues"]:
		var label = issue["id"]
		if issue["status"] == "missing":
			var type_label = "compendium" if issue["type"] == "compendium" else "plugin"
			issues += "[color=red]✗ " + label + " (" + type_label + " not installed)[/color]\n"
		else:
			issues += "[color=yellow]⚠ " + label + " (" + issue["message"] + ")[/color]\n"
			has_dep_issues = true

	if issues != "":
		dep_issues_label.text = issues.strip_edges()
		dep_issues_label.visible = true
