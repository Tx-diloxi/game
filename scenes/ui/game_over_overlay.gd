extends CanvasLayer
## Écran de fin superposé au jeu figé : fondu au rouge sombre, « Vous avez survécu X manches »,
## statistiques qui défilent, boutons.

const UI := preload("res://scenes/ui/ui_theme.gd")


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.stop_music(2.0)
	Audio.play("round_end", 4.0, 0.6)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.0, 0.0, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	col.modulate.a = 0.0

	var r := GameManager.round_num
	var t1 := UI.label(col, "FIN DE LA PARTIE", 110, UI.RED, UI.title_font())
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := UI.label(col, "Vous avez survécu %d manche%s" % [r, "s" if r > 1 else ""], 38, UI.BONE, UI.title_font())
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 24)
	col.add_child(sp)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 6)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	col.add_child(gc)
	var counters := []
	for row in [["Éliminations", GameManager.kills], ["Tirs à la tête", GameManager.headshots], ["Points gagnés", GameManager.total_points],
			["Précision", int(100.0 * GameManager.shots_hit / maxf(GameManager.shots_fired, 1.0))]]:
		UI.label(grid, row[0], 26, UI.GREY)
		var v := UI.label(grid, "0 %" if row[0] == "Précision" else "0", 30, Color.WHITE, UI.title_font())
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		counters.append([v, row[1]])

	if not GameManager.last_beaten.is_empty():
		var rec := UI.label(col, "★ NOUVEAU RECORD ★", 34, Color(1.0, 0.8, 0.2), UI.title_font())
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var names := {"best_round": "manche", "best_kills": "éliminations", "best_points": "points", "best_headshots": "tirs à la tête", "best_time": "survie"}
		var parts := []
		for k in GameManager.last_beaten:
			parts.append(names.get(k, k))
		var sub_l := UI.label(col, "Battu : " + ", ".join(parts), 20, UI.GREY)
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 30)
	col.add_child(sp2)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	col.add_child(buttons)
	var again := UI.button(buttons, "REJOUER", GameManager.new_game, 36)
	again.grab_focus.call_deferred()
	again.custom_minimum_size = Vector2(260, 0)
	again.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var menu := UI.button(buttons, "MENU PRINCIPAL", GameManager.to_menu, 36)
	menu.custom_minimum_size = Vector2(320, 0)
	menu.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.88, 1.5)
	tw.tween_property(col, "modulate:a", 1.0, 0.8)
	for c in counters:
		var lbl: Label = c[0]
		var target: int = c[1]
		var suffix := " %" if lbl.text.ends_with("%") else ""
		tw.tween_method(func(v: float): lbl.text = str(int(v)) + suffix, 0.0, float(target), 0.6)
