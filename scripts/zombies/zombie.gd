extends CharacterBody3D
## Zombie (ou chien / tank). Machine à états :
## WINDOW (aller à la fenêtre) → TEAR (arracher les planches) → ENTER (enjamber) → CHASE → DEAD

const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const ZombieModel := preload("res://scripts/zombies/zombie_model.gd")
const RealModel := preload("res://scripts/zombies/zombie_model_real.gd")
const DogModel := preload("res://scripts/zombies/dog_model.gd")
const Effects := preload("res://scripts/util/effects.gd")

## Membres que l'on peut arracher : os -> zone de touche (rayon en m).
const LIMBS := {
	"Bip01 L Forearm": 0.28, "Bip01 R Forearm": 0.28,
	"Bip01 L Calf": 0.3, "Bip01 R Calf": 0.3,
}

enum State { WINDOW, TEAR, ENTER, CHASE, DEAD }

const GRAVITY := 20.0
const TEAR_TIME := 1.3

var kind := "zombie" # "zombie", "dog", "tank"
var max_hp := 150.0
var hp := 150.0
var speed := 1.4
var damage := 50.0
var attack_range := 1.5
var head_height := 1.45
var barricade: Node3D = null

var state := State.CHASE
var agent: NavigationAgent3D
var visual: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _repath := 0.0
var _tear_t := TEAR_TIME
var _attack_cd := 0.0
var _attack_wind := -1.0
var _groan_t := 0.0
var _anim_t := 0.0
var _flinch := 0.0
var _model: Node3D = null
var _real := false
## Décor du menu : avance lentement sans IA.
var menu_idle := false
## Rampe au sol après avoir perdu une jambe.
var crawling := false
var _shape: CollisionShape3D
var _limb_dmg := {}
var _burn_t := 0.0
var _burn_dps := 0.0
var _fire_fx: CPUParticles3D
var _push := Vector3.ZERO
# Boss
var armor := 0.0
var _charge_cd := 6.0
var _charge_t := 0.0
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var _slam_cd := 4.0
var _slam_wind := -1.0
var _helmet: Node3D


func setup(p_kind: String, p_hp: float, p_speed: float, p_barricade: Node3D) -> void:
	kind = p_kind
	max_hp = p_hp
	hp = p_hp
	speed = p_speed
	barricade = p_barricade
	match kind:
		"dog":
			damage = 30.0
			attack_range = 1.3
			head_height = 0.6
		"tank":
			damage = 90.0
			attack_range = 1.9
			head_height = 1.95
		"boss":
			damage = 80.0
			attack_range = 2.4
			head_height = 2.3
			armor = p_hp * 0.25


func _ready() -> void:
	add_to_group("zombies")
	collision_layer = GameManager.L_ZOMBIE
	collision_mask = GameManager.L_WORLD
	floor_snap_length = 0.4

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	match kind:
		"dog":
			cap.radius = 0.3
			cap.height = 0.9
		"tank":
			cap.radius = 0.5
			cap.height = 2.4
		"boss":
			cap.radius = 0.6
			cap.height = 2.9
		_:
			cap.radius = 0.35
			cap.height = 1.8
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	_shape = cs

	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.4
	agent.radius = 0.5
	agent.height = 2.0
	agent.path_max_distance = 3.0
	add_child(agent)

	visual = Node3D.new()
	add_child(visual)
	if kind == "dog":
		if DogModel.available():
			_build_real_dog()
		else:
			_build_dog()
	elif RealModel.available():
		_build_real_model()
	elif ZombieModel.available():
		_build_model()
	else:
		_build_humanoid()
	state = State.WINDOW if barricade else State.CHASE
	_groan_t = randf_range(1.0, 6.0)


