extends CanvasLayer
## Interface en jeu : manche (bâtons à la craie rouge), points, munitions, atouts,
## power-ups, messages, réticule, marqueurs de touche et post-traitement (vignette, grain, sang).

const WeaponDB := preload("res://scripts/weapons/weapon_db.gd")
const UI := preload("res://scenes/ui/ui_theme.gd")
const POST_FX := preload("res://shaders/post_fx.gdshader")

const RED := Color(0.72, 0.04, 0.02)

var player: Node = null
var _root: Control
var _fx: ColorRect
var _fx_mat: ShaderMaterial
var _round_draw: Control
var _round_num := 0
var _round_seed := 0
var _round_glow := 0.0
var _round_alpha := 1.0
var _points: Label
var _weapon: Label
var _mag: Label
var _reserve: Label
var _grenades: Control
var _prompt: Label
var _prompt_bg: PanelContainer
var _message: Label
var _sub_message: Label
var _hitmarker: Control
var _hit_alpha := 0.0
var _hit_kill := false
var _crosshair: Control
var _downed: Control
var _perks: HBoxContainer
var _powerups: HBoxContainer
var _powerup_labels := {}
var _msg_tween: Tween
var _round_tween: Tween
var _damage := 0.0
var _flash := 0.0
var _tint := 0.0
var _boss: Node = null
var _boss_bar: Control
var _dmg_canvas: Control
var _dmg_hits: Array = []
var _life_label: Label
var _score_panel: Control
var _score_vals := {}
var _score_t := 0.0


func _ready() -> void:
	layer = 1
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	add_child(_root)

	# Post-traitement plein écran (sous le reste de l'interface)
	_fx = ColorRect.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = POST_FX
	_fx.material = _fx_mat
	_root.add_child(_fx)

	_crosshair = _canvas(_draw_crosshair)
	_hitmarker = _canvas(_draw_hitmarker)
	_dmg_canvas = _canvas(_draw_damage_dirs)

	# Manche (bas gauche)
	_round_draw = _canvas(_draw_round)
	_anchor(_round_draw, Vector2(0, 1), Rect2(30, -170, 320, 140))

	_points = _label("500", 34, Color(0.98, 0.93, 0.78), UI.ui_font(), Vector2(0, 1), Rect2(40, -215, 300, 44))
	_perks = HBoxContainer.new()
	_perks.add_theme_constant_override("separation", 10)
	_root.add_child(_perks)
	_anchor(_perks, Vector2(0, 1), Rect2(40, -270, 400, 46))

	# Munitions (bas droite)
	_weapon = _label("", 22, Color(0.85, 0.82, 0.76), UI.ui_font(), Vector2(1, 1), Rect2(-440, -150, 400, 30))
	_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mag = _label("", 58, Color.WHITE, UI.title_font(), Vector2(1, 1), Rect2(-440, -122, 290, 70))
	_mag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reserve = _label("", 30, Color(0.7, 0.68, 0.64), UI.title_font(), Vector2(1, 1), Rect2(-145, -100, 110, 44))
	_grenades = _canvas(_draw_grenades)
	_anchor(_grenades, Vector2(1, 1), Rect2(-240, -48, 200, 26))

	# Aide d'interaction
	_prompt_bg = PanelContainer.new()
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0, 0, 0, 0.55)
	pb.content_margin_left = 18
	pb.content_margin_right = 18
	pb.content_margin_top = 6
	pb.content_margin_bottom = 6
	_prompt_bg.add_theme_stylebox_override("panel", pb)
	_prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt_bg)
	_anchor(_prompt_bg, Vector2(0.5, 0.5), Rect2(-450, 90, 900, 44))
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_bg.add_child(_prompt)
	_prompt_bg.visible = false

	# Messages centraux
	_message = _label("", 64, Color.WHITE, UI.title_font(), Vector2(0.5, 0), Rect2(-600, 80, 1200, 80))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	_sub_message = _label("", 24, Color(0.85, 0.8, 0.75), UI.ui_font(), Vector2(0.5, 0), Rect2(-600, 158, 1200, 34))
	_sub_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_message.modulate.a = 0.0

	_boss_bar = _canvas(_draw_boss_bar)
	_anchor(_boss_bar, Vector2(0.5, 0), Rect2(-320, 26, 640, 44))

	_build_scoreboard()
	_life_label = _label("", 22, Color(1.0, 0.65, 0.75), UI.ui_font(), Vector2(0, 1), Rect2(40, -300, 300, 30))

	_powerups = HBoxContainer.new()
	_powerups.add_theme_constant_override("separation", 30)
	_powerups.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_powerups)
	_anchor(_powerups, Vector2(0.5, 1), Rect2(-400, -90, 800, 40))

	# À terre
	_downed = ColorRect.new()
	(_downed as ColorRect).color = Color(0.15, 0.15, 0.18, 0.5)
	_downed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_downed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_downed.visible = false
	_root.add_child(_downed)
	var dl := Label.new()
	dl.text = "À TERRE"
	dl.add_theme_font_override("font", UI.title_font())
	dl.add_theme_font_size_override("font_size", 80)
	dl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.15))
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed.add_child(dl)
	_anchor(dl, Vector2(0.5, 0.5), Rect2(-300, -60, 600, 100))

	GameManager.points_changed.connect(_on_points)
	GameManager.points_popup.connect(_on_popup)
	GameManager.perks_changed.connect(_on_perks)
	GameManager.powerups_changed.connect(_on_powerups)
	GameManager.message.connect(show_message)
	_on_points(GameManager.points)
	Audio.play_music("ambience", -10.0)


