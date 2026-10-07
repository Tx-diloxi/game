extends CharacterBody3D
## Joueur FPS : déplacements, santé régénérante, interaction, mise à terre.

const WeaponHolderScript := preload("res://scripts/player/weapon_holder.gd")

signal health_changed(health: float, max_health: float)
signal downed_changed(downed: bool)
signal damaged

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

var head: Node3D
var camera: Camera3D
var holder: Node3D
var hud: Node = null

var health := 100.0
var max_health := 100.0
var since_hit := 10.0
var downed := false
var dead := false
var busy_timer := 0.0
var invuln := 0.0
var sprinting := false
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

	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	crouching = Input.is_action_pressed("crouch") and not downed
	sprinting = Input.is_action_pressed("sprint") and input.y < -0.3 and not crouching \
		and can_act() and not holder.aiming and not holder.is_reloading()

	var speed := WALK_SPEED
	if downed:
		speed = 0.0
	elif sprinting:
		speed = SPRINT_SPEED
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

	if is_on_floor() and Input.is_action_just_pressed("jump") and not downed and not crouching:
		velocity.y = JUMP_VELOCITY

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
	var fast_heal := GameManager.has_perk("bouclier")
	if since_hit > (REGEN_DELAY * 0.5 if fast_heal else REGEN_DELAY) and health < max_health and not downed:
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


func take_damage(amount: float) -> void:
	if dead or downed or invuln > 0.0:
		return
	health -= amount
	since_hit = 0.0
	Audio.play("player_hurt", -2.0, randf_range(0.9, 1.1))
	GameManager.vibrate(0.4, 0.9, 0.3)
	damaged.emit()
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		_go_down()


## Boire un atout : les armes sont baissées pendant un court instant.
func drink() -> void:
	busy_timer = 1.6
	Audio.play("perk_drink")


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
	Audio.play("down")
	if GameManager.has_perk("second_souffle"):
		downed = true
		downed_changed.emit(true)
		await get_tree().create_timer(3.0, false).timeout
		if not is_inside_tree():
			return
		downed = false
		invuln = 3.0
		GameManager.clear_perks()
		health = max_health
		health_changed.emit(health, max_health)
		downed_changed.emit(false)
		GameManager.show_message("RÉANIMÉ", Color(0.3, 0.6, 1.0))
	else:
		dead = true
		downed_changed.emit(true)
		var tw := create_tween()
		tw.tween_property(head, "position:y", 0.25, 0.8)
		tw.parallel().tween_property(head, "rotation:z", 1.2, 0.8)
		await get_tree().create_timer(2.5, false).timeout
		GameManager.game_over()
