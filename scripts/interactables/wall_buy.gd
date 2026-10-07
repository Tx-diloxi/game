extends "res://scripts/interactables/interactable.gd"
## Arme murale : achat de l'arme ou de munitions. +Z local pointe vers la pièce.

var weapon_id := "carabine"
var price := 500


func _ready() -> void:
	radius = 2.0
	var d := WeaponDB.data(weapon_id)
	var chalk := StandardMaterial3D.new()
	chalk.albedo_color = Color(0.92, 0.92, 0.88, 0.85)
	chalk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chalk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Contour à la craie
	for c in [[Vector3(0, 1.93, 0.012), Vector3(1.4, 0.025, 0.004)], [Vector3(0, 1.07, 0.012), Vector3(1.4, 0.025, 0.004)],
			[Vector3(-0.7, 1.5, 0.012), Vector3(0.025, 0.86, 0.004)], [Vector3(0.7, 1.5, 0.012), Vector3(0.025, 0.86, 0.004)]]:
		var line := MeshUtil.box_mesh(self, c[1], c[0], chalk)
		line.rotation.z = randf_range(-0.012, 0.012)
	var gun := MeshUtil.build_gun(self, weapon_id, false, d.color, d.kind)
	gun.position = Vector3(0, 1.48, 0.03)
	gun.rotation.y = -PI / 2
	gun.scale = Vector3(0.06, 1.25, 1.25)
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = chalk
		(mi as MeshInstance3D).material_overlay = null
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := MeshUtil.label3d(self, "%s   %d" % [d.name.to_upper(), price], Vector3(0, 2.1, 0.02), 44, Color(0.92, 0.92, 0.88))
	l.font = preload("res://scenes/ui/ui_theme.gd").title_font()
	l.outline_size = 0


func ammo_price(player: Node) -> int:
	var idx: int = player.holder.find_weapon(weapon_id)
	if idx >= 0 and player.holder.weapons[idx].upgraded:
		return 4500
	return int(price / 2.0)


func get_prompt(player: Node) -> String:
	var d := WeaponDB.data(weapon_id)
	if player.holder.has_weapon(weapon_id):
		return "[F] Acheter des munitions  [%d]" % ammo_price(player)
	return "[F] Acheter %s  [%d]" % [d.name, price]


func interact(player: Node) -> void:
	var holder = player.holder
	if holder.has_weapon(weapon_id):
		var w: Dictionary = holder.weapons[holder.find_weapon(weapon_id)]
		if WeaponDB.is_full(w):
			Audio.play("deny")
			return
		if GameManager.spend(ammo_price(player)):
			holder.refill(weapon_id)
	elif GameManager.spend(price):
		holder.give_weapon(weapon_id)
