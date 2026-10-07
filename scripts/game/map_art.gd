extends RefCounted
## Habillage de la carte : lampes, accessoires, tuyaux, poutres, sang, poussière, extérieur.
## Les accessoires avec collision sont placés sous la NavigationRegion3D (contournés par les zombies).

const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const Mat := preload("res://scripts/util/materials.gd")
const Effects := preload("res://scripts/util/effects.gd")

var game: Node3D
var nav: Node3D
var H := 4.0


func _init(p_game: Node3D, p_nav: Node3D, height: float) -> void:
	game = p_game
	nav = p_nav
	H = height


func decorate() -> void:
	_start_room()
	_corridor()
	_hall()
	_exterior()


# --- Pièces ---------------------------------------------------------------

func _start_room() -> void:
	for x in [-6.0, -2.0, 2.0, 6.0]:
		_beam(Vector3(x, H - 0.2, 0), Vector3(0.3, 0.35, 20.0))
	_pipe(Vector3(9.6, 3.6, -10), Vector3(9.6, 3.6, 10), 0.09, Mat.rust())
	_pipe(Vector3(9.6, 3.35, -10), Vector3(9.6, 3.35, 10), 0.05, Mat.metal())
	_pipe(Vector3(-10, 3.65, -9.6), Vector3(10, 3.65, -9.6), 0.07, Mat.rust())
	game.register_light(_hanging_lamp(Vector3(0, H, 0), Color(1.0, 0.82, 0.55), 2.6, 16.0, true, true))
	game.register_light(_hanging_lamp(Vector3(-6, H, 6), Color(1.0, 0.8, 0.55), 1.0, 9.0, true, false))

	_crate(Vector3(6.0, 0, -6.0), Vector3(1.0, 1.0, 1.0), 0.1)
	_crate(Vector3(7.15, 0, -6.2), Vector3(1.0, 1.0, 1.0), -0.15)
	_crate(Vector3(6.5, 1.0, -6.1), Vector3(0.85, 0.85, 0.85), 0.4, false)
	_table(Vector3(-5.0, 0, -6.5), 0.0)
	_radio(Vector3(-5.3, 0.82, -6.5))
	_chair(Vector3(-5.2, 0, -5.6), PI + 0.3)
	_chair(Vector3(-3.6, 0, -6.9), -PI * 0.5, true)
	_barrel(Vector3(8.6, 0, -8.6), true)
	_barrel(Vector3(7.9, 0, -9.1))
	_barrel(Vector3(8.9, 0, -7.8), true, true)
	_shelf(Vector3(9.45, 0, 1.0), -PI * 0.5)
	_sandbags(Vector3(7.6, 0, 2.6), 2.4, PI * 0.5)
	_debris(Vector3(-8.5, 0, -8.5))
	_debris(Vector3(3.0, 0, 8.6))
	_sign(Vector3(0, 3.35, -9.79), Vector3.BACK, "ABRI 7", 90, Color(0.75, 0.7, 0.6))
	_sign(Vector3(-9.79, 2.95, 0), Vector3.RIGHT, "DANGER", 70, Color(0.7, 0.15, 0.1))
	for p in [Vector3(-7.5, 0, -3.2), Vector3(-7.8, 0, 4.5), Vector3(3.4, 0, 7.6), Vector3(1.5, 0, -3), Vector3(-2.5, 0, 5.5)]:
		Effects.blood_decal(game, p, randf_range(0.8, 1.8))
	Effects.blood_decal(game, Vector3(-9.79, 1.4, 6.2), 1.2, Vector3.RIGHT)
	Effects.blood_decal(game, Vector3(4.2, 1.2, -9.79), 1.0, Vector3.BACK)
	Effects.dust(game, Vector3(0, 2.0, 0), Vector3(9, 1.8, 9))


