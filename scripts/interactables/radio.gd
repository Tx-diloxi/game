extends "res://scripts/interactables/interactable.gd"
## Radio ou ordinateur d'histoire : une consultation affiche un message de l'équipe de l'abri.

## Histoire de l'Abri 7 (une entrée par objet, dans l'ordre de `entry`).
const STORY := [
	["RADIO — SERGENT VOSS, JOUR 3", "« Ici l'Abri 7. La contamination s'est propagée par la ventilation. Condamnez les fenêtres, je répète : condamnez les fenêtres. »"],
	["ENREGISTREMENT — INFIRMERIE", "« Les morts se relèvent moins d'une heure après la morsure. Les doses de sérum sont épuisées. Nous tiendrons tant que le courant tient. »"],
	["RADIO — SERGENT VOSS, JOUR 9", "« Il ne reste que moi. Si quelqu'un entend ceci : le courant se rétablit au fond de la grande salle. Ne vous fiez pas aux portes. »"],
	["ORDINATEUR — INGÉNIEUR ROUX", "« J'ai bricolé quelque chose avec la bobine, la batterie et le condensateur éparpillés dans l'abri. Un établi dans la salle de départ devrait suffire. »"],
	["RADIO — DR SIGMA, LABORATOIRE", "« Le réacteur alimente toute la zone. Si vous lisez ceci, c'est que l'expérience a échoué. Consultez mes archives. »"],
]

var entry := 0
var computer := false
var _light: OmniLight3D


func _ready() -> void:
	radius = 1.8
	var metal := Mat.metal(Color(0.18, 0.2, 0.17))
	if computer:
		MeshUtil.box_mesh(self, Vector3(0.9, 0.9, 0.5), Vector3(0, 0.45, 0.25), metal)
		MeshUtil.box_mesh(self, Vector3(0.7, 0.45, 0.05), Vector3(0, 1.1, 0.2), metal, Vector3(-0.3, 0, 0))
		MeshUtil.box_mesh(self, Vector3(0.6, 0.35, 0.02), Vector3(0, 1.11, 0.23), MeshUtil.mat(Color(0.2, 0.8, 1.0), 1.8), Vector3(-0.3, 0, 0))
		_light = OmniLight3D.new()
		_light.light_color = Color(0.3, 0.8, 1.0)
	else:
		MeshUtil.box_mesh(self, Vector3(0.8, 0.5, 0.4), Vector3(0, 0.25, 0.25), Mat.metal(Color(0.3, 0.22, 0.14)))
		MeshUtil.box_mesh(self, Vector3(0.5, 0.3, 0.3), Vector3(0, 0.65, 0.25), metal)
		MeshUtil.cylinder_mesh(self, 0.01, 0.6, Vector3(0.2, 1.1, 0.25), metal)
		MeshUtil.sphere_mesh(self, 0.03, Vector3(-0.12, 0.7, 0.1), MeshUtil.mat(Color(1.0, 0.3, 0.2), 2.0))
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.4, 0.25)
	_light.light_energy = 0.3
	_light.omni_range = 2.0
	_light.position = Vector3(0, 0.9, 0.0)
	add_child(_light)
	MeshUtil.static_box(self, Vector3(0.8, 0.9, 0.4), Vector3(0, 0.45, 0.25), null)


func get_prompt(_player: Node) -> String:
	return "[F] Consulter l'ordinateur" if computer else "[F] Écouter la radio"


func interact(_player: Node) -> void:
	var n: Array = STORY[entry % STORY.size()]
	Audio.play("radio_static", -4.0, 1.0)
	GameManager.show_message(n[0], Color(1.0, 0.8, 0.4), n[1])