func _label(text: String, font_size: int, color: Color, font: Font, anchor: Vector2, rect: Rect2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	_anchor(l, anchor, rect)
	return l


func _canvas(draw_fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(draw_fn)
	_root.add_child(c)
	return c


## Ancre le contrôle sur un point de l'écran avec un rectangle relatif à ce point.
func _anchor(c: Control, anchor: Vector2, rect: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.end.x
	c.offset_bottom = rect.end.y


func bind(p: Node) -> void:
	player = p
	p.holder.ammo_changed.connect(_on_ammo)
	p.holder.weapon_changed.connect(_on_ammo)
	p.holder.hit_confirmed.connect(_on_hit)
	p.damaged.connect(func(): _damage = maxf(_damage, 0.8))
	p.hit_from.connect(func(src: Vector3): _dmg_hits.append({"pos": src, "age": 0.0}))
	p.downed_changed.connect(func(d: bool): _downed.visible = d)
	_on_ammo()


func track_boss(z: Node) -> void:
	_boss = z


func _process(delta: float) -> void:
	for e in _dmg_hits:
		e.age += delta
	_dmg_hits = _dmg_hits.filter(func(e): return e.age < 2.6)
	_dmg_canvas.queue_redraw()
	_life_label.text = "VIE SUPPLÉMENTAIRE  ×%d" % GameManager.extra_lives if GameManager.extra_lives > 0 else ""
	var show_score := Input.is_action_pressed("scoreboard")
	if show_score != _score_panel.visible:
		_score_panel.visible = show_score
		if show_score:
			_refresh_scoreboard()
	if show_score:
		_score_t -= delta
		if _score_t <= 0.0:
			_score_t = 0.25
			_refresh_scoreboard()
	_crosshair.queue_redraw()
	_boss_bar.queue_redraw()
	_hit_alpha = move_toward(_hit_alpha, 0.0, delta * 4.0)
	_hitmarker.queue_redraw()
	_round_glow = move_toward(_round_glow, 0.0, delta * 0.8)
	_round_draw.queue_redraw()
	_flash = move_toward(_flash, 0.0, delta * 1.2)
	if player:
		var target: float = clampf(1.0 - player.health / player.max_health, 0.0, 1.0)
		_damage = move_toward(_damage, target, delta * 1.5)
	_fx_mat.set_shader_parameter("damage", _damage)
	_fx_mat.set_shader_parameter("flash", _flash)
	var blood := 1.0 if GameManager.is_powerup_active("zombie_blood") else 0.0
	_tint = move_toward(_tint, blood * 0.2, delta * 0.6)
	_fx_mat.set_shader_parameter("tint_amt", _tint)


# --- API ------------------------------------------------------------------

func _build_scoreboard() -> void:
	_score_panel = CenterContainer.new()
	_score_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_panel.visible = false
	_root.add_child(_score_panel)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(520, 0)
	_score_panel.add_child(pc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pc.add_child(col)
	var title := Label.new()
	title.text = "TABLEAU DES SCORES"
	title.add_theme_font_override("font", UI.title_font())
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", RED)
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for row in [["round", "Manche"], ["kills", "Éliminations"], ["heads", "Tirs à la tête"], ["acc", "Précision"],
			["points", "Points"], ["total", "Points gagnés"], ["perks", "Atouts achetés"], ["time", "Temps de jeu"]]:
		var l := Label.new()
		l.text = row[1]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", UI.GREY)
		grid.add_child(l)
		var v := Label.new()
		v.add_theme_font_override("font", UI.title_font())
		v.add_theme_font_size_override("font_size", 28)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(v)
		_score_vals[row[0]] = v


func _refresh_scoreboard() -> void:
	var gm := GameManager
	var acc := 0.0 if gm.shots_fired == 0 else 100.0 * float(gm.shots_hit) / float(gm.shots_fired)
	var t := int(gm.play_time)
	_score_vals.round.text = str(gm.round_num)
	_score_vals.kills.text = str(gm.kills)
	_score_vals.heads.text = str(gm.headshots)
	_score_vals.acc.text = "%d %%" % int(minf(acc, 100.0))
	_score_vals.points.text = str(gm.points)
	_score_vals.total.text = str(gm.total_points)
	_score_vals.perks.text = "%d" % gm.perks_bought
	_score_vals.time.text = "%d:%02d" % [t / 60, t % 60]


func set_prompt(raw: String) -> void:
	var text := GameManager.hint(raw)
	if _prompt.text != text:
		_prompt.text = text
		_prompt_bg.visible = text != ""
		var w := _prompt.get_minimum_size().x + 36.0
		_prompt_bg.offset_left = -w * 0.5
		_prompt_bg.offset_right = w * 0.5


func show_message(text: String, color := Color.WHITE, sub := "") -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_sub_message.text = sub
	if _msg_tween:
		_msg_tween.kill()
	_message.modulate.a = 1.0
	_sub_message.modulate.a = 1.0
	_message.pivot_offset = _message.size * 0.5
	_message.scale = Vector2.ONE * 1.15
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_msg_tween.tween_interval(2.3)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.8)
	_msg_tween.parallel().tween_property(_sub_message, "modulate:a", 0.0, 0.8)


func show_round(r: int, dog: bool) -> void:
	_round_num = r
	_round_seed = randi()
	_round_glow = 1.0
	if _round_tween:
		_round_tween.kill()
	_round_alpha = 1.0
	if dog:
		show_message("ILS ARRIVENT", Color(1.0, 0.45, 0.15), "Manche %d — les chiens sont lâchés" % r)
	elif r == 1:
		show_message("MANCHE 1", Color(0.85, 0.08, 0.04), "Survivez")


func round_over() -> void:
	if _round_tween:
		_round_tween.kill()
	_round_tween = create_tween().set_loops(5)
	_round_tween.tween_method(func(v: float): _round_alpha = v, 1.0, 0.15, 0.5)
	_round_tween.tween_method(func(v: float): _round_alpha = v, 0.15, 1.0, 0.5)


func flash(color: Color, _duration: float) -> void:
	_fx_mat.set_shader_parameter("flash_color", color)
	_flash = 0.9


# --- Signaux --------------------------------------------------------------

func _on_points(p: int) -> void:
	_points.text = str(p)


func _on_popup(amount: int) -> void:
	var l := Label.new()
	l.text = ("+%d" % amount) if amount > 0 else str(amount)
	l.add_theme_font_override("font", UI.ui_font())
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25) if amount > 0 else Color(1.0, 0.3, 0.2))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	l.position = _points.global_position + Vector2(_points.get_minimum_size().x + 20 + randf_range(0, 30), randf_range(-10, 14))
	var tw := l.create_tween()
	tw.tween_property(l, "position", l.position + Vector2(randf_range(50, 110), randf_range(-35, 35)), 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


func _on_ammo() -> void:
	if player == null:
		return
	var holder = player.holder
	var w = holder.cur()
	if w == null:
		_weapon.text = "COUTEAU"
		_mag.text = ""
		_reserve.text = ""
	else:
		_weapon.text = WeaponDB.display_name(w).to_upper()
		_weapon.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0) if w.upgraded else Color(0.85, 0.82, 0.76))
		_mag.text = str(w.mag)
		_reserve.text = "/ %d" % w.reserve
		var low: bool = w.mag <= int(WeaponDB.max_mag(w) * 0.25)
		_mag.add_theme_color_override("font_color", Color(0.95, 0.25, 0.15) if low else Color.WHITE)
	_grenades.queue_redraw()


