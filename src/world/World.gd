extends Node2D

const HUNTER_SCENE := preload("res://src/enemies/Hunter.tscn")
const WISP_SCENE := preload("res://src/enemies/Wisp.tscn")
const PRISM_SCENE := preload("res://src/enemies/Prism.tscn")
const RuntimeDebugLog := preload("res://src/debug/RuntimeDebugLog.gd")
const ObjectiveNode := preload("res://src/world/ObjectiveNode.gd")
const SearchRelayBurst := preload("res://src/fx/SearchRelayBurst.gd")
const PauseOverlayScene := preload("res://src/ui/PauseOverlay.gd")
const ArcadeSummaryOverlayScene := preload("res://src/ui/ArcadeRunSummaryOverlay.gd")
const ALERT_SPOTTED_SFX_PATH := "res://audio/sfx_alert_spotted.wav"
const PLAYER_FIRE_SFX_PATHS := [
	"res://audio/ship_fire_1.wav",
	"res://audio/ship_fire_2.wav",
]
const GUN_PULSE_SFX_PATH := "res://audio/sfx_gun_pulse.wav"
const MUSIC_FLIP_SFX_PATH := "res://audio/sfx_music_flip.wav"
const ENEMY_EXPLOSION_SFX_PATHS := [
	"res://audio/enemy_explosion_a.wav",
	"res://audio/enemy_explosion_b.wav",
]
const ENEMY_EXPLOSION_START_OFFSETS := {
	"res://audio/enemy_explosion_a.wav": 0.0032,
	"res://audio/enemy_explosion_b.wav": 0.1205,
}
const ENEMY_EXPLOSION_SEMITONE_LOOP := [0, 3, -3, 2, -2, 1, -1]

@onready var ship = $Ship
@onready var hud = $CanvasLayer/HUD
@onready var game_over_overlay = $CanvasLayer/GameOverOverlay
@onready var zone_complete_overlay = $CanvasLayer/ZoneCompleteOverlay
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var grid: Node2D = $Grid
@onready var music_stealth_player: AudioStreamPlayer = get_node_or_null("MusicStealth")
@onready var music_search_player: AudioStreamPlayer = get_node_or_null("MusicSearch")
@onready var music_combat_player: AudioStreamPlayer = get_node_or_null("MusicCombat")

var enemies: Array[Node] = []
var probe_target: Vector2 = Vector2.ZERO
var probe_expire_time: float = 0.0
var restarting: bool = false
var completing: bool = false
var combat_cooldown_remaining: float = 0.0
var _kill_count: int = 0
var _caution_active: bool = false
var _caution_timer: float = 0.0
var _caution_enemy: Node = null
var _reinforcements_spawned: bool = false
var _active_dark_pockets: Dictionary = {}
var _defeated_enemy_snapshots: Array[Dictionary] = []
var _hack_target: Node2D = null
var _hack_sequence: Array = []
var _hack_index: int = 0
var _hack_wrong_flash: bool = false
var _gate_hack_sequences: Dictionary = {}
var _search_position: Vector2 = Vector2.ZERO
var _search_timer: float = 0.0
var _search_reason: String = ""
var _search_points: Array[Vector2] = []
var _search_phase: int = 0
var _search_phase_timer: float = 0.0
var _last_known_player_position: Vector2 = Vector2.ZERO
var _jammer_position: Vector2 = Vector2.ZERO
var _jammer_radius: float = 0.0
var _jammer_timer: float = 0.0
var _objective_nodes: Array[ObjectiveNode] = []
var _objective_required: int = 0
var _objective_progress: int = 0
var _objective_type: String = ""
var _interaction_text: String = ""
var _alert_count: int = 0
var _combat_heat: float = 0.0
var _combat_reinforcement_budget: float = 0.0
var _combat_reinforcement_timer: float = 0.0
var _combat_dynamic_spawn_count: int = 0
var _combat_baseline_enemy_count: int = 0
var _combat_respawn_pool: Array[Dictionary] = []
var _combat_lockdown_level: int = 0
var _combat_locked_gate_ids: Array[int] = []
var _combat_progress_locked: bool = false
var _stealth_reentry_timer: float = 0.0
var _pause_overlay: Control = null
var _patrol_recovery_claims: Dictionary = {}
var _pending_patrol_reentries: Array[Dictionary] = []
var _arcade_summary_overlay: Control = null
var _suppressed_kill_count: int = 0
var _hacks_completed: int = 0
var _probes_used: int = 0
var _arcade_result_recorded: bool = false
var _floor_started_msec: int = 0
var _active_music_mode: StringName = &""
var _music_transition_from: StringName = &""
var _sfx_cache: Dictionary = {}
var _music_resume_positions: Dictionary = {}
var _player_fire_sfx_index: int = 0
var _enemy_explosion_sfx_index: int = 0
var _enemy_explosion_pitch_index: int = 0

const COMBAT_LOSE_CONTACT_SECONDS := 4.0
const THREAT_DISTANCE := 420.0
const CAUTION_DURATION := 1.8
const SEARCH_DURATION := 7.5
const SEARCH_PHASE_DURATION := 1.05
const JAMMER_ALERT_REDUCTION := 0.28
const SEARCH_SUPPORT_RADIUS := 460.0
const SEARCH_SUPPORT_RECEIVE_TIME := 0.9
const SEARCH_SUPPORT_DELAY := 0.55
const SEARCH_SUPPORT_DURATION := 3.0
const COMBAT_HEAT_PER_SECOND := 0.08
const COMBAT_HEAT_PER_KILL := 0.34
const COMBAT_HEAT_PER_DETECTION := 0.18
const COMBAT_REINFORCEMENT_BUDGET_PER_SECOND := 0.22
const COMBAT_REINFORCEMENT_BUDGET_PER_KILL := 0.95
const COMBAT_REINFORCEMENT_BUDGET_CAP := 10.0
const COMBAT_REINFORCEMENT_MIN_DISTANCE := 220.0
const COMBAT_REINFORCEMENT_MAX_DISTANCE := 1280.0
const COMBAT_REINFORCEMENT_BLOCKED_BONUS := 240.0
const COMBAT_REINFORCEMENT_RETRY_TIME := 1.1
const COMBAT_REINFORCEMENT_INTERVAL_HIGH := 2.6
const COMBAT_REINFORCEMENT_INTERVAL_LOW := 1.45
const COMBAT_REINFORCEMENT_IMMEDIATE_KILL_DELAY := 0.35
const COMBAT_REINFORCEMENT_RECOVERY_DELAY := 0.16
const COMBAT_REINFORCEMENT_MIN_ACTIVE := 4
const COMBAT_REINFORCEMENT_MAX_ACTIVE := 7
const COMBAT_LOCKDOWN_LEVEL_ONE_HEAT := 0.56
const COMBAT_LOCKDOWN_LEVEL_TWO_HEAT := 0.86
const COMBAT_LOCKDOWN_GOAL_EXCLUSION := 170.0
const COMBAT_LOCKDOWN_POCKET_EXCLUSION := 190.0
const COMBAT_LOCKDOWN_PLAYER_EXCLUSION := 150.0
const PATROL_RECOVERY_SLOT_RADIUS := 44.0
const PATROL_REENTRY_DELAY := 1.1
const PATROL_REENTRY_PLAYER_CLEAR := 260.0
const STEALTH_REENTRY_DURATION := 1.0
const STEALTH_REENTRY_HIDDEN_DURATION := 1.45
const STEALTH_REENTRY_DETECTION_CLEAR_DISTANCE := 185.0
const STEALTH_REENTRY_ALERT_DECAY := 0.65
const MUSIC_CROSSFADE_SPEED := 5.0
const MUSIC_START_OFFSETS := {
	&"stealth": 0.0175,
	&"search": 0.0175,
	&"combat": 0.005,
}


func _ready() -> void:
	RuntimeDebugLog.init_session()
	GameState.register_world(self)
	AlertSystem.reset()
	ColorSystem.reset()
	GameState.enforce_desktop_window_size()
	restarting = false
	completing = false
	_floor_started_msec = Time.get_ticks_msec()
	ship.destroyed.connect(_on_ship_destroyed)
	_configure_camera()
	enemies = get_tree().get_nodes_in_group("zone_enemy")
	for enemy in enemies:
		enemy.detected.connect(_on_enemy_detected)
		if enemy.has_signal("suspicious"):
			enemy.suspicious.connect(_on_enemy_suspicious)
		enemy.killed.connect(_on_enemy_killed)
	var exit := get_node_or_null("ExitZone")
	if exit:
		exit.player_reached.connect(_on_exit_reached)
	_refresh_gate_hack_previews()
	_ensure_pause_overlay()
	_ensure_arcade_summary_overlay()
	_setup_scene_music()


