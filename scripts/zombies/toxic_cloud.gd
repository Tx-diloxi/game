extends Node3D
## Nuage toxique laissé par un Infecté : infecte le joueur qui reste dedans.

const Effects := preload("res://scripts/util/effects.gd")

const RADIUS := 2.2
const LIFETIME := 5.0

var _t := 0.0
var _puff := 0.0
var _light: OmniLight3D


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.9, 0.15)
	_light.light_energy = 1.2
	_light.omni_range = 4.0
	_light.position.y = 0.8
	add_child(_light)


func _physics_process(delta: float) -> void:
	_t += delta
	_puff -= delta
	if _puff <= 0.0:
		_puff = 0.35
		Effects.burst(self, global_position + Vector3.UP * 0.3, Vector3.UP, Color(0.45, 0.8, 0.15, 0.45), 6, 0.8, 0.9, 1.4, -0.2, 40.0, 60.0)
	_light.light_energy = 1.2 * (1.0 - _t / LIFETIME)
	for p in get_tree().get_nodes_in_group("player"):
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < RADIUS and p.has_method("infect"):
			p.infect(5.0)
	if _t >= LIFETIME:
		queue_free()
