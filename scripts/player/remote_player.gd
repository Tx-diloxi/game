extends Node3D
## Avatar d'un autre joueur en coop : silhouette, nom, arme en main ; position lissée.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const WeaponDB := preload("res://scripts/weapons/weapon_db.gd")

var peer_id := 0
var player_name := ""
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var pitch := 0.0
var weapon_id := ""
var downed := false
var _head: Node3D
var _gun_root: Node3D
var _gun_id := ""
var _label: Label3D


func _ready() -> void:
	var col := Color.from_hsv(fmod(peer_id * 0.17, 1.0), 0.55, 0.8)
	var body_mat := MeshUtil.mat(col.darkened(0.3))
	MeshUtil.cylinder_mesh(self, 0.3, 1.1, Vector3(0, 0.75, 0), body_mat)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.55, 0)
	add_child(_head)
	MeshUtil.sphere_mesh(_head, 0.17, Vector3.ZERO, MeshUtil.mat(Color(0.8, 0.62, 0.5)))
	_gun_root = Node3D.new()
	_gun_root.position = Vector3(0.22, -0.3, -0.3)
	_head.add_child(_gun_root)
	_label = MeshUtil.label3d(self, player_name, Vector3(0, 2.1, 0), 32, col.lightened(0.4))
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	global_position = target_pos


func apply_state(s: Dictionary) -> void:
	target_pos = s.get("pos", target_pos)
	target_yaw = s.get("yaw", target_yaw)
	pitch = s.get("pitch", pitch)
	weapon_id = s.get("weapon", weapon_id)
	downed = s.get("downed", false)


func _process(delta: float) -> void:
	var k := minf(delta * 12.0, 1.0)
	global_position = global_position.lerp(target_pos, k)
	rotation.y = lerp_angle(rotation.y, target_yaw, k)
	_head.rotation.x = lerp_angle(_head.rotation.x, pitch, k)
	scale.y = 0.45 if downed else 1.0
	if weapon_id != _gun_id:
		_gun_id = weapon_id
		for c in _gun_root.get_children():
			c.queue_free()
		if _gun_id != "" and WeaponDB.WEAPONS.has(_gun_id):
			var d := WeaponDB.data(_gun_id)
			MeshUtil.build_gun(_gun_root, _gun_id, 0, d.color, d.kind)
