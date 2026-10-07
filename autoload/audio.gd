extends Node
## Lecture des sons. Chaque son est chargé depuis res://assets/sounds/<nom>.(ogg|wav|mp3)
## (+ variantes <nom>_1, <nom>_2… choisies au hasard) s'il existe, sinon il est
## synthétisé au démarrage (sons de remplacement).

const RATE := 22050
const SOUND_DIR := "res://assets/sounds/"

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _voice: AudioStreamPlayer
var _voice_queue: Array[String] = []
const VOICES := ["fire_sale", "bonus_points", "zombie_blood", "max_ammo", "insta_kill", "nuke", "double_points", "carpenter", "boss", "boss_down", "helmet", "dogs",
	"power_on", "box_moved", "trap_on", "game_over", "round_5", "round_10", "round_15", "round_20", "round_25", "round_30"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	GameManager.apply_audio()
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	_voice.volume_db = 2.0
	_voice.finished.connect(_next_voice)
	add_child(_voice)
	_build_library()


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _pick(sound)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for candidate in _pool:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = _pool[_next]
		_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _pick(sound)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 45.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Annonceur : une seule voix à la fois, les suivantes attendent leur tour.
func say(id: String) -> void:
	if not _streams.has("voice_" + id):
		return
	if _voice.playing:
		if _voice_queue.size() < 3 and not _voice_queue.has(id):
			_voice_queue.append(id)
		return
	_voice.stream = _pick("voice_" + id)
	_voice.play()


## Surdité passagère après un hurlement : filtre passe-bas sur la sortie principale.
func deafen(sec: float) -> void:
	var fx := AudioEffectLowPassFilter.new()
	fx.cutoff_hz = 700.0
	AudioServer.add_bus_effect(0, fx)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(maxf(sec - 1.0, 0.1))
	tw.tween_property(fx, "cutoff_hz", 20000.0, 1.0)
	tw.tween_callback(func():
		for i in AudioServer.get_bus_effect_count(0):
			if AudioServer.get_bus_effect(0, i) == fx:
				AudioServer.remove_bus_effect(0, i)
				break)


func _next_voice() -> void:
	if _voice_queue.is_empty():
		return
	say(_voice_queue.pop_front())


## Boucle musicale/ambiance (une seule à la fois, fondu enchaîné).
func play_music(sound: String, volume_db := -6.0) -> void:
	if _music_name == sound and _music.playing:
		return
	_music_name = sound
	var s := _pick(sound)
	if s == null:
		return
	_music.stream = s
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", volume_db, 2.0)


func stop_music(fade := 1.5) -> void:
	_music_name = ""
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -60.0, fade)
	tw.tween_callback(_music.stop)


func _pick(sound: String) -> AudioStream:
	var list: Array = _streams.get(sound, [])
	return list.pick_random() if not list.is_empty() else null


# --- Bibliothèque ---------------------------------------------------------

