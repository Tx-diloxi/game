extends "res://scripts/interactables/interactable.gd"
## Boîte mystère : arme aléatoire pour 950 points. Finit par déménager (crâne).

enum State { IDLE, ROLLING, OFFER, LEAVING }

const COST := 950
const OFFER_TIME := 10.0

var state := State.IDLE
var uses := 0
var offered_id := ""
var _offer_t := 0.0
var _lid: Node3D
var _display: Node3D
var _gun: Node3D
var _label: Label3D
var _beam: MeshInstance3D


func _ready() -> void:
	radius = 2.4
	var wood := Mat.textured("planks", Color(0.5, 0.36, 0.26), 0.9, 0.0, false)
	var trim := Mat.textured("metal", Color(0.85, 0.65, 0.25), 0.8, 0.9, false)
	var body := MeshUtil.static_box(self, Vector3(1.8, 0.8, 0.9), Vector3(0, 0.4, 0), wood)
	MeshUtil.box_mesh(body, Vector3(1.82, 0.08, 0.92), Vector3(0, 0.3, 0), trim)
	for x in [-0.88, 0.88]:
		MeshUtil.box_mesh(body, Vector3(0.06, 0.82, 0.94), Vector3(x, 0, 0), trim)
	for side in [1.0, -1.0]:
		var q := MeshUtil.label3d(body, "?", Vector3(0, 0, side * 0.47), 140, Color(0.45, 0.85, 1.0))
		q.font = preload("res://scenes/ui/ui_theme.gd").title_font()
		if side < 0:
			q.rotation.y = PI
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.8, -0.45)
	add_child(_lid)
	MeshUtil.box_mesh(_lid, Vector3(1.8, 0.12, 0.9), Vector3(0, 0.06, 0.45), wood)
	_display = Node3D.new()
	_display.position = Vector3(0, 0.9, 0)
	add_child(_display)
	_label = MeshUtil.label3d(_display, "", Vector3(0, 0.45, 0), 48, Color.WHITE)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var beam_mat := MeshUtil.mat(Color(0.3, 0.7, 1.0, 0.18), 1.5)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam = MeshUtil.cylinder_mesh(self, 0.5, 30.0, Vector3(0, 15.0, 0), beam_mat)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.75, 1.0)
	light.light_energy = 0.8
	light.omni_range = 4.0
	light.position = Vector3(0, 1.5, 0)
	add_child(light)


func _process(delta: float) -> void:
	if state == State.OFFER:
		_offer_t -= delta
		_display.position.y = 0.9 + 0.5 * (_offer_t / OFFER_TIME)
		if _offer_t <= 0.0:
			_close()
	if _gun:
		_gun.rotation.y += delta * 1.5


func cost() -> int:
	return 10 if GameManager.is_powerup_active("fire_sale") else COST


func is_available(_player: Node) -> bool:
	return state == State.IDLE or state == State.OFFER


func get_prompt(_player: Node) -> String:
	if state == State.OFFER:
		return "[F] Prendre %s" % _name(offered_id)
	return "[F] Boîte mystère  [%d]" % cost()


func interact(player: Node) -> void:
	if state == State.OFFER:
		if offered_id == "leurre":
			player.holder.give_monkeys(3)
		else:
			player.holder.give_weapon(offered_id)
		_close()
	elif state == State.IDLE and GameManager.spend(cost()):
		_roll(player)


func _roll(player: Node) -> void:
	state = State.ROLLING
	uses += 1
	Audio.play_at("box_jingle", global_position + Vector3.UP)
	create_tween().tween_property(_lid, "rotation:x", -1.9, 0.4)
	var pool: Array = ["leurre"] if player.holder.monkeys == 0 else []
	for id in WeaponDB.BOX_POOL:
		if not player.holder.has_weapon(id):
			pool.append(id)
	if pool.is_empty():
		pool = WeaponDB.BOX_POOL.duplicate()
	var can_move: bool = GameManager.game != null and GameManager.game.box_locations.size() > 1
	var leave := can_move and not GameManager.is_powerup_active("fire_sale") and uses >= 4 and (randf() < 0.25 or uses >= 12)

	for i in 22:
		_show_weapon((WeaponDB.BOX_POOL + ["leurre"]).pick_random())
		_display.position.y = 0.9 + i * 0.022
		await get_tree().create_timer(0.06 + i * 0.008, false).timeout
		if not is_inside_tree():
			return

	if leave:
		_clear_display()
		_label.text = "☠"
		_label.font_size = 160
		_label.modulate = Color(1.0, 0.2, 0.1)
		GameManager.add_points(COST, false)
		GameManager.show_message("La boîte s'en va…", Color(1.0, 0.4, 0.3))
		Audio.play_at("groan", global_position, 6.0, 0.5)
		await get_tree().create_timer(2.0, false).timeout
		_leave()
		return

	offered_id = pool.pick_random()
	_show_weapon(offered_id)
	state = State.OFFER
	_offer_t = OFFER_TIME


func _name(id: String) -> String:
	return "Singe-leurre (x3)" if id == "leurre" else WeaponDB.data(id).name


func _show_weapon(id: String) -> void:
	_clear_display()
	if id == "leurre":
		var m: RigidBody3D = preload("res://scripts/weapons/monkey.gd").new()
		m.freeze = true
		m.set_physics_process(false)
		_display.add_child(m)
		m.scale = Vector3.ONE * 2.2
		m.position.y = -0.3
		_gun = m
		_label.text = _name(id)
		_label.font_size = 48
		_label.modulate = Color.WHITE
		return
	var d := WeaponDB.data(id)
	_gun = MeshUtil.build_gun(_display, id, false, d.color, d.kind)
	_gun.scale = Vector3.ONE * 1.6
	_label.text = d.name
	_label.font_size = 48
	_label.modulate = Color.WHITE


func _clear_display() -> void:
	if _gun:
		_gun.queue_free()
		_gun = null
	_label.text = ""


func _close() -> void:
	state = State.IDLE
	_clear_display()
	_display.position.y = 0.9
	create_tween().tween_property(_lid, "rotation:x", 0.0, 0.4)


func _leave() -> void:
	state = State.LEAVING
	_clear_display()
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + 6.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_lid.rotation.x = 0.0
	visible = false
	await get_tree().create_timer(2.0, false).timeout
	if GameManager.game:
		GameManager.game.relocate_box(self)
	visible = true
	uses = 0
	state = State.IDLE
