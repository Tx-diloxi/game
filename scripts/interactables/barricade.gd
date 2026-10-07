extends "res://scripts/interactables/interactable.gd"
## Fenêtre barricadée : 6 planches que les zombies arrachent et que le joueur répare.
## L'origine est au sol, au centre de l'ouverture ; -Z local pointe vers l'intérieur.

const MAX_BOARDS := 6
const REPAIR_TIME := 0.9
const WIDTH := 1.6
const HEIGHT := 2.4

var zone := 0
var boards := MAX_BOARDS
var _repair_t := 0.0
var _board_nodes: Array[MeshInstance3D] = []
var _board_rest: Array[Transform3D] = []


func _ready() -> void:
	radius = 2.0
	var wood := Mat.textured("planks", Color(0.7, 0.58, 0.46), 1.0, 0.0, false)
	for i in MAX_BOARDS:
		var y := 0.35 + i * 0.32
		var rz := randf_range(-0.25, 0.25)
		var b := MeshUtil.box_mesh(self, Vector3(WIDTH + 0.3, 0.2, 0.06), Vector3(0, y, 0.12), wood, Vector3(0, 0, rz))
		_board_nodes.append(b)
		_board_rest.append(b.transform)
	# Bloque le joueur (pas les zombies, ni la navigation).
	var blocker := MeshUtil.static_box(self, Vector3(WIDTH, HEIGHT + 2.0, 0.3), Vector3(0, HEIGHT * 0.5 + 1.0, 0.0), null, GameManager.L_PLAYER_BLOCK)
	blocker.name = "PlayerBlocker"


## Point extérieur où le zombie arrache les planches.
func outside_point() -> Vector3:
	return to_global(Vector3(0, 0, 1.1))


## Point intérieur après avoir enjambé la fenêtre.
func inside_point() -> Vector3:
	return to_global(Vector3(0, 0, -1.3))


## Point d'apparition des zombies, plus loin dehors.
func spawn_point() -> Vector3:
	return to_global(Vector3(randf_range(-0.6, 0.6), 0.05, 3.6))


func remove_board() -> void:
	if boards <= 0:
		return
	boards -= 1
	var b := _board_nodes[boards]
	Audio.play_at("board_break", global_position + Vector3.UP, 0.0, randf_range(0.9, 1.1))
	var tw := b.create_tween()
	var target := b.position + Vector3(randf_range(-0.6, 0.6), -0.4, 1.4)
	tw.tween_property(b, "position", target, 0.35)
	tw.parallel().tween_property(b, "rotation:x", randf_range(-1.5, 1.5), 0.35)
	tw.tween_callback(b.hide)


func add_board() -> void:
	if boards >= MAX_BOARDS:
		return
	var b := _board_nodes[boards]
	boards += 1
	b.show()
	b.transform = _board_rest[boards - 1]
	var final_pos := b.position
	b.position = final_pos + Vector3(0, 0, -0.8)
	b.create_tween().tween_property(b, "position", final_pos, 0.2)
	Audio.play_at("board_repair", global_position + Vector3.UP)


func repair_all() -> void:
	while boards < MAX_BOARDS:
		add_board()


func is_available(_player: Node) -> bool:
	return boards < MAX_BOARDS


func get_prompt(_player: Node) -> String:
	return "Maintenir [F] pour réparer la barricade"


func interact(_player: Node) -> void:
	_repair_t = REPAIR_TIME * 0.6


func interact_hold(_player: Node, delta: float) -> void:
	_repair_t += delta
	if _repair_t >= REPAIR_TIME:
		_repair_t = 0.0
		if boards < MAX_BOARDS:
			add_board()
			GameManager.add_points(10)
