extends CharacterBody3D
## Joueur FPS : déplacements, santé régénérante, interaction, mise à terre.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const WeaponHolderScript := preload("res://scripts/player/weapon_holder.gd")

signal health_changed(health: float, max_health: float)
signal downed_changed(downed: bool)
signal damaged
## Position monde de la source d'un coup (pour l'indicateur directionnel).
signal hit_from(source: Vector3)

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.3
const ADS_SPEED := 2.8
const JUMP_VELOCITY := 6.0
const GRAVITY := 20.0
const STAND_HEIGHT := 1.6
const CROUCH_HEIGHT := 1.0
const REGEN_DELAY := 3.0
const REGEN_RATE := 60.0
## Secondes pendant lesquelles on peut tirer au pistolet à terre avant de mourir (sans Second Souffle).
const DOWN_TIME := 5.0
const DOWN_SPEED := 1.2
const SLIDE_TIME := 0.7
const SLIDE_SPEED := 9.0
const SLIDE_COOLDOWN := 0.6
const VAULT_TIME := 0.65

var head: Node3D
var camera: Camera3D
var holder: Node3D
var hud: Node = null

var health := 100.0
## Infection (zombie Infecté) : secondes restantes ; perte de vie continue, plus de régénération.
var infected := 0.0
var _infect_pulse := 0.0
var max_health := 100.0
var since_hit := 10.0
var downed := false
var down_left := 0.0
var _revive_on_end := false
var dead := false
var busy_timer := 0.0
var invuln := 0.0
var sprinting := false
var slide_t := 0.0
var slide_cd := 0.0
var _slide_dir := Vector3.ZERO
var vaulting := false
var crouching := false
var interact_target: Node = null
var _step_t := 0.0
var _shake := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = GameManager.L_PLAYER
	collision_mask = GameManager.L_WORLD | GameManager.L_PLAYER_BLOCK | GameManager.L_ZOMBIE
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	head = Node3D.new()
	head.position.y = STAND_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.03
	camera.far = 200.0
	camera.current = true
	head.add_child(camera)

	holder = WeaponHolderScript.new()
	holder.player = self
	holder.camera = camera
	camera.add_child(holder)
	holder.give_weapon("p9")

	GameManager.perks_changed.connect(apply_perks)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if dead or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var sens := GameManager.mouse_sensitivity * (0.5 if holder.aiming else 1.0)
		rotate_y(deg_to_rad(-event.relative.x * sens))
		head.rotation.x = clampf(head.rotation.x - deg_to_rad(event.relative.y * sens), -1.5, 1.5)


