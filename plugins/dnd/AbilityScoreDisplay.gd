class_name AbilityScoreDisplay
extends HBoxContainer

signal value_changed(ability_score:String, value: int)

@export var _ability_score_name: Label
@export var _value: SpinBox
@export var _modifier: Label
@export var _cost: Label

var _dnd_system: GDScript

var ability_score: String:
	set(v):
		_ability_score_name.text = v

var value: int:
	get:
		return _value.value
	set(v):
		_value.value = v

var modifier: int:
	get:
		return _dnd_system.get_modifier(int(value)) if _dnd_system else 0

var cost: int:
	get:
		return _dnd_system.get_score_cost(int(value), int(_value.min_value)) if _dnd_system else 0

var min_value: int:
	set(v):
		_value.min_value = v

var max_value: int:
	set(v):
		_value.max_value = v


func _ready() -> void:
	_dnd_system = load(get_script().resource_path.get_base_dir().path_join("DNDSystem.gd"))
	_value.value_changed.connect(_update_value)
	_update_value(value)


func _update_value(_val) -> void:
	_modifier.text = str(modifier)
	_cost.text = str(cost)
	value_changed.emit(ability_score, value)
