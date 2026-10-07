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


static func available() -> bool:
	return ResourceLoader.exists(BASE) and ResourceLoader.exists(DIR + "diffuse.jpg")


func setup(_skin: String, tint := Color.WHITE) -> void:
	var pivot := Node3D.new()
	pivot.scale = Vector3.ONE * SCALE
	pivot.rotation.y = -PI * 0.5 # le modèle regarde -X, le jeu utilise -Z
	add_child(pivot)
	var model: Node3D = load(BASE).instantiate()
	model.position = -ORIGIN_OFFSET
	pivot.add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _material(tint)
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
	if _dead:
		anim.advance(delta)
		_after_pose()
		return
	if _attack_t > 0.0:
		_attack_t -= delta
		if anim.current_animation != "fury":
			anim.play("fury", 0.15)
			anim.seek(0.35, true)
		anim.speed_scale = 1.9
	else:
		if anim.current_animation != "walk":
			anim.play("walk", 0.25)
		anim.speed_scale = anim_speed if moving else 0.12
	anim.advance(delta)
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


static func _material(tint: Color) -> StandardMaterial3D:
	var key := tint.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + "diffuse.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(DIR + "normal.jpg")
	m.normal_scale = 1.2
	m.roughness = 0.75
	m.metallic_specular = 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m
