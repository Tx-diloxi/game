extends Node3D
## Scène de jeu : construit la carte « Bunker abandonné », le joueur, l'interface,
## et relie les manches, les apparitions, les power-ups et les explosions.
## En mode menu (GameManager.menu_mode), sert de décor animé au menu principal.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const Mat := preload("res://scripts/util/materials.gd")
const Effects := preload("res://scripts/util/effects.gd")
const MapArt := preload("res://scripts/game/map_art.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const ZombieScript := preload("res://scripts/zombies/zombie.gd")
const RoundManagerScript := preload("res://scripts/game/round_manager.gd")
const PowerupScript := preload("res://scripts/powerups/powerup.gd")
const HudScript := preload("res://scenes/ui/hud.gd")
const PauseScript := preload("res://scenes/ui/pause_menu.gd")
const GameOverScript := preload("res://scenes/ui/game_over_overlay.gd")
const BarricadeScript := preload("res://scripts/interactables/barricade.gd")
const DoorScript := preload("res://scripts/interactables/door.gd")
const WallBuyScript := preload("res://scripts/interactables/wall_buy.gd")
const PerkScript := preload("res://scripts/interactables/perk_machine.gd")
const BoxScript := preload("res://scripts/interactables/mystery_box.gd")
const UpgradeScript := preload("res://scripts/interactables/upgrade_machine.gd")
const PowerScript := preload("res://scripts/interactables/power_switch.gd")
const TrapScript := preload("res://scripts/interactables/trap.gd")

const H := 4.0 # hauteur des murs
const T := 0.4 # épaisseur des murs
const DROP_CHANCE := 0.03
const MAX_DROPS := 4

## Zones jouables pour savoir si un bonus est atteignable.
const ROOMS := [
	[0, Rect2(-10, -10, 20, 20)],
	[1, Rect2(-3, -30, 6, 20)],
	[2, Rect2(-15, -50, 30, 20)],
]

var nav: NavigationRegion3D
var env: Environment
var player: CharacterBody3D
var hud: CanvasLayer
var rounds: Node
var barricades: Array = []
var active_zones := {0: true}
var box_locations: Array[Transform3D] = []
var box: Node3D
var menu_mode := false
## Singe-leurre actif (attire les zombies).
var decoy: Node3D = null
var _box_index := 0
var _power_lights: Array[OmniLight3D] = []
var _emergency: Array[Node3D] = []
var _flicker: Array[OmniLight3D] = []
var _menu_cam: Camera3D
var _menu_t := 0.0

var m_floor: Material
var m_wall: Material
var m_ceiling: Material
var m_dirt: Material
var m_fence: Material


func _ready() -> void:
	menu_mode = GameManager.menu_mode
	if not menu_mode:
		GameManager.game = self
		GameManager.in_game = true # permet aussi de lancer cette scène directement (F6)
	m_floor = Mat.floor_concrete()
	m_wall = Mat.plaster()
	m_ceiling = Mat.ceiling()
	m_dirt = Mat.ground()
	m_fence = Mat.dark_bricks()

	_build_environment()
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = GameManager.L_WORLD
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nav.navigation_mesh = nm
	add_child(nav)
	_build_map()
	MapArt.new(self, nav, H).decorate()

	if menu_mode:
		_setup_menu_scene()
		return

	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3(0, 0.1, 3)

	hud = HudScript.new()
	add_child(hud)
	hud.bind(player)
	player.hud = hud
	add_child(PauseScript.new())

	rounds = RoundManagerScript.new()
	rounds.game = self
	add_child(rounds)

	GameManager.power_changed.connect(_on_power)
	await get_tree().physics_frame
	_bake()


func _exit_tree() -> void:
	if GameManager.game == self:
		GameManager.game = null


func _process(delta: float) -> void:
	for l in _flicker:
		var base: float = l.get_meta("base")
		l.light_energy = base * (0.1 if randf() < 0.03 else randf_range(0.92, 1.0))
	for e in _emergency:
		if e.visible:
			e.get_node("Spin").rotate_y(delta * 3.5)
	if menu_mode:
		_update_menu_scene(delta)


func _bake() -> void:
	nav.bake_navigation_mesh(false)


# --- Environnement --------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.01, 0.015, 0.035)
	sky_mat.sky_horizon_color = Color(0.06, 0.065, 0.09)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.01)
	sky_mat.ground_horizon_color = Color(0.05, 0.05, 0.07)
	sky_mat.sun_angle_max = 3.0
	sky_mat.sun_curve = 0.3
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.45, 0.55)
	env.ambient_light_energy = 0.32
	env.fog_enabled = true
	env.fog_light_color = Color(0.045, 0.05, 0.07)
	env.fog_density = 0.022
	env.fog_sky_affect = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Lune
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.45
	moon.rotation = Vector3(deg_to_rad(-38), deg_to_rad(35), 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	add_child(moon)


func register_light(l: OmniLight3D) -> void:
	if l.get_meta("flicker", false):
		_flicker.append(l)


func register_power_light(l: OmniLight3D) -> void:
	_power_lights.append(l)


func register_emergency(n: Node3D) -> void:
	_emergency.append(n)


# --- Carte ----------------------------------------------------------------

func _build_map() -> void:
	# Sols intérieurs (+ plafond) et extérieurs
	_floor(Vector2(0, 0), Vector2(20.4, 20.4), m_floor, true)
	_floor(Vector2(0, -20), Vector2(6.4, 20), m_floor, true)
	_floor(Vector2(0, -40), Vector2(30.4, 20.4), m_floor, true)
	_floor(Vector2(-13, 0), Vector2(6, 20.4), m_dirt, false) # extérieur ouest salle de départ
	_floor(Vector2(-3, 13), Vector2(26, 6), m_dirt, false) # extérieur sud
	_floor(Vector2(6, -20), Vector2(6, 12), m_dirt, false) # extérieur est couloir
	_floor(Vector2(-3, -53), Vector2(36, 6), m_dirt, false) # extérieur nord grande salle
	_floor(Vector2(-18, -40), Vector2(6, 20.4), m_dirt, false) # extérieur ouest grande salle

	# Salle de départ (zone 0) : x -10..10, z -10..10 — enduit peint
	_wall_x(-10, -10, 10, [[0.0, 3.0, 3.0]])
	_wall_x(10, -10, 10, [[-4.0, 1.6, 2.4], [4.0, 1.6, 2.4]])
	_wall_z(-10, -10, 10, [[-4.0, 1.6, 2.4], [4.0, 1.6, 2.4]])
	_wall_z(10, -10, 10, [])
	# Couloir (zone 1) : x -3..3, z -30..-10 — béton
	_wall_z(-3, -30, -10, [], Mat.concrete_wall())
	_wall_z(3, -30, -10, [[-20.0, 1.6, 2.4]], Mat.concrete_wall())
	# Grande salle (zone 2) : x -15..15, z -50..-30 — briques
	_wall_x(-30, -15, 15, [[0.0, 3.0, 3.0]], Mat.bricks())
	_wall_x(-50, -15, 15, [[-8.0, 1.6, 2.4], [8.0, 1.6, 2.4]], Mat.bricks())
	_wall_z(-15, -50, -30, [[-40.0, 1.6, 2.4]], Mat.bricks())
	_wall_z(15, -50, -30, [], Mat.bricks())
	for r in [Rect2(-10, -10, 20, 20), Rect2(-3, -30, 6, 20), Rect2(-15, -50, 30, 20)]:
		_baseboard(r)

	# Murs extérieurs en ruine
	_fence_x(16, -16, 10)
	_fence_z(-16, -10, 16)
	_fence_z(10, 10, 16)
	_fence_x(-10, -16, -10)
	_fence_z(9, -26, -14)
	_fence_x(-26, 3, 9)
	_fence_x(-14, 3, 9)
	_fence_x(-56, -21, 15)
	_fence_z(-21, -56, -30)
	_fence_z(15, -56, -50)
	_fence_x(-30, -21, -15)

	# Piliers de la grande salle
	for p in [Vector2(-7, -36), Vector2(7, -36), Vector2(-7, -44)]:
		MeshUtil.static_box(nav, Vector3(0.8, H, 0.8), Vector3(p.x, H * 0.5, p.y), Mat.bricks())
		MeshUtil.box_mesh(self, Vector3(0.95, 0.3, 0.95), Vector3(p.x, 0.15, p.y), Mat.concrete_wall())

	# Barricades : position, direction vers l'intérieur, zone
	_barricade(Vector3(-10, 0, -4), Vector3.RIGHT, 0)
	_barricade(Vector3(-10, 0, 4), Vector3.RIGHT, 0)
	_barricade(Vector3(-4, 0, 10), Vector3.FORWARD, 0)
	_barricade(Vector3(4, 0, 10), Vector3.FORWARD, 0)
	_barricade(Vector3(3, 0, -20), Vector3.LEFT, 1)
	_barricade(Vector3(-8, 0, -50), Vector3.BACK, 2)
	_barricade(Vector3(8, 0, -50), Vector3.BACK, 2)
	_barricade(Vector3(-15, 0, -40), Vector3.RIGHT, 2)

	# Portes
	_door(Vector3(0, 0, -10), 750, 1)
	_door(Vector3(0, 0, -30), 1000, 2)

	# Armes murales (position sur la face intérieure du mur, direction vers la pièce)
	_wall_buy(Vector3(9.79, 0, -3), Vector3.LEFT, "carabine", 500)
	_wall_buy(Vector3(-6, 0, -9.79), Vector3.BACK, "vipere", 1000)
	_wall_buy(Vector3(-2.79, 0, -16), Vector3.RIGHT, "brise_porte", 1200)
	_wall_buy(Vector3(14.79, 0, -38), Vector3.LEFT, "k74", 1400)

	# Atouts
	_perk(Vector3(9.35, 0, 6), Vector3.LEFT, "second_souffle")
	_perk(Vector3(-2.35, 0, -25), Vector3.RIGHT, "cuirasse")
	_perk(Vector3(-14.35, 0, -34), Vector3.RIGHT, "main_leste")
	_perk(Vector3(-14.35, 0, -46), Vector3.RIGHT, "triple_etui")
	_perk(Vector3(14.35, 0, -46), Vector3.LEFT, "tonique_eclair")

	# Courant et amélioration
	_place(PowerScript.new(), nav, Vector3(0, 0, -49.79), Vector3.BACK)
	_place(UpgradeScript.new(), nav, Vector3(7, 0, -43), Vector3.BACK)

	# Pièges (courant requis)
	_trap(Vector3(-2.79, 0, -18.3), Vector3.RIGHT, "electric", 1000, Vector3(0, 1.0, -20.5), Vector3(5.6, 2.0, 2.6))
	_trap(Vector3(-14.79, 0, -37.2), Vector3.RIGHT, "fire", 1000, Vector3(-11.8, 1.0, -40.0), Vector3(3.6, 2.0, 3.4))

	# Boîte mystère : 3 emplacements
	box_locations.append(_facing_transform(Vector3(-9.3, 0, 0), Vector3.RIGHT))
	box_locations.append(_facing_transform(Vector3(2.3, 0, -14), Vector3.LEFT))
	box_locations.append(_facing_transform(Vector3(-6, 0, -30.7), Vector3.FORWARD))
	box = BoxScript.new()
	add_child(box)
	box.global_transform = box_locations[0]


## Sol (collision d'un seul bloc) affiché en dalles de ~5 m : chaque dalle ne reçoit que
## les lumières proches (limite de lumières par objet du rendu Compatibility).
func _floor(c: Vector2, size: Vector2, material: Material, ceiling: bool) -> void:
	MeshUtil.static_box(nav, Vector3(size.x, 0.5, size.y), Vector3(c.x, -0.25, c.y), null)
	var nx := maxi(1, roundi(size.x / 5.0))
	var nz := maxi(1, roundi(size.y / 5.0))
	var tile := Vector2(size.x / nx, size.y / nz)
	for i in nx:
		for j in nz:
			var tc := Vector2(c.x - size.x * 0.5 + tile.x * (i + 0.5), c.y - size.y * 0.5 + tile.y * (j + 0.5))
			MeshUtil.box_mesh(self, Vector3(tile.x, 0.5, tile.y), Vector3(tc.x, -0.25, tc.y), material)
			if ceiling:
				MeshUtil.box_mesh(self, Vector3(tile.x, 0.2, tile.y), Vector3(tc.x, H + 0.1, tc.y), m_ceiling)


## Mur le long de l'axe X à la position z, ouvertures = [[centre, largeur, hauteur_haut], ...]
func _wall_x(z: float, x0: float, x1: float, openings: Array, material: Material = null) -> void:
	_wall(true, z, x0, x1, openings, material if material else m_wall, H)


func _wall_z(x: float, z0: float, z1: float, openings: Array, material: Material = null) -> void:
	_wall(false, x, z0, z1, openings, material if material else m_wall, H)


func _fence_x(z: float, x0: float, x1: float) -> void:
	_wall(true, z, x0, x1, [], m_fence, H)


func _fence_z(x: float, z0: float, z1: float) -> void:
	_wall(false, x, z0, z1, [], m_fence, H)


func _wall(along_x: bool, fixed: float, s0: float, s1: float, openings: Array, material: Material, height: float) -> void:
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	var cur := s0
	for o in sorted:
		var c: float = o[0]
		var w: float = o[1]
		var top: float = o[2]
		_seg(along_x, fixed, cur, c - w * 0.5, 0.0, height, material)
		_seg(along_x, fixed, c - w * 0.5, c + w * 0.5, top, height, material)
		cur = c + w * 0.5
	_seg(along_x, fixed, cur, s1, 0.0, height, material)


func _seg(along_x: bool, fixed: float, a: float, b: float, y0: float, y1: float, material: Material) -> void:
	if b - a < 0.01 or y1 - y0 < 0.01:
		return
	var size := Vector3(b - a, y1 - y0, T) if along_x else Vector3(T, y1 - y0, b - a)
	var pos := Vector3((a + b) * 0.5, (y0 + y1) * 0.5, fixed) if along_x else Vector3(fixed, (y0 + y1) * 0.5, (a + b) * 0.5)
	MeshUtil.static_box(nav, size, pos, material)


## Plinthe sombre (purement visuelle) sur le pourtour intérieur d'une pièce.
func _baseboard(r: Rect2) -> void:
	var m := MeshUtil.mat(Color(0.08, 0.075, 0.07), 0.0, 0.7)
	var y := 0.12
	var inset := T * 0.5 + 0.015
	MeshUtil.box_mesh(self, Vector3(r.size.x, 0.24, 0.03), Vector3(r.get_center().x, y, r.position.y + inset), m)
	MeshUtil.box_mesh(self, Vector3(r.size.x, 0.24, 0.03), Vector3(r.get_center().x, y, r.end.y - inset), m)
	MeshUtil.box_mesh(self, Vector3(0.03, 0.24, r.size.y), Vector3(r.position.x + inset, y, r.get_center().y), m)
	MeshUtil.box_mesh(self, Vector3(0.03, 0.24, r.size.y), Vector3(r.end.x - inset, y, r.get_center().y), m)


## Transform dont l'axe +Z local pointe vers `facing`.
func _facing_transform(pos: Vector3, facing: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), pos)


