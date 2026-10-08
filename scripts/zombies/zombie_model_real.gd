extends Node3D
## Zombie réaliste (Pixelhouse, CC-BY 3.0 — pixelhouse.com.ar) : squelette Biped,
## animations marche / attaque (« fury ») / mort, pilotées manuellement.
## Même interface que zombie_model.gd (update_pose, hide_head, _eyes) + attack() et die().

const DIR := "res://assets/models/zombie_real/"
const BASE := DIR + "walk.fbx"
const SCALE := 3.2
## Position du bassin dans le fichier (le modèle n'est pas centré sur l'origine).
const ORIGIN_OFFSET := Vector3(0.42, 0.0, -0.23)

static var _library: AnimationLibrary
static var _mats := {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var arm_raise := 1.0 # compatibilité avec zombie_model.gd (non utilisé)
var arm_swing := 0.0
var _eyes: Array[MeshInstance3D] = []
var _head := -1
var _headless := false
var _attack_t := 0.0
var _dead := false
var _severed: Array[int] = []
## 0 = marche, 1 = course (penché en avant, bras qui pompent).
var run_amount := 0.0
var crawling := false
var _bones := {}
var _crawl_t := 0.0
# Cadavre physique (ragdoll) : corps rigides reliés par des articulations qui pilotent les os.
static var active_ragdolls := 0
const MAX_RAGDOLLS := 8
var _rag: Node3D
var _rag_bones: Array = [] # [index d'os, corps, transform os relatif au corps]
var _rag_sink := 0.0
## [nom, os de départ, os de fin, rayon, masse, os pilotés, parent]
const RAG_PARTS := [
	["torso", "Bip01 Pelvis", "Bip01 Neck", 0.13, 12.0, ["Bip01", "Bip01 Pelvis", "Bip01 Spine", "Bip01 Spine1", "Bip01 Spine2", "Bip01 Spine3", "Bip01 L Clavicle", "Bip01 R Clavicle"], ""],
	["head", "Bip01 Neck", "Bip01 HeadNub", 0.1, 4.0, ["Bip01 Neck", "Bip01 Head"], "torso"],
	["uarm_l", "Bip01 L UpperArm", "Bip01 L Forearm", 0.05, 2.0, ["Bip01 L UpperArm"], "torso"],
	["farm_l", "Bip01 L Forearm", "Bip01 L Hand", 0.045, 1.5, ["Bip01 L Forearm"], "uarm_l"],
	["uarm_r", "Bip01 R UpperArm", "Bip01 R Forearm", 0.05, 2.0, ["Bip01 R UpperArm"], "torso"],
	["farm_r", "Bip01 R Forearm", "Bip01 R Hand", 0.045, 1.5, ["Bip01 R Forearm"], "uarm_r"],
	["thigh_l", "Bip01 L Thigh", "Bip01 L Calf", 0.075, 5.0, ["Bip01 L Thigh"], "torso"],
	["calf_l", "Bip01 L Calf", "Bip01 L Foot", 0.06, 3.0, ["Bip01 L Calf"], "thigh_l"],
	["thigh_r", "Bip01 R Thigh", "Bip01 R Calf", 0.075, 5.0, ["Bip01 R Thigh"], "torso"],
	["calf_r", "Bip01 R Calf", "Bip01 R Foot", 0.06, 3.0, ["Bip01 R Calf"], "thigh_r"],
]


const VARIANTS := 5


static func available() -> bool:
	return ResourceLoader.exists(BASE) and ResourceLoader.exists(DIR + "diffuse_v0.jpg")


## `variant` : "0".."4" (tenue). `tint` teinte la peau/le tout.
func setup(variant: String, tint := Color.WHITE) -> void:
	var pivot := Node3D.new()
	pivot.scale = Vector3.ONE * SCALE
	pivot.rotation.y = -PI * 0.5 # le modèle regarde -X, le jeu utilise -Z
	add_child(pivot)
	var model: Node3D = load(BASE).instantiate()
	model.position = -ORIGIN_OFFSET
	pivot.add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _material(tint, int(variant) if variant.is_valid_int() else 0)
	for n in model.get_children():
		if n is Node3D and not (n is Skeleton3D):
			n.visible = false # caméras / plans d'export

	# Le lecteur d'origine ne contient que la marche : on le remplace.
	var old: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	old.queue_free()
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.add_animation_library("", _get_library())
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.play("walk")
	anim.seek(randf() * 1.4, true)
	_head = skeleton.find_bone("Bip01 Head")

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.55, 0.1) if tint.r < 0.9 else Color(1.0, 0.12, 0.05)
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_mat.albedo_color
	eye_mat.emission_energy_multiplier = 5.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 2:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.013
		sm.height = 0.02
		sm.radial_segments = 8
		sm.rings = 4
		e.mesh = sm
		e.material_override = eye_mat
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.top_level = true
		add_child(e)
		_eyes.append(e)