func _process(delta: float) -> void:
	if InputManager.is_restart_just_pressed() and not completing:
		GameState.restart_zone()
	if probe_expire_time > 0.0 and _now() >= probe_expire_time:
		probe_expire_time = 0.0
	if AlertSystem.combat_mode and not restarting:
		_update_combat_cooldown(delta)
	if _caution_active and not AlertSystem.combat_mode:
		_update_caution(delta)
	_update_search(delta)
	_update_stealth_reentry(delta)
	_update_jammer(delta)
	_update_objectives(delta)
	_update_patrol_reentries(delta)
	_update_scene_music(delta)


func _exit_tree() -> void:
	_persist_arcade_music_resume_positions()
	if Settings != null and Settings.settings_changed.is_connected(_on_music_settings_changed):
		Settings.settings_changed.disconnect(_on_music_settings_changed)


func _setup_scene_music() -> void:
	_restore_arcade_music_resume_positions()
	for player in [music_stealth_player, music_search_player, music_combat_player]:
		if player == null:
			continue
		player.bus = "Master"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = -80.0
		player.stop()
	RuntimeDebugLog.log("music", "scene music setup stealth=%s search=%s combat=%s" % [
		str(music_stealth_player != null and music_stealth_player.stream != null),
		str(music_search_player != null and music_search_player.stream != null),
		str(music_combat_player != null and music_combat_player.stream != null),
	])
	if Settings != null and not Settings.settings_changed.is_connected(_on_music_settings_changed):
		Settings.settings_changed.connect(_on_music_settings_changed)
	_sync_scene_music_mode()


func _update_scene_music(delta: float) -> void:
	if music_stealth_player == null:
		return
	_sync_scene_music_mode(delta)


func _desired_music_mode() -> StringName:
	if AlertSystem.combat_mode:
		return &"combat"
	return &"stealth"


func _music_target_db() -> float:
	var volume := Settings.music_volume if Settings != null else 0.75
	volume = clampf(volume, 0.0, 1.0)
	if volume <= 0.001:
		return -80.0
	return linear_to_db(volume)


func _sync_scene_music_mode(delta: float = 1.0) -> void:
	var desired_mode := _desired_music_mode()
	var target_db := _music_target_db()
	if desired_mode != _active_music_mode:
		_music_transition_from = _active_music_mode
		_store_music_resume_position(_music_transition_from)
		_active_music_mode = desired_mode
		if _music_transition_from != &"":
			play_music_transition_sfx()
		RuntimeDebugLog.log("music", "scene mode=%s" % String(desired_mode))
	var fade_weight := clampf(delta * MUSIC_CROSSFADE_SPEED, 0.0, 1.0)
	for mode in [&"stealth", &"search", &"combat"]:
		var player := _music_player_for_mode(mode)
		if player == null:
			continue
		if mode == _active_music_mode:
			if not player.playing:
				player.play()
				player.seek(_music_resume_position_for_mode(mode))
			player.volume_db = lerpf(player.volume_db, target_db, fade_weight)
		elif mode == _music_transition_from:
			if not player.playing:
				player.play()
				player.seek(_music_resume_position_for_mode(mode))
			player.volume_db = lerpf(player.volume_db, -80.0, fade_weight)
			if player.volume_db <= -70.0:
				_store_music_resume_position(mode)
				player.stop()
				player.volume_db = -80.0
				if mode == _music_transition_from:
					_music_transition_from = &""
		else:
			_store_music_resume_position(mode)
			player.stop()
			player.volume_db = -80.0


func _music_player_for_mode(mode: StringName) -> AudioStreamPlayer:
	match mode:
		&"combat":
			return music_combat_player
		&"search":
			return music_search_player
		_:
			return music_stealth_player


func _music_start_offset_for_mode(mode: StringName) -> float:
	return float(MUSIC_START_OFFSETS.get(mode, 0.0))


func _music_resume_position_for_mode(mode: StringName) -> float:
	return float(_music_resume_positions.get(mode, _music_start_offset_for_mode(mode)))


func _store_music_resume_position(mode: StringName) -> void:
	if mode == &"":
		return
	var player := _music_player_for_mode(mode)
	if player == null or not player.playing:
		return
	var start_offset := _music_start_offset_for_mode(mode)
	var position := maxf(player.get_playback_position(), start_offset)
	_music_resume_positions[mode] = position
	if ArcadeState.is_active:
		ArcadeState.set_music_resume_position(mode, position)


func _restore_arcade_music_resume_positions() -> void:
	if not ArcadeState.is_active:
		return
	for mode in [&"stealth", &"search", &"combat"]:
		_music_resume_positions[mode] = ArcadeState.get_music_resume_position(mode, _music_start_offset_for_mode(mode))


func _persist_arcade_music_resume_positions() -> void:
	if not ArcadeState.is_active:
		return
	for mode in [&"stealth", &"search", &"combat"]:
		_store_music_resume_position(mode)


func _fx_target_db(scale: float = 1.0) -> float:
	var volume := Settings.fx_volume if Settings != null else 0.85
	volume = clampf(volume * scale, 0.0, 1.0)
	if volume <= 0.001:
		return -80.0
	return linear_to_db(volume)