func _build_library() -> void:
	var defs := {
		"shot_pistol": [0.25, func(t, st): return _noise(st, 0.6) * exp(-t * 28.0) + sin(TAU * 140.0 * t) * exp(-t * 30.0) * 0.6],
		"shot_rifle": [0.22, func(t, st): return _noise(st, 0.7) * exp(-t * 26.0) * 1.1 + sin(TAU * 90.0 * t) * exp(-t * 25.0) * 0.6],
		"shot_smg": [0.15, func(t, st): return _noise(st, 0.8) * exp(-t * 38.0) + sin(TAU * 160.0 * t) * exp(-t * 40.0) * 0.4],
		"shot_shotgun": [0.5, func(t, st): return _noise(st, 0.35) * exp(-t * 9.0) * 1.2 + sin(TAU * 60.0 * t) * exp(-t * 12.0) * 0.8],
		"shot_sniper": [0.7, func(t, st): return _noise(st, 0.3) * exp(-t * 6.0) * 1.2 + sin(TAU * 50.0 * t) * exp(-t * 8.0)],
		"shot_plasma": [0.45, func(t, _st): return sin(TAU * (1400.0 - 2400.0 * t) * t) * exp(-t * 7.0) * 0.7],
		"reload": [0.5, func(t, st): return _noise(st, 1.0) * (exp(-t * 90.0) + exp(-maxf(t - 0.32, 0.0) * 90.0) * float(t > 0.32)) * 0.7],
		"empty": [0.06, func(t, _st): return sin(TAU * 1800.0 * t) * exp(-t * 90.0) * 0.5],
		"hit": [0.07, func(t, _st): return sin(TAU * 2300.0 * t) * exp(-t * 70.0) * 0.45],
		"headshot": [0.12, func(t, _st): return (sin(TAU * 2300.0 * t) + sin(TAU * 3100.0 * t)) * exp(-t * 40.0) * 0.35],
		"buy": [0.3, func(t, _st): return _square(t, 880.0 if t < 0.12 else 1320.0) * exp(-fmod(t, 0.12) * 12.0) * 0.25],
		"deny": [0.3, func(t, _st): return _square(t, 110.0) * 0.25 * (1.0 - t / 0.3)],
		"board_break": [0.35, func(t, st): return _noise(st, 0.5) * exp(-t * 14.0) + sin(TAU * 110.0 * t) * exp(-t * 20.0) * 0.6],
		"board_repair": [0.22, func(t, st): return sin(TAU * 170.0 * t) * exp(-t * 22.0) * 0.8 + _noise(st, 1.0) * exp(-t * 50.0) * 0.4],
		"groan": [1.1, func(t, st): return (_saw(t, 85.0 + 25.0 * sin(TAU * 3.5 * t)) * 0.45 + _noise(st, 0.1) * 0.25) * sin(PI * t / 1.1)],
		"zombie_attack": [0.45, func(t, st): return (_saw(t, 130.0 - 60.0 * t) * 0.5 + _noise(st, 0.3) * 0.5) * sin(PI * t / 0.45)],
		"dog_bark": [0.3, func(t, st): return (_saw(t, 420.0 - 600.0 * t) * 0.5 + _noise(st, 0.4) * 0.3) * exp(-t * 9.0)],
		"player_hurt": [0.35, func(t, st): return (sin(TAU * 75.0 * t) * 0.8 + _noise(st, 0.2) * 0.4) * exp(-t * 8.0)],
		"round_start": [3.0, func(t, _st): return (sin(TAU * 98.0 * t) + sin(TAU * 146.8 * t) * 0.7 + sin(TAU * 196.0 * t) * 0.3 * (0.5 + 0.5 * sin(TAU * 5.0 * t))) * 0.25 * sin(PI * t / 3.0)],
		"round_end": [2.5, func(t, _st): return (sin(TAU * (220.0 - 50.0 * t) * t) + sin(TAU * (330.0 - 80.0 * t) * t) * 0.5) * 0.25 * sin(PI * t / 2.5)],
		"powerup": [0.6, func(t, _st): return sin(TAU * [523.0, 659.0, 784.0, 1046.0][mini(int(t / 0.15), 3)] * t) * 0.35 * exp(-fmod(t, 0.15) * 8.0)],
		"powerup_spawn": [0.6, func(t, _st): return sin(TAU * (900.0 + 300.0 * sin(TAU * 12.0 * t)) * t) * 0.2 * (1.0 - t / 0.6)],
		"box_jingle": [3.6, func(t, _st): return sin(TAU * [784.0, 659.0, 523.0, 659.0, 784.0, 1046.0, 988.0, 784.0, 659.0, 587.0, 523.0, 523.0, 659.0, 784.0][mini(int(t / 0.26), 13)] * t) * 0.3 * exp(-fmod(t, 0.26) * 9.0)],
		"perk_drink": [1.0, func(t, st): return (_noise(st, 0.2) * 0.5 + sin(TAU * 220.0 * t) * 0.3) * absf(sin(TAU * 4.0 * t)) * (1.0 - t)],
		"power_on": [1.8, func(t, _st): return (_saw(t, 50.0 + 60.0 * t) * 0.3 + sin(TAU * 120.0 * t) * 0.3) * minf(t * 2.0, 1.0) * (1.0 - t / 1.8)],
		"explosion": [1.2, func(t, st): return _noise(st, 0.25) * exp(-t * 4.0) * 1.3 + sin(TAU * 45.0 * t) * exp(-t * 5.0)],
		"door_open": [1.0, func(t, st): return (_noise(st, 0.08) * 0.8 + _saw(t, 55.0) * 0.2) * sin(PI * t)],
		"knife": [0.18, func(t, st): return _noise(st, 0.6) * sin(PI * t / 0.18) * 0.6],
		"down": [1.6, func(t, _st): return sin(TAU * (200.0 - 100.0 * t) * t) * 0.35 * (1.0 - t / 1.6)],
		"grenade_throw": [0.2, func(t, st): return _noise(st, 0.3) * sin(PI * t / 0.2) * 0.4],
	}
	defs["footstep"] = [0.08, func(t, st): return _noise(st, 0.3) * exp(-t * 60.0) * 0.3]
	defs["monkey_cymbal"] = [0.25, func(t, st): return (sin(TAU * 2900.0 * t) * 0.4 + sin(TAU * 4370.0 * t) * 0.3 + _noise(st, 0.9) * 0.5) * exp(-t * 14.0)]
	defs["boss_roar"] = [1.5, func(t, st): return (_saw(t, 60.0 + 20.0 * sin(TAU * 6.0 * t)) * 0.6 + _noise(st, 0.15) * 0.4) * sin(PI * t / 1.5)]
	defs["shotgun_pump"] = [0.3, func(t, st): return _noise(st, 0.8) * (exp(-t * 60.0) + exp(-maxf(t - 0.15, 0.0) * 60.0) * float(t > 0.15)) * 0.6]
	defs["spit"] = [0.4, func(t, st): return (_noise(st, 0.35) * sin(PI * t / 0.4) * 0.5 + sin(TAU * (260.0 - 300.0 * t) * t) * 0.25 * exp(-t * 8.0))]
	defs["acid_hit"] = [0.25, func(t, st): return (_noise(st, 0.5) * 0.6 + sin(TAU * 180.0 * t) * 0.2) * exp(-t * 18.0)]
	defs["scream"] = [1.4, func(t, st): return (_saw(t, 880.0 + 260.0 * sin(TAU * 7.0 * t)) * 0.45 + _saw(t, 1330.0) * 0.2 + _noise(st, 0.5) * 0.25) * sin(PI * t / 1.4)]
	defs["beep"] = [0.09, func(t, _st): return sin(TAU * 1700.0 * t) * exp(-t * 25.0) * 0.5]
	defs["ui_hover"] = [0.05, func(t, _st): return sin(TAU * 1200.0 * t) * exp(-t * 80.0) * 0.25]
	defs["ui_click"] = [0.25, func(t, st): return (sin(TAU * 90.0 * t) * 0.7 + _noise(st, 0.5) * 0.3) * exp(-t * 18.0)]
	# Boucles (périodes entières sur la durée pour un bouclage sans clic)
	defs["menu_music"] = [8.0, func(t, st): return (
		sin(TAU * 55.0 * t) * 0.32 + sin(TAU * 82.5 * t) * 0.16 * (0.6 + 0.4 * sin(TAU * t / 8.0))
		+ sin(TAU * 110.0 * t + sin(TAU * 0.25 * t) * 2.0) * 0.06
		+ sin(TAU * 659.25 * t) * 0.05 * exp(-fmod(t, 4.0) * 1.5) * float(fmod(t, 4.0) > 0.0)
		+ _noise(st, 0.04) * 0.18 * (0.5 + 0.5 * sin(TAU * t / 4.0)))]
	defs["ambience"] = [10.0, func(t, st): return (
		_noise(st, 0.03) * 0.3 * (0.55 + 0.45 * sin(TAU * t / 5.0))
		+ sin(TAU * 41.0 * t) * 0.08 * (0.5 + 0.5 * sin(TAU * t / 10.0)))]
	for sound in defs:
		var loaded := _load_files(sound)
		if loaded.is_empty():
			var w := _synth(defs[sound][0], defs[sound][1])
			if sound in ["menu_music", "ambience"]:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = w.data.size() / 2
			loaded.append(w)
		_streams[sound] = loaded
	# Voix de l'annonceur (fichiers uniquement, pas de version synthétisée)
	for v in VOICES:
		var vl := _load_files("voice_" + v)
		if not vl.is_empty():
			_streams["voice_" + v] = vl
	# Les vraies musiques en .ogg doivent boucler
	for m in ["menu_music", "ambience"]:
		for s in _streams[m]:
			if s is AudioStreamOggVorbis:
				s.loop = true


func _load_files(sound: String) -> Array:
	var out := []
	for i in 10:
		var base: String = SOUND_DIR + sound + ("" if i == 0 else "_%d" % i)
		var found := false
		for ext in ["ogg", "wav", "mp3"]:
			if ResourceLoader.exists(base + "." + ext):
				out.append(load(base + "." + ext))
				found = true
				break
		if not found and i > 0:
			break
	return out


func _synth(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var st := [0.0]
	for i in n:
		var t := float(i) / RATE
		var v := clampf(fn.call(t, st), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Bruit filtré passe-bas (smooth : 1 = bruit blanc, proche de 0 = grave).
static func _noise(st: Array, smooth: float) -> float:
	st[0] = lerpf(st[0], randf_range(-1.0, 1.0), smooth)
	return st[0] / sqrt(smooth)


static func _square(t: float, f: float) -> float:
	return 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0


static func _saw(t: float, f: float) -> float:
	return fmod(t * f, 1.0) * 2.0 - 1.0
