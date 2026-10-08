extends Node3D
## Inventaire et tir du joueur : armes (2 emplacements, 3 avec Triple Étui), tir hitscan,
## rechargement, visée, corps-à-corps, grenades et modèle vue subjective.

const WeaponDB := preload("res://scripts/weapons/weapon_db.gd")
const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const GrenadeScript := preload("res://scripts/weapons/grenade.gd")
const MonkeyScript := preload("res://scripts/weapons/monkey.gd")
const FpsArms := preload("res://scripts/player/fps_arms.gd")

signal ammo_changed
signal weapon_changed
signal hit_confirmed(killed: bool, head: bool)

const HIP_POS := Vector3(0.21, -0.2, -0.56)
const ADS_POS := Vector3(0.0, -0.115, -0.5)
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
var arms: Node3D
var _grip := {}
## Recul de l'arme vers le joueur (m) pour que les deux mains l'atteignent, au repos et en visée.
var _hip_shift := Vector3.ZERO
var _ads_shift := Vector3.ZERO
var muzzle_light: OmniLight3D
var flash_mesh: MeshInstance3D
var flash_timer := 0.0
var pump_t := 0.0        # animation de la pompe / du verrou après un tir
var pump_total := 0.45
var throw_t := -1.0      # >= 0 : lancer en cours (temps écoulé)
var throw_kind := ""     # "grenade" ou "monkey"
var throw_released := false
var _prop: Node3D
var _prop_kind := ""
const THROW_TIME := 0.9
const THROW_RELEASE := 0.5
# Images clés des mains pendant un lancer (espace caméra) : [temps, position]
const THROW_R := [[0.0, Vector3(0.26, -0.5, -0.3)], [0.2, Vector3(0.16, -0.2, -0.4)], [0.4, Vector3(0.22, -0.04, -0.2)],
	[0.5, Vector3(0.12, 0.0, -0.6)], [0.65, Vector3(0.1, -0.3, -0.55)], [0.9, Vector3(0.26, -0.5, -0.3)]]
const THROW_L := [[0.0, Vector3(-0.25, -0.5, -0.3)], [0.15, Vector3(-0.05, -0.2, -0.4)], [0.3, Vector3(-0.13, -0.12, -0.3)],
	[0.45, Vector3(-0.25, -0.4, -0.3)], [0.9, Vector3(-0.25, -0.5, -0.3)]]


func _ready() -> void:
	if FpsArms.available():
		arms = FpsArms.new()
		add_child(arms)
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


## Arme à lunette (sniper, tireur d'élite) : la visée affiche un viseur plein écran.
func has_scope() -> bool:
	var w = cur()
	if w == null:
		return false
	var d := WeaponDB.data(w.id)
	return d.kind == "sniper" or d.get("ads_fov", 55.0) < 45.0


## Vrai quand l'œil est collé à la lunette : l'arme et les bras disparaissent.
func is_scoped() -> bool:
	return aim_blend > 0.85 and has_scope()


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
	pump_t = maxf(pump_t - delta, 0.0)
	_update_throw(delta)
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
	var busy: bool = not player.can_act() or player.is_sprinting() or throw_t >= 0.0
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 6.0)
	lower_blend = move_toward(lower_blend, 1.0 if busy else 0.0, delta * 5.0)
	kick = move_toward(kick, 0.0, delta * 6.0)

	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor() and hspeed > 0.5:
		bob_t += delta * hspeed * 1.6
	var bob_amt := (1.0 - aim_blend * 0.85) * clampf(hspeed / 5.0, 0.0, 1.5)
	var bob := Vector3(sin(bob_t) * 0.012, absf(cos(bob_t)) * 0.014, 0.0) * bob_amt

	var ads := _ads_pos()
	var pos := (HIP_POS + _hip_shift).lerp(ads + _ads_shift, aim_blend) + bob
	var rot := Vector3.ZERO
	pos.y -= lower_blend * 0.25
	rot.x -= lower_blend * 0.7
	if switch_timer > 0.0: # prise en main : l'arme remonte en tournant
		var dr := smoothstep(0.0, 1.0, switch_timer / 0.45)
		pos.y -= dr * 0.3
		rot.x -= dr * 0.8
		rot.z += dr * 0.35
	if throw_t >= 0.0:
		pos.y -= 0.4 * lower_blend
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
	_update_arms()
	view.visible = not is_scoped()
	if is_scoped():
		arms.visible = false

	var w = cur()
	var ads_fov := 55.0
	if w != null:
		var wd := WeaponDB.data(w.id)
		ads_fov = wd.get("ads_fov", 22.0 if wd.kind == "sniper" else 55.0)
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
	if reload_timer > 0.0 or switch_timer > 0.0 or fire_timer > 0.0 or melee_timer > 0.3 or throw_t >= 0.0:
		return
	if w.mag <= 0:
		if just_pressed:
			Audio.play("empty")
			start_reload()
		return
	var d := WeaponDB.data(w.id)
	if not GameManager.is_powerup_active("infinite_ammo"):
		w.mag -= 1
	GameManager.shots_fired += 1
	GameManager.vibrate(0.3, 0.0, 0.08)
	var rate: float = d.rpm * (1.33 if GameManager.has_perk("tonique_eclair") else 1.0)
	fire_timer = 60.0 / rate
	Audio.play(d.sound, -7.0, randf_range(0.95, 1.05) * d.get("sound_pitch", 1.0) * (0.85 if w.upgraded else 1.0))
	var spread := current_spread()
	if d.kind == "shotgun":
		get_tree().create_timer(0.35, false).timeout.connect(func(): Audio.play("shotgun_pump", -7.0))
		pump_total = 0.55
		pump_t = 0.55
	elif d.kind == "sniper":
		pump_total = 0.8
		pump_t = 0.8
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
		var hm: float = d.head_mult * (1.5 if GameManager.has_perk("oeil_de_lynx") else 1.0)
		var dmg: float = WeaponDB.damage(w) * (hm if head else 1.0)
		GameManager.shots_hit += 1
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
	if grenades <= 0 or throw_t >= 0.0 or grenade_timer > 0.0:
		return
	_start_throw("grenade")


