extends Control

signal new_game_pressed
signal node_editor_pressed
signal plugins_pressed
signal exit_pressed

@export var new_game_button: Button
@export var node_editor_button: Button
@export var plugins_button: Button
@export var exit_button: Button

func _ready():
	new_game_button.pressed.connect(func():
		new_game_pressed.emit()
	)

	node_editor_button.pressed.connect(func():
		node_editor_pressed.emit()
	)

	plugins_button.pressed.connect(func():
		plugins_pressed.emit()
	)

	exit_button.pressed.connect(func():
		exit_pressed.emit()
	)
