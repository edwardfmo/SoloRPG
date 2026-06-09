extends Control

@export var main_menu: Control
@export var game_view: Control
@export var game_over: Control
@export var node_editor: Control
@export var module_select: Control

var module
var api = ModAPI.new()
var context = {"hp": 10}
var current_node_id


func _ready():
	# Plugin
	var dnd = DNDSystem.new()
	api.register_system("dnd", dnd)

	# Connect UI
	main_menu.new_game_pressed.connect(_show_module_select)
	main_menu.node_editor_pressed.connect(_show_node_editor)
	main_menu.exit_pressed.connect(func(): get_tree().quit())

	node_editor.close_pressed.connect(_show_menu)

	module_select.module_selected.connect(_start_game)
	module_select.back_pressed.connect(_show_menu)

	game_view.choice_selected.connect(_on_choice_selected)
	game_over.back_to_menu.connect(_show_menu)

	_show_menu()


# -------------------------
# STATES
# -------------------------

func _show_menu():
	main_menu.visible = true
	game_view.visible = false
	game_over.visible = false
	node_editor.visible = false
	module_select.visible = false


func _show_node_editor():
	main_menu.visible = false
	game_view.visible = false
	game_over.visible = false
	node_editor.visible = true
	module_select.visible = false


func _show_module_select():
	main_menu.visible = false
	game_view.visible = false
	game_over.visible = false
	node_editor.visible = false
	module_select.visible = true


func _start_game(path: String):
	main_menu.visible = false
	game_view.visible = true
	game_over.visible = false
	node_editor.visible = false
	module_select.visible = false

	var data = JSON.parse_string(FileAccess.get_file_as_string(path))

	module = Module.new()
	module.init(data, api)

	context = {"hp": 10}
	current_node_id = module.start_node

	_enter_node()


func _enter_node():
	module.enter_node(current_node_id, context)

	var node = module.get_node(current_node_id)

	if node.get("choices", []).is_empty():
		_show_game_over()
		return

	game_view.display_node(node, module, context)


func _on_choice_selected(choice):
	current_node_id = choice.get("next", "")
	_enter_node()


func _show_game_over():
	game_view.visible = false
	game_over.visible = true
