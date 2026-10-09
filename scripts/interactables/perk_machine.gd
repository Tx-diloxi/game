extends "res://scripts/interactables/interactable.gd"
## Distributeur d'atout. +Z local = façade.

var perk_id := "cuirasse"
var _screen: MeshInstance3D
var _light: OmniLight3D
var _pending := false


func _ready() -> void:
	radius = 2.3
	var p: Dictionary = GameManager.PERKS[perk_id]
	var col: Color = p.color
	MeshUtil.static_box(self, Vector3(1.2, 2.2, 0.8), Vector3(0, 1.1, 0), Mat.textured("metal", col.darkened(0.25), 1.2, 0.5))
	MeshUtil.box_mesh(self, Vector3(1.26, 0.12, 0.86), Vector3(0, 2.2, 0), Mat.metal(Color(0.3, 0.3, 0.3)))
	MeshUtil.box_mesh(self, Vector3(1.26, 0.1, 0.86), Vector3(0, 0.05, 0), Mat.metal(Color(0.2, 0.2, 0.2)))
	MeshUtil.box_mesh(self, Vector3(1.0, 0.3, 0.05), Vector3(0, 0.35, 0.41), MeshUtil.mat(Color(0.05, 0.05, 0.05)))
	_screen = MeshUtil.box_mesh(self, Vector3(1.0, 0.9, 0.05), Vector3(0, 1.5, 0.41), MeshUtil.mat(col.darkened(0.3)))
	for i in 3:
		MeshUtil.cylinder_mesh(self, 0.06, 0.22, Vector3(-0.3 + i * 0.3, 0.75, 0.3), MeshUtil.mat(col, 0.5))
	var title := MeshUtil.label3d(self, p.name, Vector3(0, 2.0, 0.44), 60, col.lightened(0.5))
	title.font = preload("res://scenes/ui/ui_theme.gd").title_font()
	MeshUtil.label3d(self, "%d" % p.price, Vector3(0, 1.3, 0.44), 64, Color.WHITE)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.omni_range = 3.5
	_light.light_energy = 0.0
	_light.position = Vector3(0, 1.6, 0.9)
	add_child(_light)
	GameManager.power_changed.connect(_on_power)
	_on_power(GameManager.power_on)


func _needs_power() -> bool:
	return GameManager.PERKS[perk_id].power


func _powered() -> bool:
	return GameManager.power_on or not _needs_power()


func _on_power(_on: bool) -> void:
	var p: Dictionary = GameManager.PERKS[perk_id]
	var col: Color = p.color
	if _powered():
		_screen.material_override = MeshUtil.mat(col, 2.0)
		_light.light_energy = 1.2
	else:
		_screen.material_override = MeshUtil.mat(col.darkened(0.6))
		_light.light_energy = 0.0


func is_available(_player: Node) -> bool:
	return not GameManager.has_perk(perk_id) and not _pending


func get_prompt(_player: Node) -> String:
	var p: Dictionary = GameManager.PERKS[perk_id]
	if not _powered():
		return "Il faut rétablir le courant"
	if GameManager.perks.size() >= GameManager.MAX_PERKS:
		return "Limite d'atouts atteinte"
	return "[F] Acheter %s (%s)  [%d]" % [p.name, p.desc, p.price]


func interact(player: Node) -> void:
	if not _powered() or GameManager.perks.size() >= GameManager.MAX_PERKS:
		Audio.play("deny")
		return
	if not GameManager.spend(GameManager.PERKS[perk_id].price):
		return
	_pending = true
	player.drink(GameManager.PERKS[perk_id].color)
	await get_tree().create_timer(1.4, false).timeout
	_pending = false
	GameManager.add_perk(perk_id)
