extends Node3D
## Inventaire et tir du joueur : armes (2 emplacements, 3 avec Triple Étui), tir hitscan,
## rechargement, visée, corps-à-corps, grenades et modèle vue subjective.

const WeaponDB := preload("res://scripts/weapons/weapon_db.gd")
const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const GrenadeScript := preload("res://scripts/weapons/grenade.gd")
const MonkeyScript := preload("res://scripts/weapons/monkey.gd")

signal ammo_changed
signal weapon_changed
signal hit_confirmed(killed: bool, head: bool)

const HIP_POS := Vector3(0.21, -0.2, -0.56)
const ADS_POS := Vector3(0.0, -0.115, -0.4)
const HIP_FOV := 75.0
const MAX_GRENADES := 4
const MELEE_DAMAGE := 150.0
const MELEE_RANGE := 2.3

var player: CharacterBody3D
var camera: Camera3D

var weapons: Array = []
var current := 0
var max_slots := 2
var grenades := 2
var monkeys := 0

var fire_timer := 0.0
var reload_timer := 0.0
var reload_total := 0.0
var switch_timer := 0.0
var melee_timer := 0.0
var grenade_timer := 0.0
var aiming := false
var aim_blend := 0.0
var lower_blend := 0.0
var kick := 0.0
var bob_t := 0.0

var view: Node3D
var muzzle_light: OmniLight3D
var flash_mesh: MeshInstance3D
var flash_timer := 0.0


func _ready() -> void:
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.75, 0.4)
	muzzle_light.omni_range = 6.0
	muzzle_light.light_energy = 0.0
	add_child(muzzle_light)


# --- API ------------------------------------------------------------------

func cur() -> Variant:
	if weapons.is_empty():
		return null
	return weapons[current]


func has_weapon(id: String) -> bool:
	return find_weapon(id) >= 0


func find_weapon(id: String) -> int:
	for i in weapons.size():
		if weapons[i].id == id:
			return i
	return -1


func give_weapon(id: String, upgraded := false) -> void:
	var w := WeaponDB.make(id, upgraded)
	var idx := find_weapon(id)
	if idx >= 0:
		weapons[idx] = w
		current = idx
	elif weapons.size() < max_slots:
		weapons.append(w)
		current = weapons.size() - 1
	else:
		weapons[current] = w
	_on_switched()


func refill(id: String) -> void:
	var idx := find_weapon(id)
	if idx < 0:
		return
	var w: Dictionary = weapons[idx]
	w.mag = WeaponDB.max_mag(w)
	w.reserve = WeaponDB.max_reserve(w)
	ammo_changed.emit()


func refill_all() -> void:
	for w in weapons:
		w.mag = WeaponDB.max_mag(w)
		w.reserve = WeaponDB.max_reserve(w)
	grenades = MAX_GRENADES
	ammo_changed.emit()


func add_grenades(n: int) -> void:
	grenades = mini(grenades + n, MAX_GRENADES)
	ammo_changed.emit()


## Retire l'arme en main (pour la machine d'amélioration).
func take_current() -> Variant:
	if weapons.is_empty():
		return null
	var w: Dictionary = weapons[current]
	weapons.remove_at(current)
	current = clampi(current, 0, maxi(weapons.size() - 1, 0))
	_on_switched()
	return w


func set_max_slots(n: int) -> void:
	max_slots = n
	while weapons.size() > max_slots:
		var drop := weapons.size() - 1
		if drop == current:
			drop -= 1
		weapons.remove_at(drop)
	current = clampi(current, 0, maxi(weapons.size() - 1, 0))
	_on_switched()


func is_reloading() -> bool:
	return reload_timer > 0.0


func current_spread() -> float:
	var w = cur()
	if w == null:
		return 0.0
	var s: float = WeaponDB.data(w.id).spread
	s *= lerpf(1.0, 0.3, aim_blend)
	if player.velocity.length() > 1.0:
		s *= 1.5
	return s


# --- Boucle ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	fire_timer = maxf(fire_timer - delta, 0.0)
	switch_timer = maxf(switch_timer - delta, 0.0)
	melee_timer = maxf(melee_timer - delta, 0.0)
	grenade_timer = maxf(grenade_timer - delta, 0.0)
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	if not player.can_act():
		aiming = false
		return

	var sprinting: bool = player.is_sprinting()
	aiming = Input.is_action_pressed("aim") and not sprinting and cur() != null

	if Input.is_action_just_pressed("weapon_1"):
		switch_to(0)
	elif Input.is_action_just_pressed("weapon_2"):
		switch_to(1)
	elif Input.is_action_just_pressed("weapon_3"):
		switch_to(2)
	elif Input.is_action_just_pressed("weapon_next") and weapons.size() > 1:
		switch_to((current + 1) % weapons.size())
	elif Input.is_action_just_pressed("weapon_prev") and weapons.size() > 1:
		switch_to((current - 1 + weapons.size()) % weapons.size())

	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("melee"):
		_melee()
	if Input.is_action_just_pressed("grenade"):
		_throw_grenade()
	if Input.is_action_just_pressed("special"):
		throw_monkey()

	var w = cur()
	if w != null and not sprinting:
		var auto: bool = WeaponDB.data(w.id).auto
		if (auto and Input.is_action_pressed("fire")) or Input.is_action_just_pressed("fire"):
			_try_fire(w, Input.is_action_just_pressed("fire"))


