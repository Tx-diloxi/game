extends Node3D
## Orage : pluie autour du joueur (seulement à ciel ouvert), éclairs et tonnerre en différé.

const MIN_GAP := 14.0
const MAX_GAP := 34.0

var game: Node
var player: Node3D
var _rain: GPUParticles3D
var _rain_sound: AudioStreamPlayer
var _flash: DirectionalLight3D
var _next_flash := 8.0
var _outside := false


func _ready() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 2400
	_rain.lifetime = 0.9
	_rain.visibility_aabb = AABB(Vector3(-14, -12, -14), Vector3(28, 24, 28))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 0.5, 9)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 19.0
	pm.gravity = Vector3.ZERO
	_rain.process_material = pm
	var streak := QuadMesh.new()
	streak.size = Vector2(0.012, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.7, 0.8, 0.95, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	streak.material = mat
	_rain.draw_pass_1 = streak
	_rain.emitting = false
	add_child(_rain)

	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.bus = "SFX"
	_rain_sound.stream = Audio._pick("rain")
	_rain_sound.volume_db = -60.0
	add_child(_rain_sound)
	_rain_sound.play()

	_flash = DirectionalLight3D.new()
	_flash.light_color = Color(0.75, 0.85, 1.0)
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	_flash.rotation_degrees = Vector3(-60, 20, 0)
	add_child(_flash)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_rain.global_position = player.global_position + Vector3(0, 9, 0)
	_rain.global_rotation = Vector3.ZERO
	_outside = _is_outside()
	_rain.emitting = _outside and GameManager.weather
	_rain.visible = _rain.emitting # coupe aussi les gouttes déjà en l'air quand on entre
	var target := (-9.0 if _outside else -24.0) if GameManager.weather else -60.0
	_rain_sound.volume_db = move_toward(_rain_sound.volume_db, target, delta * 30.0)
	if not GameManager.weather:
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(MIN_GAP, MAX_GAP)
		lightning()


## Vrai si le joueur n'est sous aucun plafond (les plafonds n'ont pas de collision : on teste leurs emprises).
func _is_outside() -> bool:
	var p := Vector2(player.global_position.x, player.global_position.z)
	for r in game.roofs:
		if r.has_point(p):
			return false
	return true


## Éclair (double impulsion) puis tonnerre après un délai.
func lightning() -> void:
	var tw := create_tween()
	tw.tween_property(_flash, "light_energy", 1.6, 0.04)
	tw.tween_property(_flash, "light_energy", 0.2, 0.08)
	tw.tween_property(_flash, "light_energy", 1.0, 0.05)
	tw.tween_property(_flash, "light_energy", 0.0, 0.35)
	var delay := randf_range(0.4, 3.0)
	get_tree().create_timer(delay, false).timeout.connect(func():
		Audio.play("thunder", -3.0 - delay * 2.0, randf_range(0.85, 1.1)))
