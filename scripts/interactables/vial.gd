extends "res://scripts/interactables/interactable.gd"
## Fiole de sérum cachée (quête secrète du laboratoire) : trois à retrouver.

var _light: OmniLight3D


func _ready() -> void:
	radius = 1.7
	MeshUtil.cylinder_mesh(self, 0.045, 0.18, Vector3(0, 0.09, 0), MeshUtil.mat(Color(0.4, 1.0, 0.5), 2.5))
	MeshUtil.cylinder_mesh(self, 0.05, 0.03, Vector3(0, 0.19, 0), Mat.metal(Color(0.3, 0.3, 0.3)))
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 1.0, 0.5)
	_light.light_energy = 0.35
	_light.omni_range = 2.2
	_light.position.y = 0.25
	add_child(_light)


func get_prompt(_player: Node) -> String:
	return "[F] Ramasser la fiole"


func interact(_player: Node) -> void:
	GameManager.quest_vials += 1
	remove_from_group("interactable")
	Audio.play("perk_drink", -6.0, 1.6)
	GameManager.show_message("FIOLE DE SÉRUM  %d/3" % GameManager.quest_vials, Color(0.4, 1.0, 0.5),
		"Rapportez-les à la console du réacteur" if GameManager.quest_vials >= 3 else "Il en reste à trouver…")
	queue_free()