func _corridor() -> void:
	for z in [-14.0, -18.0, -22.0, -26.0]:
		_beam(Vector3(0, H - 0.2, z), Vector3(6.0, 0.3, 0.3))
	_pipe(Vector3(-2.65, 3.5, -10), Vector3(-2.65, 3.5, -30), 0.12, Mat.rust())
	_pipe(Vector3(-2.75, 3.15, -10), Vector3(-2.75, 3.15, -30), 0.05, Mat.metal())
	_pipe(Vector3(2.7, 3.7, -10), Vector3(2.7, 3.7, -30), 0.06, Mat.metal())
	game.register_light(_hanging_lamp(Vector3(0, H, -20), Color(1.0, 0.78, 0.5), 1.3, 11.0, true, true))
	game.register_power_light(_cage_lamp(Vector3(0, 3.55, -12.0), Vector3.FORWARD, Color(0.85, 0.92, 1.0), 9.0))
	game.register_power_light(_cage_lamp(Vector3(0, 3.55, -28.0), Vector3.BACK, Color(0.85, 0.92, 1.0), 9.0))
	_barrel(Vector3(2.35, 0, -27.6), true)
	_crate(Vector3(-2.3, 0, -12.3), Vector3(0.9, 0.9, 0.9), 0.2)
	_debris(Vector3(1.9, 0, -22.4))
	_sign(Vector3(-2.79, 2.6, -21.0), Vector3.RIGHT, "→ COURANT", 64, Color(0.85, 0.75, 0.2))
	Effects.blood_decal(game, Vector3(0.8, 0, -19.5), 1.6)
	Effects.blood_decal(game, Vector3(-0.6, 0, -24.0), 0.9)
	Effects.dust(game, Vector3(0, 2.0, -20), Vector3(2.5, 1.8, 9))


func _hall() -> void:
	for x in [-10.5, -3.5, 3.5, 10.5]:
		_beam(Vector3(x, H - 0.2, -40), Vector3(0.35, 0.4, 20.0))
	_pipe(Vector3(-15, 3.55, -49.6), Vector3(15, 3.55, -49.6), 0.14, Mat.rust())
	_pipe(Vector3(-15, 3.2, -49.65), Vector3(15, 3.2, -49.65), 0.06, Mat.metal())
	_pipe(Vector3(14.6, 3.6, -30), Vector3(14.6, 3.6, -50), 0.08, Mat.rust())
	game.register_emergency(_beacon(Vector3(0, 3.6, -46.5)))
	for p in [Vector3(-8, H, -35), Vector3(8, H, -35), Vector3(-8, H, -45), Vector3(8, H, -45), Vector3(0, H, -40)]:
		game.register_power_light(_hanging_lamp(p, Color(0.88, 0.94, 1.0), 0.0, 14.0, false, p.z > -36.0))

	_generator(Vector3(3.2, 0, -48.9))
	_cable(Vector3(2.2, 0.03, -48.9), Vector3(0.4, 0.03, -49.5))
	_crate(Vector3(12.2, 0, -32.0), Vector3(1.1, 1.1, 1.1), 0.3)
	_crate(Vector3(13.3, 0, -31.6), Vector3(1.0, 1.0, 1.0), -0.2)
	_crate(Vector3(12.7, 1.1, -31.8), Vector3(0.8, 0.8, 0.8), 0.7, false)
	_barrel(Vector3(-11.6, 0, -31.2), true)
	_barrel(Vector3(-12.3, 0, -31.8))
	_sandbags(Vector3(0, 0, -39.0), 3.2, 0.0)
	_sandbags(Vector3(-1.9, 0, -40.2), 1.8, PI * 0.5)
	_shelf(Vector3(14.55, 0, -42.0), -PI * 0.5)
	_table(Vector3(10.8, 0, -48.6), 0.4, true)
	_debris(Vector3(-13.0, 0, -48.6))
	_debris(Vector3(6.0, 0, -31.2))
	_sign(Vector3(0, 3.25, -49.79), Vector3.BACK, "GÉNÉRATEUR", 70, Color(0.85, 0.75, 0.2))
	_sign(Vector3(-14.79, 3.2, -40.0), Vector3.RIGHT, "SECTEUR C", 70, Color(0.75, 0.7, 0.6))
	for p in [Vector3(-9, 0, -38), Vector3(5, 0, -46), Vector3(-3, 0, -33), Vector3(9.5, 0, -40.5), Vector3(-12, 0, -44)]:
		Effects.blood_decal(game, p, randf_range(1.0, 2.2))
	Effects.blood_decal(game, Vector3(-6.6, 1.5, -36), 1.1, Vector3.RIGHT)
	Effects.blood_decal(game, Vector3(5.0, 1.0, -30.21), 1.3, Vector3.FORWARD)
	Effects.dust(game, Vector3(0, 2.0, -40), Vector3(14, 1.8, 9))


