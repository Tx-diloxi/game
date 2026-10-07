extends "res://scripts/interactables/interactable.gd"
## Machine d'amélioration : l'arme en main est améliorée pour 5000 points (courant requis).

enum State { IDLE, WORKING, READY }

const COST := 5000
const WORK_TIME := 5.0
const READY_TIME := 15.0

var state := State.IDLE
var stored: Dictionary = {}
var _t := 0.0
var _ring: MeshInstance3D
var _core: MeshInstance3D
var _light: OmniLight3D
var _slot: Node3D
var _gun: Node3D


func _ready() -> void:
	radius = 2.6
	var metal := Mat.metal(Color(0.32, 0.3, 0.36))
	MeshUtil.box_mesh(self, Vector3(2.0, 1.0, 1.2), Vector3(0, 0.5, 0), metal)
	MeshUtil.box_mesh(self, Vector3(0.3, 2.6, 0.3), Vector3(-0.85, 1.3, -0.45), metal)
	MeshUtil.box_mesh(self, Vector3(0.3, 2.6, 0.3), Vector3(0.85, 1.3, -0.45), metal)
	MeshUtil.box_mesh(self, Vector3(2.0, 0.3, 0.4), Vector3(0, 2.6, -0.45), metal)
	_core = MeshUtil.sphere_mesh(self, 0.35, Vector3(0, 1.75, -0.45), MeshUtil.mat(Color(0.3, 0.1, 0.4)))
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.65
	_ring.mesh = torus
	_ring.material_override = MeshUtil.mat(Color(0.4, 0.15, 0.5))
	_ring.position = Vector3(0, 1.75, -0.45)
	_ring.rotation.x = PI / 2
	add_child(_ring)
	MeshUtil.label3d(self, "AMÉLIORATION  %d" % COST, Vector3(0, 2.95, -0.2), 48, Color(0.85, 0.5, 1.0))
	_slot = Node3D.new()
	_slot.position = Vector3(0, 1.1, 0.1)
	add_child(_slot)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.7, 0.3, 1.0)
	_light.omni_range = 5.0
	_light.light_energy = 0.0
	_light.position = Vector3(0, 2.0, 0.6)
	add_child(_light)
	MeshUtil.static_box(self, Vector3(2.0, 1.0, 1.2), Vector3(0, 0.5, 0), null)
	GameManager.power_changed.connect(_on_power)


func _on_power(on: bool) -> void:
	_core.material_override = MeshUtil.mat(Color(0.75, 0.3, 1.0), 3.0) if on else MeshUtil.mat(Color(0.3, 0.1, 0.4))
	_ring.material_override = MeshUtil.mat(Color(0.6, 0.25, 0.9), 1.5) if on else MeshUtil.mat(Color(0.4, 0.15, 0.5))
	_light.light_energy = 1.2 if on else 0.0


func _process(delta: float) -> void:
	if GameManager.power_on:
		_ring.rotate_object_local(Vector3.FORWARD, delta * (6.0 if state == State.WORKING else 1.0))
	match state:
		State.WORKING:
			_t -= delta
			if _gun:
				_gun.rotation.y += delta * 8.0
			if _t <= 0.0:
				state = State.READY
				_t = READY_TIME
				_show_gun(true)
				Audio.play_at("powerup", global_position + Vector3.UP)
		State.READY:
			_t -= delta
			if _gun:
				_gun.rotation.y += delta * 1.5
			if _t <= 0.0:
				_reset()


func is_available(player: Node) -> bool:
	if state == State.WORKING:
		return false
	if state == State.READY:
		return true
	return player.holder.cur() != null


func get_prompt(player: Node) -> String:
	if not GameManager.power_on:
		return "Il faut rétablir le courant"
	if state == State.READY:
		return "[F] Récupérer %s" % WeaponDB.data(stored.id).upgraded_name
	var w = player.holder.cur()
	if w.upgraded:
		return "Arme déjà améliorée"
	return "[F] Améliorer l'arme  [%d]" % COST


func interact(player: Node) -> void:
	if not GameManager.power_on:
		Audio.play("deny")
		return
	if state == State.READY:
		player.holder.give_weapon(stored.id, true)
		var label: String = WeaponDB.data(stored.id).get("upgrade_label", "")
		if label != "":
			GameManager.show_message(WeaponDB.data(stored.id).upgraded_name.to_upper(), Color(0.8, 0.5, 1.0), label)
		_reset()
		return
	var w = player.holder.cur()
	if w == null or w.upgraded:
		Audio.play("deny")
		return
	if not GameManager.spend(COST):
		return
	stored = player.holder.take_current()
	state = State.WORKING
	_t = WORK_TIME
	_show_gun(false)
	Audio.play_at("power_on", global_position + Vector3.UP, 0.0, 1.5)


func _show_gun(upgraded: bool) -> void:
	if _gun:
		_gun.queue_free()
	var d := WeaponDB.data(stored.id)
	_gun = MeshUtil.build_gun(_slot, stored.id, upgraded, d.color, d.kind)
	_gun.scale = Vector3.ONE * 1.5


func _reset() -> void:
	state = State.IDLE
	stored = {}
	if _gun:
		_gun.queue_free()
		_gun = null
