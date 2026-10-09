extends RefCounted
## Caractéristiques de toutes les armes. Une arme possédée est un Dictionary :
## {"id": String, "mag": int, "reserve": int, "upgraded": bool, "tier": int}

const WEAPONS := {
	"p9": {
		"name": "P9", "upgraded_name": "P9 Infernal", "model": "Pistol_2", "fbx": true, "length": 0.26,
		"upgrade_effect": "explosive", "upgrade_label": "Balles explosives",
		"grip_r": Vector3(0.0, -0.026, 0.094), "grip_l": Vector3(0.0, -0.026, 0.094), "grip_l_mode": "side",
		"kind": "pistol",
		"damage": 40, "rpm": 420, "auto": false, "pellets": 1, "spread": 0.012,
		"mag": 8, "reserve": 80, "reload": 1.6, "head_mult": 3.0,
		"splash": 0.0, "sound": "shot_p9", "recoil": 1.6, "color": Color(0.25, 0.25, 0.28),
	},
	"revolver": {
		"name": "Justicier", "upgraded_name": "Justicier Ardent", "model": "Revolver_2", "fbx": true, "length": 0.28,
		"upgrade_effect": "fire", "upgrade_label": "Balles incendiaires",
		"grip_r": Vector3(0.0, -0.028, 0.104), "grip_l": Vector3(0.0, -0.028, 0.104), "grip_l_mode": "side",
		"kind": "pistol",
		"damage": 160, "rpm": 150, "auto": false, "pellets": 1, "spread": 0.008,
		"mag": 6, "reserve": 48, "reload": 2.6, "head_mult": 3.5,
		"splash": 0.0, "sound": "shot_revolver", "recoil": 3.0, "color": Color(0.3, 0.3, 0.32),
	},
	"carabine": {
		"name": "Carabine M2", "upgraded_name": "Carabine du Jugement", "model": "AssaultRifle2_4", "fbx": true, "length": 0.62,
		"upgrade_effect": "chain", "upgrade_label": "Arc électrique",
		"grip_r": Vector3(0.0, -0.05, 0.098), "grip_l": Vector3(0.0, 0.07, -0.106), "grip_l_mode": "side",
		"kind": "rifle",
		"damage": 110, "rpm": 360, "auto": false, "pellets": 1, "spread": 0.006,
		"mag": 10, "reserve": 120, "reload": 2.0, "head_mult": 3.0,
		"splash": 0.0, "sound": "shot_carabine", "recoil": 1.8, "color": Color(0.45, 0.3, 0.18),
	},
	"vipere": {
		"name": "Vipère", "upgraded_name": "Vipère Sanglante", "model": "SubmachineGun_2", "fbx": true, "length": 0.45,
		"upgrade_effect": "fire", "upgrade_label": "Balles incendiaires",
		"grip_r": Vector3(0.0, -0.014, 0.027), "grip_l": Vector3(0.0, -0.052, -0.067), "grip_l_mode": "side",
		"kind": "smg",
		"damage": 45, "rpm": 780, "auto": true, "pellets": 1, "spread": 0.02,
		"mag": 32, "reserve": 192, "reload": 2.2, "head_mult": 2.5,
		"splash": 0.0, "sound": "shot_vipere", "recoil": 0.7, "color": Color(0.2, 0.22, 0.2),
	},
	"frelon": {
		"name": "Frelon", "upgraded_name": "Frelon Venimeux", "model": "SubmachineGun_4", "fbx": true, "length": 0.4,
		"upgrade_effect": "chain", "upgrade_label": "Arc électrique",
		"grip_r": Vector3(0.0, -0.011, 0.147), "grip_l": Vector3(0.0, -0.049, 0.012), "grip_l_mode": "side",
		"kind": "smg",
		"damage": 36, "rpm": 900, "auto": true, "pellets": 1, "spread": 0.025,
		"mag": 40, "reserve": 240, "reload": 2.0, "head_mult": 2.5,
		"splash": 0.0, "sound": "shot_frelon", "recoil": 0.6, "color": Color(0.25, 0.25, 0.22),
	},
	"brise_porte": {
		"name": "Brise-Porte", "upgraded_name": "Broyeur d'Os", "model": "Shotgun_1", "fbx": true, "length": 0.8,
		"upgrade_effect": "knockback", "upgrade_label": "Souffle dévastateur",
		"grip_r": Vector3(0.0, -0.012, 0.188), "grip_l": Vector3(0.0, 0.014, -0.157), "grip_l_mode": "side",
		"kind": "shotgun",
		"damage": 45, "rpm": 70, "auto": false, "pellets": 8, "spread": 0.07,
		"mag": 6, "reserve": 54, "reload": 3.0, "head_mult": 1.5,
		"splash": 0.0, "sound": "shot_brise_porte", "recoil": 4.0, "color": Color(0.35, 0.22, 0.12),
	},
	"double_canon": {
		"name": "Double Canon", "upgraded_name": "Double Canon Infernal", "model": "Shotgun_SawedOff", "fbx": true, "length": 0.5,
		"upgrade_effect": "fire", "upgrade_label": "Balles incendiaires",
		"grip_r": Vector3(0.0, -0.011, 0.2), "grip_l": Vector3(0.0, 0.019, -0.114), "grip_l_mode": "side",
		"kind": "shotgun",
		"damage": 60, "rpm": 110, "auto": false, "pellets": 12, "spread": 0.09,
		"mag": 2, "reserve": 28, "reload": 2.4, "head_mult": 1.5,
		"splash": 0.0, "sound": "shot_double_canon", "recoil": 5.0, "color": Color(0.4, 0.28, 0.16),
	},
	"k74": {
		"name": "K-74", "upgraded_name": "K-74 Hurlant", "model": "AssaultRifle_3", "fbx": true, "length": 0.7,
		"upgrade_effect": "chain", "upgrade_label": "Arc électrique",
		"grip_r": Vector3(0.0, -0.008, 0.3), "grip_l": Vector3(0.0, 0.104, -0.093), "grip_l_mode": "side",
		"kind": "rifle",
		"damage": 70, "rpm": 620, "auto": true, "pellets": 1, "spread": 0.014,
		"mag": 30, "reserve": 270, "reload": 2.4, "head_mult": 3.0,
		"splash": 0.0, "sound": "shot_k74", "recoil": 1.1, "color": Color(0.3, 0.25, 0.15),
	},
	"spectre": {
		"name": "Spectre", "upgraded_name": "Spectre Hanté", "model": "Bullpup_3", "fbx": true, "length": 0.65,
		"upgrade_effect": "explosive", "upgrade_label": "Balles explosives",
		"grip_r": Vector3(0.0, -0.049, 0.081), "grip_l": Vector3(0.0, -0.01, -0.13), "grip_l_mode": "side",
		"kind": "rifle",
		"damage": 85, "rpm": 540, "auto": true, "pellets": 1, "spread": 0.012,
		"mag": 35, "reserve": 280, "reload": 2.5, "head_mult": 3.0,
		"splash": 0.0, "sound": "shot_spectre", "recoil": 0.9, "color": Color(0.2, 0.22, 0.25),
	},
	"tonnerre": {
		"name": "Tonnerre", "upgraded_name": "Tonnerre Éternel", "model": "Bullpup_1", "fbx": true, "length": 0.72,
		"upgrade_effect": "fire", "upgrade_label": "Balles incendiaires",
		"grip_r": Vector3(0.0, -0.035, 0.014), "grip_l": Vector3(0.0, -0.04, -0.25), "grip_l_mode": "side",
		"kind": "lmg",
		"damage": 80, "rpm": 650, "auto": true, "pellets": 1, "spread": 0.022,
		"mag": 100, "reserve": 400, "reload": 4.0, "head_mult": 2.5,
		"splash": 0.0, "sound": "shot_k74", "recoil": 1.0, "color": Color(0.18, 0.2, 0.18),
		"sound_pitch": 0.82,
	},
	"eclaireur": {
		"name": "Éclaireur", "upgraded_name": "Éclaireur Spectral", "model": "SniperRifle_5", "fbx": true, "length": 0.85,
		"upgrade_effect": "chain", "upgrade_label": "Arc électrique",
		"grip_r": Vector3(0.0, -0.004, 0.216), "grip_l": Vector3(0.0, 0.047, -0.037), "grip_l_mode": "side",
		"kind": "rifle",
		"damage": 190, "rpm": 240, "auto": false, "pellets": 1, "spread": 0.004,
		"mag": 12, "reserve": 96, "reload": 2.6, "head_mult": 4.0,
		"splash": 0.0, "sound": "shot_eclaireur", "recoil": 2.5, "color": Color(0.25, 0.28, 0.2),
		"ads_fov": 38.0,
	},
	"longue_vue": {
		"name": "Longue-Vue", "upgraded_name": "Œil du Néant", "model": "SniperRifle_2", "fbx": true, "length": 0.95,
		"upgrade_effect": "explosive", "upgrade_label": "Obus explosifs",
		"grip_r": Vector3(0.0, -0.029, 0.19), "grip_l": Vector3(0.0, 0.016, -0.045), "grip_l_mode": "side",
		"kind": "sniper",
		"damage": 500, "rpm": 50, "auto": false, "pellets": 1, "spread": 0.002,
		"mag": 5, "reserve": 40, "reload": 3.2, "head_mult": 5.0,
		"splash": 0.0, "sound": "shot_longue_vue", "recoil": 5.0, "color": Color(0.15, 0.15, 0.17),
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
	# Arme unique : n'existe pas dans la boîte, se construit à l'établi
	"arc_tonnerre": {
		"name": "Arc Tonnerre", "upgraded_name": "Arc Tonnerre Orageux", "model": "blaster-j", "length": 0.38,
		"upgrade_effect": "chain", "upgrade_label": "Foudre à longue portée", "native_effect": "chain",
		"grip_r": Vector3(0.0, -0.06, 0.07), "grip_l": Vector3(0.0, -0.07, -0.085), "grip_l_mode": "side",
		"kind": "wonder",
		"damage": 1500, "rpm": 150, "auto": false, "pellets": 1, "spread": 0.003,
		"mag": 12, "reserve": 96, "reload": 2.6, "head_mult": 2.0,
		"splash": 0.0, "sound": "shot_plasma", "recoil": 1.5, "color": Color(0.4, 0.75, 1.0),
	},
}

## Armes que peut donner la boîte mystère.
const BOX_POOL := ["revolver", "carabine", "vipere", "frelon", "brise_porte", "double_canon", "k74", "spectre", "tonnerre", "eclaireur", "longue_vue", "desintegrateur"]

const UPGRADE_DAMAGE := 2.5
const UPGRADE_AMMO := 1.5
## Niveaux d'amélioration : 0 = normal, 1 = Infernal, 2 = niveau II (camouflage doré).
const TIER_DAMAGE := [1.0, 2.5, 4.0]
const TIER_AMMO := [1.0, 1.5, 2.0]
const TIER_COST := [5000, 8000]


static func data(id: String) -> Dictionary:
	return WEAPONS[id]


## `upgraded` accepte un booléen (niveau 1) ou un entier de niveau (0 à 2).
static func make(id: String, upgraded = 0) -> Dictionary:
	var tier := clampi(int(upgraded), 0, 2)
	var w := {"id": id, "upgraded": tier > 0, "tier": tier, "mag": 0, "reserve": 0}
	w.mag = max_mag(w)
	w.reserve = max_reserve(w)
	return w


static func display_name(w: Dictionary) -> String:
	var d := data(w.id)
	if w.upgraded:
		return d.upgraded_name + (" II" if w.get("tier", 1) >= 2 else "")
	return d.name


static func damage(w: Dictionary) -> float:
	var d := data(w.id)
	return d.damage * TIER_DAMAGE[w.get("tier", 0)]


static func max_mag(w: Dictionary) -> int:
	var d := data(w.id)
	return int(ceil(d.mag * TIER_AMMO[w.get("tier", 0)]))


static func max_reserve(w: Dictionary) -> int:
	var d := data(w.id)
	var m := 1.5 if GameManager.has_perk("ravitailleur") else 1.0
	return int(ceil(d.reserve * TIER_AMMO[w.get("tier", 0)] * m))


static func is_full(w: Dictionary) -> bool:
	return w.mag >= max_mag(w) and w.reserve >= max_reserve(w)
