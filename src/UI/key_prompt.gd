extends Control

# Grande touche affichée au centre de l'écran : la prochaine touche à taper, dans
# la couleur de son doigt. Un anneau se resserre autour d'elle à mesure que
# l'ennemi approche (comme les cercles d'approche des jeux de rythme) ; la touche
# suivante est montrée en plus petit à côté. Elle s'efface pendant l'affichage
# du clavier d'erreur, qui montre déjà la touche attendue au même endroit.

const BOX_SIZE := 34.0
# distance de l'ennemi (en pixels) à partir de laquelle l'anneau commence à se resserrer
const APPROACH_DISTANCE := 220.0
const RING_MAX_RADIUS := 44.0
const RING_WIDTH := 2.0

const COLOR_GOOD := Color(0.3, 0.9, 0.4)
const COLOR_WRONG := Color(0.85, 0.1, 0.2)
const COLOR_TOO_EARLY := Color(1, 0.6, 0.15)

@onready var _letter: Label = $Letter
@onready var _next_letter: Label = $NextLetter

var _key_track
var _keyboard_overlay: Control
var _key := ""
var _box_style := StyleBoxFlat.new()
# 0 (loin) -> 1 (à portée)
var _approach := 0.0
var _flash_color := Color.TRANSPARENT
var _time := 0.0


func _ready():
	modulate.a = 0
	pivot_offset = size / 2
	_box_style.set_border_width_all(2)
	_box_style.set_corner_radius_all(4)


func setup(key_track, keyboard_overlay: Control):
	_key_track = key_track
	_keyboard_overlay = keyboard_overlay
	_key_track.key_validated.connect(_on_key_validated)
	_key_track.key_missed.connect(_on_key_missed)
	_key_track.key_too_early.connect(_on_key_too_early)


func _process(delta):
	_time += delta
	var current: Dictionary = _key_track.get_current() if _key_track else {}
	var key = current.get("key", "")
	if key != _key:
		_show_key(key)

	if not _key.is_empty():
		var distance = _key_track.get_current_distance()
		_approach = 1.0 - clamp(distance / APPROACH_DISTANCE, 0.0, 1.0)
		var next_key = _key_track.get_next_key()
		_next_letter.text = next_key.to_upper()
		_next_letter.add_theme_color_override("font_color", GlobalLessons.get_finger_color(next_key) if next_key else Color.WHITE)
	_flash_color.a = move_toward(_flash_color.a, 0.0, delta * 3)

	var keyboard_shown = _keyboard_overlay and _keyboard_overlay.modulate.a > 0.05
	var target_alpha = 1.0 if not _key.is_empty() and not keyboard_shown else 0.0
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
	# la nouvelle touche arrive en grossissant
	scale = Vector2(0.6, 0.6)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw():
	if _key.is_empty():
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


func _on_key_validated(_validated_key: String):
	# la touche validée s'envole en vert, la suivante prend sa place
	var ghost := Label.new()
	ghost.text = _letter.text
	ghost.add_theme_font_size_override("font_size", _letter.get_theme_font_size("font_size"))
	ghost.add_theme_color_override("font_color", COLOR_GOOD)
	ghost.add_theme_color_override("font_outline_color", Color.BLACK)
	ghost.add_theme_constant_override("outline_size", 4)
	ghost.position = _letter.position
	ghost.size = _letter.size
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.pivot_offset = ghost.size / 2
	add_child(ghost)
	var tween = ghost.create_tween().set_parallel()
	tween.tween_property(ghost, "position:y", ghost.position.y - 18, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale", Vector2(1.6, 1.6), 0.3)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(ghost.queue_free)
	_flash(COLOR_GOOD)


func _on_key_missed(_key_expected: String):
	_flash(COLOR_WRONG)
	var tween = create_tween()
	for angle in [-0.2, 0.2, -0.12, 0.12, 0.0]:
		tween.tween_property(self, "rotation", angle, 0.04)


func _on_key_too_early(_key_expected: String):
	_flash(COLOR_TOO_EARLY)
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 5, 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y, 0.1).set_ease(Tween.EASE_IN)
