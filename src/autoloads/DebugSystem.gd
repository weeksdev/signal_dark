extends Node

const ENABLE_ARG := "--signal-dark-debug"
const LOG_DIR := "res://.debug"
const LOG_FILE := "runtime_debug.log"

var enabled: bool = false
var _initialized: bool = false
var _session_started_at: String = ""


func _ready() -> void:
	enabled = _env_enabled()
	if enabled:
		init_session()


func init_session() -> void:
	if not enabled or _initialized:
		return
	_initialized = true
	_session_started_at = Time.get_datetime_string_from_system()
	var log_path := get_log_path()
	var dir_error := DirAccess.make_dir_absolute(log_path.get_base_dir())
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_warning("DebugSystem: failed to create log directory at %s" % log_path.get_base_dir())
		return
	var file := FileAccess.open(log_path, FileAccess.WRITE)
	if file == null:
		push_warning("DebugSystem: failed to open log file at %s" % log_path)
		return
	file.store_line("=== Signal Dark Debug Session: %s ===" % _session_started_at)
	file.store_line("Path: %s" % log_path)
	file.store_line("Renderer: %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	file.close()
	print("[DebugSystem] logging to %s" % log_path)


func log(channel: String, message: String) -> void:
	if not enabled:
		return
	init_session()
	var file := _open_for_append()
	if file == null:
		return
	file.store_line("[%s] [%s] %s" % [_timestamp(), channel, message])
	file.close()


func get_log_path() -> String:
	return ProjectSettings.globalize_path(LOG_DIR.path_join(LOG_FILE))


func _open_for_append() -> FileAccess:
	var log_path := get_log_path()
	var dir_error := DirAccess.make_dir_absolute(log_path.get_base_dir())
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return null
	if not FileAccess.file_exists(log_path):
		var create := FileAccess.open(log_path, FileAccess.WRITE)
		if create != null:
			create.close()
	var file := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if file == null:
		return null
	file.seek_end()
	return file


func _timestamp() -> String:
	return Time.get_time_string_from_system()


func _env_enabled() -> bool:
	return OS.get_cmdline_user_args().has(ENABLE_ARG)
