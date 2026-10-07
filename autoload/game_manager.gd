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

# Couches physiques (valeurs de bits)
const L_WORLD := 1
const L_PLAYER := 2
const L_ZOMBIE := 4
const L_PLAYER_BLOCK := 8

const MAX_PERKS := 4
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
}

const POWERUPS := {
	"max_ammo": {"name": "MUNITIONS MAX", "color": Color(0.3, 1.0, 0.3), "letter": "M"},
	"insta_kill": {"name": "MORT INSTANTANÉE", "color": Color(0.95, 0.95, 0.95), "letter": "☠"},
	"nuke": {"name": "BOMBE", "color": Color(1.0, 0.3, 0.1), "letter": "B"},
	"double_points": {"name": "POINTS x2", "color": Color(1.0, 0.85, 0.1), "letter": "x2"},
	"carpenter": {"name": "CHARPENTIER", "color": Color(0.9, 0.55, 0.2), "letter": "C"},
}
const POWERUP_DURATION := 30.0

var points := 500
var round_num := 0
var kills := 0
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

## Référence vers la scène de jeu courante (scenes/game.gd).
var game: Node = null


func _ready() -> void:
	_setup_input()
	_load_settings()


func _process(delta: float) -> void:
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

func add_points(amount: int, allow_double := true) -> void:
	if allow_double and is_powerup_active("double_points"):
		amount *= 2
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
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	save_settings()


func set_fov(v: float) -> void:
	fov = v
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = cfg.get_value("controls", "sensitivity", mouse_sensitivity)
		master_volume = cfg.get_value("audio", "volume", master_volume)
		fov = cfg.get_value("video", "fov", fov)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	if fullscreen and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))


# --- Contrôles ------------------------------------------------------------
# Touches physiques : ZQSD sur AZERTY = WASD sur QWERTY.

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
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)


func _key(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
