extends RefCounted
## Petits constructeurs de géométrie et de matériaux partagés.

static var _mat_cache := {}


static func mat(color: Color, emission := 0.0, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), emission, roughness, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


static func box_mesh(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func sphere_mesh(parent: Node, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func capsule_mesh(parent: Node, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 10
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cylinder_mesh(parent: Node, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Corps statique en boîte (collision + mesh). Position = centre.
static func static_box(parent: Node, size: Vector3, pos: Vector3, material: Material, layer := 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if material:
		box_mesh(body, size, Vector3.ZERO, material)
	parent.add_child(body)
	return body


static func label3d(parent: Node, text: String, pos: Vector3, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 8
	l.position = pos
	parent.add_child(l)
	return l


const WEAPON_MODEL_DIR := "res://assets/models/weapons/"
static var _overlays := {}


## Camouflage lumineux d'une arme améliorée : violet (niveau 1), doré (niveau 2).
static func overlay_for(tier: int) -> StandardMaterial3D:
	if not _overlays.has(tier):
		var m := StandardMaterial3D.new()
		var base := Color(0.3, 0.04, 0.5) if tier < 2 else Color(0.6, 0.4, 0.02)
		var glow := Color(0.45, 0.1, 0.8) if tier < 2 else Color(1.0, 0.7, 0.1)
		m.albedo_color = Color(base.r, base.g, base.b, 0.3)
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = 0.35 if tier < 2 else 0.5
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_overlays[tier] = m
	return _overlays[tier]
static var _gun_mats := {}


## Modèle d'arme orienté vers -Z (canon), centré, avec la méta "muzzle".
## Utilise le modèle .glb s'il existe, sinon une arme en primitives.
static func build_gun(parent: Node3D, weapon_id: String, upgraded, base_color: Color, kind: String) -> Node3D:
	var d: Dictionary = preload("res://scripts/weapons/weapon_db.gd").data(weapon_id)
	if d.get("fbx", false):
		var fbx := "res://assets/models/guns/" + str(d.model) + ".fbx"
		if ResourceLoader.exists(fbx):
			return _build_fbx_gun(parent, fbx, d.length, upgraded)
	var path := WEAPON_MODEL_DIR + str(d.get("model", "")) + ".glb"
	if d.has("model") and ResourceLoader.exists(path):
		return _build_model_gun(parent, path, d.length, upgraded)
	return _build_primitive_gun(parent, upgraded, base_color, kind)


## Armes réalistes (Quaternius, canon vers +X dans le fichier) : couleurs d'origine, canon tourné vers -Z.
static func _build_fbx_gun(parent: Node3D, path: String, length: float, upgraded) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var model: Node3D = load(path).instantiate()
	root.add_child(model)
	var box := scene_aabb(model)
	var s := length / maxf(box.size.x, 0.01)
	model.scale = Vector3.ONE * s
	model.rotation.y = PI * 0.5
	model.position = -(Basis(Vector3.UP, PI * 0.5) * (box.get_center() * s))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				if not _gun_mats.has(src):
					var dm: StandardMaterial3D = src.duplicate()
					dm.metallic = 0.1
					dm.roughness = 0.8
					_gun_mats[src] = dm
				m3.set_surface_override_material(i, _gun_mats[src])
	if upgraded:
		var ov := overlay_for(int(upgraded))
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = ov
	var half_h := box.size.y * s * 0.5
	root.set_meta("muzzle", Vector3(0, half_h * 0.3, -length * 0.5))
	# ligne de mire : sommet de l'arme (pour caler la visée sur le centre de l'écran)
	root.set_meta("sight_y", (box.end.y - box.get_center().y) * s * 0.85)
	return root


static func _build_model_gun(parent: Node3D, path: String, length: float, upgraded) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var model: Node3D = load(path).instantiate()
	root.add_child(model)
	var box := scene_aabb(model)
	var s := length / maxf(box.size.z, 0.01)
	model.scale = Vector3.ONE * s
	model.position = -box.get_center() * s
	# Teintes plus sombres et métalliques que les couleurs « jouet » d'origine.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				if not _gun_mats.has(src):
					var dm: StandardMaterial3D = src.duplicate()
					if dm.albedo_texture:
						dm.albedo_texture = _desaturated(dm.albedo_texture)
					dm.albedo_color = Color(0.62, 0.62, 0.65)
					dm.metallic = 0.25
					dm.roughness = 0.5
					_gun_mats[src] = dm
				m3.set_surface_override_material(i, _gun_mats[src])
	if upgraded:
		var ov := overlay_for(int(upgraded))
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = ov
	root.set_meta("muzzle", Vector3(0, box.size.y * s * 0.15, -length * 0.5))
	return root


## Version désaturée (acier bruni) d'une texture de couleurs, mise en cache.
static func _desaturated(tex: Texture2D) -> Texture2D:
	if _gun_mats.has(tex):
		return _gun_mats[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			# Un soupçon de la teinte d'origine pour garder des pièces lisibles.
			var g := Color(l * 0.95, l * 0.93, l * 0.9).lerp(c, 0.12)
			img.set_pixel(x, y, Color(g.r, g.g, g.b, c.a))
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	_gun_mats[tex] = out
	return out


## Boîte englobante d'une scène dans l'espace de sa racine (sans être dans l'arbre).
static func scene_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var a: AABB = xf * (mi as MeshInstance3D).get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


static func _build_primitive_gun(parent: Node3D, upgraded, base_color: Color, kind: String) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var col := base_color
	var m := mat(col, 0.0, 0.6, 0.4)
	if upgraded:
		m = mat(Color(0.55, 0.15, 0.85) if int(upgraded) < 2 else Color(0.9, 0.65, 0.1), 1.4, 0.3, 0.8)
	var dark := mat(Color(0.08, 0.08, 0.09), 0.0, 0.5, 0.6)
	var length := 0.45
	var body_h := 0.09
	match kind:
		"pistol":
			length = 0.22
		"smg":
			length = 0.38
		"shotgun":
			length = 0.7
		"lmg":
			length = 0.75
			body_h = 0.14
		"sniper":
			length = 0.85
		"wonder":
			length = 0.4
			body_h = 0.14
	box_mesh(root, Vector3(0.07, body_h, length), Vector3(0, 0, -length * 0.4), m)
	cylinder_mesh(root, 0.018 if kind != "shotgun" else 0.028, length * 0.6, Vector3(0, body_h * 0.2, -length * 0.85), dark, Vector3(PI / 2, 0, 0))
	box_mesh(root, Vector3(0.05, 0.13, 0.06), Vector3(0, -0.1, -0.02), dark, Vector3(0.3, 0, 0))
	if kind in ["rifle", "smg", "lmg"]:
		box_mesh(root, Vector3(0.05, 0.15, 0.05), Vector3(0, -0.11, -length * 0.45), dark)
	if kind in ["rifle", "shotgun", "sniper", "lmg"]:
		box_mesh(root, Vector3(0.06, 0.1, 0.22), Vector3(0, -0.02, 0.14), m)
	if kind == "sniper":
		cylinder_mesh(root, 0.03, 0.25, Vector3(0, 0.09, -0.3), dark, Vector3(PI / 2, 0, 0))
	if kind == "wonder":
		var glow := mat(Color(0.2, 1.0, 0.4), 3.0)
		sphere_mesh(root, 0.05, Vector3(0, 0.1, -0.2), glow)
		cylinder_mesh(root, 0.03, 0.3, Vector3(0, 0, -0.55), glow, Vector3(PI / 2, 0, 0))
	root.set_meta("muzzle", Vector3(0, body_h * 0.2, -length * 1.15))
	return root
