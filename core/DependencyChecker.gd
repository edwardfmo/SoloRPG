## Utility class for checking module dependencies against installed plugins/compendiums.
class_name DependencyChecker
extends RefCounted


## Result of a dependency check.
## issues: Array of {id, type, status, message} where status is "missing" or "version_mismatch"
## has_missing: true if any dependency is completely absent
## has_issues: true if any dependency has a problem (missing or version mismatch)
static func check(dependencies: Array) -> Dictionary:
	if dependencies.is_empty():
		return {"issues": [], "has_missing": false, "has_issues": false}

	var loader = PluginLoader.new()
	var all_plugins = loader.scan_metadata()
	var installed_plugins := {}
	for meta in all_plugins:
		var id = meta.get("id", meta.get("filename", ""))
		installed_plugins[id] = meta

	var comp_loader = CompendiumLoader.new()
	var all_compendiums = comp_loader.scan_metadata()
	var installed_compendiums := {}
	for meta in all_compendiums:
		var id = meta.get("id", "")
		installed_compendiums[id] = meta

	var issues := []
	var has_missing := false
	var has_issues := false

	for dep in dependencies:
		var dep_id = dep.get("id", "")
		var dep_version = dep.get("version", "")
		var dep_type = dep.get("type", "plugin")
		if dep_id == "":
			continue

		var installed_map = installed_compendiums if dep_type == "compendium" else installed_plugins

		if not installed_map.has(dep_id):
			issues.append({"id": dep_id, "type": dep_type, "status": "missing", "message": "not installed"})
			has_missing = true
			has_issues = true
		else:
			var meta = installed_map[dep_id]
			var current_ver = meta.get("version", "")
			if dep_version != "" and current_ver != "" and dep_version != current_ver:
				issues.append({"id": dep_id, "type": dep_type, "status": "version_mismatch", "message": "need v" + dep_version + ", have v" + current_ver})
				has_issues = true

	return {"issues": issues, "has_missing": has_missing, "has_issues": has_issues}
