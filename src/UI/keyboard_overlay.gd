extends Control

# Clavier affiché en transparence :
# - au début d'un niveau : les touches disponibles, colorées selon le doigt,
#   les nouvelles bordées de blanc et animées ; le clavier reste affiché
#   jusqu'à ce que le joueur appuie sur les touches « prêt » (F et J) ;
# - quand le joueur se trompe : le clavier garde les couleurs des touches du
#   niveau ; la touche tapée passe en rouge avec une croix, celle attendue est
#   mise en lumière avec une coche verte (pas de texte : pas le temps de lire).
# Deux mains « curseur » en pixel art montrent où poser les index (F et J) :
# elles tapotent les touches en début de niveau et restent immobiles en cas d'erreur.

const ROW_OFFSETS := [0.0, 5.0, 14.0]

const KEY_SIZE := Vector2(16, 16)
const KEY_SPACING := 18.0

const POINTER_LEFT := preload("res://src/UI/Hands/pointer-left.png")
const POINTER_RIGHT := preload("res://src/UI/Hands/pointer-right.png")
# position du bout de l'index dans chaque image (milieu de la colonne de l'index)
const POINTER_LEFT_TIP_X := 10.0
const POINTER_RIGHT_TIP_X := 5.0
# agrandissement entier pour garder des pixels nets
const POINTER_SCALE := 2
# touches F et J dans la rangée de repos (AZERTY comme QWERTY)
const HOME_INDEX_LEFT := 3
const HOME_INDEX_RIGHT := 6

# position verticale selon l'usage (sous la bannière de niveau / au-dessus du combat)
# en cas d'erreur (et clavier transparent) : au-dessus de la grande touche, qui
# est juste au-dessus des personnages ; sans les mains pour rester compact
const INTRO_Y := 84.0
const ERROR_Y := 38.0
# décalage vertical de l'interface de jeu (mode Arcade, sans la bande du bas)
var y_offset := 0.0
const INTRO_HEIGHT := 100.0
const ERROR_HEIGHT := 64.0

const COLOR_KEY := Color(0.164706, 0.172549, 0.4, 0.6)
const COLOR_BORDER := Color(0.34, 0.39, 0.73, 0.8)
# touche disponible : couleur du doigt assombrie ; nouvelle touche : plus vive
const AVAILABLE_DARKEN := 0.45
const NEW_DARKEN := 0.1
const COLOR_NEW_BORDER := Color.WHITE
const COLOR_WRONG := Color(0.85, 0.1, 0.2, 0.95)

# pastilles d'erreur : croix sur la touche tapée, coche sur la touche attendue
const BADGE_SIZE := 9.0
const COLOR_BADGE_WRONG := Color(0.85, 0.1, 0.2)
const COLOR_BADGE_EXPECTED := Color(0.2, 0.76, 0.28)
const COLOR_MESSAGE_READY := Color(1, 0.823529, 0.247059, 1)
const MESSAGE_FONT_SIZE_READY := 8

# opacité des touches indisponibles pendant la présentation du niveau
const DIM_ALPHA := 0.3

const MAX_ALPHA := 0.85
# clavier en transparence au début du niveau, pour voir la disposition ; la
# touche à taper y est mise en lumière (opaque, couleur vive, bordure blanche)
const LAYOUT_ALPHA := 0.45
const LAYOUT_CURRENT_SCALE := 1.2
# après une erreur, le clavier transparent revient (le joueur a des difficultés)
const LAYOUT_AFTER_ERROR_DURATION := 5.0
const ERROR_DURATION := 1.2

@onready var _keys_container: Control = $Keys
@onready var _message_label: Label = $MessageLabel

# touche -> {panel, style}
var _keys := {}
var _pointers: Array[TextureRect] = []
var _tween: Tween
var _is_showing_level := false
var _pulse_tweens: Array[Tween] = []
# touche -> tween de pulsation, pour l'arrêter quand la touche est validée
var _key_pulses := {}
var _badges: Array[Control] = []

