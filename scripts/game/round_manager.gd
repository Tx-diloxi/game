extends Node
## Gestion des manches : nombre, santé et vitesse des zombies, manches de chiens, tanks.

const MAX_ALIVE := 24
const BETWEEN_ROUNDS := 10.0
const FIRST_DELAY := 4.0

var game: Node
var round_num := 0
var to_spawn := 0
var alive := 0
var in_round := false
var dog_round := false
var _spawn_timer := 0.0
var _between_timer := FIRST_DELAY
var _next_dog_round := randi_range(5, 7)
var _tank_pending := false
var _boss_pending := false


func _physics_process(delta: float) -> void:
	if not GameManager.in_game:
		return
	if not in_round:
		_between_timer -= delta
		if _between_timer <= 0.0:
			_start_round(round_num + 1)
		return
	if to_spawn > 0 and alive < MAX_ALIVE:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _spawn_interval()
			if game.spawn_enemy(_pick_enemy()):
				to_spawn -= 1
				alive += 1


func on_killed(pos: Vector3) -> void:
	alive -= 1
	if in_round and to_spawn <= 0 and alive <= 0:
		_end_round(pos)


static func zombie_hp(r: int) -> float:
	if r < 10:
		return 150.0 + 100.0 * (r - 1)
	return 950.0 * pow(1.1, r - 9)


static func zombie_count(r: int) -> int:
	return int(minf(6.0 + 3.0 * (r - 1) + 0.15 * r * r, 200.0))


func _start_round(r: int) -> void:
	round_num = r
	in_round = true
	alive = 0
	dog_round = r == _next_dog_round
	if dog_round:
		_next_dog_round = r + randi_range(4, 6)
		to_spawn = mini(6 + r, 24)
	else:
		to_spawn = zombie_count(r)
		_tank_pending = r >= 5 and r % 5 == 0 and r % 10 != 0
		_boss_pending = r % 10 == 0
		if _tank_pending or _boss_pending:
			to_spawn += 1
	_spawn_timer = 3.0
	GameManager.set_round(r)
	Audio.play("round_start", 2.0, 0.8 if dog_round else 1.0)
	game.on_round_started(r, dog_round)


func _end_round(pos: Vector3) -> void:
	in_round = false
	_between_timer = BETWEEN_ROUNDS
	Audio.play("round_end", 2.0)
	game.on_round_ended(round_num, dog_round, pos)


func _spawn_interval() -> float:
	if dog_round:
		return 1.2
	return maxf(0.35, 2.2 - 0.12 * round_num)


func _pick_enemy() -> Dictionary:
	var r := round_num
	if dog_round:
		return {"kind": "dog", "hp": minf(1600.0, 150.0 + 60.0 * r), "speed": 6.2}
	if _boss_pending and to_spawn <= zombie_count(r) - 4:
		_boss_pending = false
		return {"kind": "boss", "hp": zombie_hp(r) * 8.0 + 2000.0, "speed": 2.1}
	if _tank_pending:
		_tank_pending = false
		return {"kind": "tank", "hp": zombie_hp(r) * 8.0, "speed": 1.7}
	# Zombies spéciaux (apparition progressive)
	var roll := randf()
	var p_bomber := clampf(0.04 + (r - 6) * 0.01, 0.0, 0.14) if r >= 6 else 0.0
	var p_spit := clampf(0.04 + (r - 8) * 0.008, 0.0, 0.11) if r >= 8 else 0.0
	var p_scream := clampf(0.03 + (r - 10) * 0.006, 0.0, 0.08) if r >= 10 else 0.0
	var p_brute := clampf(0.03 + (r - 7) * 0.008, 0.0, 0.09) if r >= 7 else 0.0
	var p_inf := clampf(0.04 + (r - 9) * 0.008, 0.0, 0.1) if r >= 9 else 0.0
	if roll < p_brute:
		return {"kind": "brute", "hp": zombie_hp(r) * 3.0, "speed": 1.9}
	elif roll < p_brute + p_inf:
		return {"kind": "infected", "hp": zombie_hp(r) * 0.8, "speed": 3.0 + randf() * 0.5}
	roll -= p_brute + p_inf
	if roll < p_bomber:
		return {"kind": "bomber", "hp": zombie_hp(r) * 0.8, "speed": 1.9 + randf() * 0.4}
	elif roll < p_bomber + p_spit:
		return {"kind": "spitter", "hp": zombie_hp(r) * 0.7, "speed": 2.2}
	elif roll < p_bomber + p_spit + p_scream:
		return {"kind": "screamer", "hp": zombie_hp(r) * 0.9, "speed": 2.4}
	var run_chance := clampf((r - 2) * 0.15, 0.0, 0.85)
	var sprint_chance := clampf((r - 6) * 0.12, 0.0, 0.7)
	var v := randf()
	var spd := 1.3 + randf() * 0.3
	if v < sprint_chance:
		spd = 4.6 + randf() * 0.4
	elif v < run_chance:
		spd = 2.6 + randf() * 0.4
	return {"kind": "zombie", "hp": zombie_hp(r), "speed": spd}
