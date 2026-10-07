extends CanvasLayer
## Menu pause (Échap) : reprendre, options, commandes, menu principal, quitter.

const UI := preload("res://scenes/ui/ui_theme.gd")
const Panels := preload("res://scenes/ui/menu_panels.gd")

var _panel: Control
var _content: Control
var _resume_btn: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.theme = UI.theme()
	add_child(_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.0, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.anchor_bottom = 1.0
	left.offset_left = 80
	left.offset_top = 90
	left.offset_right = 560
	_panel.add_child(left)
	UI.label(left, "PAUSE", 110, UI.RED, UI.title_font())
	var info := UI.label(left, "", 22, UI.GREY)
	info.name = "Info"
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	left.add_child(spacer)
	_resume_btn = UI.button(left, "REPRENDRE", _resume, 42)
	UI.button(left, "OPTIONS", func(): _show(Panels.options))
	UI.button(left, "COMMANDES", func(): _show(Panels.controls))
	UI.button(left, "MENU PRINCIPAL", GameManager.to_menu)
	UI.button(left, "QUITTER LE JEU", func(): get_tree().quit())

	_content = CenterContainer.new()
	_content.anchor_left = 0.45
	_content.anchor_right = 1.0
	_content.anchor_bottom = 1.0
	_content.offset_right = -60
	_panel.add_child(_content)
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameManager.in_game:
		if _panel.visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _show(builder: Callable) -> void:
	for c in _content.get_children():
		c.queue_free()
	builder.call(_content)


func _pause() -> void:
	_panel.visible = true
	(_panel.find_child("Info", true, false) as Label).text = "Manche %d   ·   %d éliminations   ·   %d points" % [
		GameManager.round_num, GameManager.kills, GameManager.points]
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume_btn.grab_focus()


func _resume() -> void:
	for c in _content.get_children():
		c.queue_free()
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
