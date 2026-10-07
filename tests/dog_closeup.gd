extends Node
## Plan rapproché sur les chiens (vivants puis morts).
func _ready():
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	game.rounds.set_physics_process(false)
	var p = game.player
	p.invuln = 1e9
	p.set_physics_process(false)
	p.global_position = Vector3(0, 0, 0)
	p.rotation.y = 0.0
	p.head.rotation.x = -0.15
	var dogs := []
	for i in 3:
		var z = load("res://scripts/zombies/zombie.gd").new()
		z.setup("dog", 500.0, 6.0, null)
		game.add_child(z)
		z.set_physics_process(false)
		z.global_position = Vector3(-1.8 + i * 1.8, 0, -3.5 - i * 0.5)
		z.rotation.y = [0.6, 0.0, -0.9][i]
		dogs.append(z)
	await get_tree().create_timer(0.3).timeout
	dogs[1]._model.attack()
	for t in 8:
		for d in dogs:
			d._model.update_pose(0.04, d != dogs[1], 1.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/dog_1.png")
	for d in dogs:
		d.set_physics_process(true)
	dogs[0].take_damage(9999, false, "bullet")
	dogs[2].take_damage(9999, true, "bullet")
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/dog_2.png")
	get_tree().quit()