var _key_track
# mode « clavier transparent » : touches du niveau et touche courante mise en lumière
var _layout_mode := false
var _layout_keys: Array = []
var _layout_current := ""
# clavier transparent gardé tout le niveau (au lieu de quelques secondes)
var _keep_layout := false


func _ready():
	modulate.a = 0
	_build_keys()
	GlobalEvents.wrong_key.connect(_on_wrong_key)


func set_key_track(key_track):
	_key_track = key_track


func _process(_delta):
	if not _layout_mode or not _key_track:
		return
	var key = _key_track.get_current().get("key", "")
	if key != _layout_current:
		_paint_layout_key(_layout_current, false)
		_layout_current = key
		_paint_layout_key(key, true)


func _build_keys():
	var rows = GlobalLessons.get_keyboard_rows()
	var width = 0.0
	for row_index in rows.size():
		var row: String = rows[row_index]
		for i in row.length():
			var key = row[i]
			var panel := Panel.new()
			panel.size = KEY_SIZE
			panel.pivot_offset = KEY_SIZE / 2
			panel.position = Vector2(ROW_OFFSETS[row_index] + i * KEY_SPACING, row_index * KEY_SPACING)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.set_border_width_all(1)
			panel.add_theme_stylebox_override("panel", style)

			var label := Label.new()
			label.text = key.to_upper()
			label.add_theme_font_size_override("font_size", 6)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 2)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.add_child(label)

			_keys_container.add_child(panel)
			_keys[key] = {"panel": panel, "style": style}
			width = max(width, panel.position.x + KEY_SIZE.x)
	_keys_container.size = Vector2(width, rows.size() * KEY_SPACING)
	_keys_container.position.x = (size.x - width) / 2

	var home_row_x = func(index): return ROW_OFFSETS[1] + index * KEY_SPACING + KEY_SIZE.x / 2
	# index gauche sur F, index droit sur J : le bout du doigt touche le bas
	# de la touche pour laisser la lettre lisible
	var pointer_y = KEY_SPACING + KEY_SIZE.y - 2
	_pointers.append(_create_pointer(POINTER_LEFT, home_row_x.call(HOME_INDEX_LEFT) - POINTER_LEFT_TIP_X * POINTER_SCALE, pointer_y))
	_pointers.append(_create_pointer(POINTER_RIGHT, home_row_x.call(HOME_INDEX_RIGHT) - POINTER_RIGHT_TIP_X * POINTER_SCALE, pointer_y))
	_reset_keys()


func _create_pointer(texture: Texture2D, x: float, y: float) -> TextureRect:
	var pointer := TextureRect.new()
	pointer.texture = texture
	pointer.scale = Vector2(POINTER_SCALE, POINTER_SCALE)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.position = Vector2(roundi(x), roundi(y))
	pointer.set_meta("base_y", pointer.position.y)
	pointer.visible = false
	_keys_container.add_child(pointer)
	return pointer


func _reset_keys():
	for tween in _pulse_tweens:
		tween.kill()
	_pulse_tweens.clear()
	_key_pulses.clear()
	for key in _keys:
		_paint(key, COLOR_KEY, COLOR_BORDER)
		_keys[key].panel.modulate.a = 1.0
		_keys[key].panel.scale = Vector2.ONE
		_keys[key].panel.z_index = 0
		_keys[key].panel.rotation = 0.0
	self_modulate.a = 1.0
	_layout_mode = false
	_layout_current = ""
	for pointer in _pointers:
		pointer.visible = false
		pointer.position.y = pointer.get_meta("base_y")
	for badge in _badges:
		badge.queue_free()
	_badges.clear()


func _paint(key: String, bg: Color, border: Color, border_width := 1):
	if not _keys.has(key):
		return
	var style: StyleBoxFlat = _keys[key].style
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)