func _process(delta: float) -> void:
	if view == null:
		return
	var busy: bool = not player.can_act() or player.is_sprinting() or switch_timer > 0.0
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 6.0)
	lower_blend = move_toward(lower_blend, 1.0 if busy else 0.0, delta * 5.0)
	kick = move_toward(kick, 0.0, delta * 6.0)

	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor() and hspeed > 0.5:
		bob_t += delta * hspeed * 1.6
	var bob_amt := (1.0 - aim_blend * 0.85) * clampf(hspeed / 5.0, 0.0, 1.5)
	var bob := Vector3(sin(bob_t) * 0.012, absf(cos(bob_t)) * 0.014, 0.0) * bob_amt

	var pos := HIP_POS.lerp(ADS_POS, aim_blend) + bob
	var rot := Vector3.ZERO
	pos.y -= lower_blend * 0.25
	rot.x -= lower_blend * 0.7
	pos.z += kick * 0.06
	rot.x += kick * 0.12
	if reload_timer > 0.0 and reload_total > 0.0:
		var p := sin((1.0 - reload_timer / reload_total) * PI)
		pos.y -= p * 0.12
		rot.z += p * 0.6
		rot.x += p * 0.3
	if melee_timer > 0.3:
		var m := sin((0.6 - melee_timer) / 0.3 * PI)
		pos += Vector3(-0.2, 0.05, -0.25) * m
		rot.y += m * 0.8
	view.position = view.position.lerp(pos, minf(delta * 20.0, 1.0))
	view.rotation = view.rotation.lerp(rot, minf(delta * 20.0, 1.0))

	var w = cur()
	var ads_fov := 55.0
	if w != null and WeaponDB.data(w.id).kind == "sniper":
		ads_fov = 22.0
	camera.fov = lerpf(GameManager.fov, ads_fov, aim_blend)

	flash_timer -= delta
	var flashing := flash_timer > 0.0
	muzzle_light.light_energy = 3.0 if flashing else 0.0
	if flash_mesh:
		flash_mesh.visible = flashing


# --- Actions --------------------------------------------------------------

func switch_to(i: int) -> void:
	if i == current or i < 0 or i >= weapons.size():
		return
	current = i
	_on_switched()


func start_reload() -> void:
	var w = cur()
	if w == null or reload_timer > 0.0 or w.reserve <= 0 or w.mag >= WeaponDB.max_mag(w):
		return
	var t: float = WeaponDB.data(w.id).reload
	if GameManager.has_perk("main_leste"):
		t *= 0.5
	reload_timer = t
	reload_total = t
	Audio.play("reload", -6.0, 1.0 / clampf(t / 2.0, 0.6, 1.6))


func _finish_reload() -> void:
	reload_timer = 0.0
	var w = cur()
	if w == null:
		return
	var need: int = WeaponDB.max_mag(w) - w.mag
	var take: int = mini(need, w.reserve)
	w.mag += take
	w.reserve -= take
	ammo_changed.emit()


func _try_fire(w: Dictionary, just_pressed: bool) -> void:
	if reload_timer > 0.0 or switch_timer > 0.0 or fire_timer > 0.0 or melee_timer > 0.3:
		return
	if w.mag <= 0:
		if just_pressed:
			Audio.play("empty")
			start_reload()
		return
	var d := WeaponDB.data(w.id)
	w.mag -= 1
	var rate: float = d.rpm * (1.33 if GameManager.has_perk("tonique_eclair") else 1.0)
	fire_timer = 60.0 / rate
	Audio.play(d.sound, -7.0, randf_range(0.95, 1.05) * (0.85 if w.upgraded else 1.0))
	var spread := current_spread()
	if d.kind == "shotgun":
		get_tree().create_timer(0.35, false).timeout.connect(func(): Audio.play("shotgun_pump", -7.0))
	for i in d.pellets:
		_fire_ray(w, d, spread)
	kick = minf(kick + 0.6, 1.0)
	player.add_recoil(d.recoil * lerpf(1.0, 0.5, aim_blend))
	flash_timer = 0.05
	ammo_changed.emit()
	if w.mag == 0 and w.reserve > 0:
		start_reload()


