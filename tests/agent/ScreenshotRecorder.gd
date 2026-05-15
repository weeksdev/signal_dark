extends RefCounted

var _tree: SceneTree
var _artifact_dir_abs: String = ""
var _screenshot_dir_abs: String = ""
var _max_screenshots: int = 16
var _count: int = 0
var _log: RefCounted
var captures: Array[Dictionary] = []


func setup(tree: SceneTree, artifact_dir_abs: String, max_screenshots: int, log: RefCounted = null) -> bool:
	_tree = tree
	_artifact_dir_abs = artifact_dir_abs
	_screenshot_dir_abs = artifact_dir_abs.path_join("screenshots")
	_max_screenshots = max_screenshots
	_log = log
	var error := DirAccess.make_dir_recursive_absolute(_screenshot_dir_abs)
	return error == OK or error == ERR_ALREADY_EXISTS


func capture(label: String, telemetry: Dictionary) -> Dictionary:
	if _count >= _max_screenshots:
		_log_warn("capture skipped cap reached label=%s" % label)
		return {
			"ok": false,
			"error": "screenshot cap reached",
		}
	await _tree.process_frame
	await _tree.process_frame
	_count += 1
	if DisplayServer.get_name().to_lower() == "headless":
		_log_warn("capture skipped headless display label=%s" % label)
		var headless_result := {
			"ok": true,
			"skipped": true,
			"label": label,
			"file": "",
			"telemetry": telemetry,
			"note": "headless display has no viewport image",
		}
		captures.append(headless_result)
		return headless_result
	var safe_label := _safe_name(label)
	var filename := "%03d_%s.png" % [_count, safe_label]
	var path_abs := _screenshot_dir_abs.path_join(filename)
	var texture := _tree.root.get_texture()
	if texture == null:
		_log_warn("capture skipped missing viewport texture label=%s" % label)
		var skipped_result := {
			"ok": true,
			"skipped": true,
			"label": label,
			"file": "",
			"telemetry": telemetry,
			"note": "viewport texture unavailable",
		}
		captures.append(skipped_result)
		return skipped_result
	var image := texture.get_image()
	if image == null:
		_log_warn("capture skipped missing viewport image label=%s" % label)
		var skipped_image_result := {
			"ok": true,
			"skipped": true,
			"label": label,
			"file": "",
			"telemetry": telemetry,
			"note": "viewport image unavailable",
		}
		captures.append(skipped_image_result)
		return skipped_image_result
	var error := image.save_png(path_abs)
	var result := {
		"ok": error == OK,
		"label": label,
		"file": "screenshots/%s" % filename,
		"telemetry": telemetry,
	}
	if error != OK:
		result["error"] = "save_png failed with code %d" % error
		_log_warn("capture failed label=%s code=%d" % [label, error])
	else:
		_log_info("capture saved label=%s file=%s" % [label, filename])
	captures.append(result)
	return result


func count() -> int:
	return _count


func capture_index() -> Array[Dictionary]:
	var index: Array[Dictionary] = []
	for capture in captures:
		var telemetry: Dictionary = capture.get("telemetry", {})
		index.append({
			"ok": bool(capture.get("ok", false)),
			"skipped": bool(capture.get("skipped", false)),
			"label": str(capture.get("label", "")),
			"file": str(capture.get("file", "")),
			"note": str(capture.get("note", "")),
			"time_msec": telemetry.get("time_msec", 0),
			"enemy_count": telemetry.get("enemy_count", 0),
			"drone_count": telemetry.get("drone_count", 0),
			"player": telemetry.get("player", {}),
			"enemies": telemetry.get("enemies", []),
			"drones": telemetry.get("drones", []),
			"search": telemetry.get("search", {}),
			"events_since_last_capture": telemetry.get("events_since_last_capture", []),
		})
	return index


func _safe_name(value: String) -> String:
	var output := value.to_snake_case()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		output = output.replace(ch, "_")
	return output


func _log_info(message: String) -> void:
	if _log != null and _log.has_method("info"):
		_log.info(message)


func _log_warn(message: String) -> void:
	if _log != null and _log.has_method("warn"):
		_log.warn(message)