func _play_one_shot_sfx(stream: AudioStream, volume_scale: float = 1.0, pitch_scale: float = 1.0, start_offset: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Master"
	player.volume_db = _fx_target_db(volume_scale)
	player.pitch_scale = pitch_scale
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play(start_offset)


func play_spotted_sfx(_world_position: Vector2 = Vector2.ZERO) -> void:
	_play_one_shot_sfx(_load_sfx(ALERT_SPOTTED_SFX_PATH), 0.95, randf_range(0.98, 1.02))


func play_music_transition_sfx() -> void:
	_play_one_shot_sfx(_load_sfx(MUSIC_FLIP_SFX_PATH), 0.62, randf_range(0.98, 1.03))


func play_player_fire_sfx(_world_position: Vector2 = Vector2.ZERO) -> void:
	if PLAYER_FIRE_SFX_PATHS.is_empty():
		_play_one_shot_sfx(_load_sfx(GUN_PULSE_SFX_PATH), 0.42, randf_range(1.03, 1.08))
		return
	var path: String = PLAYER_FIRE_SFX_PATHS[_player_fire_sfx_index % PLAYER_FIRE_SFX_PATHS.size()]
	_player_fire_sfx_index += 1
	_play_one_shot_sfx(_load_sfx(path), 0.72, randf_range(0.98, 1.03))


func play_enemy_fire_sfx(_world_position: Vector2 = Vector2.ZERO) -> void:
	_play_one_shot_sfx(_load_sfx(GUN_PULSE_SFX_PATH), 0.34, randf_range(0.88, 0.96))


func play_enemy_explosion_sfx(_world_position: Vector2 = Vector2.ZERO, silent: bool = false) -> void:
	if ENEMY_EXPLOSION_SFX_PATHS.is_empty():
		return
	var path: String = ENEMY_EXPLOSION_SFX_PATHS[_enemy_explosion_sfx_index % ENEMY_EXPLOSION_SFX_PATHS.size()]
	_enemy_explosion_sfx_index += 1
	var semitone: int = ENEMY_EXPLOSION_SEMITONE_LOOP[_enemy_explosion_pitch_index % ENEMY_EXPLOSION_SEMITONE_LOOP.size()]
	_enemy_explosion_pitch_index += 1
	var pitch_scale := pow(2.0, float(semitone) / 12.0)
	var volume_scale := 0.52 if silent else 0.68
	var start_offset := float(ENEMY_EXPLOSION_START_OFFSETS.get(path, 0.0))
	_play_one_shot_sfx(_load_sfx(path), volume_scale, pitch_scale, start_offset)


func _load_sfx(path: String) -> AudioStream:
	if _sfx_cache.has(path):
		return _sfx_cache[path]
	var stream := load(path) as AudioStream
	_sfx_cache[path] = stream
	return stream


func _on_music_settings_changed() -> void:
	if music_stealth_player == null:
		return
	_active_music_mode = &""
	_music_transition_from = &""
	_music_resume_positions.clear()
	_sync_scene_music_mode(1.0 / MUSIC_CROSSFADE_SPEED)


func _update_caution(delta: float) -> void:
	if ship.in_dark_pocket:
		_cancel_caution()
		return
	# Cancel if the detecting enemy died or lost sight of the player
	if not is_instance_valid(_caution_enemy) or not _caution_enemy.is_alive:
		_cancel_caution()
		return
	if _caution_enemy.has_method("is_alerting_state"):
		if not _caution_enemy.is_alerting_state():
			_cancel_caution()
			return
	elif not _caution_enemy._alerting:
		_cancel_caution()
		return
	_caution_timer -= delta
	if _caution_timer <= 0.0:
		_cancel_caution()
		trigger_alert()


func _cancel_caution() -> void:
	_caution_active = false
	_caution_timer = 0.0
	_caution_enemy = null


func _on_enemy_detected(enemy: Node) -> void:
	RuntimeDebugLog.log("detect", "%s detected player at ship=(%.1f, %.1f)" % [enemy.name, ship.global_position.x, ship.global_position.y])
	_last_known_player_position = ship.global_position
	start_search(ship.global_position, SEARCH_DURATION * 0.55, "SEARCH: CONTACT")
	_log_system_state("enemy_detected:%s" % enemy.name)
	if ship.in_dark_pocket:
		_cancel_caution()
		return
	if AlertSystem.combat_mode:
		_combat_heat = minf(1.0, _combat_heat + COMBAT_HEAT_PER_DETECTION)
		combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
		return
	if _caution_active:
		# Spotted again during caution window → straight to combat
		_cancel_caution()
		trigger_alert()
		return
	# First detection → caution window (player can escape before full alert)
	_caution_active = true
	_caution_timer = CAUTION_DURATION
	_caution_enemy = enemy
	AlertSystem.set_alert_level(maxf(AlertSystem.alert_level, 0.42))
	play_spotted_sfx(enemy.global_position)
	_maybe_request_search_support(enemy, ship.global_position)


func _on_enemy_suspicious(enemy: Node) -> void:
	if ship == null or ship.in_dark_pocket:
		RuntimeDebugLog.log("suspicion", "%s suspicious ignored; ship hidden or missing" % enemy.name)
		return
	RuntimeDebugLog.log("suspicion", "%s triggered suspicion support flow at ship=(%.1f, %.1f)" % [enemy.name, ship.global_position.x, ship.global_position.y])
	play_spotted_sfx(enemy.global_position)
	_last_known_player_position = ship.global_position
	start_search(ship.global_position, SEARCH_DURATION * 0.4, "SEARCH: SUSPICION")
	AlertSystem.set_alert_level(maxf(AlertSystem.alert_level, 0.18))
	_log_system_state("enemy_suspicious:%s" % enemy.name)
	if not _maybe_request_search_support(enemy, ship.global_position):
		RuntimeDebugLog.log("support", "%s had no helper; spawning local burst only" % enemy.name)
		_spawn_search_relay_fx(enemy.global_position, enemy.global_position)


func _on_enemy_killed(enemy: Node, silent: bool) -> void:
	var snapshot := _snapshot_enemy(enemy)
	if not snapshot.is_empty():
		_defeated_enemy_snapshots.append(snapshot)
		if AlertSystem.combat_mode:
			_combat_respawn_pool.append(snapshot.duplicate(true))
	play_enemy_explosion_sfx(enemy.global_position, silent)
	_kill_count += 1
	if _caution_enemy == enemy:
		_cancel_caution()
	if not silent and not AlertSystem.combat_mode:
		trigger_alert()
	elif AlertSystem.combat_mode:
		_combat_heat = minf(1.0, _combat_heat + COMBAT_HEAT_PER_KILL)
		_combat_reinforcement_budget = minf(COMBAT_REINFORCEMENT_BUDGET_CAP, _combat_reinforcement_budget + COMBAT_REINFORCEMENT_BUDGET_PER_KILL)
		_combat_reinforcement_timer = minf(_combat_reinforcement_timer, COMBAT_REINFORCEMENT_IMMEDIATE_KILL_DELAY)
		RuntimeDebugLog.log("combat", "kill raised heat=%.2f budget=%.2f pool=%d" % [_combat_heat, _combat_reinforcement_budget, _combat_respawn_pool.size()])
	if silent:
		_suppressed_kill_count += 1
	if _living_enemy_count() == 0:
		_exit_combat_to_stealth()


func _on_exit_reached() -> void:
	if completing or restarting:
		return
	if _objective_required > 0 and _objective_progress < _objective_required:
		_interaction_text = "EXIT LOCKED  //  %s" % get_hud_objective_text()
		start_search(ship.global_position, SEARCH_DURATION * 0.45, "SEARCH: EXIT LOCK")
		return
	completing = true
	get_tree().paused = false
	if ArcadeState.is_active:
		_record_arcade_floor_result(true)
		_show_arcade_run_summary(ArcadeState.is_final_floor(), true)
		return
	zone_complete_overlay.trigger(_kill_count == 0)


func _on_ship_destroyed() -> void:
	if restarting or completing:
		return
	restarting = true
	get_tree().paused = false
	if ArcadeState.is_active:
		_record_arcade_floor_result(false)
		_show_arcade_run_summary(false)
		return
	game_over_overlay.trigger()


func can_pause_game() -> bool:
	return not restarting and not completing


func _ensure_pause_overlay() -> void:
	if canvas_layer == null or _pause_overlay != null:
		return
	_pause_overlay = PauseOverlayScene.new()
	canvas_layer.add_child(_pause_overlay)
	if _pause_overlay.has_method("setup"):
		_pause_overlay.setup(self)


func _ensure_arcade_summary_overlay() -> void:
	if canvas_layer == null or _arcade_summary_overlay != null:
		return
	_arcade_summary_overlay = ArcadeSummaryOverlayScene.new()
	canvas_layer.add_child(_arcade_summary_overlay)


func trigger_alert() -> void:
	_alert_count += 1
	_last_known_player_position = ship.global_position
	start_search(ship.global_position, SEARCH_DURATION * 1.35, "SEARCH: ALERT")
	_log_system_state("trigger_alert:start")
	if AlertSystem.combat_mode:
		combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
		return
	AlertSystem.enter_combat()
	_begin_combat_pressure()
	_spawn_reinforcements_for_alert()
	combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.activate_for_combat(ship)
	_log_system_state("trigger_alert:combat_entered")


func register_spawned_enemy(enemy: Node) -> void:
	add_child(enemy)
	enemies.append(enemy)
	if enemy.has_signal("detected"):
		enemy.detected.connect(_on_enemy_detected)
	if enemy.has_signal("suspicious"):
		enemy.suspicious.connect(_on_enemy_suspicious)
	if enemy.has_signal("killed"):
		enemy.killed.connect(_on_enemy_killed)
	if AlertSystem.combat_mode and enemy.has_method("activate_for_combat"):
		enemy.activate_for_combat(ship)


func _register_combat_temporary_enemy(enemy: Node) -> void:
	if enemy != null and is_instance_valid(enemy):
		enemy.set_meta("combat_temporary", true)


func _clear_enemy_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()


func _maybe_request_search_support(source_enemy: Node, target_position: Vector2) -> bool:
	if source_enemy == null or not is_instance_valid(source_enemy):
		RuntimeDebugLog.log("support", "source enemy invalid for support request")
		return false
	if AlertSystem.combat_mode or ship.in_dark_pocket:
		RuntimeDebugLog.log("support", "%s support request suppressed by combat/hidden state" % source_enemy.name)
		return false
	var candidates: Array[Node] = []
	for enemy in enemies:
		if enemy == source_enemy or not is_instance_valid(enemy):
			continue
		if not enemy.is_alive:
			continue
		if enemy.global_position.distance_to(source_enemy.global_position) > SEARCH_SUPPORT_RADIUS:
			continue
		if enemy.has_method("can_receive_search_support") and not enemy.can_receive_search_support():
			continue
		candidates.append(enemy)
	if candidates.is_empty():
		RuntimeDebugLog.log("support", "%s found zero helpers within %.1f" % [source_enemy.name, SEARCH_SUPPORT_RADIUS])
		return false
	var helper: Node = candidates[randi() % candidates.size()]
	RuntimeDebugLog.log("support", "%s selected helper %s from %d candidates" % [source_enemy.name, helper.name, candidates.size()])
	if helper.has_method("receive_search_support") and helper.receive_search_support(target_position, SEARCH_SUPPORT_RECEIVE_TIME, SEARCH_SUPPORT_DELAY, SEARCH_SUPPORT_DURATION):
		_spawn_search_relay_fx(source_enemy.global_position, helper.global_position)
		return true
	RuntimeDebugLog.log("support", "%s helper %s failed receive_search_support" % [source_enemy.name, helper.name])
	return false

func _spawn_search_relay_fx(from_point: Vector2, to_point: Vector2) -> void:
	var burst: Node2D = SearchRelayBurst.new()
	burst.from_point = from_point
	burst.to_point = to_point
	RuntimeDebugLog.log("fx", "spawn relay burst from=(%.1f, %.1f) to=(%.1f, %.1f)" % [from_point.x, from_point.y, to_point.x, to_point.y])
	add_child(burst)


func register_probe(position: Vector2, duration: float) -> void:
	probe_target = position
	probe_expire_time = _now() + duration
	_probes_used += 1
	start_search(position, duration, "SEARCH: PROBE")


func has_active_probe() -> bool:
	return probe_expire_time > _now()


func get_probe_target() -> Vector2:
	return probe_target


func is_line_blocked(from_point: Vector2, to_point: Vector2, exclusions := []) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from_point, to_point)
	query.collision_mask = 4
	query.exclude = exclusions
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func set_player_dark_pocket_state(pocket: Area2D, active: bool) -> void:
	if active:
		_active_dark_pockets[pocket.get_instance_id()] = pocket
		_relax_enemies_for_hiding()
	else:
		_active_dark_pockets.erase(pocket.get_instance_id())
	ship.in_dark_pocket = not _active_dark_pockets.is_empty()
	_refresh_dark_pocket_gates()