# présentation du niveau, affichée jusqu'à l'appel de hide_keyboard() :
# ready_keys pulsent tant que le joueur ne les a pas appuyées (mark_ready_key) ;
func show_level_keys(keys: Array, new_keys: Array, ready_keys: Array):
	_reset_keys()
	_layout_keys = keys
	_is_showing_level = true
	position.y = INTRO_Y + y_offset
	size.y = INTRO_HEIGHT
	for key in _keys:
		var finger_color = GlobalLessons.get_key_color(key)
		if new_keys.has(key):
			_paint(key, finger_color.darkened(NEW_DARKEN), COLOR_NEW_BORDER, 2)
			_pulse(key)
		elif keys.has(key):
			_paint(key, finger_color.darkened(AVAILABLE_DARKEN), finger_color)
		else:
			_keys[key].panel.modulate.a = DIM_ALPHA

	_show_pointers(true)

	for key in ready_keys:
		if not _key_pulses.has(key):
			_pulse(key)
	set_message(tr("READY") % _join_keys(ready_keys), COLOR_MESSAGE_READY, MESSAGE_FONT_SIZE_READY)

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", MAX_ALPHA, 0.2)


# « F et J », « F, J, D et K »
func _join_keys(keys: Array) -> String:
	var letters = keys.map(func(key): return key.to_upper())
	if letters.size() <= 1:
		return "".join(letters)
	return ", ".join(letters.slice(0, -1)) + " %s %s" % [tr("AND"), letters.back()]


# le joueur a appuyé sur une des touches « prêt » : elle s'allume et ne pulse plus
func mark_ready_key(key: String):
	if not _keys.has(key):
		return
	if _key_pulses.has(key):
		_key_pulses[key].kill()
		_key_pulses.erase(key)
	var panel: Panel = _keys[key].panel
	_paint(key, GlobalLessons.get_key_color(key), COLOR_NEW_BORDER, 2)
	panel.scale = Vector2(1.4, 1.4)
	var tween = panel.create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_message(text: String, color: Color, font_size := MESSAGE_FONT_SIZE_READY):
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.add_theme_font_size_override("font_size", font_size)


# après « C'est parti ! » : le clavier glisse sous la grande touche et reste en
# transparence quelques secondes (touches du niveau colorées par doigt) ;
# keep : il reste affiché jusqu'à hide_keyboard()
func show_layout(keys: Array, duration: float, keep := false):
	_layout_keys = keys
	_keep_layout = keep
	_enter_layout(duration)


# la transparence est portée par chaque touche (et le fond via self_modulate)
# pour que la touche à taper puisse, elle, rester opaque
func _enter_layout(duration: float):
	_reset_keys()
	_is_showing_level = false
	_layout_mode = true
	self_modulate.a = LAYOUT_ALPHA
	for key in _keys:
		_paint_layout_key(key, false)
	set_message("", Color.WHITE)

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(self, "position:y", ERROR_Y + y_offset, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "size:y", ERROR_HEIGHT, 0.3)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	if _keep_layout:
		return
	_tween.chain().tween_interval(duration)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.8)
	_tween.chain().tween_callback(_on_hidden)


func _paint_layout_key(key: String, is_current: bool):
	if not _keys.has(key):
		return
	var panel: Panel = _keys[key].panel
	var finger_color = GlobalLessons.get_key_color(key)
	if is_current:
		_paint(key, finger_color, Color.WHITE, 2)
		panel.modulate.a = 1.0
		panel.z_index = 1
		panel.scale = Vector2.ONE * LAYOUT_CURRENT_SCALE
		var tween = panel.create_tween()
		tween.tween_property(panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2.ONE * 1.1, 0.1)
		return
	panel.z_index = 0
	panel.scale = Vector2.ONE
	if _layout_keys.has(key):
		_paint(key, finger_color.darkened(AVAILABLE_DARKEN), finger_color)
		panel.modulate.a = LAYOUT_ALPHA
	else:
		_paint(key, COLOR_KEY, COLOR_BORDER)
		panel.modulate.a = LAYOUT_ALPHA * DIM_ALPHA


func hide_keyboard():
	_keep_layout = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(_on_hidden)
	await _tween.finished