func _physics_process(delta: float) -> void:
	busy_timer = maxf(busy_timer - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if downed and not dead:
		down_left -= delta
		if down_left <= 0.0:
			_end_down()
	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if vaulting:
		return
	slide_cd = maxf(slide_cd - delta, 0.0)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	# Glissade : s'accroupir en plein sprint
	if sprinting and Input.is_action_just_pressed("crouch") and is_on_floor() and slide_cd <= 0.0 and not downed:
		slide_t = SLIDE_TIME
		_slide_dir = dir if dir != Vector3.ZERO else -transform.basis.z
		Audio.play("footstep", -4.0, 0.7)
	crouching = (Input.is_action_pressed("crouch") or slide_t > 0.0) and not downed
	sprinting = Input.is_action_pressed("sprint") and input.y < -0.3 and not crouching \
		and can_act() and not holder.aiming and not holder.is_reloading()

	var speed := WALK_SPEED
	if downed:
		speed = DOWN_SPEED
	elif slide_t > 0.0:
		speed = 0.0
	elif sprinting:
		speed = SPRINT_SPEED * (1.3 if GameManager.has_perk("sprinteur") else 1.0)
	elif crouching:
		speed = CROUCH_SPEED
	elif holder.aiming:
		speed = ADS_SPEED
	if busy_timer > 0.0:
		speed *= 0.6
	if GameManager.has_perk("pied_leger"):
		speed *= 1.2

	var accel := 12.0 if is_on_floor() else 3.0
	var t := minf(accel * delta, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, t)
	velocity.z = lerpf(velocity.z, dir.z * speed, t)

	if slide_t > 0.0:
		slide_t -= delta
		var k := clampf(slide_t / SLIDE_TIME, 0.0, 1.0)
		var sv := _slide_dir * lerpf(3.0, SLIDE_SPEED, k * k)
		velocity.x = sv.x
		velocity.z = sv.z
		if slide_t <= 0.0:
			slide_cd = SLIDE_COOLDOWN
	if Input.is_action_just_pressed("jump") and not downed and _try_vault():
		return
	if is_on_floor() and Input.is_action_just_pressed("jump") and not downed and not crouching:
		velocity.y = JUMP_VELOCITY
		slide_t = 0.0

	move_and_slide()

	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 1.0:
		_step_t -= delta * hspeed
		if _step_t <= 0.0:
			_step_t = 2.2
			Audio.play("footstep", -14.0 if crouching else -8.0, randf_range(0.9, 1.1))

	var target_h := 0.4 if downed else (CROUCH_HEIGHT if crouching else STAND_HEIGHT)
	head.position.y = move_toward(head.position.y, target_h, delta * 4.0)

	since_hit += delta
	if infected > 0.0 and not dead and not downed:
		infected -= delta
		since_hit = 0.0
		health = maxf(health - 3.5 * delta, minf(health, 12.0))
		health_changed.emit(health, max_health)
		_infect_pulse -= delta
		if _infect_pulse <= 0.0:
			_infect_pulse = 1.2
			if hud:
				hud.flash(Color(0.45, 0.8, 0.1, 0.5), 0.3)
	var fast_heal := GameManager.has_perk("bouclier")
	if since_hit > (REGEN_DELAY * (0.5 if fast_heal else 1.0) * GameManager.diff("regen")) and health < max_health and not downed:
		health = minf(max_health, health + REGEN_RATE * (2.0 if fast_heal else 1.0) * delta)
		health_changed.emit(health, max_health)

	_update_interact(delta)


func _update_interact(delta: float) -> void:
	var best: Node = null
	if can_act():
		var best_score := -INF
		var fwd := -camera.global_basis.z
		var fwd_h := Vector3(fwd.x, 0, fwd.z).normalized()
		for n in get_tree().get_nodes_in_group("interactable"):
			if not n.is_available(self):
				continue
			var to: Vector3 = n.global_position - global_position
			to.y = 0.0
			var dist := to.length()
			if dist > n.radius:
				continue
			var dot := 1.0 if dist < 0.3 else fwd_h.dot(to / dist)
			if dot < 0.25:
				continue
			var score := dot - dist * 0.3
			if score > best_score:
				best_score = score
				best = n
	interact_target = best
	if hud:
		hud.set_prompt(best.get_prompt(self) if best else "")
	if best:
		if Input.is_action_just_pressed("interact"):
			best.interact(self)
		elif Input.is_action_pressed("interact"):
			best.interact_hold(self, delta)


# --- API ------------------------------------------------------------------

## Enjambe une fenêtre dégagée (plus aucune planche) située juste devant le joueur.
func _try_vault() -> bool:
	if not can_act() or GameManager.game == null:
		return false
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for b in GameManager.game.barricades:
		if b.boards > 0:
			continue
		var lp: Vector3 = b.to_local(global_position)
		if absf(lp.x) > b.WIDTH * 0.5 + 0.1 or absf(lp.z) > 1.5:
			continue
		var to_side := 1.0 if lp.z < 0.0 else -1.0 # côté d'arrivée (+Z local = extérieur)
		var dest: Vector3 = b.to_global(Vector3(clampf(lp.x, -0.5, 0.5), 0.0, to_side * 1.5))
		var to_dest := dest - global_position
		to_dest.y = 0.0
		if fwd.dot(to_dest.normalized()) < 0.5:
			continue
		_vault_to(dest)
		return true
	return false


func _vault_to(dest: Vector3) -> void:
	vaulting = true
	slide_t = 0.0
	velocity = Vector3.ZERO
	var start := global_position
	collision_mask = 0
	Audio.play("footstep", -2.0, 0.8)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var pos := start.lerp(dest, t)
		pos.y = start.y + sin(t * PI) * 0.7
		global_position = pos, 0.0, 1.0, VAULT_TIME)
	await tw.finished
	global_position = Vector3(dest.x, start.y, dest.z)
	collision_mask = GameManager.L_WORLD | GameManager.L_PLAYER_BLOCK | GameManager.L_ZOMBIE
	vaulting = false


func can_act() -> bool:
	return not downed and not dead and busy_timer <= 0.0


func is_sprinting() -> bool:
	return sprinting


## Tremblement de caméra (explosions).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	# Caméra à la manette (stick droit)
	if not dead and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look.length() > 0.0:
			var sens := (GameManager.mouse_sensitivity / 0.12) * 170.0 * (0.5 if holder.aiming else 1.0)
			var curved := look * look.length()
			rotate_y(deg_to_rad(-curved.x * sens * delta))
			head.rotation.x = clampf(head.rotation.x - deg_to_rad(curved.y * sens * 0.75 * delta), -1.5, 1.5)
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.08
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.08


