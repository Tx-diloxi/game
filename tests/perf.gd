extends Node
## Mesure des performances : 24 zombies en poursuite dans la salle de départ.
func _ready():
	GameManager.vsync = false
	GameManager.max_fps_index = 0
	GameManager.apply_video()
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(1.0).timeout
	game.rounds.set_physics_process(false)
	var p = game.player
	p.invuln = 1e9
	p.global_position = Vector3(0, 0, 0)
	var n := int(OS.get_cmdline_user_args()[0])
	var flags: Array = OS.get_cmdline_user_args().slice(1)
	if "noarms" in flags:
		p.holder.arms.queue_free()
		p.holder.arms = null
	if "nohud" in flags:
		game.hud.visible = false
		game.hud.set_process(false)
	if "noshadow" in flags:
		GameManager.set_shadow_quality(0)
	if "nolights" in flags:
		for l in game.find_children("*", "OmniLight3D", true, false):
			l.visible = false
	if "nopost" in flags:
		game.hud._fx.visible = false
	GameManager.set_shadow_quality(2)
	for f in flags:
		if f.begins_with("sq"):
			GameManager.set_shadow_quality(int(f.substr(2)))
	if "noglow" in flags:
		game.env.glow_enabled = false
	if "noadj" in flags:
		game.env.adjustment_enabled = false
	if "nofog" in flags:
		game.env.fog_enabled = false
	if "notone" in flags:
		game.env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if "msaa0" in flags:
		GameManager.set_msaa(0)
	if "scale" in flags:
		GameManager.set_render_scale(0.7)
	if "noview" in flags:
		p.holder.view.visible = false
	for i in n:
		var z = load("res://scripts/zombies/zombie.gd").new()
		z.setup("zombie", 100000.0, 2.2, null)
		game.add_child(z)
		z.global_position = Vector3(-8 + (i % 8) * 2.2, 0, -8 + (i / 8) * 2.0)
	if "nophys" in flags:
		for z in get_tree().get_nodes_in_group("zombies"):
			z.set_physics_process(false)
	if "novis" in flags:
		for z in get_tree().get_nodes_in_group("zombies"):
			z.visual.visible = false
	await get_tree().create_timer(3.0).timeout
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var sum_proc := 0.0
	var sum_phys := 0.0
	var max_dt := 0.0
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
		frames += 1
		var now := Time.get_ticks_usec()
		max_dt = maxf(max_dt, (now - last) / 1000.0)
		last = now
		sum_proc += Performance.get_monitor(Performance.TIME_PROCESS)
		sum_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("PERF n=%d fps=%.1f frame_ms=%.1f max_ms=%.1f process_ms=%.2f physics_ms=%.2f draws=%d objects=%d prims=%d" % [
		n, frames / secs, 1000.0 * secs / frames, max_dt, sum_proc / frames * 1000.0, sum_phys / frames * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()
