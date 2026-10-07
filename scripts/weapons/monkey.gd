extends RigidBody3D
## Singe-leurre : jouet mécanique à cymbales. Une fois posé, il joue sa mélodie et attire
## tous les zombies (pas les chiens), puis explose violemment.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")

const ACTIVE_TIME := 7.0
const RADIUS := 6.0
const LURE_RANGE := 40.0

var _t := 0.0
var _armed := false
var _arms: Array[Node3D] = []
var _light: OmniLight3D
var _beep := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = GameManager.L_WORLD
	mass = 0.6
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.15
	physics_material_override.friction = 1.0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.18, 0.28, 0.14)
	cs.shape = box
	cs.position.y = 0.14
	add_child(cs)

	var fur := MeshUtil.mat(Color(0.45, 0.28, 0.15), 0.0, 1.0)
	var face := MeshUtil.mat(Color(0.85, 0.7, 0.55))
	var red := MeshUtil.mat(Color(0.7, 0.05, 0.05))
	var brass := MeshUtil.mat(Color(0.85, 0.65, 0.2), 0.3, 0.3, 0.9)
	MeshUtil.capsule_mesh(self, 0.07, 0.2, Vector3(0, 0.12, 0), fur)
	MeshUtil.box_mesh(self, Vector3(0.15, 0.06, 0.11), Vector3(0, 0.06, 0), red) # culotte
	MeshUtil.sphere_mesh(self, 0.065, Vector3(0, 0.26, 0), fur)
	MeshUtil.sphere_mesh(self, 0.042, Vector3(0, 0.25, -0.04), face)
	MeshUtil.cylinder_mesh(self, 0.045, 0.04, Vector3(0, 0.33, 0), red) # fez
	for side in [-1.0, 1.0]:
		MeshUtil.sphere_mesh(self, 0.022, Vector3(0.065 * side, 0.27, 0), face)
		var arm := Node3D.new()
		arm.position = Vector3(0.07 * side, 0.17, 0)
		add_child(arm)
		MeshUtil.capsule_mesh(arm, 0.02, 0.1, Vector3(0, 0, -0.05), fur, Vector3(PI / 2, 0, 0))
		MeshUtil.cylinder_mesh(arm, 0.045, 0.006, Vector3(-0.01 * side, 0, -0.1), brass, Vector3(0, 0, PI / 2))
		_arms.append(arm)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.2, 0.1)
	_light.light_energy = 0.0
	_light.omni_range = 3.0
	_light.position.y = 0.4
	add_child(_light)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _armed:
		if _t > 0.4 and linear_velocity.length() < 0.3:
			_arm()
		elif _t > 3.0:
			_arm()
		return
	# Cymbales qui claquent
	var clap := absf(sin(_t * 9.0))
	_arms[0].rotation.y = -0.9 * clap
	_arms[1].rotation.y = 0.9 * clap
	_beep -= delta
	if _beep <= 0.0:
		_beep = 0.45
		Audio.play_at("monkey_cymbal", global_position, 2.0, randf_range(0.95, 1.05))
	_light.light_energy = 2.5 if fmod(_t, 0.5) < 0.25 else 0.3
	if _t >= ACTIVE_TIME:
		set_physics_process(false)
		if GameManager.game:
			GameManager.game.decoy = null
			GameManager.game.explode(global_position + Vector3.UP * 0.2, RADIUS, 4000.0 + 400.0 * GameManager.round_num, "explosion", true)
		queue_free()


func _arm() -> void:
	_armed = true
	_t = 0.0
	freeze = true
	rotation = Vector3(0, rotation.y, 0)
	Audio.play_at("box_jingle", global_position, 0.0, 1.3)
	if GameManager.game:
		GameManager.game.decoy = self