# --- Boucle ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		if _real:
			_model.update_pose(delta, false, 1.0)
		return
	if menu_idle:
		var fwd := -global_basis.z
		velocity = Vector3(fwd.x, 0, fwd.z) * speed
		move_and_slide()
		if global_position.z > -38.5:
			global_position.z = -47.5
		_animate(delta, true)
		return
	if global_position.y < -20.0:
		take_damage(hp * 10.0, false, "nuke")
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	_attack_cd -= delta
	if _burn_t > 0.0:
		_burn_t -= delta
		if _burn_t <= 0.0 and _fire_fx:
			_fire_fx.emitting = false
		if take_damage(_burn_dps * delta, false, "fire"):
			return
	var player := _get_player()
	var moving := true

	match state:
		State.WINDOW:
			var op: Vector3 = barricade.outside_point()
			if _flat_dist(op) < 0.5:
				state = State.TEAR
				_tear_t = TEAR_TIME
			else:
				_move_to(op, delta)
		State.TEAR:
			moving = false
			_stop()
			_face((barricade.inside_point() - global_position), delta)
			if player and _flat_dist(player.global_position) < 2.3:
				_try_attack()
			elif barricade.boards > 0:
				_tear_t -= delta
				if _tear_t <= 0.0:
					_tear_t = TEAR_TIME
					barricade.remove_board()
				elif _tear_t < 0.9 and _real:
					_model.attack()
			else:
				state = State.ENTER
		State.ENTER:
			var ip: Vector3 = barricade.inside_point()
			if _flat_dist(ip) < 0.5:
				state = State.CHASE
			else:
				var dir := ip - global_position
				dir.y = 0.0
				dir = dir.normalized()
				velocity.x = dir.x * minf(speed, 2.5)
				velocity.z = dir.z * minf(speed, 2.5)
				_face(dir, delta)
		State.CHASE:
			var decoy: Node3D = _decoy()
			if kind == "boss" and _boss_logic(delta, player):
				pass
			elif decoy:
				var dd := _flat_dist(decoy.global_position)
				if dd < 1.4:
					moving = false
					_stop()
					_face(decoy.global_position - global_position, delta)
					if _real:
						_model.attack()
				else:
					_move_to(decoy.global_position, delta)
			elif player == null or player.dead:
				moving = false
				_stop()
			else:
				var d := _flat_dist(player.global_position)
				if d < attack_range and absf(player.global_position.y - global_position.y) < 1.5:
					moving = false
					_stop()
					_face(player.global_position - global_position, delta)
					_try_attack()
				else:
					_move_to(player.global_position, delta)

	if moving:
		_separate()
	_update_attack(delta, player)
	if _push.length_squared() > 0.01:
		velocity.x += _push.x
		velocity.z += _push.z
		_push = _push.move_toward(Vector3.ZERO, delta * 25.0)
	move_and_slide()
	_animate(delta, moving)

	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(4.0, 10.0)
		if kind == "dog":
			Audio.play_at("dog_bark", global_position, -2.0, randf_range(0.8, 1.2))
		else:
			Audio.play_at("groan", global_position + Vector3.UP * 1.5, -4.0, randf_range(0.7, 1.2) * (0.7 if kind == "tank" else 1.0))


## Singe-leurre actif qui attire ce zombie (les chiens et le boss l'ignorent).
func _decoy() -> Node3D:
	if kind == "dog" or kind == "boss" or GameManager.game == null:
		return null
	var d = GameManager.game.decoy
	if d and is_instance_valid(d) and d.global_position.distance_to(global_position) < 40.0:
		return d
	return null


## Comportements du boss : charge et coup au sol. Retourne true s'il a pris la main ce tour-ci.
func _boss_logic(delta: float, player: Node3D) -> bool:
	if player == null or player.dead:
		return false
	_charge_cd -= delta
	_slam_cd -= delta
	var d := _flat_dist(player.global_position)
	if _charge_t > 0.0:
		_charge_t -= delta
		velocity.x = _charge_dir.x * 9.5
		velocity.z = _charge_dir.z * 9.5
		_face(_charge_dir, delta)
		if not _charge_hit and d < 2.0:
			_charge_hit = true
			player.take_damage(70.0)
			player.velocity += _charge_dir * 12.0 + Vector3.UP * 4.0
			if GameManager.game:
				GameManager.game._shake(0.5)
			_charge_t = minf(_charge_t, 0.2)
		if is_on_wall():
			_charge_t = 0.0
			if GameManager.game:
				GameManager.game._shake(0.3)
		return true
	if _slam_wind >= 0.0:
		_slam_wind -= delta
		_stop()
		if _slam_wind < 0.0:
			_slam_wind = -1.0
			_slam()
		return true
	if d < 3.2 and _slam_cd <= 0.0:
		_slam_cd = 7.0
		_slam_wind = 0.8
		if _real:
			_model.attack()
		Audio.play_at("boss_roar", global_position + Vector3.UP * 2.0, 4.0, 0.75)
		return true
	if d > 5.0 and d < 16.0 and _charge_cd <= 0.0:
		_charge_cd = randf_range(7.0, 11.0)
		_charge_t = 1.5
		_charge_hit = false
		_charge_dir = player.global_position - global_position
		_charge_dir.y = 0.0
		_charge_dir = _charge_dir.normalized()
		Audio.play_at("boss_roar", global_position + Vector3.UP * 2.0, 6.0, 0.6)
		return true
	return false


