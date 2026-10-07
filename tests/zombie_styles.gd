extends Node3D
## Planche d'inspection sur fond clair : variantes, course (4 phases), reptation (4 phases).
var cam: Camera3D

func _ready():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.32, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation = Vector3(-0.8, -0.6, 0); add_child(l)
	var floor_mesh := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 20); floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.15, 0.15, 0.17); floor_mesh.material_override = fm; add_child(floor_mesh)
	cam = Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 22
	var out := OS.get_cmdline_user_args()[0]
	# 1. variantes de face
	var zs := []
	for i in 5:
		var z = _zombie(1.3, Vector3(-4.0 + i * 2.0, 0, 0), i)
		z.rotation.y = PI  # face à la caméra (+Z)
		zs.append(z)
	cam.look_at_from_position(Vector3(0, 1.1, 16.0), Vector3(0, 0.95, 0))
	await _frames(zs, 10)
	await _shot(out + "/styles_1.png")
	for z in zs: z.queue_free()
	# 2. course vue de côté, 4 phases côte à côte
	var runs := []
	for i in 4:
		var z = _zombie(4.6, Vector3(-4.5 + i * 3.0, 0, 0), i)
		z.rotation.y = -PI * 0.5   # regarde vers +X
		runs.append(z)
	cam.look_at_from_position(Vector3(0, 1.1, 16.0), Vector3(0, 0.95, 0))
	for k in 4:
		runs[k].velocity = Vector3(4.6, 0, 0)
		for t in 8 + k * 6:
			runs[k]._animate(0.02, true)
	await get_tree().process_frame
	await _shot(out + "/styles_2.png")
	for z in runs: z.queue_free()
	# 3. reptation
	var crs := []
	for i in 4:
		var z = _zombie(1.3, Vector3(-4.5 + i * 3.0, 0, 0), i)
		z.rotation.y = -PI * 0.5
		z._start_crawl()
		crs.append(z)
	cam.look_at_from_position(Vector3(0, 0.9, 16.0), Vector3(0, 0.55, 0))
	for k in 4:
		crs[k].velocity = Vector3(1.0, 0, 0)
		for t in 40 + k * 12:
			crs[k]._animate(0.02, true)
	await get_tree().process_frame
	await _shot(out + "/styles_3.png")
	get_tree().quit()

func _zombie(speed: float, pos: Vector3, variant: int) -> Node:
	var z = load("res://scripts/zombies/zombie.gd").new()
	z.setup("zombie", 9000.0, speed, null)
	add_child(z)
	z.set_physics_process(false)
	z.global_position = pos
	z._model.setup if false else null
	return z

func _frames(zs: Array, n: int):
	for t in n:
		for z in zs: z._animate(0.05, true)
		await get_tree().process_frame

func _shot(path: String):
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