func _on_hit(killed: bool, _head: bool) -> void:
	_hit_alpha = 1.0
	_hit_kill = killed


func _on_perks() -> void:
	for c in _perks.get_children():
		c.queue_free()
	for id in GameManager.perks:
		var p: Dictionary = GameManager.PERKS[id]
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(44, 44)
		var col: Color = p.color
		var letter: String = p.letter
		icon.draw.connect(func():
			icon.draw_circle(Vector2(22, 22), 21.0, Color(0, 0, 0, 0.6))
			icon.draw_circle(Vector2(22, 22), 18.0, col.darkened(0.2))
			icon.draw_arc(Vector2(22, 22), 20.0, 0.0, TAU, 32, col.lightened(0.4), 2.0, true)
			var f := UI.title_font()
			var sz := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
			icon.draw_string_outline(f, Vector2(22 - sz.x * 0.5, 31), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 4, Color(0, 0, 0, 0.8))
			icon.draw_string(f, Vector2(22 - sz.x * 0.5, 31), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE))
		_perks.add_child(icon)
		icon.pivot_offset = Vector2(22, 22)
		icon.scale = Vector2.ONE * 1.6
		icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _on_powerups() -> void:
	for kind in _powerup_labels.keys():
		if not GameManager.active_powerups.has(kind):
			_powerup_labels[kind].queue_free()
			_powerup_labels.erase(kind)
	for kind in GameManager.active_powerups:
		var remaining: float = GameManager.active_powerups[kind]
		var p: Dictionary = GameManager.POWERUPS[kind]
		if not _powerup_labels.has(kind):
			var l := Label.new()
			l.add_theme_font_override("font", UI.title_font())
			l.add_theme_font_size_override("font_size", 28)
			l.add_theme_color_override("font_color", p.color)
			l.add_theme_color_override("font_outline_color", Color.BLACK)
			l.add_theme_constant_override("outline_size", 6)
			_powerups.add_child(l)
			_powerup_labels[kind] = l
		var lbl: Label = _powerup_labels[kind]
		lbl.text = "%s  %d" % [p.name, ceili(remaining)]
		lbl.visible = remaining > 5.0 or fmod(remaining, 0.4) < 0.25