func update_gate_hacking(ship_node: Node2D, _delta: float) -> Dictionary:
	_interaction_text = ""
	var objective := _nearest_objective(ship_node)
	if objective != null and _combat_progress_locked and objective.can_be_triggered_by(ship_node):
		_interaction_text = "REDLINE  //  LOSE CONTACT"
	elif objective != null and objective.can_be_triggered_by(ship_node):
		objective.complete()
		_interaction_text = "%s LINKED" % objective.objective_name
		start_search(objective.global_position, SEARCH_DURATION * 0.35, "SEARCH: OBJECTIVE")

	var gate := _find_nearest_hack_gate(ship_node)
	if gate == null:
		_reset_hack_state()
		_refresh_gate_hack_previews()
		return {
			"visible": false,
			"sequence": [],
			"current_index": 0,
			"wrong_flash": false,
		}

	if gate != _hack_target:
		_hack_target = gate
		_hack_sequence = _ensure_gate_hack_sequence(gate)
		_hack_index = 0

	_hack_wrong_flash = false
	var pressed := InputManager.get_hack_button_just_pressed()
	if pressed != "":
		if pressed == _hack_sequence[_hack_index]:
			_hack_index += 1
		else:
			_hack_index = 0
			_hack_wrong_flash = true
			start_search(gate.global_position, SEARCH_DURATION * 0.4, "SEARCH: BAD HACK")
			AlertSystem.add_alert(0.12)

		if _hack_index >= _hack_sequence.size():
			gate.set_hacked_open(true)
			_hacks_completed += 1
			_respawn_defeated_enemies()
			var success_pos := gate.global_position + Vector2(0.0, -54.0)
			_gate_hack_sequences.erase(gate.get_instance_id())
			_reset_hack_state()
			_refresh_gate_hack_previews()
			return {
				"visible": true,
				"world_pos": success_pos,
				"sequence": ["O", "P", "E", "N"],
				"current_index": 4,
				"wrong_flash": false,
			}

	_refresh_gate_hack_previews()
	return {
		"visible": true,
		"world_pos": gate.global_position + Vector2(0.0, -54.0),
		"sequence": _hack_sequence,
		"current_index": _hack_index,
		"wrong_flash": _hack_wrong_flash,
	}


func _reset_hack_state() -> void:
	_hack_target = null
	_hack_sequence.clear()
	_hack_index = 0
	_hack_wrong_flash = false


func _make_hack_sequence() -> Array:
	var buttons := ["A", "B", "X", "Y"]
	var length := 3 if ArcadeState.floor_index <= 1 else 4
	var sequence: Array = []
	for _i in range(length):
		sequence.append(buttons[randi() % buttons.size()])
	return sequence


func _ensure_gate_hack_sequence(gate: Node2D) -> Array:
	if gate == null:
		return []
	var gate_id := gate.get_instance_id()
	if not _gate_hack_sequences.has(gate_id):
		_gate_hack_sequences[gate_id] = _make_hack_sequence()
	return (_gate_hack_sequences[gate_id] as Array).duplicate()


func _refresh_gate_hack_previews() -> void:
	for child in get_children():
		if child == null or not child.has_method("set_hack_preview"):
			continue
		if child.has_method("is_lockdown_candidate") and child.is_lockdown_candidate():
			child.set_hack_preview([], 0, false)
			continue
		if not child.has_method("is_open") or child.is_open():
			child.set_hack_preview([], 0, false)
			continue
		var sequence := _ensure_gate_hack_sequence(child)
		var progress := 0
		var wrong_flash := false
		if child == _hack_target:
			progress = _hack_index
			wrong_flash = _hack_wrong_flash
		child.set_hack_preview(sequence, progress, wrong_flash)


func get_hud_objective_text() -> String:
	if _objective_required <= 0:
		if is_search_active():
			return _search_reason
		return ""
	var prefix := "FIND %s NODE" % _objective_type
	var progress := "%d/%d" % [_objective_progress, _objective_required]
	if is_search_active():
		return "%s  %s  //  %s" % [prefix, progress, _search_reason]
	return "%s  %s" % [prefix, progress]


func get_hud_interaction_text() -> String:
	return _interaction_text


func get_hud_combat_state_text() -> String:
	if ship != null and ship.in_dark_pocket:
		if AlertSystem.combat_mode:
			return "HIDDEN  //  COOLING %.1fs" % maxf(combat_cooldown_remaining, 0.0)
		if _stealth_reentry_timer > 0.0:
			return "HIDDEN  //  RESET %.1fs" % _stealth_reentry_timer
		if _caution_active:
			return "HIDDEN  //  SAFE"
	if _caution_active:
		return "CAUTION  %.1fs" % maxf(_caution_timer, 0.0)
	if not AlertSystem.combat_mode:
		if _stealth_reentry_timer > 0.0:
			return "STEALTH WINDOW  %.1fs" % _stealth_reentry_timer
		return ""
	var lockdown_text := ""
	if _combat_lockdown_level > 0:
		lockdown_text = "  //  LOCKDOWN L%d" % _combat_lockdown_level
	if _enemy_still_threatening():
		return "TRACKED  //  HEAT %02d%%%s  //  BREAK LINE OF SIGHT" % [int(round(_combat_heat * 100.0)), lockdown_text]
	return "EVADE  %.1fs  //  HEAT %02d%%%s" % [maxf(combat_cooldown_remaining, 0.0), int(round(_combat_heat * 100.0)), lockdown_text]


func get_hud_level_time_text() -> String:
	if _floor_started_msec <= 0:
		return "00:00"
	var elapsed_seconds := maxf(0.0, float(Time.get_ticks_msec() - _floor_started_msec) / 1000.0)
	var total_seconds := int(floor(elapsed_seconds))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func is_search_active() -> bool:
	return _search_timer > 0.0


func get_search_target() -> Vector2:
	return _search_position


func get_search_target_for(enemy: Node2D) -> Vector2:
	if _search_timer <= 0.0 or _search_points.is_empty():
		return _search_position
	if _search_phase <= 0:
		return _search_points[0]
	var sweep_count := maxi(_search_points.size() - 1, 1)
	var slot: int = abs(enemy.get_instance_id()) % sweep_count
	var sweep_index: int = ((_search_phase - 1) + slot) % sweep_count
	return _search_points[sweep_index + 1]


func trigger_signal_jammer(position: Vector2, radius: float, duration: float) -> void:
	_jammer_position = position
	_jammer_radius = radius
	_jammer_timer = duration
	_cancel_caution()
	AlertSystem.set_alert_level(maxf(0.0, AlertSystem.alert_level - JAMMER_ALERT_REDUCTION))
	start_search(position, duration * 0.65, "SEARCH: JAMMER")


func trigger_emp_blast(position: Vector2, radius: float, duration: float) -> void:
	_cancel_caution()
	AlertSystem.set_alert_level(maxf(0.0, AlertSystem.alert_level - 0.18))
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("apply_emp_disable"):
			continue
		if enemy.global_position.distance_to(position) > radius:
			continue
		enemy.apply_emp_disable(duration)
	start_search(position, duration * 0.35, "SEARCH: EMP")


func is_point_jammed(point: Vector2) -> bool:
	if _jammer_timer <= 0.0:
		return false
	return point.distance_to(_jammer_position) <= _jammer_radius


func notify_player_noise(position: Vector2, strength: float) -> void:
	if ship.in_dark_pocket:
		return
	_last_known_player_position = position
	if not AlertSystem.combat_mode:
		AlertSystem.add_alert(0.04 * strength)
	start_search(position, SEARCH_DURATION * clampf(0.45 + strength * 0.35, 0.35, 1.2), "SEARCH: NOISE")


