extends "res://scripts/interactables/interactable.gd"
## Terminal d'archives du Dr Sigma : chaque consultation révèle un indice de la quête secrète.

const NOTES := [
	["JOURNAL DU DR SIGMA — 1/3", "« J'ai caché trois fioles de sérum. La première attend près des tables de l'accueil, au sud-ouest. »"],
	["JOURNAL DU DR SIGMA — 2/3", "« La deuxième est dans le couloir, derrière les caisses près de la fenêtre. »"],
	["JOURNAL DU DR SIGMA — 3/3", "« La dernière dort au fond des cuves, dans l'angle sud-est. Le réacteur n'est joignable que par le téléporteur… ou une porte coûteuse. »"],
]

var _i := 0


func _ready() -> void:
	radius = 1.8
	var metal := Mat.metal(Color(0.2, 0.22, 0.25))
	MeshUtil.box_mesh(self, Vector3(0.9, 1.0, 0.5), Vector3(0, 0.5, 0.25), metal)
	MeshUtil.box_mesh(self, Vector3(0.8, 0.5, 0.06), Vector3(0, 1.2, 0.2), metal, Vector3(-0.35, 0, 0))
	MeshUtil.box_mesh(self, Vector3(0.7, 0.4, 0.02), Vector3(0, 1.21, 0.24), MeshUtil.mat(Color(0.2, 0.9, 0.5), 2.0), Vector3(-0.35, 0, 0))
	MeshUtil.label3d(self, "ARCHIVES", Vector3(0, 1.85, 0.2), 40, Color(0.4, 1.0, 0.6))


func get_prompt(_player: Node) -> String:
	return "[F] Consulter les archives"


func interact(_player: Node) -> void:
	var n: Array = NOTES[_i % NOTES.size()]
	_i += 1
	Audio.play("empty", -6.0, 1.4)
	GameManager.show_message(n[0], Color(0.4, 1.0, 0.6), n[1])
