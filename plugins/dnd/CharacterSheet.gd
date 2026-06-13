extends PluginOverlay


@export var title_label: Label
@export var hp_label: Label
@export var max_hp_label: Label
@export var weapon_label: Label
@export var armor_label: Label
@export var close_button: Button

var _context := {}
var api: ModAPI


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
	var character = _context.get("character", {})
	hp_label.text = "HP: %d" % character.get("hp", 0)
	max_hp_label.text = "Max HP: %d" % character.get("max_hp", 10)

	# Equipment
	var equipment = character.get("equipment", {})
	weapon_label.text = _format_slot("Weapon", equipment.get("weapon", {}))
	armor_label.text = _format_slot("Armor", equipment.get("armor", {}))


func _format_slot(slot_name: String, slot_value) -> String:
	if slot_value == null or (slot_value is Dictionary and slot_value.is_empty()):
		return slot_name + ": (empty)"
	# Resolve _ref wrapper if api is available
	var item = slot_value
	if api != null:
		item = api.resolve(slot_value)
	if not item is Dictionary:
		return slot_name + ": (unknown)"
	var text = slot_name + ": " + item.get("name", "???")
	var details := []
	if item.has("damage"):
		details.append("dmg " + str(item["damage"]))
	if item.has("weight"):
		details.append(str(item["weight"]) + " lb")
	var tags = item.get("tags", [])
	if not tags.is_empty():
		details.append(", ".join(tags))
	if not details.is_empty():
		text += "  (" + " | ".join(details) + ")"
	return text
