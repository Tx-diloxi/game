extends RefCounted
## Caractéristiques de toutes les armes. Une arme possédée est un Dictionary :
## {"id": String, "mag": int, "reserve": int, "upgraded": bool}

const WEAPONS := {
	"p9": {
		"name": "P9", "upgraded_name": "P9 Infernal", "model": "blaster-a", "length": 0.3,
		"upgrade_effect": "explosive", "upgrade_label": "Balles explosives",
		"grip_r": Vector3(0.0, -0.04, 0.06), "grip_l": Vector3(0.0, -0.04, 0.06), "grip_l_mode": "side",
		"kind": "pistol",
		"damage": 40, "rpm": 420, "auto": false, "pellets": 1, "spread": 0.012,
		"mag": 8, "reserve": 80, "reload": 1.6, "head_mult": 3.0,
		"splash": 0.0, "sound": "shot_pistol", "recoil": 1.6, "color": Color(0.25, 0.25, 0.28),
	},
	"carabine": {
		"name": "Carabine M2", "upgraded_name": "Carabine du Jugement", "model": "blaster-n", "length": 0.62,
		"upgrade_effect": "chain", "upgrade_label": "Arc électrique",
		"grip_r": Vector3(0.0, -0.08, 0.09), "grip_l": Vector3(0.0, -0.03, -0.12), "grip_l_mode": "under",
		"kind": "rifle",
		"damage": 110, "rpm": 360, "auto": false, "pellets": 1, "spread": 0.006,
		"mag": 10, "reserve": 120, "reload": 2.0, "head_mult": 3.0,
		"splash": 0.0, "sound": "shot_rifle", "recoil": 1.8, "color": Color(0.45, 0.3, 0.18),
	},
	"vipere": {
		"name": "Vipère", "upgraded_name": "Vipère Sanglante", "model": "blaster-j", "length": 0.42,
		"upgrade_effect": "fire", "upgrade_label": "Balles incendiaires",
		"grip_r": Vector3(0.0, -0.04, 0.15), "grip_l": Vector3(0.0, -0.07, -0.055), "grip_l_mode": "side",
		"kind": "smg",
		"damage": 45, "rpm": 780, "auto": true, "pellets": 1, "spread": 0.02,
		"mag": 32, "reserve": 192, "reload": 2.2, "head_mult": 2.5,
		"splash": 0.0, "sound": "shot_smg", "recoil": 0.7, "color": Color(0.2, 0.22, 0.2),
	},
	"brise_porte": {
		"name": "Brise-Porte", "upgraded_name": "Broyeur d'Os", "model": "blaster-l", "length": 0.55,
		"upgrade_effect": "knockback", "upgrade_label": "Souffle dévastateur",
		"grip_r": Vector3(0.0, -0.07, 0.17), "grip_l": Vector3(0.0, -0.07, -0.12), "grip_l_mode": "side",
		"kind": "shotgun",
		"damage": 45, "rpm": 70, "auto": false, "pellets": 8, "spread": 0.07,
		"mag": 6, "reserve": 54, "reload": 3.0, "head_mult": 1.5,
		"splash": 0.0, "sound": "shot_shotgun", "recoil": 4.0, "color": Color(0.35, 0.22, 0.12),
	},
	"k74": {
		"name": "K-74", "upgraded_name": "K-74 Hurlant", "model": "blaster-d", "length": 0.62,
		"upgrade_effect": "chain", "upgrade_label": "Arc électrique",
		"grip_r": Vector3(0.0, -0.04, 0.10), "grip_l": Vector3(0.0, -0.075, -0.05), "grip_l_mode": "side",
		"kind": "rifle",
		"damage": 70, "rpm": 620, "auto": true, "pellets": 1, "spread": 0.014,
		"mag": 30, "reserve": 270, "reload": 2.4, "head_mult": 3.0,
		"splash": 0.0, "sound": "shot_rifle", "recoil": 1.1, "color": Color(0.3, 0.25, 0.15),
	},
	"tonnerre": {
		"name": "Tonnerre", "upgraded_name": "Tonnerre Éternel", "model": "blaster-p", "length": 0.72,
		"upgrade_effect": "fire", "upgrade_label": "Balles incendiaires",
		"grip_r": Vector3(0.0, -0.06, 0.19), "grip_l": Vector3(0.0, -0.10, -0.03), "grip_l_mode": "side",
		"kind": "lmg",
		"damage": 80, "rpm": 650, "auto": true, "pellets": 1, "spread": 0.022,
		"mag": 100, "reserve": 400, "reload": 4.0, "head_mult": 2.5,
		"splash": 0.0, "sound": "shot_rifle", "recoil": 1.0, "color": Color(0.18, 0.2, 0.18),
	},
	"longue_vue": {
		"name": "Longue-Vue", "upgraded_name": "Œil du Néant", "model": "blaster-e", "length": 0.8,
		"upgrade_effect": "explosive", "upgrade_label": "Obus explosifs",
		"grip_r": Vector3(0.0, -0.045, 0.18), "grip_l": Vector3(0.0, -0.06, 0.03), "grip_l_mode": "side",
		"kind": "sniper",
		"damage": 500, "rpm": 50, "auto": false, "pellets": 1, "spread": 0.002,
		"mag": 5, "reserve": 40, "reload": 3.2, "head_mult": 5.0,
		"splash": 0.0, "sound": "shot_sniper", "recoil": 5.0, "color": Color(0.15, 0.15, 0.17),
	},
	"desintegrateur": {
		"name": "Désintégrateur", "upgraded_name": "Désintégrateur Oméga", "model": "blaster-o", "length": 0.45,
		"upgrade_effect": "chain", "upgrade_label": "Désintégration en chaîne",
		"grip_r": Vector3(0.0, -0.06, 0.07), "grip_l": Vector3(0.0, -0.07, -0.085), "grip_l_mode": "side",
		"kind": "wonder",
		"damage": 1200, "rpm": 180, "auto": false, "pellets": 1, "spread": 0.004,
		"mag": 20, "reserve": 160, "reload": 3.0, "head_mult": 1.0,
		"splash": 3.0, "sound": "shot_plasma", "recoil": 2.0, "color": Color(0.1, 0.9, 0.3),
	},
}

## Armes que peut donner la boîte mystère.
const BOX_POOL := ["carabine", "vipere", "brise_porte", "k74", "tonnerre", "longue_vue", "desintegrateur"]

const UPGRADE_DAMAGE := 2.5
const UPGRADE_AMMO := 1.5


static func data(id: String) -> Dictionary:
	return WEAPONS[id]


static func make(id: String, upgraded := false) -> Dictionary:
	var w := {"id": id, "upgraded": upgraded, "mag": 0, "reserve": 0}
	w.mag = max_mag(w)
	w.reserve = max_reserve(w)
	return w


static func display_name(w: Dictionary) -> String:
	var d := data(w.id)
	return d.upgraded_name if w.upgraded else d.name


static func damage(w: Dictionary) -> float:
	var d := data(w.id)
	return d.damage * (UPGRADE_DAMAGE if w.upgraded else 1.0)


static func max_mag(w: Dictionary) -> int:
	var d := data(w.id)
	return int(ceil(d.mag * (UPGRADE_AMMO if w.upgraded else 1.0)))


static func max_reserve(w: Dictionary) -> int:
	var d := data(w.id)
	var m := 1.5 if GameManager.has_perk("ravitailleur") else 1.0
	return int(ceil(d.reserve * (UPGRADE_AMMO if w.upgraded else 1.0) * m))


static func is_full(w: Dictionary) -> bool:
	return w.mag >= max_mag(w) and w.reserve >= max_reserve(w)
