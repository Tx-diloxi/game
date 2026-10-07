extends Node3D
## Chien de l'enfer : loup riggé (umask007, CC-BY-SA 3.0 — opengameart.org/content/winter-wolf-normal-wolf),
## converti en glTF. Animations course / attaque / mort, pelage assombri et yeux incandescents.
## Même interface que zombie_model_real.gd.

const DIR := "res://assets/models/dog/"
const BASE := DIR + "wolf.glb"
const SCALE := 0.55

static var _mat_fur: StandardMaterial3D
static var _mat_eye: StandardMaterial3D

var skeleton: Skeleton3D
var anim: AnimationPlayer
var arm_raise := 0.0 # compatibilité (non utilisé)
var arm_swing := 0.0
# Compatibilité avec zombie_model_real.gd (non utilisés par le chien)
var run_amount := 0.0
var crawling := false
var _eyes: Array[MeshInstance3D] = []
var _head := -1
var _attack_t := 0.0
var _dead := false


static func available() -> bool:
	return ResourceLoader.exists(BASE)


func setup(_skin := "", _tint := Color.WHITE) -> void:
	var pivot := Node3D.new()
	pivot.scale = Vector3.ONE * SCALE
	pivot.rotation.y = PI * 0.5 # le loup regarde +X, le jeu utilise -Z
	pivot.position.x = 0.0
	add_child(pivot)
	var model: Node3D = load(BASE).instantiate()
	model.position.x = -0.1 # recentre le corps sur la collision
	pivot.add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for a in ["run", "idle"]:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.play("run")
	anim.seek(randf() * 0.9, true)
	_head = skeleton.find_bone("head")

	_init_materials()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(i)
			var sname := src.resource_name if src else ""
			if sname.begins_with("fell"):
				m3.set_surface_override_material(i, _mat_fur)
			elif sname.begins_with("eye"):
				m3.set_surface_override_material(i, _mat_eye)

	for i in 2:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.02
		sm.height = 0.03
		sm.radial_segments = 8
		sm.rings = 4
		e.mesh = sm
		e.material_override = _mat_eye
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.top_level = true
		add_child(e)
		_eyes.append(e)


func update_pose(delta: float, moving: bool, anim_speed: float) -> void:
	if _dead:
		anim.advance(delta)
		return
	if _attack_t > 0.0:
		_attack_t -= delta
		if anim.current_animation != "attack":
			anim.play("attack", 0.08)
		anim.speed_scale = 1.2
	else:
		var wanted := "run" if moving else "idle"
		if anim.current_animation != wanted:
			anim.play(wanted, 0.15)
		anim.speed_scale = anim_speed if moving else 1.0
	anim.advance(delta)
	_place_eyes()


func attack() -> void:
	if not _dead:
		_attack_t = 0.5


func die() -> void:
	_dead = true
	anim.play("die", 0.05)
	anim.speed_scale = 0.6
	for e in _eyes:
		e.visible = false


func hide_head() -> void:
	for e in _eyes:
		e.visible = false


func _place_eyes() -> void:
	if _head < 0 or not _eyes[0].visible:
		return
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(_head)
	var b := global_basis
	var s := b.get_scale().x
	b = b.orthonormalized()
	var center := head.origin - b.z * 0.09 * s + Vector3.UP * 0.0
	_eyes[0].global_position = center - b.x * 0.045 * s
	_eyes[1].global_position = center + b.x * 0.045 * s


static func _init_materials() -> void:
	if _mat_fur:
		return
	_mat_fur = StandardMaterial3D.new()
	_mat_fur.albedo_texture = load(DIR + "fellGrey.png")
	_mat_fur.albedo_color = Color(0.32, 0.22, 0.18)
	_mat_fur.roughness = 0.95
	_mat_fur.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_eye = StandardMaterial3D.new()
	_mat_eye.albedo_color = Color(1.0, 0.35, 0.0)
	_mat_eye.emission_enabled = true
	_mat_eye.emission = Color(1.0, 0.35, 0.0)
	_mat_eye.emission_energy_multiplier = 6.0
	_mat_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