func _slam() -> void:
	var game := GameManager.game
	if game == null:
		return
	Audio.play_at("explosion", global_position, 2.0, 0.5)
	Effects.burst(game, global_position + Vector3.UP * 0.1, Vector3.UP, Color(0.3, 0.27, 0.22, 0.8), 30, 5.0, 0.6, 1.2, 4.0, 0.0, 80.0)
	game._shake(0.7)
	for p in get_tree().get_nodes_in_group("player"):
		var pd := _flat_dist(p.global_position)
		if pd < 4.5:
			p.take_damage(55.0 * (1.0 - pd / 6.0))
			var away: Vector3 = (p.global_position - global_position)
			away.y = 0.0
			p.velocity += away.normalized() * 8.0 + Vector3.UP * 5.0


func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _move_to(target: Vector3, delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.25
		agent.target_position = target
	var dir := Vector3.ZERO
	if not agent.is_navigation_finished():
		dir = agent.get_next_path_position() - global_position
		dir.y = 0.0
	if dir.length() < 0.05:
		dir = target - global_position
		dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(dir, delta)


## Évite que les zombies se superposent.
func _separate() -> void:
	var push := Vector3.ZERO
	for z in get_tree().get_nodes_in_group("zombies"):
		if z == self:
			continue
		var d: Vector3 = global_position - z.global_position
		d.y = 0.0
		var l := d.length()
		if l < 0.75 and l > 0.001:
			push += d / l * (0.75 - l)
	velocity.x += push.x * 4.0
	velocity.z += push.z * 4.0


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target, minf(delta * 8.0, 1.0))


func _try_attack() -> void:
	if _attack_cd > 0.0 or _attack_wind >= 0.0:
		return
	_attack_wind = 0.25 if kind == "dog" else 0.45
	if _real:
		_model.attack()
	if kind == "dog":
		Audio.play_at("dog_bark", global_position, 0.0, 1.3)
	else:
		Audio.play_at("zombie_attack", global_position + Vector3.UP * 1.5, 0.0, randf_range(0.8, 1.1) * (0.7 if kind == "tank" else 1.0))


func _update_attack(delta: float, player: Node3D) -> void:
	if _attack_wind < 0.0:
		return
	_attack_wind -= delta
	if _attack_wind < 0.0:
		_attack_wind = -1.0
		_attack_cd = 1.0
		if player and _flat_dist(player.global_position) < attack_range + 0.8 \
				and absf(player.global_position.y - global_position.y) < 1.6:
			player.take_damage(damage)


# --- Dégâts ---------------------------------------------------------------

## Retourne true si le coup tue.
func take_damage(amount: float, head: bool, cause: String) -> bool:
	if state == State.DEAD:
		return false
	if GameManager.is_powerup_active("insta_kill") and kind != "tank" and kind != "boss":
		amount = hp
	if kind == "boss" and armor > 0.0 and head:
		# Le casque encaisse les tirs à la tête jusqu'à se briser.
		armor -= amount
		amount *= 0.25
		if armor <= 0.0:
			_break_helmet()
	hp -= amount
	_flinch = 1.0
	if hp <= 0.0:
		_die(head, cause)
		return true
	if cause in ["bullet", "melee", "explosion"]:
		GameManager.add_points(10)
		Audio.play("hit", -8.0)
	return false


# --- Effets spéciaux (améliorations, démembrement) -------------------------

## Appelé par une balle avant les dégâts : accumule les dégâts par membre et l'arrache au-delà d'un seuil.
func on_limb_hit(pos: Vector3, dmg: float) -> void:
	if not _real or kind == "dog" or state == State.DEAD:
		return
	for bone in LIMBS:
		var bp: Vector3 = _model.bone_pos(bone)
		if bp.distance_to(pos) < LIMBS[bone] * visual.scale.x:
			_limb_dmg[bone] = _limb_dmg.get(bone, 0.0) + dmg
			if _limb_dmg[bone] >= minf(max_hp * 0.3, 400.0):
				_sever(bone)
			return


## Souffle d'explosion non mortel : peut arracher une jambe (zombie rampant).
func on_blast(pos: Vector3) -> void:
	if not _real or kind != "zombie" or state == State.DEAD or crawling:
		return
	if randf() < 0.45:
		var bone := "Bip01 L Calf" if randf() < 0.5 else "Bip01 R Calf"
		_sever(bone)
	_push += (global_position - pos).normalized() * 4.0


