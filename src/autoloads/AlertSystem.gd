extends Node

signal emission_changed(value: float)
signal alert_changed(value: float)
signal combat_changed(active: bool)

var emission: float = 0.08
var alert_level: float = 0.0
var combat_mode: bool = false


func reset() -> void:
	emission = 0.08
	alert_level = 0.0
	combat_mode = false
	emission_changed.emit(emission)
	alert_changed.emit(alert_level)
	combat_changed.emit(combat_mode)


func set_emission(value: float) -> void:
	var next_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_value, emission):
		return
	emission = next_value
	emission_changed.emit(emission)


func set_alert_level(value: float) -> void:
	var next_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_value, alert_level):
		return
	alert_level = next_value
	alert_changed.emit(alert_level)


func add_alert(amount: float) -> void:
	set_alert_level(alert_level + amount)


func enter_combat() -> void:
	if combat_mode:
		return
	combat_mode = true
	set_alert_level(1.0)
	combat_changed.emit(true)
	ColorSystem.enter_combat()


func exit_combat() -> void:
	if not combat_mode:
		return
	combat_mode = false
	set_alert_level(0.0)
	combat_changed.emit(false)
	ColorSystem.exit_combat()
