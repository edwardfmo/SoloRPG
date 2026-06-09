extends Control

signal back_to_menu

@export var back_button: Button

func _ready():
	back_button.pressed.connect(func():
		back_to_menu.emit())
		