func update_pose(delta: float, moving: bool, anim_speed: float) -> void:
	if _rag:
		_sync_ragdoll()
		return
	if _dead:
		anim.advance(delta)
		_after_pose()
		return
	if crawling:
		_crawl_t += delta * (2.4 if moving else 0.6)
	if _attack_t > 0.0:
		_attack_t -= delta
		if anim.current_animation != "fury":
			anim.play("fury", 0.15)
			anim.seek(0.35, true)
		anim.speed_scale = 1.9
	else:
		if anim.current_animation != "walk":
			anim.play("walk", 0.25)
		anim.speed_scale = (anim_speed * (0.45 if crawling else 1.0)) if moving else 0.12
	anim.advance(delta)
	_apply_style()
	_after_pose()


## Coup de griffes (animation « fury » accélérée).
func attack() -> void:
	if _dead:
		return
	_attack_t = 0.9


func die() -> void:
	_dead = true
	anim.play("dead", 0.12)
	anim.speed_scale = 1.6
	for e in _eyes:
		e.visible = false


## Bascule en cadavre physique. `vel` : vitesse initiale de tous les corps ; `hit` : point d'impact
## (monde) et `kick` : impulsion supplémentaire appliquée au torse (fait tournoyer le corps).
## Retourne false si le ragdoll n'est pas possible (trop nombreux, squelette incomplet).
func start_ragdoll(vel: Vector3, hit: Vector3, kick: Vector3) -> bool:
	if _rag or _dead or active_ragdolls >= MAX_RAGDOLLS:
		return false
	for part in RAG_PARTS:
		if skeleton.find_bone(part[1]) < 0 or skeleton.find_bone(part[2]) < 0:
			return false
	_dead = true
	_rag = Node3D.new()
	_rag.top_level = true
	add_child(_rag)
	active_ragdolls += 1
	tree_exiting.connect(func(): active_ragdolls -= 1)
	var sx := skeleton.global_transform
	var scl := sx.basis.y.length() / SCALE # 1.0 pour un zombie à l'échelle normale
	var bodies := {}
	for part in RAG_PARTS:
		var a := sx * skeleton.get_bone_global_pose(skeleton.find_bone(part[1])).origin
		var b := sx * skeleton.get_bone_global_pose(skeleton.find_bone(part[2])).origin
		var axis := b - a
		var length := maxf(axis.length(), 0.05)
		var radius: float = part[3] * scl
		var body := RigidBody3D.new()
		body.name = part[0]
		body.mass = part[4]
		body.collision_layer = 0
		body.collision_mask = GameManager.L_WORLD
		body.linear_damp = 0.4
		body.angular_damp = 3.0
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = minf(radius, length * 0.5)
		cap.height = maxf(length + radius, cap.radius * 2.0 + 0.01)
		cs.shape = cap
		body.add_child(cs)
		_rag.add_child(body)
		var basis := Basis(Quaternion(Vector3.UP, axis.normalized()))
		body.global_transform = Transform3D(basis, (a + b) * 0.5)
		body.linear_velocity = vel
		bodies[part[0]] = body
		for bn in part[5]:
			var bi := skeleton.find_bone(bn)
			if bi >= 0:
				var bw := sx * skeleton.get_bone_global_pose(bi)
				_rag_bones.append([bi, body, body.global_transform.affine_inverse() * bw])
		if part[6] != "":
			var j := ConeTwistJoint3D.new()
			_rag.add_child(j)
			var jx := Basis(Quaternion(Vector3.RIGHT, axis.normalized())) # axe X de l'articulation = le long du membre
			j.global_transform = Transform3D(jx, a)
			j.node_a = j.get_path_to(bodies[part[6]])
			j.node_b = j.get_path_to(body)
			var limb: bool = part[0] != "head"
			j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, 1.0 if limb else 0.7)
			j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, 0.7)
	_rag_bones.sort_custom(func(x, y): return x[0] < y[0])
	(bodies["torso"] as RigidBody3D).apply_impulse(kick, hit - (bodies["torso"] as RigidBody3D).global_position)
	for mi in skeleton.get_parent().find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).extra_cull_margin = 4.0
	for e in _eyes:
		e.visible = false
	return true


