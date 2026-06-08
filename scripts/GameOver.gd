extends Control

signal back_to_menu

func _ready():
	$CenterContainer/VBoxContainer/Button.pressed.connect(func():
		back_to_menu.emit())
		
