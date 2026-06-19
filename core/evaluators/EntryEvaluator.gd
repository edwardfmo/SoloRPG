## Evaluator that resolves compendium/plugin entry references.
## Format: @namespace.entry_id (searches all templates)
##     or: @template_id/namespace.entry_id (explicit template)
## Examples: @srd_equipment.longsword, @item/srd_equipment.longsword
class_name EntryEvaluator
extends Evaluator

var api: ModAPI


func get_prefixes() -> Array[String]:
	return ["@"]


func evaluate(code: String) -> Variant:
	var parsed = ModAPI.parse_entry_ref(code)
	var template_id: String = parsed["template"]
	# Reconstruct the full entry key (namespace.entry_id)
	var entry_key: String = parsed["namespace"]
	if parsed["entry_id"] != "":
		entry_key += "." + parsed["entry_id"]

	if entry_key == "":
		push_warning("[EntryEvaluator] Invalid entry reference: " + code)
		return code

	if template_id != "":
		var entry = api.get_entry(template_id, entry_key)
		if entry.is_empty():
			push_warning("[EntryEvaluator] Entry not found: " + code)
			return code
		return entry.duplicate(true)
	else:
		# Search all templates for this entry_key
		for tmpl_id in api._entries:
			var map = api._entries[tmpl_id]
			if map.has(entry_key):
				return map[entry_key].duplicate(true)
		push_warning("[EntryEvaluator] Entry not found in any template: " + code)
		return code