func start_search(position: Vector2, duration: float, reason: String = "SEARCH") -> void:
	_search_position = position
	_search_timer = maxf(_search_timer, duration)
	_search_reason = reason
	_search_points = _build_search_points(position)
	_search_phase = 0
	_search_phase_timer = SEARCH_PHASE_DURATION
	RuntimeDebugLog.log("search", "start_search reason=%s pos=(%.1f, %.1f) duration=%.2f" % [reason, position.x, position.y, duration])


func setup_arcade_objectives(graph, node_rects: Dictionary) -> void:
	if not ArcadeState.is_active:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ArcadeState.get_floor_seed() + 424242)
	var candidates: Array = []
	for node in graph.nodes:
		if node.type == graph.NodeType.START or node.type == graph.NodeType.EXIT:
			continue
		if not node_rects.has(node.id):
			continue
		if node.type == graph.NodeType.SETPIECE_ROOM or node.depth >= 2:
			candidates.append({"id": node.id, "rect": node_rects[node.id], "branch": node.type == graph.NodeType.BRANCH_ROOM})
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b): return int(a["branch"]) > int(b["branch"]))
	_objective_nodes.clear()
	_objective_progress = 0
	_objective_required = 0
	var floor_num: int = ArcadeState.floor_index + 1
	match floor_num % 3:
		1:
			_objective_type = "UPLINK"
			_objective_required = 1 if floor_num == 1 else 2
		2:
			_objective_type = "INTEL"
			_objective_required = 1
		_:
			_objective_type = "RELAY"
			_objective_required = 2
	var count: int = mini(_objective_required, candidates.size())
	for i in range(count):
		var data: Dictionary = candidates[i]
		var rect: Rect2 = data["rect"]
		var node := ObjectiveNode.new()
		node.global_position = _pick_objective_position(rect, rng)
		node.objective_name = _objective_type
		node.accent_color = ColorSystem.ui_color()
		node.add_to_group("arcade_objective")
		node.objective_completed.connect(_on_objective_completed)
		add_child(node)
		_objective_nodes.append(node)
	_set_exit_locked(_objective_required > 0)


func _pick_objective_position(rect: Rect2, rng: RandomNumberGenerator) -> Vector2:
	var inner := rect.grow(-92.0)
	if inner.size.x <= 4.0 or inner.size.y <= 4.0:
		inner = rect.grow(-42.0)
	var center := inner.get_center()
	var best_pos := center
	var best_score := _objective_clearance_score(center)
	for _attempt in range(18):
		var pos := center + Vector2(rng.randf_range(-84.0, 84.0), rng.randf_range(-56.0, 56.0))
		pos = pos.clamp(inner.position, inner.end)
		var score := _objective_clearance_score(pos)
		if score > best_score:
			best_score = score
			best_pos = pos
		if _is_objective_position_clear(pos):
			return pos
	return best_pos


func _is_objective_position_clear(pos: Vector2) -> bool:
	for pocket in get_tree().get_nodes_in_group("dark_pocket"):
		if pocket is Node2D and pos.distance_to(pocket.global_position) < 118.0:
			return false
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D and pos.distance_to(enemy.global_position) < 118.0:
			return false
	return true


func _objective_clearance_score(pos: Vector2) -> float:
	var score := 0.0
	for pocket in get_tree().get_nodes_in_group("dark_pocket"):
		if pocket is Node2D:
			score += minf(pos.distance_to(pocket.global_position), 240.0) * 3.0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D:
			score += minf(pos.distance_to(enemy.global_position), 220.0)
	return score


func _on_objective_completed(_node: ObjectiveNode) -> void:
	_objective_progress += 1
	AlertSystem.set_alert_level(maxf(0.0, AlertSystem.alert_level - 0.12))
	if ship != null:
		ship.probe_charges = mini(ship.probe_charges + 1, 5)
		ship.jammer_charges = mini(ship.jammer_charges + 1, 3)
	if _objective_progress >= _objective_required:
		_set_exit_locked(false)
		_interaction_text = "EXIT UNLOCKED"


func _record_arcade_floor_result(cleared: bool) -> void:
	if not ArcadeState.is_active or _arcade_result_recorded:
		return
	_arcade_result_recorded = true
	ArcadeState.record_floor_result({
		"kills": _kill_count,
		"suppressed_kills": _suppressed_kill_count,
		"alerts_triggered": _alert_count,
		"hacks_completed": _hacks_completed,
		"probes_used": _probes_used,
		"floor_time_seconds": maxf(0.0, float(Time.get_ticks_msec() - _floor_started_msec) / 1000.0),
	}, cleared)


func _show_arcade_run_summary(completed: bool, floor_clear: bool = false) -> void:
	_ensure_arcade_summary_overlay()
	if _arcade_summary_overlay != null and _arcade_summary_overlay.has_method("show_summary"):
		_arcade_summary_overlay.show_summary(ArcadeState.build_run_summary(completed), "floor_clear" if floor_clear and not completed else "run_end")


func _set_exit_locked(active: bool) -> void:
	var exit := get_node_or_null("ExitZone")
	if exit != null and exit.has_method("set_locked"):
		exit.set_locked(active, "FIND %s" % _objective_type if active else "EXIT")


func _nearest_objective(ship_node: Node2D) -> ObjectiveNode:
	var best: ObjectiveNode = null
	var best_dist := INF
	for node in _objective_nodes:
		if node == null or not is_instance_valid(node) or node.completed:
			continue
		var dist: float = node.global_position.distance_to(ship_node.global_position)
		if dist < best_dist:
			best = node
			best_dist = dist
	return best


func _update_search(delta: float) -> void:
	if _search_timer <= 0.0:
		return
	if ship.in_dark_pocket and not AlertSystem.combat_mode:
		_search_timer = maxf(0.0, _search_timer - delta * 1.8)
	elif _stealth_reentry_timer > 0.0 and not AlertSystem.combat_mode:
		_search_timer = maxf(0.0, _search_timer - delta * 1.2)
	else:
		_search_timer = maxf(0.0, _search_timer - delta)
	_search_phase_timer = maxf(0.0, _search_phase_timer - delta)
	if _search_timer > 0.0 and _search_phase_timer <= 0.0 and not _search_points.is_empty():
		_search_phase = mini(_search_phase + 1, maxi(_search_points.size() - 1, 0))
		_search_phase_timer = SEARCH_PHASE_DURATION
	if _search_timer <= 0.0:
		_search_reason = ""
		_search_points.clear()
		_search_phase = 0
		_search_phase_timer = 0.0


func _update_jammer(delta: float) -> void:
	if _jammer_timer <= 0.0:
		return
	_jammer_timer = maxf(0.0, _jammer_timer - delta)


func _update_objectives(_delta: float) -> void:
	if _interaction_text != "" and not InputManager.is_hack_pressed():
		if not _interaction_text.begins_with("EXIT") and not _interaction_text.ends_with("LINKED"):
			_interaction_text = ""


func _living_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			count += 1
	return count


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _configure_camera() -> void:
	var camera: Camera2D = ship.get_node("Camera2D")
	var rect: Rect2 = grid.get("world_rect")
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		camera.zoom = Vector2.ONE
		camera.position_smoothing_speed = 9.0


func _update_combat_cooldown(delta: float) -> void:
	_update_combat_pressure(delta)
	if _enemy_still_threatening():
		combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
		return
	combat_cooldown_remaining = maxf(0.0, combat_cooldown_remaining - delta)
	if combat_cooldown_remaining <= 0.0:
		_exit_combat_to_stealth()


func _enemy_still_threatening() -> bool:
	if ship.in_dark_pocket:
		return false
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		var distance: float = enemy.global_position.distance_to(ship.global_position)
		if distance > THREAT_DISTANCE:
			continue
		if not is_line_blocked(enemy.global_position, ship.global_position, [enemy.get_rid()]):
			return true
	return false


func _exit_combat_to_stealth() -> void:
	begin_patrol_recovery_cycle()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if bool(enemy.get_meta("combat_temporary", false)):
			enemy.queue_free()
			continue
		if enemy.has_method("deactivate_to_stealth"):
			enemy.deactivate_to_stealth()
		if enemy.has_method("clear_alert_state"):
			enemy.clear_alert_state()
	_clear_enemy_projectiles()
	_prune_enemy_list()
	AlertSystem.exit_combat()
	combat_cooldown_remaining = 0.0
	_reset_combat_pressure()
	_begin_stealth_reentry(ship != null and ship.in_dark_pocket)
	start_search(_last_known_player_position if _last_known_player_position != Vector2.ZERO else ship.global_position, SEARCH_DURATION, "SEARCH: SWEEP")
	_log_system_state("combat_exit_to_stealth")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("_update_palette"):
			enemy.call("_update_palette")
		if enemy.has_method("queue_redraw"):
			enemy.queue_redraw()