func give_monkeys(n: int) -> void:
	monkeys = n
	ammo_changed.emit()


func throw_monkey() -> void:
	if monkeys <= 0 or throw_t >= 0.0 or grenade_timer > 0.0:
		return
	_start_throw("monkey")


func _start_throw(kind: String) -> void:
	throw_kind = kind
	throw_t = 0.0
	throw_released = false
	reload_timer = 0.0
	Audio.play("knife", -14.0, 1.6) # saisie de l'objet


## Avance le lancer : l'objet part à l'instant de la libération de la main.
func _update_throw(delta: float) -> void:
	if throw_t < 0.0:
		return
	throw_t += delta
	if not throw_released and throw_t >= THROW_RELEASE:
		throw_released = true
		_release_throw()
	if throw_t >= THROW_TIME:
		throw_t = -1.0


func _release_throw() -> void:
	Audio.play("grenade_throw")
	var obj: RigidBody3D
	var speed := 15.0
	var lift := 3.0
	if throw_kind == "grenade":
		if grenades <= 0:
			return
		grenades -= 1
		obj = GrenadeScript.new()
	else:
		if monkeys <= 0:
			return
		monkeys -= 1
		obj = MonkeyScript.new()
		speed = 11.0
		lift = 3.5
	ammo_changed.emit()
	get_tree().current_scene.add_child(obj)
	var fwd := -camera.global_basis.z
	obj.global_position = camera.global_position + fwd * 0.6
	obj.linear_velocity = fwd * speed + Vector3.UP * lift + player.velocity * 0.5


static func _keys(keys: Array, t: float) -> Vector3:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var u: float = (t - keys[i - 1][0]) / (keys[i][0] - keys[i - 1][0])
			return (keys[i - 1][1] as Vector3).lerp(keys[i][1], smoothstep(0.0, 1.0, u))
	return keys[keys.size() - 1][1]


## Pose des deux mains pendant un lancer ; l'objet suit la main droite jusqu'à la libération.
func _throw_grip() -> Dictionary:
	var t := throw_t
	var wind := smoothstep(0.25, 0.42, t) * (1.0 - smoothstep(0.42, 0.52, t))
	var fr := Vector3(0.0, 0.15 + 0.4 * wind, -1.0).normalized()
	var pinch := smoothstep(0.1, 0.2, t) * (1.0 - smoothstep(0.28, 0.36, t))
	var rw: Vector3 = _keys(THROW_R, t)
	var right := {"wrist": rw, "f": fr, "n": Vector3(-1, 0, 0), "curl": 1.0 if t < THROW_RELEASE else 0.15, "thumb": 0.6}
	var left := {"wrist": _keys(THROW_L, t), "f": Vector3(0.25, 0.1, -0.95), "n": Vector3(1, 0.05, 0), "curl": 0.3 + 0.5 * pinch, "thumb": 0.3 + 0.4 * pinch}
	_show_prop(not throw_released, rw + fr * 0.085 + Vector3(-0.03, 0.0, 0.0))
	return {"R": right, "L": left}


