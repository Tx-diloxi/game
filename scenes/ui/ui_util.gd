extends RefCounted
## Construction rapide d'éléments d'interface.

const RED := Color(0.75, 0.05, 0.03)


static func label(parent: Node, text: String, font_size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 54)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


static func slider(parent: Node, title: String, min_v: float, max_v: float, step: float, value: float, callback: Callable) -> HSlider:
	label(parent, title, 20, Color(0.8, 0.8, 0.8))
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(320, 28)
	s.value_changed.connect(callback)
	parent.add_child(s)
	return s


## Fond plein écran + colonne centrée.
static func centered_column(parent: Node, bg: Color) -> VBoxContainer:
	var rect := ColorRect.new()
	rect.color = bg
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	return col
