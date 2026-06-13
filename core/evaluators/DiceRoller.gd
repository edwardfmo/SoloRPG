## Dice roller evaluator. Supports chained expressions with modifiers.
##
## Grammar:
##   expression := term (('+' | '-') term)*
##   term       := dice_expr | number
##   dice_expr  := [count] 'd' sides [postfixes]
##   postfixes  := any combination of: kh|kl|>|<|min|max|ra|rb (each with number)
##   number     := digits
##
## Execution order for postfixes:
##   1. rb/ra (reroll below/above X, once)
##   2. min/max (clamp individual dice)
##   3. kh/kl (keep highest/lowest N)
##   4. >/< (count successes — threshold mode)
##
## Examples: /r2d6+3, /r4d6kh3min2, /r1d20+2d6kh1-2, /r3d10rb2+5
class_name DiceRoller
extends Evaluator

var _term_regex: RegEx
var _postfix_regex: RegEx


func get_prefixes() -> Array[String]:
	return ["/r", "/roll"]


func _init():
	_term_regex = RegEx.new()
	_term_regex.compile("^(\\d+)d(\\d+)")
	_postfix_regex = RegEx.new()
	_postfix_regex.compile("(kh|kl|min|max|ra|rb|[><])(\\d+)")


func evaluate(code: String) -> Variant:
	var rest = ""
	for prefix in get_prefixes():
		if code.begins_with(prefix):
			rest = code.substr(prefix.length())
			break
	if rest == "":
		push_warning("[DiceRoller] Invalid dice code: " + code)
		return code

	var terms = _split_terms(rest)
	if terms == null:
		push_warning("[DiceRoller] Invalid dice code: " + code)
		return code

	var total := 0
	for term in terms:
		var sign: int = term["sign"]
		var value = _evaluate_term(term)
		if value == null:
			push_warning("[DiceRoller] Invalid term in: " + code)
			return code
		total += sign * value

	return total


## Splits an expression into an array of terms with sign and raw string.
func _split_terms(expr: String) -> Variant:
	var terms := []
	var current := ""
	var sign := 1

	var i := 0
	while i < expr.length():
		var ch = expr[i]
		if (ch == "+" or ch == "-") and current != "":
			terms.append({"sign": sign, "raw": current})
			sign = 1 if ch == "+" else -1
			current = ""
		else:
			current += ch
		i += 1

	if current != "":
		terms.append({"sign": sign, "raw": current})

	if terms.is_empty():
		return null
	return terms


## Evaluates a single term (dice expression or flat number).
func _evaluate_term(term: Dictionary) -> Variant:
	var raw: String = term["raw"]

	# Check if it's a dice expression
	var dice_match = _term_regex.search(raw)
	if dice_match:
		return _evaluate_dice(raw, dice_match)

	# Otherwise it must be a flat number
	if raw.is_valid_int():
		return raw.to_int()

	return null


## Evaluates a dice expression with postfixes.
func _evaluate_dice(raw: String, dice_match: RegExMatch) -> Variant:
	var num = dice_match.get_string(1).to_int()
	var sides = dice_match.get_string(2).to_int()

	if num <= 0 or sides <= 0:
		return null

	# Parse postfixes from the remainder
	var postfix_str = raw.substr(dice_match.get_end())
	var postfixes = _parse_postfixes(postfix_str)
	if postfixes == null:
		return null

	# Validate: kh/kl/>/< only valid on dice, not flat numbers (already enforced by structure)
	var keep_mode: String = postfixes.get("keep_mode", "")
	var keep_count: int = postfixes.get("keep_count", num)
	var reroll_below: int = postfixes.get("rb", 0)
	var reroll_above: int = postfixes.get("ra", 0)
	var clamp_min: int = postfixes.get("min", 0)
	var clamp_max: int = postfixes.get("max", 0)
	var threshold_mode: String = postfixes.get("threshold_mode", "")
	var threshold_target: int = postfixes.get("threshold_target", 0)

	if keep_mode != "" and (keep_count <= 0 or keep_count > num):
		return null

	# 1. Roll all dice
	var rolls: Array[int] = []
	for i in num:
		rolls.append(randi_range(1, sides))

	# 2. Reroll below/above (once)
	if reroll_below > 0:
		for i in rolls.size():
			if rolls[i] < reroll_below:
				rolls[i] = randi_range(1, sides)
	if reroll_above > 0:
		for i in rolls.size():
			if rolls[i] > reroll_above:
				rolls[i] = randi_range(1, sides)

	# 3. Clamp min/max
	if clamp_min > 0:
		for i in rolls.size():
			if rolls[i] < clamp_min:
				rolls[i] = clamp_min
	if clamp_max > 0:
		for i in rolls.size():
			if rolls[i] > clamp_max:
				rolls[i] = clamp_max

	# 4. Keep highest/lowest
	rolls.sort()
	var kept: Array[int]
	if keep_mode == "kh":
		kept = rolls.slice(rolls.size() - keep_count) as Array[int]
	elif keep_mode == "kl":
		kept = rolls.slice(0, keep_count) as Array[int]
	else:
		kept = rolls

	# 5. Threshold or sum
	if threshold_mode != "":
		var count := 0
		for die in kept:
			if threshold_mode == ">" and die > threshold_target:
				count += 1
			elif threshold_mode == "<" and die < threshold_target:
				count += 1
		return count
	else:
		var total := 0
		for die in kept:
			total += die
		return total


## Parses postfix string into a dictionary of modifiers.
## Returns null if the postfix string is malformed.
func _parse_postfixes(postfix_str: String) -> Variant:
	if postfix_str == "":
		return {}

	var result := {}
	var matches = _postfix_regex.search_all(postfix_str)

	# Validate that all characters are accounted for
	var total_matched := 0
	for m in matches:
		total_matched += m.get_string().length()
	if total_matched != postfix_str.length():
		return null

	for m in matches:
		var key = m.get_string(1)
		var val = m.get_string(2).to_int()
		match key:
			"kh":
				result["keep_mode"] = "kh"
				result["keep_count"] = val
			"kl":
				result["keep_mode"] = "kl"
				result["keep_count"] = val
			">":
				result["threshold_mode"] = ">"
				result["threshold_target"] = val
			"<":
				result["threshold_mode"] = "<"
				result["threshold_target"] = val
			"min":
				result["min"] = val
			"max":
				result["max"] = val
			"ra":
				result["ra"] = val
			"rb":
				result["rb"] = val

	return result
