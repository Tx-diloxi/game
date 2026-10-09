extends "res://scripts/interactables/interactable.gd"
## Piège payant (courant requis) : électrique ou incendiaire. L'interrupteur est ce nœud ;
## la zone mortelle est une boîte en coordonnées monde (`zone_center`, `zone_size`).

const Effects := preload("res://scripts/util/effects.gd")

const ACTIVE_TIME := 25.0
const COOLDOWN := 45.0
const PLAYER_DPS := 70.0

var kind := "electric" # "electric" ou "fire"
var net_index := -1
var cost := 1000
var zone_center := Vector3.ZERO
var zone_size := Vector3(4, 2, 3)

var _active_t := 0.0
var _cooldown_t := 0.0
var _hurt_t := 0.0
var _fx_root: Node3D
var _arcs: Array[MeshInstance3D] = []
var _flames: Array[CPUParticles3D] = []
var _light: OmniLight3D
var _lamp: MeshInstance3D


func _ready() -> void:
	radius = 1.8
	var metal := Mat.metal(Color(0.35, 0.35, 0.3))
	MeshUtil.box_mesh(self, Vector3(0.5, 0.7, 0.18), Vector3(0, 1.35, 0.09), metal)
	MeshUtil.box_mesh(self, Vector3(0.06, 0.3, 0.06), Vector3(0, 1.35, 0.25), MeshUtil.mat(Color(0.15, 0.15, 0.15)), Vector3(-0.6, 0, 0))
	_lamp = MeshUtil.sphere_mesh(self, 0.05, Vector3(0.17, 1.62, 0.19), MeshUtil.mat(Color(0.3, 0.05, 0.05)))
	var title := "PIÈGE ÉLECTRIQUE" if kind == "electric" else "PIÈGE À FEU"
	var l := MeshUtil.label3d(self, "%s\n%d" % [title, cost], Vector3(0, 1.9, 0.12), 30, Color(0.95, 0.8, 0.3))
	l.outline_size = 4
	_build_zone_fx.call_deferred()
	GameManager.power_changed.connect(func(on: bool):
		if on and _cooldown_t <= 0.0 and _active_t <= 0.0:
			_lamp.material_override = MeshUtil.mat(Color(0.1, 1.0, 0.2), 2.0))


func _build_zone_fx() -> void:
	_fx_root = Node3D.new()
	get_parent().add_child(_fx_root)
	_fx_root.global_position = zone_center
	var half := zone_size * 0.5
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.75, 1.0) if kind == "electric" else Color(1.0, 0.5, 0.15)
	_light.light_energy = 0.0
	_light.omni_range = maxf(zone_size.x, zone_size.z) * 1.4
	_light.position.y = 1.2
	_fx_root.add_child(_light)
	if kind == "electric":
		# Deux bornes de part et d'autre, reliées par des arcs.
		var along_x := zone_size.x >= zone_size.z
		var side := Vector3(half.x - 0.15, 0, 0) if along_x else Vector3(0, 0, half.z - 0.15)
		for s in [-1.0, 1.0]:
			var post := MeshUtil.cylinder_mesh(_fx_root, 0.08, 1.9, side * s + Vector3(0, -half.y + 0.95, 0), Mat.metal(Color(0.3, 0.3, 0.3)))
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for k in 3:
				MeshUtil.cylinder_mesh(_fx_root, 0.11, 0.05, side * s + Vector3(0, -half.y + 0.6 + k * 0.5, 0), MeshUtil.mat(Color(0.85, 0.8, 0.6)))
		var arc_mat := MeshUtil.mat(Color(0.6, 0.85, 1.0), 8.0)
		for i in 6:
			var arc := MeshUtil.box_mesh(_fx_root, Vector3(0.03, 0.03, 1.0), Vector3.ZERO, arc_mat)
			arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			arc.visible = false
			_arcs.append(arc)
		_fx_root.set_meta("side", side)
	else:
		# Grille au sol + flammes.
		var grate := MeshUtil.box_mesh(_fx_root, Vector3(zone_size.x, 0.04, zone_size.z), Vector3(0, -half.y + 0.02, 0), Mat.metal(Color(0.12, 0.11, 0.1)))
		grate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p := CPUParticles3D.new()
		p.amount = 220
		p.lifetime = 0.8
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(half.x * 0.9, 0.05, half.z * 0.9)
		Effects.setup_fire(p, 0.55)
		p.initial_velocity_max = 2.2
		p.position.y = -half.y + 0.05
		p.emitting = false
		_fx_root.add_child(p)
		_flames.append(p)


