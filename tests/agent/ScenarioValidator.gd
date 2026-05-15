extends RefCounted

const REQUIRED_TOP_LEVEL := ["scenario", "scene", "steps"]
const ACTIONS := [
	"spawn_player",
	"spawn_dark_pocket",
	"spawn_enemy",
	"move_to",
	"move_vector",
	"aim_at",
	"hold_input",
	"tap_input",
	"wait",
	"capture",
	"assert",
]


func validate(scenario: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_TOP_LEVEL:
		if not scenario.has(key):
			errors.append("Missing required field '%s'" % key)
	if scenario.has("scenario") and str(scenario.get("scenario", "")).strip_edges() == "":
		errors.append("'scenario' must be a non-empty string")
	if scenario.has("scene") and str(scenario.get("scene", "")).strip_edges() == "":
		errors.append("'scene' must be a non-empty resource path")
	if scenario.has("seed") and not _is_number(scenario.get("seed")):
		errors.append("'seed' must be numeric")
	if scenario.has("time_scale") and (not _is_number(scenario.get("time_scale")) or float(scenario.get("time_scale")) <= 0.0):
		errors.append("'time_scale' must be a positive number")
	if scenario.has("duration") and (not _is_number(scenario.get("duration")) or float(scenario.get("duration")) < 0.0):
		errors.append("'duration' must be a non-negative number")
	if scenario.has("screenshots"):
		_validate_screenshots(scenario.get("screenshots"), errors)
	var steps_value: Variant = scenario.get("steps")
	if not (steps_value is Array):
		errors.append("'steps' must be an array")
	else:
		_validate_steps(steps_value as Array, errors)
	var assertions_value: Variant = scenario.get("assertions", [])
	if not (assertions_value is Array):
		errors.append("'assertions' must be an array when present")
	else:
		_validate_assertions(assertions_value as Array, "assertions", errors)
	return errors


func _validate_screenshots(value: Variant, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("'screenshots' must be an object")
		return
	var config := value as Dictionary
	if config.has("interval_seconds") and (not _is_number(config.get("interval_seconds")) or float(config.get("interval_seconds")) < 0.0):
		errors.append("'screenshots.interval_seconds' must be a non-negative number")
	if config.has("max") and (not _is_number(config.get("max")) or int(config.get("max")) < 0):
		errors.append("'screenshots.max' must be a non-negative integer")
	if config.has("capture_on_failure") and not (config.get("capture_on_failure") is bool):
		errors.append("'screenshots.capture_on_failure' must be a boolean")


func _validate_steps(steps: Array, errors: Array[String]) -> void:
	for i in range(steps.size()):
		var step_value: Variant = steps[i]
		if not (step_value is Dictionary):
			errors.append("steps[%d] must be an object" % i)
			continue
		var step := step_value as Dictionary
		if not _is_number(step.get("t")):
			errors.append("steps[%d].t must be numeric" % i)
		var action := str(step.get("action", ""))
		if action == "":
			errors.append("steps[%d].action is required" % i)
			continue
		if not ACTIONS.has(action):
			errors.append("steps[%d].action '%s' is not supported" % [i, action])
			continue
		_validate_action_step(step, i, errors)


func _validate_action_step(step: Dictionary, index: int, errors: Array[String]) -> void:
	match str(step.get("action", "")):
		"spawn_player":
			if step.has("at") and not _is_vec2_array(step.get("at")):
				errors.append("steps[%d].at must be [x, y]" % index)
		"spawn_dark_pocket":
			if step.has("at") and not _is_vec2_array(step.get("at")):
				errors.append("steps[%d].at must be [x, y]" % index)
		"spawn_enemy":
			if str(step.get("type", "")).strip_edges() == "":
				errors.append("steps[%d].type is required for spawn_enemy" % index)
			if step.has("at") and not _is_vec2_array(step.get("at")):
				errors.append("steps[%d].at must be [x, y]" % index)
			if step.has("patrol_points"):
				var points: Variant = step.get("patrol_points")
				if not (points is Array):
					errors.append("steps[%d].patrol_points must be an array" % index)
				else:
					for j in range((points as Array).size()):
						if not _is_vec2_array((points as Array)[j]):
							errors.append("steps[%d].patrol_points[%d] must be [x, y]" % [index, j])
		"move_to":
			if not _is_vec2_array(step.get("target")):
				errors.append("steps[%d].target must be [x, y]" % index)
		"move_vector":
			if not _is_vec2_array(step.get("direction")):
				errors.append("steps[%d].direction must be [x, y]" % index)
			if not _is_non_negative_duration(step):
				errors.append("steps[%d].duration must be non-negative" % index)
		"aim_at":
			if not step.has("target"):
				errors.append("steps[%d].target is required for aim_at" % index)
		"hold_input", "tap_input":
			if str(step.get("input", "")).strip_edges() == "":
				errors.append("steps[%d].input is required" % index)
			if not _is_non_negative_duration(step):
				errors.append("steps[%d].duration must be non-negative" % index)
		"capture":
			if str(step.get("name", "")).strip_edges() == "":
				errors.append("steps[%d].name is required for capture" % index)
		"assert":
			_validate_assertion(step, "steps[%d]" % index, errors)


func _validate_assertions(assertions: Array, label: String, errors: Array[String]) -> void:
	for i in range(assertions.size()):
		var assertion: Variant = assertions[i]
		if not (assertion is Dictionary):
			errors.append("%s[%d] must be an object" % [label, i])
			continue
		_validate_assertion(assertion as Dictionary, "%s[%d]" % [label, i], errors)


func _validate_assertion(assertion: Dictionary, label: String, errors: Array[String]) -> void:
	if str(assertion.get("condition", "")).strip_edges() == "":
		errors.append("%s.condition is required" % label)
	if assertion.has("message") and not (assertion.get("message") is String):
		errors.append("%s.message must be a string" % label)


func _is_non_negative_duration(step: Dictionary) -> bool:
	if not step.has("duration"):
		return true
	return _is_number(step.get("duration")) and float(step.get("duration")) >= 0.0


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _is_vec2_array(value: Variant) -> bool:
	if not (value is Array):
		return false
	var array := value as Array
	return array.size() >= 2 and _is_number(array[0]) and _is_number(array[1])
