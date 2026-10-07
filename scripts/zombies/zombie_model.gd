extends Node3D
## Modèle de zombie riggé (Kenney « Animated Characters Survivors », CC0).
## Anime le squelette manuellement (course / repos) puis force les bras vers l'avant.

const DIR := "res://assets/models/zombie/"
const MODEL_PATH := DIR + "characterMedium.fbx"
const SCALE := 0.5

static var _library: AnimationLibrary
static var _skins := {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var _arm_l := -1
var _arm_r := -1
var _forearm_l := -1
var _forearm_r := -1
var _head := -1
var _up_sk := Vector3.UP
var arm_raise := 1.0 # 0 = bras baissés (animation), 1 = bras tendus
var arm_swing := 0.0
var _eyes: Array[MeshInstance3D] = []


static func available() -> bool:
	return ResourceLoader.exists(MODEL_PATH)


func setup(skin: String, tint := Color.WHITE) -> void:
	var model: Node3D = load(MODEL_PATH).instantiate()
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = PI # le modèle regarde +Z, le jeu utilise -Z
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _skin_material(skin, tint)

	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.add_animation_library("", _get_library())
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.play("run")
	anim.seek(randf() * 0.6, true)

	_arm_l = skeleton.find_bone("LeftArm")
	_arm_r = skeleton.find_bone("RightArm")
	_forearm_l = skeleton.find_bone("LeftForeArm")
	_forearm_r = skeleton.find_bone("RightForeArm")
	_head = skeleton.find_bone("Head")

	# Yeux lumineux, recalés sur l'os de la tête à chaque frame.
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.6, 0.1) if tint.g > 0.62 else Color(1.0, 0.12, 0.05)
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_mat.albedo_color
	eye_mat.emission_energy_multiplier = 6.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 2:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.028
		sm.height = 0.04
		e.mesh = sm
		e.material_override = eye_mat
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.top_level = true
		add_child(e)
		_eyes.append(e)


## À appeler chaque frame : anime puis pose les bras.
func update_pose(delta: float, moving: bool, anim_speed: float) -> void:
	var wanted := "run" if moving else "idle"
	if anim.current_animation != wanted:
		anim.play(wanted, 0.2)
	anim.speed_scale = anim_speed if moving else 1.0
	anim.advance(delta)
	if arm_raise > 0.01:
		_pose_arm(_arm_l, 1.0)
		_pose_arm(_arm_r, -1.0)
	_place_eyes()


func _place_eyes() -> void:
	if _head < 0 or _eyes.is_empty() or not _eyes[0].visible:
		return
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(_head).origin
	var b := global_basis
	var s := b.get_scale().x
	b = b.orthonormalized()
	var center := head + b.y * 0.31 * s - b.z * 0.24 * s
	_eyes[0].global_position = center - b.x * 0.09 * s
	_eyes[1].global_position = center + b.x * 0.09 * s
	for e in _eyes:
		e.scale = Vector3.ONE * s


func hide_head() -> void:
	if _head >= 0:
		skeleton.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
	for e in _eyes:
		e.visible = false


func _pose_arm(bone: int, side: float) -> void:
	if bone < 0:
		return
	_up_sk = (skeleton.global_basis.inverse() * Vector3.UP).normalized()
	var parent := skeleton.get_bone_parent(bone)
	var rest_g := skeleton.get_bone_global_rest(bone).basis
	# Tourne le bras (en T-pose le long de ±X) vers l'avant du modèle, légèrement relevé.
	var yaw := -side * PI * 0.5 * arm_raise + arm_swing * side
	var target_g := Basis(_up_sk, yaw) * rest_g
	var parent_g := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	var local := (parent_g.inverse() * target_g).orthonormalized()
	skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
	var fore := _forearm_l if side > 0.0 else _forearm_r
	if fore >= 0:
		skeleton.set_bone_pose_rotation(fore, skeleton.get_bone_rest(fore).basis.get_rotation_quaternion())


static func _get_library() -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
	for pair in [["idle", "idle.fbx", "Root|Idle"], ["run", "run.fbx", "Root|Run"]]:
		var scene: Node = load(DIR + pair[1]).instantiate()
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = ap.get_animation(pair[2]).duplicate()
		a.loop_mode = Animation.LOOP_LINEAR
		_library.add_animation(pair[0], a)
		scene.free()
	return _library


static func _skin_material(skin: String, tint: Color) -> StandardMaterial3D:
	var key := skin + tint.to_html()
	if _skins.has(key):
		return _skins[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + skin + ".png")
	m.albedo_color = tint
	m.roughness = 0.9
	_skins[key] = m
	return m
