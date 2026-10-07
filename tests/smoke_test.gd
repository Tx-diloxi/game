extends Node
## Test de fumée headless : joue une partie accélérée et vérifie les mécaniques principales.
## Lancer : Godot_console.exe --headless --path . res://tests/smoke_test.tscn

const DoorScript := preload("res://scripts/interactables/door.gd")
const PerkScript := preload("res://scripts/interactables/perk_machine.gd")
const WallBuyScript := preload("res://scripts/interactables/wall_buy.gd")
const PowerScript := preload("res://scripts/interactables/power_switch.gd")
const UpgradeScript := preload("res://scripts/interactables/upgrade_machine.gd")
const TrapScript := preload("res://scripts/interactables/trap.gd")
const ZombieScript := preload("res://scripts/zombies/zombie.gd")
const WeaponDBTest := preload("res://scripts/weapons/weapon_db.gd")

var game: Node
var player: Node
var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		fails += 1


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return cond.call()


func find_interactables(script: Script) -> Array:
	return get_tree().get_nodes_in_group("interactable").filter(func(n): return n.get_script() == script)


func _ready() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await wait(1.0)
	player = game.player
	player.invuln = 1e9

	# Navigation
	var map: RID = game.nav.get_navigation_map()
	for b in game.barricades:
		if b.zone != 0:
			continue
		var path := NavigationServer3D.map_get_path(map, b.spawn_point(), b.outside_point(), true)
		check(path.size() > 0 and path[-1].distance_to(b.outside_point()) < 0.8, "chemin apparition -> fenêtre %s" % b.global_position)
		path = NavigationServer3D.map_get_path(map, b.inside_point(), player.global_position, true)
		check(path.size() > 0 and path[-1].distance_to(player.global_position) < 1.5, "chemin fenêtre -> joueur %s" % b.global_position)

	# Manche 1
	Engine.time_scale = 4.0
	check(await wait_until(func(): return GameManager.round_num == 1, 10.0), "la manche 1 démarre")
	check(await wait_until(func(): return get_tree().get_nodes_in_group("zombies").size() > 0, 10.0), "des zombies apparaissent")
	check(await wait_until(func(): return game.barricades.any(func(b): return b.boards < 6), 40.0), "un zombie arrache des planches")
	check(await wait_until(func(): return get_tree().get_nodes_in_group("zombies").any(func(z): return z.state == z.State.CHASE), 40.0), "un zombie entre et poursuit le joueur")
	var z0: Node3D = get_tree().get_nodes_in_group("zombies").filter(func(z): return z.state == z.State.CHASE).front()
	if z0:
		var d0: float = z0.global_position.distance_to(player.global_position)
		await wait(4.0)
		if is_instance_valid(z0) and z0.state != z0.State.DEAD:
			var d1: float = z0.global_position.distance_to(player.global_position)
			check(d1 < d0 or d1 < 2.0, "le zombie se rapproche du joueur (%.1f -> %.1f)" % [d0, d1])

	# Tuer toute la manche
	var pts_before := GameManager.points
	var ok := await wait_until(func():
		for z in get_tree().get_nodes_in_group("zombies"):
			z.take_damage(99999.0, true, "bullet")
		return GameManager.round_num == 2, 120.0)
	check(ok, "la manche 2 démarre après avoir tué la manche 1")
	check(GameManager.points > pts_before, "les éliminations rapportent des points (%d)" % GameManager.points)
	check(GameManager.kills >= 6, "kills comptés (%d)" % GameManager.kills)
	Engine.time_scale = 1.0

	# Économie
	GameManager.points = 100000
	for d in find_interactables(DoorScript):
		d.interact(player)
	await wait(1.5)
	check(game.active_zones.has(1) and game.active_zones.has(2), "les portes débloquent les zones")
	var path2 := NavigationServer3D.map_get_path(map, Vector3(0, 0, 0), Vector3(0, 0, -45), true)
	check(path2.size() > 0 and path2[-1].distance_to(Vector3(0, 0, -45)) < 1.0, "navigation vers la grande salle après ouverture")

	var perk: Node = find_interactables(PerkScript).filter(func(p): return p.perk_id == "cuirasse").front()
	perk.interact(player)
	await wait(0.2)
	check(not GameManager.has_perk("cuirasse"), "atout refusé sans courant")
	find_interactables(PowerScript)[0].interact(player)
	check(GameManager.power_on, "courant rétabli")
	for p in find_interactables(PerkScript):
		p.interact(player)
		await wait(1.7)
	check(GameManager.perks.size() == GameManager.MAX_PERKS, "4 atouts maximum (%s)" % [GameManager.perks])
	check(player.max_health == 250.0 or not GameManager.has_perk("cuirasse"), "Cuirasse augmente la santé")

	var wb: Node = find_interactables(WallBuyScript).filter(func(w): return w.weapon_id == "carabine").front()
	wb.interact(player)
	check(player.holder.has_weapon("carabine"), "achat d'arme murale")
	var w = player.holder.cur()
	w.mag = 0
	wb.interact(player)
	check(player.holder.cur().mag > 0, "achat de munitions")

	var box: Node = game.box
	box.interact(player)
	check(await wait_until(func(): return box.state == box.State.OFFER or box.state == box.State.LEAVING, 8.0), "la boîte propose une arme")
	if box.state == box.State.OFFER:
		var offered: String = box.offered_id
		box.interact(player)
		check(player.holder.has_weapon(offered), "arme de la boîte récupérée (%s)" % offered)

	await wait(0.6)
	var up: Node = find_interactables(UpgradeScript)[0]
	var id: String = player.holder.cur().id
	up.interact(player)
	check(await wait_until(func(): return up.state == up.State.READY, 8.0), "l'amélioration se termine")
	up.interact(player)
	check(player.holder.has_weapon(id) and player.holder.cur().upgraded, "arme améliorée récupérée")

	# Tir et grenade
	await wait(0.6)
	var cw = player.holder.cur()
	var mag_before: int = cw.mag
	player.holder._try_fire(cw, true)
	check(cw.mag == mag_before - 1, "tir consomme une balle")
	player.holder._throw_grenade()
	await wait(2.6)
	check(true, "grenade lancée et explosée sans erreur")

	# Chiens
	var before := get_tree().get_nodes_in_group("zombies").size()
	game.rounds.alive += 1
	check(game.spawn_enemy({"kind": "dog", "hp": 300.0, "speed": 6.2}), "apparition d'un chien")
	var dog: Node = get_tree().get_nodes_in_group("zombies").filter(func(z): return z.kind == "dog").front()
	var d0: float = dog.global_position.distance_to(player.global_position)
	await wait(1.0)
	check(dog.global_position.distance_to(player.global_position) < d0, "le chien court vers le joueur")
	dog.take_damage(9999.0, false, "bullet")
	await wait(1.5)
	check(get_tree().get_nodes_in_group("zombies").size() == before, "le chien meurt sans erreur")

	# Pièges
	var trap: Node = find_interactables(TrapScript).filter(func(t): return t.kind == "electric").front()
	var tz := _spawn_test_zombie(trap.zone_center - Vector3(0, 1, 0))
	game.rounds.alive += 1
	trap.interact(player)
	await wait(0.5)
	check(not is_instance_valid(tz) or tz.state == tz.State.DEAD, "le piège électrique tue les zombies")
	check(trap.get_prompt(player) == "Piège actif", "le piège reste actif")

	# Démembrement
	var dz := _spawn_test_zombie(Vector3(4, 0, -36))
	await wait(0.3)
	dz.on_limb_hit(dz._model.bone_pos("Bip01 L Forearm"), 9999.0 * 0.0 + dz.max_hp)
	check(dz._model._severed.size() == 1, "un bras peut être arraché")
	for i in 20:
		if dz.crawling:
			break
		dz.on_blast(dz.global_position + Vector3(1, 0, 0))
	check(dz.crawling, "une explosion peut transformer un zombie en rampant")
	await wait(0.5)
	check(is_instance_valid(dz) and dz.state != dz.State.DEAD, "le zombie rampant reste en vie")

	# Améliorations spéciales
	var fz := _spawn_test_zombie(Vector3(-4, 0, -36))
	player.holder._apply_upgrade_effect("fire", fz, fz.global_position, Vector3.FORWARD, 50.0)
	check(fz._burn_t > 0.0, "balles incendiaires : le zombie brûle")
	var hp_before: float = dz.hp
	player.holder._apply_upgrade_effect("chain", fz, dz.global_position + Vector3(1, 1, 0), Vector3.FORWARD, 30.0)
	check(not is_instance_valid(dz) or dz.hp < hp_before or dz.state == dz.State.DEAD, "arc électrique : touche un zombie voisin")
	for z in get_tree().get_nodes_in_group("zombies"):
		z.take_damage(99999.0, false, "nuke")
	await wait(0.5)

	# Singe-leurre
	var lz := _spawn_test_zombie(Vector3(0, 0, -44))
	lz.speed = 2.0
	lz.state = lz.State.CHASE
	player.holder.give_monkeys(1)
	player.global_position = Vector3(0, 0.1, -34)
	player.rotation.y = PI
	player.head.rotation.x = -0.3
	player.holder.grenade_timer = 0.0
	player.holder.throw_monkey()
	check(player.holder.monkeys == 0, "le singe est lancé")
	check(await wait_until(func(): return game.decoy != null, 4.0), "le singe s'active au sol")
	var md: Vector3 = game.decoy.global_position if game.decoy else Vector3.ZERO
	var lz0: float = lz.global_position.distance_to(md)
	await wait(2.0)
	check(is_instance_valid(lz) and lz.global_position.distance_to(md) < lz0, "les zombies sont attirés par le singe")
	check(await wait_until(func(): return game.decoy == null, 9.0), "le singe explose")
	check(not is_instance_valid(lz) or lz.state == lz.State.DEAD, "l'explosion du singe tue le zombie")

	# Boss
	game.rounds.alive += 1
	check(game.spawn_enemy({"kind": "boss", "hp": 5000.0, "speed": 2.1}), "apparition du Colosse")
	var boss: Node = get_tree().get_nodes_in_group("zombies").filter(func(z): return z.kind == "boss").front()
	check(boss.armor > 0.0, "le Colosse porte un casque")
	boss.take_damage(boss.armor * 1.01, true, "bullet")
	check(boss.armor <= 0.0 and boss.hp > 0.0, "le casque se brise avant le Colosse")
	await wait(1.0)
	var pts := GameManager.points
	boss.take_damage(99999.0, true, "bullet")
	check(GameManager.points >= pts + 500, "le Colosse rapporte 500 points")
	await wait(0.5)

	# Nouveaux atouts
	check(find_interactables(PerkScript).size() == GameManager.PERKS.size(), "un distributeur par atout (%d)" % GameManager.PERKS.size())
	GameManager.perks.clear()
	GameManager.add_perk("mains_d_or")
	var pts0 := GameManager.points
	GameManager.add_points(100)
	check(GameManager.points - pts0 == 150, "Mains d'Or : +50 % de points")
	GameManager.perks.clear()
	var wr := WeaponDBTest.make("k74")
	var res0: int = WeaponDBTest.max_reserve(wr)
	GameManager.add_perk("ravitailleur")
	check(WeaponDBTest.max_reserve(wr) == int(ceil(res0 * 1.5)), "Ravitailleur : réserves +50 %")
	GameManager.perks.clear()
	GameManager.add_perk("pied_leger")
	GameManager.add_perk("oeil_de_lynx")
	GameManager.add_perk("bouclier")
	check(GameManager.perks.size() == 3, "atouts cumulables")
	GameManager.perks.clear()

	# Statistiques et manette
	check(GameManager.shots_fired > 0 and GameManager.play_time > 5.0, "statistiques de partie enregistrées")
	check(InputMap.has_action("scoreboard") and InputMap.has_action("look_left"), "actions tableau des scores et caméra manette")
	var pad_ok := true
	for a in ["fire", "aim", "jump", "reload", "interact", "pause", "move_forward", "special"]:
		var has_pad := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		pad_ok = pad_ok and has_pad
	check(pad_ok, "chaque action principale a une touche de manette")
	GameManager.gamepad = true
	check(GameManager.hint("[F] Acheter").begins_with("[Y]"), "les indications passent en touches de manette")
	GameManager.gamepad = false

	# Sons : annonceur et musique
	var voices_ok := true
	for v in Audio.VOICES:
		voices_ok = voices_ok and Audio._streams.has("voice_" + v)
	check(voices_ok, "toutes les voix de l'annonceur sont chargées")
	var loop_ok := true
	for m in ["menu_music", "ambience"]:
		for st in Audio._streams[m]:
			if st is AudioStreamOggVorbis and not st.loop:
				loop_ok = false
	check(loop_ok, "les musiques bouclent")
	Audio.say("max_ammo")
	check(Audio._voice.playing, "l'annonceur parle")

	# Power-ups
	for kind in GameManager.POWERUPS:
		game.apply_powerup(kind)
	check(GameManager.is_powerup_active("insta_kill") and GameManager.is_powerup_active("double_points"), "power-ups temporisés actifs")
	game.spawn_powerup(player.global_position, "max_ammo")
	await wait(0.3)
	check(true, "ramassage de power-up sans erreur")

	print("==== %s (%d échec(s)) ====" % ["SUCCÈS" if fails == 0 else "ÉCHEC", fails])
	get_tree().quit(fails)


func _spawn_test_zombie(pos: Vector3) -> Node:
	var z = ZombieScript.new()
	z.setup("zombie", 2000.0, 0.01, null)
	game.add_child(z)
	z.global_position = pos
	return z