func _prune_enemy_list() -> void:
	var retained: Array[Node] = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_alive:
			continue
		if bool(enemy.get_meta("combat_temporary", false)):
			continue
		retained.append(enemy)
	enemies = retained


func _relax_enemies_for_hiding() -> void:
	_cancel_caution()
	_search_timer = 0.0
	_search_reason = ""
	_search_position = Vector2.ZERO
	_last_known_player_position = Vector2.ZERO
	combat_cooldown_remaining = 0.0
	_reset_combat_pressure()
	if AlertSystem.combat_mode:
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if bool(enemy.get_meta("combat_temporary", false)):
				enemy.queue_free()
				continue
			if enemy.has_method("deactivate_to_stealth"):
				enemy.deactivate_to_stealth()
		AlertSystem.exit_combat()
	else:
		AlertSystem.set_alert_level(0.0)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if bool(enemy.get_meta("combat_temporary", false)):
			enemy.queue_free()
			continue
		if enemy.has_method("clear_alert_state"):
			enemy.clear_alert_state()
		elif enemy.has_method("deactivate_to_stealth"):
			enemy.deactivate_to_stealth()
		if enemy.has_method("_update_palette"):
			enemy.call("_update_palette")
		if enemy.has_method("queue_redraw"):
			enemy.queue_redraw()
	_clear_enemy_projectiles()
	_prune_enemy_list()
	_begin_stealth_reentry(true)
	_log_system_state("relax_enemies_for_hiding")


func is_stealth_reentry_active() -> bool:
	return _stealth_reentry_timer > 0.0 and not AlertSystem.combat_mode


func should_suppress_enemy_detection(enemy: Node2D, player: Node2D) -> bool:
	if enemy == null or player == null:
		return false
	if player.in_dark_pocket:
		return true
	if not is_stealth_reentry_active():
		return false
	if enemy.global_position.distance_to(player.global_position) >= STEALTH_REENTRY_DETECTION_CLEAR_DISTANCE:
		return true
	return is_line_blocked(enemy.global_position, player.global_position, [enemy.get_rid()])


func _begin_stealth_reentry(hidden_reset: bool) -> void:
	_stealth_reentry_timer = maxf(_stealth_reentry_timer, STEALTH_REENTRY_HIDDEN_DURATION if hidden_reset else STEALTH_REENTRY_DURATION)


func _update_stealth_reentry(delta: float) -> void:
	if _stealth_reentry_timer <= 0.0 or AlertSystem.combat_mode:
		return
	_stealth_reentry_timer = maxf(0.0, _stealth_reentry_timer - delta)
	if AlertSystem.alert_level > 0.0:
		AlertSystem.set_alert_level(maxf(0.0, AlertSystem.alert_level - delta * STEALTH_REENTRY_ALERT_DECAY))


func begin_patrol_recovery_cycle() -> void:
	_patrol_recovery_claims.clear()


func reserve_patrol_recovery_point(enemy: Node2D, candidate_points: Array) -> Variant:
	if enemy == null or candidate_points.is_empty():
		return null
	for point in candidate_points:
		if not (point is Vector2):
			continue
		var candidate: Vector2 = point
		if _is_patrol_recovery_point_claimed(candidate):
			continue
		_patrol_recovery_claims[_patrol_recovery_key(candidate)] = enemy.get_instance_id()
		return candidate
	return null


func schedule_enemy_patrol_reentry(enemy: Node2D, candidate_points: Array) -> void:
	if enemy == null or candidate_points.is_empty():
		return
	if not enemy.has_method("suspend_for_patrol_reentry"):
		return
	for pending in _pending_patrol_reentries:
		if pending.get("enemy") == enemy:
			return
	enemy.suspend_for_patrol_reentry()
	_pending_patrol_reentries.append({
		"enemy": enemy,
		"timer": PATROL_REENTRY_DELAY,
		"points": candidate_points.duplicate(true),
	})


func _update_patrol_reentries(delta: float) -> void:
	if _pending_patrol_reentries.is_empty():
		return
	for i in range(_pending_patrol_reentries.size() - 1, -1, -1):
		var pending: Dictionary = _pending_patrol_reentries[i]
		var enemy: Node2D = pending.get("enemy")
		if enemy == null or not is_instance_valid(enemy):
			_pending_patrol_reentries.remove_at(i)
			continue
		var timer: float = float(pending.get("timer", 0.0)) - delta
		pending["timer"] = timer
		if timer > 0.0:
			_pending_patrol_reentries[i] = pending
			continue
		var reserved: Variant = reserve_patrol_recovery_point(enemy, pending.get("points", []))
		if reserved is Vector2:
			var target: Vector2 = reserved
			if ship != null and target.distance_to(ship.global_position) < PATROL_REENTRY_PLAYER_CLEAR:
				pending["timer"] = 0.35
				_pending_patrol_reentries[i] = pending
				continue
			if enemy.has_method("resume_from_patrol_reentry"):
				enemy.resume_from_patrol_reentry(target)
			_pending_patrol_reentries.remove_at(i)
			continue
		pending["timer"] = 0.4
		_pending_patrol_reentries[i] = pending


func _is_patrol_recovery_point_claimed(point: Vector2) -> bool:
	for key in _patrol_recovery_claims.keys():
		var parts := str(key).split(":")
		if parts.size() != 2:
			continue
		var claimed := Vector2(float(parts[0]), float(parts[1]))
		if claimed.distance_to(point) < PATROL_RECOVERY_SLOT_RADIUS:
			return true
	return false


func _patrol_recovery_key(point: Vector2) -> String:
	return "%.1f:%.1f" % [point.x, point.y]


func _log_system_state(reason: String) -> void:
	if ship == null:
		return
	var alive_count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			alive_count += 1
	RuntimeDebugLog.log(
		"state",
		"%s | player=(%.1f, %.1f) vel=%.1f dark=%s hidden=%s alert=%.2f combat=%s caution=%s search=%s reason=%s search_timer=%.2f phase=%d cooldown=%.2f heat=%.2f budget=%.2f pool=%d lockdown=%d gates=%d alive=%d" % [
			reason,
			ship.global_position.x,
			ship.global_position.y,
			ship.velocity.length(),
			ship.dark_mode,
			ship.in_dark_pocket,
			AlertSystem.alert_level,
			AlertSystem.combat_mode,
			_caution_active,
			is_search_active(),
			_search_reason,
			_search_timer,
			_search_phase,
			combat_cooldown_remaining,
			_combat_heat,
			_combat_reinforcement_budget,
			_combat_respawn_pool.size(),
			_combat_lockdown_level,
			_combat_locked_gate_ids.size(),
			alive_count,
		]
	)


func _begin_combat_pressure() -> void:
	_combat_heat = maxf(_combat_heat, 0.24)
	_combat_reinforcement_budget = maxf(_combat_reinforcement_budget, 0.65)
	_combat_reinforcement_timer = _combat_interval_for_heat()
	_combat_dynamic_spawn_count = 0
	_combat_baseline_enemy_count = _living_enemy_count()
	_combat_respawn_pool.clear()
	_set_combat_lockdown_level(0)
	RuntimeDebugLog.log("combat", "begin pressure heat=%.2f budget=%.2f baseline=%d target=%d" % [_combat_heat, _combat_reinforcement_budget, _combat_baseline_enemy_count, _combat_target_alive_count()])


func _reset_combat_pressure() -> void:
	_combat_heat = 0.0
	_combat_reinforcement_budget = 0.0
	_combat_reinforcement_timer = 0.0
	_combat_dynamic_spawn_count = 0
	_combat_baseline_enemy_count = 0
	_combat_respawn_pool.clear()
	_set_combat_lockdown_level(0)


