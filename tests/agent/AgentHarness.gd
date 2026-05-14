extends SceneTree

const ScenarioRunner := preload("res://tests/agent/ScenarioRunner.gd")
const HarnessLog := preload("res://tests/agent/HarnessLog.gd")

const DEFAULT_SCENARIO := "res://tests/agent/scenarios/hunter_basic_attack.json"
const DEFAULT_ARTIFACT_ROOT := "res://tests/agent/artifacts"

var _scenario_path := DEFAULT_SCENARIO
var _artifact_root := DEFAULT_ARTIFACT_ROOT
var _artifact_dir_res := ""
var _artifact_dir_abs := ""
var _log := HarnessLog.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_args(OS.get_cmdline_user_args())
	var scenario := _load_scenario(_scenario_path)
	if scenario.is_empty():
		quit(1)
		return
	_prepare_artifact_dir(str(scenario.get("scenario", "scenario")))
	_log.setup(_artifact_dir_abs)
	_log.info("scenario_path=%s" % _scenario_path)
	_log.info("artifact_dir=%s" % _artifact_dir_abs)
	var runner := ScenarioRunner.new()
	if not runner.setup(self, scenario, _artifact_dir_abs, _log):
		_log.close()
		quit(1)
		return
	var summary: Dictionary = await runner.run()
	_write_json("run.json", summary)
	_write_summary(summary)
	_log.info("artifacts=%s" % _artifact_dir_abs)
	if bool(summary.get("ok", false)):
		_log.info("PASS %s" % str(summary.get("scenario", "")))
		_log.close()
		quit(0)
	else:
		_log.error("FAIL %s" % str(summary.get("failures", [])))
		_log.close()
		push_error("[AgentHarness] FAIL %s" % str(summary.get("failures", [])))
		quit(1)


func _parse_args(args: PackedStringArray) -> void:
	var i := 0
	while i < args.size():
		match args[i]:
			"--scenario":
				i += 1
				if i < args.size():
					_scenario_path = args[i]
			"--artifact-dir":
				i += 1
				if i < args.size():
					_artifact_root = _normalize_res_path(args[i])
		i += 1


func _load_scenario(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open scenario %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Scenario is not a JSON object: %s" % path)
		return {}
	return parsed


func _prepare_artifact_dir(scenario_name: String) -> void:
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(":", "")
	var dir_name := "%s_%s" % [timestamp, scenario_name.to_snake_case()]
	_artifact_dir_res = _artifact_root.path_join(dir_name)
	_artifact_dir_abs = ProjectSettings.globalize_path(_artifact_dir_res)
	var error := DirAccess.make_dir_recursive_absolute(_artifact_dir_abs)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Unable to create artifact dir %s" % _artifact_dir_abs)


func _write_json(filename: String, data: Dictionary) -> void:
	var file := FileAccess.open(_artifact_dir_abs.path_join(filename), FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s" % filename)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _write_summary(summary: Dictionary) -> void:
	var lines: Array[String] = []
	lines.append("# %s" % str(summary.get("scenario", "Scenario")))
	lines.append("")
	lines.append("- ok: %s" % str(summary.get("ok", false)))
	lines.append("- seed: %s" % str(summary.get("seed", 0)))
	lines.append("- duration_seconds: %s" % str(summary.get("duration_seconds", 0.0)))
	lines.append("- screenshots: %s" % str(summary.get("screenshots", 0)))
	lines.append("")
	lines.append("## Assertions")
	for assertion in summary.get("assertions", []):
		lines.append("- [%s] %s" % ["x" if assertion.get("ok", false) else " ", assertion.get("message", assertion.get("condition", ""))])
	if not summary.get("failures", []).is_empty():
		lines.append("")
		lines.append("## Failures")
		for failure in summary.get("failures", []):
			lines.append("- %s" % failure)
	var file := FileAccess.open(_artifact_dir_abs.path_join("summary.md"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _normalize_res_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	return "res://%s" % path.trim_prefix("./")