# --- Dessins --------------------------------------------------------------

## Compteur de manche : bâtons à la craie rouge pour 1 à 5, chiffres ensuite.
func _draw_round() -> void:
	if _round_num <= 0:
		return
	var c := _round_draw
	var col := RED.lerp(Color(1.0, 0.95, 0.9), _round_glow)
	col.a = _round_alpha
	var shadow := Color(0, 0, 0, 0.6 * _round_alpha)
	if _round_num <= 5:
		var rng := RandomNumberGenerator.new()
		rng.seed = _round_seed
		var marks := mini(_round_num, 4)
		for i in marks:
			var x := 18.0 + i * 26.0
			var a := Vector2(x + rng.randf_range(-3, 3), 22 + rng.randf_range(-4, 4))
			var b := Vector2(x + rng.randf_range(-5, 5), 118 + rng.randf_range(-4, 4))
			_chalk_line(c, a, b, col, shadow, rng)
		if _round_num == 5:
			_chalk_line(c, Vector2(4, 100), Vector2(118, 36), col, shadow, rng)
	else:
		var f := UI.title_font()
		var txt := str(_round_num)
		c.draw_string_outline(f, Vector2(14, 122), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, 10, shadow)
		c.draw_string(f, Vector2(14, 122), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, col)


func _chalk_line(c: Control, a: Vector2, b: Vector2, col: Color, shadow: Color, rng: RandomNumberGenerator) -> void:
	c.draw_line(a + Vector2(3, 3), b + Vector2(3, 3), shadow, 13.0, true)
	c.draw_line(a, b, col, 11.0, true)
	# grain de craie
	for i in 6:
		var t := rng.randf()
		var p := a.lerp(b, t) + Vector2(rng.randf_range(-6, 6), 0)
		c.draw_line(p, p + (b - a).normalized() * rng.randf_range(4, 12), Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, col.a), 3.0)


func _draw_boss_bar() -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.state == _boss.State.DEAD:
		_boss = null
		return
	var c := _boss_bar
	var f := UI.title_font()
	c.draw_string_outline(f, Vector2(0, 18), "LE COLOSSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
	c.draw_string(f, Vector2(0, 18), "LE COLOSSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.3, 0.15))
	var r := Rect2(0, 26, 640, 14)
	c.draw_rect(r.grow(2), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(_boss.hp / _boss.max_hp, 0, 1), r.size.y)), Color(0.75, 0.08, 0.04))
	if _boss.armor > 0.0:
		c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4), Vector2(r.size.x * clampf(_boss.armor / (_boss.max_hp * 0.25), 0, 1), 4)), Color(0.75, 0.75, 0.8))


