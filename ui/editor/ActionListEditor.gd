## Editor for an array of action dictionaries.
class_name ActionListEditor
extends APIItemListEditor

var _display_scene = preload("res://ui/editor/CollapsibleActionDisplay.tscn")


func _get_display_scene() -> PackedScene:
	return _display_scene
