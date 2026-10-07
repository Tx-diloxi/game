extends "res://scripts/interactables/interactable.gd"
## Interrupteur général : active le courant (atouts, machine d'amélioration, lumières).

var _lever: Node3D
var _lamp: MeshInstance3D


func _ready() -> void:
	radius = 2.0
	var metal := Mat.metal(Color(0.4, 0.45, 0.38))
	MeshUtil.box_mesh(self, Vector3(0.9, 1.3, 0.25), Vector3(0, 1.4, 0.12), metal)
	MeshUtil.label3d(self, "COURANT", Vector3(0, 2.25, 0.26), 56, Color(1.0, 0.85, 0.2))
	_lamp = MeshUtil.sphere_mesh(self, 0.08, Vector3(0.3, 1.95, 0.28), MeshUtil.mat(Color(1.0, 0.1, 0.1), 2.0))
	_lever = Node3D.new()
	_lever.position = Vector3(0, 1.4, 0.3)
	_lever.rotation.x = -0.8
	add_child(_lever)
	MeshUtil.box_mesh(_lever, Vector3(0.08, 0.5, 0.08), Vector3(0, 0.25, 0), MeshUtil.mat(Color(0.6, 0.1, 0.1)))


func is_available(_player: Node) -> bool:
	return not GameManager.power_on


func get_prompt(_player: Node) -> String:
	return "[F] Rétablir le courant"


func interact(_player: Node) -> void:
	if GameManager.power_on:
		return
	create_tween().tween_property(_lever, "rotation:x", 0.8, 0.4)
	_lamp.material_override = MeshUtil.mat(Color(0.1, 1.0, 0.2), 2.0)
	Audio.play("power_on", 2.0)
	GameManager.set_power(true)
	GameManager.show_message("COURANT RÉTABLI", Color(1.0, 0.9, 0.3))
	Audio.say("power_on")
