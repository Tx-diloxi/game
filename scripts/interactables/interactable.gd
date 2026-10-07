extends Node3D
## Base des objets interactifs. Le joueur choisit l'objet le plus proche qu'il regarde
## (dans le rayon `radius`) et affiche son texte d'aide.

const MeshUtil := preload("res://scripts/util/mesh_util.gd")
const WeaponDB := preload("res://scripts/weapons/weapon_db.gd")
const Mat := preload("res://scripts/util/materials.gd")

var radius := 2.2


func _enter_tree() -> void:
	add_to_group("interactable")


func is_available(_player: Node) -> bool:
	return true


func get_prompt(_player: Node) -> String:
	return ""


func interact(_player: Node) -> void:
	pass


func interact_hold(_player: Node, _delta: float) -> void:
	pass


## Ajoute une collision statique (sous le parent fourni, pour qu'elle soit prise
## en compte par le maillage de navigation si c'est la NavigationRegion3D).
func add_blocker(size: Vector3, local_pos: Vector3, nav_parent: Node = null) -> StaticBody3D:
	var body := MeshUtil.static_box(nav_parent if nav_parent else self, size, Vector3.ZERO, null)
	body.global_transform = global_transform * Transform3D(Basis(), local_pos)
	return body
