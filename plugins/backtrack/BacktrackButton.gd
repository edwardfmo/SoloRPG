extends Button

const BACKTRACK_KEY = "_backtrack"

var _api: ModAPI = null
var _last_context: Dictionary = {}


func set_api(api: ModAPI):
	_api = api


func _ready():
	text = "↩"
	tooltip_text = "Back"
	disabled = true
	pressed.connect(_on_pressed)


func update_context(context: Dictionary):
	_last_context = context
	disabled = not context.has(BACKTRACK_KEY)


func _on_pressed():
	if _api and _api.restore_state_callback.is_valid() and _last_context.has(BACKTRACK_KEY):
		var saved_context = _last_context[BACKTRACK_KEY]
		if saved_context.has("_current_node_id"):
			_api.restore_state_callback.call(saved_context)
