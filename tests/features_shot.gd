extends Node
## Captures : piège électrique actif, zombie rampant, zombie sans bras, piège à feu.
func _ready():
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	game.rounds.set_physics_process(false)
	var p = game.player
	p.invuln = 1e9
	p.set_physics_process(false)
	GameManager.points = 100000
	GameManager.set_power(true)
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get_script().resource_path.ends_with("door.gd"):
			n.interact(p)
	await get_tree().create_timer(1.5).timeout
	# Couloir : rampant + manchot devant le piège électrique
	p.global_position = Vector3(0, 0, -15)
	p.rotation.y = 0.0
	p.head.rotation.x = -0.2
	var a = _z(game, Vector3(-1.0, 0, -18.2))
	var b = _z(game, Vector3(1.0, 0, -17.6))
	await get_tree().create_timer(0.3).timeout
	a.on_limb_hit(a._model.bone_pos("Bip01 L Calf"), 5000)
	b.on_limb_hit(b._model.bone_pos("Bip01 R Forearm"), 5000)
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get_script().resource_path.ends_with("trap.gd"):
			n.interact(p)
	for i in 30:
		for z in [a, b]:
			if is_instance_valid(z):
				z._animate(0.03, true)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/feat_1.png")
	p.global_position = Vector3(-6.5, 0, -40)
	p.rotation.y = PI * 0.5
	p.head.rotation.x = -0.15
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/feat_2.png")
	get_tree().quit()

func _z(game, pos):
	var z = load("res://scripts/zombies/zombie.gd").new()
	z.setup("zombie", 9000.0, 0.0, null)
	game.add_child(z)
	z.global_position = pos
	z.set_physics_process(false)
	return z
