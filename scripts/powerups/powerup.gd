extends Node3D
## Bonus lâché par un zombie. Ramassé en passant dessus, disparaît au bout de 25 s.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")

const LIFETIME := 25.0
const PICKUP_RADIUS := 1.3

var kind := "max_ammo"
var net_id := 0
var _sent := false
var _t := 0.0
var _visual: Node3D


func _ready() -> void:
	var p: Dictionary = GameManager.POWERUPS[kind]
	var col: Color = p.color
	_visual = Node3D.new()
	_visual.position.y = 1.0
	add_child(_visual)
	MeshUtil.box_mesh(_visual, Vector3(0.45, 0.45, 0.12), Vector3.ZERO, MeshUtil.mat(col, 2.5))
	var l := MeshUtil.label3d(_visual, p.letter, Vector3(0, 0, 0.07), 96, Color(0.05, 0.05, 0.05))
	l.outline_size = 0
	var l2 := MeshUtil.label3d(_visual, p.letter, Vector3(0, 0, -0.07), 96, Color(0.05, 0.05, 0.05))
	l2.outline_size = 0
	l2.rotation.y = PI
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.5
	light.omni_range = 3.0
	_visual.add_child(light)
	Audio.play_at("powerup_spawn", global_position + Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y += delta * 2.0
	_visual.position.y = 1.0 + sin(_t * 3.0) * 0.12
	if _t > LIFETIME - 5.0:
		_visual.visible = fmod(_t, 0.3) < 0.18
	if _t > LIFETIME:
		queue_free()
		return
	for p in get_tree().get_nodes_in_group("player"):
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() < PICKUP_RADIUS and not p.dead:
			if Net.active and Net.players.size() > 1:
				if not _sent:
					_sent = true
					Net.act("pu_take", net_id, null)
				return
			if GameManager.game:
				GameManager.game.apply_powerup(kind)
			queue_free()
			return
