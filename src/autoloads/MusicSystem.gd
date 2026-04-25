extends Node

const RuntimeDebugLog := preload("res://src/debug/RuntimeDebugLog.gd")

const TITLE_TRACK_PATH := "res://audio/signal_dark_title.wav"
const STEALTH_TRACK_PATH := "res://audio/signal_dark_spy_stealth.wav"
const SEARCH_TRACK_PATH := "res://audio/signal_dark_spy_search.wav"
const COMBAT_TRACK_PATH := "res://audio/signal_dark_spy_combat.wav"
const MUSIC_BUS_NAME := "Master"
const SILENT_DB := -80.0
const FADE_SPEED := 3.2

var _title_player: AudioStreamPlayer
var _stealth_player: AudioStreamPlayer
var _search_player: AudioStreamPlayer
var _combat_player: AudioStreamPlayer
var _last_mix_key: String = ""
var _initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Settings != null and not Settings.settings_changed.is_connected(_apply_bus_settings):
		Settings.settings_changed.connect(_apply_bus_settings)
	_apply_bus_settings()
	_initialize_players.call_deferred()


func _process(delta: float) -> void:
	if not _initialized:
		return
	_ensure_music_playing()
	var target := _target_mix()
	_log_mix_if_changed(target)
	_fade_player(_title_player, _mix_to_db(float(target["title"])), delta)
	_fade_player(_stealth_player, _mix_to_db(float(target["stealth"])), delta)
	_fade_player(_search_player, _mix_to_db(float(target["search"])), delta)
	_fade_player(_combat_player, _mix_to_db(float(target["combat"])), delta)


func _apply_bus_settings() -> void:
	RuntimeDebugLog.log("music", "settings music=%.2f fx=%.2f" % [
		Settings.music_volume if Settings != null else 0.75,
		Settings.fx_volume if Settings != null else 0.85,
	])


func _target_mix() -> Dictionary:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return {"title": 0.0, "stealth": 0.0, "search": 0.0, "combat": 0.0}
	var path := String(current_scene.scene_file_path)
	if path == "res://src/ui/StartScreen.tscn" or path == "res://src/ui/EnemyInfoScreen.tscn":
		return {"title": 0.68, "stealth": 0.0, "search": 0.0, "combat": 0.0}
	if path.begins_with("res://src/world/"):
		var search_mix := 0.0
		var world := GameState.current_world if GameState != null else current_scene
		if world != null and is_instance_valid(world) and world.has_method("is_search_active") and world.is_search_active():
			search_mix = 0.46
		return {
			"title": 0.0,
			"stealth": 0.78,
			"search": search_mix,
			"combat": 0.62 if AlertSystem != null and AlertSystem.combat_mode else 0.0,
		}
	return {"title": 0.0, "stealth": 0.0, "search": 0.0, "combat": 0.0}


func _make_loop_player(track_path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = MUSIC_BUS_NAME
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = SILENT_DB
	var imported_stream: Resource = load(track_path)
	if imported_stream is AudioStream:
		player.stream = _loopable_stream(imported_stream)
		RuntimeDebugLog.log("music", "loaded resource %s" % track_path.get_file())
	else:
		RuntimeDebugLog.log("music", "failed load resource %s" % track_path.get_file())
	return player


func _fade_player(player: AudioStreamPlayer, target_db: float, delta: float) -> void:
	if player == null:
		return
	var settings_db := _music_settings_db()
	var mixed_target := SILENT_DB if target_db <= SILENT_DB + 0.1 else target_db + settings_db
	player.volume_db = lerpf(player.volume_db, mixed_target, clampf(delta * FADE_SPEED, 0.0, 1.0))


func _mix_to_db(value: float) -> float:
	if value <= 0.001:
		return SILENT_DB
	return linear_to_db(value)


func _log_mix_if_changed(target: Dictionary) -> void:
	var key := "title=%.2f s=%.2f search=%.2f c=%.2f" % [float(target["title"]), float(target["stealth"]), float(target["search"]), float(target["combat"])]
	if key == _last_mix_key:
		return
	_last_mix_key = key
	RuntimeDebugLog.log("music", "mix %s" % key)


func _initialize_players() -> void:
	if _initialized:
		return
	_title_player = _make_loop_player(TITLE_TRACK_PATH)
	_stealth_player = _make_loop_player(STEALTH_TRACK_PATH)
	_search_player = _make_loop_player(SEARCH_TRACK_PATH)
	_combat_player = _make_loop_player(COMBAT_TRACK_PATH)
	add_child(_title_player)
	add_child(_stealth_player)
	add_child(_search_player)
	add_child(_combat_player)
	if _title_player.stream != null:
		_title_player.play()
	if _stealth_player.stream != null:
		_stealth_player.play()
	if _search_player.stream != null:
		_search_player.play()
	if _combat_player.stream != null:
		_combat_player.play()
	_initialized = true
	RuntimeDebugLog.log("music", "ready title_stream=%s stealth_stream=%s search_stream=%s combat_stream=%s playing=%s/%s/%s/%s" % [
		str(_title_player.stream != null),
		str(_stealth_player.stream != null),
		str(_search_player.stream != null),
		str(_combat_player.stream != null),
		str(_title_player.playing),
		str(_stealth_player.playing),
		str(_search_player.playing),
		str(_combat_player.playing),
	])


func _music_settings_db() -> float:
	var value := Settings.music_volume if Settings != null else 0.75
	value = clampf(value, 0.0, 1.0)
	return SILENT_DB if value <= 0.001 else linear_to_db(value)


func _loopable_stream(stream: Resource) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = (stream as AudioStreamWAV).duplicate()
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return wav
	return stream as AudioStream


func _ensure_music_playing() -> void:
	for player in [_title_player, _stealth_player, _search_player, _combat_player]:
		if player == null or player.stream == null:
			continue
		if not player.playing:
			player.play()