func _draw_grenades() -> void:
	if player == null:
		return
	var mk: int = player.holder.monkeys
	if mk > 0:
		var f := UI.ui_font()
		var txt := GameManager.hint("SINGE x%d  [T]" % mk)
		_grenades.draw_string_outline(f, Vector2(-170, 19), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.8))
		_grenades.draw_string(f, Vector2(-170, 19), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.75, 0.35))
	var n: int = player.holder.grenades
	for i in 4:
		var p := Vector2(190 - i * 22, 13)
		var filled := i < n
		_grenades.draw_circle(p, 8.0, Color(0, 0, 0, 0.5))
		_grenades.draw_circle(p, 6.5, Color(0.55, 0.62, 0.4) if filled else Color(1, 1, 1, 0.12))
		_grenades.draw_rect(Rect2(p + Vector2(-2, -11), Vector2(4, 4)), Color(0.3, 0.3, 0.3) if filled else Color(1, 1, 1, 0.1))


func _draw_crosshair() -> void:
	if player == null or player.is_sprinting() or player.dead or player.downed:
		return
	if player.holder.aiming:
		_draw_aim_reticle()
		return
	var c := _crosshair.size * 0.5
	var gap: float = 7.0 + player.holder.current_spread() * 900.0
	var col := Color(1, 1, 1, 0.85)
	var sh := Color(0, 0, 0, 0.5)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		_crosshair.draw_line(c + d * gap, c + d * (gap + 11), sh, 4.0)
		_crosshair.draw_line(c + d * gap, c + d * (gap + 11), col, 2.0)
	_crosshair.draw_circle(c, 1.5, col)


## Visée : lunette plein écran pour les snipers, petit réticule fin pour les autres armes.
func _draw_aim_reticle() -> void:
	var h = player.holder
	var c := _crosshair.size * 0.5
	var a: float = clampf((h.aim_blend - 0.5) * 2.0, 0.0, 1.0)
	if a <= 0.0:
		return
	if h.has_scope():
		var r: float = minf(_crosshair.size.x, _crosshair.size.y) * 0.46
		var black := Color(0, 0, 0, a)
		# tout ce qui dépasse du cercle est noir
		_crosshair.draw_arc(c, r + 1500.0, 0.0, TAU, 128, black, 3000.0)
		_crosshair.draw_arc(c, r, 0.0, TAU, 128, Color(0, 0, 0, a), 5.0)
		var line := Color(0, 0, 0, 0.9 * a)
		_crosshair.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), line, 1.5)
		_crosshair.draw_line(c + Vector2(0, -r), c + Vector2(0, r), line, 1.5)
		# gros fils en bordure + graduations
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			_crosshair.draw_line(c + d * r * 0.62, c + d * r, line, 6.0)
		for i in range(1, 6):
			var t: float = r * 0.1 * i
			for d in [Vector2.RIGHT, Vector2.LEFT]:
				_crosshair.draw_line(c + d * t + Vector2(0, -5), c + d * t + Vector2(0, 5), line, 1.5)
			for d in [Vector2.DOWN, Vector2.UP]:
				_crosshair.draw_line(c + d * t + Vector2(-5, 0), c + d * t + Vector2(5, 0), line, 1.5)
		_crosshair.draw_circle(c, 2.0, Color(1, 0.1, 0.1, a))


## Flèches rouges autour du réticule, orientées vers la source des dégâts.
func _draw_damage_dirs() -> void:
	if player == null:
		return
	var c := _dmg_canvas.size * 0.5
	for e in _dmg_hits:
		var d: Vector3 = e.pos - player.global_position
		d.y = 0.0
		if d.length() < 0.05:
			continue
		var local: Vector3 = player.global_basis.inverse() * d.normalized()
		var theta := atan2(local.x, -local.z) - PI * 0.5 # 0 = devant (haut de l'écran)
		var a := clampf(1.0 - e.age / 2.6, 0.0, 1.0)
		var col := Color(0.9, 0.05, 0.03, a * 0.9)
		var r := 170.0
		_dmg_canvas.draw_arc(c, r, theta - 0.3, theta + 0.3, 14, col, 12.0, true)
		var tip := c + Vector2(cos(theta), sin(theta)) * (r + 26.0)
		var left := c + Vector2(cos(theta - 0.09), sin(theta - 0.09)) * (r + 4.0)
		var right := c + Vector2(cos(theta + 0.09), sin(theta + 0.09)) * (r + 4.0)
		_dmg_canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), col)


func _draw_hitmarker() -> void:
	if _hit_alpha <= 0.0:
		return
	var c := _hitmarker.size * 0.5
	var col := Color(1.0, 0.15, 0.1, _hit_alpha) if _hit_kill else Color(1, 1, 1, _hit_alpha)
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_hitmarker.draw_line(c + d * 6.0, c + d * 14.0, col, 2.5, true)
