extends Node
## Coop : applique chez chaque joueur les événements du monde (portes, courant, pièges,
## barricades, boîte, power-ups). L'hôte reste l'autorité pour ce qui touche aux zombies.

const PowerupScript := preload("res://scripts/powerups/powerup.gd")

var game: Node
var _applied_pu := {}


func _ready() -> void:
	Net.world_event.connect(_on_event)


func _exit_tree() -> void:
	if Net.world_event.is_connected(_on_event):
		Net.world_event.disconnect(_on_event)


func _on_event(kind: String, idx: int, data, sender: int) -> void:
	match kind:
		"door":
			if idx >= 0 and idx < game.doors.size() and is_instance_valid(game.doors[idx]) and not game.doors[idx].opened:
				game.doors[idx]._open()
		"power":
			var sw := get_tree().get_first_node_in_group("power_switch")
			if sw:
				sw.activate()
		"trap":
			if idx >= 0 and idx < game.traps.size():
				game.traps[idx].activate()
		"boards":
			if not Net.is_host and idx >= 0 and idx < game.barricades.size():
				game.barricades[idx].set_boards(int(data))
		"repair":
			if Net.is_host and idx >= 0 and idx < game.barricades.size():
				var b = game.barricades[idx]
				if b.boards < b.MAX_BOARDS:
					b.add_board()
					Net.award(sender, 10)
		"box_pick":
			if Net.is_host:
				Net.act("box_move", game._pick_box_index())
		"box_move":
			game.apply_box_index(idx)
		"pu_spawn":
			if not Net.is_host:
				var p: Node3D = PowerupScript.new()
				p.kind = data.kind
				p.net_id = idx
				game.powerups[idx] = p
				p.tree_exiting.connect(func(): game.powerups.erase(idx))
				game.add_child(p)
				p.global_position = data.pos
		"dead":
			Net._on_dead_event(sender, bool(data))
		"game_over":
			GameManager.game_over()
		"pu_take":
			if Net.is_host and game.powerups.has(idx) and not _applied_pu.has(idx):
				Net.act("pu_apply", idx, game.powerups[idx].kind)
		"respawn":
			# Nouvelle manche : les joueurs morts reviennent
			if game.player and game.player.dead:
				game.player.respawn()
		"pu_apply":
			if not _applied_pu.has(idx):
				_applied_pu[idx] = true
				game.apply_powerup(str(data))
				if game.powerups.has(idx):
					game.powerups[idx].queue_free()
