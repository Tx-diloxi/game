extends Node
## État global de la partie : points, manche, atouts, power-ups, réglages.

signal points_changed(points: int)
signal points_popup(amount: int)
signal round_changed(round_num: int)
signal powerups_changed
signal power_changed(on: bool)
signal perks_changed
signal message(text: String, color: Color, sub: String)

const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const SETTINGS_PATH := "user://settings.cfg"
var records_path := "user://records.cfg"
const FPS_LIMITS := [0, 30, 60, 90, 120, 144, 240]
const RESOLUTIONS := [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const MSAA_MODES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]

# Couches physiques (valeurs de bits)
const L_WORLD := 1
const L_PLAYER := 2
const L_ZOMBIE := 4
const L_PLAYER_BLOCK := 8

const MAX_PERKS := 6
const PERKS := {
	"cuirasse": {"name": "Cuirasse", "price": 2500, "color": Color(0.85, 0.1, 0.1), "letter": "C", "power": true,
		"desc": "Santé x2,5"},
	"main_leste": {"name": "Main Leste", "price": 3000, "color": Color(0.1, 0.75, 0.25), "letter": "M", "power": true,
		"desc": "Rechargement 2x plus rapide"},
	"tonique_eclair": {"name": "Tonique Éclair", "price": 2000, "color": Color(0.95, 0.8, 0.1), "letter": "T", "power": true,
		"desc": "Cadence de tir +33 %"},
	"second_souffle": {"name": "Second Souffle", "price": 500, "color": Color(0.2, 0.5, 1.0), "letter": "S", "power": false,
		"desc": "Réanimation automatique"},
	"triple_etui": {"name": "Triple Étui", "price": 4000, "color": Color(0.6, 0.2, 0.9), "letter": "3", "power": true,
		"desc": "Une troisième arme"},
	"oeil_de_lynx": {"name": "Œil de Lynx", "price": 2000, "color": Color(1.0, 0.55, 0.1), "letter": "L", "power": true,
		"desc": "Dégâts à la tête +50 %"},
	"pied_leger": {"name": "Pied Léger", "price": 2000, "color": Color(0.1, 0.8, 0.85), "letter": "P", "power": true,
		"desc": "Déplacement +20 %"},
	"mains_d_or": {"name": "Mains d'Or", "price": 3000, "color": Color(0.95, 0.85, 0.3), "letter": "$", "power": true,
		"desc": "Points gagnés +50 %"},
	"bouclier": {"name": "Bouclier", "price": 2500, "color": Color(0.55, 0.6, 0.7), "letter": "B", "power": true,
		"desc": "Immunité aux explosions, soin rapide"},
	"ravitailleur": {"name": "Ravitailleur", "price": 2000, "color": Color(0.5, 0.75, 0.3), "letter": "R", "power": true,
		"desc": "Réserves de munitions +50 %"},
}

const POWERUPS := {
	"max_ammo": {"name": "MUNITIONS MAX", "color": Color(0.3, 1.0, 0.3), "letter": "M"},
	"insta_kill": {"name": "MORT INSTANTANÉE", "color": Color(0.95, 0.95, 0.95), "letter": "☠"},
	"nuke": {"name": "BOMBE", "color": Color(1.0, 0.3, 0.1), "letter": "B"},
	"double_points": {"name": "POINTS x2", "color": Color(1.0, 0.85, 0.1), "letter": "x2"},
	"fire_sale": {"name": "FEU DE VENTE", "color": Color(1.0, 0.45, 0.1), "letter": "10"},
	"bonus_points": {"name": "BONUS DE POINTS", "color": Color(1.0, 0.95, 0.4), "letter": "+"},
	"zombie_blood": {"name": "SANG DE ZOMBIE", "color": Color(0.3, 0.55, 1.0), "letter": "Z"},
	"infinite_ammo": {"name": "MUNITIONS ILLIMITÉES", "color": Color(0.2, 0.9, 0.95), "letter": "A"},
	"last_stand": {"name": "DERNIER SURVIVANT", "color": Color(1.0, 0.55, 0.7), "letter": "+1"},
	"carpenter": {"name": "CHARPENTIER", "color": Color(0.9, 0.55, 0.2), "letter": "C"},
}
const POWERUP_DURATION := 30.0

