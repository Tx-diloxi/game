extends RefCounted
## Carte 2 : « Laboratoire Sigma ». Quatre zones le long de l'axe X :
## 0 accueil (x -10..10) → 1 couloir (x 10..28) → 2 salle des cuves (x 28..52, z -14..14)
## → 3 réacteur (x 34..46, z -30..-14). Un téléporteur relie l'accueil au réacteur ;
## trois fioles cachées et la console du réacteur forment la quête secrète.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const Mat := preload("res://scripts/util/materials.gd")
const Effects := preload("res://scripts/util/effects.gd")
const MapArt := preload("res://scripts/game/map_art.gd")
const TeleporterScript := preload("res://scripts/interactables/teleporter.gd")
const VialScript := preload("res://scripts/interactables/vial.gd")
const TerminalScript := preload("res://scripts/interactables/terminal.gd")
const ReactorScript := preload("res://scripts/interactables/reactor_console.gd")

const ROOMS := [
	[0, Rect2(-10, -8, 20, 16)],
	[1, Rect2(10, -3, 18, 6)],
	[2, Rect2(28, -14, 24, 28)],
	[3, Rect2(34, -30, 12, 16)],
]
const START := Vector3(0, 0.1, 0)

var g: Node3D
var art: MapArt
var H := 4.0


func _init(game: Node3D) -> void:
	g = game
	H = game.H
	art = MapArt.new(game, game.nav, H)


