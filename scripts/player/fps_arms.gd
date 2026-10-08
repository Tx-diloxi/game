extends Node3D
## Bras du joueur en vue subjective. Modèle « FPS Arms (Rigged Only) » (CC0, MakeHuman).
## Les épaules restent fixes dans l'espace caméra ; chaque poignet est amené sur l'arme par une
## IK à deux os analytique, la main est orientée par un repère (doigts, paume) et les doigts
## sont refermés autour de la poignée.

const MODEL := "res://assets/models/arms/arms.fbx"
const TEXTURE := "res://assets/models/arms/arms_diffuse.png"
const RIG_SCALE := 1.05
## Position de l'origine du modèle dans l'espace caméra (le milieu des épaules).
const RIG_POS := Vector3(0.0, -0.3, 0.0)

var sk: Skeleton3D
var _b := {}          # noms d'os -> index
var _rest := {}       # index -> Transform3D (repos global, espace squelette)
var _len := {}        # "R"/"L" -> [L1, L2]
var _frame_rest := {} # "R"/"L" -> Basis du repère de main au repos
var _fingers := {"R": [], "L": []}
var visible_arms := true
var _sleeve_mat: StandardMaterial3D


static func available() -> bool:
	return ResourceLoader.exists(MODEL)


func _ready() -> void:
	var model: Node3D = load(MODEL).instantiate()
	add_child(model)
	rotation.y = PI # le modèle regarde +Z, la caméra regarde -Z
	scale = Vector3.ONE * RIG_SCALE
	position = RIG_POS
	sk = model.find_children("*", "Skeleton3D", true, false)[0]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEXTURE)
	mat.albedo_color = Color(0.82, 0.78, 0.74)
	mat.roughness = 0.8
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 4.0
	for i in sk.get_bone_count():
		_b[sk.get_bone_name(i)] = i
	_sleeve_mat = StandardMaterial3D.new()
	_sleeve_mat.albedo_color = Color(0.16, 0.18, 0.14)
	_sleeve_mat.roughness = 1.0
	# repos global (espace squelette) de chaque os
	sk.reset_bone_poses()
	for i in sk.get_bone_count():
		_rest[i] = sk.get_bone_global_pose(i)
	for s in ["R", "L"]:
		var sh: Vector3 = _rest[_b["upper_arm." + s]].origin
		var el: Vector3 = _rest[_b["forearm." + s]].origin
		var wr: Vector3 = _rest[_b["forearm.%s_end" % s]].origin
		_len[s] = [sh.distance_to(el), el.distance_to(wr)]
		_frame_rest[s] = _hand_frame_rest(s)
		for f in ["index", "middle", "ring", "pinky"]:
			_fingers[s].append([_b["f_%s.01.%s" % [f, s]], _b["f_%s.02.%s" % [f, s]], _b["f_%s.03.%s" % [f, s]]])
		_fingers[s].append([_b["thumb.01." + s], _b["thumb.02." + s], _b["thumb.03." + s]])
		_add_sleeve(s)


## Manche de vêtement (cylindres) sur le bras et l'avant-bras, accrochée aux os.
func _add_sleeve(s: String) -> void:
	var specs := [["upper_arm." + s, "forearm." + s, 0.9, 0.74, 0.92], ["forearm." + s, "forearm.%s_end" % s, 0.7, 0.46, 0.74]]
	for sp in specs:
		var bi: int = _b[sp[0]]
		var ni: int = _b[sp[1]]
		var att := BoneAttachment3D.new()
		att.bone_name = sp[0]
		sk.add_child(att)
		var axis: Vector3 = ((_rest[bi].basis.inverse()) * (_rest[ni].origin - _rest[bi].origin)).normalized()
		var length: float = _rest[bi].origin.distance_to(_rest[ni].origin) * sp[4]
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = sp[3]
		cm.bottom_radius = sp[2]
		cm.height = length
		cm.radial_segments = 14
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = _sleeve_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# le cylindre (axe Y, sommet = bout) est orienté le long de l'os
		var q := Quaternion(Vector3.UP, axis)
		mi.transform = Transform3D(Basis(q), axis * length * 0.5 + axis * 0.0)
		att.add_child(mi)


## Repère de la main au repos : Z = direction des doigts, Y = normale de la paume.
func _hand_frame_rest(s: String) -> Basis:
	var h: Vector3 = _rest[_b["hand." + s]].origin
	var tip: Vector3 = _rest[_b["f_middle.03.%s_end" % s]].origin
	var f := (tip - h).normalized()
	var side: Vector3 = (_rest[_b["palm_index." + s]].origin - _rest[_b["palm_pinky." + s]].origin).normalized()
	var n := f.cross(side).normalized()
	if s == "L":
		n = -n
	return _frame(f, n)


static func _frame(f: Vector3, n: Vector3) -> Basis:
	var fz := f.normalized()
	var ny := (n - fz * n.dot(fz)).normalized()
	return Basis(ny.cross(fz), ny, fz)


func _set_global(i: int, b: Basis, o: Vector3) -> void:
	var p := sk.get_bone_parent(i)
	var pg := sk.get_bone_global_pose(p) if p >= 0 else Transform3D()
	# Godot 4 : la pose d'un os est son transform local (global = parent_global * pose).
	var local := pg.affine_inverse() * Transform3D(b.orthonormalized(), o)
	sk.set_bone_pose_position(i, local.origin)
	sk.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
	sk.set_bone_pose_scale(i, local.basis.get_scale())


