extends VBoxContainer
## Liste des commandes avec remappage clavier/souris et manette.
## Clic sur une touche : « Appuyez… » puis la prochaine touche (ou bouton, ou stick) est assignée.
## Échap annule. Fonctionne aussi en pause (le panneau tourne même quand l'arbre est en pause).

const UI := preload("res://scenes/ui/ui_theme.gd")

var _waiting: Button = null
var _waiting_action := ""
var _waiting_pad := false
var _buttons := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	add_child(head)
	var h0 := UI.label(head, "Action", 18, UI.GREY)
	h0.custom_minimum_size = Vector2(200, 0)
	var h1 := UI.label(head, "Clavier / souris", 18, UI.GREY)
	h1.custom_minimum_size = Vector2(150, 0)
	UI.label(head, "Manette", 18, UI.GREY)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for row in GameManager.REMAPPABLE:
		var l := UI.label(grid, row[1], 20, UI.BONE)
		l.custom_minimum_size = Vector2(200, 0)
		for pad in [false, true]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(150, 34)
			b.add_theme_font_size_override("font_size", 18)
			b.add_theme_font_override("font", UI.ui_font())
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			var action: String = row[0]
			b.pressed.connect(func(): _start(b, action, pad))
			grid.add_child(b)
			_buttons[[action, pad]] = b
	_refresh()

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	add_child(foot)
	var reset := Button.new()
	reset.text = "Réinitialiser"
	reset.add_theme_font_size_override("font_size", 20)
	reset.pressed.connect(func():
		_cancel()
		GameManager.reset_bindings()
		_refresh())
	foot.add_child(reset)
	UI.label(foot, "Clic sur une touche pour la changer — Échap annule", 16, UI.GREY)


func _refresh() -> void:
	for k in _buttons:
		_buttons[k].text = GameManager.action_label(k[0], k[1])


func _start(b: Button, action: String, pad: bool) -> void:
	_cancel()
	_waiting = b
	_waiting_action = action
	_waiting_pad = pad
	b.text = "Appuyez…"


func _cancel() -> void:
	if _waiting:
		_waiting = null
		_refresh()


func _input(event: InputEvent) -> void:
	if _waiting == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_cancel()
		elif not _waiting_pad:
			_assign(event)
	elif event is InputEventMouseButton and event.pressed and not _waiting_pad:
		# Le premier clic qui a ouvert la capture est déjà consommé par le bouton.
		get_viewport().set_input_as_handled()
		_assign(event)
	elif event is InputEventJoypadButton and event.pressed and _waiting_pad:
		get_viewport().set_input_as_handled()
		_assign(event)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.7 and _waiting_pad:
		get_viewport().set_input_as_handled()
		_assign(event)


func _assign(event: InputEvent) -> void:
	GameManager.rebind(_waiting_action, event, _waiting_pad)
	_waiting = null
	_refresh()
