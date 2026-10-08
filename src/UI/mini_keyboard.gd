extends Control

# Petit clavier permanent (en bas au centre, activable depuis le bouton en haut du
# jeu ou avec Tab) : touches du niveau dans la couleur de leur doigt, touches pas
# encore apprises estompées, touche à taper bordée de blanc.

# décalage de chaque rangée, en fraction de largeur de touche
const ROW_OFFSETS := [0.0, 0.3, 0.8]
# les touches remplissent la place disponible
const KEY_GAP := 1.0

const COLOR_KEY := Color(0.164706, 0.172549, 0.4, 0.6)
const COLOR_BORDER := Color(0.34, 0.39, 0.73, 0.8)
# touches du niveau en retrait, pour que la touche à taper ressorte
const AVAILABLE_DARKEN := 0.55
const AVAILABLE_ALPHA := 0.8
const DIM_ALPHA := 0.25
# touche à taper : couleur vive, bordure épaisse et halo blanc qui pulse
const CURRENT_LIGHTEN := 0.25
const CURRENT_BORDER_WIDTH := 2
const HALO_SIZE := 2.0
const HALO_ALPHA_MIN := 0.35
const HALO_ALPHA_MAX := 0.9
const HALO_SPEED := 8.0
# touche suivante : simple bordure claire
const COLOR_NEXT_BORDER := Color(1, 1, 1, 0.6)
# fond sombre derrière les touches, même style que la piste des touches
const BACKGROUND_MARGIN := 2.0

# touche -> {panel, style}
var _keys := {}
var _available: Array = []
var _current_key := ""
var _next_key := ""
var _key_track
var _background := StyleBoxFlat.new()
var _halo := StyleBoxFlat.new()
var _time := 0.0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.bg_color = Color(0.0627451, 0.0862745, 0.2, 0.92)
	_background.border_color = Color(0.34, 0.39, 0.73)
	_background.set_border_width_all(1)
	_background.set_corner_radius_all(5)
	_halo.set_corner_radius_all(3)
	resized.connect(_layout_keys)
	_build_keys()


func setup(key_track):
	_key_track = key_track


func set_available_keys(keys: Array):
	_available = keys
	_current_key = ""
	_next_key = ""
	_refresh()


func _process(delta):
	if not visible or not _key_track:
		return
	var key = _key_track.get_current().get("key", "")
	var next_key = _key_track.get_next_key()
	if key != _current_key or next_key != _next_key:
		_current_key = key
		_next_key = next_key
		_refresh()
	# le halo de la touche à taper pulse
	_time += delta
	if _keys.has(_current_key):
		queue_redraw()


func _draw():
	draw_style_box(_background, Rect2(-Vector2.ONE * BACKGROUND_MARGIN, size + Vector2.ONE * BACKGROUND_MARGIN * 2))
	# halo dessiné sous la touche à taper (les touches sont des enfants, dessinés par-dessus)
	if _keys.has(_current_key):
		var panel: Panel = _keys[_current_key].panel
		var pulse = (sin(_time * HALO_SPEED) + 1.0) / 2.0
		_halo.bg_color = Color(1, 1, 1, lerp(HALO_ALPHA_MIN, HALO_ALPHA_MAX, pulse))
		draw_style_box(_halo, Rect2(panel.position, panel.size).grow(HALO_SIZE))


func _build_keys():
	var rows = GlobalLessons.get_keyboard_rows()
	for row_index in rows.size():
		var row: String = rows[row_index]
		for i in row.length():
			var key = row[i]
			var panel := Panel.new()
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
			panel.add_child(label)
			add_child(panel)
			_keys[key] = {"panel": panel, "style": style, "label": label, "row": row_index, "column": i}
	_layout_keys()
	_refresh()


# touches plus larges que hautes pour occuper toute la bande
func _layout_keys():
	# largeur de la rangée la plus longue, décalage compris, en largeurs de touche
	var rows = GlobalLessons.get_keyboard_rows()
	var columns := 0.0
	for row_index in rows.size():
		columns = max(columns, ROW_OFFSETS[row_index] + rows[row_index].length())
	var step = Vector2(floor(size.x / columns), floor(size.y / rows.size()))
	var key_size = step - Vector2.ONE * KEY_GAP
	# clavier centré dans la bande
	var margin_x = floor((size.x - step.x * columns + KEY_GAP) / 2)
	for key in _keys:
		var data = _keys[key]
		var panel: Panel = data.panel
		panel.size = key_size
		panel.position = Vector2(margin_x + round((ROW_OFFSETS[data.row] + data.column) * step.x), data.row * step.y)
		var label: Label = data.label
		label.size = key_size.max(label.get_combined_minimum_size())
		label.position = (key_size - label.size) / 2
	queue_redraw()


func _refresh():
	for key in _keys:
		var style: StyleBoxFlat = _keys[key].style
		var panel: Panel = _keys[key].panel
		var finger_color = GlobalLessons.get_key_color(key)
		style.set_border_width_all(1)
		if key == _current_key:
			style.bg_color = finger_color.lightened(CURRENT_LIGHTEN)
			style.border_color = Color.WHITE
			style.set_border_width_all(CURRENT_BORDER_WIDTH)
			panel.modulate.a = 1.0
		elif _available.has(key):
			style.bg_color = finger_color.darkened(AVAILABLE_DARKEN)
			style.border_color = COLOR_NEXT_BORDER if key == _next_key else finger_color.darkened(AVAILABLE_DARKEN / 2)
			panel.modulate.a = 1.0 if key == _next_key else AVAILABLE_ALPHA
		else:
			style.bg_color = COLOR_KEY
			style.border_color = COLOR_BORDER
			panel.modulate.a = DIM_ALPHA
	queue_redraw()