## Tourne un os autour de l'axe global donné (autour de son origine).
func _curl(i: int, axis: Vector3, angle: float) -> void:
	var g := sk.get_bone_global_pose(i)
	_set_global(i, Basis(axis.normalized(), angle) * g.basis, g.origin)


## Pose un bras. Cibles en espace squelette : poignet `wrist`, doigts `f` (direction) et paume `n`.
## `pole` : direction (espace squelette) vers laquelle le coude plie.
func solve_arm(s: String, wrist: Vector3, f: Vector3, n: Vector3, pole: Vector3, curl: float, thumb_curl: float) -> void:
	var ua: int = _b["upper_arm." + s]
	var fa: int = _b["forearm." + s]
	var sh: Vector3 = _rest[ua].origin
	var l1: float = _len[s][0]
	var l2: float = _len[s][1]
	var d := wrist - sh
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.995)
	var dir := d.normalized()
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pp := (pole - dir * pole.dot(dir)).normalized()
	var elbow := sh + dir * a + pp * h
	var tgt := sh + dir * dist
	# humérus
	var u0: Vector3 = (_rest[fa].origin - sh).normalized()
	var q1 := Quaternion(u0, (elbow - sh).normalized())
	_set_global(ua, Basis(q1) * _rest[ua].basis, sh)
	# avant-bras
	var w0: Vector3 = _rest[_b["forearm.%s_end" % s]].origin
	var f0: Vector3 = (w0 - _rest[fa].origin).normalized()
	var q2 := Quaternion(f0, (tgt - elbow).normalized())
	_set_global(fa, Basis(q2) * _rest[fa].basis, elbow)
	# main (os de contrôle racine) : orientée par le repère voulu
	var hc: int = _b["hand.%s.control" % s]
	var rot := _frame(f, n) * (_frame_rest[s] as Basis).inverse()
	_set_global(hc, rot * _rest[hc].basis, tgt)
	# doigts refermés autour de la poignée (axe = doigts × paume)
	var axis := f.normalized().cross(n.normalized()).normalized()
	for k in 4:
		var ch: Array = _fingers[s][k]
		_curl(ch[0], axis, curl * 0.8)
		_curl(ch[1], axis, curl * 1.0)
		_curl(ch[2], axis, curl * 0.7)
	var th: Array = _fingers[s][4]
	_curl(th[0], axis, thumb_curl * 0.5)
	_curl(th[1], axis, thumb_curl * 0.6)
	_curl(th[2], axis, thumb_curl * 0.5)


## Place les deux bras d'après le repère de l'arme (`gun` : nœud de l'arme, -Z = canon).
## `grip` : dictionnaire de la prise (voir FpsArms.grip_for) ; `extra_left` : décalage local de la main gauche (rechargement).
func update_for_gun(gun: Node3D, grip: Dictionary, extra_left := Vector3.ZERO, left_curl_scale := 1.0, extra_right := Vector3.ZERO) -> void:
	if sk == null:
		return
	sk.reset_bone_poses()
	var to_sk := sk.global_transform.affine_inverse()
	var gx := gun.global_transform
	var gb := gx.basis.orthonormalized()
	for s in ["R", "L"]:
		var p: Dictionary = grip[s]
		var local: Vector3 = p.wrist + (extra_left if s == "L" else extra_right)
		var wrist: Vector3 = to_sk * (gx * local)
		var f: Vector3 = (to_sk.basis * (gb * p.f)).normalized()
		var n: Vector3 = (to_sk.basis * (gb * p.n)).normalized()
		var pole: Vector3 = (to_sk.basis * (get_parent().global_basis * Vector3(0.55 if s == "R" else -0.55, -1.0, 0.25))).normalized()
		solve_arm(s, wrist, f, n, pole, p.curl * (left_curl_scale if s == "L" else 1.0), p.thumb)


## Prise sur une arme. `d` = entrée de WeaponDB (champs optionnels "grip_r", "grip_l" : centres des
## poignées en repère de l'arme ; "grip_l_mode" : "side" (main à plat sur le côté, ex. chargeur)
## ou "under" (main en coupe sous le canon).
static func grip_for(d: Dictionary) -> Dictionary:
	var l: float = d.get("length", 0.4)
	var gr: Vector3 = d.get("grip_r", Vector3(0.0, -0.05, l * 0.2))
	var gl: Vector3 = d.get("grip_l", Vector3(0.0, -0.06, -l * 0.1))
	var mode: String = d.get("grip_l_mode", "side")
	# Main droite : à droite de la poignée, poignet derrière, doigts vers l'avant et un peu vers le bas.
	var right := {
		"wrist": gr + Vector3(0.032, 0.012, 0.075),
		"f": Vector3(-0.08, -0.25, -0.96), "n": Vector3(-1, 0, 0), "curl": 1.05, "thumb": 0.7,
	}
	var left: Dictionary
	if mode == "under":
		left = {"wrist": gl + Vector3(0.0, -0.035, 0.07), "f": Vector3(0, 0.0, -1), "n": Vector3(0, 1, 0), "curl": 0.9, "thumb": 0.5}
	else:
		left = {"wrist": gl + Vector3(-0.035, 0.0, 0.07), "f": Vector3(0.1, -0.2, -0.97), "n": Vector3(1, 0.05, 0), "curl": 1.0, "thumb": 0.6}
	return {"R": right, "L": left}