func _place(node: Node3D, parent: Node, pos: Vector3, facing: Vector3) -> Node3D:
	node.transform = _facing_transform(pos, facing)
	parent.add_child(node)
	return node


func _barricade(pos: Vector3, inward: Vector3, zone: int) -> void:
	var b := BarricadeScript.new()
	b.zone = zone
	# -Z local doit pointer vers l'intérieur, donc +Z vers l'extérieur.
	_place(b, self, pos, -inward)
	barricades.append(b)


func _door(pos: Vector3, cost: int, zone: int) -> void:
	var d := DoorScript.new()
	d.cost = cost
	d.unlock_zone = zone
	_place(d, nav, pos, Vector3.BACK)


func _wall_buy(pos: Vector3, facing: Vector3, weapon_id: String, price: int) -> void:
	var w := WallBuyScript.new()
	w.weapon_id = weapon_id
	w.price = price
	_place(w, self, pos, facing)


func _trap(pos: Vector3, facing: Vector3, kind: String, cost: int, center: Vector3, size: Vector3) -> void:
	var t := TrapScript.new()
	t.kind = kind
	t.cost = cost
	t.zone_center = center
	t.zone_size = size
	_place(t, self, pos, facing)


func _perk(pos: Vector3, facing: Vector3, perk_id: String) -> void:
	var p := PerkScript.new()
	p.perk_id = perk_id
	_place(p, nav, pos, facing)