func _exterior() -> void:
	for p in [Vector3(-14.5, 0, -8.0), Vector3(-14.8, 0, 9.0), Vector3(-12.0, 0, 15.0), Vector3(8.5, 0, 14.6),
			Vector3(7.8, 0, -24.8), Vector3(-19.5, 0, -32.0), Vector3(-20.0, 0, -54.5), Vector3(13.5, 0, -54.8)]:
		_dead_tree(p)
	for p in [Vector3(-15.2, 0, -1.0), Vector3(-1.0, 0, 15.2), Vector3(8.2, 0, -16.0), Vector3(-2.0, 0, -55.2), Vector3(-20.2, 0, -44.0)]:
		_debris(p)
	for p in [Vector3(-13.5, 0, 0.0), Vector3(0.0, 0, 13.5), Vector3(-10.0, 0, -53.0), Vector3(10.0, 0, -53.0)]:
		_lamp_post(p)


# --- Éclairage ------------------------------------------------------------

## Lampe suspendue (câble + abat-jour + ampoule). Retourne la lumière.
func _hanging_lamp(ceiling_pos: Vector3, color: Color, energy: float, light_range: float, flicker: bool, shadows: bool) -> OmniLight3D:
	var root := Node3D.new()
	game.add_child(root)
	root.position = ceiling_pos
	var drop := 0.7
	MeshUtil.cylinder_mesh(root, 0.01, drop, Vector3(0, -drop * 0.5, 0), MeshUtil.mat(Color(0.05, 0.05, 0.05)))
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 0.32
	cone.height = 0.22
	cone.radial_segments = 16
	shade.mesh = cone
	shade.material_override = Mat.metal(Color(0.25, 0.32, 0.25))
	shade.position = Vector3(0, -drop - 0.08, 0)
	root.add_child(shade)
	var bulb := MeshUtil.sphere_mesh(root, 0.07, Vector3(0, -drop - 0.17, 0), MeshUtil.mat(color, 6.0 if energy > 0.0 else 0.0))
	var l := OmniLight3D.new()
	l.position = Vector3(0, -drop - 0.3, 0)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.1
	l.shadow_enabled = shadows
	l.shadow_bias = 0.05
	l.set_meta("base", energy)
	l.set_meta("bulb", bulb)
	l.set_meta("color", color)
	l.set_meta("flicker", flicker)
	root.add_child(l)
	return l


## Lampe grillagée murale/plafond.
func _cage_lamp(pos: Vector3, facing: Vector3, color: Color, light_range: float) -> OmniLight3D:
	var root := Node3D.new()
	game.add_child(root)
	root.transform = Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), pos)
	MeshUtil.box_mesh(root, Vector3(0.25, 0.08, 0.25), Vector3(0, 0.38, 0), Mat.metal())
	var bulb := MeshUtil.capsule_mesh(root, 0.06, 0.25, Vector3(0, 0.2, 0), MeshUtil.mat(color.darkened(0.6)))
	for i in 4:
		var a := i * PI * 0.5
		MeshUtil.box_mesh(root, Vector3(0.015, 0.3, 0.015), Vector3(cos(a) * 0.1, 0.2, sin(a) * 0.1), MeshUtil.mat(Color(0.1, 0.1, 0.1)))
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0.1, 0)
	l.light_color = color
	l.light_energy = 0.0
	l.omni_range = light_range
	l.set_meta("base", 0.0)
	l.set_meta("bulb", bulb)
	l.set_meta("color", color)
	l.set_meta("flicker", false)
	root.add_child(l)
	return l


