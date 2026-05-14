extends RefCounted

var _file: FileAccess
var _started_msec: int = 0


func setup(artifact_dir_abs: String) -> bool:
	_started_msec = Time.get_ticks_msec()
	_file = FileAccess.open(artifact_dir_abs.path_join("harness.log"), FileAccess.WRITE)
	if _file == null:
		push_error("[AgentHarness] unable to open harness.log")
		return false
	info("log initialized")
	return true


func info(message: String) -> void:
	_write("INFO", message)


func warn(message: String) -> void:
	_write("WARN", message)


func error(message: String) -> void:
	_write("ERROR", message)


func close() -> void:
	if _file != null:
		info("log closed")
		_file.close()
		_file = null


func _write(level: String, message: String) -> void:
	var elapsed := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	var line := "[AgentHarness %.3fs] %s %s" % [elapsed, level, message]
	print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()

