extends Node
func _ready():
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	game.rounds.set_physics_process(false)
	var p = game.player
	p.invuln = 1e9
	p.set_physics_process(false)
	p.global_position = Vector3(0, 0, 4)
	p.rotation.y = 0.0
	p.head.rotation.x = 0.05
	var b = load("res://scripts/zombies/zombie.gd").new()
	b.setup("boss", 9000.0, 2.1, null)
	game.add_child(b)
	b.global_position = Vector3(0.6, 0, -1.5)
	b.rotation.y = PI
	b.set_physics_process(false)
	game.hud.track_boss(b)
	var m = load("res://scripts/weapons/monkey.gd").new()
	game.add_child(m)
	m.global_position = Vector3(-2.2, 0.0, 0.5)
	await get_tree().create_timer(0.6).timeout
	for i in 20:
		b._animate(0.03, true)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/boss.png")
	get_tree().quit()