## Gyrophare rouge de secours (tourne tant que le courant est coupé).
func _beacon(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	game.add_child(root)
	root.position = pos
	MeshUtil.cylinder_mesh(root, 0.12, 0.1, Vector3(0, 0.3, 0), Mat.metal())
	MeshUtil.sphere_mesh(root, 0.13, Vector3(0, 0.2, 0), MeshUtil.mat(Color(1.0, 0.1, 0.05, 0.85), 3.0))
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(0, 0.2, 0)
	root.add_child(spin)
	for side in [1.0, -1.0]:
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.1, 0.05)
		s.light_energy = 6.0
		s.spot_range = 22.0
		s.spot_angle = 28.0
		s.rotation = Vector3(-0.25, PI * 0.5 * side, 0)
		spin.add_child(s)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.12, 0.08)
	glow.light_energy = 0.6
	glow.omni_range = 18.0
	root.add_child(glow)
	return root


func _lamp_post(pos: Vector3) -> void:
	var root := Node3D.new()
	game.add_child(root)
	root.position = pos
	var iron := Mat.metal(Color(0.15, 0.15, 0.17))
	MeshUtil.cylinder_mesh(root, 0.06, 3.2, Vector3(0, 1.6, 0), iron)
	MeshUtil.box_mesh(root, Vector3(0.25, 0.3, 0.25), Vector3(0, 3.3, 0), iron)
	MeshUtil.sphere_mesh(root, 0.08, Vector3(0, 3.25, 0), MeshUtil.mat(Color(0.6, 0.75, 1.0), 4.0))
	var l := OmniLight3D.new()
	l.position = Vector3(0, 3.0, 0)
	l.light_color = Color(0.5, 0.62, 0.95)
	l.light_energy = 1.4
	l.omni_range = 9.0
	root.add_child(l)


# --- Accessoires ----------------------------------------------------------

func _beam(center: Vector3, size: Vector3) -> void:
	MeshUtil.box_mesh(game, size, center, Mat.dark_wood())


func _pipe(a: Vector3, b: Vector3, r: float, material: Material) -> void:
	var mi := MeshUtil.cylinder_mesh(game, r, a.distance_to(b), (a + b) * 0.5, material)
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI * 0.5), (a + b) * 0.5)
	# colliers de fixation
	var n := int(a.distance_to(b) / 3.0)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		var c := MeshUtil.cylinder_mesh(game, r * 1.35, 0.06, p, Mat.metal(Color(0.3, 0.3, 0.3)))
		c.global_transform = Transform3D(mi.global_basis, p)


func _cable(a: Vector3, b: Vector3) -> void:
	_pipe(a, b, 0.02, MeshUtil.mat(Color(0.04, 0.04, 0.04), 0.0, 0.6))


func _crate(pos: Vector3, size: Vector3, rot_y: float, collide := true) -> void:
	var parent: Node = nav if collide else game
	var body := MeshUtil.static_box(parent, size, pos + Vector3(0, size.y * 0.5, 0), null, GameManager.L_WORLD if collide else 0)
	body.rotation.y = rot_y
	MeshUtil.box_mesh(body, size, Vector3.ZERO, Mat.wood())
	var trim := Mat.dark_wood()
	for y in [-0.5, 0.5]:
		MeshUtil.box_mesh(body, Vector3(size.x + 0.02, 0.08, size.z + 0.02), Vector3(0, size.y * y * 0.86, 0), trim)
	for side in [1.0, -1.0]:
		MeshUtil.box_mesh(body, Vector3(minf(size.x, size.y) * 1.25, 0.08, 0.03), Vector3(0, 0, side * (size.z * 0.5 + 0.015)), trim, Vector3(0, 0, 0.75))