# --- Zones et boîte -------------------------------------------------------

func unlock_zone(zone: int) -> void:
	active_zones[zone] = true
	_bake.call_deferred()


func relocate_box(b: Node3D) -> void:
	var choices: Array[int] = []
	for i in box_locations.size():
		if i != _box_index:
			choices.append(i)
	_box_index = choices.pick_random()
	b.global_transform = box_locations[_box_index]
	GameManager.show_message("La boîte est réapparue ailleurs", Color(0.4, 0.8, 1.0))


func _on_power(on: bool) -> void:
	if not on:
		return
	for l in _power_lights:
		var col: Color = l.get_meta("color", Color.WHITE)
		var bulb = l.get_meta("bulb", null)
		if bulb:
			bulb.material_override = MeshUtil.mat(col, 6.0)
		l.shadow_enabled = l.omni_range > 12.0
		create_tween().tween_property(l, "light_energy", 2.6, 1.2)
		l.set_meta("base", 2.6)
	for e in _emergency:
		e.visible = false
	env.ambient_light_energy = 0.5


# --- Manches et ennemis ---------------------------------------------------

func spawn_enemy(info: Dictionary) -> bool:
	var pos: Vector3
	var barricade: Node3D = null
	if info.kind == "dog" or info.kind == "boss":
		var pts := _dog_points()
		if pts.is_empty():
			return false
		pos = pts.pick_random()
	else:
		var cands: Array = barricades.filter(func(b): return active_zones.has(b.zone))
		if cands.is_empty():
			return false
		var ppos := player.global_position
		cands.sort_custom(func(a, b): return a.global_position.distance_squared_to(ppos) < b.global_position.distance_squared_to(ppos))
		barricade = cands.slice(0, 4).pick_random()
		pos = barricade.spawn_point()
	var z: CharacterBody3D = ZombieScript.new()
	z.setup(info.kind, info.hp, info.speed, barricade)
	add_child(z)
	z.global_position = pos
	z.rotation.y = randf() * TAU
	if info.kind == "dog":
		_lightning(pos)
	elif info.kind == "boss":
		_lightning(pos)
		_shake(0.6)
		Audio.play("boss_roar", 6.0, 0.7)
		GameManager.show_message("LE COLOSSE", Color(1.0, 0.25, 0.1), "Un monstre blindé approche — brisez son casque")
		hud.track_boss(z)
	else:
		Effects.dirt_puff(self, pos)
	return true


