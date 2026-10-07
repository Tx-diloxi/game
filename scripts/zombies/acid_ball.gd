extends Node3D
## Crachat acide du Cracheur : boule qui vole en arc, s'écrase sur le décor ou sur le joueur.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const Effects := preload("res://scripts/util/effects.gd")

const GRAVITY := 4.0
const DAMAGE := 25.0
const LIFETIME := 4.0

var velocity := Vector3.ZERO
var _t := 0.0
var _light: OmniLight3D


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.9, 0.15, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 0.1)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshUtil.sphere_mesh(self, 0.14, Vector3.ZERO, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 0.9, 0.1)
	_light.light_energy = 1.2
	_light.omni_range = 3.0
	add_child(_light)
	Effects.burst(get_parent(), global_position, Vector3.UP, Color(0.4, 0.9, 0.15, 0.8), 6, 1.0, 0.1, 0.5, 0.0, 2.0, 180.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFETIME:
		queue_free()
		return
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, GameManager.L_WORLD | GameManager.L_PLAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	_impact(hit)


func _impact(hit: Dictionary) -> void:
	var game := GameManager.game
	var pos: Vector3 = hit.position
	Audio.play_at("acid_hit", pos, -2.0)
	if game:
		Effects.burst(game, pos, hit.normal, Color(0.4, 0.9, 0.15, 0.8), 14, 3.0, 0.12, 0.6, 6.0, 2.0, 70.0)
		var decal := Effects.blood_decal(game, pos, randf_range(0.6, 1.0), hit.normal)
		(decal.material_override as ShaderMaterial).set_shader_parameter("blood_color", Color(0.25, 0.55, 0.05, 0.9))
	var col: Object = hit.collider
	if col != null and col.is_in_group("player"):
		col.take_damage(DAMAGE)
		GameManager.vibrate(0.3, 0.6, 0.2)
	queue_free()