func _update_combat_pressure(delta: float) -> void:
	if not AlertSystem.combat_mode:
		return
	var alive_now := _living_enemy_count()
	var target_alive := _combat_target_alive_count()
	_combat_heat = minf(1.0, _combat_heat + delta * COMBAT_HEAT_PER_SECOND)
	_update_combat_lockdown()
	_combat_reinforcement_budget = minf(COMBAT_REINFORCEMENT_BUDGET_CAP, _combat_reinforcement_budget + delta * COMBAT_REINFORCEMENT_BUDGET_PER_SECOND * lerpf(0.7, 1.4, _combat_heat))
	if alive_now < target_alive:
		var missing := target_alive - alive_now
		_combat_reinforcement_budget = maxf(_combat_reinforcement_budget, float(missing))
		_combat_reinforcement_timer = minf(_combat_reinforcement_timer, COMBAT_REINFORCEMENT_RECOVERY_DELAY)
	_combat_reinforcement_timer = maxf(0.0, _combat_reinforcement_timer - delta)
	if _combat_reinforcement_budget < 1.0 or _combat_reinforcement_timer > 0.0:
		return
	if _spawn_dynamic_combat_reinforcement():
		_combat_dynamic_spawn_count += 1
		_combat_reinforcement_budget = maxf(0.0, _combat_reinforcement_budget - 1.0)
		alive_now = _living_enemy_count()
		target_alive = _combat_target_alive_count()
		if alive_now < target_alive:
			_combat_reinforcement_timer = COMBAT_REINFORCEMENT_RECOVERY_DELAY
		else:
			_combat_reinforcement_timer = _combat_interval_for_heat()
		RuntimeDebugLog.log("combat", "dynamic reinforcement spawned count=%d heat=%.2f budget=%.2f alive=%d target=%d" % [_combat_dynamic_spawn_count, _combat_heat, _combat_reinforcement_budget, alive_now, target_alive])
	else:
		_combat_reinforcement_timer = COMBAT_REINFORCEMENT_RETRY_TIME


func _combat_interval_for_heat() -> float:
	return lerpf(COMBAT_REINFORCEMENT_INTERVAL_HIGH, COMBAT_REINFORCEMENT_INTERVAL_LOW, _combat_heat)


func _combat_target_alive_count() -> int:
	if _combat_baseline_enemy_count <= 0:
		return COMBAT_REINFORCEMENT_MIN_ACTIVE
	var scaled_target := int(ceil(float(_combat_baseline_enemy_count) * lerpf(0.62, 0.82, _combat_heat)))
	return clampi(maxi(COMBAT_REINFORCEMENT_MIN_ACTIVE, scaled_target), COMBAT_REINFORCEMENT_MIN_ACTIVE, COMBAT_REINFORCEMENT_MAX_ACTIVE)


func _update_combat_lockdown() -> void:
	var next_level := 0
	if _combat_heat >= COMBAT_LOCKDOWN_LEVEL_TWO_HEAT:
		next_level = 2
	elif _combat_heat >= COMBAT_LOCKDOWN_LEVEL_ONE_HEAT:
		next_level = 1
	_set_combat_lockdown_level(next_level)


func _set_combat_lockdown_level(level: int) -> void:
	level = clampi(level, 0, 2)
	if _combat_lockdown_level == level and (level == 0 or not _combat_locked_gate_ids.is_empty()):
		return
	_combat_lockdown_level = level
	var gates := _get_lockdown_gates()
	for gate in gates:
		gate.set_lockdown_closed(false)
	_combat_locked_gate_ids.clear()
	if level <= 0:
		_refresh_progress_lock_state()
		return
	var to_lock := _select_lockdown_gates(level)
	for gate in to_lock:
		gate.set_lockdown_closed(true)
		_combat_locked_gate_ids.append(gate.get_instance_id())
	_refresh_progress_lock_state()
	_interaction_text = "LOCKDOWN L%d  //  ROUTES SHIFTING" % level
	RuntimeDebugLog.log("lockdown", "level=%d locked=%d" % [level, _combat_locked_gate_ids.size()])
	_log_system_state("combat_lockdown_l%d" % level)


func _get_lockdown_gates() -> Array:
	var gates: Array = []
	var lockdown_only: Array = []
	for child in get_children():
		if child == null or not child.has_method("set_lockdown_closed"):
			continue
		gates.append(child)
		if child.has_method("is_lockdown_candidate") and child.is_lockdown_candidate():
			lockdown_only.append(child)
	if not lockdown_only.is_empty():
		return lockdown_only
	return gates


func _select_lockdown_gates(level: int) -> Array:
	var gates := _get_lockdown_gates()
	if gates.is_empty():
		return []
	var safe_anchor := _nearest_dark_pocket_position()
	if safe_anchor == Vector2.ZERO:
		safe_anchor = _goal_anchor_position()
	var goal_anchor := _goal_anchor_position()
	var desired_dir := _lockdown_desired_direction(goal_anchor)
	var candidates: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for gate in gates:
		var pos: Vector2 = gate.global_position
		if pos.distance_to(ship.global_position) < COMBAT_LOCKDOWN_PLAYER_EXCLUSION:
			continue
		if safe_anchor != Vector2.ZERO and pos.distance_to(safe_anchor) < COMBAT_LOCKDOWN_POCKET_EXCLUSION:
			continue
		if goal_anchor != Vector2.ZERO and pos.distance_to(goal_anchor) < COMBAT_LOCKDOWN_GOAL_EXCLUSION:
			fallback.append({"gate": gate, "score": 1.0})
			continue
		var to_gate: Vector2 = pos - ship.global_position
		var score: float = to_gate.length()
		if desired_dir != Vector2.ZERO:
			score += maxf(desired_dir.dot(to_gate.normalized()), 0.0) * 260.0
		if safe_anchor != Vector2.ZERO:
			score += minf(pos.distance_to(safe_anchor), 520.0) * 0.28
		if goal_anchor != Vector2.ZERO:
			score += maxf(420.0 - pos.distance_to(goal_anchor), 0.0) * 0.45
		candidates.append({"gate": gate, "score": score})
	if candidates.is_empty():
		candidates = fallback
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	var selected: Array = []
	for candidate in candidates:
		if selected.size() >= level:
			break
		selected.append(candidate["gate"])
	return selected


func _nearest_dark_pocket_position() -> Vector2:
	var best := Vector2.ZERO
	var best_dist := INF
	for pocket in get_tree().get_nodes_in_group("dark_pocket"):
		if not (pocket is Node2D):
			continue
		var dist: float = ship.global_position.distance_to(pocket.global_position)
		if dist < best_dist:
			best_dist = dist
			best = pocket.global_position
	return best


func _goal_anchor_position() -> Vector2:
	var objective := _nearest_objective(ship)
	if objective != null:
		return objective.global_position
	var exit := get_node_or_null("ExitZone")
	if exit is Node2D:
		return exit.global_position
	return Vector2.ZERO


func _lockdown_desired_direction(goal_anchor: Vector2) -> Vector2:
	if ship.velocity.length() > 1.0:
		return ship.velocity.normalized()
	if goal_anchor != Vector2.ZERO:
		return (goal_anchor - ship.global_position).normalized()
	return Vector2.ZERO


func _refresh_progress_lock_state() -> void:
	var should_lock_progress := AlertSystem.combat_mode and _combat_lockdown_level >= 1
	_combat_progress_locked = should_lock_progress
	if should_lock_progress:
		var exit := get_node_or_null("ExitZone")
		if exit != null and exit.has_method("set_locked"):
			exit.set_locked(true, "REDLINE")
		return
	_set_exit_locked(_objective_required > 0 and _objective_progress < _objective_required)


func _build_search_points(position: Vector2) -> Array[Vector2]:
	var rect: Rect2 = grid.get("world_rect")
	var radius_x := 118.0
	var radius_y := 92.0
	var points: Array[Vector2] = [
		position,
		position + Vector2(-radius_x, 0.0),
		position + Vector2(radius_x, 0.0),
		position + Vector2(0.0, -radius_y),
		position + Vector2(0.0, radius_y),
		position + Vector2(-radius_x * 0.72, -radius_y * 0.72),
		position + Vector2(radius_x * 0.72, -radius_y * 0.72),
		position + Vector2(-radius_x * 0.72, radius_y * 0.72),
		position + Vector2(radius_x * 0.72, radius_y * 0.72),
	]
	for i in range(points.size()):
		points[i] = points[i].clamp(rect.position + Vector2(36.0, 36.0), rect.end - Vector2(36.0, 36.0))
	return points


func _refresh_dark_pocket_gates() -> void:
	for child in get_children():
		if child == null or not child.has_method("set_dark_pocket_open"):
			continue
		child.set_dark_pocket_open(false)

	for pocket in _active_dark_pockets.values():
		_open_gates_for_pocket(pocket)


func _open_gates_for_pocket(pocket: Area2D) -> void:
	var unlock_radius: float = pocket.get("gate_unlock_radius")
	for child in get_children():
		if child == null or not child.has_method("set_dark_pocket_open"):
			continue
		if pocket.global_position.distance_to(child.global_position) > unlock_radius:
			continue
		child.set_dark_pocket_open(true)