func _barrel(pos: Vector3, rusty := false, tipped := false) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameManager.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = 0.9
	cs.shape = shape
	body.add_child(cs)
	nav.add_child(body)
	body.position = pos + Vector3(0, 0.45 if not tipped else 0.32, 0)
	if tipped:
		body.rotation = Vector3(PI * 0.5, randf() * TAU, 0)
	var m := Mat.rust() if rusty else Mat.metal(Color(0.2, 0.3, 0.22))
	MeshUtil.cylinder_mesh(body, 0.32, 0.9, Vector3.ZERO, m)
	for y in [-0.3, 0.0, 0.3]:
		MeshUtil.cylinder_mesh(body, 0.335, 0.04, Vector3(0, y, 0), Mat.metal(Color(0.25, 0.25, 0.25)))
	if tipped:
		Effects.blood_decal(game, Vector3(pos.x, 0.0, pos.z) + Vector3(0.6, 0, 0.3), 1.1)


func _table(pos: Vector3, rot_y: float, flipped := false) -> void:
	var body := MeshUtil.static_box(nav, Vector3(1.8, 0.8, 0.9), pos + Vector3(0, 0.4, 0), null)
	body.rotation.y = rot_y
	var top := Node3D.new()
	body.add_child(top)
	if flipped:
		top.rotation.x = PI * 0.5
		top.position = Vector3(0, -0.0, 0)
	MeshUtil.box_mesh(top, Vector3(1.8, 0.06, 0.9), Vector3(0, 0.37, 0), Mat.dark_wood())
	for x in [-0.82, 0.82]:
		for z in [-0.38, 0.38]:
			MeshUtil.box_mesh(top, Vector3(0.06, 0.74, 0.06), Vector3(x, 0.0, z), Mat.metal(Color(0.2, 0.2, 0.2)))


func _chair(pos: Vector3, rot_y: float, fallen := false) -> void:
	var root := Node3D.new()
	game.add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	if fallen:
		root.rotation.z = PI * 0.5
		root.position.y = 0.22
	var w := Mat.dark_wood()
	MeshUtil.box_mesh(root, Vector3(0.45, 0.05, 0.45), Vector3(0, 0.45, 0), w)
	MeshUtil.box_mesh(root, Vector3(0.45, 0.5, 0.05), Vector3(0, 0.72, 0.2), w)
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			MeshUtil.box_mesh(root, Vector3(0.04, 0.45, 0.04), Vector3(x, 0.22, z), w)


func _radio(pos: Vector3) -> void:
	var root := Node3D.new()
	game.add_child(root)
	root.position = pos
	MeshUtil.box_mesh(root, Vector3(0.5, 0.28, 0.25), Vector3(0, 0.14, 0), Mat.metal(Color(0.3, 0.33, 0.25)))
	MeshUtil.cylinder_mesh(root, 0.008, 0.6, Vector3(0.18, 0.55, 0), MeshUtil.mat(Color(0.1, 0.1, 0.1)))
	MeshUtil.sphere_mesh(root, 0.02, Vector3(-0.15, 0.2, 0.13), MeshUtil.mat(Color(1.0, 0.3, 0.1), 4.0))
	MeshUtil.box_mesh(root, Vector3(0.2, 0.1, 0.01), Vector3(0.05, 0.16, 0.126), MeshUtil.mat(Color(0.9, 0.7, 0.3), 1.0))


func _shelf(pos: Vector3, rot_y: float) -> void:
	var body := MeshUtil.static_box(nav, Vector3(1.6, 2.2, 0.5), pos + Vector3(0, 1.1, 0), null)
	body.rotation.y = rot_y
	var m := Mat.metal(Color(0.35, 0.37, 0.35))
	for x in [-0.77, 0.77]:
		MeshUtil.box_mesh(body, Vector3(0.05, 2.2, 0.5), Vector3(x, 0, 0), m)
	for i in 4:
		var y := -1.0 + i * 0.65
		MeshUtil.box_mesh(body, Vector3(1.6, 0.04, 0.5), Vector3(0, y, 0), m)
		var n := randi_range(1, 3)
		for j in n:
			var s := randf_range(0.2, 0.35)
			var item := MeshUtil.box_mesh(body, Vector3(s, s * 0.8, s), Vector3(randf_range(-0.55, 0.55), y + s * 0.4 + 0.02, 0), Mat.wood() if randf() < 0.5 else Mat.metal(Color(0.3, 0.35, 0.3)))
			item.rotation.y = randf_range(-0.4, 0.4)


