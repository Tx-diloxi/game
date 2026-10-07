extends Node
## Captures d'écran (avec rendu) pour vérification visuelle.
## Lancer : Godot.exe --path . res://tests/screenshot.tscn -- <dossier_sortie>

var out_dir := "user://screens"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)

	# 1. Menu principal
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(2.5).timeout
	await _shot("1_menu.png")
	menu._show(preload("res://scenes/ui/menu_panels.gd").options)
	await get_tree().create_timer(0.5).timeout
	await _shot("2_menu_options.png")
	menu.queue_free()
	await get_tree().process_frame

	# 2. Jeu
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	var p: Node3D = game.player
	p.invuln = 1e9
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(1.0).timeout
	p.rotation.y = PI * 0.25
	await _shot("3_depart.png")
	Engine.time_scale = 4.0
	await get_tree().create_timer(28.0).timeout
	Engine.time_scale = 1.0
	var zs := get_tree().get_nodes_in_group("zombies")
	if zs.size() > 0:
		var z: Node3D = zs[0]
		var front := z.global_position - z.global_basis.z * 2.4
		p.global_position = Vector3(front.x, z.global_position.y, front.z)
		p.look_at(Vector3(z.global_position.x, p.global_position.y, z.global_position.z))
		p.head.rotation.x = 0.05
		await get_tree().create_timer(0.15).timeout
		p.holder._try_fire(p.holder.cur(), true)
		await get_tree().create_timer(0.05).timeout
	await _shot("4_zombie.png")
	GameManager.points = 100000
	for n in get_tree().get_nodes_in_group("interactable"):
		var path: String = n.get_script().resource_path
		if path.ends_with("door.gd"):
			n.interact(p)
	await get_tree().create_timer(1.5).timeout
	p.global_position = Vector3(0, 0.1, -31.5)
	p.rotation.y = 0.0
	p.head.rotation.x = -0.05
	await get_tree().create_timer(0.3).timeout
	await _shot("5_salle_sans_courant.png")
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get_script().resource_path.ends_with("power_switch.gd"):
			n.interact(p)
	await get_tree().create_timer(2.0).timeout
	await _shot("6_salle_courant.png")
	p.global_position = Vector3(0, 0.1, -16)
	p.rotation.y = 0.0
	p.holder.give_weapon("k74", true)
	await get_tree().create_timer(0.8).timeout
	await _shot("7_couloir.png")
	GameManager.game_over()
	await get_tree().create_timer(3.5).timeout
	await _shot("8_fin.png")
	get_tree().paused = false
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/" + name)
	print("saved ", name)
