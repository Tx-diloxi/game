extends RefCounted
## Panneaux partagés entre le menu principal et le menu pause.

const UI := preload("res://scenes/ui/ui_theme.gd")


static func _panel(parent: Node, title: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(540, 0)
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


static func _option_row(col: Node, title: String, items: Array, selected: int, cb: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var l := UI.label(row, title, 22, UI.GREY)
	l.custom_minimum_size = Vector2(210, 0)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(200, 0)
	ob.add_theme_font_size_override("font_size", 20)
	for it in items:
		ob.add_item(it)
	ob.select(selected)
	ob.item_selected.connect(cb)
	row.add_child(ob)
	return ob


static func _check(col: Node, title: String, value: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 22)
	c.toggled.connect(cb)
	col.add_child(c)


## Choix de la carte : un gros bouton par carte avec sa description.
static func map_select(parent: Node, on_pick: Callable) -> Control:
	var col := _panel(parent, "CHOISIR UNE CARTE")
	var first: Button = null
	for id in GameManager.MAPS:
		var info: Dictionary = GameManager.MAPS[id]
		var b := UI.button(col, str(info.name).to_upper(), func():
			GameManager.map_id = id
			on_pick.call(), 34)
		if first == null:
			first = b
		var d := UI.label(col, info.desc, 20, UI.GREY)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		d.custom_minimum_size = Vector2(500, 0)
	first.grab_focus.call_deferred()
	return col.get_parent()


static func options(parent: Node) -> Control:
	var col := _panel(parent, "OPTIONS")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	UI.label(box, "AUDIO", 26, UI.RED, UI.title_font())
	UI.slider(box, "Volume général", 0.0, 1.0, 0.05, GameManager.master_volume, GameManager.set_volume)
	UI.slider(box, "Musique", 0.0, 1.0, 0.05, GameManager.music_volume, GameManager.set_music_volume)
	UI.slider(box, "Effets sonores", 0.0, 1.0, 0.05, GameManager.sfx_volume, GameManager.set_sfx_volume)
	UI.slider(box, "Voix (annonceur)", 0.0, 1.0, 0.05, GameManager.voice_volume, GameManager.set_voice_volume)
	UI.label(box, "IMAGE", 26, UI.RED, UI.title_font())
	UI.slider(box, "Champ de vision", 60.0, 100.0, 1.0, GameManager.fov, GameManager.set_fov, "%d°")
	_option_row(box, "Qualité des ombres", ["Désactivées (rapide)", "1 lampe", "2 lampes", "2 lampes + lune (lent)"], GameManager.shadow_quality, GameManager.set_shadow_quality)
	var fps_names := []
	for f in GameManager.FPS_LIMITS:
		fps_names.append("Illimité" if f == 0 else "%d" % f)
	_option_row(box, "Limite d'images/s", fps_names, GameManager.max_fps_index, GameManager.set_max_fps)
	_option_row(box, "Anticrénelage (MSAA)", ["Désactivé", "2x", "4x", "8x"], GameManager.msaa_index, GameManager.set_msaa)
	var res_names := []
	for r in GameManager.RESOLUTIONS:
		res_names.append("%d × %d" % [r.x, r.y])
	_option_row(box, "Résolution (fenêtré)", res_names, GameManager.res_index, GameManager.set_resolution)
	UI.slider(box, "Échelle de rendu 3D", 0.5, 1.0, 0.05, GameManager.render_scale, GameManager.set_render_scale, "%.2f×")
	_check(box, "Synchronisation verticale", GameManager.vsync, GameManager.set_vsync)
	_check(box, "Plein écran", GameManager.fullscreen, GameManager.set_fullscreen)
	UI.label(box, "CONTRÔLES", 26, UI.RED, UI.title_font())
	UI.slider(box, "Sensibilité souris", 0.03, 0.4, 0.01, GameManager.mouse_sensitivity, GameManager.set_sensitivity)
	UI.label(box, "TEST", 26, UI.RED, UI.title_font())
	_check(box, "Mode test (F1 arme suivante, F2 améliorer, F3 munitions et points, F4 atouts, F5 manche suivante)", GameManager.debug_mode, GameManager.set_debug)
	return col.get_parent()


static func controls(parent: Node) -> Control:
	var col := _panel(parent, "COMMANDES")
	col.add_child(preload("res://scenes/ui/remap_panel.gd").new())
	return col.get_parent()


static func _fmt_time(sec: int) -> String:
	return "%d:%02d" % [sec / 60, sec % 60]


static func records(parent: Node) -> Control:
	var col := _panel(parent, "MEILLEURS SCORES")
	var r := GameManager.get_records()
	if r.games == 0:
		UI.label(col, "Aucune partie jouée pour l'instant.", 22, UI.GREY)
		return col.get_parent()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for row in [["Manche record", str(r.best_round)], ["Éliminations", str(r.best_kills)], ["Tirs à la tête", str(r.best_headshots)],
			["Points gagnés", str(r.best_points)], ["Plus longue survie", _fmt_time(r.best_time)], ["Parties jouées", str(r.games)]]:
		UI.label(grid, row[0], 24, UI.GREY)
		var v := UI.label(grid, row[1], 30, UI.BONE, UI.title_font())
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return col.get_parent()


static func credits(parent: Node) -> Control:
	var col := _panel(parent, "CRÉDITS")
	for line in ["BUNKER Z — un jeu de survie par manches",
			"Moteur : Godot 4.7",
			"Zombies : Pixelhouse (pixelhouse.com.ar) — CC-BY 3.0",
			"Chiens : loup de umask007 (OpenGameArt) — CC-BY-SA 3.0",
			"Bras : FPS Arms Rigged (OpenGameArt) — CC0",
			"Modèles d'armes : Ultimate Gun Pack, Quaternius — CC0 ; armes futuristes : Kenney (kenney.nl) — CC0",
			"Tirs des armes : The Free Firearm Sound Library, Ben Jaszczak et al. — CC0",
			"Sons d'impact : Kenney — CC0",
			"Tirs : Vincent Sevedge — CC-BY 3.0 ; cris de zombies, rechargements : OpenGameArt — CC0",
			"Textures : ambientCG.com — CC0",
			"Musique : Ambient Horror Track 01 (CC0) ; Dark Ambience Loop, Iwan Gabovitch (CC-BY 3.0) ; stings d'horreur et jingle de mort (CC0)",
			"Annonceur : voix de synthèse ; autres sons synthétisés en jeu"]:
		var l := UI.label(col, line, 20, UI.GREY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return col.get_parent()