func build() -> void:
	_environment()
	var steel := Mat.concrete_wall()
	var tiles := Mat.bricks()
	# Sols intérieurs
	g._floor(Vector2(0, 0), Vector2(20.4, 16.4), g.m_floor, true)
	g._floor(Vector2(19, 0), Vector2(18.4, 6.4), g.m_floor, true)
	g._floor(Vector2(40, 0), Vector2(24.4, 28.4), g.m_floor, true)
	g._floor(Vector2(40, -22), Vector2(12.4, 16.4), g.m_floor, true)
	# Extérieurs
	g._floor(Vector2(-1.5, -11), Vector2(23, 6), g.m_dirt, false)
	g._floor(Vector2(-1.5, 11), Vector2(23, 6), g.m_dirt, false)
	g._floor(Vector2(19, 6), Vector2(12, 6), g.m_dirt, false)
	g._floor(Vector2(40, 17), Vector2(24, 6), g.m_dirt, false)
	g._floor(Vector2(55, 0), Vector2(6, 20), g.m_dirt, false)
	g._floor(Vector2(40, -33), Vector2(14, 6), g.m_dirt, false)

	# Accueil (zone 0) : fenêtres au nord et au sud, porte vers le couloir à l'est
	g._wall_x(-8, -10, 10, [[-5.0, 1.6, 2.4], [5.0, 1.6, 2.4]])
	g._wall_x(8, -10, 10, [[-5.0, 1.6, 2.4], [5.0, 1.6, 2.4]])
	g._wall_z(-10, -8, 8, [])
	g._wall_z(10, -8, 8, [[0.0, 3.0, 3.0]])
	# Couloir (zone 1) : une fenêtre au sud
	g._wall_x(-3, 10, 28, [], steel)
	g._wall_x(3, 10, 28, [[19.0, 1.6, 2.4]], steel)
	# Salle des cuves (zone 2)
	g._wall_z(28, -14, 14, [[0.0, 3.0, 3.0]], tiles)
	g._wall_x(-14, 28, 52, [[40.0, 3.0, 3.0]], tiles)
	g._wall_x(14, 28, 52, [[34.0, 1.6, 2.4], [46.0, 1.6, 2.4]], tiles)
	g._wall_z(52, -14, 14, [[-6.0, 1.6, 2.4], [6.0, 1.6, 2.4]], tiles)
	# Réacteur (zone 3)
	g._wall_z(34, -30, -14, [], steel)
	g._wall_z(46, -30, -14, [], steel)
	g._wall_x(-30, 34, 46, [[37.0, 1.6, 2.4], [43.0, 1.6, 2.4]], steel)
	for r in [Rect2(-10, -8, 20, 16), Rect2(10, -3, 18, 6), Rect2(28, -14, 24, 28), Rect2(34, -30, 12, 16)]:
		g._baseboard(r)

	# Clôtures extérieures
	g._fence_x(-14, -13, 10)
	g._fence_z(-13, -14, -8)
	g._fence_z(10, -14, -8)
	g._fence_x(14, -13, 10)
	g._fence_z(-13, 8, 14)
	g._fence_z(10, 8, 14)
	g._fence_x(9, 13, 25)
	g._fence_z(13, 3, 9)
	g._fence_z(25, 3, 9)
	g._fence_x(20, 28, 52)
	g._fence_z(28, 14, 20)
	g._fence_z(52, 14, 20)
	g._fence_x(-10, 52, 58)
	g._fence_x(10, 52, 58)
	g._fence_z(58, -10, 10)
	g._fence_x(-36, 33, 47)
	g._fence_z(33, -36, -30)
	g._fence_z(47, -36, -30)

	# Barricades
	g._barricade(Vector3(-5, 0, -8), Vector3.BACK, 0)
	g._barricade(Vector3(5, 0, -8), Vector3.BACK, 0)
	g._barricade(Vector3(-5, 0, 8), Vector3.FORWARD, 0)
	g._barricade(Vector3(5, 0, 8), Vector3.FORWARD, 0)
	g._barricade(Vector3(19, 0, 3), Vector3.FORWARD, 1)
	g._barricade(Vector3(34, 0, 14), Vector3.FORWARD, 2)
	g._barricade(Vector3(46, 0, 14), Vector3.FORWARD, 2)
	g._barricade(Vector3(52, 0, -6), Vector3.LEFT, 2)
	g._barricade(Vector3(52, 0, 6), Vector3.LEFT, 2)
	g._barricade(Vector3(37, 0, -30), Vector3.BACK, 3)
	g._barricade(Vector3(43, 0, -30), Vector3.BACK, 3)

	# Portes
	g._door(Vector3(10, 0, 0), 750, 1, Vector3.RIGHT)
	g._door(Vector3(28, 0, 0), 1000, 2, Vector3.RIGHT)
	g._door(Vector3(40, 0, -14), 1250, 3, Vector3.BACK)

	# Armes murales
	g._wall_buy(Vector3(9.79, 0, -5), Vector3.LEFT, "carabine", 500)
	g._wall_buy(Vector3(2, 0, 7.79), Vector3.FORWARD, "vipere", 1000)
	g._wall_buy(Vector3(24, 0, -2.79), Vector3.BACK, "brise_porte", 1200)
	g._wall_buy(Vector3(51.79, 0, -11), Vector3.LEFT, "k74", 1400)
	g._wall_buy(Vector3(40, 0, 13.79), Vector3.FORWARD, "tonnerre", 1500)
	g._wall_buy(Vector3(45.79, 0, -18), Vector3.LEFT, "longue_vue", 1700)
	g._wall_buy(Vector3(-1.5, 0, 7.79), Vector3.FORWARD, "revolver", 600)
	g._wall_buy(Vector3(12.5, 0, 2.79), Vector3.FORWARD, "frelon", 1100)
	g._wall_buy(Vector3(45.79, 0, -22), Vector3.LEFT, "eclaireur", 1600)
	g._wall_buy(Vector3(34.21, 0, -26), Vector3.RIGHT, "spectre", 1800)

	# Atouts
	g._perk(Vector3(9.35, 0, 5), Vector3.LEFT, "second_souffle")
	g._perk(Vector3(-9.35, 0, 5), Vector3.RIGHT, "oeil_de_lynx")
	g._perk(Vector3(15, 0, -2.35), Vector3.BACK, "cuirasse")
	g._perk(Vector3(28.65, 0, -8), Vector3.RIGHT, "main_leste")
	g._perk(Vector3(28.65, 0, 8), Vector3.RIGHT, "pied_leger")
	g._perk(Vector3(32, 0, -13.35), Vector3.BACK, "mains_d_or")
	g._perk(Vector3(51.35, 0, 0), Vector3.LEFT, "triple_etui")
	g._perk(Vector3(34.65, 0, -22), Vector3.RIGHT, "ravitailleur")
	g._perk(Vector3(34.65, 0, -18), Vector3.RIGHT, "bouclier")
	g._perk(Vector3(51.35, 0, 11), Vector3.LEFT, "tonique_eclair")
	g._perk(Vector3(-9.35, 0, -1), Vector3.RIGHT, "gilet")
	g._perk(Vector3(0, 0, -7.35), Vector3.BACK, "sprinteur")

	# Courant, amélioration, piège
	g._place(g.PowerScript.new(), g.nav, Vector3(50, 0, -13.79), Vector3.BACK)
	g._place(g.UpgradeScript.new(), g.nav, Vector3(46, 0, -13.79), Vector3.BACK)
	g._trap(Vector3(16, 0, 2.79), Vector3.FORWARD, "electric", 1000, Vector3(19, 1.0, 0), Vector3(7.0, 2.0, 5.0))

	# Boîte mystère : 3 emplacements
	g.box_locations.append(g._facing_transform(Vector3(0, 0, -7.3), Vector3.BACK))
	g.box_locations.append(g._facing_transform(Vector3(12.5, 0, -2.3), Vector3.BACK))
	g.box_locations.append(g._facing_transform(Vector3(51.3, 0, -3.5), Vector3.LEFT))
	g.box = g.BoxScript.new()
	g.add_child(g.box)
	g.box.global_transform = g.box_locations[0]

	# Téléporteur, notes et quête secrète
	var pad_a := TeleporterScript.new()
	pad_a.zone = 0
	g._place(pad_a, g, Vector3(-7.5, 0, 0), Vector3.RIGHT)
	var pad_b := TeleporterScript.new()
	pad_b.zone = 3
	g._place(pad_b, g, Vector3(37.5, 0, -19.5), Vector3.BACK)
	pad_a.partner = pad_b
	pad_b.partner = pad_a
	g._place(TerminalScript.new(), g, Vector3(-9.6, 0, -2.5), Vector3.RIGHT)
	g._place(ReactorScript.new(), g, Vector3(45.79, 0, -25), Vector3.LEFT)
	g._radio(Vector3(-9.6, 0, -5.0), Vector3.RIGHT, 4)
	_vial(Vector3(-6.3, 0.1, 6.2))
	_vial(Vector3(22.4, 0.1, 2.5))
	_vial(Vector3(50.6, 0.1, 12.7))

	_decorate()