var points := 500
var round_num := 0
var kills := 0
## Statistiques de la partie (tableau des scores).
var shots_fired := 0
var shots_hit := 0
var play_time := 0.0
var perks_bought := 0
var gamepad := false
var seen_kinds := {}
var extra_lives := 0
var _rage_until := 0.0
var headshots := 0
var total_points := 0
var power_on := false
var perks: Array[String] = []
var active_powerups := {}
var drops_this_round := 0
var in_game := false
## Vrai quand la scène de jeu sert de décor au menu principal.
var menu_mode := false

var mouse_sensitivity := 0.12
var master_volume := 0.8
var fov := 75.0
var fullscreen := false
var music_volume := 0.8
var sfx_volume := 1.0
var voice_volume := 1.0
var vsync := true
var max_fps_index := 0
var shadow_quality := 3
var msaa_index := 1 # 0 = aucun, 1 = 2x, 2 = 4x, 3 = 8x
var res_index := 1
var render_scale := 1.0
## Touches personnalisées : {action: {"key": [type, valeur…], "pad": [type, valeur…]}}
var custom_bindings := {}
var last_beaten := {}

## Référence vers la scène de jeu courante (scenes/game.gd).
var game: Node = null


func _ready() -> void:
	_setup_input()
	_load_settings()


func _process(delta: float) -> void:
	if in_game and not menu_mode:
		play_time += delta
	if active_powerups.is_empty():
		return
	for k in active_powerups.keys():
		active_powerups[k] -= delta
		if active_powerups[k] <= 0.0:
			active_powerups.erase(k)
	powerups_changed.emit()


# --- Partie ---------------------------------------------------------------

func new_game() -> void:
	points = 500
	round_num = 0
	kills = 0
	headshots = 0
	total_points = 0
	last_beaten = {}
	seen_kinds = {}
	extra_lives = 0
	_rage_until = 0.0
	shots_fired = 0
	shots_hit = 0
	play_time = 0.0
	perks_bought = 0
	power_on = false
	perks.clear()
	active_powerups.clear()
	drops_this_round = 0
	in_game = true
	menu_mode = false
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)


func game_over() -> void:
	if not in_game:
		return
	in_game = false
	active_powerups.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	record_game()
	Audio.say("game_over")
	if game:
		game.show_game_over()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file.call_deferred(GAME_OVER_SCENE)


func to_menu() -> void:
	in_game = false
	game = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


func set_round(r: int) -> void:
	round_num = r
	drops_this_round = 0
	round_changed.emit(r)


# --- Points ---------------------------------------------------------------

## Hurlement : tous les zombies courent plus vite pendant `sec` secondes.
func start_rage(sec: float) -> void:
	_rage_until = Time.get_ticks_msec() / 1000.0 + sec


func rage_active() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _rage_until


func add_points(amount: int, allow_double := true) -> void:
	if allow_double and is_powerup_active("double_points"):
		amount *= 2
	if allow_double and amount > 0 and has_perk("mains_d_or"):
		amount = int(amount * 1.5)
	points += amount
	total_points += amount
	points_changed.emit(points)
	points_popup.emit(amount)


func can_afford(cost: int) -> bool:
	return points >= cost


func spend(cost: int) -> bool:
	if points < cost:
		Audio.play("deny")
		return false
	points -= cost
	points_changed.emit(points)
	points_popup.emit(-cost)
	Audio.play("buy")
	return true


# --- Atouts ---------------------------------------------------------------

func has_perk(id: String) -> bool:
	return perks.has(id)


func add_perk(id: String) -> void:
	if not perks.has(id):
		perks.append(id)
		perks_bought += 1
		perks_changed.emit()


func clear_perks() -> void:
	perks.clear()
	perks_changed.emit()


func set_power(on: bool) -> void:
	power_on = on
	power_changed.emit(on)


# --- Power-ups ------------------------------------------------------------

func activate_timed_powerup(kind: String) -> void:
	active_powerups[kind] = POWERUP_DURATION
	powerups_changed.emit()


func is_powerup_active(kind: String) -> bool:
	return active_powerups.has(kind)


func show_message(text: String, color := Color.WHITE, sub := "") -> void:
	message.emit(text, color, sub)


# --- Réglages -------------------------------------------------------------

func set_sensitivity(v: float) -> void:
	mouse_sensitivity = v
	save_settings()


func set_volume(v: float) -> void:
	master_volume = v
	apply_audio()
	save_settings()


