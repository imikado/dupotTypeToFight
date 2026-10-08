extends Control

# Grande touche affichée au centre de l'écran : la prochaine touche à taper, dans
# la couleur de son doigt. Un anneau se resserre autour d'elle à mesure que
# l'ennemi approche (comme les cercles d'approche des jeux de rythme) ; la touche
# suivante est montrée en plus petit à côté. Elle reste toujours visible, juste
# au-dessus du joueur (centré à l'écran) : le regard reste au centre.

const BOX_SIZE := 34.0
# distance de l'ennemi (en pixels) à partir de laquelle l'anneau commence à se resserrer
const APPROACH_DISTANCE := 220.0
const RING_MAX_RADIUS := 30.0
const RING_WIDTH := 2.0

const COLOR_GOOD := Color(0.3, 0.9, 0.4)

# explosion de la touche validée, puis courte pause avant la suivante : même si
# c'est la même lettre, on voit bien qu'il faut la retaper
const EXPLOSION_SHARDS := 12
const EXPLOSION_DISTANCE := 42.0
const SHARD_SIZE := Vector2(4, 4)
const GAP_DURATION := 0.12
# chaque nouvelle touche tombe du haut de l'écran jusqu'à sa place
const FALL_HEIGHT := 90.0
const FALL_DURATION := 0.22
const COLOR_WRONG := Color(0.85, 0.1, 0.2)
const COLOR_TOO_EARLY := Color(1, 0.6, 0.15)

@onready var _letter: Label = $Letter
@onready var _next_letter: Label = $NextLetter

var _key_track
var _key := ""
var _box_style := StyleBoxFlat.new()
# 0 (loin) -> 1 (à portée)
var _approach := 0.0
var _flash_color := Color.TRANSPARENT
var _time := 0.0
# temps restant pendant lequel le centre reste vide après une touche validée
var _gap := 0.0
# position de repos (la touche tombe jusqu'ici)
var _base_y := 0.0
var _move_tween: Tween


func _ready():
	modulate.a = 0
	pivot_offset = size / 2
	_base_y = position.y
	_box_style.set_border_width_all(2)
	_box_style.set_corner_radius_all(4)


func setup(key_track):
	_key_track = key_track
	_key_track.key_validated.connect(_on_key_validated)
	_key_track.key_missed.connect(_on_key_missed)
	_key_track.key_too_early.connect(_on_key_too_early)


func _process(delta):
	_time += delta
	var current: Dictionary = _key_track.get_current() if _key_track else {}
	var key = current.get("key", "")
	_gap = max(0.0, _gap - delta)
	_letter.visible = _gap <= 0
	if _gap <= 0 and key != _key:
		_show_key(key)

	if not _key.is_empty():
		var distance = _key_track.get_current_distance()
		_approach = 1.0 - clamp(distance / APPROACH_DISTANCE, 0.0, 1.0)
		var next_key = _key_track.get_next_key()
		_next_letter.text = next_key.to_upper()
		_next_letter.add_theme_color_override("font_color", GlobalLessons.get_finger_color(next_key) if next_key else Color.WHITE)
	_flash_color.a = move_toward(_flash_color.a, 0.0, delta * 3)

	var target_alpha = 0.0 if key.is_empty() and _gap <= 0 else 1.0
	modulate.a = move_toward(modulate.a, target_alpha, delta * 6)
	queue_redraw()


