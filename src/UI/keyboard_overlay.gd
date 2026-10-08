extends Control

# Clavier affiché en transparence :
# - au début d'un niveau : les touches disponibles, les nouvelles en orange,
#   avec le doigt à utiliser pour chaque nouvelle touche ;
# - quand le joueur se trompe : la touche tapée en rouge, celle attendue en jaune.

const ROWS := {
	0: ["azertyuiop", "qsdfghjklm", "wxcvbn"],  # GlobalGame.KEYBOARD_LAYOUT.AZERTY
	1: ["qwertyuiop", "asdfghjkl", "zxcvbnm"],  # GlobalGame.KEYBOARD_LAYOUT.QWERTY
}
const ROW_OFFSETS := [0.0, 5.0, 14.0]

const KEY_SIZE := Vector2(16, 16)
const KEY_SPACING := 18.0

# position verticale selon l'usage (sous la bannière de niveau / au-dessus du combat)
const INTRO_Y := 84.0
const ERROR_Y := 46.0

const COLOR_KEY := Color(0.164706, 0.172549, 0.4, 0.6)
const COLOR_BORDER := Color(0.34, 0.39, 0.73, 0.8)
const COLOR_AVAILABLE := Color(0.2, 0.45, 0.3, 0.85)
const COLOR_AVAILABLE_BORDER := Color(0.45, 0.9, 0.55, 1)
const COLOR_NEW := Color(1, 0.603922, 0.235294, 1)
const COLOR_WRONG := Color(0.85, 0.1, 0.2, 0.95)
const COLOR_EXPECTED := Color(1, 0.823529, 0.247059, 0.95)

const COLOR_MESSAGE_INTRO := Color(1, 0.8, 0.6, 1)
const COLOR_MESSAGE_ERROR := Color(1, 0.6, 0.6, 1)

# opacité des touches indisponibles pendant la présentation du niveau
const DIM_ALPHA := 0.3

const MAX_ALPHA := 0.85
const ERROR_DURATION := 1.2

@onready var _keys_container: Control = $Keys
@onready var _message_label: Label = $MessageLabel

# touche -> {panel, style}
var _keys := {}
var _tween: Tween
var _is_showing_level := false
var _pulse_tweens: Array[Tween] = []


func _ready():
	modulate.a = 0
	_build_keys()
	GlobalEvents.wrong_key.connect(_on_wrong_key)


func _build_keys():
	var rows = ROWS[GlobalGame.getKeyboardLayout()]
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
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.add_child(label)

			_keys_container.add_child(panel)
			_keys[key] = {"panel": panel, "style": style}
			width = max(width, panel.position.x + KEY_SIZE.x)
	_keys_container.size = Vector2(width, rows.size() * KEY_SPACING)
	_keys_container.position.x = (size.x - width) / 2
	_reset_keys()


func _reset_keys():
	for tween in _pulse_tweens:
		tween.kill()
	_pulse_tweens.clear()
	for key in _keys:
		_paint(key, COLOR_KEY, COLOR_BORDER)
		_keys[key].panel.modulate.a = 1.0
		_keys[key].panel.scale = Vector2.ONE


func _paint(key: String, bg: Color, border: Color, border_width := 1):
	if not _keys.has(key):
		return
	var style: StyleBoxFlat = _keys[key].style
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)


# présentation du niveau : touches disponibles en vert, nouvelles en orange
func show_level_keys(keys: Array, new_keys: Array, duration: float):
	_reset_keys()
	_is_showing_level = true
	position.y = INTRO_Y
	for key in _keys:
		if new_keys.has(key):
			_paint(key, COLOR_NEW.darkened(0.35), COLOR_NEW, 2)
			_pulse(_keys[key].panel)
		elif keys.has(key):
			_paint(key, COLOR_AVAILABLE, COLOR_AVAILABLE_BORDER)
		else:
			_keys[key].panel.modulate.a = DIM_ALPHA

	var hints := []
	for key in new_keys:
		hints.append("%s : %s" % [key.to_upper(), GlobalLessons.get_finger(key)])
	# deux consignes par ligne pour rester dans la largeur du clavier
	var lines := []
	for i in range(0, hints.size(), 2):
		lines.append("   ".join(hints.slice(i, i + 2)))
	_message_label.text = "\n".join(lines)
	_message_label.add_theme_color_override("font_color", COLOR_MESSAGE_INTRO)
	_show(duration)


func _pulse(panel: Panel):
	var tween = panel.create_tween().set_loops()
	tween.tween_property(panel, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	_pulse_tweens.append(tween)


func _on_wrong_key(expected: String, typed: String):
	_reset_keys()
	# pendant la bannière de niveau, on reste en dessous pour ne pas la masquer
	if not _is_showing_level:
		position.y = ERROR_Y
	_paint(expected, COLOR_EXPECTED.darkened(0.4), COLOR_EXPECTED)
	_paint(typed, COLOR_WRONG, COLOR_WRONG.lightened(0.3))

	var typed_text = typed.to_upper()
	if typed.strip_edges().is_empty():
		typed_text = "ESPACE"
	_message_label.text = "%s au lieu de %s" % [typed_text, expected.to_upper()]
	_message_label.add_theme_color_override("font_color", COLOR_MESSAGE_ERROR)
	_show(ERROR_DURATION)


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
