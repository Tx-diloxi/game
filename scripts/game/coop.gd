extends Node
## Coop en ligne côté partie : envoie l'état du joueur local et gère les avatars des autres.

const RemoteScript := preload("res://scripts/player/remote_player.gd")
const SEND_INTERVAL := 1.0 / 20.0

var game: Node
var player: Node3D
var remotes := {}
var _t := 0.0
var _zt := 0.0
const ZOMBIE_INTERVAL := 1.0 / 15.0


func _ready() -> void:
	Net.remote_state.connect(_on_state)
	Net.players_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if Net.remote_state.is_connected(_on_state):
		Net.remote_state.disconnect(_on_state)
	if Net.players_changed.is_connected(_refresh):
		Net.players_changed.disconnect(_refresh)


## Crée les avatars manquants et retire ceux des joueurs partis.
func _refresh() -> void:
	for id in Net.players:
		if id != Net.my_id() and not remotes.has(id):
			var r := RemoteScript.new()
			r.peer_id = id
			r.player_name = Net.players[id]
			r.target_pos = game.start_position()
			game.add_child(r)
			remotes[id] = r
	for id in remotes.keys():
		if not Net.players.has(id):
			remotes[id].queue_free()
			remotes.erase(id)


func _physics_process(delta: float) -> void:
	if Net.is_host:
		_zt += delta
		if _zt >= ZOMBIE_INTERVAL:
			_zt = 0.0
			var list := []
			for z in Net.zombies.values():
				if is_instance_valid(z) and z.state != z.State.DEAD:
					list.append([z.net_id, z.global_position, z.rotation.y, Vector2(z.velocity.x, z.velocity.z).length(), z._atk_count])
			Net.send_zombies(list)
	_t += delta
	if _t < SEND_INTERVAL or player == null:
		return
	_t = 0.0
	var w = player.holder.cur()
	Net.send_state({
		"pos": player.global_position, "yaw": player.rotation.y, "pitch": player.head.rotation.x,
		"weapon": w.id if w else "", "downed": player.downed,
	})


func _on_state(id: int, state: Dictionary) -> void:
	if remotes.has(id):
		remotes[id].apply_state(state)