func _sever(bone: String) -> void:
	var at: Vector3 = _model.bone_pos(bone)
	if not _model.sever(bone):
		return
	if GameManager.game:
		Effects.blood_hit(GameManager.game, at, Vector3.UP, true)
		Effects.blood_decal(GameManager.game, Vector3(at.x, 0.0, at.z), randf_range(0.5, 0.9))
		_spawn_gib(at)
	Audio.play_at("board_break", at, -4.0, 0.6)
	if "Calf" in bone:
		_start_crawl()


func _spawn_gib(at: Vector3) -> void:
	var gib := RigidBody3D.new()
	gib.collision_layer = 0
	gib.collision_mask = GameManager.L_WORLD
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.06
	shape.height = 0.4
	cs.shape = shape
	gib.add_child(cs)
	MeshUtil.capsule_mesh(gib, 0.06, 0.4, Vector3.ZERO, MeshUtil.mat(Color(0.35, 0.05, 0.04), 0.0, 0.4))
	GameManager.game.add_child(gib)
	gib.global_position = at
	gib.linear_velocity = Vector3(randf_range(-2, 2), 3.0, randf_range(-2, 2))
	gib.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	get_tree().create_timer(15.0, false).timeout.connect(gib.queue_free)


func _start_crawl() -> void:
	if crawling:
		return
	crawling = true
	speed = minf(speed, 1.6) * 0.55
	head_height = 0.3
	attack_range = 1.2
	var cap := _shape.shape as CapsuleShape3D
	cap.height = 0.8
	_shape.position.y = 0.4


## Brûlure (améliorations incendiaires).
func ignite(dps: float, duration: float) -> void:
	if state == State.DEAD:
		return
	_burn_dps = maxf(_burn_dps if _burn_t > 0.0 else 0.0, dps)
	_burn_t = maxf(_burn_t, duration)
	if _fire_fx == null:
		_fire_fx = CPUParticles3D.new()
		_fire_fx.amount = 24
		_fire_fx.lifetime = 0.6
		_fire_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_fire_fx.emission_box_extents = Vector3(0.25, 0.7, 0.2)
		Effects.setup_fire(_fire_fx, 0.35)
		_fire_fx.position.y = 0.4 if crawling else 1.0
		add_child(_fire_fx)
	_fire_fx.emitting = true


func push(v: Vector3) -> void:
	_push += Vector3(v.x, 0.0, v.z)


func _die(head: bool, cause: String) -> void:
	state = State.DEAD
	remove_from_group("zombies")
	collision_layer = 0
	_stop()
	GameManager.kills += 1
	match cause:
		"bullet":
			GameManager.add_points(100 if head else 60)
			if head:
				GameManager.headshots += 1
		"melee":
			GameManager.add_points(130)
		"trap":
			pass
		"explosion", "fire":
			GameManager.add_points(60)
	if _model:
		for e in _model._eyes:
			e.visible = false
	if head:
		if _model:
			_model.hide_head()
		elif _head:
			_head.visible = false
		Audio.play("headshot", -4.0)
	if kind == "boss":
		GameManager.add_points(500)
		if _helmet:
			_helmet.queue_free()
	if GameManager.game:
		GameManager.game.on_zombie_killed(self, cause)
	var tw := create_tween()
	if _real:
		_model.die()
		if not crawling:
			visual.rotation.x = 0.0
		tw.tween_interval(3.2)
	else:
		tw.tween_property(visual, "rotation:x", PI / 2 * (1.0 if kind != "dog" else 0.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if kind == "dog":
			tw.parallel().tween_property(visual, "rotation:z", PI / 2, 0.45)
		tw.tween_interval(2.0)
	tw.tween_property(visual, "position:y", -1.2, 1.5)
	tw.tween_callback(queue_free)


# --- Visuel ---------------------------------------------------------------

func _animate(delta: float, moving: bool) -> void:
	_flinch = move_toward(_flinch, 0.0, delta * 6.0)
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_anim_t += delta * (2.0 + hspeed * 2.2)
	var swing := sin(_anim_t) * clampf(hspeed / 2.0, 0.0, 1.0) * (0.7 if kind == "dog" else 0.55)
	if _model:
		var attacking := state == State.TEAR or _attack_wind >= 0.0
		_model.arm_swing = sin(_anim_t * 2.5) * 0.5 if attacking else sin(_anim_t * 0.5) * 0.05
		_model.arm_raise = 0.35 if speed > 3.0 and moving and not attacking else 1.0
		if kind == "boss":
			_place_armor()
		if _real:
			var ref := 5.5 if kind == "dog" else 1.1
			_model.update_pose(delta, moving and hspeed > 0.2, clampf(hspeed / ref, 0.45, 2.4))
		else:
			_model.update_pose(delta, moving and hspeed > 0.2, clampf(hspeed / 4.0, 0.35, 1.3))
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0)
	if kind != "dog":
		var base := 1.35
		for i in _arms.size():
			var s := 1.0 if i == 0 else -1.0
			if state == State.TEAR or _attack_wind >= 0.0:
				_arms[i].rotation.x = base + sin(_anim_t * 2.5 + s) * 0.6
			elif speed > 3.0 and moving:
				_arms[i].rotation.x = 0.6 - swing * s * 1.4
			else:
				_arms[i].rotation.x = base + sin(_anim_t * 0.5 + s) * 0.08
	if crawling:
		visual.rotation.x = lerpf(visual.rotation.x, -1.3, minf(delta * 6.0, 1.0))
		visual.position.y = lerpf(visual.position.y, 0.32, minf(delta * 6.0, 1.0))
	else:
		visual.rotation.x = -_flinch * 0.25 + (-0.12 if kind != "dog" and not _real else 0.0)


func _build_real_dog() -> void:
	var m: Node3D = DogModel.new()
	visual.add_child(m)
	m.setup()
	head_height = 0.6
	_model = m
	_real = true
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.1)
	light.light_energy = 0.7
	light.omni_range = 2.5
	light.position = Vector3(0, 0.8, -0.5)
	visual.add_child(light)


