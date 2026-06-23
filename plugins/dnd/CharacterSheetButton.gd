extends Button

var _api: ModAPI = null


func set_api(api: ModAPI):
	_api = api


func _ready():
	text = "📋"
	tooltip_text = "Character Sheet"
	custom_minimum_size = Vector2(40, 40)
	pressed.connect(_on_pressed)


func _on_pressed():
	if _api:
		_api.dispatch_action("core.show_view", {"view": "dnd_character_sheet"})
