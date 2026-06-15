## Top-level editor wrapper with tabs for Module and Compendium editing.
extends Control

signal close_pressed

@export var tab_container: TabContainer
@export var node_editor: Control
@export var compendium_editor: Control

var _api: ModAPI = null


func set_api(api: ModAPI):
	_api = api
	node_editor.set_api(api)
	compendium_editor.set_api(api)


func _ready():
	visibility_changed.connect(_on_visibility_changed)
	tab_container.tab_changed.connect(_on_tab_changed)


func _on_tab_changed(_tab: int):
	_sync_module_to_compendium()
	compendium_editor.refresh()

func _on_close_pressed():
	if compendium_editor.has_unsaved_changes():
		_show_unsaved_dialog()
	else:
		close_pressed.emit()


func _show_unsaved_dialog():
	var dialog = ConfirmationDialog.new()
	dialog.title = "Unsaved Changes"
	dialog.dialog_text = "You have unsaved compendium changes.\nSave before closing?"
	dialog.get_ok_button().text = "Save"
	dialog.add_button("Discard", true, "discard")
	dialog.confirmed.connect(func():
		compendium_editor.save_all()
		dialog.queue_free()
		close_pressed.emit())
	dialog.custom_action.connect(func(action):
		if action == "discard":
			compendium_editor.discard_changes()
			dialog.queue_free()
			close_pressed.emit())
	dialog.canceled.connect(func():
		dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_visibility_changed():
	if visible:
		node_editor.reset()
		_sync_module_to_compendium()
		compendium_editor.refresh()


func _sync_module_to_compendium():
	if node_editor.is_module_loaded():
		compendium_editor.set_module_data(node_editor.get_module_id(), node_editor.get_module_entries())
	else:
		compendium_editor.set_module_data("", {})
