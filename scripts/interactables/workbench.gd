extends "res://scripts/interactables/interactable.gd"
## Établi : assemble l'arme unique (Arc Tonnerre) avec les trois pièces cachées sur la carte.

const WEAPON_ID := "arc_tonnerre"
const BUILD_TIME := 4.0

var _t := -1.0
var _slots: Array[MeshInstance3D] = []
var _light: OmniLight3D


func _ready() -> void:
	radius = 2.2
	var wood := Mat.metal(Color(0.3, 0.22, 0.15))
	MeshUtil.box_mesh(self, Vector3(1.8, 0.08, 0.8), Vector3(0, 0.95, 0), wood)
	for x in [-0.8, 0.8]:
		MeshUtil.box_mesh(self, Vector3(0.1, 0.95, 0.7), Vector3(x, 0.47, 0), wood)
	MeshUtil.static_box(self, Vector3(1.8, 1.0, 0.8), Vector3(0, 0.5, 0), null)
	for i in 3:
		var s := MeshUtil.sphere_mesh(self, 0.07, Vector3(-0.5 + 0.5 * i, 1.05, 0), MeshUtil.mat(Color(0.15, 0.15, 0.15)))
		_slots.append(s)
	MeshUtil.label3d(self, "ÉTABLI", Vector3(0, 1.7, 0.1), 48, Color(1.0, 0.7, 0.3))
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.8, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 3.5
	_light.position = Vector3(0, 1.4, 0.3)
	add_child(_light)


func is_available(_player: Node) -> bool:
	return not GameManager.craft_done and _t < 0.0


func get_prompt(_player: Node) -> String:
	var n := GameManager.craft_count()
	if n < 3:
		return "Établi : pièces %d/3" % n
	return "[F] Assembler l'Arc Tonnerre"


func interact(player: Node) -> void:
	if GameManager.craft_count() < 3:
		Audio.play("deny")
		return
	_t = BUILD_TIME
	player.set_meta("crafting", true)
	Audio.play_at("power_on", global_position + Vector3.UP, 0.0, 1.5)


func _process(delta: float) -> void:
	for i in 3:
		(_slots[i] as MeshInstance3D).material_override = MeshUtil.mat(
			preload("res://scripts/interactables/craft_part.gd").COLORS[i], 2.0) if GameManager.craft_parts[i] else MeshUtil.mat(Color(0.15, 0.15, 0.15))
	if _t < 0.0:
		return
	_t -= delta
	_light.light_energy = 1.5 + sin(_t * 30.0) * 0.8
	if _t <= 0.0:
		_t = -1.0
		_light.light_energy = 0.0
		GameManager.craft_done = true
		var p := get_tree().get_first_node_in_group("player")
		if p:
			p.holder.give_weapon(WEAPON_ID)
		GameManager.show_message("ARC TONNERRE", Color(0.5, 0.85, 1.0), "Arme unique assemblée — la foudre rebondit entre les zombies")
		Audio.play("powerup", 2.0)
