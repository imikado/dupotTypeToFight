extends Control

# Petit clavier permanent (en bas à droite, activable depuis le bouton en haut du
# jeu ou avec Tab) : touches du niveau dans la couleur de leur doigt, touches pas
# encore apprises estompées, touche à taper bordée de blanc.

const ROWS := {
	0: ["azertyuiop", "qsdfghjklm", "wxcvbn"],  # GlobalGame.KEYBOARD_LAYOUT.AZERTY
	1: ["qwertyuiop", "asdfghjkl", "zxcvbnm"],  # GlobalGame.KEYBOARD_LAYOUT.QWERTY
}
const ROW_OFFSETS := [0.0, 3.0, 8.0]
const KEY_SIZE := Vector2(10, 10)
const KEY_SPACING := 11.0

const COLOR_KEY := Color(0.164706, 0.172549, 0.4, 0.6)
const COLOR_BORDER := Color(0.34, 0.39, 0.73, 0.8)
const AVAILABLE_DARKEN := 0.4
const DIM_ALPHA := 0.35

# touche -> {panel, style}
var _keys := {}
var _available: Array = []
var _current_key := ""
var _key_track


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_keys()


func setup(key_track):
	_key_track = key_track


func set_available_keys(keys: Array):
	_available = keys
	_current_key = ""
	_refresh()


func _process(_delta):
	if not visible or not _key_track:
		return
	var key = _key_track.get_current().get("key", "")
	if key != _current_key:
		_current_key = key
		_refresh()


func _build_keys():
	var rows = ROWS[GlobalGame.getKeyboardLayout()]
	for row_index in rows.size():
		var row: String = rows[row_index]
		for i in row.length():
			var key = row[i]
			var panel := Panel.new()
			panel.size = KEY_SIZE
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
			panel.add_child(label)
			label.size = KEY_SIZE.max(label.get_combined_minimum_size())
			label.position = (KEY_SIZE - label.size) / 2
			add_child(panel)
			_keys[key] = {"panel": panel, "style": style}
	_refresh()


func _refresh():
	for key in _keys:
		var style: StyleBoxFlat = _keys[key].style
		var panel: Panel = _keys[key].panel
		var finger_color = GlobalLessons.get_finger_color(key)
		if key == _current_key:
			style.bg_color = finger_color
			style.border_color = Color.WHITE
			panel.modulate.a = 1.0
		elif _available.has(key):
			style.bg_color = finger_color.darkened(AVAILABLE_DARKEN)
			style.border_color = finger_color
			panel.modulate.a = 1.0
		else:
			style.bg_color = COLOR_KEY
			style.border_color = COLOR_BORDER
			panel.modulate.a = DIM_ALPHA
