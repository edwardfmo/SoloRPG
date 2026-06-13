extends HBoxContainer

@onready var label := $Label
@onready var bar := $ProgressBar


func _ready():
	label.text = "HP:"
	bar.min_value = 0
	bar.max_value = 10
	bar.value = 10


func update_context(context: Dictionary):
	var character = context.get("character", {})
	var hp = character.get("hp", 0)
	var max_hp = character.get("max_hp", 10)
	bar.max_value = max_hp
	bar.value = hp
	label.text = "HP: %d/%d" % [hp, max_hp]