func set_music_volume(v: float) -> void:
	music_volume = v
	apply_audio()
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	apply_audio()
	save_settings()


func set_voice_volume(v: float) -> void:
	voice_volume = v
	apply_audio()
	save_settings()


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	for pair in [["Music", music_volume], ["SFX", sfx_volume], ["Voice", voice_volume]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(pair[1], 0.0001)))


func set_fov(v: float) -> void:
	fov = v
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()


func set_vsync(on: bool) -> void:
	vsync = on
	apply_video()
	save_settings()


func set_max_fps(i: int) -> void:
	max_fps_index = clampi(i, 0, FPS_LIMITS.size() - 1)
	apply_video()
	save_settings()


## 0 = aucune ombre, 1 = basses, 2 = moyennes, 3 = hautes.
func set_shadow_quality(q: int) -> void:
	shadow_quality = clampi(q, 0, 3)
	apply_video()
	save_settings()


func set_msaa(i: int) -> void:
	msaa_index = clampi(i, 0, MSAA_MODES.size() - 1)
	apply_video()
	save_settings()


func set_resolution(i: int) -> void:
	res_index = clampi(i, 0, RESOLUTIONS.size() - 1)
	apply_video()
	save_settings()


func set_render_scale(v: float) -> void:
	render_scale = clampf(v, 0.5, 1.0)
	apply_video()
	save_settings()


func apply_video() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_LIMITS[max_fps_index]
	var size: int = [0, 1024, 2048, 4096][shadow_quality]
	var root := get_tree().root if is_inside_tree() else null
	if root:
		root.positional_shadow_atlas_size = size
		root.msaa_3d = MSAA_MODES[msaa_index]
		root.scaling_3d_scale = render_scale
		if not fullscreen and DisplayServer.get_name() != "headless":
			var res: Vector2i = RESOLUTIONS[res_index]
			if DisplayServer.window_get_size() != res:
				DisplayServer.window_set_size(res)
				var screen := DisplayServer.screen_get_size()
				DisplayServer.window_set_position((screen - res) / 2)
	RenderingServer.directional_shadow_atlas_set_size(maxi(size, 256), shadow_quality >= 2)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD if shadow_quality <= 1 else (RenderingServer.SHADOW_QUALITY_SOFT_LOW if shadow_quality == 2 else RenderingServer.SHADOW_QUALITY_SOFT_HIGH))
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD if shadow_quality <= 1 else (RenderingServer.SHADOW_QUALITY_SOFT_LOW if shadow_quality == 2 else RenderingServer.SHADOW_QUALITY_SOFT_HIGH))
	# Sans ombres : on coupe aussi le calcul côté lumières déjà présentes.
	for l in get_tree().get_nodes_in_group("shadow_lights") if is_inside_tree() else []:
		if l is Light3D:
			l.shadow_enabled = shadow_quality > 0 and l.get_meta("wants_shadow", true)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "voice", voice_volume)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "max_fps", max_fps_index)
	cfg.set_value("video", "shadows", shadow_quality)
	cfg.set_value("video", "msaa", msaa_index)
	cfg.set_value("video", "resolution", res_index)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("bindings", "custom", custom_bindings)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = cfg.get_value("controls", "sensitivity", mouse_sensitivity)
		master_volume = cfg.get_value("audio", "volume", master_volume)
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		voice_volume = cfg.get_value("audio", "voice", voice_volume)
		fov = cfg.get_value("video", "fov", fov)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		vsync = cfg.get_value("video", "vsync", vsync)
		max_fps_index = cfg.get_value("video", "max_fps", max_fps_index)
		shadow_quality = cfg.get_value("video", "shadows", shadow_quality)
		msaa_index = cfg.get_value("video", "msaa", msaa_index)
		res_index = cfg.get_value("video", "resolution", res_index)
		render_scale = cfg.get_value("video", "render_scale", render_scale)
		custom_bindings = cfg.get_value("bindings", "custom", {})
	if fullscreen and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	apply_audio()
	apply_video()
	_apply_custom_bindings()


# --- Records --------------------------------------------------------------