func _dog_points() -> Array:
	var out := []
	for b in barricades:
		if not active_zones.has(b.zone):
			continue
		var p: Vector3 = b.inside_point() + Vector3(randf_range(-1.5, 1.5), 0.05, 0)
		if p.distance_to(player.global_position) > 6.0:
			out.append(p)
	return out


func _lightning(pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.8, 1.0)
	l.light_energy = 8.0
	l.omni_range = 9.0
	add_child(l)
	l.global_position = pos + Vector3.UP * 2.0
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
	Effects.burst(self, pos + Vector3.UP, Vector3.UP, Color(0.7, 0.85, 1.0), 20, 3.0, 0.05, 0.4, 0.0, 6.0, 180.0)
	Audio.play_at("explosion", pos, -6.0, 1.6)


func on_round_started(r: int, dog: bool) -> void:
	hud.show_round(r, dog)
	if r > 1:
		player.holder.add_grenades(2)
	var tw := create_tween()
	tw.tween_property(env, "fog_light_color", Color(0.25, 0.12, 0.04) if dog else Color(0.045, 0.05, 0.07), 2.0)
	tw.parallel().tween_property(env, "fog_density", 0.04 if dog else 0.022, 2.0)


func on_round_ended(_r: int, dog: bool, pos: Vector3) -> void:
	hud.round_over()
	if dog:
		spawn_powerup(pos, "max_ammo")


