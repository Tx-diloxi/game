extends Node
## Les trois zombies spéciaux devant le joueur, plus une boule d'acide en vol.
func _ready():
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.rounds.set_physics_process(false)
	var p = game.player
	p.invuln = 1e9
	p.set_physics_process(false)
	p.global_position = Vector3(0, 0, 4.5)
	p.rotation.y = 0.0
	p.head.rotation.x = -0.03
	var kinds := ["bomber", "zombie", "spitter", "screamer"]
	for i in kinds.size():
		var z = load("res://scripts/zombies/zombie.gd").new()
		z.setup(kinds[i], 9000.0, 1.5, null)
		game.add_child(z)
		z.global_position = Vector3(-3.6 + i * 2.4, 0, 0.5)
		z.rotation.y = 0.0
		z.set_physics_process(false)
	var ball = load("res://scripts/zombies/acid_ball.gd").new()
	game.add_child(ball)
	ball.global_position = Vector3(1.2, 1.6, 2.0)
	ball.set_physics_process(false)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/specials.png")
	get_tree().quit()