## Enregistre la partie terminée et retourne les records battus {clé: ancienne valeur}.
func record_game() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(records_path)
	var beaten := {}
	var results := {
		"best_round": round_num, "best_kills": kills, "best_points": total_points,
		"best_headshots": headshots, "best_time": int(play_time),
	}
	for k in results:
		var old: int = cfg.get_value("records", k, 0)
		if results[k] > old:
			cfg.set_value("records", k, results[k])
			if old > 0:
				beaten[k] = old
	cfg.set_value("records", "games", int(cfg.get_value("records", "games", 0)) + 1)
	cfg.save(records_path)
	last_beaten = beaten
	return beaten


func get_records() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(records_path)
	var out := {}
	for k in ["best_round", "best_kills", "best_points", "best_headshots", "best_time", "games"]:
		out[k] = int(cfg.get_value("records", k, 0))
	return out


# --- Contrôles ------------------------------------------------------------
# Touches physiques : ZQSD sur AZERTY = WASD sur QWERTY.

## Détecte le dernier périphérique utilisé (pour afficher [F] ou [Y]…).
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.6):
		gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		gamepad = false


## Remplace les noms de touches clavier d'un texte par ceux de la manette si besoin.
func hint(text: String) -> String:
	var pad := gamepad
	return text.replace("[F]", "[%s]" % action_label("interact", pad)) 		.replace("[G]", "[%s]" % action_label("grenade", pad)) 		.replace("[T]", "[%s]" % action_label("special", pad))


func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("sprint", [KEY_SHIFT])
	_key("crouch", [KEY_CTRL, KEY_C])
	_key("reload", [KEY_R])
	_key("interact", [KEY_F, KEY_E])
	_key("melee", [KEY_V])
	_key("grenade", [KEY_G])
	_key("special", [KEY_T])
	_key("weapon_1", [KEY_1])
	_key("weapon_2", [KEY_2])
	_key("weapon_3", [KEY_3])
	_key("pause", [KEY_ESCAPE, KEY_P])
	_key("scoreboard", [KEY_TAB])
	_key("look_left", [])
	_key("look_right", [])
	_key("look_up", [])
	_key("look_down", [])

	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	_setup_gamepad()
	# Navigation des menus à la manette : A valide, B annule
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var has := false
		for e in InputMap.action_get_events(pair[0]):
			if e is InputEventJoypadButton and e.button_index == pair[1]:
				has = true
		if not has:
			_pad_button(pair[0], pair[1])


func _setup_gamepad() -> void:
	# Manette (Xbox) : stick gauche = déplacement, stick droit = caméra, gâchettes = viser/tirer
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_pad_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_button("jump", JOY_BUTTON_A)
	_pad_button("crouch", JOY_BUTTON_B)
	_pad_button("reload", JOY_BUTTON_X)
	_pad_button("interact", JOY_BUTTON_Y)
	_pad_button("sprint", JOY_BUTTON_LEFT_STICK)
	_pad_button("melee", JOY_BUTTON_RIGHT_STICK)
	_pad_button("grenade", JOY_BUTTON_LEFT_SHOULDER)
	_pad_button("special", JOY_BUTTON_RIGHT_SHOULDER)
	_pad_button("weapon_next", JOY_BUTTON_DPAD_RIGHT)
	_pad_button("weapon_prev", JOY_BUTTON_DPAD_LEFT)
	_pad_button("pause", JOY_BUTTON_START)
	_pad_button("scoreboard", JOY_BUTTON_BACK)
	for a in ["move_left", "move_right", "move_forward", "move_back", "look_left", "look_right", "look_up", "look_down", "fire", "aim"]:
		InputMap.action_set_deadzone(a, 0.2)


func _pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _pad_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func vibrate(weak: float, strong: float, duration: float) -> void:
	if gamepad and Input.get_connected_joypads().size() > 0:
		Input.start_joy_vibration(Input.get_connected_joypads()[0], weak, strong, duration)


func _ensure(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)


