extends Node
## Vue en jeu avec les bras : pistolet au repos, k74, k74 en rechargement, désintégrateur amélioré.
func _ready():
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.rounds.set_physics_process(false)
	var p = game.player
	p.invuln = 1e9
	p.global_position = Vector3(0, 0, 3)
	var out := OS.get_cmdline_user_args()[0]
	var shots := [["p9", false, false], ["k74", false, false], ["k74", false, true], ["longue_vue", true, false]]
	var i := 0
	for s in shots:
		p.holder.give_weapon(s[0], s[1])
		p.holder.switch_timer = 0.0
		p.holder.reload_timer = 0.0
		await get_tree().create_timer(0.7).timeout
		if s[2]:
			p.holder.reload_timer = 0.9
			p.holder.reload_total = 1.8
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/game_arms_%d.png" % i)
		i += 1
	get_tree().quit()