func ragdoll_sink(amount: float) -> void:
	_rag_sink = amount


func _sync_ragdoll() -> void:
	var inv := skeleton.global_transform.affine_inverse()
	for e in _rag_bones:
		var w: Transform3D = (e[1] as RigidBody3D).global_transform * e[2]
		w.origin.y += _rag_sink
		var g: Transform3D = inv * w
		var i: int = e[0]
		var parent := skeleton.get_bone_parent(i)
		var pg := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
		var local := pg.affine_inverse() * g
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(i, local.basis.get_scale())
	_after_pose()


func hide_head() -> void:
	_headless = true
	for e in _eyes:
		e.visible = false
	_after_pose()


## Position monde d'un os (pour savoir quel membre a été touché).
func bone_pos(bone_name: String) -> Vector3:
	var i := skeleton.find_bone(bone_name)
	if i < 0:
		return Vector3.INF
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin


## Arrache un membre (l'os et ses enfants sont réduits à rien). Retourne false si déjà fait.
func sever(bone_name: String) -> bool:
	var i := skeleton.find_bone(bone_name)
	if i < 0 or _severed.has(i):
		return false
	_severed.append(i)
	_after_pose()
	return true


# --- Styles d'animation procéduraux (course, reptation) -------------------
# Repère du squelette : avant = -X, haut = +Y ; une rotation de +θ autour de +Z
# fait pencher le haut vers l'avant, -θ balance un bras pendant vers l'avant.

func _bone(n: String) -> int:
	if not _bones.has(n):
		_bones[n] = skeleton.find_bone(n)
	return _bones[n]


## Ajoute une rotation globale (autour de l'axe Z du squelette) à un os.
func _rot(n: String, angle: float, axis := Vector3(0, 0, 1)) -> void:
	var i := _bone(n)
	if i < 0 or absf(angle) < 0.0001:
		return
	var parent := skeleton.get_bone_parent(i)
	var pg := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local := Basis(skeleton.get_bone_pose_rotation(i))
	var out := pg.inverse() * Basis(axis, angle) * pg * local
	skeleton.set_bone_pose_rotation(i, out.get_rotation_quaternion())


