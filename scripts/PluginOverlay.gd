## Base class for plugin overlay views (full-screen modals).
## Handles Escape key to close. Subclass and override _on_open(params).
class_name PluginOverlay
extends Control


signal closed


func _ready():
	visible = false
	set_process_unhandled_input(true)
	# Full screen
	anchors_preset = PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0


func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Called when the overlay is shown. Override in subclass.
func _on_open(_params: Dictionary):
	pass


## Called when context changes while overlay is visible. Override if needed.
func update_context(_context: Dictionary):
	pass


## Show the overlay with parameters.
func open(params: Dictionary = {}):
	_on_open(params)
	visible = true
	grab_focus()


## Hide the overlay.
func close():
	visible = false
	closed.emit()
