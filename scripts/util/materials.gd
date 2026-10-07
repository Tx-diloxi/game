extends RefCounted
## Matériaux texturés (textures ambientCG CC0) en projection triplanaire monde :
## pas besoin d'UV, les textures se raccordent d'un bloc à l'autre.

const TEX_DIR := "res://assets/textures/"

static var _cache := {}


## name : dossier de texture (concrete, bricks, planks, metal, ground, paintedplaster)
## tile : taille en mètres d'une répétition de la texture.
static func textured(name: String, tint := Color.WHITE, tile := 2.0, metallic := 0.0, world := true) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [name, tint.to_html(), tile, metallic, world]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var dir := TEX_DIR + name + "/"
	if ResourceLoader.exists(dir + "color.jpg"):
		m.albedo_texture = load(dir + "color.jpg")
		if ResourceLoader.exists(dir + "normal.jpg"):
			m.normal_enabled = true
			m.normal_texture = load(dir + "normal.jpg")
			m.normal_scale = 1.0
		if ResourceLoader.exists(dir + "roughness.jpg"):
			m.roughness_texture = load(dir + "roughness.jpg")
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		if ResourceLoader.exists(dir + "ao.jpg"):
			m.ao_enabled = true
			m.ao_texture = load(dir + "ao.jpg")
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.uv1_triplanar = true
		m.uv1_world_triplanar = world
		m.uv1_scale = Vector3.ONE / tile
		m.uv1_triplanar_sharpness = 4.0
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.albedo_color = tint
	m.metallic = metallic
	m.roughness = 1.0
	_cache[key] = m
	return m


# Palette de la carte
static func floor_concrete() -> StandardMaterial3D:
	return textured("concrete", Color(0.46, 0.44, 0.42), 3.0)


static func ceiling() -> StandardMaterial3D:
	return textured("concrete", Color(0.32, 0.31, 0.3), 3.0)


static func plaster() -> StandardMaterial3D:
	return textured("paintedplaster", Color(0.55, 0.6, 0.52), 2.5)


static func bricks() -> StandardMaterial3D:
	return textured("bricks", Color(0.72, 0.62, 0.55), 2.2)


static func dark_bricks() -> StandardMaterial3D:
	return textured("bricks", Color(0.35, 0.32, 0.32), 2.2)


static func concrete_wall() -> StandardMaterial3D:
	return textured("concrete", Color(0.5, 0.49, 0.47), 2.5)


static func wood() -> StandardMaterial3D:
	return textured("planks", Color(0.75, 0.62, 0.5), 1.5)


static func dark_wood() -> StandardMaterial3D:
	return textured("planks", Color(0.42, 0.32, 0.25), 1.5)


static func metal(tint := Color(0.6, 0.6, 0.62)) -> StandardMaterial3D:
	return textured("metal", tint, 1.2, 0.75)


static func rust() -> StandardMaterial3D:
	return textured("metal", Color(0.55, 0.33, 0.22), 1.0, 0.4)


static func ground() -> StandardMaterial3D:
	return textured("ground", Color(0.55, 0.5, 0.45), 3.0)
