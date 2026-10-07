extends RefCounted
## Effets visuels : particules (sang, étincelles, poussière, explosion) et flaques de sang.

const BLOOD_SHADER := preload("res://shaders/blood_decal.gdshader")
const MAX_DECALS := 60

static var _noise: NoiseTexture2D
static var _decals: Array = []
static var _mats := {}
static var _soft: GradientTexture2D
static var _fire_mat: StandardMaterial3D


## Disque flou (centre opaque, bords transparents) pour des particules rondes.
static func soft_texture() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft


## Matériau de flamme : additif, rond, couleur pilotée par la couleur des particules.
static func fire_material() -> StandardMaterial3D:
	if _fire_mat == null:
		_fire_mat = StandardMaterial3D.new()
		_fire_mat.albedo_texture = soft_texture()
		_fire_mat.albedo_color = Color(1, 1, 1)
		_fire_mat.vertex_color_use_as_albedo = true
		_fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_fire_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _fire_mat


## Dégradé de couleur d'une flamme sur sa durée de vie.
static func fire_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 0.9))
	g.set_color(1, Color(0.25, 0.05, 0.0, 0.0))
	g.add_point(0.35, Color(1.0, 0.4, 0.05, 0.7))
	return g


## Configure un émetteur de flammes réaliste.
static func setup_fire(p: CPUParticles3D, size: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.material = fire_material()
	p.mesh = q
	p.color_ramp = fire_ramp()
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 2.5, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve


static func _particle_mat(color: Color, emission := 0.0, unshaded := false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), emission, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = soft_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


## Particules ponctuelles qui se détruisent toutes seules.
static func burst(parent: Node, pos: Vector3, normal: Vector3, color: Color, amount: int, speed: float,
		size: float, lifetime: float, gravity := 9.8, emission := 0.0, spread_deg := 45.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = _particle_mat(color, emission, emission > 0.0)
	p.mesh = quad
	p.direction = normal if normal.length_squared() > 0.01 else Vector3.UP
	p.spread = spread_deg
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(lifetime + 0.2, false).timeout.connect(p.queue_free)
	return p


static func blood_hit(parent: Node, pos: Vector3, dir: Vector3, heavy := false) -> void:
	burst(parent, pos, -dir + Vector3.UP * 0.3, Color(0.45, 0.02, 0.02), 14 if heavy else 7, 3.5 if heavy else 2.2, 0.06, 0.6, 9.8, 0.0, 35.0)


static func spark_hit(parent: Node, pos: Vector3, normal: Vector3) -> void:
	burst(parent, pos, normal, Color(1.0, 0.75, 0.35), 6, 4.0, 0.025, 0.25, 6.0, 4.0, 40.0)
	burst(parent, pos, normal, Color(0.55, 0.52, 0.48, 0.6), 4, 0.8, 0.12, 0.6, -0.3, 0.0, 30.0)


static func explosion(parent: Node, pos: Vector3, radius: float) -> void:
	burst(parent, pos, Vector3.UP, Color(1.0, 0.55, 0.15), 30, radius * 2.5, 0.25, 0.5, 2.0, 4.0, 180.0)
	burst(parent, pos, Vector3.UP, Color(0.2, 0.19, 0.18, 0.8), 20, radius * 0.9, 0.8, 1.6, -1.0, 0.0, 180.0)
	burst(parent, pos, Vector3.UP, Color(1.0, 0.8, 0.4), 16, radius * 4.0, 0.04, 0.8, 9.8, 5.0, 90.0)


static func dirt_puff(parent: Node, pos: Vector3) -> void:
	burst(parent, pos + Vector3.UP * 0.1, Vector3.UP, Color(0.3, 0.26, 0.2, 0.7), 12, 1.8, 0.35, 1.0, 1.0, 0.0, 70.0)


## Poussière flottante permanente dans une zone (boîte de taille `extents`).
static func dust(parent: Node, center: Vector3, extents: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.025
	quad.material = _particle_mat(Color(0.9, 0.85, 0.75, 0.35), 0.6, true)
	p.mesh = quad
	p.gravity = Vector3(0, -0.02, 0)
	p.direction = Vector3(1, 0.2, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.1
	parent.add_child(p)
	p.position = center
	return p


## Flaque/éclaboussure de sang au sol (ou sur un mur si normal horizontale).
static func blood_decal(parent: Node, pos: Vector3, size: float, normal := Vector3.UP, grow := 0.0) -> Node3D:
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.02
		fn.fractal_octaves = 4
		_noise.noise = fn
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * size
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = BLOOD_SHADER
	m.set_shader_parameter("noise_tex", _noise)
	m.set_shader_parameter("noise_offset", Vector2(randf(), randf()))
	m.set_shader_parameter("spread", 1.0 if grow <= 0.0 else 0.0)
	mi.material_override = m
	parent.add_child(mi)
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)
	mi.global_transform = Transform3D(basis, pos + up * (0.01 + randf() * 0.005))
	if grow > 0.0:
		mi.create_tween().tween_method(func(v: float): m.set_shader_parameter("spread", v), 0.0, 1.0, grow)
	_decals.append(mi)
	while _decals.size() > MAX_DECALS:
		var old = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return mi
