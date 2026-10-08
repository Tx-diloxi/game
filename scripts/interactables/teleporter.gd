extends "res://scripts/interactables/interactable.gd"
## Téléporteur : deux plateformes reliées (courant requis, 750 points, recharge 25 s).
## Utiliser celle de l'accueil ouvre le réacteur (zone 3) sans payer sa porte.

const COST := 750
const COOLDOWN := 25.0

static var _ready_at := 0.0 # temps (s) à partir duquel le téléporteur est de nouveau utilisable

var zone := 0
var partner: Node3D
var _ring: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	radius = 2.2
	var base := Mat.metal(Color(0.25, 0.27, 0.3))
	MeshUtil.cylinder_mesh(self, 1.35, 0.12, Vector3(0, 0.06, 0), base)
	var glow := MeshUtil.mat(Color(0.2, 0.8, 1.0), 3.0)
	_ring = MeshUtil.cylinder_mesh(self, 1.2, 0.04, Vector3(0, 0.14, 0), glow)
	MeshUtil.cylinder_mesh(self, 1.0, 0.045, Vector3(0, 0.145, 0), MeshUtil.mat(Color(0.03, 0.05, 0.07)))
	MeshUtil.label3d(self, "TÉLÉPORTEUR", Vector3(0, 2.3, 0), 48, Color(0.5, 0.9, 1.0))
	_light = OmniLight3D.new()
	_light.light_color = Color(0.3, 0.85, 1.0)
	_light.light_energy = 0.8
	_light.omni_range = 4.5
	_light.position.y = 0.6
	add_child(_light)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var ready_now := t >= _ready_at and GameManager.power_on
	_light.light_energy = (0.8 + 0.3 * sin(t * 4.0)) if ready_now else 0.15
	(_ring.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if ready_now else 0.3


func get_prompt(_player: Node) -> String:
	if not GameManager.power_on:
		return "Le téléporteur nécessite le courant"
	var wait := _ready_at - Time.get_ticks_msec() / 1000.0
	if wait > 0.0:
		return "Téléporteur en recharge (%d s)" % ceili(wait)
	return "[F] Se téléporter  [%d]" % COST


func interact(player: Node) -> void:
	if not GameManager.power_on or partner == null or Time.get_ticks_msec() / 1000.0 < _ready_at:
		return
	if not GameManager.spend(COST):
		return
	_ready_at = Time.get_ticks_msec() / 1000.0 + COOLDOWN
	var game := GameManager.game
	if game and not game.active_zones.has(partner.zone):
		game.unlock_zone(partner.zone)
		for d in get_tree().get_nodes_in_group("doors"):
			if d.unlock_zone == partner.zone:
				d.force_open()
	Audio.play("power_on", 4.0, 1.8)
	if game and game.hud:
		game.hud.flash(Color(0.4, 0.9, 1.0, 0.9), 0.6)
	var dest: Vector3 = partner.global_position + partner.global_basis.z * 1.9
	player.global_position = Vector3(dest.x, 0.1, dest.z)
	player.velocity = Vector3.ZERO
	var look: Vector3 = partner.global_basis.z
	player.rotation.y = atan2(-look.x, -look.z)
	GameManager.show_message("TÉLÉPORTATION", Color(0.5, 0.9, 1.0))