func _vial(pos: Vector3) -> void:
	var v := VialScript.new()
	g.add_child(v)
	v.global_position = pos


func _environment() -> void:
	g.env.fog_light_color = Color(0.03, 0.06, 0.07)
	g.env.ambient_light_color = Color(0.4, 0.55, 0.6)
	g.env.ambient_light_energy = 0.34


# --- Décor ---------------------------------------------------------------

func _decorate() -> void:
	var cold := Color(0.78, 0.92, 1.0)
	# Accueil
	for x in [-6.0, 0.0, 6.0]:
		art._beam(Vector3(x, H - 0.2, 0), Vector3(0.3, 0.35, 16.0))
	g.register_light(art._hanging_lamp(Vector3(0, H, 0), cold, 2.4, 15.0, true, true))
	g.register_light(art._hanging_lamp(Vector3(-6, H, 5), cold, 1.0, 9.0, true, false))
	art._table(Vector3(-6.0, 0, 6.5), 0.2)
	art._table(Vector3(-3.0, 0, -6.2), 0.0)
	art._crate(Vector3(7.5, 0, -6.5), Vector3(1.0, 1.0, 1.0), 0.2)
	art._barrel(Vector3(8.8, 0, 6.8), true)
	art._shelf(Vector3(-9.45, 0, -5.5), PI * 0.5)
	art._sign(Vector3(0, 3.3, -7.79), Vector3.BACK, "LABORATOIRE SIGMA", 70, Color(0.7, 0.85, 0.9))
	art._sign(Vector3(-9.79, 2.9, 3.0), Vector3.RIGHT, "TÉLÉPORTEUR", 60, Color(0.5, 0.9, 1.0))
	for p in [Vector3(-3, 0, 3), Vector3(4, 0, -2), Vector3(6, 0, 5)]:
		Effects.blood_decal(g, p, randf_range(0.8, 1.6))
	Effects.dust(g, Vector3(0, 2.0, 0), Vector3(9, 1.8, 7))

	# Couloir
	for x in [13.0, 17.0, 21.0, 25.0]:
		art._beam(Vector3(x, H - 0.2, 0), Vector3(0.3, 0.3, 6.0))
	art._pipe(Vector3(10, 3.5, -2.65), Vector3(28, 3.5, -2.65), 0.1, Mat.rust())
	art._pipe(Vector3(10, 3.2, 2.7), Vector3(28, 3.2, 2.7), 0.06, Mat.metal())
	g.register_light(art._hanging_lamp(Vector3(19, H, 0), cold, 1.3, 11.0, true, true))
	g.register_power_light(art._cage_lamp(Vector3(13, 3.55, 0), Vector3.RIGHT, Color(0.85, 0.95, 1.0), 9.0))
	g.register_power_light(art._cage_lamp(Vector3(25, 3.55, 0), Vector3.LEFT, Color(0.85, 0.95, 1.0), 9.0))
	art._crate(Vector3(22.9, 0, 2.2), Vector3(0.9, 0.9, 0.9), 0.3)
	art._crate(Vector3(22.0, 0, 2.55), Vector3(0.7, 0.7, 0.7), -0.2)
	art._barrel(Vector3(26.8, 0, -2.2), false)
	art._sign(Vector3(15, 2.9, -2.79), Vector3.BACK, "SECTEUR B", 56, Color(0.7, 0.85, 0.9))
	Effects.blood_decal(g, Vector3(18, 0, -1), 1.4)
	Effects.dust(g, Vector3(19, 2.0, 0), Vector3(8, 1.8, 2.5))

	# Salle des cuves
	for z in [-9.0, 0.0, 9.0]:
		art._beam(Vector3(40, H - 0.2, z), Vector3(24.0, 0.4, 0.35))
	for p in [Vector3(33, H, -6), Vector3(47, H, -6), Vector3(33, H, 7), Vector3(47, H, 7), Vector3(40, H, 0)]:
		g.register_power_light(art._hanging_lamp(p, Color(0.8, 0.95, 1.0), 0.0, 14.0, false, p.z < -2.0))
	g.register_emergency(art._beacon(Vector3(40, 3.6, -12.5)))
	for p in [Vector3(33, 0, -9), Vector3(37, 0, -9), Vector3(44, 0, -9), Vector3(33.5, 0, 9), Vector3(44.5, 0, 9.5)]:
		_vat(p)
	_vat(Vector3(49.5, 0, 12.5))
	art._table(Vector3(40, 0, 5.5), 0.0)
	art._table(Vector3(40, 0, -5.5), 0.0, true)
	art._crate(Vector3(30.5, 0, 12.0), Vector3(1.1, 1.1, 1.1), 0.3)
	art._barrel(Vector3(31.6, 0, 12.6), true)
	art._sign(Vector3(40, 3.3, -13.79), Vector3.BACK, "ACCÈS RÉACTEUR", 64, Color(0.9, 0.6, 0.2))
	art._sign(Vector3(51.79, 3.1, 8.5), Vector3.LEFT, "CUVES", 70, Color(0.7, 0.85, 0.9))
	for p in [Vector3(36, 0, 2), Vector3(44, 0, -3), Vector3(31, 0, -2), Vector3(48, 0, 4)]:
		Effects.blood_decal(g, p, randf_range(1.0, 2.2))
	Effects.dust(g, Vector3(40, 2.0, 0), Vector3(11, 1.8, 12))

	# Réacteur
	g.register_power_light(art._hanging_lamp(Vector3(37, H, -26), Color(0.7, 1.0, 0.85), 0.0, 12.0, false, false))
	g.register_power_light(art._hanging_lamp(Vector3(43, H, -18), Color(0.7, 1.0, 0.85), 0.0, 12.0, false, false))
	_core(Vector3(40, 0, -22))
	art._sign(Vector3(40, 3.3, -29.79), Vector3.BACK, "RÉACTEUR Σ", 80, Color(0.5, 1.0, 0.8))
	Effects.blood_decal(g, Vector3(38, 0, -19), 1.5)
	Effects.dust(g, Vector3(40, 2.0, -22), Vector3(5, 1.8, 7))

	# Extérieur
	for p in [Vector3(-12, 0, -12.5), Vector3(-12.5, 0, 12.5), Vector3(56.5, 0, 9), Vector3(46, 0, -35)]:
		art._dead_tree(p)
	for p in [Vector3(5, 0, -12.5), Vector3(0, 0, 12.5), Vector3(20, 0, 8.5), Vector3(36, 0, 19)]:
		art._debris(p)


