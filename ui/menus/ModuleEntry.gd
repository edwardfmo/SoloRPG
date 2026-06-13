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

	var issues := ""
	var loaded_plugins = api.plugins.keys()
	# Scan all installed plugins (regardless of enabled/disabled)
	var loader = PluginLoader.new()
	var all_installed = loader.scan_metadata()
	var installed_ids := {}
	for meta in all_installed:
		var id = meta.get("id", meta.get("filename", ""))
		installed_ids[id] = meta

	# Scan all installed compendiums
	var comp_loader = CompendiumLoader.new()
	var all_compendiums = comp_loader.scan_metadata()
	var installed_compendiums := {}
	for meta in all_compendiums:
		var id = meta.get("id", "")
		installed_compendiums[id] = meta

	for dep in deps:
		var dep_id = dep.get("id", "")
		var dep_version = dep.get("version", "")
		var dep_type = dep.get("type", "plugin")
		if dep_id == "":
			continue

		if dep_type == "compendium":
			if not installed_compendiums.has(dep_id):
				issues += "[color=red]✗ " + dep_id + " (compendium not installed)[/color]\n"
				has_dep_issues = true
			else:
				var meta = installed_compendiums[dep_id]
				var current_ver = meta.get("version", "")
				if dep_version != "" and current_ver != "" and dep_version != current_ver:
					issues += "[color=yellow]⚠ " + dep_id + " (need v" + dep_version + ", have v" + current_ver + ")[/color]\n"
					has_dep_issues = true
		else:
			if not installed_ids.has(dep_id):
				issues += "[color=red]✗ " + dep_id + " (not installed)[/color]\n"
				has_dep_issues = true
			else:
				var meta = installed_ids[dep_id]
				var current_ver = meta.get("version", "")
				if dep_version != "" and current_ver != "" and dep_version != current_ver:
					issues += "[color=yellow]⚠ " + dep_id + " (need v" + dep_version + ", have v" + current_ver + ")[/color]\n"
					has_dep_issues = true

	if issues != "":
		dep_issues_label.text = issues.strip_edges()
		dep_issues_label.visible = true