func _apply_style() -> void:
	var ph := anim.current_animation_position / maxf(anim.current_animation_length, 0.01) * TAU if anim.current_animation == "walk" else 0.0
	if crawling:
		_rot("Bip01 Spine", -0.06)
		_rot("Bip01 Spine1", -0.06)
		_rot("Bip01 Spine2", -0.05)
		_rot("Bip01 Head", -0.35)
		if _attack_t <= 0.0:
			for side in [["L", 0.0], ["R", PI]]:
				var sw := sin(_crawl_t * 3.0 + side[1])
				_rot("Bip01 %s UpperArm" % side[0], -(PI * 0.88) - 0.5 * sw)
				_rot("Bip01 %s Forearm" % side[0], -0.5 + 0.5 * maxf(0.0, -sw))
		# buste qui se tord, jambes qui traînent et ruent en alternance
		_rot("Bip01 Spine1", 0.22 * sin(_crawl_t * 3.0), Vector3.UP)
		_rot("Bip01 Spine2", 0.18 * sin(_crawl_t * 3.0), Vector3.UP)
		_rot("Bip01 L Thigh", 0.25 + 0.18 * sin(_crawl_t * 3.0))
		_rot("Bip01 R Thigh", 0.25 - 0.18 * sin(_crawl_t * 3.0))
		_rot("Bip01 L Calf", 0.2 + 0.25 * maxf(0.0, sin(_crawl_t * 3.0)))
		_rot("Bip01 R Calf", 0.2 + 0.25 * maxf(0.0, -sin(_crawl_t * 3.0)))
	elif run_amount > 0.01:
		var r := run_amount
		_rot("Bip01 Spine", 0.14 * r)
		_rot("Bip01 Spine1", 0.14 * r)
		_rot("Bip01 Spine2", 0.12 * r)
		_rot("Bip01 Head", -0.3 * r)
		# torsion du buste en contre-rythme des épaules, tête qui compense
		_rot("Bip01 Spine1", 0.3 * r * sin(ph), Vector3.UP)
		_rot("Bip01 Head", -0.25 * r * sin(ph), Vector3.UP)
		_run_legs(r)
		if _attack_t <= 0.0:
			for side in [["L", 0.0], ["R", PI]]:
				var sw := sin(ph + side[1])
				_rot("Bip01 %s UpperArm" % side[0], r * (-0.35 - 0.75 * sw))
				_rot("Bip01 %s Forearm" % side[0], r * (-1.35 - 0.3 * sw))


## Foulée de course : amplifie le balancement de chaque cuisse (selon sa position réelle dans
## l'animation) et replie le mollet quand la jambe passe devant (genou levé).
func _run_legs(r: float) -> void:
	for side in ["L", "R"]:
		var ti := _bone("Bip01 %s Thigh" % side)
		var ci := _bone("Bip01 %s Calf" % side)
		if ti < 0 or ci < 0:
			continue
		var d := skeleton.get_bone_global_pose(ci).origin - skeleton.get_bone_global_pose(ti).origin
		var fwd := clampf(-d.x / 0.07, -1.0, 1.0) # >0 : la jambe est devant
		_rot("Bip01 %s Thigh" % side, -0.35 * r * fwd)
		_rot("Bip01 %s Calf" % side, r * (0.15 + 0.85 * maxf(0.0, fwd)))


func _after_pose() -> void:
	for i in _severed:
		skeleton.set_bone_pose_scale(i, Vector3.ONE * 0.001)
	if _headless and _head >= 0:
		skeleton.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
	if _head < 0 or _eyes.is_empty() or not _eyes[0].visible:
		return
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(_head)
	var b := global_basis
	var s := b.get_scale().x
	b = b.orthonormalized()
	var center := head.origin + Vector3.UP * 0.075 * s - b.z * 0.095 * s
	_eyes[0].global_position = center - b.x * 0.032 * s
	_eyes[1].global_position = center + b.x * 0.032 * s
	for e in _eyes:
		e.scale = Vector3.ONE * s


static func _get_library() -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
	for pair in [["walk", "walk.fbx", Animation.LOOP_LINEAR], ["fury", "fury.fbx", Animation.LOOP_NONE], ["dead", "dead.fbx", Animation.LOOP_NONE]]:
		var scene: Node = load(DIR + pair[1]).instantiate()
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate()
		a.loop_mode = pair[2]
		_library.add_animation(pair[0], a)
		scene.free()
	return _library


static func _material(tint: Color, variant := 0) -> StandardMaterial3D:
	var key := "%s|%d" % [tint.to_html(), variant]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + "diffuse_v%d.jpg" % clampi(variant, 0, VARIANTS - 1))
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(DIR + "normal.jpg")
	m.normal_scale = 1.2
	m.roughness = 0.75
	m.metallic_specular = 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m
