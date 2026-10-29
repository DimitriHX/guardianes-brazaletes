extends Node
## Música y efectos de sonido (Autoload "AudioManager").
## - Música: play_music(&"menu") con fundido cruzado entre dos reproductores
##   (bus "Music"). Si ya suena la misma pista, no la reinicia.
## - Efectos: play_sfx(&"coin") desde un pool de reproductores (bus "SFX").
## - La jugabilidad no llama al audio: este nodo escucha Events y suena solo.
## Los archivos se cargan solo si existen (audio con licencia fuera del repo):
## si falta alguno, el juego sigue sin ese sonido.

const MUSIC: Dictionary[StringName, String] = {
	&"menu": "res://audio/music/menu.mp3",
	&"levels": "res://audio/music/levels.mp3",
	&"victory": "res://audio/music/victory.mp3",
	&"game_over": "res://audio/music/game_over.ogg",
}
const SFX: Dictionary[StringName, String] = {
	&"jump": "res://audio/sfx/jump.wav",
	&"ui_select": "res://audio/sfx/ui_select.wav",
	&"shoot": "res://audio/sfx/shoot.wav",
	&"impact": "res://audio/sfx/impact.wav",
	&"coin": "res://audio/sfx/coin.wav",
	&"heal": "res://audio/sfx/heal.wav",
	&"player_hurt": "res://audio/sfx/player_hurt.wav",
	&"enemy_purified": "res://audio/sfx/enemy_purified.wav",
	&"door_open": "res://audio/sfx/door_open.wav",
	&"door_enter": "res://audio/sfx/door_enter.wav",
	&"boss_charge": "res://audio/sfx/boss_charge.wav",
	&"boss_roar": "res://audio/sfx/boss_roar.wav",
	&"boss_purified": "res://audio/sfx/boss_purified.wav",
}
## Pistas de una sola pasada (no se repiten en bucle).
const ONE_SHOT_MUSIC: Array[StringName] = [&"game_over"]
## Volumen relativo por efecto (dB), para equilibrar sonidos de distintos paquetes.
const SFX_GAIN_DB: Dictionary[StringName, float] = {&"ui_select": -8.0, &"shoot": -4.0, &"impact": -6.0}

@export var sfx_voices: int = 8
@export var music_fade_time: float = 0.8

var current_music: StringName = &""

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cache: Dictionary[String, AudioStream] = {}
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player(&"Music")
	_music_b = _make_player(&"Music")
	_active_music = _music_a
	for i: int in sfx_voices:
		_sfx_pool.append(_make_player(&"SFX"))
	Events.sfx_requested.connect(play_sfx)
	Events.player_jumped.connect(_on_player_jumped)
	Events.player_shot.connect(_on_player_shot)
	Events.pickup_collected.connect(_on_pickup_collected)
	Events.entity_damaged.connect(_on_entity_damaged)
	Events.enemy_died.connect(_on_enemy_died)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.player_died.connect(_on_player_died)
	Events.level_change_requested.connect(_on_level_change_requested)


func play_music(track: StringName, fade: float = -1.0) -> void:
	if track == current_music and _active_music.playing:
		return
	var stream: AudioStream = _load(MUSIC.get(track, ""))
	current_music = track
	var duration: float = music_fade_time if fade < 0.0 else fade
	var outgoing: AudioStreamPlayer = _active_music
	_active_music = _music_b if _active_music == _music_a else _music_a
	if stream != null:
		_set_loop(stream, not ONE_SHOT_MUSIC.has(track))
		_active_music.stream = stream
		_active_music.volume_db = -40.0 if duration > 0.0 else 0.0
		_active_music.play()
	_crossfade(outgoing, _active_music if stream != null else null, duration)


func stop_music(fade: float = -1.0) -> void:
	current_music = &""
	_crossfade(_active_music, null, music_fade_time if fade < 0.0 else fade)


func play_sfx(sfx_name: StringName) -> void:
	var stream: AudioStream = _load(SFX.get(sfx_name, ""))
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_pool[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = SFX_GAIN_DB.get(sfx_name, 0.0)
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func has_sound(sfx_name: StringName) -> bool:
	return _load(SFX.get(sfx_name, "")) != null


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _load(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_cache[path] = stream
	return stream


func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED


func _crossfade(outgoing: AudioStreamPlayer, incoming: AudioStreamPlayer, duration: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if duration <= 0.0:
		if outgoing != null and outgoing != incoming:
			outgoing.stop()
		return
	_fade_tween = create_tween().set_parallel(true)
	if outgoing != null and outgoing.playing and outgoing != incoming:
		_fade_tween.tween_property(outgoing, "volume_db", -40.0, duration)
		_fade_tween.chain().tween_callback(outgoing.stop)
	if incoming != null:
		_fade_tween.tween_property(incoming, "volume_db", 0.0, duration)


func _on_player_jumped() -> void:
	play_sfx(&"jump")


func _on_player_shot(_cooldown: float) -> void:
	play_sfx(&"shoot")


func _on_pickup_collected(kind: StringName) -> void:
	play_sfx(&"heal" if kind == &"health" else &"coin")


func _on_entity_damaged(entity: Node, _amount: int) -> void:
	play_sfx(&"player_hurt" if entity.is_in_group("player") else &"impact")


func _on_enemy_died(_enemy: Node) -> void:
	play_sfx(&"enemy_purified")


func _on_boss_defeated(_boss: Node) -> void:
	play_sfx(&"boss_purified")


func _on_player_died() -> void:
	play_music(&"game_over", 0.3)


func _on_level_change_requested(_scene_path: String) -> void:
	play_sfx(&"door_enter")
