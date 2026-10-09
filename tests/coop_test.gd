extends Node
## Test de la coop en ligne : l'hôte lance un invité (second processus Godot) sur 127.0.0.1.
## Lancement : Godot_..._console.exe --headless --path . res://tests/coop_test.tscn
## (l'invité est lancé automatiquement avec les arguments « -- client <port> <fichier_résultat> »).

const PORT := 17777

var fails := 0
var lines: Array[String] = []


func check(cond: bool, label: String) -> void:
	lines.append(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		fails += 1


func wait_until(cond: Callable, timeout := 15.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "client":
		await run_client(int(args[1]), args[2])
	else:
		await run_host()


func start_game() -> Node:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(1.2).timeout
	game.rounds.set_physics_process(false)
	game.player.invuln = 1e9
	return game


func run_host() -> void:
	var result_file := ProjectSettings.globalize_path("user://coop_client_result.txt")
	if FileAccess.file_exists(result_file):
		DirAccess.remove_absolute(result_file)
	Net.my_name = "Hote"
	check(Net.host(PORT) == OK, "l'hôte ouvre le port")
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/coop_test.tscn", "--", "client", str(PORT), result_file])
	check(pid > 0, "l'invité est lancé")
	check(await wait_until(func(): return Net.players.size() == 2), "l'invité apparaît dans la liste des joueurs")
	check(Net.players.values().has("Invite"), "le pseudo de l'invité est transmis")
	var started := [false]
	Net.game_starting.connect(func(_m): started[0] = true)
	Net.start_game("bunker")
	check(await wait_until(func(): return started[0], 5.0), "l'hôte reçoit le signal de départ")
	var game := await start_game()
	var coop: Node = game.get_children().filter(func(n): return n.get_script() != null and str(n.get_script().resource_path).ends_with("coop.gd")).front()
	check(await wait_until(func(): return coop.remotes.size() == 1), "l'avatar de l'invité est créé")
	game.player.global_position = Vector3(-2, 0.1, 2)
	# L'invité se déplace en (3, 0, -2) : l'avatar doit le suivre
	var remote: Node3D = coop.remotes.values()[0]
	check(await wait_until(func(): return remote.global_position.distance_to(Vector3(3, 0.1, -2)) < 0.6), "l'avatar de l'invité suit sa position")
	check(remote.weapon_id == "p9", "l'arme de l'invité est visible (%s)" % remote.weapon_id)
	check(remote.player_name == "Invite", "le nom s'affiche au-dessus de l'avatar")
	# Zombie partagé : l'hôte le simule, il attaque l'avatar de l'invité, l'invité le tue
	var z: CharacterBody3D = load("res://scripts/zombies/zombie.gd").new()
	z.setup("zombie", 1000.0, 1.3, null)
	Net.register_zombie(z, Vector3(5, 0.1, -2))
	game.add_child(z)
	z.global_position = Vector3(5, 0.1, -2)
	check(await wait_until(func(): return z.state == z.State.DEAD, 20.0), "le zombie de l'hôte meurt sous les coups de l'invité")
	check(not is_instance_valid(z) or z.attacker_id == 0, "l'auteur du coup est remis à zéro")
	# Monde partagé : barricade, courant, porte, boîte, power-up (actions de l'invité, effets chez l'hôte)
	var bar = game.barricades[0]
	var box_start: Vector3 = game.box.global_position
	bar.remove_board()
	check(await wait_until(func(): return bar.boards == 6, 15.0), "la barricade est réparée par l'invité")
	check(await wait_until(func(): return GameManager.power_on, 15.0), "le courant est rétabli par l'invité")
	check(await wait_until(func(): return not is_instance_valid(game.doors[0]) or game.doors[0].opened, 15.0), "la porte payée par l'invité s'ouvre chez l'hôte")
	game.relocate_box(game.box)
	check(await wait_until(func(): return game.box.global_position.distance_to(box_start) > 1.0, 5.0), "l'hôte déplace la boîte")
	var box_mid: Vector3 = game.box.global_position
	check(await wait_until(func(): return game.box.global_position.distance_to(box_mid) > 1.0, 15.0), "l'invité déclenche aussi un déménagement de la boîte")
	game.spawn_powerup(Vector3(0, 0, 0), "bonus_points")
	var has_bonus := func(): return game.powerups.values().any(func(pu): return is_instance_valid(pu) and pu.kind == "bonus_points")
	check(has_bonus.call(), "l'hôte lâche un power-up")
	check(await wait_until(func(): return not has_bonus.call(), 15.0), "le power-up ramassé par l'invité disparaît chez l'hôte")
	# Fin : attendre le verdict de l'invité
	check(await wait_until(func(): return FileAccess.file_exists(result_file), 20.0), "l'invité a terminé son test")
	if FileAccess.file_exists(result_file):
		var txt := FileAccess.get_file_as_string(result_file)
		for l in txt.split("\n"):
			if l.strip_edges() != "":
				lines.append("[invité] " + l)
		if "FAIL" in txt:
			fails += 1
		for l in txt.split("\n"):
			if l.begins_with("BOX "):
				var xz := l.substr(4).split(" ")
				var p := Vector3(float(xz[0]), 0.0, float(xz[1]))
				check(Vector2(game.box.global_position.x, game.box.global_position.z).distance_to(Vector2(p.x, p.z)) < 0.1, "la boîte est au même endroit chez l'hôte et chez l'invité")
	print("\n".join(lines))
	print("==== %s (%d échec(s)) ====" % ["SUCCÈS" if fails == 0 else "ÉCHEC", fails])
	Net.leave()
	get_tree().quit(fails)


func run_client(port: int, result_file: String) -> void:
	Net.my_name = "Invite"
	check(Net.join("127.0.0.1", port) == OK, "l'invité se connecte")
	var started := [false]
	Net.game_starting.connect(func(_m): started[0] = true)
	check(await wait_until(func(): return Net.players.size() == 2), "l'invité reçoit la liste des joueurs")
	check(await wait_until(func(): return started[0]), "l'invité reçoit le départ de la partie")
	var game := await start_game()
	var coop: Node = game.get_children().filter(func(n): return n.get_script() != null and str(n.get_script().resource_path).ends_with("coop.gd")).front()
	check(await wait_until(func(): return coop.remotes.size() == 1), "l'avatar de l'hôte est créé")
	game.player.global_position = Vector3(3, 0.1, -2)
	game.player.invuln = 0.0
	var remote: Node3D = coop.remotes.values()[0]
	check(await wait_until(func(): return remote.global_position.distance_to(Vector3(-2, 0.1, 2)) < 0.6), "l'avatar de l'hôte suit sa position")
	check(remote.player_name == "Hote", "le nom de l'hôte s'affiche")
	# Le zombie de l'hôte apparaît chez l'invité (marionnette) et attaque son joueur
	check(await wait_until(func(): return Net.zombies.size() == 1), "le zombie de l'hôte apparaît chez l'invité")
	var pz: Node = Net.zombies.values()[0] if Net.zombies.size() > 0 else null
	check(pz != null and pz.puppet, "c'est une marionnette (pas d'IA locale)")
	check(await wait_until(func(): return game.player.health < game.player.max_health, 15.0), "le zombie de l'hôte blesse le joueur de l'invité")
	check(pz != null and pz.global_position.distance_to(Vector3(3, 0.1, -2)) < 4.0, "la marionnette est proche de sa cible")
	var pts0 := GameManager.points
	game.player.invuln = 1e9
	if pz != null:
		pz.take_damage(1e9, false, "bullet")
		check(await wait_until(func(): return pz.state == pz.State.DEAD, 8.0), "le zombie meurt aussi chez l'invité")
		check(await wait_until(func(): return GameManager.points > pts0, 8.0), "l'invité reçoit les points du kill (%d)" % (GameManager.points - pts0))
	# Monde partagé
	var box_start: Vector3 = game.box.global_position
	check(await wait_until(func(): return game.barricades[0].boards == 5, 15.0), "la planche arrachée par l'hôte disparaît chez l'invité")
	var pts1 := GameManager.points
	Net.act("repair", 0)
	check(await wait_until(func(): return game.barricades[0].boards == 6 and GameManager.points == pts1 + 10, 15.0), "l'invité répare la barricade et gagne 10 points")
	get_tree().get_first_node_in_group("power_switch").interact(game.player)
	check(await wait_until(func(): return GameManager.power_on, 15.0), "le courant s'allume chez l'invité")
	GameManager.points = 5000
	game.doors[0].interact(game.player)
	check(await wait_until(func(): return not is_instance_valid(game.doors[0]) or game.doors[0].opened, 15.0), "la porte s'ouvre chez l'invité")
	check(GameManager.points == 5000 - 750, "la porte est payée par l'invité seul")
	check(await wait_until(func(): return game.box.global_position.distance_to(box_start) > 1.0, 15.0), "la boîte déménage chez l'invité (choix de l'hôte)")
	var box_mid: Vector3 = game.box.global_position
	game.relocate_box(game.box)
	check(await wait_until(func(): return game.box.global_position.distance_to(box_mid) > 1.0, 15.0), "le déménagement demandé par l'invité est exécuté")
	var has_bonus := func(): return game.powerups.values().any(func(pu): return is_instance_valid(pu) and pu.kind == "bonus_points")
	check(await wait_until(has_bonus, 15.0), "le power-up de l'hôte apparaît chez l'invité")
	var pts2 := GameManager.points
	var bonus_id: int = game.powerups.keys().filter(func(k): return game.powerups[k].kind == "bonus_points")[0]
	Net.act("pu_take", bonus_id)
	check(await wait_until(func(): return not has_bonus.call(), 15.0), "le power-up est ramassé chez l'invité")
	check(await wait_until(func(): return GameManager.points > pts2, 15.0), "l'invité reçoit l'effet du power-up")
	await get_tree().create_timer(1.0).timeout
	var f := FileAccess.open(result_file, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\nBOX %f %f\n" % [game.box.global_position.x, game.box.global_position.z] + ("FAIL\n" if fails > 0 else ""))
	f.close()
	await get_tree().create_timer(1.5).timeout
	Net.leave()
	get_tree().quit(fails)