func _process(delta: float) -> void:
	if _cooldown_t > 0.0:
		_cooldown_t -= delta
		if _cooldown_t <= 0.0:
			_lamp.material_override = MeshUtil.mat(Color(0.1, 1.0, 0.2), 2.0) if GameManager.power_on else MeshUtil.mat(Color(0.3, 0.05, 0.05))
	if _active_t <= 0.0:
		return
	_active_t -= delta
	if _active_t <= 0.0:
		_stop()
		return
	_animate_fx()
	for z in get_tree().get_nodes_in_group("zombies"):
		if _inside(z.global_position):
			if z.kind == "boss":
				z.take_damage(z.max_hp * 0.15 * delta, false, "trap")
				continue
			if kind == "fire" and z.has_method("ignite"):
				z.take_damage(z.hp + 1.0, false, "trap")
			else:
				z.take_damage(z.hp + 1.0, false, "trap")
				if GameManager.game:
					Effects.spark_hit(GameManager.game, z.global_position + Vector3.UP, Vector3.UP)
	_hurt_t -= delta
	for p in get_tree().get_nodes_in_group("player"):
		if _inside(p.global_position) and _hurt_t <= 0.0:
			_hurt_t = 0.4
			p.take_damage(PLAYER_DPS * 0.4)


func _inside(pos: Vector3) -> bool:
	var d := (pos + Vector3.UP * 0.5) - zone_center
	var half := zone_size * 0.5
	return absf(d.x) < half.x and absf(d.z) < half.z and absf(d.y) < half.y + 0.5


func _animate_fx() -> void:
	_light.light_energy = randf_range(1.5, 4.0)
	if kind != "electric":
		return
	var side: Vector3 = _fx_root.get_meta("side")
	var half := zone_size * 0.5
	for arc in _arcs:
		arc.visible = randf() < 0.75
		var y := randf_range(-half.y + 0.4, half.y - 0.1)
		var a := -side + Vector3(0, y, 0)
		var b := side + Vector3(0, y + randf_range(-0.4, 0.4), 0)
		var mid := (a + b) * 0.5 + Vector3(0, randf_range(-0.25, 0.25), 0)
		var dir := (b - a).normalized()
		arc.transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3(1, 1, a.distance_to(b))), mid)
	if randf() < 0.2:
		Audio.play_at("power_on", zone_center, -12.0, randf_range(2.5, 3.5))


func is_available(_player: Node) -> bool:
	return true


func get_prompt(_player: Node) -> String:
	if not GameManager.power_on:
		return "Il faut rétablir le courant"
	if _active_t > 0.0:
		return "Piège actif"
	if _cooldown_t > 0.0:
		return "Piège en recharge (%d s)" % ceili(_cooldown_t)
	return "[F] Activer le %s  [%d]" % ["piège électrique" if kind == "electric" else "piège à feu", cost]


func interact(_player: Node) -> void:
	if not GameManager.power_on or _active_t > 0.0 or _cooldown_t > 0.0:
		Audio.play("deny")
		return
	if not GameManager.spend(cost):
		return
	if Net.active:
		Net.act("trap", net_index, null)
	else:
		activate()


func activate() -> void:
	if _active_t > 0.0:
		return
	_active_t = ACTIVE_TIME
	Audio.say("trap_on")
	_lamp.material_override = MeshUtil.mat(Color(1.0, 0.15, 0.05), 3.0)
	Audio.play_at("power_on", zone_center, 2.0, 1.4 if kind == "electric" else 0.7)
	for f in _flames:
		f.emitting = true


func _stop() -> void:
	_active_t = 0.0
	_cooldown_t = COOLDOWN
	_light.light_energy = 0.0
	for arc in _arcs:
		arc.visible = false
	for f in _flames:
		f.emitting = false
	_lamp.material_override = MeshUtil.mat(Color(1.0, 0.6, 0.1), 1.5)
