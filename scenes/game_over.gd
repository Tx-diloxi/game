extends Control
## Écran de fin de partie avec statistiques.

const UI := preload("res://scenes/ui/ui_util.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var col := UI.centered_column(self, Color(0.04, 0.0, 0.0))
	UI.label(col, "FIN DE LA PARTIE", 80, UI.RED)
	var r := GameManager.round_num
	UI.label(col, "Vous avez survécu %d manche%s" % [r, "s" if r > 1 else ""], 34)
	UI.label(col, "Éliminations : %d" % GameManager.kills, 24, Color(0.8, 0.8, 0.8))
	UI.label(col, "Tirs à la tête : %d" % GameManager.headshots, 24, Color(0.8, 0.8, 0.8))
	UI.label(col, "Points gagnés : %d" % GameManager.total_points, 24, Color(0.8, 0.8, 0.8))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	col.add_child(spacer)
	UI.button(col, "Rejouer", GameManager.new_game)
	UI.button(col, "Menu principal", GameManager.to_menu)