## Casque et épaulières métalliques du boss (suivent les os à chaque frame).
func _build_armor() -> void:
	var metal := preload("res://scripts/util/materials.gd").metal(Color(0.3, 0.28, 0.26))
	_helmet = Node3D.new()
	_helmet.top_level = true
	add_child(_helmet)
	MeshUtil.sphere_mesh(_helmet, 0.2, Vector3(0, 0.12, 0), metal).scale = Vector3(1.0, 0.85, 1.1)
	MeshUtil.box_mesh(_helmet, Vector3(0.3, 0.05, 0.03), Vector3(0, 0.1, -0.2), MeshUtil.mat(Color(1.0, 0.3, 0.05), 5.0))
	for side in [-1.0, 1.0]:
		var pad := MeshUtil.sphere_mesh(_helmet, 0.17, Vector3(0.32 * side, -0.25, 0), metal)
		pad.scale = Vector3(1.0, 0.6, 1.1)
		pad.name = "Pad%d" % int(side)


func _place_armor() -> void:
	if _helmet == null or not is_instance_valid(_helmet):
		return
	var head: Vector3 = _model.bone_pos("Bip01 Head")
	var s := visual.scale.x
	_helmet.global_transform = Transform3D(global_basis.orthonormalized().scaled(Vector3.ONE * s), head)


func _break_helmet() -> void:
	if _helmet == null:
		return
	Audio.play_at("door_open", global_position + Vector3.UP * 2.4, 4.0, 1.6)
	if GameManager.game:
		Effects.spark_hit(GameManager.game, global_position + Vector3.UP * 2.4, Vector3.UP)
		GameManager.show_message("CASQUE BRISÉ", Color(1.0, 0.6, 0.2), "Visez la tête !")
	for c in _helmet.get_children():
		if not c.name.begins_with("Pad"):
			c.queue_free()
	armor = 0.0


func _build_real_model() -> void:
	var m: Node3D = RealModel.new()
	visual.add_child(m)
	if kind == "tank":
		visual.scale = Vector3.ONE * 1.3
		m.setup("", Color(0.92, 0.6, 0.55))
		head_height = 1.95
	elif kind == "boss":
		visual.scale = Vector3.ONE * 1.6
		m.setup("", Color(0.95, 0.45, 0.4))
		head_height = 2.3
		_build_armor()
	else:
		var v := randf_range(0.72, 0.88)
		m.setup("", Color(v, v * randf_range(0.98, 1.08), v * randf_range(0.92, 1.0)))
		head_height = 1.5
	_model = m
	_real = true


