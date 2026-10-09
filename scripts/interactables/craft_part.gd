extends "res://scripts/interactables/interactable.gd"
## Pièce cachée de l'arme unique : trois à retrouver puis à assembler à l'établi.

const NAMES := ["Bobine", "Batterie", "Condensateur"]
const COLORS := [Color(1.0, 0.6, 0.2), Color(0.3, 0.8, 1.0), Color(0.9, 0.4, 1.0)]

var index := 0


func _ready() -> void:
	radius = 1.7
	var col: Color = COLORS[index]
	match index:
		0: MeshUtil.cylinder_mesh(self, 0.09, 0.14, Vector3(0, 0.1, 0), MeshUtil.mat(col, 2.0))
		1: MeshUtil.box_mesh(self, Vector3(0.18, 0.1, 0.1), Vector3(0, 0.07, 0), MeshUtil.mat(col, 2.0))
		_: MeshUtil.sphere_mesh(self, 0.08, Vector3(0, 0.1, 0), MeshUtil.mat(col, 2.0))
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.4
	l.omni_range = 2.2
	l.position.y = 0.25
	add_child(l)


func get_prompt(_player: Node) -> String:
	return "[F] Ramasser : %s" % NAMES[index]


func interact(_player: Node) -> void:
	GameManager.craft_parts[index] = true
	remove_from_group("interactable")
	Audio.play("perk_drink", -6.0, 1.4)
	var n := GameManager.craft_count()
	GameManager.show_message("PIÈCE : %s  %d/3" % [NAMES[index].to_upper(), n], COLORS[index],
		"Assemblez l'arme à l'établi" if n >= 3 else "Il en reste à trouver…")
	queue_free()
