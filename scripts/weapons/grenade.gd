extends RigidBody3D
## Grenade à fragmentation : explose après un délai.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")

const FUSE := 2.2
const RADIUS := 5.5

var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = GameManager.L_WORLD
	mass = 0.4
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.3
	physics_material_override.friction = 0.8
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.08
	cs.shape = s
	add_child(cs)
	const MODEL := "res://assets/models/weapons/grenade-a.glb"
	if ResourceLoader.exists(MODEL):
		var m: Node3D = load(MODEL).instantiate()
		m.scale = Vector3.ONE * 0.7
		m.position.y = -0.08
		add_child(m)
	else:
		MeshUtil.sphere_mesh(self, 0.08, Vector3.ZERO, MeshUtil.mat(Color(0.2, 0.28, 0.15), 0.0, 0.6, 0.3))
	MeshUtil.sphere_mesh(self, 0.02, Vector3(0, 0.1, 0), MeshUtil.mat(Color(1.0, 0.2, 0.1), 3.0))


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= FUSE:
		set_physics_process(false)
		var dmg := 150.0 + 60.0 * GameManager.round_num
		if GameManager.game:
			GameManager.game.explode(global_position, RADIUS, dmg, "explosion", true)
		queue_free()