func _build_model() -> void:
	var m: Node3D = ZombieModel.new()
	visual.add_child(m)
	if kind == "tank":
		visual.scale = Vector3.ONE * 1.35
		m.setup("zombieC", Color(0.75, 0.42, 0.38))
		head_height = 1.85
	else:
		m.setup(["zombieA", "zombieC"].pick_random(), Color(0.66, 0.7, 0.64))
		head_height = 1.38
	_model = m


func _build_humanoid() -> void:
	var shirts := [Color(0.25, 0.3, 0.38), Color(0.35, 0.28, 0.2), Color(0.3, 0.3, 0.3), Color(0.4, 0.38, 0.3)]
	var skin_col := Color(0.42, 0.5, 0.38)
	var shirt_col: Color = shirts.pick_random()
	var pants_col := Color(0.18, 0.18, 0.2)
	var eye_col := Color(1.0, 0.55, 0.05)
	if kind == "tank":
		visual.scale = Vector3.ONE * 1.35
		skin_col = Color(0.45, 0.32, 0.3)
		shirt_col = Color(0.2, 0.08, 0.06)
		eye_col = Color(1.0, 0.1, 0.05)
	var skin := MeshUtil.mat(skin_col)
	var shirt := MeshUtil.mat(shirt_col)
	var pants := MeshUtil.mat(pants_col)
	var eyes := MeshUtil.mat(eye_col, 4.0)

	MeshUtil.box_mesh(visual, Vector3(0.5, 0.65, 0.28), Vector3(0, 1.17, 0), shirt)
	MeshUtil.box_mesh(visual, Vector3(0.44, 0.15, 0.26), Vector3(0, 0.8, 0), pants)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.65, -0.02)
	visual.add_child(_head)
	MeshUtil.sphere_mesh(_head, 0.17, Vector3.ZERO, skin)
	MeshUtil.sphere_mesh(_head, 0.035, Vector3(-0.065, 0.03, -0.15), eyes)
	MeshUtil.sphere_mesh(_head, 0.035, Vector3(0.065, 0.03, -0.15), eyes)
	MeshUtil.box_mesh(_head, Vector3(0.14, 0.05, 0.04), Vector3(0, -0.08, -0.14), MeshUtil.mat(Color(0.15, 0.05, 0.05)))

	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.31 * side, 1.43, 0)
		arm.rotation.x = 1.35
		visual.add_child(arm)
		MeshUtil.box_mesh(arm, Vector3(0.13, 0.62, 0.13), Vector3(0, -0.3, 0), shirt)
		MeshUtil.box_mesh(arm, Vector3(0.11, 0.12, 0.11), Vector3(0, -0.66, 0), skin)
		_arms.append(arm)
		var leg := Node3D.new()
		leg.position = Vector3(0.12 * side, 0.82, 0)
		visual.add_child(leg)
		MeshUtil.box_mesh(leg, Vector3(0.17, 0.82, 0.17), Vector3(0, -0.41, 0), pants)
		_legs.append(leg)


func _build_dog() -> void:
	var fur := MeshUtil.mat(Color(0.15, 0.1, 0.08))
	var eyes := MeshUtil.mat(Color(1.0, 0.35, 0.0), 5.0)
	MeshUtil.box_mesh(visual, Vector3(0.34, 0.34, 0.85), Vector3(0, 0.6, 0.05), fur)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.75, -0.48)
	visual.add_child(_head)
	MeshUtil.box_mesh(_head, Vector3(0.26, 0.26, 0.3), Vector3.ZERO, fur)
	MeshUtil.box_mesh(_head, Vector3(0.16, 0.14, 0.2), Vector3(0, -0.05, -0.22), fur)
	MeshUtil.sphere_mesh(_head, 0.03, Vector3(-0.08, 0.06, -0.15), eyes)
	MeshUtil.sphere_mesh(_head, 0.03, Vector3(0.08, 0.06, -0.15), eyes)
	for p in [Vector3(-0.12, 0.45, -0.28), Vector3(0.12, 0.45, 0.32), Vector3(0.12, 0.45, -0.28), Vector3(-0.12, 0.45, 0.32)]:
		var leg := Node3D.new()
		leg.position = p
		visual.add_child(leg)
		MeshUtil.box_mesh(leg, Vector3(0.09, 0.45, 0.09), Vector3(0, -0.22, 0), fur)
		_legs.append(leg)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.1)
	light.light_energy = 0.6
	light.omni_range = 2.0
	light.position = Vector3(0, 0.8, -0.6)
	visual.add_child(light)
