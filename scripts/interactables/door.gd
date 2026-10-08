extends "res://scripts/interactables/interactable.gd"
## Porte payante (débris) qui débloque une zone. Doit être placée sous la NavigationRegion3D
## pour bloquer le maillage de navigation tant qu'elle est fermée.

var cost := 750
var unlock_zone := 1
var size := Vector3(3.0, 3.0, 0.4)
var opened := false
var _body: StaticBody3D


func _ready() -> void:
	add_to_group("doors")
	radius = 2.8
	_body = MeshUtil.static_box(self, size, Vector3(0, size.y * 0.5, 0), null)
	var wood := Mat.textured("planks", Color(0.6, 0.48, 0.38), 1.0, 0.0, false)
	var metal := Mat.textured("metal", Color(0.45, 0.42, 0.4), 1.2, 0.7, false)
	MeshUtil.box_mesh(_body, size, Vector3.ZERO, metal)
	for i in 4:
		MeshUtil.box_mesh(_body, Vector3(size.x * 0.95, 0.25, 0.08), Vector3(0, -1.0 + i * 0.65, size.z * 0.5 + 0.04), wood, Vector3(0, 0, randf_range(-0.3, 0.3)))
		MeshUtil.box_mesh(_body, Vector3(size.x * 0.95, 0.25, 0.08), Vector3(0, -1.0 + i * 0.65, -size.z * 0.5 - 0.04), wood, Vector3(0, 0, randf_range(-0.3, 0.3)))
	for side in [1.0, -1.0]:
		var l := MeshUtil.label3d(self, "%d" % cost, Vector3(0, 2.6, side * (size.z * 0.5 + 0.12)), 72, Color(0.95, 0.85, 0.6))
		l.font = preload("res://scenes/ui/ui_theme.gd").stencil_font()
		l.outline_size = 0
		l.shaded = true
		if side < 0:
			l.rotation.y = PI


func is_available(_player: Node) -> bool:
	return not opened


func get_prompt(_player: Node) -> String:
	return "[F] Dégager les débris  [%d]" % cost


func interact(_player: Node) -> void:
	if opened or not GameManager.spend(cost):
		return
	_open()


## Ouverture sans payer (téléporteur).
func force_open() -> void:
	if not opened:
		_open()


func _open() -> void:
	opened = true
	remove_from_group("interactable")
	Audio.play_at("door_open", global_position + Vector3.UP * 1.5)
	_body.collision_layer = 0
	var tw := create_tween()
	tw.tween_property(_body, "position:y", -size.y, 1.2).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(queue_free)
	if GameManager.game:
		GameManager.game.unlock_zone(unlock_zone)