func _find_nearest_hack_gate(ship_node: Node2D) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for child in get_children():
		if child == null or not child.has_method("can_be_hacked_by"):
			continue
		if not child.can_be_hacked_by(ship_node):
			continue
		var dist: float = ship_node.global_position.distance_to(child.global_position)
		if dist >= nearest_dist:
			continue
		nearest = child
		nearest_dist = dist
	return nearest


func _snapshot_enemy(enemy: Node) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy):
		return {}
	if enemy.scene_file_path.is_empty():
		return {}
	var snapshot := {
		"scene_path": enemy.scene_file_path,
		"global_position": enemy.global_position,
		"rotation": enemy.rotation,
	}
	if enemy.has_node("PatrolA"):
		snapshot["patrol_a"] = enemy.get_node("PatrolA").position
	if enemy.has_node("PatrolB"):
		snapshot["patrol_b"] = enemy.get_node("PatrolB").position
	return snapshot


func _respawn_defeated_enemies() -> void:
	if _defeated_enemy_snapshots.is_empty():
		return
	var snapshots := _defeated_enemy_snapshots.duplicate(true)
	_defeated_enemy_snapshots.clear()
	for snapshot in snapshots:
		var scene: PackedScene = load(snapshot["scene_path"])
		if scene == null:
			continue
		var enemy := scene.instantiate()
		enemy.global_position = snapshot["global_position"]
		enemy.rotation = snapshot["rotation"]
		if snapshot.has("patrol_a") and enemy.has_node("PatrolA"):
			enemy.get_node("PatrolA").position = snapshot["patrol_a"]
		if snapshot.has("patrol_b") and enemy.has_node("PatrolB"):
			enemy.get_node("PatrolB").position = snapshot["patrol_b"]
		register_spawned_enemy(enemy)


func _spawn_reinforcements_for_alert() -> void:
	if _reinforcements_spawned:
		return
	var spawn_points := _get_reinforcement_points()
	if spawn_points.is_empty():
		return

	var desired_count := 4
	var min_distance := 280.0
	var max_distance := 980.0
	var candidates: Array[Dictionary] = []

	for point in spawn_points:
		var marker: Marker2D = point["marker"]
		var distance := marker.global_position.distance_to(ship.global_position)
		if distance < min_distance or distance > max_distance:
			continue
		candidates.append({
			"marker": marker,
			"kind": point["kind"],
			"distance": distance,
		})

	if candidates.is_empty():
		return

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"]
	)

	var spawned := 0
	for candidate in candidates:
		if spawned >= desired_count:
			break
		var enemy := _instantiate_reinforcement(candidate["kind"])
		if enemy == null:
			continue
		enemy.global_position = candidate["marker"].global_position
		_register_combat_temporary_enemy(enemy)
		register_spawned_enemy(enemy)
		spawned += 1

	if spawned > 0:
		_reinforcements_spawned = true


func _spawn_dynamic_combat_reinforcement() -> bool:
	var candidates: Array[Dictionary] = []
	var fallback_candidates: Array[Dictionary] = []
	for point in _get_reinforcement_points():
		var marker: Marker2D = point["marker"]
		var pos: Vector2 = marker.global_position
		var score := _combat_spawn_score(pos, false)
		var data := {
			"source": "marker",
			"score": score,
			"kind": point["kind"],
			"position": pos,
		}
		if score > 0.0:
			candidates.append(data)
		elif _combat_fallback_spawn_ok(pos):
			data["score"] = _combat_fallback_score(pos)
			fallback_candidates.append(data)
	for i in range(_combat_respawn_pool.size()):
		var snapshot: Dictionary = _combat_respawn_pool[i]
		var pos: Vector2 = snapshot.get("global_position", Vector2.ZERO)
		var score := _combat_spawn_score(pos, true)
		var data := {
			"source": "snapshot",
			"score": score + 60.0,
			"snapshot_index": i,
			"snapshot": snapshot,
			"position": pos,
		}
		if score > 0.0:
			candidates.append(data)
		elif _combat_fallback_spawn_ok(pos):
			data["score"] = _combat_fallback_score(pos) + 40.0
			fallback_candidates.append(data)
	if candidates.is_empty():
		candidates = fallback_candidates
		if candidates.is_empty():
			RuntimeDebugLog.log("combat", "no dynamic reinforcement candidates passed filters")
			return false
		RuntimeDebugLog.log("combat", "using fallback reinforcement candidates count=%d" % candidates.size())
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	var chosen: Dictionary = candidates[0]
	if str(chosen["source"]) == "snapshot":
		var respawned := _instantiate_snapshot_enemy(chosen["snapshot"])
		if respawned == null:
			return false
		_register_combat_temporary_enemy(respawned)
		register_spawned_enemy(respawned)
		_combat_respawn_pool.remove_at(int(chosen["snapshot_index"]))
		RuntimeDebugLog.log("combat", "respawned snapshot enemy at (%.1f, %.1f)" % [respawned.global_position.x, respawned.global_position.y])
		return true
	var enemy := _instantiate_reinforcement(str(chosen["kind"]))
	if enemy == null:
		return false
	enemy.global_position = chosen["position"]
	_register_combat_temporary_enemy(enemy)
	register_spawned_enemy(enemy)
	RuntimeDebugLog.log("combat", "spawned marker reinforcement kind=%s at (%.1f, %.1f)" % [chosen["kind"], enemy.global_position.x, enemy.global_position.y])
	return true


func _combat_spawn_score(position: Vector2, from_snapshot: bool) -> float:
	var distance := position.distance_to(ship.global_position)
	if distance < COMBAT_REINFORCEMENT_MIN_DISTANCE or distance > COMBAT_REINFORCEMENT_MAX_DISTANCE:
		return -1.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if enemy.global_position.distance_to(position) < (84.0 if from_snapshot else 110.0):
			return -1.0
	var blocked := is_line_blocked(position, ship.global_position, [])
	var score := distance
	if blocked:
		score += COMBAT_REINFORCEMENT_BLOCKED_BONUS
	if ship.velocity.length() > 1.0:
		var to_spawn: Vector2 = (position - ship.global_position).normalized()
		var move_dir: Vector2 = ship.velocity.normalized()
		score += maxf(-move_dir.dot(to_spawn), 0.0) * 160.0
	else:
		score += absf(position.x - ship.global_position.x) * 0.08 + absf(position.y - ship.global_position.y) * 0.08
	return score


func _combat_fallback_spawn_ok(position: Vector2) -> bool:
	var distance := position.distance_to(ship.global_position)
	if distance < 180.0 or distance > COMBAT_REINFORCEMENT_MAX_DISTANCE * 1.15:
		return false
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if enemy.global_position.distance_to(position) < 72.0:
			return false
	return true


func _combat_fallback_score(position: Vector2) -> float:
	var distance := position.distance_to(ship.global_position)
	var score := distance * 0.85
	if is_line_blocked(position, ship.global_position, []):
		score += COMBAT_REINFORCEMENT_BLOCKED_BONUS * 0.55
	if ship.velocity.length() > 1.0:
		var to_spawn: Vector2 = (position - ship.global_position).normalized()
		var move_dir: Vector2 = ship.velocity.normalized()
		score += maxf(-move_dir.dot(to_spawn), 0.0) * 110.0
	return score


func _get_reinforcement_points() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for node in find_children("*", "Marker2D", true, false):
		if not node.name.begins_with("Reinforce"):
			continue
		var marker := node as Marker2D
		if marker == null:
			continue
		points.append({
			"marker": marker,
			"kind": _reinforcement_kind_from_name(marker.name),
		})
	return points


func _reinforcement_kind_from_name(node_name: String) -> String:
	if node_name.contains("Prism"):
		return "prism"
	if node_name.contains("Wisp"):
		return "wisp"
	return "hunter"


func _instantiate_reinforcement(kind: String) -> Node:
	match kind:
		"prism":
			return PRISM_SCENE.instantiate()
		"wisp":
			return WISP_SCENE.instantiate()
		_:
			return HUNTER_SCENE.instantiate()


func _instantiate_snapshot_enemy(snapshot: Dictionary) -> Node:
	if snapshot.is_empty():
		return null
	var scene: PackedScene = load(snapshot["scene_path"])
	if scene == null:
		return null
	var enemy := scene.instantiate()
	enemy.global_position = snapshot["global_position"]
	enemy.rotation = snapshot["rotation"]
	if snapshot.has("patrol_a") and enemy.has_node("PatrolA"):
		enemy.get_node("PatrolA").position = snapshot["patrol_a"]
	if snapshot.has("patrol_b") and enemy.has_node("PatrolB"):
		enemy.get_node("PatrolB").position = snapshot["patrol_b"]
	return enemy
