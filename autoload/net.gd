extends Node
## Coop en ligne (ENet) : un hôte, 1 à 3 invités. Gère la connexion, la liste des joueurs
## et l'échange des positions. Les zombies et l'économie ne sont pas encore partagés.

signal players_changed
signal connection_lost(reason: String)
signal game_starting(map_id: String)
signal remote_state(id: int, state: Dictionary)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var active := false
var is_host := false
var my_name := ""
## id de pair -> nom (l'hôte a toujours l'id 1).
var players := {}
var _peer: ENetMultiplayerPeer


func _ready() -> void:
	my_name = OS.get_environment("USERNAME")
	if my_name == "":
		my_name = "Joueur"
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Connexion impossible"))
	multiplayer.server_disconnected.connect(func(): _fail("L'hôte a quitté la partie"))


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


func host(port := DEFAULT_PORT) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = true
	players = {1: my_name}
	players_changed.emit()
	return OK


func join(ip: String, port := DEFAULT_PORT) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, port)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = false
	players = {}
	return OK


func leave() -> void:
	if _peer != null:
		_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	active = false
	is_host = false
	players = {}
	players_changed.emit()


func _fail(reason: String) -> void:
	leave()
	connection_lost.emit(reason)


func _on_connected() -> void:
	_register.rpc_id(1, my_name)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_host and players.erase(id):
		_sync_players.rpc(players)


## Invité -> hôte : annonce son nom.
@rpc("any_peer", "reliable")
func _register(pname: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = pname.substr(0, 20)
	_sync_players.rpc(players)


@rpc("authority", "call_local", "reliable")
func _sync_players(list: Dictionary) -> void:
	players = list
	players_changed.emit()


## L'hôte lance la partie sur tous les pairs.
func start_game(map_id: String) -> void:
	if is_host:
		_start.rpc(map_id)


@rpc("authority", "call_local", "reliable")
func _start(map_id: String) -> void:
	GameManager.map_id = map_id
	game_starting.emit(map_id)


## Diffuse l'état du joueur local (position, visée, arme) aux autres.
func send_state(state: Dictionary) -> void:
	if active and multiplayer.multiplayer_peer != null and players.size() > 1:
		_state.rpc(state)


@rpc("any_peer", "unreliable_ordered")
func _state(state: Dictionary) -> void:
	remote_state.emit(multiplayer.get_remote_sender_id(), state)