func _key(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# --- Remappage ------------------------------------------------------------

## Actions que le joueur peut réassigner, avec leur libellé.
const REMAPPABLE := [
	["move_forward", "Avancer"], ["move_back", "Reculer"], ["move_left", "Gauche"], ["move_right", "Droite"],
	["fire", "Tirer"], ["aim", "Viser"], ["reload", "Recharger"], ["interact", "Interagir / acheter"],
	["jump", "Sauter"], ["crouch", "S'accroupir"], ["sprint", "Sprint"], ["melee", "Couteau"],
	["grenade", "Grenade"], ["special", "Singe-leurre"], ["weapon_next", "Arme suivante"], ["weapon_prev", "Arme précédente"],
	["weapon_1", "Arme 1"], ["weapon_2", "Arme 2"], ["weapon_3", "Arme 3"], ["scoreboard", "Tableau des scores"], ["pause", "Pause"],
]


func _is_pad(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


## Sérialise un événement : [type, valeurs…] (types: key, mouse, pbtn, paxis).
func _ser(ev: InputEvent) -> Array:
	if ev is InputEventKey:
		return ["key", ev.physical_keycode]
	if ev is InputEventMouseButton:
		return ["mouse", ev.button_index]
	if ev is InputEventJoypadButton:
		return ["pbtn", ev.button_index]
	if ev is InputEventJoypadMotion:
		return ["paxis", ev.axis, ev.axis_value]
	return []


func _deser(a: Array) -> InputEvent:
	match a[0]:
		"key":
			var ev := InputEventKey.new()
			ev.physical_keycode = a[1]
			return ev
		"mouse":
			var ev := InputEventMouseButton.new()
			ev.button_index = a[1]
			return ev
		"pbtn":
			var ev := InputEventJoypadButton.new()
			ev.button_index = a[1]
			return ev
		"paxis":
			var ev := InputEventJoypadMotion.new()
			ev.axis = a[1]
			ev.axis_value = a[2]
			return ev
	return null


## Remplace les touches clavier/souris (pad=false) ou manette (pad=true) d'une action.
func rebind(action: String, ev: InputEvent, pad: bool) -> void:
	var keep: Array[InputEvent] = []
	for e in InputMap.action_get_events(action):
		if _is_pad(e) != pad:
			keep.append(e)
	InputMap.action_erase_events(action)
	for e in keep:
		InputMap.action_add_event(action, e)
	var clean := ev.duplicate()
	if clean is InputEventJoypadMotion:
		clean.axis_value = signf(clean.axis_value)
	InputMap.action_add_event(action, clean)
	if not custom_bindings.has(action):
		custom_bindings[action] = {}
	custom_bindings[action]["pad" if pad else "key"] = _ser(clean)
	save_settings()


func reset_bindings() -> void:
	custom_bindings = {}
	_setup_input()
	save_settings()


func _apply_custom_bindings() -> void:
	for action in custom_bindings:
		if not InputMap.has_action(action):
			continue
		for kind in custom_bindings[action]:
			var ev := _deser(custom_bindings[action][kind])
			if ev == null:
				continue
			var pad: bool = kind == "pad"
			var keep: Array[InputEvent] = []
			for e in InputMap.action_get_events(action):
				if _is_pad(e) != pad:
					keep.append(e)
			InputMap.action_erase_events(action)
			for e in keep:
				InputMap.action_add_event(action, e)
			InputMap.action_add_event(action, ev)


const PAD_BUTTON_NAMES := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "Retour", 6: "Start", 7: "Clic stick G", 8: "Clic stick D",
	9: "LB", 10: "RB", 11: "Croix ↑", 12: "Croix ↓", 13: "Croix ←", 14: "Croix →"}
const PAD_AXIS_NAMES := {0: "Stick G", 1: "Stick G", 2: "Stick D", 3: "Stick D", 4: "LT", 5: "RT"}


func event_name(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: Key = ev.physical_keycode
		if DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
		return OS.get_keycode_string(code if code != KEY_NONE else ev.physical_keycode)
	if ev is InputEventMouseButton:
		return {1: "Clic gauche", 2: "Clic droit", 3: "Clic molette", 4: "Molette ↑", 5: "Molette ↓"}.get(ev.button_index, "Souris %d" % ev.button_index)
	if ev is InputEventJoypadButton:
		return PAD_BUTTON_NAMES.get(ev.button_index, "Bouton %d" % ev.button_index)
	if ev is InputEventJoypadMotion:
		var dir := ""
		if ev.axis <= 3:
			dir = (" ←" if ev.axis_value < 0 else " →") if ev.axis % 2 == 0 else (" ↑" if ev.axis_value < 0 else " ↓")
		return PAD_AXIS_NAMES.get(ev.axis, "Axe %d" % ev.axis) + dir
	return "?"


## Nom de la touche principale d'une action pour le périphérique demandé.
func action_label(action: String, pad: bool) -> String:
	for e in InputMap.action_get_events(action):
		if _is_pad(e) == pad:
			return event_name(e)
	return "—"