func _sandbags(pos: Vector3, length: float, rot_y: float) -> void:
	var body := MeshUtil.static_box(nav, Vector3(length, 0.75, 0.6), pos + Vector3(0, 0.375, 0), null)
	body.rotation.y = rot_y
	var cloth := Mat.textured("ground", Color(0.85, 0.75, 0.55), 0.6, 0.0, false)
	var n := int(length / 0.55)
	for row in 3:
		for i in n - (row % 2):
			var x := -length * 0.5 + 0.3 + i * 0.55 + (0.27 if row % 2 == 1 else 0.0)
			var bag := MeshUtil.capsule_mesh(body, 0.14, 0.55, Vector3(x, -0.25 + row * 0.24, randf_range(-0.05, 0.05)), cloth, Vector3(0, randf_range(-0.15, 0.15), PI * 0.5))
			bag.scale = Vector3(0.7, 1.0, 1.35)


func _generator(pos: Vector3) -> void:
	var body := MeshUtil.static_box(nav, Vector3(1.6, 1.2, 0.9), pos + Vector3(0, 0.6, 0), null)
	var m := Mat.metal(Color(0.35, 0.4, 0.3))
	MeshUtil.box_mesh(body, Vector3(1.6, 1.0, 0.9), Vector3(0, -0.1, 0), m)
	MeshUtil.cylinder_mesh(body, 0.25, 1.4, Vector3(0, 0.5, 0), Mat.rust(), Vector3(0, 0, PI * 0.5))
	for i in 5:
		MeshUtil.box_mesh(body, Vector3(0.04, 0.6, 0.92), Vector3(-0.6 + i * 0.12, -0.1, 0), Mat.metal(Color(0.15, 0.15, 0.15)))
	MeshUtil.label3d(body, "DANGER\n400 V", Vector3(0.45, 0.0, 0.46), 32, Color(0.95, 0.8, 0.2))


func _debris(pos: Vector3) -> void:
	for i in randi_range(4, 7):
		var s := Vector3(randf_range(0.1, 0.5), randf_range(0.05, 0.2), randf_range(0.1, 0.4))
		var m := Mat.concrete_wall() if randf() < 0.6 else Mat.dark_wood()
		var mi := MeshUtil.box_mesh(game, s, pos + Vector3(randf_range(-0.6, 0.6), s.y * 0.5, randf_range(-0.6, 0.6)), m)
		mi.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))


func _dead_tree(pos: Vector3) -> void:
	var root := Node3D.new()
	game.add_child(root)
	root.position = pos
	root.rotation.y = randf() * TAU
	var bark := Mat.textured("planks", Color(0.22, 0.18, 0.15), 0.8, 0.0, false)
	var h := randf_range(3.5, 5.5)
	var trunk := MeshUtil.cylinder_mesh(root, 0.16, h, Vector3(0, h * 0.5, 0), bark, Vector3(randf_range(-0.08, 0.08), 0, randf_range(-0.08, 0.08)))
	(trunk.mesh as CylinderMesh).top_radius = 0.06
	for i in randi_range(3, 5):
		var y := randf_range(h * 0.45, h * 0.9)
		var l := randf_range(0.8, 1.6)
		var a := randf() * TAU
		var tilt := randf_range(0.6, 1.1)
		var br := MeshUtil.cylinder_mesh(root, 0.05, l, Vector3.ZERO, bark)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, tilt)
		br.transform = Transform3D(basis, Vector3(0, y, 0) + basis.y * l * 0.5)
		(br.mesh as CylinderMesh).top_radius = 0.015


func _sign(pos: Vector3, facing: Vector3, text: String, size: int, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.font = preload("res://scenes/ui/ui_theme.gd").stencil_font()
	game.add_child(l)
	l.transform = Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), pos + facing * 0.02)
