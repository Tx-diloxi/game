extends Node3D
## Banc d'essai des bras FPS : vue subjective avec différentes armes.
const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const WeaponDB := preload("res://scripts/weapons/weapon_db.gd")
const FpsArms := preload("res://scripts/player/fps_arms.gd")

func _ready():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.27, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation = Vector3(-0.7, -0.4, 0); add_child(l)
	var cam := Camera3D.new(); cam.fov = 75.0; cam.near = 0.03; cam.current = true; add_child(cam)
	var arms: Node3D = FpsArms.new(); cam.add_child(arms)
	var out := OS.get_cmdline_user_args()[0]
	var ids := ["p9", "vipere", "carabine", "brise_porte"]
	if OS.get_cmdline_user_args().size() > 1:
		ids = OS.get_cmdline_user_args()[1].split(",")
	var i := 0
	for id in ids:
		var d := WeaponDB.data(id)
		var view := MeshUtil.build_gun(cam, id, false, d.color, d.kind)
		view.position = Vector3(0.21, -0.2, -0.56)
		var grip := FpsArms.grip_for(d)
		await get_tree().process_frame
		await get_tree().process_frame
		arms.update_for_gun(view, grip)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/arms_%d.png" % i)
		var cam2 := Camera3D.new(); cam2.fov = 50.0; add_child(cam2)
		cam2.look_at_from_position(Vector3(0.75, -0.05, -0.15), Vector3(0.1, -0.3, -0.45))
		cam2.current = true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/arms_%d_side.png" % i)
		cam.current = true
		cam2.queue_free()
		view.queue_free()
		i += 1
	get_tree().quit()