func on_zombie_killed(z: Node3D, cause: String) -> void:
	var pos := z.global_position
	if cause != "nuke":
		Effects.blood_decal(self, Vector3(pos.x, 0.0, pos.z), randf_range(1.2, 1.9), Vector3.UP, 2.5)
	if menu_mode:
		return
	rounds.on_killed(pos)
	if z.kind == "boss":
		spawn_powerup(pos, "max_ammo")
		GameManager.show_message("COLOSSE ABATTU", Color(1.0, 0.85, 0.3), "+500 points")
		return
	if cause == "nuke" or GameManager.drops_this_round >= MAX_DROPS or z.kind == "dog":
		return
	if randf() < DROP_CHANCE and _is_reachable(pos):
		GameManager.drops_this_round += 1
		spawn_powerup(pos, GameManager.POWERUPS.keys().pick_random())


func _is_reachable(pos: Vector3) -> bool:
	for r in ROOMS:
		if active_zones.has(r[0]) and (r[1] as Rect2).has_point(Vector2(pos.x, pos.z)):
			return true
	return false


func spawn_powerup(pos: Vector3, kind: String) -> void:
	if not _is_reachable(pos):
		pos = player.global_position + (-player.global_basis.z * 2.0)
	var p: Node3D = PowerupScript.new()
	p.kind = kind
	add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)


