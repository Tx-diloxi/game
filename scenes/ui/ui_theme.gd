extends RefCounted
## Thème visuel commun : polices système Windows (repli sur la police Godot), boutons, curseurs.

const RED := Color(0.78, 0.06, 0.04)
const RED_DARK := Color(0.35, 0.02, 0.02)
const BONE := Color(0.92, 0.88, 0.8)
const GREY := Color(0.6, 0.58, 0.55)

static var _theme: Theme
static var _fonts := {}


static func _sys(key: String, names: PackedStringArray, weight := 400, italic := false) -> SystemFont:
	if _fonts.has(key):
		return _fonts[key]
	var f := SystemFont.new()
	f.font_names = names
	f.font_weight = weight
	f.font_italic = italic
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.allow_system_fallback = true
	_fonts[key] = f
	return f


## Gros titres (manches, menu) : Impact.
static func title_font() -> Font:
	return _sys("title", PackedStringArray(["Impact", "Haettenschweiler", "Arial Black", "Bahnschrift"]))


## Texte d'interface : Bahnschrift (DIN), condensé et lisible.
static func ui_font() -> Font:
	return _sys("ui", PackedStringArray(["Bahnschrift SemiBold", "Bahnschrift", "Segoe UI", "Arial"]), 600)


static func ui_light_font() -> Font:
	return _sys("ui_light", PackedStringArray(["Bahnschrift Light", "Bahnschrift", "Segoe UI", "Arial"]), 300)


## Pochoir pour les inscriptions sur les murs.
static func stencil_font() -> Font:
	return _sys("stencil", PackedStringArray(["Stencil", "Impact", "Arial Black"]))


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 22

	t.set_color("font_color", "Label", BONE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 4)

	# Boutons façon menu de jeu : texte à gauche, barre rouge au survol.
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.0)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(RED.r, RED.g, RED.b, 0.28)
	hover.border_width_left = 5
	hover.border_color = RED
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(RED.r, RED.g, RED.b, 0.5)
	var focus := StyleBoxEmpty.new()
	for s in ["normal", "disabled"]:
		t.set_stylebox(s, "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.78, 0.75, 0.7))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", 34)
	t.set_constant("outline_size", "Button", 0)

	# Curseurs
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = RED
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _circle_texture(18, BONE)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(20, Color.WHITE))

	# Cases à cocher
	t.set_color("font_color", "CheckButton", Color(0.78, 0.75, 0.7))
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)

	# Panneaux
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.03, 0.025, 0.025, 0.82)
	panel.border_width_left = 3
	panel.border_color = RED_DARK
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 22
	panel.content_margin_bottom = 22
	t.set_stylebox("panel", "PanelContainer", panel)
	_theme = t
	return t


static func _circle_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			img.set_pixel(x, y, Color(color.r, color.g, color.b, clampf(c - d + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func label(parent: Node, text: String, size: int, color := BONE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, callback: Callable, size := 34) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 0)
	b.add_theme_font_size_override("font_size", size)
	b.mouse_entered.connect(func(): Audio.play("ui_hover", -10.0))
	b.pressed.connect(func(): Audio.play("ui_click", -6.0))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


static func slider(parent: Node, title: String, min_v: float, max_v: float, step: float, value: float, callback: Callable, fmt := "%.2f") -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var l := label(row, title, 22, GREY)
	l.custom_minimum_size = Vector2(210, 0)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(200, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := label(row, fmt % value, 22, BONE)
	v.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(x: float): v.text = fmt % x)
	s.value_changed.connect(callback)
	return s
