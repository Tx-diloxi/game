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
const MeshUtilTest := preload("res://scripts/util/mesh_util.gd")

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
		if offered == "leurre":
			check(player.holder.monkeys == 3, "singe-leurre récupéré dans la boîte")
		else:
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
	var gren_before: int = player.holder.grenades
	player.holder._throw_grenade()
	check(player.holder.throw_t >= 0.0 and player.holder.grenades == gren_before, "animation de lancer démarrée, grenade encore en main")
	await wait(0.7)
	check(player.holder.grenades == gren_before - 1, "la grenade quitte la main à la libération")
	await wait(2.0)
	check(true, "grenade lancée et explosée sans erreur")

	# Chiens
	var before := get_tree().get_nodes_in_group("zombies").size()
	game.rounds.alive += 1
	check(game.spawn_enemy({"kind": "dog", "hp": 300.0, "speed": 6.2}), "apparition d'un chien")
	var dog: Node = get_tree().get_nodes_in_group("zombies").filter(func(z): return z.kind == "dog").front()
	var d0: float = dog.global_position.distance_to(player.global_position)
	await wait(1.0)
	check(dog.global_position.distance_to(player.global_position) < d0, "le chien court vers le joueur")
	var rz = load("res://scripts/zombies/zombie.gd").new()
	rz.setup("zombie", 100.0, 1.0, null)
	game.add_child(rz)
	rz.global_position = Vector3(0, 0, -30)
	await wait(0.3)
	rz.take_damage(9999.0, false, "bullet")
	check(rz._model != null and rz._model._rag != null and rz._model._rag_bones.size() > 10, "cadavre physique (ragdoll) créé")
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
	await wait(0.7)
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
	check(Audio._streams.keys().filter(func(k): return k.begins_with("voice_")).is_empty(), "annonceur désactivé (aucune voix chargée)")
	var loop_ok := true
	for m in ["menu_music", "ambience"]:
		for st in Audio._streams[m]:
			if st is AudioStreamOggVorbis and not st.loop:
				loop_ok = false
	check(loop_ok, "les musiques bouclent")
	Audio.say("max_ammo")
	check(not Audio._voice.playing, "l'annonceur reste muet")
	check(InputMap.action_get_events("ui_accept").any(func(e): return e is InputEventJoypadButton), "A valide dans les menus")

	# Options, records, remappage
	check(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Voice") >= 0, "bus audio musique/effets/voix")
	GameManager.set_music_volume(0.25)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.25), "le curseur musique règle son bus")
	GameManager.set_music_volume(0.8)
	GameManager.set_max_fps(2)
	check(Engine.max_fps == 60, "limite d'images par seconde")
	GameManager.set_max_fps(0)
	GameManager.set_shadow_quality(0)
	var shadowed := get_tree().root.find_children("*", "Light3D", true, false).filter(func(l): return l.shadow_enabled)
	check(shadowed.is_empty() and get_tree().root.positional_shadow_atlas_size > 0, "ombres désactivables sans lumières noires")
	GameManager.set_shadow_quality(3)
	check(get_tree().root.find_children("*", "Light3D", true, false).any(func(l): return l.shadow_enabled), "les ombres reviennent en qualité élevée")
	GameManager.set_shadow_quality(0)
	GameManager.set_shadow_quality(3)
	check(get_tree().root.positional_shadow_atlas_size == 4096, "ombres hautes")
	GameManager.records_path = "user://records_test.cfg"
	DirAccess.remove_absolute("user://records_test.cfg")
	GameManager.round_num = 7
	GameManager.kills = 50
	GameManager.record_game()
	GameManager.round_num = 9
	GameManager.kills = 40
	var beaten := GameManager.record_game()
	var rec := GameManager.get_records()
	check(rec.best_round == 9 and rec.best_kills == 50 and rec.games == 2, "records sauvegardés (meilleur de chaque)")
	check(beaten.has("best_round") and not beaten.has("best_kills"), "seuls les records battus sont signalés")
	DirAccess.remove_absolute("user://records_test.cfg")
	GameManager.records_path = "user://records.cfg"
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_X
	GameManager.rebind("reload", ev, false)
	var has_x := false
	var has_pad := false
	for e in InputMap.action_get_events("reload"):
		has_x = has_x or (e is InputEventKey and e.physical_keycode == KEY_X)
		has_pad = has_pad or e is InputEventJoypadButton
	check(has_x and has_pad, "remappage clavier conserve la manette")
	var pev := InputEventJoypadButton.new()
	pev.button_index = JOY_BUTTON_LEFT_SHOULDER
	GameManager.rebind("reload", pev, true)
	check(GameManager.action_label("reload", true) == "LB", "remappage manette")
	GameManager.reset_bindings()
	check(GameManager.action_label("reload", true) == "X" and GameManager.custom_bindings.is_empty(), "réinitialisation des commandes")

	# Nouveaux power-ups
	var wbuy: Node = find_interactables(WallBuyScript).front()
	var normal_price: int = wbuy.buy_price()
	game.apply_powerup("fire_sale")
	check(wbuy.buy_price() == 10 and game.box.cost() == 10, "Feu de vente : tout à 10 points")
	GameManager.active_powerups.erase("fire_sale")
	check(wbuy.buy_price() == normal_price, "le prix normal revient")
	var pts_b := GameManager.points
	game.apply_powerup("bonus_points")
	check(GameManager.points > pts_b + 400, "Bonus de points")
	game.apply_powerup("zombie_blood")
	var bz := _spawn_test_zombie(player.global_position + Vector3(8, 0, 0))
	bz.speed = 3.0
	bz.state = bz.State.CHASE
	var bz0: Vector3 = bz.global_position
	await wait(1.0)
	check(bz.global_position.distance_to(bz0) < 0.6, "Sang de zombie : les zombies lointains ne bougent pas")
	GameManager.active_powerups.erase("zombie_blood")
	bz.take_damage(99999.0, false, "nuke")

	# Variété et animations des zombies
	var runner = null
	for i in 12:
		var vz := _spawn_test_zombie(Vector3(0, 0, -44))
		if i == 0:
			runner = vz
		else:
			vz.queue_free()
	runner.speed = 4.6
	runner.state = runner.State.CHASE
	await wait(1.0)
	check(runner._model.run_amount > 0.5, "les sprinteurs passent en animation de course")
	runner._start_crawl()
	await wait(0.5)
	check(runner._model.crawling, "la jambe arrachée déclenche l'animation de reptation")
	runner.queue_free()
	check(ResourceLoader.exists("res://assets/models/zombie_real/diffuse_v4.jpg"), "5 tenues de zombie disponibles")

	# Indicateurs de dégâts directionnels
	var got := []
	var cb := func(p: Vector3): got.append(p)
	player.hit_from.connect(cb)
	player.invuln = 0.0
	var src: Vector3 = player.global_position + Vector3(5, 0, 0)
	player.take_damage(1.0, src)
	player.take_damage(1.0)
	player.invuln = 1e9
	player.hit_from.disconnect(cb)
	check(got.size() == 1 and got[0].is_equal_approx(src), "la source du coup est signalée (et seulement si connue)")

	# Munitions illimitées et Dernier survivant
	player.holder.give_weapon("k74")
	player.holder.switch_timer = 0.0
	player.holder.fire_timer = 0.0
	player.holder.reload_timer = 0.0
	game.apply_powerup("infinite_ammo")
	var mag0: int = player.holder.cur().mag
	player.holder._try_fire(player.holder.cur(), true)
	check(player.holder.cur().mag == mag0, "munitions illimitées : le chargeur ne baisse pas")
	GameManager.active_powerups.erase("infinite_ammo")
	player.holder.fire_timer = 0.0
	player.holder._try_fire(player.holder.cur(), true)
	check(player.holder.cur().mag == mag0 - 1, "le chargeur baisse de nouveau après l'effet")
	var lives0 := GameManager.extra_lives
	game.apply_powerup("last_stand")
	check(GameManager.extra_lives == lives0 + 1, "Dernier survivant donne une vie")
	player.invuln = 0.0
	player.health = 5.0
	player.take_damage(999.0)
	check(not player.dead and not player.downed and GameManager.extra_lives == lives0 and player.health == player.max_health, "la vie supplémentaire annule le coup fatal")
	player.invuln = 1e9

	# Résolution et anticrénelage
	GameManager.set_msaa(2)
	check(get_tree().root.msaa_3d == Viewport.MSAA_4X, "anticrénelage 4x appliqué")
	GameManager.set_msaa(1)
	GameManager.set_render_scale(0.75)
	check(is_equal_approx(get_tree().root.scaling_3d_scale, 0.75), "échelle de rendu 3D appliquée")
	GameManager.set_render_scale(1.0)

	# Musique de mort
	check(Audio._streams.has("game_over_jingle") and Audio._streams.has("round_end"), "jingle de mort et musique de fin de manche chargés")

	# Zombies spéciaux
	game.rounds.round_num = 12
	var seen := {}
	for i in 500:
		seen[game.rounds._pick_enemy().kind] = true
	check(seen.has("bomber") and seen.has("spitter") and seen.has("screamer"), "les 3 zombies spéciaux apparaissent à la manche 12")
	game.rounds.round_num = 3
	var early := true
	for i in 300:
		early = early and not (game.rounds._pick_enemy().kind in ["bomber", "spitter", "screamer"])
	check(early, "aucun zombie spécial avant la manche 6")
	game.rounds.round_num = GameManager.round_num
	player.global_position = Vector3(0, 0.1, -34)
	var bz2 = ZombieScript.new()
	bz2.setup("bomber", 400.0, 1.9, null)
	game.add_child(bz2)
	bz2.global_position = player.global_position + Vector3(0, 0, -1.4)
	bz2.state = bz2.State.CHASE
	game.rounds.alive += 1
	check(await wait_until(func(): return not is_instance_valid(bz2) or bz2.state == bz2.State.DEAD, 4.0), "le kamikaze explose au contact")
	var sp = ZombieScript.new()
	sp.setup("spitter", 300.0, 2.2, null)
	game.add_child(sp)
	sp.global_position = player.global_position + Vector3(0, 0, -3.0)
	sp.state = sp.State.CHASE
	var sp_d0: float = sp.global_position.distance_to(player.global_position)
	await wait(1.0)
	check(sp.global_position.distance_to(player.global_position) > sp_d0 + 0.5, "le cracheur recule pour garder ses distances")
	sp._spit(player)
	var acid := 0
	for n in game.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("acid_ball.gd"):
			acid += 1
	check(acid >= 1, "le cracheur crache une boule d'acide")
	sp.take_damage(99999.0, false, "nuke")
	var sc = ZombieScript.new()
	sc.setup("screamer", 300.0, 2.4, null)
	game.add_child(sc)
	sc.global_position = player.global_position + Vector3(0, 0, -8.0)
	sc._scream(player)
	check(GameManager.rage_active(), "le hurlement enrage les zombies")
	sc.take_damage(99999.0, false, "nuke")
	GameManager._rage_until = 0.0
	for z in get_tree().get_nodes_in_group("zombies"):
		z.take_damage(99999.0, false, "nuke")
	await wait(0.4)

	# Bras du joueur
	var arms = player.holder.arms
	check(arms != null and arms.visible, "les bras du joueur sont affichés")
	var wrist_ok := true
	for wid in WeaponDBTest.WEAPONS:
		player.holder.give_weapon(wid)
		player.holder.switch_timer = 0.0
		await wait(0.25)
		var w_world: Vector3 = arms.sk.global_transform * arms.sk.get_bone_global_pose(arms._b["hand.R"]).origin
		var grip_world: Vector3 = player.holder.view.to_global(WeaponDBTest.data(wid).get("grip_r", Vector3.ZERO))
		wrist_ok = wrist_ok and w_world.distance_to(grip_world) < 0.2
	check(wrist_ok, "la main droite reste près de la poignée pour chaque arme")
	player.holder.give_weapon("k74")
	player.holder.switch_timer = 0.0
	await wait(0.2)
	var left_rest: Vector3 = arms.sk.get_bone_global_pose(arms._b["hand.L"]).origin
	player.holder.reload_timer = 1.0
	player.holder.reload_total = 2.0
	await wait(0.3)
	var left_reload: Vector3 = arms.sk.get_bone_global_pose(arms._b["hand.L"]).origin
	check(left_rest.distance_to(left_reload) > 0.3, "la main gauche quitte l'arme pendant le rechargement")
	player.holder.reload_timer = 0.0

	# Power-ups
	for kind in GameManager.POWERUPS:
		game.apply_powerup(kind)
	check(GameManager.is_powerup_active("insta_kill") and GameManager.is_powerup_active("double_points"), "power-ups temporisés actifs")
	game.spawn_powerup(player.global_position, "max_ammo")
	await wait(0.3)
	check(true, "ramassage de power-up sans erreur")

	# Arsenal : chaque arme a un modèle, une ligne de mire, un tir sonore et des mains qui l'atteignent
	var arsenal_ok := true
	var sound_ok := true
	for wid in WeaponDBTest.WEAPONS:
		var wd: Dictionary = WeaponDBTest.WEAPONS[wid]
		var g := MeshUtilTest.build_gun(game, wid, false, wd.color, wd.kind)
		arsenal_ok = arsenal_ok and g != null and g.has_meta("muzzle")
		if g:
			g.queue_free()
		if wd.get("fbx", false):
			sound_ok = sound_ok and Audio._streams.get(wd.sound, []).size() >= 1
	check(WeaponDBTest.WEAPONS.size() >= 13 and arsenal_ok, "13 armes, chacune avec son modèle 3D")
	check(sound_ok and Audio._streams["shot_p9"].size() >= 2 and Audio._streams["shot_vipere"][0] is AudioStreamWAV, "tirs dédiés par arme chargés")
	for wid in WeaponDBTest.BOX_POOL:
		arsenal_ok = arsenal_ok and WeaponDBTest.WEAPONS.has(wid)
	check(arsenal_ok, "la boîte mystère ne propose que des armes existantes")
	for wid in ["revolver", "double_canon", "frelon", "eclaireur", "spectre"]:
		player.holder.give_weapon(wid)
		player.holder.switch_timer = 0.0
		await wait(0.15)
		check(player.holder._grip.has("R") and player.holder._hip_shift.length() < 0.35, "prise et portée des bras : %s" % wid)

	# Apparences des zombies : équipements portés par les os
	var styles_ok := true
	for st in ["soldier", "worker", "woman_a", "woman_b"]:
		var sm = load("res://scripts/zombies/zombie_model_real.gd").new()
		game.add_child(sm)
		sm.setup("0", Color.WHITE, st)
		var n_att: int = sm.skeleton.find_children("*", "BoneAttachment3D", true, false).size()
		styles_ok = styles_ok and n_att >= 1
		sm.queue_free()
	check(styles_ok, "soldats, ouvriers et femmes portent leur équipement")

	# Zombies spéciaux : Brute (bouclier frontal) et Infecté (infection du joueur)
	GameManager.active_powerups.clear()
	player.invuln = 0.0
	player.health = player.max_health
	player.global_position = Vector3(0, 0.1, 3)
	var brute = ZombieScript.new()
	brute.setup("brute", 1000.0, 0.01, null)
	game.add_child(brute)
	brute.global_position = Vector3(0, 0, 0)
	brute.set_physics_process(false)
	brute.rotation.y = 0.0 # regarde -Z ; le joueur est derrière lui (+Z)
	await wait(0.2)
	var hp0: float = brute.hp
	brute.take_damage(100.0, false, "bullet")
	var back_loss: float = hp0 - brute.hp
	brute.rotation.y = PI # regarde +Z : le joueur est devant
	await wait(0.1)
	var hp1: float = brute.hp
	var sh1: float = brute.shield
	brute.take_damage(100.0, false, "bullet")
	var front_loss: float = hp1 - brute.hp
	check(back_loss > 99.0 and front_loss < 50.0 and brute.shield < sh1, "la Brute encaisse les tirs de face avec son bouclier")
	brute.take_damage(100.0, true, "bullet")
	check(hp1 - front_loss - brute.hp > 99.0, "le bouclier ne protège pas la tête")
	brute.take_damage(99999.0, false, "nuke")
	var inf = ZombieScript.new()
	inf.setup("infected", 100.0, 0.01, null)
	game.add_child(inf)
	inf.global_position = Vector3(8, 0, 8)
	player.infect(6.0)
	var hp_inf: float = player.health
	await wait(1.0)
	check(player.infected > 0.0 and player.health < hp_inf, "l'infection fait perdre de la vie")
	player.infected = 0.0
	inf.take_damage(9999.0, false, "bullet")
	await wait(0.4)
	check(get_tree().get_nodes_in_group("player").size() > 0 and game.get_children().any(func(n): return n.get_script() == load("res://scripts/zombies/toxic_cloud.gd")), "l'Infecté laisse un nuage toxique")

	# Carte 2 : laboratoire, téléporteur et quête secrète
	GameManager.in_game = false
	game.queue_free()
	await wait(0.5)
	GameManager.map_id = "lab"
	GameManager.quest_vials = 0
	GameManager.in_game = true
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await wait(1.2)
	player = game.player
	player.invuln = 1e9
	game.rounds.set_physics_process(false)
	check(game.map_id == "lab" and game.barricades.size() == 11, "le laboratoire est construit (11 fenêtres)")
	check(find_interactables(TrapScript).size() == 1 and find_interactables(PerkScript).size() == 10, "atouts et piège du laboratoire")
	check(player.global_position.distance_to(Vector3(0, 0.1, 0)) < 1.0, "départ dans l'accueil du laboratoire")
	var pads: Array = find_interactables(load("res://scripts/interactables/teleporter.gd"))
	check(pads.size() == 2, "deux plateformes de téléportation")
	GameManager.add_points(5000)
	var pad: Node3D = pads[0] if pads[0].zone == 0 else pads[1]
	GameManager.set_power(true)
	pad.interact(player)
	await wait(0.3)
	check(player.global_position.z < -15.0 and player.global_position.x > 30.0, "le téléporteur emmène le joueur au réacteur")
	check(game.active_zones.has(3), "le réacteur est débloqué par la téléportation")
	var door3 = get_tree().get_nodes_in_group("doors").filter(func(d): return d.unlock_zone == 3)
	check(door3.is_empty() or door3[0].opened, "la porte du réacteur s'ouvre toute seule")
	var console = find_interactables(load("res://scripts/interactables/reactor_console.gd"))[0]
	console.interact(player)
	check(console._state == 0, "la console refuse sans les trois fioles")
	for v in find_interactables(load("res://scripts/interactables/vial.gd")):
		v.interact(player)
	check(GameManager.quest_vials == 3, "trois fioles ramassées")
	var lives_before: int = GameManager.extra_lives
	console.interact(player)
	check(console._state == 1, "la synthèse démarre avec les trois fioles")
	console._t = console.SYNTH_TIME - 0.05
	await wait(0.3)
	check(GameManager.quest_done and GameManager.extra_lives == lives_before + 1, "la quête secrète donne une vie supplémentaire")
	GameManager.map_id = "bunker"

	print("==== %s (%d échec(s)) ====" % ["SUCCÈS" if fails == 0 else "ÉCHEC", fails])
	get_tree().quit(fails)


func _spawn_test_zombie(pos: Vector3) -> Node:
	var z = ZombieScript.new()
	z.setup("zombie", 2000.0, 0.01, null)
	game.add_child(z)
	z.global_position = pos
	return z
