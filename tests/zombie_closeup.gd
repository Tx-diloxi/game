extends Node
## Plan rapproché sur des zombies réalistes dans la salle de départ.
func _ready():
	GameManager.menu_mode = false
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	game.rounds.set_physics_process(false)
	var p = game.player
	p.invuln = 1e9
	p.set_physics_process(false)
	p.global_position = Vector3(0, 0, 0)
	p.rotation.y = 0.0
	p.head.rotation.x = -0.05
	var zs := []
	for i in 3:
		var z = load("res://scripts/zombies/zombie.gd").new()
		z.setup("zombie" if i < 2 else "tank", 500.0, 1.4, null)
		game.add_child(z)
		z.global_position = Vector3(-1.6 + i * 1.8, 0, -3.2 - i * 0.6)
		z.rotation.y = PI * 0.0
		zs.append(z)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/real_1.png")
	zs[0].take_damage(9999, true, "bullet")
	zs[1].take_damage(9999, false, "bullet")
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/real_2.png")
	get_tree().quit()
