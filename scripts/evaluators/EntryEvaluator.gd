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
	var rest = code.substr(1)  # remove @

	var template_id := ""
	var entry_id := ""

	var slash_idx = rest.find("/")
	if slash_idx > 0:
		# Explicit template: @template_id/namespace.entry_id
		template_id = rest.substr(0, slash_idx)
		entry_id = rest.substr(slash_idx + 1)
	else:
		# Short form: @namespace.entry_id — search all templates
		entry_id = rest

	if entry_id == "":
		push_warning("[EntryEvaluator] Invalid entry reference: " + code)
		return code

	if template_id != "":
		var entry = api.get_entry(template_id, entry_id)
		if entry.is_empty():
			push_warning("[EntryEvaluator] Entry not found: " + code)
			return code
		return entry
	else:
		# Search all templates for this entry_id
		for tmpl_id in api._entries:
			var map = api._entries[tmpl_id]
			if map.has(entry_id):
				return map[entry_id]
		push_warning("[EntryEvaluator] Entry not found in any template: " + code)
		return code