func _show_key(key: String):
	_key = key
	if key.is_empty():
		return
	_letter.text = key.to_upper()
	var finger_color = GlobalLessons.get_finger_color(key)
	_box_style.bg_color = finger_color.darkened(0.45)
	_box_style.border_color = finger_color
	# la nouvelle touche tombe du haut, puis s'écrase légèrement en arrivant
	if _move_tween:
		_move_tween.kill()
	position.y = _base_y - FALL_HEIGHT
	scale = Vector2(0.85, 1.15)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:y", _base_y, FALL_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_move_tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.05)
	_move_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw():
	if _key.is_empty() or _gap > 0:
		return
	var center = size / 2
	var box = Rect2(center - Vector2.ONE * BOX_SIZE / 2, Vector2.ONE * BOX_SIZE)
	var finger_color: Color = _box_style.border_color
	var half = BOX_SIZE / 2

	# anneau d'approche : il se resserre jusqu'à la touche quand l'ennemi est à portée
	if _approach < 1.0:
		var radius = lerp(RING_MAX_RADIUS, half + 2, _approach)
		var ring_color = finger_color
		ring_color.a = 0.3 + 0.7 * _approach
		draw_arc(center, radius, 0, TAU, 48, ring_color, RING_WIDTH)
	else:
		# à portée : halo qui pulse
		var pulse = 0.5 + 0.5 * sin(_time * 12)
		draw_arc(center, half + 3 + pulse * 2, 0, TAU, 48, Color(COLOR_GOOD, 0.9), RING_WIDTH)

	draw_style_box(_box_style, box)
	if _flash_color.a > 0:
		draw_rect(box, _flash_color)


func _flash(color: Color):
	_flash_color = Color(color, 0.8)


func _on_key_validated(validated_key: String):
	# la touche validée explose ; le centre reste vide un court instant puis la
	# suivante arrive, même si c'est la même lettre
	var center = global_position + size / 2
	var finger_color = GlobalLessons.get_finger_color(validated_key)
	_explode_box(center, validated_key)
	for i in EXPLOSION_SHARDS:
		_spawn_shard(center, TAU * i / EXPLOSION_SHARDS, COLOR_GOOD if i % 2 == 0 else finger_color.lightened(0.3))
	_key = ""
	_gap = GAP_DURATION


# copie verte de la touche qui gonfle et s'efface (hors de ce nœud, qui est
# lui-même animé en taille)
func _explode_box(center: Vector2, key: String):
	var ghost := Panel.new()
	var style: StyleBoxFlat = _box_style.duplicate()
	style.bg_color = COLOR_GOOD
	style.border_color = Color.WHITE
	ghost.add_theme_stylebox_override("panel", style)
	ghost.size = Vector2.ONE * BOX_SIZE
	ghost.position = center - ghost.size / 2
	ghost.pivot_offset = ghost.size / 2
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = key.to_upper()
	label.add_theme_font_size_override("font_size", _letter.get_theme_font_size("font_size"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	get_parent().add_child(ghost)
	ghost.add_child(label)
	# une fois dans l'arbre (police du thème connue), on centre le texte sur sa
	# taille réelle, qui dépasse parfois la boîte
	label.size = ghost.size.max(label.get_combined_minimum_size())
	label.position = (ghost.size - label.size) / 2

	var tween = ghost.create_tween().set_parallel()
	tween.tween_property(ghost, "scale", Vector2(2.0, 2.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ghost.queue_free)


func _spawn_shard(center: Vector2, angle: float, color: Color):
	var shard := ColorRect.new()
	shard.size = SHARD_SIZE
	shard.color = color
	shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shard.pivot_offset = SHARD_SIZE / 2
	shard.position = center - SHARD_SIZE / 2
	get_parent().add_child(shard)
	var direction = Vector2.RIGHT.rotated(angle)
	var distance = EXPLOSION_DISTANCE * randf_range(0.7, 1.2)
	var tween = shard.create_tween().set_parallel()
	tween.tween_property(shard, "position", shard.position + direction * distance, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shard, "rotation", randf_range(-PI, PI), 0.35)
	tween.tween_property(shard, "modulate:a", 0.0, 0.2).set_delay(0.15)
	tween.chain().tween_callback(shard.queue_free)


func _on_key_missed(_key_expected: String):
	_flash(COLOR_WRONG)
	var tween = create_tween()
	for angle in [-0.2, 0.2, -0.12, 0.12, 0.0]:
		tween.tween_property(self, "rotation", angle, 0.04)


func _on_key_too_early(_key_expected: String):
	_flash(COLOR_TOO_EARLY)
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:y", _base_y - 5, 0.07).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position:y", _base_y, 0.1).set_ease(Tween.EASE_IN)
