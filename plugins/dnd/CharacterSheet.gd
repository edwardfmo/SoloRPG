extends PluginOverlay


@export var title_label: Label
@export var hp_label: Label
@export var max_hp_label: Label
@export var close_button: Button

var _context := {}


func _ready():
	super._ready()
	close_button.pressed.connect(close)


func _on_open(params: Dictionary):
	_update_display()


func update_context(context: Dictionary):
	_context = context
	_update_display()


func _update_display():
	if not is_inside_tree():
		return
	title_label.text = "Character Sheet"
	hp_label.text = "HP: %d" % _context.get("hp", 0)
	max_hp_label.text = "Max HP: %d" % _context.get("max_hp", 10)
