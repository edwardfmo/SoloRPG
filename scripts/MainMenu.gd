extends Control

signal new_game_pressed
signal exit_pressed

func _ready():
	$CenterContainer/VBoxContainer/NewGame.pressed.connect(func():
		new_game_pressed.emit()
	)

	$CenterContainer/VBoxContainer/Exit.pressed.connect(func():
		exit_pressed.emit()
	)
