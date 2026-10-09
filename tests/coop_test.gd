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
	# Fin : attendre le verdict de l'invité
	check(await wait_until(func(): return FileAccess.file_exists(result_file), 20.0), "l'invité a terminé son test")
	if FileAccess.file_exists(result_file):
		var txt := FileAccess.get_file_as_string(result_file)
		for l in txt.split("\n"):
			if l.strip_edges() != "":
				lines.append("[invité] " + l)
		if "FAIL" in txt:
			fails += 1
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
	var remote: Node3D = coop.remotes.values()[0]
	check(await wait_until(func(): return remote.global_position.distance_to(Vector3(-2, 0.1, 2)) < 0.6), "l'avatar de l'hôte suit sa position")
	check(remote.player_name == "Hote", "le nom de l'hôte s'affiche")
	await get_tree().create_timer(1.0).timeout
	var f := FileAccess.open(result_file, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n" + ("FAIL\n" if fails > 0 else ""))
	f.close()
	await get_tree().create_timer(1.5).timeout
	Net.leave()
	get_tree().quit(fails)
