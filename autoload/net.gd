extends Node
## Coop en ligne (ENet) : un hôte, 1 à 3 invités. Gère la connexion, la liste des joueurs
## et l'échange des positions. Les zombies et l'économie ne sont pas encore partagés.

signal players_changed
signal connection_lost(reason: String)
signal game_starting(map_id: String)
signal remote_state(id: int, state: Dictionary)
## Événement du monde appliqué chez tous les joueurs : (genre, indice, données, émetteur).
signal world_event(kind: String, idx: int, data, sender: int)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var active := false
var is_host := false
var my_name := ""
## id de pair -> nom (l'hôte a toujours l'id 1).
var players := {}
var _peer: ENetMultiplayerPeer
## Zombies de la partie : id réseau -> noeud (réels chez l'hôte, marionnettes chez les invités).
var zombies := {}
## Joueurs hors d'état de jouer (morts) : id -> true.
var dead_peers := {}
var _next_zid := 1
const ZombieScript := preload("res://scripts/zombies/zombie.gd")


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
	zombies = {}
	dead_peers = {}
	_next_zid = 1
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


# --- Zombies (l'hôte simule, les invités affichent) ----------------------------

## Hôte : attribue un id au zombie et l'annonce aux invités.
func register_zombie(z: Node, pos: Vector3) -> void:
	z.net_id = _next_zid
	_next_zid += 1
	zombies[z.net_id] = z
	if players.size() > 1:
		_zspawn.rpc(z.net_id, z.kind, z.max_hp, z.speed, pos)


@rpc("authority", "reliable")
func _zspawn(id: int, kind: String, hp: float, spd: float, pos: Vector3) -> void:
	var game := GameManager.game
	if game == null or zombies.has(id):
		return
	var z: CharacterBody3D = ZombieScript.new()
	z.puppet = true
	z.net_id = id
	z.setup(kind, hp, spd, null)
	zombies[id] = z
	game.add_child(z)
	z.global_position = pos


## Hôte : position, cap, vitesse et compteur d'attaques de chaque zombie vivant.
func send_zombies(list: Array) -> void:
	if players.size() > 1:
		_zsnap.rpc(list)


@rpc("authority", "unreliable_ordered")
func _zsnap(list: Array) -> void:
	for e in list:
		var z = zombies.get(e[0])
		if z != null and is_instance_valid(z) and z.puppet:
			z.apply_snapshot(e[1], e[2], e[3], e[4])


func zombie_died(id: int, head: bool, cause: String) -> void:
	if players.size() > 1:
		_zdie.rpc(id, head, cause)


@rpc("authority", "reliable")
func _zdie(id: int, head: bool, cause: String) -> void:
	var z = zombies.get(id)
	if z != null and is_instance_valid(z) and z.puppet and z.state != z.State.DEAD:
		z._die(head, cause)


## Invité : demande à l'hôte d'appliquer des dégâts à un zombie.
func hit_zombie(id: int, amount: float, head: bool, cause: String) -> void:
	if active and not is_host:
		_zhit.rpc_id(1, id, amount, head, cause)


@rpc("any_peer", "reliable")
func _zhit(id: int, amount: float, head: bool, cause: String) -> void:
	if not is_host:
		return
	var z = zombies.get(id)
	if z != null and is_instance_valid(z) and not z.puppet:
		z.attacker_id = multiplayer.get_remote_sender_id()
		z.take_damage(amount, head, cause)
		z.attacker_id = 0


## Hôte -> invité : points gagnés, dégâts subis, infection.
func award(peer: int, points: int) -> void:
	if peer == my_id():
		GameManager.add_points(points)
	else:
		_award.rpc_id(peer, points)


@rpc("authority", "reliable")
func _award(points: int) -> void:
	GameManager.add_points(points)


func hurt(peer: int, amount: float, from: Vector3) -> void:
	_hurt.rpc_id(peer, amount, from)


@rpc("authority", "reliable")
func _hurt(amount: float, from: Vector3) -> void:
	if GameManager.game and GameManager.game.player:
		GameManager.game.player.take_damage(amount, from)


func infect(peer: int, seconds: float) -> void:
	_infect.rpc_id(peer, seconds)


@rpc("authority", "reliable")
func _infect(seconds: float) -> void:
	if GameManager.game and GameManager.game.player:
		GameManager.game.player.infect(seconds)


# --- Manches ---------------------------------------------------------------------

func round_started(r: int, dog: bool) -> void:
	if players.size() > 1:
		world_event.emit("respawn", 0, null, 1)
		_round_started.rpc(r, dog)


@rpc("authority", "reliable")
func _round_started(r: int, dog: bool) -> void:
	world_event.emit("respawn", 0, null, 1)
	GameManager.set_round(r)
	if GameManager.game:
		GameManager.game.on_round_started(r, dog)


func round_ended() -> void:
	if players.size() > 1:
		_round_ended.rpc()


@rpc("authority", "reliable")
func _round_ended() -> void:
	if GameManager.game:
		GameManager.game.hud.round_over()


# --- Événements du monde (portes, courant, pièges, barricades, boîte, power-ups) ----

## Action d'un joueur sur le monde. L'hôte la rediffuse à tout le monde (lui compris) ;
## hors coop, elle s'applique directement.
func act(kind: String, idx: int, data = null) -> void:
	if not active or players.size() < 2:
		world_event.emit(kind, idx, data, my_id())
	elif is_host:
		_apply.rpc(kind, idx, data, 1)
	else:
		_ask.rpc_id(1, kind, idx, data)


@rpc("any_peer", "reliable")
func _ask(kind: String, idx: int, data) -> void:
	if is_host:
		_apply.rpc(kind, idx, data, multiplayer.get_remote_sender_id())


@rpc("authority", "call_local", "reliable")
func _apply(kind: String, idx: int, data, sender: int) -> void:
	world_event.emit(kind, idx, data, sender)


# --- Réanimation, mort et fin de partie ---------------------------------------------

func multiplayer_session() -> bool:
	return active and players.size() > 1


## Un coéquipier relève ce joueur (appelé par celui qui maintient F).
func revive(peer: int) -> void:
	_revive.rpc_id(peer)


@rpc("any_peer", "reliable")
func _revive() -> void:
	if GameManager.game and GameManager.game.player:
		GameManager.game.player.revive()


## Signale que le joueur local est mort (true) ou de retour (false). L'hôte termine la partie
## quand tous les joueurs sont morts.
func report_dead(is_dead: bool) -> void:
	act("dead", 0, is_dead)


func _on_dead_event(sender: int, is_dead: bool) -> void:
	if is_dead:
		dead_peers[sender] = true
	else:
		dead_peers.erase(sender)
	if is_host and is_dead:
		for id in players:
			if not dead_peers.has(id):
				return
		act("game_over", 0, null)