# animated : petit mouvement de frappe pour inviter à appuyer sur F et J
func _show_pointers(animated: bool):
	for pointer in _pointers:
		pointer.visible = true
		if not animated:
			continue
		# petit mouvement de frappe : le doigt s'écarte puis revient sur la touche
		var base_y = pointer.get_meta("base_y")
		var tween = pointer.create_tween().set_loops()
		tween.tween_property(pointer, "position:y", base_y + 4, 0.3).set_trans(Tween.TRANS_SINE)
		tween.tween_property(pointer, "position:y", base_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_interval(0.25)
		_pulse_tweens.append(tween)


func _pulse(key: String):
	var panel: Panel = _keys[key].panel
	var tween = panel.create_tween().set_loops()
	tween.tween_property(panel, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	_pulse_tweens.append(tween)
	_key_pulses[key] = tween


func _on_wrong_key(expected: String, typed: String):
	_reset_keys()
	# pendant la bannière de niveau, on reste en dessous pour ne pas la masquer
	if not _is_showing_level:
		position.y = ERROR_Y + y_offset
		size.y = ERROR_HEIGHT
	# mêmes couleurs que le clavier transparent, pour ne pas perdre ses repères
	for key in _keys:
		if _layout_keys.has(key):
			var finger_color = GlobalLessons.get_key_color(key)
			_paint(key, finger_color.darkened(AVAILABLE_DARKEN), finger_color)
		else:
			_keys[key].panel.modulate.a = DIM_ALPHA
	var expected_panel: Panel = _keys[expected].panel if _keys.has(expected) else null
	if expected_panel:
		_paint(expected, GlobalLessons.get_key_color(expected), Color.WHITE, 2)
		expected_panel.modulate.a = 1.0
		expected_panel.z_index = 1
		expected_panel.scale = Vector2.ONE * LAYOUT_CURRENT_SCALE
	# bordure blanche et secousse : à ne pas confondre avec le rouge de l'auriculaire gauche
	_paint(typed, COLOR_WRONG, Color.WHITE, 2)
	if _keys.has(typed):
		var typed_panel: Panel = _keys[typed].panel
		typed_panel.modulate.a = 1.0
		typed_panel.z_index = 1
		var shake = typed_panel.create_tween()
		for angle in [-0.25, 0.25, -0.15, 0.15, 0.0]:
			shake.tween_property(typed_panel, "rotation", angle, 0.04)
	_add_badge(typed, false)
	_add_badge(expected, true)
	set_message("", Color.WHITE)
	if _is_showing_level or _layout_keys.is_empty():
		_show(ERROR_DURATION)
		return
	# puis le clavier transparent revient quelques secondes : le joueur a des difficultés
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", MAX_ALPHA, 0.1)
	_tween.tween_interval(ERROR_DURATION)
	_tween.tween_callback(_enter_layout.bind(LAYOUT_AFTER_ERROR_DURATION))


# pastille ronde dans le coin de la touche : coche (attendue) ou croix (erreur)
func _add_badge(key: String, is_expected: bool):
	if not _keys.has(key):
		return
	var badge := Control.new()
	badge.size = Vector2.ONE * BADGE_SIZE
	badge.position = Vector2(KEY_SIZE.x - BADGE_SIZE + 3, -3)
	badge.pivot_offset = badge.size / 2
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 1
	badge.draw.connect(_draw_badge.bind(badge, is_expected))
	_keys[key].panel.add_child(badge)
	_badges.append(badge)
	badge.scale = Vector2.ZERO
	var tween = badge.create_tween()
	tween.tween_property(badge, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_badge(badge: Control, is_expected: bool):
	var center = badge.size / 2
	badge.draw_circle(center, BADGE_SIZE / 2, COLOR_BADGE_EXPECTED if is_expected else COLOR_BADGE_WRONG)
	if is_expected:
		badge.draw_polyline(PackedVector2Array([Vector2(2, 4.5), Vector2(4, 6.5), Vector2(7, 2.5)]), Color.WHITE, 1.5)
	else:
		badge.draw_line(Vector2(2.5, 2.5), Vector2(6.5, 6.5), Color.WHITE, 1.5)
		badge.draw_line(Vector2(6.5, 2.5), Vector2(2.5, 6.5), Color.WHITE, 1.5)


func _show(duration: float):
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", MAX_ALPHA, 0.1)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(_on_hidden)


func _on_hidden():
	_is_showing_level = false
	_reset_keys()
