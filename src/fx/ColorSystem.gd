extends Node

signal mode_changed(in_combat: bool)

const PHOSPHOR_BRIGHT := Color("4fbf68")
const PHOSPHOR_MID := Color("2e8f45")
const PHOSPHOR_DARK := Color("1c5b2c")
const PHOSPHOR_SHADOW := Color("10351b")
const PHOSPHOR_DEEP := Color("08180d")
const PHOSPHOR_GHOST := Color("78b98a")
const BG_STEALTH := Color("000a02")
const BG_COMBAT := Color("01030a")
const PLAYER_COMBAT := Color("00bfff")
const PLAYER_DARK := Color("1a1022")
const DARK_OUTLINE := Color("7a5cff")
const UI_COMBAT := Color("c8f7ff")

var in_combat: bool = false


func reset() -> void:
	in_combat = false
	mode_changed.emit(in_combat)


func enter_combat() -> void:
	in_combat = true
	mode_changed.emit(true)


func exit_combat() -> void:
	in_combat = false
	mode_changed.emit(false)


func background_color() -> Color:
	return BG_COMBAT if in_combat else BG_STEALTH


func grid_color() -> Color:
	return Color("0f1a31") if in_combat else Color("2a663d")


func haze_color() -> Color:
	return Color("1b4126") if not in_combat else Color("030b16")


func shadow_color() -> Color:
	return Color("000603") if not in_combat else Color("000208")


func glow_color() -> Color:
	return Color("2d7d42") if not in_combat else Color("ff3b1f")


func player_fill(dark_mode: bool) -> Color:
	if dark_mode:
		return Color("030403")
	return Color("090b09") if not in_combat else Color("16181c")


func player_outline(dark_mode: bool) -> Color:
	if dark_mode:
		return Color("1a221c")
	return Color("6d7f73") if not in_combat else Color("d7e8ef")


func enemy_fill(signature_color: Color) -> Color:
	return Color("7a1008") if in_combat else PHOSPHOR_DARK


func enemy_outline() -> Color:
	return Color("ff3b1f") if in_combat else PHOSPHOR_MID


func terrain_fill() -> Color:
	return Color("050910") if in_combat else PHOSPHOR_DEEP


func terrain_outline() -> Color:
	return Color("1f4058") if in_combat else Color("3a8d4f")


func ui_color() -> Color:
	return Color("9ee8f3") if in_combat else PHOSPHOR_BRIGHT