func add_recoil(amount: float) -> void:
	head.rotation.x = clampf(head.rotation.x + deg_to_rad(amount) * 0.5, -1.5, 1.5)
	rotate_y(deg_to_rad(randf_range(-amount, amount) * 0.15))


## Infecte le joueur (prolonge l'infection en cours).
func infect(seconds: float) -> void:
	if dead or downed:
		return
	if infected <= 0.0:
		GameManager.show_message("INFECTÉ", Color(0.6, 0.9, 0.2), "Vous perdez de la vie — plus de régénération")
	infected = maxf(infected, seconds)


func take_damage(amount: float, from := Vector3.INF) -> void:
	if dead or downed or invuln > 0.0:
		return
	amount *= GameManager.diff("damage")
	if GameManager.has_perk("gilet"):
		amount *= 0.65
	health -= amount
	since_hit = 0.0
	Audio.play("player_hurt", -2.0, randf_range(0.9, 1.1))
	GameManager.vibrate(0.4, 0.9, 0.3)
	damaged.emit()
	if from != Vector3.INF:
		hit_from.emit(from)
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		_go_down()


## Boire un atout : les armes sont baissées pendant un court instant.
func drink(color := Color(0.8, 0.8, 0.8)) -> void:
	busy_timer = 1.6
	Audio.play("perk_drink")
	# Flacon coloré : il monte vers la bouche, s'incline, puis redescend
	var bottle := Node3D.new()
	var glass := MeshUtil.cylinder_mesh(bottle, 0.025, 0.11, Vector3.ZERO, MeshUtil.mat(color, 0.7))
	MeshUtil.cylinder_mesh(bottle, 0.011, 0.045, Vector3(0, 0.077, 0), MeshUtil.mat(color.darkened(0.4), 0.6))
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(bottle)
	bottle.position = Vector3(0.22, -0.55, -0.4)
	var tw := create_tween()
	tw.tween_property(bottle, "position", Vector3(0.12, -0.2, -0.32), 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(bottle, "rotation:z", 0.0, 0.35)
	tw.tween_property(bottle, "position", Vector3(0.03, -0.08, -0.26), 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(bottle, "rotation:z", deg_to_rad(115.0), 0.35)
	tw.tween_interval(0.35)
	tw.tween_property(bottle, "position", Vector3(0.22, -0.55, -0.4), 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(bottle, "rotation:z", 0.0, 0.4)
	tw.tween_callback(bottle.queue_free)


func apply_perks() -> void:
	var new_max := 250.0 if GameManager.has_perk("cuirasse") else 100.0
	if new_max > max_health:
		health = new_max
	max_health = new_max
	health = minf(health, max_health)
	holder.set_max_slots(3 if GameManager.has_perk("triple_etui") else 2)
	health_changed.emit(health, max_health)


func _go_down() -> void:
	health = 0.0
	if GameManager.extra_lives > 0:
		# Dernier survivant : le coup fatal est annulé
		GameManager.extra_lives -= 1
		invuln = 3.0
		health = max_health
		health_changed.emit(health, max_health)
		GameManager.show_message("DERNIER SURVIVANT", Color(1.0, 0.6, 0.7), "Vie supplémentaire utilisée")
		Audio.play("powerup", 2.0)
		return
	Audio.play("down")
	downed = true
	holder.enter_downed()
	downed_changed.emit(true)
	_revive_on_end = GameManager.has_perk("second_souffle")
	down_left = 3.0 if _revive_on_end else DOWN_TIME
	GameManager.show_message("À TERRE", Color(0.9, 0.3, 0.2), "Tirez au pistolet pour survivre" if not _revive_on_end else "Réanimation en cours…")


## Fin du temps à terre : réanimation (Second Souffle) ou mort.
func _end_down() -> void:
	if _revive_on_end:
		downed = false
		holder.exit_downed()
		invuln = 3.0
		GameManager.clear_perks()
		health = max_health
		health_changed.emit(health, max_health)
		downed_changed.emit(false)
		GameManager.show_message("RÉANIMÉ", Color(0.3, 0.6, 1.0))
	else:
		dead = true
		var tw := create_tween()
		tw.tween_property(head, "position:y", 0.25, 0.8)
		tw.parallel().tween_property(head, "rotation:z", 1.2, 0.8)
		await get_tree().create_timer(2.5, false).timeout
		GameManager.game_over()
