extends Node

const RuntimeDebugLog := preload("res://src/debug/RuntimeDebugLog.gd")

const MUSIC_BUS_NAME := "Master"
const SILENT_DB := -80.0
const FADE_SPEED := 3.2

@onready var _title_player: AudioStreamPlayer = $TitlePlayer
@onready var _stealth_player: AudioStreamPlayer = $StealthPlayer
@onready var _search_player: AudioStreamPlayer = $SearchPlayer
@onready var _combat_player: AudioStreamPlayer = $CombatPlayer
var _last_mix_key: String = ""
var _log_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Settings != null and not Settings.settings_changed.is_connected(_apply_bus_settings):
		Settings.settings_changed.connect(_apply_bus_settings)
	_apply_bus_settings()
	_initialize_players()


func _process(delta: float) -> void:
	_ensure_music_playing()
	var target := _target_mix()
	_log_mix_if_changed(target)
	_fade_player(_title_player, _mix_to_db(float(target["title"])), delta)
	_fade_player(_stealth_player, _mix_to_db(float(target["stealth"])), delta)
	_fade_player(_search_player, _mix_to_db(float(target["search"])), delta)
	_fade_player(_combat_player, _mix_to_db(float(target["combat"])), delta)
	_log_timer += delta
	if _log_timer >= 1.0:
		_log_timer = 0.0
		RuntimeDebugLog.log("music", "tick pos=%.2f/%.2f/%.2f/%.2f vol=%.2f/%.2f/%.2f/%.2f playing=%s/%s/%s/%s" % [
			_title_player.get_playback_position(),
			_stealth_player.get_playback_position(),
			_search_player.get_playback_position(),
			_combat_player.get_playback_position(),
			_title_player.volume_db,
			_stealth_player.volume_db,
			_search_player.volume_db,
			_combat_player.volume_db,
			str(_title_player.playing),
			str(_stealth_player.playing),
			str(_search_player.playing),
			str(_combat_player.playing),
		])


func _apply_bus_settings() -> void:
	var master_bus := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	RuntimeDebugLog.log("music", "settings music=%.2f fx=%.2f" % [
		Settings.music_volume if Settings != null else 0.75,
		Settings.fx_volume if Settings != null else 0.85,
	])
	if master_bus >= 0:
		RuntimeDebugLog.log("music", "master bus volume_db=%.2f mute=%s" % [
			AudioServer.get_bus_volume_db(master_bus),
			str(AudioServer.is_bus_mute(master_bus)),
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
	for player in [_title_player, _stealth_player, _search_player, _combat_player]:
		if player.stream is AudioStreamWAV:
			var wav := (player.stream as AudioStreamWAV).duplicate()
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			player.stream = wav
		player.bus = MUSIC_BUS_NAME
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = SILENT_DB
		if player.stream != null:
			player.play()
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


func _ensure_music_playing() -> void:
	for player in [_title_player, _stealth_player, _search_player, _combat_player]:
		if player == null or player.stream == null:
			continue
		if not player.playing:
			player.play()
