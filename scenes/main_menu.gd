extends Control
## Menu principal : le bunker en 3D en arrière-plan (caméra lente, zombies),
## titre, boutons à gauche et panneau de contenu à droite.

const UI := preload("res://scenes/ui/ui_theme.gd")
const Panels := preload("res://scenes/ui/menu_panels.gd")
const POST_FX := preload("res://shaders/post_fx.gdshader")
const GAME_SCENE := preload("res://scenes/game.tscn")

var _title: Label
var _content: Control
var _fade: ColorRect
var _t := 0.0
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	# Décor 3D
	GameManager.menu_mode = true
	add_child(GAME_SCENE.instantiate())
	GameManager.menu_mode = false

	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	ui.add_child(root)

	var fx := ColorRect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx_mat := ShaderMaterial.new()
	fx_mat.shader = POST_FX
	fx_mat.set_shader_parameter("vignette", 0.75)
	fx.material = fx_mat
	root.add_child(fx)

	# Dégradé sombre à gauche pour la lisibilité
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.92))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.65
	root.add_child(shade)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.anchor_top = 0.0
	left.anchor_bottom = 1.0
	left.offset_left = 80
	left.offset_top = 36
	left.offset_right = 600
	left.offset_bottom = -40
	root.add_child(left)

	_title = UI.label(left, "BUNKER Z", 130, UI.RED, UI.title_font())
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0, 0, 0.9))
	var sub := UI.label(left, "SURVIVEZ.  COMBIEN DE MANCHES ?", 24, Color(0.75, 0.7, 0.62), UI.ui_font())
	sub.add_theme_constant_override("outline_size", 4)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	left.add_child(spacer)

	var play_btn := UI.button(left, "JOUER", _play, 40)
	play_btn.grab_focus.call_deferred()
	UI.button(left, "OPTIONS", func(): _show(Panels.options))
	UI.button(left, "COMMANDES", func(): _show(Panels.controls))
	UI.button(left, "RECORDS", func(): _show(Panels.records))
	UI.button(left, "CRÉDITS", func(): _show(Panels.credits))
	UI.button(left, "QUITTER", func(): get_tree().quit())

	var foot := UI.label(root, "v1.1  —  Godot 4.7", 16, Color(0.5, 0.48, 0.45))
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 82
	foot.offset_top = -40

	_content = CenterContainer.new()
	_content.anchor_left = 0.5
	_content.anchor_right = 1.0
	_content.anchor_bottom = 1.0
	_content.offset_right = -60
	root.add_child(_content)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.5)
	Audio.play_music("menu_music", -4.0)


func _process(delta: float) -> void:
	_t += delta
	# Titre qui grésille comme un néon fatigué
	var flicker := 1.0
	if fmod(_t, 4.0) > 3.7:
		flicker = 0.35 if randf() < 0.5 else 1.0
	_title.modulate = Color(1, 1, 1, flicker)


func _show(builder: Callable) -> void:
	for c in _content.get_children():
		c.queue_free()
	var panel: Control = builder.call(_content)
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)


func _play() -> void:
	if _leaving:
		return
	_leaving = true
	Audio.stop_music(1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	tw.tween_callback(GameManager.new_game)