func apply_powerup(kind: String) -> void:
	var p: Dictionary = GameManager.POWERUPS[kind]
	Audio.play("powerup", 2.0)
	GameManager.show_message(p.name, p.color)
	match kind:
		"max_ammo":
			player.holder.refill_all()
		"insta_kill", "double_points":
			GameManager.activate_timed_powerup(kind)
		"nuke":
			Audio.play("explosion", 4.0, 0.7)
			hud.flash(Color(1.0, 0.95, 0.8), 1.2)
			_shake(0.6)
			for z in get_tree().get_nodes_in_group("zombies"):
				z.take_damage(z.hp + 1.0, false, "nuke")
			GameManager.add_points(400, false)
		"carpenter":
			for b in barricades:
				b.repair_all()
			GameManager.add_points(200, false)


# --- Effets ---------------------------------------------------------------

func explode(pos: Vector3, radius: float, dmg: float, cause: String, hurt_player: bool) -> void:
	Audio.play_at("explosion", pos, 2.0, randf_range(0.9, 1.1))
	Effects.explosion(self, pos, radius)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 8.0
	l.omni_range = radius * 3.0
	add_child(l)
	l.global_position = pos + Vector3.UP * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	if pos.y < 1.0:
		var scorch := Effects.blood_decal(self, Vector3(pos.x, 0.0, pos.z), radius * 0.6)
		(scorch.material_override as ShaderMaterial).set_shader_parameter("blood_color", Color(0.03, 0.03, 0.03, 0.85))
	for z in get_tree().get_nodes_in_group("zombies"):
		var d: float = (z.global_position + Vector3.UP * 0.9).distance_to(pos)
		if d < radius:
			if not z.take_damage(dmg * (1.0 - 0.5 * d / radius), false, cause) and z.has_method("on_blast"):
				z.on_blast(pos)
	if player:
		var pd := (player.global_position + Vector3.UP).distance_to(pos)
		_shake(clampf(1.0 - pd / (radius * 4.0), 0.0, 1.0) * 0.5)
		if hurt_player and pd < radius * 0.6:
			player.take_damage(45.0 * (1.0 - pd / (radius * 0.6)))


func _shake(amount: float) -> void:
	if player and amount > 0.01:
		player.shake(amount)


## Impact de balle sur un zombie.
func spawn_blood(pos: Vector3, dir: Vector3, head: bool) -> void:
	Effects.blood_hit(self, pos, dir, head)
	if randf() < 0.35:
		var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * 3.0, GameManager.L_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			Effects.blood_decal(self, hit.position, randf_range(0.3, 0.6), hit.normal)


## Impact de balle sur le décor : étincelles + trou.
func spawn_spark(pos: Vector3, normal: Vector3) -> void:
	Effects.spark_hit(self, pos, normal)
	var hole := MeshUtil.cylinder_mesh(self, 0.025, 0.005, Vector3.ZERO, MeshUtil.mat(Color(0.03, 0.03, 0.03)))
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	hole.global_transform = Transform3D(Basis(side, up, side.cross(up)), pos + up * 0.004)
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().create_timer(20.0, false).timeout.connect(hole.queue_free)


func spawn_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var mi := MeshUtil.box_mesh(self, Vector3(0.05, 0.05, length), Vector3.ZERO, MeshUtil.mat(color, 4.0))
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(dir, up), (from + to) * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.01, 0.01, 1.0), 0.15)
	tw.tween_callback(mi.queue_free)


func show_game_over() -> void:
	add_child(GameOverScript.new())


# --- Décor du menu principal ---------------------------------------------

func _setup_menu_scene() -> void:
	_menu_cam = Camera3D.new()
	_menu_cam.fov = 60.0
	_menu_cam.current = true
	add_child(_menu_cam)
	_on_power(true)
	for e in _emergency:
		e.visible = true
	for i in 5:
		var z: CharacterBody3D = ZombieScript.new()
		z.setup("zombie", 100.0, 0.6, null)
		z.menu_idle = true
		add_child(z)
		z.global_position = Vector3(-6.0 + i * 3.0 + randf_range(-0.8, 0.8), 0.0, -45.0 + randf_range(-1.5, 1.5))
		z.rotation.y = randf_range(-0.5, 0.5)
	_update_menu_scene(0.0)


func _update_menu_scene(delta: float) -> void:
	_menu_t += delta
	var t := _menu_t * 0.08
	var pos := Vector3(sin(t) * 4.0, 1.65 + sin(t * 1.7) * 0.12, -33.5 + cos(t * 0.8) * 0.8)
	_menu_cam.look_at_from_position(pos, Vector3(sin(t * 0.6) * 2.5, 1.3, -45.0))
