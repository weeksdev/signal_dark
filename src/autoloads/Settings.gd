extends Node

signal auto_fire_changed(active: bool)
signal music_volume_changed(value: float)
signal fx_volume_changed(value: float)
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "gameplay"
const KEY_AUTO_FIRE_MODE := "auto_fire_mode"
const KEY_MUSIC_VOLUME := "music_volume"
const KEY_FX_VOLUME := "fx_volume"

const AUTO_FIRE_MODE_AUTO := -1
const AUTO_FIRE_MODE_OFF := 0
const AUTO_FIRE_MODE_ON := 1
const VOLUME_STEP := 0.1

var auto_fire_mode: int = AUTO_FIRE_MODE_AUTO
var music_volume: float = 0.75
var fx_volume: float = 0.85


func _ready() -> void:
	_load()
	if InputManager != null and not InputManager.controller_layout_changed.is_connected(_on_controller_layout_changed):
		InputManager.controller_layout_changed.connect(_on_controller_layout_changed)


func set_auto_fire_mode(mode: int) -> void:
	mode = clampi(mode, AUTO_FIRE_MODE_AUTO, AUTO_FIRE_MODE_ON)
	if auto_fire_mode == mode:
		return
	auto_fire_mode = mode
	_save()
	auto_fire_changed.emit(is_auto_fire_enabled())
	settings_changed.emit()


func cycle_auto_fire_mode(direction: int = 1) -> void:
	var modes := [AUTO_FIRE_MODE_AUTO, AUTO_FIRE_MODE_OFF, AUTO_FIRE_MODE_ON]
	var current_index := modes.find(auto_fire_mode)
	if current_index == -1:
		current_index = 0
	var next_index := posmod(current_index + direction, modes.size())
	set_auto_fire_mode(modes[next_index])


func set_music_volume(value: float) -> void:
	value = snappedf(clampf(value, 0.0, 1.0), 0.01)
	if is_equal_approx(music_volume, value):
		return
	music_volume = value
	_save()
	music_volume_changed.emit(music_volume)
	settings_changed.emit()


func adjust_music_volume(direction: int) -> void:
	set_music_volume(music_volume + float(direction) * VOLUME_STEP)


func set_fx_volume(value: float) -> void:
	value = snappedf(clampf(value, 0.0, 1.0), 0.01)
	if is_equal_approx(fx_volume, value):
		return
	fx_volume = value
	_save()
	fx_volume_changed.emit(fx_volume)
	settings_changed.emit()


func adjust_fx_volume(direction: int) -> void:
	set_fx_volume(fx_volume + float(direction) * VOLUME_STEP)


func is_auto_fire_enabled() -> bool:
	match auto_fire_mode:
		AUTO_FIRE_MODE_OFF:
			return false
		AUTO_FIRE_MODE_ON:
			return true
		_:
			return InputManager != null and InputManager.has_controller()


func get_auto_fire_label() -> String:
	match auto_fire_mode:
		AUTO_FIRE_MODE_OFF:
			return "OFF"
		AUTO_FIRE_MODE_ON:
			return "ON"
		_:
			return "AUTO"


func get_auto_fire_summary() -> String:
	var effective := "ON" if is_auto_fire_enabled() else "OFF"
	if auto_fire_mode == AUTO_FIRE_MODE_AUTO:
		return "AUTO (%s)" % effective
	return get_auto_fire_label()


func get_music_volume_summary() -> String:
	return "%d%%" % int(round(music_volume * 100.0))


func get_fx_volume_summary() -> String:
	return "%d%%" % int(round(fx_volume * 100.0))


func _load() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		return
	auto_fire_mode = int(config.get_value(SECTION, KEY_AUTO_FIRE_MODE, AUTO_FIRE_MODE_AUTO))
	music_volume = float(config.get_value(SECTION, KEY_MUSIC_VOLUME, 0.75))
	fx_volume = float(config.get_value(SECTION, KEY_FX_VOLUME, 0.85))


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY_AUTO_FIRE_MODE, auto_fire_mode)
	config.set_value(SECTION, KEY_MUSIC_VOLUME, music_volume)
	config.set_value(SECTION, KEY_FX_VOLUME, fx_volume)
	config.save(SETTINGS_PATH)


func _on_controller_layout_changed(_using_controller: bool) -> void:
	if auto_fire_mode == AUTO_FIRE_MODE_AUTO:
		auto_fire_changed.emit(is_auto_fire_enabled())
		settings_changed.emit()
