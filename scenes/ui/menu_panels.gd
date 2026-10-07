extends RefCounted
## Panneaux partagés entre le menu principal et le menu pause.

const UI := preload("res://scenes/ui/ui_theme.gd")


static func _panel(parent: Node, title: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(560, 0)
	parent.add_child(pc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	pc.add_child(col)
	UI.label(col, title, 44, UI.RED, UI.title_font())
	var sep := ColorRect.new()
	sep.color = Color(UI.RED.r, UI.RED.g, UI.RED.b, 0.5)
	sep.custom_minimum_size = Vector2(0, 2)
	col.add_child(sep)
	return col


static func options(parent: Node) -> Control:
	var col := _panel(parent, "OPTIONS")
	UI.slider(col, "Sensibilité souris", 0.03, 0.4, 0.01, GameManager.mouse_sensitivity, GameManager.set_sensitivity)
	UI.slider(col, "Champ de vision", 60.0, 100.0, 1.0, GameManager.fov, GameManager.set_fov, "%d°")
	UI.slider(col, "Volume", 0.0, 1.0, 0.05, GameManager.master_volume, GameManager.set_volume)
	var fs := CheckButton.new()
	fs.text = "Plein écran"
	fs.button_pressed = GameManager.fullscreen
	fs.add_theme_font_size_override("font_size", 22)
	fs.toggled.connect(GameManager.set_fullscreen)
	col.add_child(fs)
	return col.get_parent()


static func controls(parent: Node) -> Control:
	var col := _panel(parent, "COMMANDES")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for row in [["Z Q S D", "Se déplacer"], ["Souris", "Regarder"], ["Clic gauche", "Tirer"], ["Clic droit", "Viser"],
			["R", "Recharger"], ["F", "Acheter / interagir (maintenir pour réparer)"], ["Maj", "Sprint"],
			["Ctrl", "S'accroupir"], ["Espace", "Sauter"], ["V", "Couteau"], ["G", "Grenade"], ["T", "Singe-leurre"],
			["1 / 2 / 3, molette", "Changer d'arme"], ["Échap", "Pause"]]:
		UI.label(grid, row[0], 22, UI.BONE, UI.title_font())
		UI.label(grid, row[1], 20, UI.GREY)
	return col.get_parent()


static func credits(parent: Node) -> Control:
	var col := _panel(parent, "CRÉDITS")
	for line in ["BUNKER Z — un jeu de survie par manches",
			"Moteur : Godot 4.7",
			"Zombies : Pixelhouse (pixelhouse.com.ar) — CC-BY 3.0",
			"Chiens : loup de umask007 (OpenGameArt) — CC-BY-SA 3.0",
			"Modèles d'armes : Kenney (kenney.nl) — CC0",
			"Sons d'impact : Kenney — CC0",
			"Tirs : Vincent Sevedge — CC-BY 3.0 ; cris de zombies, rechargements : OpenGameArt — CC0",
			"Textures : ambientCG.com — CC0",
			"Musique et autres sons : synthétisés en jeu"]:
		var l := UI.label(col, line, 20, UI.GREY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return col.get_parent()