func _show_prop(on: bool, pos: Vector3) -> void:
	if on and (_prop == null or _prop_kind != throw_kind):
		if _prop:
			_prop.queue_free()
		_prop = Node3D.new()
		_prop_kind = throw_kind
		add_child(_prop)
		if throw_kind == "grenade":
			const MODEL := "res://assets/models/weapons/grenade-a.glb"
			if ResourceLoader.exists(MODEL):
				var m: Node3D = load(MODEL).instantiate()
				m.scale = Vector3.ONE * 0.7
				m.position.y = -0.06
				_prop.add_child(m)
			else:
				MeshUtil.sphere_mesh(_prop, 0.045, Vector3.ZERO, MeshUtil.mat(Color(0.2, 0.28, 0.15), 0.0, 0.6, 0.3))
		else:
			var fur := MeshUtil.mat(Color(0.45, 0.28, 0.15), 0.0, 1.0)
			MeshUtil.capsule_mesh(_prop, 0.05, 0.14, Vector3.ZERO, fur)
			MeshUtil.sphere_mesh(_prop, 0.045, Vector3(0, 0.1, 0), fur)
			MeshUtil.cylinder_mesh(_prop, 0.03, 0.03, Vector3(0, 0.15, 0), MeshUtil.mat(Color(0.7, 0.05, 0.05)))
		for mi in _prop.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _prop:
		_prop.visible = on
		_prop.position = pos


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


## Les mains suivent l'arme ; la main gauche quitte la poignée pendant le rechargement.
func _update_arms() -> void:
	if arms == null:
		return
	if throw_t >= 0.0:
		arms.visible = true
		arms.update_for_gun(self, _throw_grip())
		return
	if _prop:
		_prop.visible = false
	arms.visible = view != null and not _grip.is_empty()
	if not arms.visible:
		return
	var extra := Vector3.ZERO
	var extra_r := Vector3.ZERO
	var curl := 1.0
	if reload_timer > 0.0 and reload_total > 0.0:
		var p := sin((1.0 - reload_timer / reload_total) * PI)
		extra = Vector3(-0.03 * p, -0.17 * p, 0.09 * p)
		curl = lerpf(1.0, 0.25, p)
	elif pump_t > 0.0 and pump_t < pump_total - 0.1:
		var p := sin((1.0 - pump_t / pump_total) * PI)
		var w = cur()
		if w != null and WeaponDB.data(w.id).kind == "shotgun":
			extra = Vector3(0.0, 0.0, 0.11 * p) # la main avant fait coulisser la pompe
		else:
			extra_r = Vector3(0.0, 0.025 * p, 0.07 * p) # la main droite arme le verrou
	arms.update_for_gun(view, _grip, extra, curl, extra_r)


## Position de visée : l'arme est calée sur sa ligne de mire et repoussée si elle est longue (sinon sa crosse masque l'écran).
func _ads_pos() -> Vector3:
	var ads := ADS_POS
	if view and view.has_meta("sight_y"):
		ads.y = -0.035 - float(view.get_meta("sight_y"))
		ads.z -= maxf(0.0, WeaponDB.data(cur().id).length * 0.5 - 0.2)
	return ads


## Calcule le décalage (vers le joueur et vers le centre) pour que les deux poignets restent à portée de bras.
func _fit_reach() -> void:
	_hip_shift = Vector3.ZERO
	_ads_shift = Vector3.ZERO
	if arms == null or _grip.is_empty() or view == null:
		return
	var ads := _ads_pos()
	for pass_i in 2:
		var base := HIP_POS if pass_i == 0 else ads
		var shift := Vector3.ZERO
		for _k in 14:
			for s in ["R", "L"]:
				var info: Dictionary = arms.shoulder_info(s)
				var p: Vector3 = base + (_grip[s].wrist as Vector3) + shift
				var d: float = p.distance_to(info.pos)
				var limit: float = info.reach * 0.88
				if d > limit:
					var dirv: Vector3 = info.pos - p
					dirv.y = 0.0
					if dirv.length() > 0.001:
						shift += dirv.normalized() * (d - limit) * 0.5
		if pass_i == 1 and not view.has_meta("sight_y"):
			shift = Vector3.ZERO
		shift.x = clampf(shift.x, -0.15, 0.05)
		shift.z = clampf(shift.z, 0.0, 0.3 if pass_i == 0 else 0.07)
		if pass_i == 1:
			shift.x = 0.0 # en visée l'arme reste pile au centre de l'écran
		if pass_i == 0:
			_hip_shift = shift
		else:
			_ads_shift = shift


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
	_grip = FpsArms.grip_for(d) if arms else {}
	view = MeshUtil.build_gun(self, w.id, w.upgraded, d.color, d.kind)
	view.position = HIP_POS + Vector3(0, -0.3, 0)
	var muzzle: Vector3 = view.get_meta("muzzle")
	flash_mesh = MeshUtil.sphere_mesh(view, 0.05, muzzle, MeshUtil.mat(Color(1.0, 0.8, 0.4), 6.0))
	flash_mesh.visible = false
	muzzle_light.reparent(view, false)
	muzzle_light.position = muzzle
	_fit_reach()
	for mi in view.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