func _fire_ray(w: Dictionary, d: Dictionary, spread: float) -> void:
	var b := camera.global_basis
	var origin := camera.global_position
	var dir := (-b.z + b.x * randf_range(-spread, spread) + b.y * randf_range(-spread, spread)).normalized()
	var hit := _ray(origin, origin + dir * 150.0)
	var game := GameManager.game
	if d.splash > 0.0:
		var end: Vector3 = hit.position if not hit.is_empty() else origin + dir * 40.0
		if game:
			game.spawn_tracer(_muzzle_global(), end, Color(0.3, 1.0, 0.4))
			game.explode(end, d.splash * (1.5 if w.upgraded else 1.0), WeaponDB.damage(w), "bullet", false)
		return
	if hit.is_empty():
		return
	var col: Object = hit.collider
	var pos: Vector3 = hit.position
	var effect: String = d.get("upgrade_effect", "") if w.upgraded else ""
	if col != null and col.has_method("take_damage"):
		var head: bool = pos.y > col.global_position.y + col.head_height
		var dmg: float = WeaponDB.damage(w) * (d.head_mult if head else 1.0)
		if col.has_method("on_limb_hit") and not head:
			col.on_limb_hit(pos, dmg)
		_apply_upgrade_effect(effect, col, pos, dir, dmg)
		var killed: bool = col.take_damage(dmg, head, "bullet")
		hit_confirmed.emit(killed, head)
		if game:
			game.spawn_blood(pos, -dir, head or killed)
	elif game:
		game.spawn_spark(pos, hit.normal)
		if effect == "explosive":
			_apply_upgrade_effect(effect, null, pos, dir, WeaponDB.damage(w))


## Effets propres à chaque arme améliorée.
func _apply_upgrade_effect(effect: String, target: Object, pos: Vector3, dir: Vector3, dmg: float) -> void:
	var game := GameManager.game
	if effect == "" or game == null:
		return
	match effect:
		"explosive":
			game.explode(pos, 2.2, dmg * 0.8 + 150.0, "explosion", false)
		"fire":
			if target and target.has_method("ignite"):
				target.ignite(maxf(dmg * 1.5, 60.0 + 25.0 * GameManager.round_num), 3.5)
		"knockback":
			if target and target.has_method("push"):
				target.push(dir * 9.0)
		"chain":
			var hits := 0
			var from := pos
			for z in get_tree().get_nodes_in_group("zombies"):
				if z == target or hits >= 3:
					continue
				var zp: Vector3 = z.global_position + Vector3.UP
				if zp.distance_to(pos) < 6.0:
					game.spawn_tracer(from, zp, Color(0.45, 0.7, 1.0))
					z.take_damage(dmg * 0.75, false, "bullet")
					from = zp
					hits += 1
			if hits > 0:
				Audio.play_at("power_on", pos, -10.0, 3.0)


func _melee() -> void:
	if melee_timer > 0.0:
		return
	melee_timer = 0.6
	reload_timer = 0.0
	Audio.play("knife", -4.0)
	var origin := camera.global_position
	var hit := _ray(origin, origin - camera.global_basis.z * MELEE_RANGE)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col != null and col.has_method("take_damage"):
		var killed: bool = col.take_damage(MELEE_DAMAGE, false, "melee")
		hit_confirmed.emit(killed, false)
		if GameManager.game:
			GameManager.game.spawn_blood(hit.position, camera.global_basis.z, true)


func _throw_grenade() -> void:
	if grenades <= 0 or grenade_timer > 0.0:
		return
	grenades -= 1
	grenade_timer = 0.8
	ammo_changed.emit()
	Audio.play("grenade_throw")
	var g: RigidBody3D = GrenadeScript.new()
	get_tree().current_scene.add_child(g)
	var fwd := -camera.global_basis.z
	g.global_position = camera.global_position + fwd * 0.6
	g.linear_velocity = fwd * 15.0 + Vector3.UP * 3.0 + player.velocity * 0.5


func give_monkeys(n: int) -> void:
	monkeys = n
	ammo_changed.emit()


func throw_monkey() -> void:
	if monkeys <= 0 or grenade_timer > 0.0:
		return
	monkeys -= 1
	grenade_timer = 0.8
	ammo_changed.emit()
	Audio.play("grenade_throw")
	var m: RigidBody3D = MonkeyScript.new()
	get_tree().current_scene.add_child(m)
	var fwd := -camera.global_basis.z
	m.global_position = camera.global_position + fwd * 0.6
	m.linear_velocity = fwd * 11.0 + Vector3.UP * 3.5 + player.velocity * 0.5


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, GameManager.L_WORLD | GameManager.L_ZOMBIE, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


func _muzzle_global() -> Vector3:
	if view and view.has_meta("muzzle"):
		return view.to_global(view.get_meta("muzzle"))
	return camera.global_position


func _on_switched() -> void:
	reload_timer = 0.0
	switch_timer = 0.45
	_rebuild_view()
	weapon_changed.emit()
	ammo_changed.emit()


func _rebuild_view() -> void:
	if view:
		muzzle_light.reparent(self, false)
		view.queue_free()
		view = null
		flash_mesh = null
	var w = cur()
	if w == null:
		return
	var d := WeaponDB.data(w.id)
	view = MeshUtil.build_gun(self, w.id, w.upgraded, d.color, d.kind)
	view.position = HIP_POS + Vector3(0, -0.3, 0)
	var muzzle: Vector3 = view.get_meta("muzzle")
	flash_mesh = MeshUtil.sphere_mesh(view, 0.05, muzzle, MeshUtil.mat(Color(1.0, 0.8, 0.4), 6.0))
	flash_mesh.visible = false
	muzzle_light.reparent(view, false)
	muzzle_light.position = muzzle
	for mi in view.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
