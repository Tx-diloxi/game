extends "res://scripts/interactables/interactable.gd"
## Console du réacteur : avec les trois fioles et le courant, lance la synthèse du sérum (40 s à tenir).
## Récompense : une vie supplémentaire, munitions max et 3000 points.

const SYNTH_TIME := 40.0

var _state := 0 # 0 en attente, 1 synthèse, 2 terminée
var _t := 0.0
var _screen: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	radius = 2.0
	var metal := Mat.metal(Color(0.22, 0.24, 0.27))
	MeshUtil.box_mesh(self, Vector3(1.6, 1.1, 0.6), Vector3(0, 0.55, 0.3), metal)
	_screen = MeshUtil.box_mesh(self, Vector3(1.4, 0.55, 0.04), Vector3(0, 1.35, 0.22), MeshUtil.mat(Color(1.0, 0.3, 0.2), 2.0), Vector3(-0.3, 0, 0))
	_label = MeshUtil.label3d(self, "SYNTHÈSE SIGMA", Vector3(0, 2.0, 0.2), 44, Color(1.0, 0.5, 0.3))


func is_available(_player: Node) -> bool:
	return _state != 2


func get_prompt(_player: Node) -> String:
	if _state == 1:
		return "Synthèse en cours : %d s" % ceili(SYNTH_TIME - _t)
	if not GameManager.power_on:
		return "Console hors tension"
	if GameManager.quest_vials < 3:
		return "Console : il manque des fioles de sérum (%d/3)" % GameManager.quest_vials
	return "[F] Lancer la synthèse du sérum"


func interact(_player: Node) -> void:
	if _state != 0 or not GameManager.power_on or GameManager.quest_vials < 3:
		return
	_state = 1
	_t = 0.0
	GameManager.quest_started = true
	(_screen.material_override as StandardMaterial3D).emission = Color(1.0, 0.8, 0.2)
	Audio.play("power_on", 4.0, 0.7)
	GameManager.show_message("SYNTHÈSE LANCÉE", Color(1.0, 0.8, 0.2), "Survivez 40 secondes")


func _process(delta: float) -> void:
	if _state != 1 or not GameManager.in_game:
		return
	_t += delta
	_label.text = "SYNTHÈSE  %d s" % ceili(SYNTH_TIME - _t)
	if _t >= SYNTH_TIME:
		_state = 2
		_label.text = "SÉRUM PRÊT"
		(_screen.material_override as StandardMaterial3D).emission = Color(0.2, 1.0, 0.4)
		_reward()


func _reward() -> void:
	GameManager.quest_done = true
	GameManager.extra_lives += 1
	GameManager.add_points(3000)
	if GameManager.game:
		GameManager.game.apply_powerup("max_ammo")
		if GameManager.game.hud:
			GameManager.game.hud.flash(Color(0.4, 1.0, 0.5, 0.9), 0.8)
	Audio.play("power_on", 6.0, 1.5)
	GameManager.show_message("SÉRUM SIGMA", Color(0.4, 1.0, 0.5), "Vie supplémentaire, munitions max et 3000 points")
