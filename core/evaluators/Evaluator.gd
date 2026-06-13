## Base class for evaluators. Subclass this to create custom value evaluators.
## Each evaluator declares one or more prefixes and implements evaluate().
class_name Evaluator
extends RefCounted


## Return the prefixes this evaluator handles (e.g. ["/r", "/roll"]).
func get_prefixes() -> Array[String]:
	return []


## Evaluate a code string and return the result.
## Called when a value starts with one of this evaluator's prefixes.
func evaluate(_code: String) -> Variant:
	return _code


## Register this evaluator with a ModAPI instance.
func register(api: ModAPI):
	api.register_evaluator_instance(self)
