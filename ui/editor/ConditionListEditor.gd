## Editor for an array of condition dictionaries.
## Uses CollapsibleConditionDisplay which adds OR/NOT toggles.
class_name ConditionListEditor
extends APIItemListEditor

var _display_scene = preload("res://ui/editor/CollapsibleConditionDisplay.tscn")


func _get_display_scene() -> PackedScene:
	return _display_scene


func _get_extra_config(idx: int) -> Dictionary:
	return {"show_or": idx > 0}