## Cuve de culture : verre, liquide luminescent et couvercle.
func _vat(pos: Vector3) -> void:
	var body := MeshUtil.static_box(g.nav, Vector3(1.5, 3.2, 1.5), pos + Vector3(0, 1.6, 0), null, GameManager.L_WORLD)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.45, 0.9, 0.55, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(0.2, 0.9, 0.35)
	glass.emission_energy_multiplier = 1.4
	glass.roughness = 0.1
	MeshUtil.cylinder_mesh(body, 0.7, 2.6, Vector3(0, 0.0, 0), glass)
	MeshUtil.cylinder_mesh(body, 0.78, 0.25, Vector3(0, 1.45, 0), Mat.metal(Color(0.35, 0.37, 0.4)))
	MeshUtil.cylinder_mesh(body, 0.78, 0.25, Vector3(0, -1.45, 0), Mat.metal(Color(0.35, 0.37, 0.4)))
	var l := OmniLight3D.new()
	l.light_color = Color(0.3, 1.0, 0.45)
	l.light_energy = 0.7
	l.omni_range = 4.5
	l.position = Vector3(0, 0.2, 0)
	l.set_meta("base", 0.7)
	l.set_meta("flicker", true)
	body.add_child(l)
	g.register_light(l)


## Cœur du réacteur : colonne lumineuse avec anneaux.
func _core(pos: Vector3) -> void:
	var body := MeshUtil.static_box(g.nav, Vector3(2.6, 3.6, 2.6), pos + Vector3(0, 1.8, 0), null, GameManager.L_WORLD)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.15, 0.7, 0.6, 0.6)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(0.2, 1.0, 0.8)
	glow.emission_energy_multiplier = 1.1
	MeshUtil.cylinder_mesh(body, 0.55, 3.2, Vector3.ZERO, glow)
	for y in [-1.4, 0.0, 1.4]:
		MeshUtil.cylinder_mesh(body, 1.25, 0.14, Vector3(0, y, 0), Mat.metal(Color(0.3, 0.33, 0.36)))
	var l := OmniLight3D.new()
	l.light_color = Color(0.3, 1.0, 0.85)
	l.light_energy = 1.6
	l.omni_range = 11.0
	l.position = Vector3(0, 0.5, 0)
	body.add_child(l)
