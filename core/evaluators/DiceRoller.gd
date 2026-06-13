## Dice roller evaluator. Parses dice codes in the format:
## /r[num]d[sides] — optional: kh[X] or kl[X] — optional: >[X] or <[X]
## Examples: /r2d6, /r4d6kh3, /r3d8>5, /r2d20kl1
## Also accepts /roll as prefix (e.g. /roll2d6).
class_name DiceRoller
extends Evaluator


func get_prefixes() -> Array[String]:
	return ["/r", "/roll"]


func evaluate(code: String) -> Variant:
	var parsed = _parse(code)
	if parsed == null:
		push_warning("[DiceRoller] Invalid dice code: " + code)
		return code

	var num: int = parsed["num"]
	var sides: int = parsed["sides"]
	var keep_mode: String = parsed["keep_mode"]
	var keep_count: int = parsed["keep_count"]
	var count_mode: String = parsed["count_mode"]
	var count_target: int = parsed["count_target"]

	# Roll all dice
	var rolls: Array[int] = []
	for i in num:
		rolls.append(randi_range(1, sides))

	# Sort for keep logic
	rolls.sort()

	# Apply keep
	var kept: Array[int] = []
	if keep_mode == "kh":
		kept = rolls.slice(rolls.size() - keep_count) as Array[int]
	elif keep_mode == "kl":
		kept = rolls.slice(0, keep_count) as Array[int]
	else:
		kept = rolls

	# Compute result
	if count_mode != "":
		var count := 0
		for die in kept:
			if count_mode == ">" and die > count_target:
				count += 1
			elif count_mode == "<" and die < count_target:
				count += 1
		return count
	else:
		var total := 0
		for die in kept:
			total += die
		return total


## Parses a dice code string. Returns null if invalid.
func _parse(code: String):
	var rest = ""
	for prefix in get_prefixes():
		if code.begins_with(prefix):
			rest = code.substr(prefix.length())
			break
	if rest == "":
		return null

	# Match: [num]d[sides] (optional kh[X]|kl[X]) (optional >[X]|<[X])
	var regex = RegEx.new()
	regex.compile("^(\\d+)d(\\d+)(?:(kh|kl)(\\d+))?(?:([><])(\\d+))?$")
	var result = regex.search(rest)
	if result == null:
		return null

	var num = result.get_string(1).to_int()
	var sides = result.get_string(2).to_int()

	var keep_mode = result.get_string(3)
	var keep_count = result.get_string(4).to_int() if result.get_string(4) != "" else num
	var count_mode = result.get_string(5)
	var count_target = result.get_string(6).to_int() if result.get_string(6) != "" else 0

	if num <= 0 or sides <= 0:
		return null
	if keep_mode != "" and (keep_count <= 0 or keep_count > num):
		return null

	return {
		"num": num,
		"sides": sides,
		"keep_mode": keep_mode,
		"keep_count": keep_count,
		"count_mode": count_mode,
		"count_target": count_target,
	}
